"""
Phase 7.10 Safety & Regression Tests for Odisha-Wide Official Village Identity Catalog
Validates strict isolation, representation normalization, deterministic lookup, and fail-closed security.
"""
import pytest
from resolvers.village_identity_normalizer import (
    normalize_unicode_representation,
    normalize_village_name,
    normalize_odia_village_key,
)
from resolvers.bhulekh_identity_resolver import (
    VerifiedBhulekhCatalog,
    BhulekhVillageResolver,
    ResolutionStatus,
)


def test_unicode_normalization():
    # 1. NFC composition & zero width stripping
    s = "ଅ\u200Dତିବୁଦ୍ଧି\u200C ପଡା\uFEFF"
    norm = normalize_unicode_representation(s)
    assert "\u200D" not in norm
    assert "\u200C" not in norm
    assert "\uFEFF" not in norm
    assert norm == "ଅତିବୁଦ୍ଧି ପଡା"

    # 2. Odia nukta decomposition to canonical composite
    decomposed_da = "ଡ\u0B3Cିମ୍ବୋ" # ଡ + nukta
    assert normalize_unicode_representation(decomposed_da) == "ଡ଼ିମ୍ବୋ"


def test_district_isolation():
    # Anantapur in Cuttack (dCode=3, tCode=1, mCode=88) vs Mayurbhanj/other
    rec_cuttack, status_cuttack, _ = VerifiedBhulekhCatalog.lookup(
        district_id="3",
        tahasil_id="1",
        village_name="ଅନନ୍ତପୁର"
    )
    assert status_cuttack in (ResolutionStatus.EXACT, ResolutionStatus.NORMALIZED_EXACT)
    assert rec_cuttack["bhulekh_district_id"] == "3"
    assert rec_cuttack["bhulekh_tahasil_id"] == "1"

    # In a district where Anantapur does not exist under that tahasil
    rec_other, status_other, _ = VerifiedBhulekhCatalog.lookup(
        district_id="15", # Bargarh
        tahasil_id="1",  # Atabira
        village_name="ଅନନ୍ତପୁର"
    )
    assert status_other == ResolutionStatus.NOT_FOUND
    assert rec_other is None


def test_tahasil_isolation():
    # Village within Tahasil 1 should not resolve under Tahasil 4
    rec_wrong_tah, status_wrong_tah, _ = VerifiedBhulekhCatalog.lookup(
        district_id="15", # Bargarh
        tahasil_id="4",  # Wrong Tahasil
        village_name="ଚକୁଳି"
    )
    assert status_wrong_tah == ResolutionStatus.NOT_FOUND
    assert rec_wrong_tah is None


def test_unknown_village_fails_closed():
    rec, status, _ = VerifiedBhulekhCatalog.lookup(
        district_id="7",
        tahasil_id="4",
        village_name="NON_EXISTENT_VILLAGE_XYZ_999"
    )
    assert status == ResolutionStatus.NOT_FOUND
    assert rec is None


def test_resolve_mouza_option_exact_and_level0():
    options = [
        {"value": "317", "text": "ଡ଼ିମ୍ବୋ"},
        {"value": "33", "text": "ଅତିବୁଦ୍ଧି ପଡା"},
        {"value": "67", "text": "ଅମୃତପଡା"},
    ]
    # G_Dimbo resolution
    status, matched_opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="7",
        tahasil_id="4",
        gis_village_name="ଡ଼ିମ୍ବୋ",
        gis_village_id=None,
        available_options=options,
    )
    assert status in (ResolutionStatus.EXACT, ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.VERIFIED_MAPPED)
    assert matched_opt is not None
    assert matched_opt["value"] == "317"
    assert matched_opt["text"] == "ଡ଼ିମ୍ବୋ"


def test_regression_core_parcels_identity():
    # 1. Chakuli (Bargarh / Atabira)
    rec1, s1, _ = VerifiedBhulekhCatalog.lookup("15", "1", "ଚକୁଳି")
    assert rec1 is not None
    assert rec1["bhulekh_mouza_id"] == "61"

    # 2. G_Dimbo (Keonjhar / Keonjhar Sadar)
    rec2, s2, _ = VerifiedBhulekhCatalog.lookup("7", "4", "ଡ଼ିମ୍ବୋ")
    assert rec2 is not None
    assert rec2["bhulekh_mouza_id"] == "317"

    # 3. Raghunathpur Jali (Khordha / Bhubaneswar)
    rec3, s3, _ = VerifiedBhulekhCatalog.lookup("20", "2", "ରଘୁନାଥପୁର ଜଳି")
    assert rec3 is not None
    assert rec3["bhulekh_mouza_id"] == "359"
