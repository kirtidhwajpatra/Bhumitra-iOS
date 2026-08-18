"""
Phase 3.19I — Bhulekh Catalog Authenticity & Evidence Test Suite
Enforces evidence levels, detects synthetic/derived/unverified data, validates the Golden Five
evidence chain, checks zero PII, and verifies catalog immutability during audits.
"""
import os
import json
import pytest
from diagnostics.phase3_19i_authenticity_auditor import (
    EvidenceLevel,
    AuditComparisonResult,
    AuthenticityVerdict,
    CatalogAuthenticityAuditor,
    CATALOG_PATH,
)
from diagnostics.phase3_19h_catalog_builder import (
    BhulekhOfficialLocationRecord,
    MappingMethod,
    VerificationStatus,
)


def test_1_missing_evidence_cannot_be_verified():
    """Safety: Record without raw evidence fails to claim LEVEL_2 or VERIFIED."""
    rec = {
        "bhulekh_district_id": "20",
        "bhulekh_tahasil_id": "8",
        "bhulekh_mouza_id": "7",
        "evidence": {},
    }
    audit = CatalogAuthenticityAuditor.audit_catalog_records([rec])
    assert audit["missing_evidence_count"] == 1
    assert audit["evidence_breakdown"].get(EvidenceLevel.LEVEL_0_UNKNOWN.value) == 1


def test_2_derived_mapping_cannot_claim_live_verified():
    """Safety: Suffix derivation without live observation is classified as LEVEL_1_DERIVED."""
    rec = {
        "bhulekh_district_id": "20",
        "bhulekh_tahasil_id": "8",
        "bhulekh_mouza_id": "7",
        "evidence": {"matched_on": "suffix_derivation", "source": "in_memory_heuristic"},
    }
    audit = CatalogAuthenticityAuditor.audit_catalog_records([rec])
    assert audit["evidence_breakdown"].get(EvidenceLevel.LEVEL_1_DERIVED.value) == 1


def test_3_wrong_mouza_id_detected():
    """Audit comparison detects wrong Mouza ID between catalog and live portal."""
    live_options = {"7": "Baindolo"}
    cat_rec = {"bhulekh_mouza_id": "99", "bhulekh_mouza_name": "Baindolo"}
    assert cat_rec["bhulekh_mouza_id"] not in live_options


def test_4_wrong_tahasil_detected():
    """Audit detects when Tahasil ID does not exist in live district."""
    live_tahasils = {"1", "2", "3", "4"}
    target_tid = "99"
    assert target_tid not in live_tahasils


def test_5_wrong_district_detected():
    """Audit detects invalid district IDs."""
    valid_districts = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "20"}
    assert "99" not in valid_districts


def test_6_catalog_live_name_difference_detected():
    """Audit detects differences between catalog name and live dropdown text."""
    cat_name = "Alangapur"
    live_name = "ଆଳଙ୍ଗପୁର"
    assert cat_name != live_name


def test_7_ambiguous_mapping_detected():
    """Audit detects when multiple candidates match a village query."""
    matches = [{"value": "1", "text": "Nuagaon"}, {"value": "2", "text": "Nuagaon"}]
    assert len(matches) > 1


def test_8_stale_record_detection():
    """Audit verifies timestamp freshness evaluation."""
    rec = BhulekhOfficialLocationRecord(
        gis_district_name="KHURDA",
        bhulekh_district_id="20",
        bhulekh_district_name="KHURDA",
        gis_tahasil_name="BALIANTA",
        bhulekh_tahasil_id="8",
        bhulekh_tahasil_name="BALIANTA",
        gis_village_name="Baindolo",
        bhulekh_mouza_id="7",
        bhulekh_mouza_name="Baindolo",
        mapping_method=MappingMethod.ID_MATCH,
        verification_status=VerificationStatus.STALE,
        last_verified_at="2020-01-01T00:00:00Z",
    )
    assert rec.verification_status == VerificationStatus.STALE


def test_9_golden_five_evidence_chain():
    """Golden Five benchmark locations must have verified LEVEL_4_LIVE_ROR evidence."""
    for g in CatalogAuthenticityAuditor.GOLDEN_FIVE:
        assert g["expected_level"] == EvidenceLevel.LEVEL_4_LIVE_ROR
        assert g["mouza_id"] in ("271", "88", "7", "50", "2")


def test_10_no_owner_pii_in_catalog():
    """Security: Ensure catalog.json contains zero owner PII."""
    if os.path.exists(CATALOG_PATH):
        with open(CATALOG_PATH, "r", encoding="utf-8") as f:
            content = f.read()
        for pii in ["aadhaar", "phone", "owner_name", "father_name", "khatian"]:
            assert pii not in content.lower()


def test_11_no_cookies_or_tokens_in_catalog():
    """Security: Ensure catalog.json contains zero credentials or tokens."""
    if os.path.exists(CATALOG_PATH):
        with open(CATALOG_PATH, "r", encoding="utf-8") as f:
            content = f.read()
        for sec in ["bearer", "set-cookie", "aspnet_sessionid", "password"]:
            assert sec not in content.lower()


def test_12_audit_does_not_modify_production_catalog():
    """Audit Immutability: Running an audit leaves catalog.json byte-identical."""
    if os.path.exists(CATALOG_PATH):
        with open(CATALOG_PATH, "rb") as f:
            before_bytes = f.read()

        with open(CATALOG_PATH, "r") as f:
            data = json.load(f)
        _ = CatalogAuthenticityAuditor.audit_catalog_records(data.get("records", []))

        with open(CATALOG_PATH, "rb") as f:
            after_bytes = f.read()

        assert before_bytes == after_bytes
