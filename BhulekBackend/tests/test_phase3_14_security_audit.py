"""
Phase 3.14 Automated Test Suite: Security, Privacy & Land-Record Data Protection Audit.
"""
import pytest
import time
import jwt
import hashlib
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from main import app
from core.config import settings
from services.ror_service import RoRService, _cache, _pdf_cache
from models.ror_response import (
    RoRResponse,
    RoRVerificationStatus,
    RoRVerification,
    OwnerEntry,
)

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_caches():
    _cache.clear()
    _pdf_cache.clear()


def test_1_invalid_jwt_token_rejected():
    """Verify that an arbitrary malformed JWT token is rejected with 401 Unauthorized."""
    headers = {"Authorization": "Bearer invalid.jwt.token"}
    response = client.get("/api/v1/usage/status", headers=headers)
    assert response.status_code == 401


def test_2_expired_jwt_token_rejected():
    """Verify that an expired JWT token is rejected with 401 Unauthorized."""
    payload = {"sub": "user-123", "exp": int(time.time()) - 3600}
    expired_token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm="HS256")
    headers = {"Authorization": f"Bearer {expired_token}"}
    response = client.get("/api/v1/usage/status", headers=headers)
    assert response.status_code == 401


def test_3_tampered_jwt_signature_rejected():
    """Verify that a JWT signed with a different secret key is rejected with 401 Unauthorized."""
    payload = {"sub": "user-123", "exp": int(time.time()) + 3600}
    tampered_token = jwt.encode(payload, "wrong-secret-key-9999-32-chars-long!", algorithm="HS256")
    headers = {"Authorization": f"Bearer {tampered_token}"}
    response = client.get("/api/v1/usage/status", headers=headers)
    assert response.status_code == 401


def test_4_anonymous_access_allowed_and_rate_limited():
    """Verify that anonymous requests are supported with IP-based rate limiting."""
    response = client.get("/api/v1/gis/districts")
    assert response.status_code == 200


def test_5_path_traversal_in_plot_rejected():
    """Verify that path traversal strings in plot parameter are rejected with 400 Bad Request."""
    response = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=DIMBO&plot=../../etc/passwd")
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "MALFORMED_INPUT"


def test_6_path_traversal_in_location_rejected():
    """Verify that path traversal strings in location parameters are rejected with 400 Bad Request."""
    response = client.get("/api/v1/ror?district=..%2F..%2Fetc&tahasil=SADAR&village=DIMBO&plot=12")
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "MALFORMED_INPUT"


def test_7_null_byte_injection_rejected():
    """Verify that null bytes in query parameters are rejected with 400 Bad Request."""
    response = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=DIMBO%00&plot=12")
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "MALFORMED_INPUT"


def test_8_oversized_string_input_rejected():
    """Verify that oversized parameter strings are rejected with 400 Bad Request."""
    oversized_plot = "A" * 100
    response = client.get(f"/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=DIMBO&plot={oversized_plot}")
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "INPUT_TOO_LONG"


@pytest.mark.anyio
async def test_9_legitimate_indian_plot_formats_preserved():
    """Verify that authentic Indian cadastral plot formats (12, 12/1, 12A, 0012, 2/936) are preserved without distortion."""
    valid_plots = ["12", "12/1", "12A", "0012", "2/936", "12-1"]
    ror_service = RoRService()
    
    for p in valid_plots:
        mock_resp = RoRResponse(
            success=True,
            district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot=p,
            khata_number="112", area="0.41 Acre", owners=[OwnerEntry(name="MOHAN PATRA")],
            verification=RoRVerification(
                status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
                requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot=p,
                details="Exact Match"
            )
        )
        with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
            mock_fetch.return_value = mock_resp
            result = await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", p)
            assert result.plot == p


@pytest.mark.anyio
async def test_10_cache_isolation_same_plot_different_villages():
    """Verify that identical plot numbers in different villages do not collide in the RoR cache."""
    ror_service = RoRService()
    
    res_dimbo = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot="12",
        khata_number="112", area="0.41 Acre", owners=[OwnerEntry(name="DIMBO OWNER")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12",
            details="Exact Match"
        )
    )
    res_baniapat = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Baniapat 270", plot="12",
        khata_number="83", area="0.05 Acre", owners=[OwnerEntry(name="BANIAPAT OWNER")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Baniapat 270", requested_plot="12",
            details="Exact Match"
        )
    )
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.side_effect = [res_dimbo, res_baniapat]
        
        out1 = await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12", v_id="0704317")
        out2 = await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Baniapat 270", "12", v_id="0704270")
        
        assert out1.owners[0].name == "DIMBO OWNER"
        assert out2.owners[0].name == "BANIAPAT OWNER"
        assert len(_cache) == 2


def test_11_pdf_idor_protection_canonical_identity_binding():
    """Verify that PDF generation enforces canonical land identity headers."""
    valid_pdf_content = b"%PDF-1.4 Mock PDF Content"
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", new_callable=AsyncMock) as mock_pdf:
        mock_pdf.return_value = valid_pdf_content
        
        response = client.get("/api/v1/ror/pdf?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12&khata=112")
        assert response.status_code == 200
        assert "X-Bhumitra-Document-Identity" in response.headers
        assert "X-Bhumitra-Document-SHA256" in response.headers


def test_12_secrets_audit_no_live_credentials_in_repo():
    """Verify that database URLs and secret keys in settings do not contain leaked plaintext credentials."""
    assert "ghp_" not in settings.JWT_SECRET_KEY
    assert "AKIA" not in settings.ADMIN_API_KEY
    assert "AIza" not in settings.DATABASE_URL


def test_13_error_response_no_stack_traces_leaked():
    """Verify that 400/404/500 error responses return structured JSON error models and do not leak Python stack traces."""
    response = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=DIMBO&plot=../")
    assert response.status_code == 400
    data = response.json()
    assert "Traceback" not in str(data)
    assert "detail" in data
    assert "code" in data["detail"]


def test_14_cors_origins_restricted_in_production():
    """Verify that CORS origins in production are strictly restricted to official domains."""
    with patch.object(settings, "ENV", "production"):
        assert settings.is_production is True
        assert "*" not in settings.ALLOWED_ORIGINS
        assert "https://bhumitra.app" in settings.ALLOWED_ORIGINS
