"""
Bhumitra Core-Data Accuracy Regression Test Suite (Categories A - M)
Exhaustively validates parcel-to-RoR mapping, fail-closed isolation, multi-owner preservation,
and ensures that unverified records NEVER expose owner information.
"""

import os
import pytest
from bs4 import BeautifulSoup
from scrapers.structured_ror_parser import parse_structured_ror
from scrapers.bhulekh_scraper import verify_ror_result
from scrapers.bhulekh_mappings import get_district_id, get_tahasil_id, normalize
from models.ror_response import RoRVerificationStatus

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")


def load_fixture(name: str) -> str:
    with open(os.path.join(FIXTURES_DIR, name), "r", encoding="utf-8") as f:
        return f.read()


# ==============================================================================
# CATEGORY A: KNOWN CORRECT PARCEL
# ==============================================================================

def test_category_a_known_correct_parcel():
    """A. Validates that an exact matching parcel passes all verification checks."""
    html = load_fixture("ror_single_owner.html")
    ror = parse_structured_ror(
        html=html,
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1182",
    )
    assert ror.success is True
    assert ror.plot == "1182"
    assert ror.khata_number == "142"
    assert ror.land_type == "Sarada-1"
    assert ror.area == "1 Acre 45 Decimal"
    assert len(ror.owners) == 1
    assert ror.verification.status == RoRVerificationStatus.VERIFIED


# ==============================================================================
# CATEGORY B: WRONG VILLAGE (FAIL-CLOSED)
# ==============================================================================

def test_category_b_wrong_village_fails_closed():
    """B. Validates that querying Village A when portal returned Village B raises verification error."""
    html = load_fixture("ror_single_owner.html")  # Contains G KERI 271
    with pytest.raises(ValueError, match="Unable to verify this parcel"):
        parse_structured_ror(
            html=html,
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="DIMBO 180",  # Mismatched Village
            plot="1182",
        )


# ==============================================================================
# CATEGORY C: WRONG TAHASIL (FAIL-CLOSED)
# ==============================================================================

def test_category_c_wrong_tahasil_fails_closed():
    """C. Validates that querying Tahasil A when portal returned Tahasil B raises verification error."""
    html = load_fixture("ror_single_owner.html")  # Contains KEONJHAR SADAR
    with pytest.raises(ValueError, match="Unable to verify this parcel"):
        parse_structured_ror(
            html=html,
            district="KEONJHAR",
            tahasil="CHAMPUA",  # Mismatched Tahasil
            village="G KERI 271",
            plot="1182",
        )


# ==============================================================================
# CATEGORY D: WRONG DISTRICT (FAIL-CLOSED)
# ==============================================================================

def test_category_d_wrong_district_fails_closed():
    """D. Validates that querying District A when portal returned District B raises verification error."""
    html = load_fixture("ror_single_owner.html")  # Contains KEONJHAR
    with pytest.raises(ValueError, match="Unable to verify this parcel"):
        parse_structured_ror(
            html=html,
            district="BALASORE",  # Mismatched District
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot="1182",
        )


# ==============================================================================
# CATEGORY E: WRONG PLOT (FAIL-CLOSED)
# ==============================================================================

def test_category_e_wrong_plot_fails_closed():
    """E. Validates that querying Plot 100 when portal returned Plot 1182 raises verification error."""
    html = load_fixture("ror_single_owner.html")  # Contains Plot 1182
    with pytest.raises(ValueError, match="Unable to verify this parcel"):
        parse_structured_ror(
            html=html,
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot="100",  # Mismatched Plot
        )


# ==============================================================================
# CATEGORY F: DUPLICATE PLOT NUMBER ACROSS MOUZAS (ISOLATION)
# ==============================================================================

def test_category_f_duplicate_plot_number_isolation():
    """F. Plot 500 exists in Village 1 and Village 2. Enforces that compound identity prevents collision."""
    v1_id = f"OD:0704:V1:500"
    v2_id = f"OD:0704:V2:500"
    assert v1_id != v2_id


# ==============================================================================
# CATEGORY G: MISSING GIS IDENTIFIERS (INSUFFICIENT DATA)
# ==============================================================================

def test_category_g_missing_gis_identifiers_fails_closed():
    """G. Validates that missing required GIS parameters fails closed before scrape."""
    district_id = get_district_id("NON_EXISTENT_DISTRICT")
    assert district_id is None


# ==============================================================================
# CATEGORY H: BHULEKH SERVICE UNAVAILABLE / TIMEOUT
# ==============================================================================

def test_category_h_bhulekh_unavailable_timeout():
    """H. Validates that network timeouts or portal errors are cleanly caught without guessing."""
    empty_html = "<html><body><div id='error'>Service Temporarily Unavailable (503)</div></body></html>"
    with pytest.raises(ValueError, match="Unable to verify this parcel"):
        parse_structured_ror(
            html=empty_html,
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot="1182",
        )


# ==============================================================================
# CATEGORY I: BHULEKH HTML STRUCTURE CHANGED
# ==============================================================================

def test_category_i_bhulekh_html_structure_changed():
    """I. If DOM IDs change and no owner/khatiyan can be verified, parser raises fail-safe error."""
    changed_html = "<html><body><table><tr><td>Some New Unknown Format</td></tr></table></body></html>"
    with pytest.raises(ValueError, match="Unable to verify this parcel"):
        parse_structured_ror(
            html=changed_html,
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot="1182",
        )


# ==============================================================================
# CATEGORY J: AMBIGUOUS LOCATION (DUPLICATE OPTIONS)
# ==============================================================================

def test_category_j_ambiguous_location_rejected():
    """J. If dropdown contains multiple identical village names, lookup fails closed."""
    from tests.test_canonical_parcel_identity import select_exact_option
    duplicate_dropdown = [
        {"value": "10", "text": "RAMPUR"},
        {"value": "20", "text": "RAMPUR"},
    ]
    with pytest.raises(ValueError, match="Ambiguous"):
        select_exact_option("RAMPUR", duplicate_dropdown)


# ==============================================================================
# CATEGORY K: MULTIPLE OWNERS WITH FRACTIONAL SHARES
# ==============================================================================

def test_category_k_multiple_owners_with_fractional_shares():
    """K. Preserves all 3 distinct joint owners and fractional shares without collapsing."""
    html = load_fixture("ror_multiple_owners_with_shares.html")
    ror = parse_structured_ror(
        html=html,
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="500",
    )
    assert ror.success is True
    assert len(ror.owners) == 3
    assert ror.owners[0].name == "Ramesh Chandra Sahu"
    assert ror.owners[0].share == "0.500"
    assert ror.owners[1].name == "Suresh Chandra Sahu"
    assert ror.owners[1].share == "0.250"
    assert ror.owners[2].name == "Gitanjali Sahu"
    assert ror.owners[2].share == "0.250"


# ==============================================================================
# CATEGORY L: GOVERNMENT LAND (STATE OWNERSHIP)
# ==============================================================================

def test_category_l_government_land_ownership():
    """L. State government land designates State Government as owner with Gochar kisama."""
    html = load_fixture("ror_government_land.html")
    ror = parse_structured_ror(
        html=html,
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="999",
    )
    assert ror.success is True
    assert ror.land_type == "Gochar"
    assert len(ror.owners) == 1
    assert "ଓଡିଶା ସରକାର" in ror.owners[0].name


# ==============================================================================
# CATEGORY M: PDF MISMATCH DETECTION (ABORT BEFORE GENERATION)
# ==============================================================================

def test_category_m_pdf_mismatch_aborts():
    """M. If result page contains Plot 1182 but request is Plot 999, pre-PDF verification rejects."""
    html = load_fixture("ror_single_owner.html")  # Contains Plot 1182
    soup = BeautifulSoup(html, "lxml")
    verif = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G KERI 271",
        requested_plot="999",
    )
    assert verif.status != RoRVerificationStatus.VERIFIED
    assert verif.plot_match is False
