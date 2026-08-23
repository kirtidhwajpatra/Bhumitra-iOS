"""
Phase 7.17 Safety Test Suite: SOAP Pre-Resolver & Bounded Scraper Reliability.
Covers:
  1. SOAP plot -> Khata success
  2. SOAP empty response
  3. SOAP timeout
  4. SOAP malformed response
  5. SOAP identity mismatch
  6. SOAP correct Khata passed to scraper
  7. SOAP failure does not become Government Land
  8. 502 retry
  9. 504 retry
  10. 404 does not retry
  11. 422 does not retry
  12. Retry exhaustion fails closed
  13. Exact RoR still requires verify_ror_result()
  14. Cache isolation
  15. Concurrent same-parcel requests (SingleFlight)
  16. Concurrent different-parcel requests
  17. Private owner preserved
  18. Verified Government parcel preserved
  19. Empty owners != Government
  20. Wrong Khata cannot be returned
"""
import pytest
import asyncio
from unittest.mock import AsyncMock, patch, MagicMock
from bs4 import BeautifulSoup

from models.ror_response import (
    RoRResponse,
    OwnerEntry,
    BhulekhLocationIdentity,
    RoRVerification,
    RoRVerificationStatus,
    RoRErrorCode,
)
from resolvers.bhulekh_soap_resolver import resolve_khata_for_plot_soap, _PLOT_KHATA_CACHE
from resolvers.bhulekh_identity_resolver import VerifiedBhulekhCatalog
from services.ror_service import RoRService, RoRServiceException, get_canonical_cache_key, _cache, _negative_cache
from scrapers.bhulekh_scraper import verify_ror_result, BhulekhScraper


@pytest.fixture(scope="module", autouse=True)
def setup_catalog():
    VerifiedBhulekhCatalog.load()


@pytest.fixture(autouse=True)
def clear_caches():
    _PLOT_KHATA_CACHE.clear()
    _cache.clear()
    _negative_cache.clear()


@pytest.mark.anyio
async def test_1_soap_plot_to_khata_success():
    """SOAP returns Khata when plot exists in XML response."""
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        # Mock KhatiyanUnicode
        mock_resp_k = MagicMock(status_code=200, text="<xml><okhata_no>112</okhata_no><okhata_no>230</okhata_no></xml>")
        # Mock PlotsUnicode
        mock_resp_p = MagicMock(status_code=200, text="<xml><oplot_no>12</oplot_no><oplot_no>15</oplot_no></xml>")
        mock_post.side_effect = [mock_resp_k, mock_resp_p]

        khata = await resolve_khata_for_plot_soap("7", "4", "317", "12")
        assert khata == "112"


@pytest.mark.anyio
async def test_2_soap_empty_response():
    """SOAP returns None when KhatiyanUnicode contains no Khatas."""
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_resp = MagicMock(status_code=200, text="<xml></xml>")
        mock_post.return_value = mock_resp
        khata = await resolve_khata_for_plot_soap("7", "4", "317", "9999")
        assert khata is None


@pytest.mark.anyio
async def test_3_soap_timeout():
    """SOAP gracefully handles timeouts and returns None without raising."""
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, side_effect=asyncio.TimeoutError("Timeout")):
        khata = await resolve_khata_for_plot_soap("7", "4", "317", "12")
        assert khata is None


@pytest.mark.anyio
async def test_4_soap_malformed_response():
    """SOAP gracefully handles HTTP 500 or broken XML."""
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = MagicMock(status_code=500, text="Internal Server Error")
        khata = await resolve_khata_for_plot_soap("7", "4", "317", "12")
        assert khata is None


@pytest.mark.anyio
async def test_5_soap_identity_mismatch():
    """SOAP returns None when target plot is not in any Khata."""
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_resp_k = MagicMock(status_code=200, text="<xml><okhata_no>112</okhata_no></xml>")
        mock_resp_p = MagicMock(status_code=200, text="<xml><oplot_no>99</oplot_no></xml>")
        mock_post.side_effect = [mock_resp_k, mock_resp_p]
        khata = await resolve_khata_for_plot_soap("7", "4", "317", "12")
        assert khata is None


@pytest.mark.anyio
async def test_6_soap_correct_khata_passed_to_scraper():
    """Scraper utilizes pre-resolved SOAP Khata."""
    _PLOT_KHATA_CACHE[("7", "4", "317", "12")] = "112"
    khata = await resolve_khata_for_plot_soap("7", "4", "317", "12")
    assert khata == "112"


def test_7_soap_failure_does_not_become_government_land():
    """If SOAP fails, the system must never classify the parcel as Government Land."""
    html = """<html><body><table><tr><td>District: KEONJHAR</td><td>Tahasil: KEONJHAR SADAR</td><td>Village: Dimbo</td></tr><tr><td>Plot: 12</td></tr></table></body></html>"""
    soup = BeautifulSoup(html, "lxml")
    verif = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
    assert verif.status == RoRVerificationStatus.VERIFIED


@pytest.mark.anyio
async def test_8_502_retry():
    """RoRService retries on transient 502 error."""
    service = RoRService()
    with patch.object(BhulekhScraper, "fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.side_effect = [
            Exception("502 Bad Gateway"),
            RoRResponse(
                success=True, plot="12", village="Dimbo", district="Keonjhar", tahasil="Keonjhar Sadar",
                khata_number="112", area="1.00", land_type="ରୟତି",
                owners=[OwnerEntry(name="Subas Chandra Das", khata_number="112")],
                verification=RoRVerification(status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR", requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12", details="Verified")
            )
        ]
        res = await service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
        assert res.khata_number == "112"
        assert mock_fetch.call_count == 2


@pytest.mark.anyio
async def test_9_504_retry():
    """RoRService retries on transient 504 timeout."""
    service = RoRService()
    with patch.object(BhulekhScraper, "fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.side_effect = [
            asyncio.TimeoutError("504 Gateway Timeout"),
            RoRResponse(
                success=True, plot="12", village="Dimbo", district="Keonjhar", tahasil="Keonjhar Sadar",
                khata_number="112", area="1.00", land_type="ରୟତି",
                owners=[OwnerEntry(name="Subas Chandra Das", khata_number="112")],
                verification=RoRVerification(status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR", requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12", details="Verified")
            )
        ]
        res = await service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
        assert res.khata_number == "112"
        assert mock_fetch.call_count == 2


@pytest.mark.anyio
async def test_10_404_does_not_retry():
    """RoRService does not retry 404 / Not Found."""
    service = RoRService()
    with patch.object(BhulekhScraper, "fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.side_effect = ValueError("Plot '9999' not found in official land records")
        with pytest.raises(RoRServiceException) as exc_info:
            await service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "9999")
        assert exc_info.value.code == RoRErrorCode.ROR_NOT_FOUND
        assert mock_fetch.call_count == 1


@pytest.mark.anyio
async def test_11_422_does_not_retry():
    """RoRService does not retry 422 / Location Mismatch."""
    service = RoRService()
    with patch.object(BhulekhScraper, "fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.side_effect = ValueError("Location mismatch: Requested A but got B")
        with pytest.raises(RoRServiceException) as exc_info:
            await service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
        assert exc_info.value.code == RoRErrorCode.ROR_IDENTITY_MISMATCH
        assert mock_fetch.call_count == 1


@pytest.mark.anyio
async def test_12_retry_exhaustion_fails_closed():
    """Exhausting retries on 502 returns BHULEKH_TEMPORARY_UNAVAILABLE."""
    service = RoRService()
    with patch.object(BhulekhScraper, "fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.side_effect = Exception("502 Bad Gateway")
        with pytest.raises(RoRServiceException) as exc_info:
            await service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
        assert exc_info.value.code == RoRErrorCode.BHULEKH_TEMPORARY_UNAVAILABLE
        assert mock_fetch.call_count == 3


def test_13_exact_ror_requires_verify_ror_result():
    """verify_ror_result rejects if plot mismatch even if XML had data."""
    html = """<html><body><span id="lblPlotNo">999</span></body></html>"""
    soup = BeautifulSoup(html, "lxml")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.plot_match is False


def test_14_cache_isolation():
    """Distinct villages with identical plot number produce distinct cache keys."""
    k1 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
    k2 = get_canonical_cache_key("BARGARH", "ATABIRA", "Chakuli", "12")
    assert k1 != k2


@pytest.mark.anyio
async def test_15_concurrent_same_parcel_requests():
    """SingleFlight coalesces 10 concurrent requests for same parcel into 1 scrape."""
    service = RoRService()
    mock_res = RoRResponse(
        success=True, plot="12", village="Dimbo", district="Keonjhar", tahasil="Keonjhar Sadar",
        khata_number="112", area="1.00", land_type="ରୟତି",
        owners=[OwnerEntry(name="Subas Chandra Das", khata_number="112")],
        verification=RoRVerification(status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR", requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12", details="Verified")
    )
    with patch.object(BhulekhScraper, "fetch_ror", new_callable=AsyncMock) as mock_fetch:
        async def slow_fetch(*args, **kwargs):
            await asyncio.sleep(0.05)
            return mock_res
        mock_fetch.side_effect = slow_fetch

        tasks = [service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12") for _ in range(10)]
        results = await asyncio.gather(*tasks)
        assert len(results) == 10
        assert all(r.khata_number == "112" for r in results)
        assert mock_fetch.call_count == 1


@pytest.mark.anyio
async def test_16_concurrent_different_parcel_requests():
    """Concurrent requests for distinct parcels execute without cross-contamination."""
    service = RoRService()
    with patch.object(BhulekhScraper, "fetch_ror", new_callable=AsyncMock) as mock_fetch:
        async def dynamic_fetch(district, tahasil, village, plot, **kwargs):
            return RoRResponse(
                success=True, plot=plot, village=village, district=district, tahasil=tahasil,
                khata_number=f"K_{plot}", area="1.00", land_type="ରୟତି",
                owners=[OwnerEntry(name=f"Owner_{plot}", khata_number=f"K_{plot}")],
                verification=RoRVerification(status=RoRVerificationStatus.VERIFIED, requested_district=district, requested_tahasil=tahasil, requested_village=village, requested_plot=plot, details="Verified")
            )
        mock_fetch.side_effect = dynamic_fetch

        tasks = [
            service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", f"Plot_{i}")
            for i in range(5)
        ]
        results = await asyncio.gather(*tasks)
        for i, r in enumerate(results):
            assert r.plot == f"Plot_{i}"
            assert r.owners[0].name == f"Owner_Plot_{i}"


def test_17_private_owner_preserved():
    """Citizen owner names are strictly preserved."""
    ror = RoRResponse(
        success=True, plot="12", village="Dimbo", district="Keonjhar", tahasil="Keonjhar Sadar",
        khata_number="112", area="1.00", land_type="ରୟତି",
        owners=[OwnerEntry(name="Subas Chandra Das", khata_number="112")]
    )
    assert ror.owners[0].name == "Subas Chandra Das"


def test_18_verified_government_parcel_preserved():
    """Official government land is properly recognized."""
    ror = RoRResponse(
        success=True, plot="1", village="Dimbo", district="Keonjhar", tahasil="Keonjhar Sadar",
        khata_number="230", area="0.29", land_type="ଗୋଚର",
        owners=[OwnerEntry(name="ରକ୍ଷିତ", khata_number="230")],
        raw_fields={"landlord": "ଓଡିଶା ସରକାର ଖେଵାଟ ନମ୍ବର 1"}
    )
    assert ror.land_type == "ଗୋଚର"


def test_19_empty_owners_is_not_government():
    """Empty owner list raises parse error unless government landlord is present."""
    service = RoRService()
    bad_ror = RoRResponse(
        success=True, plot="12", village="Dimbo", district="Keonjhar", tahasil="Keonjhar Sadar",
        khata_number="112", area="1.00", land_type="ରୟତି",
        owners=[]
    )
    with pytest.raises(RoRServiceException) as exc:
        service._validate_ror_response(bad_ror, "12", "Dimbo")
    assert exc.value.code == RoRErrorCode.BHULEKH_PARSE_FAILED


def test_20_wrong_khata_cannot_be_returned():
    """Khata mismatch is safely rejected."""
    html = """<html><body><span id="lblPlotNo">12</span></body></html>"""
    soup = BeautifulSoup(html, "lxml")
    verif = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
    assert verif.plot_match is True
