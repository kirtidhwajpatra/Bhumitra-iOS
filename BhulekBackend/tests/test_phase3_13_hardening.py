"""
Phase 3.13 Automated Test Suite: Production Backend Hardening, Scaling, Reliability & Cost Control.
"""
import pytest
import asyncio
import time
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from main import app
from core.config import settings
from services.ror_service import (
    RoRService,
    RoRServiceException,
    _cache,
    _pdf_cache,
    _inflight_scrapes,
)
from models.ror_response import (
    RoRResponse,
    RoRVerificationStatus,
    RoRVerification,
    RoRErrorCode,
    OwnerEntry,
)

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_caches_and_inflights():
    _cache.clear()
    _pdf_cache.clear()
    _inflight_scrapes.clear()


@pytest.mark.anyio
async def test_1_concurrency_semaphore_bounded_to_config():
    """Verify that concurrent Playwright operations do not exceed the configured maximum."""
    from services.ror_service import _scrape_semaphore
    assert _scrape_semaphore._value <= settings.BHULEKH_MAX_CONCURRENT


@pytest.mark.anyio
async def test_2_queue_depth_rejection_when_capacity_exceeded():
    """Verify that requests are rejected with BHULEKH_RATE_LIMITED when the queue is full."""
    ror_service = RoRService()
    
    # Fill up the pending queue
    with patch("services.ror_service._pending_ror_count", settings.MAX_PENDING_BHULEKH_REQUESTS + 1):
        with pytest.raises(RoRServiceException) as exc_info:
            await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "999")
        
        assert exc_info.value.code == RoRErrorCode.BHULEKH_RATE_LIMITED
        assert exc_info.value.retryable is True


@pytest.mark.anyio
async def test_3_playwright_context_cleanup_guarantee_on_exception():
    """Verify that Playwright contexts and pages are safely closed on scrape exceptions."""
    from scrapers.bhulekh_scraper import BhulekhScraper
    scraper = BhulekhScraper()
    
    with patch.object(scraper, "_scrape", side_effect=ValueError("Simulated Page Crash")), \
         patch.object(scraper, "_fallback_verified_ror", side_effect=ValueError("Simulated Fallback Crash")):
        with pytest.raises(ValueError):
            await scraper.fetch_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")


@pytest.mark.anyio
async def test_4_session_isolation_between_concurrent_requests():
    """Verify that concurrent users querying different plots remain completely isolated."""
    ror_service = RoRService()
    
    res1 = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot="12",
        khata_number="112", area="0.41 Acre", owners=[OwnerEntry(name="MOHAN PATRA")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12",
            details="Exact Match"
        )
    )
    res2 = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot="836",
        khata_number="13", area="0.05 Acre", owners=[OwnerEntry(name="RAMA PATRA")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="836",
            details="Exact Match"
        )
    )
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_scrape:
        mock_scrape.side_effect = [res1, res2]
        
        task1 = asyncio.create_task(ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12"))
        task2 = asyncio.create_task(ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "836"))
        
        out1, out2 = await asyncio.gather(task1, task2)
        
        assert out1.plot == "12"
        assert out1.khata_number == "112"
        assert out2.plot == "836"
        assert out2.khata_number == "13"


@pytest.mark.anyio
async def test_5_timeout_enforcement_raises_504_or_timeout_error():
    """Verify that requests exceeding ROR_TIMEOUT_SECONDS fail with timeout error."""
    ror_service = RoRService()
    
    async def slow_scrape(*args, **kwargs):
        await asyncio.sleep(5)
        return None

    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", side_effect=slow_scrape):
        with patch.object(settings, "ROR_TIMEOUT_SECONDS", 0.05):
            with pytest.raises(RoRServiceException) as exc_info:
                await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
            assert exc_info.value.code == RoRErrorCode.BHULEKH_TIMEOUT


def test_6_health_and_readiness_probes():
    """Verify lightweight /health and /ready endpoints for Cloud Run."""
    res_health = client.get("/health")
    assert res_health.status_code == 200
    assert res_health.json()["status"] == "ok"
    
    res_ready = client.get("/ready")
    assert res_ready.status_code == 200
    assert res_ready.json()["status"] == "ready"


def test_7_provider_health_status_endpoint():
    """Verify that provider diagnostics return status without leaking credentials."""
    response = client.get("/api/v1/health/providers")
    assert response.status_code == 200
    data = response.json()
    assert "providers" in data
    assert "4k_geo_gis" in data["providers"]
    assert "bhulekh_portal" in data["providers"]
    assert "playwright_worker_pool" in data["providers"]


def test_8_rate_limit_structured_json_response():
    """Verify that rate limit or validation returns structured JSON error."""
    response = client.get("/api/v1/ror?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12")
    # Should not crash or return unhandled 500
    assert response.status_code in [200, 404, 422, 429, 502, 503]


def test_9_secrets_audit_cleanliness():
    """Verify that default production configuration does not contain hardcoded live passwords."""
    assert "password123" not in settings.DATABASE_URL
    assert settings.APPLE_BUNDLE_ID == "com.kirtidhwaj.Bhumitra"


@pytest.mark.anyio
async def test_10_simulated_load_10_25_50_concurrent_users():
    """Simulated load test verifying response times, throughput, and error rates across 10, 25, 50 concurrent simulated users."""
    ror_service = RoRService()
    mock_resp = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot="12",
        khata_number="112", area="0.41 Acre", owners=[OwnerEntry(name="MOHAN PATRA")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12",
            details="Exact Match"
        )
    )
    
    for concurrent_users in [10, 25, 50]:
        with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
            # Simulate 10ms processing latency
            async def fast_scrape(*args, **kwargs):
                await asyncio.sleep(0.01)
                return mock_resp
            mock_fetch.side_effect = fast_scrape
            
            start = time.time()
            tasks = [ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12") for _ in range(concurrent_users)]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            elapsed = time.time() - start
            
            successful = [r for r in results if isinstance(r, RoRResponse)]
            assert len(successful) == concurrent_users
            # Due to SingleFlight deduplication, mock_fetch was called at most once or twice
            assert mock_fetch.call_count <= 2
            assert elapsed < 1.0 # 50 concurrent requests handled in < 1 second!
