"""
Phase 2 Test Suite: Exact Plot Verification, Plot-Level Association, & Cache Isolation
Tests canonical plot normalization, multi-plot Khata extraction, owner/classification leak prevention,
and zero-collision cache semantics across Odisha Bhulekh.
"""
import pytest
from bs4 import BeautifulSoup
from models.ror_response import (
    RoRResponse,
    RoRVerificationStatus,
    OwnerEntry,
    AssociatedPlot,
)
from resolvers.plot_normalizer import normalize_plot_number, is_exact_plot_match
from scrapers.bhulekh_scraper import verify_ror_result
from scrapers.structured_ror_parser import parse_structured_ror, parse_associated_plots
from services.ror_service import get_canonical_cache_key, _cache, _negative_cache, RoRService


# ==============================================================================
# 1. CANONICAL PLOT NORMALIZATION TESTS
# ==============================================================================

def test_1_plot_normalization_basic_and_whitespace():
    """Verify whitespace stripping and string cleanup."""
    assert normalize_plot_number(" 123 ") == "123"
    assert normalize_plot_number("\t456\n") == "456"
    assert normalize_plot_number(None) == ""
    assert normalize_plot_number("") == ""


def test_2_plot_normalization_odia_numerals():
    """Verify Odia numerals transliterate to ASCII digits."""
    assert normalize_plot_number("୦") == "0"
    assert normalize_plot_number("୧୨୩") == "123"
    assert normalize_plot_number("୪୫୬/୭୮") == "456/78"
    assert normalize_plot_number("୧୨୩/୧A") == "123/1A"


def test_3_plot_normalization_slash_and_hyphen_spacing():
    """Verify harmless whitespace around slashes/hyphens is normalized."""
    assert normalize_plot_number("12 / 1") == "12/1"
    assert normalize_plot_number("12 / 1 / A") == "12/1/A"
    assert normalize_plot_number("12 - A") == "12-A"
    assert normalize_plot_number("12 a") == "12A"


def test_4_plot_normalization_strict_inequality_guarantees():
    """Critical safety invariant: normalize_plot_number MUST NEVER equate distinct plots."""
    p_123 = normalize_plot_number("123")
    p_0123 = normalize_plot_number("0123")
    p_1234 = normalize_plot_number("1234")
    p_123_1 = normalize_plot_number("123/1")
    p_123_a = normalize_plot_number("123-A")
    p_9123 = normalize_plot_number("9123")

    # Distinct plots must remain distinct
    assert p_123 != p_0123
    assert p_123 != p_1234
    assert p_123 != p_123_1
    assert p_123 != p_123_a
    assert p_123 != p_9123
    assert not is_exact_plot_match("123", "0123")
    assert not is_exact_plot_match("123", "1234")
    assert not is_exact_plot_match("123", "123/1")
    assert not is_exact_plot_match("123", "123-A")


# ==============================================================================
# 2. FALSE MATCH NEGATIVE TESTS (AREA, CESS, DATES, KHATA, SUBSTRINGS)
# ==============================================================================

def test_5_false_match_area_does_not_satisfy_plot():
    """Area 123.00 must not satisfy requested Plot 123."""
    html = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G_Dimbo</span>
        <table>
            <tr><td>Area: 123.00</td><td>Cess: 45</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "123")
    assert v.plot_match is False
    assert v.status in (RoRVerificationStatus.MISMATCH, RoRVerificationStatus.INSUFFICIENT_DATA)


def test_6_false_match_cess_and_date_do_not_satisfy_plot():
    """Cess 123 and Date 12/3/2021 must not satisfy requested Plot 123."""
    html = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G_Dimbo</span>
        <table>
            <tr><td>Cess: 123</td><td>Date: 12/3/2021</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "123")
    assert v.plot_match is False
    assert v.status in (RoRVerificationStatus.MISMATCH, RoRVerificationStatus.INSUFFICIENT_DATA)


def test_7_false_match_khata_number_does_not_satisfy_plot():
    """Khata 123 must not satisfy requested Plot 123 when plot is 500."""
    html = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G_Dimbo</span>
        <span id="lblKhatiyanslNo">123</span>
        <table id="gvRorBack">
            <tr><td>500</td><td>Sarada</td><td>1</td><td>0</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "123")
    assert v.plot_match is False
    assert v.status in (RoRVerificationStatus.MISMATCH, RoRVerificationStatus.INSUFFICIENT_DATA)


def test_8_false_match_substring_plots_rejected():
    """Plots 1234 and 9123 must not satisfy requested Plot 123."""
    html = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G_Dimbo</span>
        <table id="gvRorBack">
            <tr><td>1234</td><td>Sarada</td><td>1</td><td>0</td></tr>
            <tr><td>9123</td><td>Sarada</td><td>2</td><td>0</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "123")
    assert v.plot_match is False
    assert v.status in (RoRVerificationStatus.MISMATCH, RoRVerificationStatus.INSUFFICIENT_DATA)


def test_9_exact_plot_field_satisfies_verification():
    """Actual Plot 123 in table satisfies verification cleanly."""
    html = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G_Dimbo</span>
        <table id="gvRorBack">
            <tr><td>123</td><td>Sarada-1</td><td>1</td><td>45</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "123")
    assert v.plot_match is True
    assert v.status == RoRVerificationStatus.VERIFIED


# ==============================================================================
# 3. MULTI-PLOT KHATA EXTRACTION & PLOT-LEVEL ASSOCIATION
# ==============================================================================

MULTI_PLOT_KHATA_HTML = """
<html><body>
    <span id="lblDistrictName">KEONJHAR</span>
    <span id="lblTahasilName">KEONJHAR SADAR</span>
    <span id="lblVillageName">G_Dimbo</span>
    <span id="lblKhatiyanslNo">250</span>
    <table id="gvfront">
        <tr><td><span id="lblName">Bipin Mahanta S/O Suresh</span></td><td><span id="lblShare">1.000</span></td></tr>
    </table>
    <table id="gvRorBack">
        <tr><td>101</td><td>Sarada-1</td><td>0</td><td>50</td></tr>
        <tr><td>102</td><td>Gharabari</td><td>0</td><td>25</td></tr>
        <tr><td>103</td><td>Taila-2</td><td>1</td><td>10</td></tr>
    </table>
</body></html>
"""

def test_10_multi_plot_khata_row_isolation():
    """Requesting Plot 102 selects Plot 102's exact land type and acreage."""
    ror_102 = parse_structured_ror(MULTI_PLOT_KHATA_HTML, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "102")
    assert ror_102.plot == "102"
    assert ror_102.land_type == "Gharabari"
    assert ror_102.area == "0 Acre 25 Decimal"
    assert ror_102.khata_number == "250"
    assert len(ror_102.plots) == 3

    # Requesting Plot 101 selects Plot 101's exact record
    ror_101 = parse_structured_ror(MULTI_PLOT_KHATA_HTML, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "101")
    assert ror_101.plot == "101"
    assert ror_101.land_type == "Sarada-1"
    assert ror_101.area == "0 Acre 50 Decimal"

    # Requesting Plot 103 selects Plot 103's exact record
    ror_103 = parse_structured_ror(MULTI_PLOT_KHATA_HTML, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "103")
    assert ror_103.plot == "103"
    assert ror_103.land_type == "Taila-2"
    assert ror_103.area == "1 Acre 10 Decimal"


def test_11_unrequested_plot_in_multi_plot_khata_fails_closed():
    """Requesting Plot 999 (not in Khata 250) fails closed with ValueError."""
    with pytest.raises(ValueError, match="Unable to verify"):
        parse_structured_ror(MULTI_PLOT_KHATA_HTML, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "999")


# ==============================================================================
# 4. OWNER & CLASSIFICATION LEAK TESTS
# ==============================================================================

def test_12_owner_leak_prevention():
    """Plot 101 (Alice) vs Plot 102 (Bob) must never leak owners across plots."""
    html_alice = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G_Dimbo</span>
        <span id="lblKhatiyanslNo">10</span>
        <table id="gvfront"><tr><td><span id="lblName">Alice Mahanta</span></td></tr></table>
        <table id="gvRorBack"><tr><td>101</td><td>Sarada-1</td><td>1</td><td>0</td></tr></table>
    </body></html>
    """
    html_bob = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G_Dimbo</span>
        <span id="lblKhatiyanslNo">20</span>
        <table id="gvfront"><tr><td><span id="lblName">Bob Mahanta</span></td></tr></table>
        <table id="gvRorBack"><tr><td>102</td><td>Gharabari</td><td>0</td><td>50</td></tr></table>
    </body></html>
    """
    ror_alice = parse_structured_ror(html_alice, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "101")
    ror_bob = parse_structured_ror(html_bob, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "102")

    assert ror_alice.owners[0].name == "Alice Mahanta"
    assert "Bob Mahanta" not in [o.name for o in ror_alice.owners]

    assert ror_bob.owners[0].name == "Bob Mahanta"
    assert "Alice Mahanta" not in [o.name for o in ror_bob.owners]


def test_13_classification_leak_prevention():
    """Plot 101 (Government) vs Plot 102 (Private) must never leak classification."""
    html_govt = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G_Dimbo</span>
        <span id="lblKhatiyanslNo">01</span>
        <span id="lblLandlordName">ଓଡ଼ିଶା ସରକାର</span>
        <table id="gvRorBack"><tr><td>101</td><td>Abada Jogya Anabadi</td><td>5</td><td>0</td></tr></table>
    </body></html>
    """
    html_private = """
    <html><body>
        <span id="lblDistrictName">KEONJHAR</span>
        <span id="lblTahasilName">KEONJHAR SADAR</span>
        <span id="lblVillageName">G_Dimbo</span>
        <span id="lblKhatiyanslNo">142</span>
        <table id="gvfront"><tr><td><span id="lblName">Dillip Mahanta</span></td></tr></table>
        <table id="gvRorBack"><tr><td>102</td><td>Stitiban Sarada-1</td><td>1</td><td>20</td></tr></table>
    </body></html>
    """
    ror_govt = parse_structured_ror(html_govt, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "101")
    ror_priv = parse_structured_ror(html_private, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "102")

    assert ror_govt.land_type == "Abada Jogya Anabadi"
    assert ror_govt.owners[0].name == "ଓଡ଼ିଶା ସରକାର"

    assert ror_priv.land_type == "Stitiban Sarada-1"
    assert ror_priv.owners[0].name == "Dillip Mahanta"
    assert "ଓଡ଼ିଶା ସରକାର" not in [o.name for o in ror_priv.owners]


# ==============================================================================
# 5. CACHE ISOLATION & SEMANTIC INTEGRITY
# ==============================================================================

def test_14_cache_keys_distinct_for_different_plots():
    """Cache keys for Plot 101, Plot 102, and Plot 103 are strictly distinct."""
    k1 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "101")
    k2 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "102")
    k3 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "103")

    assert len({k1, k2, k3}) == 3
    assert k1 != k2
    assert k2 != k3


def test_15_cache_keys_distinct_for_same_plot_in_different_villages():
    """Cache keys for Plot 12 in Village A vs Village B must never collide."""
    k_va = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "VILLAGE_A", "12")
    k_vb = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "VILLAGE_B", "12")
    assert k_va != k_vb


def test_16_multi_plot_cache_sequential_isolation():
    """Sequential cache test: A cached, B requested (not A), B cached, C requested (not A/B), A requested (hits A)."""
    _cache.clear()

    ror_a = parse_structured_ror(MULTI_PLOT_KHATA_HTML, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "101")
    key_a = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "101")
    _cache[key_a] = ror_a

    # Request B
    key_b = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "102")
    assert key_b not in _cache  # B does NOT receive A from cache

    ror_b = parse_structured_ror(MULTI_PLOT_KHATA_HTML, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "102")
    _cache[key_b] = ror_b

    # Request C
    key_c = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "103")
    assert key_c not in _cache  # C does NOT receive A or B

    # Request A again
    assert key_a in _cache
    cached_a = _cache[key_a]
    assert cached_a.plot == "101"
    assert cached_a.land_type == "Sarada-1"
    assert cached_a.area == "0 Acre 50 Decimal"

    _cache.clear()
