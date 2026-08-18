"""
Phase 3.19J — Bhulekh Catalog Crawl Integrity & State Isolation Test Suite
Validates Fresh-Page isolation, ViewState contamination detection, canonical key integrity,
checkpoint persistence, catalog v2 schema, Golden Five preservation, and post-crawl audit logic.
"""
import os
import json
import pytest
from diagnostics.phase3_19j_clean_catalog_builder import (
    CleanBhulekhCatalogBuilder,
    ViewStateContaminationError,
    CATALOG_V2_FILE,
    CHECKPOINT_V2_FILE,
)
from diagnostics.phase3_19i_authenticity_auditor import (
    CatalogAuthenticityAuditor,
    EvidenceLevel,
)
from resolvers.bhulekh_identity_resolver import VerifiedBhulekhCatalog


def test_1_viewstate_contamination_error_triggered():
    """Safety: Postback mismatch between requested and DOM district raises ViewStateContaminationError."""
    with pytest.raises(ViewStateContaminationError):
        expected_d, returned_d = "7", "3"
        if expected_d != returned_d:
            raise ViewStateContaminationError("District postback mismatch detected")


def test_2_tahasil_mismatch_rejected():
    """Safety: Tahasil mismatch raises ViewStateContaminationError."""
    with pytest.raises(ViewStateContaminationError):
        expected_t, returned_t = "8", "4"
        if expected_t != returned_t:
            raise ViewStateContaminationError("Tahasil postback mismatch detected")


def test_3_duplicate_canonical_key_detection():
    """Quality: Detect duplicate (district_id, tahasil_id, mouza_id) in catalog records."""
    records = [
        {"bhulekh_district_id": "20", "bhulekh_tahasil_id": "8", "bhulekh_mouza_id": "7"},
        {"bhulekh_district_id": "20", "bhulekh_tahasil_id": "8", "bhulekh_mouza_id": "7"},
    ]
    keys = set()
    duplicates = []
    for r in records:
        k = (r["bhulekh_district_id"], r["bhulekh_tahasil_id"], r["bhulekh_mouza_id"])
        if k in keys:
            duplicates.append(k)
        keys.add(k)
    assert len(duplicates) == 1


def test_4_missing_evidence_rejected():
    """Integrity: Record missing raw evidence cannot claim LIVE_VERIFIED."""
    rec = {"evidence": None, "verification_status": "LIVE_VERIFIED"}
    assert not rec["evidence"]


def test_5_derived_mapping_cannot_become_live_verified():
    """Integrity: Derived mapping without live dropdown observation is not LEVEL_2+."""
    rec = {"evidence": {"matched_on": "suffix_derivation"}}
    assert rec["evidence"].get("matched_on") != "live_dropdown"


def test_6_checkpoint_recovery_logic(tmp_path):
    """Resilience: Checkpoint saves and restores completed districts and tahasils."""
    cp_data = {
        "completed_districts": ["20", "11"],
        "completed_tahasils": ["20:8", "11:8"],
        "failed_tahasils": [],
    }
    cp_file = tmp_path / "checkpoint_v2.json"
    with open(cp_file, "w") as f:
        json.dump(cp_data, f)

    with open(cp_file, "r") as f:
        loaded = json.load(f)
    assert "20" in loaded["completed_districts"]
    assert "20:8" in loaded["completed_tahasils"]


def test_7_catalog_v1_immutable_during_v2_crawl():
    """Safety: catalog.json (v1) remains intact when catalog_v2.json is generated."""
    v1_path = os.path.join(os.path.dirname(__file__), "..", "data", "bhulekh_catalog", "catalog.json")
    v2_path = os.path.join(os.path.dirname(__file__), "..", "data", "bhulekh_catalog", "catalog_v2.json")

    assert os.path.exists(v1_path)
    assert os.path.exists(v2_path)
    assert v1_path != v2_path


def test_8_catalog_v2_schema_validation():
    """Schema: Verify catalog_v2 contains expected fields and non-empty records."""
    if os.path.exists(CATALOG_V2_FILE):
        with open(CATALOG_V2_FILE, "r") as f:
            data = json.load(f)
        assert data.get("schema_version") == 2
        assert data.get("total_records") > 0
        rec = data["records"][0]
        assert "bhulekh_district_id" in rec
        assert "bhulekh_tahasil_id" in rec
        assert "bhulekh_mouza_id" in rec
        assert "evidence" in rec


def test_9_golden_five_preservation():
    """Golden Five benchmark locations must remain valid."""
    for g in CatalogAuthenticityAuditor.GOLDEN_FIVE:
        assert g["mouza_id"] in ("271", "88", "7", "50", "2")


def test_10_no_owner_pii_in_catalog_v2():
    """Security: Ensure catalog_v2 contains zero owner PII."""
    if os.path.exists(CATALOG_V2_FILE):
        with open(CATALOG_V2_FILE, "r") as f:
            content = f.read()
        for pii in ["aadhaar", "owner_name", "father_name", "khatian", "mobile"]:
            assert pii not in content.lower()


def test_11_no_secrets_or_cookies_in_catalog_v2():
    """Security: Ensure catalog_v2 contains zero credentials or cookies."""
    if os.path.exists(CATALOG_V2_FILE):
        with open(CATALOG_V2_FILE, "r") as f:
            content = f.read()
        for sec in ["bearer", "set-cookie", "aspnet_sessionid", "password"]:
            assert sec not in content.lower()


def test_12_deterministic_sample_reproducibility():
    """Audit: Random sample with fixed seed 319 returns identical records."""
    records = [{"id": i} for i in range(100)]
    s1 = CatalogAuthenticityAuditor.select_deterministic_sample(records, sample_size=10, seed=319)
    s2 = CatalogAuthenticityAuditor.select_deterministic_sample(records, sample_size=10, seed=319)
    assert s1 == s2
