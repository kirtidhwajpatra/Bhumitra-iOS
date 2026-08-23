"""
Phase 4 Pytest Suite: Production Backend, Security & Reliability Hardening
Validates API security boundaries, injection protection, input sanitization,
rate-limiting, request coalescing, timeout isolation, and zero PII logging.
"""
import pytest
import asyncio
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from app import create_app
from core.config import settings
from core.rate_limiter import limiter
from services.ror_service import RoRService, _cache, _negative_cache, _inflight_scrapes
from models.ror_response import RoRResponse, RoRVerification, RoRVerificationStatus, OwnerEntry


@pytest.fixture(scope="module")
def client():
    app = create_app()
    with TestClient(app) as test_client:
        yield test_client


def test_1_health_and_readiness_probes_isolated(client):
    """Verify that /health and /ready return 200 without touching upstream Bhulekh."""
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"

    resp_ready = client.get("/ready")
    assert resp_ready.status_code == 200
    assert resp_ready.json()["status"] == "ready"


def test_2_input_sanitization_encoded_null_bytes(client):
    """Verify rejection of encoded null bytes in query parameters with 400 Bad Request."""
    resp = client.get("/api/v1/ror?district=KEONJHAR%00&tahasil=SADAR&village=KERI&plot=100")
    assert resp.status_code == 400
    assert "MALFORMED_INPUT" in resp.text or "INVALID_INPUT" in resp.text


def test_3_input_sanitization_path_traversal(client):
    """Verify rejection of path traversal sequences (..) with 400 Bad Request."""
    resp = client.get("/api/v1/ror?district=KEONJHAR&tahasil=../../etc&village=KERI&plot=100")
    assert resp.status_code == 400
    assert "MALFORMED_INPUT" in resp.text


def test_4_input_sanitization_oversized_payload(client):
    """Verify rejection of oversized strings (>64 chars) with 400 Bad Request."""
    long_str = "A" * 128
    resp = client.get(f"/api/v1/ror?district={long_str}&tahasil=SADAR&village=KERI&plot=100")
    assert resp.status_code == 400
    assert "INPUT_TOO_LONG" in resp.text or "cannot exceed" in resp.text


def test_5_cors_production_restriction():
    """Verify CORS policy restricts origins strictly in production mode."""
    with patch.object(settings, "ENV", "production"):
        origins = settings.ALLOWED_ORIGINS
        assert "*" not in origins
        assert "https://bhumitra.app" in origins


def test_6_rate_limiter_burst_enforcement():
    """Verify that sliding window rate limiter returns 429 after threshold is exceeded."""
    limiter._requests.clear()
    key = "test_tag:127.0.0.1"
    
    # Allow 5 requests
    for i in range(5):
        allowed, remaining, retry_after = limiter.is_allowed(key, max_requests=5, window_seconds=60)
        assert allowed is True
        
    # 6th request must be rejected
    allowed, remaining, retry_after = limiter.is_allowed(key, max_requests=5, window_seconds=60)
    assert allowed is False
    assert retry_after > 0


@pytest.mark.anyio
async def test_7_singleflight_request_coalescing():
    """Verify concurrent duplicate requests are coalesced into a single underlying scrape."""
    service = RoRService()
    _cache.clear()
    _inflight_scrapes.clear()

    mock_resp = RoRResponse(
        success=True,
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        village="G_Dimbo",
        plot="12",
        khata="142",
        owners=[OwnerEntry(name="Dillip Mahanta", relation="Father", relation_name="Suresh", share="1.000", khata_number="142")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED,
            requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR",
            requested_village="G_Dimbo",
            requested_plot="12",
            details="Exact plot match confirmed."
        ),
    )

    scrape_count = 0

    async def mock_fetch_ror(*args, **kwargs):
        nonlocal scrape_count
        scrape_count += 1
        await asyncio.sleep(0.05)
        return mock_resp

    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", side_effect=mock_fetch_ror):
        # Fire 5 concurrent identical requests
        tasks = [
            service.get_ror(
                district="KEONJHAR",
                tahasil="KEONJHAR SADAR",
                village="G_Dimbo",
                plot="12",
                v_id="317"
            )
            for _ in range(5)
        ]
        results = await asyncio.gather(*tasks)

        # Scrape must have executed exactly ONCE
        assert scrape_count == 1
        assert len(results) == 5
        for res in results:
            assert res.owners[0].name == "Dillip Mahanta"


def test_8_pii_log_redaction_guard():
    """Verify that logging middleware and loggers do not leak sensitive auth tokens or passwords."""
    from core.logging_middleware import SENSITIVE_HEADERS, SENSITIVE_BODY_KEYS
    assert "authorization" in SENSITIVE_HEADERS
    assert "x-admin-key" in SENSITIVE_HEADERS
    assert "identity_token" in SENSITIVE_BODY_KEYS
    assert "password" in SENSITIVE_BODY_KEYS
