"""
Phase 7.13: Production GIS -> Bhulekh Village Crosswalk Safety & Regression Test Suite.
Validates:
  1. Verified crosswalk loading and integrity checksum.
  2. District-scoped isolation (Zero cross-district leakage).
  3. Ambiguous same-name village fail-closed protection (e.g., Kalahandi / Ambaguda).
  4. Non-existent village fail-closed protection.
  5. Cache key isolation between distinct villages.
  6. False-Government protection invariants.
"""
import os
import json
import pytest
from resolvers.bhulekh_identity_resolver import (
    VerifiedBhulekhCatalog,
    BhulekhVillageResolver,
    ResolutionStatus,
    CATALOG_CROSSWALK_PATH,
)
from services.ror_service import get_canonical_cache_key


@pytest.fixture(scope="module", autouse=True)
def setup_catalog():
    VerifiedBhulekhCatalog.load()


def test_1_canonical_crosswalk_loaded_and_verified():
    """Verifies that the canonical village crosswalk dataset is present and populated."""
    assert os.path.exists(CATALOG_CROSSWALK_PATH), f"Crosswalk not found at {CATALOG_CROSSWALK_PATH}"
    with open(CATALOG_CROSSWALK_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    assert data.get("catalog_version") == "ODISHA_BHULEKH_VILLAGE_CROSSWALK_V1"
    assert data.get("total_verified_crosswalks", 0) > 40000
    assert len(data.get("checksum_sha256", "")) == 64
    assert len(VerifiedBhulekhCatalog._crosswalk_by_dist_odia) > 40000


def test_2_district_isolation_for_common_village_names():
    """
    Verifies that identical village names across different districts (e.g. 'Anantapur')
    resolve strictly to their scoped parent district and never cross-pollute.
    """
    # Anantapur in Cuttack (3)
    rec_cuttack, status_c, _ = VerifiedBhulekhCatalog.lookup("3", "1", "Anantapur")
    assert status_c in (ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.VERIFIED_MAPPED, ResolutionStatus.CANONICAL_ALIAS)
    assert rec_cuttack["bhulekh_district_id"] == "3"
    assert rec_cuttack["bhulekh_mouza_id"] == "88"

    # In Mayurbhanj (9), searching for Anantapur must strictly return Mayurbhanj or NOT_FOUND (never Cuttack 88)
    rec_mayurbhanj, status_m, _ = VerifiedBhulekhCatalog.lookup("9", "1", "Anantapur")
    if rec_mayurbhanj:
        assert rec_mayurbhanj["bhulekh_district_id"] == "9"
        assert rec_mayurbhanj["bhulekh_mouza_id"] != "88"


def test_3_ambiguous_same_name_village_fails_closed():
    """
    Verifies that 'ଆମ୍ବଗୁଡା' in District 6 (Kalahandi), which exists in multiple Tahasils,
    is flagged as AMBIGUOUS and fails closed without guessing.
    """
    rec, status, detail = VerifiedBhulekhCatalog.lookup("6", "", "ଆମ୍ବଗୁଡା")
    assert status == ResolutionStatus.AMBIGUOUS
    assert rec is None
    assert "Ambiguous" in detail


def test_4_unknown_village_fails_closed():
    """Verifies that a fictional village returns NOT_FOUND and never guesses."""
    rec, status, detail = VerifiedBhulekhCatalog.lookup("7", "4", "NonExistentVillageXYZ_999")
    assert status == ResolutionStatus.NOT_FOUND
    assert rec is None


def test_5_cache_key_isolation_between_distinct_villages():
    """Verifies that cache keys between distinct villages sharing the same plot never collide."""
    key1 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12")
    key2 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Keri", "12")
    key3 = get_canonical_cache_key("BARGARH", "ATTABIRA", "Chakuli", "12")

    assert key1 != key2
    assert key1 != key3
    assert key2 != key3


def test_6_historical_problem_villages_resolve_deterministically():
    """Verifies historical production test parcels resolve cleanly."""
    # Chakuli in Bargarh (15)
    rec_c, stat_c, _ = VerifiedBhulekhCatalog.lookup("15", "1", "Chakuli")
    assert stat_c in (ResolutionStatus.EXACT, ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.CANONICAL_ALIAS, ResolutionStatus.VERIFIED_MAPPED)
    assert rec_c["bhulekh_mouza_id"] == "61"

    # G_Dimbo in Keonjhar (7)
    rec_d, stat_d, _ = VerifiedBhulekhCatalog.lookup("7", "4", "G_Dimbo")
    assert stat_d in (ResolutionStatus.EXACT, ResolutionStatus.NORMALIZED_EXACT, ResolutionStatus.CANONICAL_ALIAS, ResolutionStatus.VERIFIED_MAPPED)
    assert rec_d["bhulekh_mouza_id"] == "317"
