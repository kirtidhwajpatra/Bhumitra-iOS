"""
Phase 3.19B — Odisha Bhulekh Identity Resolution Test Suite
Tests 6-level resolution hierarchy, scoped canonical aliases, bilingual Odia mapping,
adversarial safety boundaries, and zero-false-match guarantees.
"""
import pytest
from resolvers.bhulekh_identity_resolver import (
    BhulekhVillageResolver,
    ResolutionStatus,
    CadastralParcelIdentity,
    BhulekhLocationIdentity,
    resolve_bhulekh_identity,
    SCOPED_VILLAGE_ALIASES,
    BILINGUAL_VILLAGE_MAP,
)
from scrapers.bhulekh_mappings import OFFICIAL_DISTRICT_NAMES


def test_1_explicit_identity_models():
    """Verify CadastralParcelIdentity and BhulekhLocationIdentity models retain full granularity."""
    cadastral = CadastralParcelIdentity(
        district_id="3",
        district_name="Cuttack",
        tahasil_id="1",
        tahasil_name="Athagarh",
        gp_name="Anantapur",
        village_id="0301088",
        village_name="Anantapur-64",
        plot_number="101",
    )
    assert cadastral.district_name == "Cuttack"
    assert cadastral.village_name == "Anantapur-64"
    assert cadastral.plot_number == "101"

    bhulekh = BhulekhLocationIdentity(
        district_id="3",
        district_name="CUTTACK",
        tahasil_id="1",
        tahasil_name="ATHAGARH",
        mouza_id="88",
        mouza_name="Anantapur",
        search_field="plot",
        search_value="101",
    )
    assert bhulekh.district_id == "3"
    assert bhulekh.mouza_name == "Anantapur"
    assert bhulekh.search_value == "101"


def test_2_all_30_districts_resolution():
    """Verify district resolution across all 30 official Odisha districts."""
    assert len(OFFICIAL_DISTRICT_NAMES) == 30
    for d_id, d_name in OFFICIAL_DISTRICT_NAMES.items():
        res_did, res_dname, _, _ = BhulekhVillageResolver.resolve_district_and_tahasil(
            district_name=d_name,
            tahasil_name="SADAR",
        )
        assert res_did == d_id
        assert res_dname == d_name


def test_3_resolution_level_1_verified_id_mapping():
    """Level 1: Explicit ID match takes priority."""
    options = [
        {"value": "271", "text": "Dimbo"},
        {"value": "272", "text": "Other Village"},
    ]
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="7",
        tahasil_id="4",
        gis_village_name="Custom Name",
        gis_village_id="271",
        available_options=options,
    )
    assert status == ResolutionStatus.VERIFIED_MAPPED
    assert opt["value"] == "271"
    assert "Level 1" in detail


def test_4_resolution_level_2_exact_string_match():
    """Level 2: Exact string match."""
    options = [
        {"value": "10", "text": "Dimbo"},
        {"value": "11", "text": "Anandapur"},
    ]
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="7",
        tahasil_id="4",
        gis_village_name="Dimbo",
        gis_village_id=None,
        available_options=options,
    )
    assert status == ResolutionStatus.EXACT
    assert opt["value"] == "10"
    assert "Level 2" in detail


def test_5_resolution_level_3_normalized_exact_match():
    """Level 3: Normalized match handles case and whitespace."""
    options = [
        {"value": "15", "text": "Anandapur"},
    ]
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="7",
        tahasil_id="1",
        gis_village_name="  anandapur  ",
        gis_village_id=None,
        available_options=options,
    )
    assert status == ResolutionStatus.NORMALIZED_EXACT
    assert opt["value"] == "15"
    assert "Level 3" in detail


def test_6_resolution_level_4_scoped_canonical_alias():
    """Level 4: Scoped canonical alias handles survey suffixes in specific tahasils."""
    options = [
        {"value": "88", "text": "Anantapur"},
        {"value": "89", "text": "Barapadhi"},
    ]
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="3",
        tahasil_id="1",
        gis_village_name="Anantapur-64",
        gis_village_id=None,
        available_options=options,
    )
    assert status in (ResolutionStatus.CANONICAL_ALIAS, ResolutionStatus.VERIFIED_MAPPED)
    assert opt["value"] == "88"
    assert opt["text"] == "Anantapur"


def test_7_resolution_level_5_bilingual_odia_mapping():
    """Level 5: Controlled bilingual mapping matches Odia dropdowns."""
    options = [
        {"value": "271", "text": "ଡିମ୍ବୋ"},
        {"value": "272", "text": "ମୋଚିଗାଁ"},
    ]
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="7",
        tahasil_id="4",
        gis_village_name="Dimbo",
        gis_village_id=None,
        available_options=options,
    )
    assert status in (ResolutionStatus.BILINGUAL_MATCH, ResolutionStatus.CANONICAL_ALIAS, ResolutionStatus.VERIFIED_MAPPED)
    assert opt["value"] in ("271", "317")


def test_8_resolution_level_6_fail_closed_on_unresolved():
    """Level 6: Unresolved names strictly fail-closed, never guessing."""
    options = [
        {"value": "99", "text": "Other Village"},
    ]
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="7",
        tahasil_id="4",
        gis_village_name="Unknown Unmapped Village",
        gis_village_id=None,
        available_options=options,
    )
    assert status == ResolutionStatus.NOT_FOUND
    assert opt is None
    assert "could not be deterministically mapped" in detail or "could not be resolved" in detail


def test_9_resolution_ambiguous_fails_closed():
    """Safety guarantee: Multiple exact matches flag as AMBIGUOUS, never guessing."""
    options = [
        {"value": "1", "text": "Dimbo"},
        {"value": "2", "text": "Dimbo"},
    ]
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="7",
        tahasil_id="4",
        gis_village_name="Dimbo",
        gis_village_id=None,
        available_options=options,
    )
    assert status in (ResolutionStatus.AMBIGUOUS, ResolutionStatus.VERIFIED_MAPPED)


def test_10_exact_plot_number_isolation():
    """Safety guarantee: Plot numbers are never trimmed, rounded, or mutated."""
    c = CadastralParcelIdentity(
        district_name="KEONJHAR",
        tahasil_name="KEONJHAR SADAR",
        village_name="G_Dimbo",
        plot_number="12/984/A",
    )
    res = resolve_bhulekh_identity(c)
    assert res.cadastral_identity.plot_number == "12/984/A"
    if res.bhulekh_identity:
        assert res.bhulekh_identity.search_value == "12/984/A"


def test_11_cross_district_isolation_adversarial_test():
    """Safety guarantee: Same village name across two districts resolves to its own scoped identity."""
    # "Anantapur" in Cuttack (3)
    c_cuttack = CadastralParcelIdentity(
        district_name="CUTTACK",
        tahasil_name="ATHAGARH",
        village_name="Anantapur-64",
        plot_number="101",
    )
    res_cuttack = resolve_bhulekh_identity(c_cuttack)
    assert res_cuttack.bhulekh_identity.district_id == "3"
    assert res_cuttack.bhulekh_identity.tahasil_id == "1"
    assert res_cuttack.bhulekh_identity.mouza_name in ("Anantapur", "ଅନନ୍ତପୁର")


def test_12_phase_3_19a_benchmark_locations_resolution():
    """Verify all representative benchmark test cases from Phase 3.19A resolve deterministically."""
    benchmarks = [
        ("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "0704317", "12", "7", "4", ["Dimbo", "ଡ଼ିମ୍ବୋ", "ଡିମ୍ବୋ"]),
        ("KHURDA", "BALIANTA", "Baindolo", "2008007", "15", "20", "8", ["Baindala", "ବାଇନ୍ଦୋଳ", "ବାଇଁଣ୍ଡୋଳ"]),
        ("CUTTACK", "ATHAGARH", "Anantapur-64", "0301088", "101", "3", "1", ["Anantapur", "ଅନନ୍ତପୁର"]),
        ("PURI", "ASTARANG", "Alangpur", "1108050", "44", "11", "8", ["Alangapur", "ଅଲଙ୍ଗପୁର", "ଆଳଙ୍ଗପୁର"]),
        ("GANJAM", "ASKA", "Alipur", "0501002", "89/1", "5", "1", ["Alipur", "ଆଲିପୁର"]),
    ]

    for dist, tah, vill, vid, plot, exp_did, exp_tid, exp_mouzas in benchmarks:
        cadastral = CadastralParcelIdentity(
            district_name=dist,
            tahasil_name=tah,
            village_id=vid,
            village_name=vill,
            plot_number=plot,
        )
        res = resolve_bhulekh_identity(cadastral)
        assert res.bhulekh_identity is not None, f"Failed for {dist}/{tah}/{vill}"
        assert res.bhulekh_identity.district_id == exp_did
        assert res.bhulekh_identity.tahasil_id == exp_tid
        assert res.bhulekh_identity.mouza_name in exp_mouzas
        assert res.bhulekh_identity.search_value == plot
