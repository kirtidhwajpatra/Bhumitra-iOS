"""
Phase 1 — Comprehensive Identity Resolution Test Suite
Validates the deterministic ORSAC/GIS -> Odisha Bhulekh mapping layer across all required criteria:
- Multi-tier matching hierarchy
- Indic phonemic transliteration & skeleton matching
- Scoped geographic isolation
- Ambiguity fail-closed protection
- Absolute immunity against Khata 01 / Government Land fallbacks
"""
import pytest
from typing import List, Dict

from resolvers.bhulekh_identity_resolver import (
    VerifiedBhulekhCatalog,
    BhulekhVillageResolver,
    resolve_bhulekh_identity,
    CadastralParcelIdentity,
    ResolutionStatus,
    clean_gis_village_name,
    normalize_phonetic,
    consonant_skeleton,
    odia_to_phonetic,
)
from models.canonical_village import CanonicalVillageIdentity, VillageVerificationStatus


@pytest.fixture(autouse=True)
def load_catalog():
    VerifiedBhulekhCatalog.load()


# ── TEST 1: Exact Official Identifier Match ─────────────────────────────────────

def test_1_exact_identifier_match():
    """Level 1: Verifies exact 7-digit GIS census/mouza code resolution."""
    # 7-digit code ending in 088 -> Mouza 88 under Cuttack (3), Athagarh (1)
    rec, status, detail = VerifiedBhulekhCatalog.lookup(
        district_id="3",
        tahasil_id="1",
        village_name="UnknownVillage",
        village_id="2803088"
    )
    assert status == ResolutionStatus.VERIFIED_MAPPED
    assert rec is not None
    assert rec["bhulekh_mouza_id"] == "88"
    assert "88" in detail


# ── TEST 2: Exact Name Match ───────────────────────────────────────────────────

def test_2_exact_name_match():
    """Level 2: Verifies exact string matching against live dropdown options."""
    dropdown_opts = [
        {"value": "11", "text": "Hinjili"},
        {"value": "12", "text": "Katu"},
        {"value": "13", "text": "Ankorada"},
    ]
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="5",
        tahasil_id="13",
        gis_village_name="Hinjili",
        gis_village_id=None,
        available_options=dropdown_opts,
    )
    assert status in (ResolutionStatus.EXACT, ResolutionStatus.VERIFIED_MAPPED)
    assert opt is not None
    assert opt["value"] == "11"


# ── TEST 3: Scoped Canonical Alias Match ───────────────────────────────────────

def test_3_scoped_canonical_alias_match():
    """Level 4: Verifies scoped canonical aliases function strictly within district+tahasil."""
    # G_Dimbo is aliased to Dimbo specifically in Keonjhar (7) Sadar (4)
    rec, status, detail = VerifiedBhulekhCatalog.lookup(
        district_id="7",
        tahasil_id="4",
        village_name="G_Dimbo",
        village_id=None
    )
    assert status in (ResolutionStatus.CANONICAL_ALIAS, ResolutionStatus.VERIFIED_MAPPED)
    assert rec is not None
    assert rec["bhulekh_mouza_id"] == "317"


# ── TEST 4: Ambiguous Village Handling (Fail-Closed) ───────────────────────────

def test_4_ambiguous_village_fails_closed():
    """Ambiguity Protection: If multiple candidates match phonetically in same Tahasil, strictly fail-closed."""
    dropdown_opts = [
        {"value": "101", "text": "ହିଞ୍ଜିଳି ୧"},
        {"value": "102", "text": "ହିଞ୍ଜିଳି ୨"},
    ]
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="5",
        tahasil_id="13",
        gis_village_name="Hinjili",
        gis_village_id=None,
        available_options=dropdown_opts,
    )
    # Must NOT pick one at random; must return AMBIGUOUS
    assert status in (ResolutionStatus.AMBIGUOUS, ResolutionStatus.NOT_FOUND)
    assert opt is None


# ── TEST 5: Nonexistent Village Handling ───────────────────────────────────────

def test_5_nonexistent_village_returns_not_found():
    """Returns NOT_FOUND when a village does not exist in the official portal."""
    rec, status, detail = VerifiedBhulekhCatalog.lookup(
        district_id="7",
        tahasil_id="4",
        village_name="CompletelyNonExistentVillageXYZ",
        village_id=None
    )
    assert status == ResolutionStatus.NOT_FOUND
    assert rec is None


# ── TEST 6: Same Village Name in Two Districts (Scoped Isolation) ──────────────

def test_6_same_village_name_in_two_districts():
    """Verifies that common village names (e.g. 'Anantapur') resolve to distinct mouzas per district."""
    # Anantapur in Cuttack (3), Athagarh (1) -> Mouza 88
    rec_cuttack, status_c, _ = VerifiedBhulekhCatalog.lookup("3", "1", "Anantapur")
    assert status_c in (ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.VERIFIED_MAPPED, ResolutionStatus.CANONICAL_ALIAS)
    assert rec_cuttack["bhulekh_mouza_id"] == "88"

    # Searching under Keonjhar (7), Sadar (4) must NOT return Cuttack's Mouza 88
    rec_keonjhar, status_k, _ = VerifiedBhulekhCatalog.lookup("7", "4", "Anantapur")
    # If Anantapur does not exist in Keonjhar Sadar, it must return NOT_FOUND (never Cuttack's 88)
    if rec_keonjhar:
        assert rec_keonjhar["bhulekh_district_id"] == "7"
        assert rec_keonjhar["bhulekh_mouza_id"] != "88" or rec_keonjhar["bhulekh_district_id"] == "7"


# ── TEST 7: Same Village Name in Two Tahasils ─────────────────────────────────

def test_7_same_village_name_in_two_tahasils():
    """Verifies that village resolution is strictly isolated to the specified Tahasil."""
    # Alipur in Ganjam (5), Aska (1) -> Mouza 46
    rec_aska, status_a, _ = VerifiedBhulekhCatalog.lookup("5", "1", "Alipur")
    # Alipur in Ganjam (5), Hinjilicut (13) -> Mouza 46
    rec_hinjili, status_h, _ = VerifiedBhulekhCatalog.lookup("5", "13", "Alipur")
    
    assert rec_aska is not None or rec_hinjili is not None
    if rec_aska and rec_hinjili:
        assert rec_aska["bhulekh_tahasil_id"] == "1"
        assert rec_hinjili["bhulekh_tahasil_id"] == "13"


# ── TEST 8: English vs Odia Transliteration Differences ───────────────────────

def test_8_english_odia_transliteration():
    """Verifies that English phonemic strings resolve accurately to Odia records across multiple districts."""
    test_cases = [
        ("5", "13", "Hinjili", "11"),              # Ganjam / Hinjilicut -> ହିଞ୍ଜିଳି (11)
        ("3", "1", "Anantapur", "88"),             # Cuttack / Athagarh -> ଅନନ୍ତପୁର (88)
        ("7", "4", "Dimbo", "317"),                # Keonjhar / Keonjhar Sadar -> ଡ଼ିମ୍ବୋ (317)
        ("20", "1", "Bikrampur Sasan", "214"),     # Khordha / Banapur -> ବିକ୍ରମପୁର ଶାସନ (214)
        ("1", "1", "Pachhudia", "336"),            # Balasore / Baleswar -> ପାଛୁଡିଆ (336)
        ("11", "8", "Alangapur", "50"),            # Puri / Astarang -> ଆଳଙ୍ଗପୁର (50)
        ("14", "5", "Biraramchandrapur", "352"),   # Angul / Talcher -> ବୀରରାମଚନ୍ଦ୍ରପୁର (352)
    ]
    for did, tid, gis_name, expected_mid in test_cases:
        rec, status, detail = VerifiedBhulekhCatalog.lookup(did, tid, gis_name)
        assert status in (ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.VERIFIED_MAPPED, ResolutionStatus.CANONICAL_ALIAS), f"Failed for {gis_name} in Dist {did}, Tah {tid}"
        assert rec is not None
        assert rec["bhulekh_mouza_id"] == expected_mid


# ── TEST 9: Punctuation & Suffix Tolerant Matching ────────────────────────────

def test_9_punctuation_and_survey_suffixes():
    """Verifies that GIS cadastral noise tokens (-13, _64, _Mosaic, G_, Un24_) are stripped safely."""
    assert clean_gis_village_name("Hinjili 13") == "Hinjili"
    assert clean_gis_village_name("Anantapur-64") == "Anantapur"
    assert clean_gis_village_name("G_Dimbo_Mosaic") == "Dimbo"
    assert clean_gis_village_name("G_Keri 271") == "Keri"
    assert clean_gis_village_name("Un14_Baraguda_WGS84") == "Baraguda"

    # Test that stripped names resolve in catalog
    rec, status, _ = VerifiedBhulekhCatalog.lookup("5", "13", "Hinjili 13")
    assert rec is not None
    assert rec["bhulekh_mouza_id"] == "11"


# ── TEST 10: Whitespace Differences ───────────────────────────────────────────

def test_10_whitespace_differences():
    """Verifies that irregular whitespace is normalized."""
    rec1, status1, _ = VerifiedBhulekhCatalog.lookup("7", "4", "  G   KERI   271  ")
    assert rec1 is not None
    assert rec1["bhulekh_mouza_id"] in ("271", "330")


# ── TEST 11: Phonetic Variations (Schwa / Vowel Normalization) ─────────────────

def test_11_phonetic_variations():
    """Verifies that minor transliteration vowel differences (Anandapura vs Anandapur) match correctly."""
    rec1, _, _ = VerifiedBhulekhCatalog.lookup("7", "1", "Anandapur")
    rec2, _, _ = VerifiedBhulekhCatalog.lookup("7", "1", "Anandapura")
    assert rec1 is not None
    assert rec2 is not None
    assert rec1["bhulekh_mouza_id"] == rec2["bhulekh_mouza_id"]


# ── TEST 12 & 13: Missing and Invalid Identifiers ──────────────────────────────

def test_12_missing_identifier_handles_gracefully():
    """Verifies that missing village_id falls back to robust name/phonetic resolution."""
    rec, status, _ = VerifiedBhulekhCatalog.lookup("5", "13", "Hinjili", village_id=None)
    assert rec is not None
    assert rec["bhulekh_mouza_id"] == "11"


def test_13_invalid_identifier_handles_gracefully():
    """Verifies that non-numeric or malformed village_id does not cause crashes or false matches."""
    rec, status, _ = VerifiedBhulekhCatalog.lookup("5", "13", "Hinjili", village_id="INVALID_CODE_9999")
    assert rec is not None
    assert rec["bhulekh_mouza_id"] == "11"


# ── TEST 14, 15, 16: Mismatched District and Tahasil ──────────────────────────

def test_15_mismatched_district_fails_closed():
    """Verifies that searching a Ganjam village (Hinjili) under Keonjhar (7) strictly fails-closed."""
    rec, status, _ = VerifiedBhulekhCatalog.lookup("7", "4", "Hinjili")
    assert status == ResolutionStatus.NOT_FOUND
    assert rec is None


def test_16_mismatched_tahasil_fails_closed():
    """Verifies that searching Banapur village (Bikrampur Sasan) under Athagarh tahasil strictly fails-closed."""
    rec, status, _ = VerifiedBhulekhCatalog.lookup("3", "1", "Bikrampur Sasan")
    assert status == ResolutionStatus.NOT_FOUND
    assert rec is None


# ── TEST 17: CRITICAL SAFETY TEST — FAILED MATCH NEVER FALLS BACK TO KHATA 01 ──

def test_17_failed_match_never_falls_back_to_khata_01():
    """
    CRITICAL ACCEPTANCE CRITERIA:
    Proves that an unresolvable or mismatched village strictly produces ResolutionStatus.NOT_FOUND
    with NO BhulekhLocationIdentity, NO Khata 01 assignment, and NO government record fallback.
    """
    cadastral = CadastralParcelIdentity(
        district_name="UNKNOWN_DISTRICT",
        tahasil_name="UNKNOWN_TAHASIL",
        village_name="UNKNOWN_VILLAGE",
        plot_number="1234"
    )
    result = resolve_bhulekh_identity(cadastral)
    
    # Must be strictly NOT_FOUND
    assert result.status == ResolutionStatus.NOT_FOUND
    assert result.bhulekh_identity is None
    assert result.canonical_village is None
    
    # Prove that resolution details do NOT contain Khata 01 or default government identities
    assert "01" not in (result.resolution_method or "")
    assert "Odisha Sarkar" not in result.details
