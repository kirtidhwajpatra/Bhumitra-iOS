"""
Phase 3.19G — Live Bhulekh Dropdown Hardening & Resolution Test Suite
Validates 7-digit GIS Mouza ID matching, Odia numeral translation, dropdown value-first selection,
exact plot preservation, and strict cross-district isolation.
"""
import pytest
from bs4 import BeautifulSoup
from resolvers.bhulekh_identity_resolver import (
    CadastralParcelIdentity,
    BhulekhVillageResolver,
    ResolutionStatus,
    resolve_bhulekh_identity,
)
from scrapers.bhulekh_scraper import verify_ror_result, to_english_digits


def test_1_seven_digit_gis_mouza_id_resolution():
    """Level 1: 7-digit GIS village ID (DDTTNNN) maps to Bhulekh numeric option value (NNN)."""
    options = [
        {"value": "7", "text": "ବାଇଁଣ୍ଡୋଳ"},
        {"value": "50", "text": "ଆଳଙ୍ଗପୁର"},
        {"value": "88", "text": "ଅନନ୍ତପୁର"},
        {"value": "2", "text": "ଆଲିପୁର"},
    ]

    # Khurda / Balianta / Baindolo (2008007 -> 7)
    s1, o1, d1 = BhulekhVillageResolver.resolve_mouza_option("20", "8", "Baindolo", "2008007", options)
    assert s1 == ResolutionStatus.VERIFIED_MAPPED
    assert o1["value"] == "7"
    assert o1["text"] == "ବାଇଁଣ୍ଡୋଳ"

    # Puri / Astarang / Alangpur (1108050 -> 50)
    s2, o2, d2 = BhulekhVillageResolver.resolve_mouza_option("11", "8", "Alangpur", "1108050", options)
    assert s2 == ResolutionStatus.VERIFIED_MAPPED
    assert o2["value"] == "50"
    assert o2["text"] == "ଆଳଙ୍ଗପୁର"

    # Ganjam / Aska / Alipur (0501002 -> 2)
    s3, o3, d3 = BhulekhVillageResolver.resolve_mouza_option("5", "1", "Alipur", "0501002", options)
    assert s3 == ResolutionStatus.VERIFIED_MAPPED
    assert o3["value"] == "2"
    assert o3["text"] == "ଆଲିପୁର"

    # Cuttack / Athagarh / Anantapur-64 (0301088 -> 88)
    s4, o4, d4 = BhulekhVillageResolver.resolve_mouza_option("3", "1", "Anantapur-64", "0301088", options)
    assert s4 == ResolutionStatus.VERIFIED_MAPPED
    assert o4["value"] == "88"
    assert o4["text"] == "ଅନନ୍ତପୁର"


def test_2_odia_numeral_digit_translation():
    """Verify Odia numeral translation to standard digits."""
    assert to_english_digits("୧୨୩୪୫୬୭୮୯୦") == "1234567890"
    assert to_english_digits("୧୫") == "15"
    assert to_english_digits("୪୪") == "44"
    assert to_english_digits("୧୦୧") == "101"
    assert to_english_digits("୮୯") == "89"
    assert to_english_digits("15") == "15"


def test_3_odia_numeral_plot_verification():
    """Verify verify_ror_result correctly matches table rows containing Odia numerals."""
    html = """
    <html><body>
        <table id="tblRoR">
            <tr><td>District: ଖୋର୍ଦ୍ଧା</td><td>Tahasil: ବାଲିଅନ୍ତା</td><td>Village: ବାଇଁଣ୍ଡୋଳ</td></tr>
            <tr><td>SL No: ୧</td><td>Plot: ୧୫</td><td>Area: 0.25</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    verif = verify_ror_result(
        soup=soup,
        requested_district="KHURDA",
        requested_tahasil="BALIANTA",
        requested_village="Baindolo",
        requested_plot="15",
    )
    assert verif.status.value == "VERIFIED"
    assert verif.plot_match is True
    assert verif.location_match is True


def test_4_exact_plot_number_isolation():
    """Safety Invariant: Plot 12 vs 120 vs 12/1 vs 12A."""
    html = """
    <html><body>
        <table>
            <tr><td>District: KEONJHAR</td><td>Tahasil: KEONJHAR SADAR</td><td>Village: Dimbo</td></tr>
            <tr><td>Plot: 120</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")

    # Target 12 vs 120
    v1 = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12")
    assert v1.status.value == "MISMATCH"
    assert v1.plot_match is False

    # Target 12/1 vs 120
    v2 = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12/1")
    assert v2.status.value == "MISMATCH"
    assert v2.plot_match is False

    # Target 12A vs 120
    v3 = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12A")
    assert v3.status.value == "MISMATCH"
    assert v3.plot_match is False


def test_5_duplicate_village_cross_district_isolation():
    """Safety Invariant: Same village name across distinct districts produces isolated identities."""
    c_balasore = CadastralParcelIdentity(
        district_name="BALASORE",
        tahasil_name="BASTA",
        village_name="Nuagaon",
        plot_number="5",
    )
    c_nayagarh = CadastralParcelIdentity(
        district_name="NAYAGARH",
        tahasil_name="NAYAGARH",
        village_name="Nuagaon",
        plot_number="5",
    )

    r_balasore = resolve_bhulekh_identity(c_balasore)
    r_nayagarh = resolve_bhulekh_identity(c_nayagarh)

    assert r_balasore.bhulekh_identity.district_id == "1"
    assert r_nayagarh.bhulekh_identity.district_id == "22"
    assert r_balasore.bhulekh_identity.district_id != r_nayagarh.bhulekh_identity.district_id


def test_6_unmapped_or_wrong_id_fails_closed():
    """Safety Invariant: Unknown village or wrong ID fails closed with zero guessing."""
    s, m, d = BhulekhVillageResolver.resolve_mouza_option(
        district_id="7",
        tahasil_id="4",
        gis_village_name="InvalidVillageName999",
        gis_village_id="9999999",
        available_options=[{"value": "1", "text": "Dimbo"}],
    )
    assert s == ResolutionStatus.NOT_FOUND
    assert m is None
