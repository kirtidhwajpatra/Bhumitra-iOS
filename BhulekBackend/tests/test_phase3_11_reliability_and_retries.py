"""
Phase 3.11 Automated Test Suite: Reliability, Exponential Retries, SingleFlight Deduplication, and Error Taxonomy.
"""
import pytest
import asyncio
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient

from main import app
from models.ror_response import (
    RoRResponse,
    RoRVerification,
    RoRVerificationStatus,
    RoRErrorCode,
    OwnerEntry,
    AssociatedPlot,
)
from services.ror_service import RoRService, RoRServiceException, _cache, _pdf_cache, get_canonical_cache_key

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_caches():
    _cache.clear()
    _pdf_cache.clear()


@pytest.mark.anyio
async def test_1_retry_engine_exponential_backoff_on_transient_failures():
    """Verify that transient network errors trigger retries with exponential backoff up to max attempts."""
    ror_service = RoRService()
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
        # First 2 attempts fail with transient connection error, 3rd succeeds
        verified_resp = RoRResponse(
            success=True,
            plot="12",
            village="Dimbo",
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            owners=[OwnerEntry(name="Test Owner", share="1.0", khata_number="112")],
            plots=[AssociatedPlot(plot_number="12", area="0.41 Acre")],
            verification=RoRVerification(
                status=RoRVerificationStatus.VERIFIED,
                requested_district="KEONJHAR",
                requested_tahasil="KEONJHAR SADAR",
                requested_village="Dimbo",
                requested_plot="12",
                location_match=True,
                plot_match=True,
                details="Verified",
            )
        )
        mock_fetch.side_effect = [
            ConnectionError("Upstream connection reset"),
            asyncio.TimeoutError("Upstream gateway timeout"),
            verified_resp
        ]
        
        res = await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
        assert res.success is True
        assert res.plot == "12"
        assert mock_fetch.call_count == 3


@pytest.mark.anyio
async def test_2_no_retry_on_permanent_not_found():
    """Verify that permanent 'not found' errors fail-closed immediately without retrying."""
    ror_service = RoRService()
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.side_effect = ValueError("Plot number '9999' could not be verified in official Bhulekh records for village 'Dimbo'.")
        
        with pytest.raises(RoRServiceException) as exc_info:
            await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "9999")
            
        assert exc_info.value.code == RoRErrorCode.ROR_NOT_FOUND
        assert exc_info.value.retryable is False
        # Must fail immediately on attempt 1
        assert mock_fetch.call_count == 1


@pytest.mark.anyio
async def test_3_no_retry_on_identity_mismatch():
    """Verify that identity mismatch errors fail-closed immediately without retrying."""
    ror_service = RoRService()
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.side_effect = ValueError("Plot mismatch: Requested plot '12', but portal returned plot '120'.")
        
        with pytest.raises(RoRServiceException) as exc_info:
            await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
            
        assert exc_info.value.code == RoRErrorCode.ROR_IDENTITY_MISMATCH
        assert exc_info.value.retryable is False
        assert mock_fetch.call_count == 1


@pytest.mark.anyio
async def test_4_single_flight_coalescing_prevents_duplicate_scrapes():
    """Verify that simultaneous duplicate queries coalesce onto a single in-flight scrape."""
    ror_service = RoRService()
    
    verified_resp = RoRResponse(
        success=True,
        plot="460",
        village="Dimbo",
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        owners=[OwnerEntry(name="Verified Owner", share="1.0", khata_number="50")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED,
            requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR",
            requested_village="Dimbo",
            requested_plot="460",
            location_match=True,
            plot_match=True,
            details="Verified",
        )
    )
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
        async def delayed_fetch(*args, **kwargs):
            await asyncio.sleep(0.1)
            return verified_resp
            
        mock_fetch.side_effect = delayed_fetch
        
        # Fire 5 concurrent requests for the exact same plot
        tasks = [
            ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "460")
            for _ in range(5)
        ]
        results = await asyncio.gather(*tasks)
        
        assert len(results) == 5
        for r in results:
            assert r.plot == "460"
        
        # Scraper should have executed only ONCE!
        assert mock_fetch.call_count == 1


def test_5_exact_identity_string_immutability():
    """Verify that special plot formats survive as strict strings."""
    special_plots = ["12", "120", "12/1", "12A", "0012", "12/1A", "12-1"]
    for p in special_plots:
        key = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "Dimbo", p)
        assert isinstance(key, str)
        assert len(key) == 64


def test_6_endpoint_error_taxonomy_404_not_found():
    """Verify that ROR_NOT_FOUND produces structured 404 response."""
    with patch("services.ror_service.RoRService.get_ror", new_callable=AsyncMock) as mock_get:
        mock_get.side_effect = RoRServiceException(
            code=RoRErrorCode.ROR_NOT_FOUND,
            message="No official RoR record found for plot '9999'.",
            retryable=False,
        )
        response = client.get("/api/v1/ror?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=9999")
        assert response.status_code == 404
        data = response.json()
        assert data["detail"]["code"] == "ROR_NOT_FOUND"
        assert data["detail"]["retryable"] is False


def test_7_endpoint_error_taxonomy_503_temporary_unavailable():
    """Verify that BHULEKH_TEMPORARY_UNAVAILABLE produces structured 503 response."""
    with patch("services.ror_service.RoRService.get_ror", new_callable=AsyncMock) as mock_get:
        mock_get.side_effect = RoRServiceException(
            code=RoRErrorCode.BHULEKH_TEMPORARY_UNAVAILABLE,
            message="Official Bhulekh service is temporarily unavailable.",
            retryable=True,
        )
        response = client.get("/api/v1/ror?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12")
        assert response.status_code == 503
        data = response.json()
        assert data["detail"]["code"] == "BHULEKH_TEMPORARY_UNAVAILABLE"
        assert data["detail"]["retryable"] is True


def test_8_endpoint_error_taxonomy_422_identity_mismatch():
    """Verify that ROR_IDENTITY_MISMATCH produces structured 422 response."""
    with patch("services.ror_service.RoRService.get_ror", new_callable=AsyncMock) as mock_get:
        mock_get.side_effect = RoRServiceException(
            code=RoRErrorCode.ROR_IDENTITY_MISMATCH,
            message="Official record could not be verified.",
            retryable=False,
        )
        response = client.get("/api/v1/ror?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=Dimbo&plot=12")
        assert response.status_code == 422
        data = response.json()
        assert data["detail"]["code"] == "ROR_IDENTITY_MISMATCH"
        assert data["detail"]["retryable"] is False


@pytest.mark.anyio
async def test_9_pdf_failure_distinct_from_ror():
    """Verify that PDF generation failure is distinct and retries independently."""
    ror_service = RoRService()
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", new_callable=AsyncMock) as mock_pdf:
        mock_pdf.side_effect = [
            Exception("Transient timeout generating PDF"),
            b"%PDF-1.4 Mock Valid PDF Data"
        ]
        
        pdf_bytes = await ror_service.get_ror_pdf("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
        assert pdf_bytes.startswith(b"%PDF-1.4")
        assert mock_pdf.call_count == 2
