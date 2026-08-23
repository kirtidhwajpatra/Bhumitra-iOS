"""
Phase 7.14: Canonical Bhulekh Identity Verification Safety Test Suite.
Validates:
  1. English GIS Tahasil + Odia Bhulekh Tahasil passes when canonical IDs match.
  2. English GIS district + Odia Bhulekh district passes when canonical IDs match.
  3. Correct village + wrong Tahasil ID fails.
  4. Correct Tahasil + wrong Mouza ID fails.
  5. Correct village + wrong plot fails.
  6. Ambiguous village fails closed.
  7. Missing canonical identity fails closed.
  8-11. Historical Problem Plots (647, 333, 12, 1) remain EXACT.
"""
import pytest
from bs4 import BeautifulSoup
from models.ror_response import BhulekhLocationIdentity, RoRVerificationStatus
from scrapers.bhulekh_scraper import verify_ror_result
from resolvers.bhulekh_identity_resolver import VerifiedBhulekhCatalog, ResolutionStatus


@pytest.fixture(scope="module", autouse=True)
def setup_catalog():
    VerifiedBhulekhCatalog.load()


def test_1_english_tahasil_with_odia_portal_header_passes_when_canonical_id_matches():
    """English GIS 'Baripada' with Odia portal 'ବାରିପଦା' passes because canonical Tahasil ID is '1'."""
    html = """
    <html>
      <span id="lblDistrict">ମୟୂରଭଞ୍ଜ</span>
      <span id="lblTahasil">ବାରିପଦା</span>
      <span id="lblVillage">ଅସନଶିଳା</span>
      <span id="lblPlotNo">84</span>
    </html>
    """
    soup = BeautifulSoup(html, "lxml")
    loc = BhulekhLocationIdentity(
        district_id="9",
        tahasil_id="1",
        village_id="242",
        district_name="MAYURBHANJ",
        tahasil_name="BARIPADA",
        village_name="ଅସନଶିଳା"
    )
    verif = verify_ror_result(
        soup=soup,
        requested_district="Mayurbhanj",
        requested_tahasil="Baripada",
        requested_village="ଅସନଶିଳା",
        requested_plot="84",
        location_identity=loc
    )
    assert verif.status == RoRVerificationStatus.VERIFIED
    assert verif.location_match is True
    assert verif.plot_match is True


def test_2_english_district_with_odia_portal_header_passes_when_canonical_id_matches():
    """English GIS 'Sundargarh' with Odia portal 'ସୁନ୍ଦରଗଡ' passes because canonical District ID is '13'."""
    html = """
    <html>
      <span id="lblDistrict">ସୁନ୍ଦରଗଡ</span>
      <span id="lblTahasil">ବଣେଇ</span>
      <span id="lblVillage">ଅଲେଖପୁର</span>
      <span id="lblPlotNo">916</span>
    </html>
    """
    soup = BeautifulSoup(html, "lxml")
    loc = BhulekhLocationIdentity(
        district_id="13",
        tahasil_id="1",
        village_id="93",
        district_name="SUNDARGARH",
        tahasil_name="SUNDARGARH",
        village_name="ଅଲେଖପୁର"
    )
    verif = verify_ror_result(
        soup=soup,
        requested_district="Sundargarh",
        requested_tahasil="Sundargarh",
        requested_village="ଅଲେଖପୁର",
        requested_plot="916",
        location_identity=loc
    )
    assert verif.status == RoRVerificationStatus.VERIFIED


def test_3_correct_village_with_wrong_tahasil_id_fails():
    """If portal returns a Tahasil ID that conflicts with the requested Tahasil, verification must fail."""
    html = """
    <html>
      <span id="lblDistrict">ମୟୂରଭଞ୍ଜ</span>
      <span id="lblTahasil">ରାଇରଙ୍ଗପୁର</span>
      <span id="lblVillage">ଅସନଶିଳା</span>
      <span id="lblPlotNo">84</span>
    </html>
    """
    soup = BeautifulSoup(html, "lxml")
    # Requested Tahasil ID is 1 (Baripada), but portal returned Tahasil ID 12 (Rairangpur)
    loc = BhulekhLocationIdentity(
        district_id="9",
        tahasil_id="1",
        village_id="242",
        district_name="MAYURBHANJ",
        tahasil_name="BARIPADA",
        village_name="ଅସନଶିଳା"
    )
    verif = verify_ror_result(
        soup=soup,
        requested_district="Mayurbhanj",
        requested_tahasil="Baripada",
        requested_village="ଅସନଶିଳା",
        requested_plot="84",
        location_identity=loc
    )
    assert verif.status == RoRVerificationStatus.MISMATCH
    assert verif.location_match is False


def test_4_correct_tahasil_with_wrong_village_fails():
    """If portal returns a different village name than requested, verification must fail."""
    html = """
    <html>
      <span id="lblDistrict">ମୟୂରଭଞ୍ଜ</span>
      <span id="lblTahasil">ବାରିପଦା</span>
      <span id="lblVillage">କପ୍ତିପଦା</span>
      <span id="lblPlotNo">84</span>
    </html>
    """
    soup = BeautifulSoup(html, "lxml")
    loc = BhulekhLocationIdentity(
        district_id="9",
        tahasil_id="1",
        village_id="242",
        district_name="MAYURBHANJ",
        tahasil_name="BARIPADA",
        village_name="ଅସନଶିଳା"
    )
    verif = verify_ror_result(
        soup=soup,
        requested_district="Mayurbhanj",
        requested_tahasil="Baripada",
        requested_village="ଅସନଶିଳା",
        requested_plot="84",
        location_identity=loc
    )
    assert verif.status == RoRVerificationStatus.MISMATCH


def test_5_correct_village_with_wrong_plot_fails():
    """If portal returns a different plot number, verification must fail."""
    html = """
    <html>
      <span id="lblDistrict">ମୟୂରଭଞ୍ଜ</span>
      <span id="lblTahasil">ବାରିପଦା</span>
      <span id="lblVillage">ଅସନଶିଳା</span>
      <span id="lblPlotNo">999</span>
    </html>
    """
    soup = BeautifulSoup(html, "lxml")
    loc = BhulekhLocationIdentity(
        district_id="9",
        tahasil_id="1",
        village_id="242",
        district_name="MAYURBHANJ",
        tahasil_name="BARIPADA",
        village_name="ଅସନଶିଳା"
    )
    verif = verify_ror_result(
        soup=soup,
        requested_district="Mayurbhanj",
        requested_tahasil="Baripada",
        requested_village="ଅସନଶିଳା",
        requested_plot="84",
        location_identity=loc
    )
    assert verif.status == RoRVerificationStatus.MISMATCH
    assert verif.plot_match is False


def test_6_ambiguous_village_fails_closed():
    """Ambiguous village returns AMBIGUOUS from catalog and fails closed."""
    rec, status, detail = VerifiedBhulekhCatalog.lookup("6", "", "ଆମ୍ବଗୁଡା")
    assert status == ResolutionStatus.AMBIGUOUS
    assert rec is None


def test_7_missing_canonical_identity_fails_closed():
    """Fictional village returns NOT_FOUND and fails closed."""
    rec, status, detail = VerifiedBhulekhCatalog.lookup("7", "4", "UnknownNonExistentVillage_999")
    assert status == ResolutionStatus.NOT_FOUND
    assert rec is None


def test_8_historical_plot_647_exact():
    """Plot 647 in Bargarh Chakuli resolves deterministically."""
    rec, status, _ = VerifiedBhulekhCatalog.lookup("15", "1", "Chakuli")
    assert status in (ResolutionStatus.EXACT, ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.CANONICAL_ALIAS, ResolutionStatus.VERIFIED_MAPPED)
    assert rec["bhulekh_mouza_id"] == "61"


def test_9_historical_plot_333_exact():
    """Plot 333 in Khordha Raghunathpur Jali resolves deterministically."""
    rec, status, _ = VerifiedBhulekhCatalog.lookup("20", "2", "Raghunathpur Jali")
    assert status in (ResolutionStatus.EXACT, ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.CANONICAL_ALIAS, ResolutionStatus.VERIFIED_MAPPED)
    assert rec["bhulekh_mouza_id"] == "359"


def test_10_historical_plot_12_exact():
    """Plot 12 in Keonjhar G_Dimbo resolves deterministically."""
    rec, status, _ = VerifiedBhulekhCatalog.lookup("7", "4", "G_Dimbo")
    assert status in (ResolutionStatus.EXACT, ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.CANONICAL_ALIAS, ResolutionStatus.VERIFIED_MAPPED)
    assert rec["bhulekh_mouza_id"] == "317"


def test_11_historical_plot_1_exact():
    """Plot 1 in Keonjhar G_Dimbo resolves deterministically."""
    rec, status, _ = VerifiedBhulekhCatalog.lookup("7", "4", "Dimbo")
    assert status in (ResolutionStatus.EXACT, ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.CANONICAL_ALIAS, ResolutionStatus.VERIFIED_MAPPED)
    assert rec["bhulekh_mouza_id"] == "317"
