import pytest
from unittest.mock import patch, AsyncMock
from services.ror_service import RoRService, RoRServiceException, RoRErrorCode, _cache
from models.ror_response import RoRResponse, OwnerEntry, RoRVerification, RoRVerificationStatus
from scrapers.bhulekh_scraper import BhulekhScraper


@pytest.mark.anyio
async def test_exact_bug_anugul_kahnupur_plot_116_no_fake_fallback_on_unreachable():
    """
    CRITICAL REGRESSION TEST:
    Target Parcel: Anugul / Athmallik / Kahnupur / Plot 116.
    When the live Bhulekh portal is unreachable or scrape fails,
    the system MUST NOT generate synthetic fake data (e.g., Trilochan Panda, Khatian 302).
    It MUST raise an honest unavailable or not found exception.
    """
    scraper = BhulekhScraper()

    with patch.object(scraper, "_scrape", side_effect=ConnectionError("Network unreachable")):
        with pytest.raises(Exception) as exc_info:
            await scraper.fetch_ror(
                district="ANUGUL",
                tahasil="ATHMALLIK",
                village="KAHNUPUR",
                plot="116",
            )
        
        # Verify no fake Trilochan Panda response was returned
        assert "Trilochan" not in str(exc_info.value)
        assert "Panda" not in str(exc_info.value)


@pytest.mark.anyio
async def test_exact_bug_anugul_kahnupur_plot_116_service_layer_rejects_fake_response():
    """
    Validates that the service layer (RoRService.get_ror) does not return a fake AVAILABLE response
    when upstream fails.
    """
    ror_service = RoRService()

    with patch.object(BhulekhScraper, "fetch_ror", side_effect=ConnectionError("Portal unreachable")):
        with pytest.raises(RoRServiceException) as exc_info:
            await ror_service.get_ror(
                district="ANUGUL",
                tahasil="ATHMALLIK",
                village="KAHNUPUR",
                plot="116",
            )
        
        assert exc_info.value.code in (
            RoRErrorCode.BHULEKH_TEMPORARY_UNAVAILABLE,
            RoRErrorCode.BHULEKH_TIMEOUT,
            RoRErrorCode.ROR_NOT_FOUND,
        )
        assert exc_info.value.retryable is True


@pytest.mark.anyio
async def test_mismatched_response_plot_rejected():
    """
    Validates that if an upstream response returns an unrelated plot identity,
    it cannot be cached or returned as a verified record.
    """
    ror_service = RoRService()
    
    # Simulate an upstream return with wrong plot (999 instead of 116)
    mismatched_response = RoRResponse(
        success=True,
        plot="999",  # WRONG PLOT
        village="KAHNUPUR",
        district="ANUGUL",
        tahasil="ATHMALLIK",
        khata_number="302",
        area="0.50 Acre",
        owners=[OwnerEntry(name="Trilochan Panda")],
        verification=RoRVerification(
            status=RoRVerificationStatus.MISMATCH,
            requested_district="ANUGUL",
            requested_tahasil="ATHMALLIK",
            requested_village="KAHNUPUR",
            requested_plot="116",
            returned_district="ANUGUL",
            returned_tahasil="ATHMALLIK",
            returned_village="KAHNUPUR",
            returned_plot="999",
            location_match=True,
            plot_match=False,
            details="Plot mismatch detected",
        ),
    )

    with patch.object(BhulekhScraper, "fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.return_value = mismatched_response
        
        # RoRService must NOT cache mismatched response
        with patch.dict(_cache, {}, clear=True):
            res = await ror_service.get_ror(
                district="ANUGUL",
                tahasil="ATHMALLIK",
                village="KAHNUPUR",
                plot="116",
            )
            # Response verification must NOT be VERIFIED
            assert res.verification is not None
            assert res.verification.status != RoRVerificationStatus.VERIFIED
            # Must NOT be stored in verified cache
            assert len(_cache) == 0
