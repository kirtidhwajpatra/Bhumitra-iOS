"""
Phase 3.19H — Odisha-Wide Bhulekh Official Location Catalog Test Suite
Validates canonical location record schemas, catalog indexing, Level 0 catalog matching,
checkpoint persistence, Odia Unicode preservation, and fail-closed safety invariants.
"""
import os
import json
import pytest
from datetime import datetime, timezone

from diagnostics.phase3_19h_catalog_builder import (
    BhulekhOfficialLocationRecord,
    CatalogCheckpoint,
    BhulekhCatalogBuilder,
    MappingMethod,
    VerificationStatus,
    CATALOG_VERSION,
    SCHEMA_VERSION,
)
from resolvers.bhulekh_identity_resolver import (
    CadastralParcelIdentity,
    BhulekhVillageResolver,
    ResolutionStatus,
    VerifiedBhulekhCatalog,
    resolve_bhulekh_identity,
)


def test_1_canonical_location_record_schema():
    """Verify BhulekhOfficialLocationRecord fields and types."""
    rec = BhulekhOfficialLocationRecord(
        gis_district_id="20",
        gis_district_name="KHURDA",
        bhulekh_district_id="20",
        bhulekh_district_name="KHURDA",
        bhulekh_district_odia_name="ଖୋର୍ଦ୍ଧା",
        gis_tahasil_id="2008",
        gis_tahasil_name="BALIANTA",
        bhulekh_tahasil_id="8",
        bhulekh_tahasil_name="BALIANTA",
        bhulekh_tahasil_odia_name="ବାଲିଅନ୍ତା",
        gis_village_id="2008007",
        gis_village_name="Baindolo",
        bhulekh_mouza_id="7",
        bhulekh_mouza_name="ବାଇଁଣ୍ଡୋଳ",
        bhulekh_mouza_odia_name="ବାଇଁଣ୍ଡୋଳ",
        mapping_method=MappingMethod.GIS_SUFFIX_VERIFIED,
        verification_status=VerificationStatus.VERIFIED,
        evidence={"matched_on": "7_digit_suffix_verified", "source": "bhulekh.ori.nic.in"},
    )
    assert rec.catalog_version == CATALOG_VERSION
    assert rec.schema_version == SCHEMA_VERSION
    assert rec.bhulekh_tahasil_id == "8"
    assert rec.bhulekh_mouza_id == "7"
    assert rec.bhulekh_mouza_odia_name == "ବାଇଁଣ୍ଡୋଳ"
    assert rec.verification_status == VerificationStatus.VERIFIED


def test_2_catalog_validation_and_duplicate_detection():
    """Quality Check: Detect duplicate (district_id, tahasil_id, mouza_id) and conflicting GIS mappings."""
    rec1 = BhulekhOfficialLocationRecord(
        gis_district_name="KHURDA",
        bhulekh_district_id="20",
        bhulekh_district_name="KHURDA",
        gis_tahasil_name="BALIANTA",
        bhulekh_tahasil_id="8",
        bhulekh_tahasil_name="BALIANTA",
        gis_village_id="2008007",
        gis_village_name="Baindolo",
        bhulekh_mouza_id="7",
        bhulekh_mouza_name="Baindolo",
        mapping_method=MappingMethod.ID_MATCH,
        verification_status=VerificationStatus.VERIFIED,
    )
    rec2_duplicate = BhulekhOfficialLocationRecord(
        gis_district_name="KHURDA",
        bhulekh_district_id="20",
        bhulekh_district_name="KHURDA",
        gis_tahasil_name="BALIANTA",
        bhulekh_tahasil_id="8",
        bhulekh_tahasil_name="BALIANTA",
        gis_village_id="2008007",
        gis_village_name="Baindolo",
        bhulekh_mouza_id="7",
        bhulekh_mouza_name="Baindolo",
        mapping_method=MappingMethod.ID_MATCH,
        verification_status=VerificationStatus.VERIFIED,
    )

    res = BhulekhCatalogBuilder.validate_catalog([rec1, rec2_duplicate])
    assert res["valid"] is False
    assert res["duplicate_count"] == 1


def test_3_checkpoint_serialization_and_recovery(tmp_path):
    """Test checkpoint state saves and resumes correctly."""
    cp_file = tmp_path / "checkpoint.json"
    cp = CatalogCheckpoint(
        last_district_id="20",
        last_tahasil_id="8",
        completed_districts=["20"],
        completed_tahasils=["20:8"],
        total_records_cataloged=150,
        total_mouzas_discovered=150,
    )
    with open(cp_file, "w", encoding="utf-8") as f:
        json.dump(cp.model_dump(), f)

    builder = BhulekhCatalogBuilder(checkpoint_dir=str(tmp_path))
    assert builder.checkpoint.last_district_id == "20"
    assert "20" in builder.checkpoint.completed_districts
    assert "20:8" in builder.checkpoint.completed_tahasils
    assert builder.checkpoint.total_records_cataloged == 150


def test_4_level_0_verified_catalog_resolver_matching():
    """Verify Level 0 catalog match is prioritized when available."""
    options = [
        {"value": "7", "text": "ବାଇଁଣ୍ଡୋଳ"},
        {"value": "50", "text": "ଆଳଙ୍ଗପୁର"},
    ]

    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="20",
        tahasil_id="8",
        gis_village_name="Baindolo",
        gis_village_id="2008007",
        available_options=options,
    )
    assert status == ResolutionStatus.VERIFIED_MAPPED
    assert opt["value"] == "7"
    assert opt["text"] == "ବାଇଁଣ୍ଡୋଳ"


def test_5_zero_pii_or_secrets_in_catalog():
    """Security Invariant: Catalog records never contain owner names, phone, Aadhaar, or passwords."""
    rec = BhulekhOfficialLocationRecord(
        gis_district_name="PURI",
        bhulekh_district_id="11",
        bhulekh_district_name="PURI",
        gis_tahasil_name="ASTARANG",
        bhulekh_tahasil_id="8",
        bhulekh_tahasil_name="ASTARANG",
        gis_village_name="Alangpur",
        bhulekh_mouza_id="50",
        bhulekh_mouza_name="Alangpur",
        mapping_method=MappingMethod.EXACT_NAME,
        verification_status=VerificationStatus.VERIFIED,
    )
    dump_str = json.dumps(rec.model_dump())
    forbidden_terms = ["aadhaar", "owner_name", "password", "bearer", "cookie", "mobile", "phone"]
    for term in forbidden_terms:
        assert term not in dump_str.lower()


def test_6_unmapped_village_fails_closed_without_guessing():
    """Safety Invariant: Unverified village returns NOT_FOUND with zero guessing."""
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="20",
        tahasil_id="8",
        gis_village_name="NonExistentVillageXYZ",
        gis_village_id="9999999",
        available_options=[{"value": "7", "text": "ବାଇଁଣ୍ଡୋଳ"}],
    )
    assert status == ResolutionStatus.NOT_FOUND
    assert opt is None
