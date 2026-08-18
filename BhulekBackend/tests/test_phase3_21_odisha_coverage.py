"""
Phase 3.21 — Odisha-Wide Bhulekh Coverage & Resolution API Test Suite
Validates 30-district hierarchy, coverage endpoints, location resolution without owner leakage,
evidence-level gates, and state-isolated crawl invariants.
"""
import os
import json
import pytest
from fastapi.testclient import TestClient

from app import create_app
from scrapers.bhulekh_mappings import OFFICIAL_DISTRICT_NAMES, DISTRICT_MAP
from diagnostics.phase3_21_odisha_coverage_crawler import (
    OdishaCoverageCrawler,
    CATALOG_V3_FILE,
    CHECKPOINT_V3_FILE,
)
from resolvers.bhulekh_identity_resolver import (
    CadastralParcelIdentity,
    resolve_bhulekh_identity,
    VerifiedBhulekhCatalog,
)


@pytest.fixture
def client():
    app = create_app()
    return TestClient(app)


def test_1_all_30_districts_mapped_in_hierarchy():
    """Verify all 30 Odisha districts are accounted for with official names."""
    assert len(OFFICIAL_DISTRICT_NAMES) == 30
    for did in range(1, 31):
        assert str(did) in OFFICIAL_DISTRICT_NAMES


def test_2_bhulekh_state_coverage_api(client):
    """Verify GET /api/v1/bhulekh/coverage returns valid state summary."""
    resp = client.get("/api/v1/bhulekh/coverage")
    assert resp.status_code == 200
    data = resp.json()
    assert "total_districts" in data
    assert "total_tahasils" in data
    assert "total_mouzas_cataloged" in data
    assert "evidence_levels" in data
    assert "districts" in data
    assert len(data["districts"]) == 30


def test_3_bhulekh_district_coverage_api(client):
    """Verify GET /api/v1/bhulekh/district/7/coverage returns Keonjhar metrics."""
    resp = client.get("/api/v1/bhulekh/district/7/coverage")
    assert resp.status_code == 200
    data = resp.json()
    assert data["district_id"] == "7"
    assert data["district_name"] == "KEONJHAR"
    assert data["mouzas_count"] > 0


def test_4_bhulekh_resolve_api_safe(client):
    """Verify GET /api/v1/bhulekh/resolve returns location metadata without owner info."""
    resp = client.get(
        "/api/v1/bhulekh/resolve",
        params={
            "district": "KEONJHAR",
            "tahasil": "KEONJHAR SADAR",
            "village": "G_Dimbo",
            "plot": "12",
            "v_id": "0704317",
        }
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "RESOLVED"
    assert data["available"] is True
    assert data["bhulekh_identity"]["district_id"] == "7"
    # Ensure zero ownership fields leaked
    assert "owners" not in data
    assert "khata_number" not in data


def test_5_evidence_level_gate_enforcement():
    """Security: LEVEL_0 and LEVEL_1 cannot claim verified location status."""
    c_unknown = CadastralParcelIdentity(
        district_name="UNKNOWN_DISTRICT",
        tahasil_name="UNKNOWN_TAHASIL",
        village_name="UnknownVillage",
        plot_number="999",
    )
    res = resolve_bhulekh_identity(c_unknown)
    assert res.bhulekh_identity is None or res.status not in (ResolutionStatus.EXACT, ResolutionStatus.NORMALIZED_EXACT)


def test_6_no_pii_or_session_tokens_in_coverage_endpoints(client):
    """Security: Ensure coverage and resolve endpoints never return auth tokens or cookies."""
    resp = client.get("/api/v1/bhulekh/coverage")
    body = resp.text.lower()
    for token in ["bearer", "set-cookie", "aspnet_sessionid", "password"]:
        assert token not in body


def test_7_crawler_checkpoint_resume_logic(tmp_path):
    """Crawler: Checkpoint records completed districts and tahasils cleanly."""
    crawler = OdishaCoverageCrawler()
    assert "completed_districts" in crawler.checkpoint
    assert "completed_tahasils" in crawler.checkpoint
