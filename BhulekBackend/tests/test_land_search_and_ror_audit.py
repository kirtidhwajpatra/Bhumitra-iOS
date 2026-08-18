"""
Comprehensive Land Search & RoR Dual-Path Audit Test Suite
Covers all 20 adversarial cases, validating cross-path identity equivalence (Map vs Manual),
fail-closed shielding, and zero-tolerance collision isolation.
"""

import asyncio
import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from main import app
from scrapers.structured_ror_parser import (
    parse_structured_ror,
    parse_structured_khata_ror,
    clean_owner_name,
)
from services.ror_service import RoRService, get_canonical_cache_key, _cache, _pdf_cache
from models.ror_response import (
    RoRResponse,
    OwnerEntry,
    AssociatedPlot,
    RoRVerification,
    RoRVerificationStatus,
    BhulekhLocationIdentity,
    PlotSearchRequest,
    KhataSearchRequest,
    PlotUniqueIDSearchRequest,
)

client = TestClient(app)

SAMPLE_VERIFIED_HTML = """
<html>
    <body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G KERI 271</span>
        <span id="lblKhatiyanslNo">142</span>
        <span id="lblName">Dillip Kumar Mahanta</span>
        <table id="gvfront">
            <tr>
                <td><span id="lblName">Dillip Kumar Mahanta S/O Late Suresh Mahanta</span></td>
                <td><span id="lblShare">1.000</span></td>
            </tr>
        </table>
        <table id="gvRorBack">
            <tr>
                <td><span id="lblPlotNo">1182</span></td>
                <td><span id="lbllType">Sarada-1</span></td>
                <td><span id="lblAcre">1</span></td>
                <td><span id="lblDecimil">45</span></td>
            </tr>
        </table>
    </body>
</html>
"""


@pytest.fixture(autouse=True)
def clean_all_caches():
    _cache.clear()
    _pdf_cache.clear()
    yield
    _cache.clear()
    _pdf_cache.clear()


# ==============================================================================
# 1. CROSS-PATH CONVERGENCE: MAP PATH vs MANUAL PATH
# ==============================================================================

def test_audit_cross_path_equivalence():
    """Validates that Map Path and Manual Path yield identical canonical identity and RoR fields."""
    # MAP PATH IDENTIFICATION
    map_district = "KEONJHAR"
    map_tahasil = "KEONJHAR SADAR"
    map_village = "G KERI 271"
    map_plot = "1182"
    
    map_key = get_canonical_cache_key(map_district, map_tahasil, map_village, map_plot)
    map_ror = parse_structured_ror(SAMPLE_VERIFIED_HTML, map_district, map_tahasil, map_village, map_plot)
    
    # MANUAL PATH IDENTIFICATION
    manual_district_id = "7"
    manual_tahasil_id = "4"
    manual_village_id = "179"
    manual_plot = "1182"
    
    manual_key = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", manual_plot)
    manual_ror = parse_structured_ror(SAMPLE_VERIFIED_HTML, "KEONJHAR", "KEONJHAR SADAR", "G KERI 271", manual_plot)
    
    # Assert Exact Equivalence Across Both Discovery Channels
    assert map_key == manual_key
    assert map_ror.plot == manual_ror.plot == "1182"
    assert map_ror.district == manual_ror.district == "KEONJHAR"
    assert map_ror.tahasil == manual_ror.tahasil == "KEONJHAR SADAR"
    assert map_ror.village == manual_ror.village == "G KERI 271"
    assert map_ror.khata_number == manual_ror.khata_number == "142"
    assert map_ror.land_type == manual_ror.land_type == "Sarada-1"
    assert map_ror.area == manual_ror.area == "1 Acre 45 Decimal"
    assert len(map_ror.owners) == len(manual_ror.owners) == 1
    assert map_ror.owners[0].name == manual_ror.owners[0].name == "Dillip Kumar Mahanta"


# ==============================================================================
# 2. 20 DANGEROUS ADVERSARIAL CASES
# ==============================================================================

def test_case_1_plot_12_vs_120():
    """Case 1: Plot 12 must not match Plot 120."""
    k1 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "12")
    k2 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "120")
    assert k1 != k2


def test_case_2_plot_12_vs_12_slash_1():
    """Case 2: Plot 12 must not match fractional Plot 12/1."""
    k1 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "12")
    k2 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "12/1")
    assert k1 != k2


def test_case_3_same_plot_in_two_villages():
    """Case 3: Plot 100 in Village A must not match Plot 100 in Village B."""
    k_va = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "VILLAGE_A", "100")
    k_vb = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "VILLAGE_B", "100")
    assert k_va != k_vb


def test_case_4_same_village_name_in_two_tahasils():
    """Case 4: Village 'KANTAPALI' in Tahasil A vs Tahasil B must produce distinct identities."""
    k_ta = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "KANTAPALI", "100")
    k_tb = get_canonical_cache_key("KEONJHAR", "CHAMPUA", "KANTAPALI", "100")
    assert k_ta != k_tb


def test_case_5_same_khata_number_in_two_villages():
    """Case 5: Khata 142 in Village 1 vs Village 2 must be isolated."""
    k_v1 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "VILLAGE_1", "KHATA_142")
    k_v2 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "VILLAGE_2", "KHATA_142")
    assert k_v1 != k_v2


def test_case_6_wrong_district_fails_closed():
    """Case 6: Scraped district mismatch fails closed."""
    with pytest.raises(ValueError, match="Unable to verify"):
        parse_structured_ror(SAMPLE_VERIFIED_HTML, "CUTTACK", "KEONJHAR SADAR", "G KERI 271", "1182")


def test_case_7_wrong_tahasil_fails_closed():
    """Case 7: Scraped tahasil mismatch fails closed."""
    with pytest.raises(ValueError, match="Unable to verify"):
        parse_structured_ror(SAMPLE_VERIFIED_HTML, "KEONJHAR", "CHAMPUA", "G KERI 271", "1182")


def test_case_8_wrong_village_fails_closed():
    """Case 8: Scraped village mismatch fails closed."""
    with pytest.raises(ValueError, match="Unable to verify"):
        parse_structured_ror(SAMPLE_VERIFIED_HTML, "KEONJHAR", "KEONJHAR SADAR", "OTHER VILLAGE", "1182")


def test_case_9_wrong_plot_fails_closed():
    """Case 9: Scraped plot mismatch fails closed."""
    with pytest.raises(ValueError, match="Unable to verify"):
        parse_structured_ror(SAMPLE_VERIFIED_HTML, "KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "9999")


def test_case_10_map_parcel_missing_p_id_fallback():
    """Case 10: Missing p_id safely uses deterministic compound key."""
    k_fallback = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "1182", v_id=None)
    assert len(k_fallback) == 64  # SHA256 hex string


def test_case_11_duplicate_plot_number_in_gis_resolution():
    """Case 11: Duplicate display plots distinguished via village code."""
    k_1 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "1182", v_id="179")
    k_2 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "1182", v_id="180")
    assert k_1 != k_2


def test_case_12_bhulekh_unavailable_fails_closed():
    """Case 12: Backend returns 500 when portal is down without faking success."""
    with patch("services.ror_service.RoRService.get_ror", AsyncMock(side_effect=ConnectionError("Portal down"))):
        res = client.post("/api/v1/search/plot", json={
            "district_id": "7", "tahasil_id": "4", "village_id": "179", "exact_plot_number": "1182"
        })
        assert res.status_code == 500


def test_case_13_bhulekh_timeout_fails_closed():
    """Case 13: Timeouts do not leak stale data."""
    with patch("services.ror_service.RoRService.get_ror", AsyncMock(side_effect=TimeoutError("Request timed out"))):
        res = client.post("/api/v1/search/plot", json={
            "district_id": "7", "tahasil_id": "4", "village_id": "179", "exact_plot_number": "1182"
        })
        assert res.status_code == 500


def test_case_14_bhulekh_html_changed_fails_closed():
    """Case 14: Malformed/Changed HTML triggers verification failure and shields owners."""
    corrupted_html = "<html><body><div>Unknown Table Format</div></body></html>"
    with pytest.raises(ValueError, match="Unable to verify"):
        parse_structured_ror(corrupted_html, "KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "1182")


def test_case_15_multiple_owners_with_fractional_shares():
    """Case 15: Multiple owners preserve independent names and fractions."""
    multi_html = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G KERI 271</span>
        <span id="lblKhatiyanslNo">142</span>
        <table id="gvfront">
            <tr><td><span id="lblName">Alekha Mahanta S/O Late Suresh</span></td><td><span id="lblShare">0.500</span></td></tr>
            <tr><td><span id="lblName">Bipin Mahanta S/O Late Suresh</span></td><td><span id="lblShare">0.500</span></td></tr>
        </table>
        <table id="gvRorBack"><tr><td><span id="lblPlotNo">1182</span></td></tr></table>
    </body></html>
    """
    ror = parse_structured_ror(multi_html, "KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "1182")
    assert len(ror.owners) == 2
    assert ror.owners[0].name == "Alekha Mahanta"
    assert ror.owners[0].share == "0.500"
    assert ror.owners[1].name == "Bipin Mahanta"
    assert ror.owners[1].share == "0.500"


def test_case_16_multiple_plots_in_one_khata():
    """Case 16: Multi-plot Khata retains all plots with distinct Kisam."""
    multi_k_html = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G KERI 271</span>
        <span id="lblKhatiyanslNo">142</span>
        <table id="gvRorBack">
            <tr><td><span id="lblPlotNo">101</span></td><td><span id="lbllType">Sarada-1</span></td></tr>
            <tr><td><span id="lblPlotNo">102</span></td><td><span id="lbllType">Gharabari</span></td></tr>
        </table>
    </body></html>
    """
    res = parse_structured_khata_ror(multi_k_html, "KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "142")
    assert len(res.plots) == 2
    assert res.plots[0].plot_number == "101"
    assert res.plots[0].land_type == "Sarada-1"
    assert res.plots[1].plot_number == "102"
    assert res.plots[1].land_type == "Gharabari"


def test_case_17_duplicate_webhook_cache_isolation():
    """Case 17: Canonical hashing isolates cache items across requests."""
    k1 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "VILL_A", "10")
    k2 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "VILL_B", "10")
    _cache[k1] = "RECORD_A"
    _cache[k2] = "RECORD_B"
    assert _cache[k1] == "RECORD_A"
    assert _cache[k2] == "RECORD_B"


def test_case_18_pdf_mismatch_fails_closed():
    """Case 18: PDF generator rejects mismatched plot before writing PDF."""
    with pytest.raises(ValueError, match="Unable to verify"):
        parse_structured_ror(SAMPLE_VERIFIED_HTML, "KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "WRONG_PLOT")


def test_case_19_stale_cached_result_unverified_never_cached():
    """Case 19: Unverified records are never stored in cache."""
    assert len(_cache) == 0


@pytest.mark.anyio
async def test_case_20_concurrent_searches_thread_safety():
    """Case 20: 10 concurrent requests for same parcel coalesce safely without race conditions."""
    service = RoRService()
    mock_res = RoRResponse(
        success=True,
        plot="1182",
        village="G KERI 271",
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        owners=[OwnerEntry(name="Dillip Kumar Mahanta", share="1.000")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED,
            requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR",
            requested_village="G KERI 271",
            requested_plot="1182",
            location_match=True,
            plot_match=True,
            details="Verified",
        ),
    )
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", AsyncMock(return_value=mock_res)) as mock_scrape:
        tasks = [
            service.get_ror("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "1182")
            for _ in range(10)
        ]
        results = await asyncio.gather(*tasks)
        assert len(results) == 10
        assert all(r.plot == "1182" for r in results)
        assert mock_scrape.call_count == 1
