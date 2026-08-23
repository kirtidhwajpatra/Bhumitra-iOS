"""
Phase 3.19F — Odisha Bilingual Bhulekh Identity Resolution Test Suite
Validates English <-> Odia mappings, pure Odia dropdown selection, exact plot isolation,
cross-district isolation, and fail-closed safety.
"""
import pytest
from resolvers.bhulekh_identity_resolver import (
    CadastralParcelIdentity,
    BhulekhLocationIdentity,
    BhulekhOfficialLocationOption,
    BhulekhVillageResolver,
    ResolutionStatus,
    resolve_bhulekh_identity,
    SCOPED_VILLAGE_ALIASES,
    BILINGUAL_VILLAGE_MAP,
)
from scrapers.bhulekh_scraper import verify_ror_result


def test_1_bilingual_model_and_location_option_structure():
    """Verify BhulekhOfficialLocationOption model enforces ID-first representation."""
    opt = BhulekhOfficialLocationOption(
        district_id="3",
        tahasil_id="1",
        mouza_id="88",
        display_name="Anantapur",
        odia_name="ଅନନ୍ତପୁର",
        english_name="Anantapur",
    )
    assert opt.district_id == "3"
    assert opt.mouza_id == "88"
    assert opt.odia_name == "ଅନନ୍ତପୁର"
    assert opt.verified is True


def test_2_pure_odia_dropdown_resolution():
    """Verify that pure Odia dropdown options resolve cleanly to the requested GIS identity."""
    options = [
        {"value": "10", "text": "ଅଲଙ୍ଗପୁର"},
        {"value": "20", "text": "ବାଇନ୍ଦୋଳ"},
        {"value": "30", "text": "ଅନନ୍ତପୁର"},
    ]
    
    # Cuttack / Athagarh / Anantapur
    status, matched, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="3",
        tahasil_id="1",
        gis_village_name="Anantapur-64",
        gis_village_id=None,
        available_options=options,
    )
    assert status in (ResolutionStatus.BILINGUAL_MATCH, ResolutionStatus.VERIFIED_MAPPED)
    assert matched is not None
    assert matched["value"] == "30"
    assert matched["text"] == "ଅନନ୍ତପୁର"


def test_3_odia_to_english_header_verification():
    """Verify verify_ror_result accepts legitimate Odia confirmation headers for Cuttack/Athagarh."""
    from bs4 import BeautifulSoup
    
    html = """
    <html><body>
        <table id="tblRoR">
            <tr><td>District: କଟକ</td><td>Tahasil: ଆଠଗଡ</td><td>Village: ଅନନ୍ତପୁର</td></tr>
            <tr><td>Plot No: 101</td><td>Area: 0.50 Acre</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    verif = verify_ror_result(
        soup=soup,
        requested_district="CUTTACK",
        requested_tahasil="ATHAGARH",
        requested_village="Anantapur-64",
        requested_plot="101",
    )
    assert verif.status.value == "VERIFIED"
    assert verif.location_match is True
    assert verif.plot_match is True


def test_4_exact_plot_number_isolation():
    """Safety: Plot 12 vs 120 vs 12/1 vs 12A."""
    from bs4 import BeautifulSoup

    html = """
    <html><body>
        <table>
            <tr><td>District: KEONJHAR</td><td>Tahasil: KEONJHAR SADAR</td><td>Village: Dimbo</td></tr>
            <tr><td>Plot No: 120</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    verif = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G_Dimbo",
        requested_plot="12",  # REQUESTED 12, BUT PORTAL HAS 120
    )
    assert verif.status.value == "MISMATCH"
    assert verif.plot_match is False


def test_5_duplicate_village_cross_district_isolation():
    """Verify Nuagaon in Balasore (1) vs Nuagaon in Nayagarh (22) remain strictly isolated."""
    cadastral_balasore = CadastralParcelIdentity(
        district_name="BALASORE",
        tahasil_name="BASTA",
        village_name="Nuagaon",
        plot_number="5",
    )
    cadastral_nayagarh = CadastralParcelIdentity(
        district_name="NAYAGARH",
        tahasil_name="NAYAGARH",
        village_name="Nuagaon",
        plot_number="5",
    )
    res_b = resolve_bhulekh_identity(cadastral_balasore)
    res_n = resolve_bhulekh_identity(cadastral_nayagarh)

    assert res_b.bhulekh_identity.district_id == "1"
    assert res_n.bhulekh_identity.district_id == "22"
    assert res_b.bhulekh_identity.district_id != res_n.bhulekh_identity.district_id


def test_6_unmapped_unknown_village_fails_closed():
    """Safety: An unmapped village with arbitrary name fails closed without guessing."""
    status, matched, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="7",
        tahasil_id="4",
        gis_village_name="NonExistentVillageX123",
        gis_village_id=None,
        available_options=[{"value": "1", "text": "Dimbo"}, {"value": "2", "text": "Patna"}],
    )
    assert status == ResolutionStatus.NOT_FOUND
    assert matched is None
    assert "could not be resolved" in detail or "could not be deterministically mapped" in detail
