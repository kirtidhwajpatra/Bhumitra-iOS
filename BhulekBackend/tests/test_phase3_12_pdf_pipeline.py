"""
Phase 3.12 Automated Test Suite: Production-Grade RoR PDF / Document Pipeline.
"""
import pytest
import hashlib
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from main import app
from models.ror_response import RoRErrorCode
from services.ror_service import RoRService, RoRServiceException, _pdf_cache

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_pdf_cache():
    _pdf_cache.clear()


@pytest.mark.anyio
async def test_1_valid_pdf_generation_returns_pdf_bytes_and_correct_headers():
    """Verify that a valid PDF with %PDF- signature generates HTTP 200 with checksum and document identity headers."""
    valid_pdf_content = b"%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF"
    expected_sha256 = hashlib.sha256(valid_pdf_content).hexdigest()
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", new_callable=AsyncMock) as mock_pdf:
        mock_pdf.return_value = valid_pdf_content
        
        response = client.get("/api/v1/ror/pdf?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12&khata=112")
        assert response.status_code == 200
        assert response.headers["Content-Type"] == "application/pdf"
        assert response.headers["X-Bhumitra-Document-SHA256"] == expected_sha256
        assert "X-Bhumitra-Document-Identity" in response.headers
        assert response.headers["X-Bhumitra-Verified-Plot"] == "12"
        assert response.content.startswith(b"%PDF-")


@pytest.mark.anyio
async def test_2_html_returned_with_200_is_rejected_as_pdf_download_failed():
    """Verify that HTML error pages disguised as PDFs are strictly rejected."""
    html_error_page = b"<!DOCTYPE html><html><body><h1>Service Temporarily Unavailable</h1></body></html>"
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", new_callable=AsyncMock) as mock_pdf:
        mock_pdf.return_value = html_error_page
        
        response = client.get("/api/v1/ror/pdf?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12")
        assert response.status_code == 502
        data = response.json()
        assert data["detail"]["code"] == "PDF_GENERATION_FAILED"
        assert data["detail"]["retryable"] is True


@pytest.mark.anyio
async def test_3_json_error_returned_with_200_is_rejected():
    """Verify that JSON error payloads returned as bytes are rejected."""
    json_error_blob = b'{"error": "Session expired", "code": 500}'
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", new_callable=AsyncMock) as mock_pdf:
        mock_pdf.return_value = json_error_blob
        
        response = client.get("/api/v1/ror/pdf?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12")
        assert response.status_code == 502
        data = response.json()
        assert data["detail"]["code"] == "PDF_GENERATION_FAILED"


@pytest.mark.anyio
async def test_4_empty_or_truncated_pdf_bytes_rejected():
    """Verify that empty or truncated bytes are rejected."""
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", new_callable=AsyncMock) as mock_pdf:
        mock_pdf.return_value = b""
        
        response = client.get("/api/v1/ror/pdf?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12")
        assert response.status_code == 502
        data = response.json()
        assert data["detail"]["code"] == "PDF_GENERATION_FAILED"


@pytest.mark.anyio
async def test_5_pdf_cache_isolation_by_canonical_identity():
    """Verify that identical plot numbers in different villages or tahasils have completely isolated PDF caches."""
    ror_service = RoRService()
    pdf_dimbo = b"%PDF-1.4 Dimbo Plot 12 Content"
    pdf_baniapat = b"%PDF-1.4 Baniapat Plot 12 Content"
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", new_callable=AsyncMock) as mock_pdf:
        mock_pdf.side_effect = [pdf_dimbo, pdf_baniapat]
        
        res1 = await ror_service.get_ror_pdf("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
        res2 = await ror_service.get_ror_pdf("KEONJHAR", "KEONJHAR SADAR", "Baniapat 270", "12")
        
        assert res1 == pdf_dimbo
        assert res2 == pdf_baniapat
        assert len(_pdf_cache) == 2


@pytest.mark.anyio
async def test_6_document_identity_and_sha256_header_contracts():
    """Verify that X-Bhumitra-Document-Identity is deterministic for a given parcel."""
    valid_pdf_content = b"%PDF-1.4 Sample Valid Data"
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", new_callable=AsyncMock) as mock_pdf:
        mock_pdf.return_value = valid_pdf_content
        
        resp1 = client.get("/api/v1/ror/pdf?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12&khata=112")
        resp2 = client.get("/api/v1/ror/pdf?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12&khata=112")
        
        assert resp1.headers["X-Bhumitra-Document-Identity"] == resp2.headers["X-Bhumitra-Document-Identity"]
        assert resp1.headers["X-Bhumitra-Document-SHA256"] == resp2.headers["X-Bhumitra-Document-SHA256"]
