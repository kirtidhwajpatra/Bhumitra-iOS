"""
Structured RoR Parser Test Suite
Tests exact DOM element extraction, multi-owner isolation, share binding,
government land handling, and relation filtering against realistic HTML fixtures.
"""

import os
import pytest
from scrapers.structured_ror_parser import parse_structured_ror, clean_owner_name
from models.ror_response import RoRVerificationStatus

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")


def load_fixture(filename: str) -> str:
    with open(os.path.join(FIXTURES_DIR, filename), "r", encoding="utf-8") as f:
        return f.read()


def test_clean_owner_name_filters_relations():
    """Validates that relations like S/O, W/O, Guardian are stripped while initials/titles are preserved."""
    assert clean_owner_name("S/O Late Bipin Sahu") is None
    assert clean_owner_name("Guardian: Subhasish Mohanty") is None
    assert clean_owner_name("Dr. P. K. Patnaik, M.B.B.S.") == "Dr. P. K. Patnaik, M.B.B.S."
    assert clean_owner_name("ଦିଲ୍ଲୀପ କୁମାର ମହାନ୍ତ") == "ଦିଲ୍ଲୀପ କୁମାର ମହାନ୍ତ"
    assert clean_owner_name("SL NO") is None
    assert clean_owner_name("12345") is None


def test_fixture_single_owner_with_father_relation():
    """Tests single owner extraction with father relation in separate column."""
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
    assert ror.owners[0].name == "ଦିଲ୍ଲୀପ କୁମାର ମହାନ୍ତ (Dillip Kumar Mahanta)"
    assert ror.owners[0].share == "1.000"
    assert "ଅର୍ଜୁନ" not in [o.name for o in ror.owners]  # Father name not in owners list


def test_fixture_multiple_owners_with_shares():
    """Tests 3 joint owners with fractional shares without collapsing names."""
    html = load_fixture("ror_multiple_owners_with_shares.html")
    ror = parse_structured_ror(
        html=html,
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="500",
    )
    assert ror.success is True
    assert ror.plot == "500"
    assert ror.khata_number == "305"
    assert ror.land_type == "Gharabari"
    assert ror.area == "0 Acre 80 Decimal"
    assert len(ror.owners) == 3
    assert ror.owners[0].name == "Ramesh Chandra Sahu"
    assert ror.owners[0].share == "0.500"
    assert ror.owners[1].name == "Suresh Chandra Sahu"
    assert ror.owners[1].share == "0.250"
    assert ror.owners[2].name == "Gitanjali Sahu"
    assert ror.owners[2].share == "0.250"


def test_fixture_government_land():
    """Tests government land where landlord represents the official owner."""
    html = load_fixture("ror_government_land.html")
    ror = parse_structured_ror(
        html=html,
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="999",
    )
    assert ror.success is True
    assert ror.plot == "999"
    assert ror.khata_number == "1"
    assert ror.land_type == "Gochar"
    assert ror.area == "5 Acre 20 Decimal"
    assert len(ror.owners) == 1
    assert "ଓଡିଶା ସରକାର" in ror.owners[0].name


def test_fixture_complex_relations_and_initials():
    """Tests owners with medical/doctoral titles, initials, and guardian entries."""
    html = load_fixture("ror_complex_relations.html")
    ror = parse_structured_ror(
        html=html,
        district="CUTTACK",
        tahasil="SALIPUR",
        village="BAHALPADA",
        plot="45/1",
    )
    assert ror.success is True
    assert ror.plot == "45/1"
    assert ror.khata_number == "88"
    assert ror.land_type == "Jal-2"
    assert ror.area == "2 Acre 10 Decimal"
    assert len(ror.owners) == 2
    assert ror.owners[0].name == "Dr. P. K. Patnaik, M.B.B.S."
    assert ror.owners[0].share == "1/2"
    assert ror.owners[1].name == "Smruti R. Mohanty"
    assert ror.owners[1].share == "1/2"


# ==============================================================================
# PHASE 7 PDF PRE-VERIFICATION & DOCUMENT ACCURACY TESTS
# ==============================================================================

def test_pdf_pre_verification_passes_for_correct_plot():
    """Validates that PDF generation verification passes when result page matches requested parcel."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result
    from models.ror_response import RoRVerificationStatus

    html = load_fixture("ror_single_owner.html")
    soup = BeautifulSoup(html, "lxml")
    verification = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G KERI 271",
        requested_plot="1182",
    )
    assert verification.status == RoRVerificationStatus.VERIFIED
    assert verification.plot_match is True
    assert verification.location_match is True


def test_pdf_pre_verification_fails_for_wrong_plot():
    """Validates that PDF generation is aborted when portal renders a different plot."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result
    from models.ror_response import RoRVerificationStatus

    html = load_fixture("ror_single_owner.html")  # Contains Plot 1182
    soup = BeautifulSoup(html, "lxml")
    verification = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G KERI 271",
        requested_plot="9999",  # Requested 9999
    )
    assert verification.status != RoRVerificationStatus.VERIFIED
    assert verification.plot_match is False


def test_pdf_pre_verification_fails_for_wrong_village():
    """Validates that PDF generation is aborted when village does not match."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result
    from models.ror_response import RoRVerificationStatus

    html = load_fixture("ror_single_owner.html")
    soup = BeautifulSoup(html, "lxml")
    verification = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="OTHER VILLAGE",
        requested_plot="1182",
    )
    assert verification.status == RoRVerificationStatus.MISMATCH
    assert verification.location_match is False


def test_pdf_pre_verification_fails_for_wrong_tahasil():
    """Validates that PDF generation is aborted when tahasil does not match."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result
    from models.ror_response import RoRVerificationStatus

    html = load_fixture("ror_single_owner.html")
    soup = BeautifulSoup(html, "lxml")
    verification = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="CHAMPUA",  # Requested Champua, but page has Keonjhar Sadar
        requested_village="G KERI 271",
        requested_plot="1182",
    )
    assert verification.status == RoRVerificationStatus.MISMATCH
    assert verification.location_match is False


def test_pdf_pre_verification_fails_for_wrong_district():
    """Validates that PDF generation is aborted when district does not match."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result
    from models.ror_response import RoRVerificationStatus

    html = load_fixture("ror_single_owner.html")
    soup = BeautifulSoup(html, "lxml")
    verification = verify_ror_result(
        soup=soup,
        requested_district="MAYURBHANJ",  # Requested Mayurbhanj, but page has Keonjhar
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G KERI 271",
        requested_plot="1182",
    )
    assert verification.status == RoRVerificationStatus.MISMATCH
    assert verification.location_match is False


def test_pdf_pre_verification_fails_for_missing_result_page():
    """Validates that PDF generation fails safely on empty/corrupt HTML."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result
    from models.ror_response import RoRVerificationStatus

    empty_soup = BeautifulSoup("<html><body><h1>Error</h1></body></html>", "lxml")
    verification = verify_ror_result(
        soup=empty_soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G KERI 271",
        requested_plot="1182",
    )
    assert verification.status == RoRVerificationStatus.INSUFFICIENT_DATA

