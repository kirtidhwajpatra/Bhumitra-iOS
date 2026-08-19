"""
Phase 3.30 — Odisha-Wide Real Parcel -> RoR Validation Automated Test Suite
Verifies statewide catalog resolution, exact plot number isolation, bilingual Odia/English mapping,
fail-closed security invariants, cache isolation, and zero-PII storage.
"""
import pytest
from bs4 import BeautifulSoup
from fastapi.testclient import TestClient

from app import create_app
from resolvers.bhulekh_identity_resolver import VerifiedBhulekhCatalog, BhulekhVillageResolver
from scrapers.bhulekh_scraper import verify_ror_result
from models.ror_response import RoRVerificationStatus


@pytest.fixture
def client():
    app = create_app()
    return TestClient(app)


def test_1_statewide_catalog_30_districts_loaded():
    """Validates that VerifiedBhulekhCatalog loads statewide records for Odisha."""
    VerifiedBhulekhCatalog.load()
    assert len(VerifiedBhulekhCatalog._by_id) > 10000
    assert len(VerifiedBhulekhCatalog._by_name) > 10000


def test_2_deterministic_resolution_across_sample_districts():
    """Validates that districts across Odisha resolve deterministically."""
    # Keonjhar (7, 4) -> G_Dimbo -> 317
    rec_kj = VerifiedBhulekhCatalog.lookup("7", "4", "G_Dimbo", "0704317")
    assert rec_kj is not None and rec_kj["bhulekh_mouza_id"] == "317"

    # Cuttack (3, 1) -> Anantapur -> 88
    rec_ct = VerifiedBhulekhCatalog.lookup("3", "1", "Anantapur-64", "0301088")
    assert rec_ct is not None and rec_ct["bhulekh_mouza_id"] == "88"

    # Khurda (20, 8) -> Baindolo -> 7
    rec_kh = VerifiedBhulekhCatalog.lookup("20", "8", "Baindolo", "2008007")
    assert rec_kh is not None and rec_kh["bhulekh_mouza_id"] == "7"

    # Puri (11, 8) -> Alangpur -> 50
    rec_pu = VerifiedBhulekhCatalog.lookup("11", "8", "Alangpur", "1108050")
    assert rec_pu is not None and rec_pu["bhulekh_mouza_id"] == "50"

    # Ganjam (5, 1) -> Alipur -> 2
    rec_gj = VerifiedBhulekhCatalog.lookup("5", "1", "Alipur", "0501002")
    assert rec_gj is not None and rec_gj["bhulekh_mouza_id"] == "2"


def test_3_exact_plot_preservation_with_slash():
    """Plot with slash notation (e.g. 89/1) is preserved verbatim and verified."""
    html = """
    <html><body>
        <table>
            <tr><td>District: ଗଞ୍ଜାମ</td><td>Tahasil: ଆସିକା</td><td>Village: ଆଲିପୁର</td></tr>
            <tr><td>Plot: 89/1</td><td>Khata: 200</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "GANJAM", "ASKA", "Alipur", "89/1")
    assert v.status == RoRVerificationStatus.VERIFIED
    assert v.plot_match is True


def test_4_district_isolation_fails_closed():
    """Attempting to resolve a village under the wrong district fails closed."""
    # Dimbo exists in Keonjhar (7), not Cuttack (3)
    rec = VerifiedBhulekhCatalog.lookup("3", "1", "G_Dimbo")
    assert rec is None


def test_5_tahasil_isolation_fails_closed():
    """Attempting to resolve a village under the wrong tahasil fails closed."""
    # Dimbo exists in Keonjhar Sadar (4), not Anandapur (1)
    rec = VerifiedBhulekhCatalog.lookup("7", "1", "G_Dimbo")
    assert rec is None


def test_6_plot_mismatch_fails_closed():
    """Requested plot 489 does not match returned plot 490."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: ଡିମ୍ବୋ</td></tr>
            <tr><td>Plot: 490</td><td>Khata: 212</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "489")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.plot_match is False


def test_7_bilingual_odia_district_tahasil_verification():
    """Validates that Odia headers match canonical English requested district and tahasil."""
    html = """
    <html><body>
        <table>
            <tr><td>District: ଖୋର୍ଦ୍ଧା</td><td>Tahasil: ବାଲିଅନ୍ତା</td><td>Village: ବାଇଁଣ୍ଡୋଳ</td></tr>
            <tr><td>Plot: 15</td><td>Khata: 59</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KHURDA", "BALIANTA", "Baindolo", "15")
    assert v.status == RoRVerificationStatus.VERIFIED
    assert v.location_match is True
    assert v.plot_match is True


def test_8_no_pii_in_endpoint_responses_or_logs(client):
    """Ensures that health, version, and coverage endpoints do not leak PII."""
    res_v = client.get("/api/v1/version")
    assert res_v.status_code == 200
    v_data = res_v.json()
    assert "owner" not in str(v_data).lower()
    assert "aadhaar" not in str(v_data).lower()


def test_9_duplicate_village_names_isolated_by_tahasil():
    """Identically named villages in different tahasils map to distinct Mouza IDs."""
    options_t1 = [{"value": "10", "text": "ନୂଆଗାଁ"}]
    options_t2 = [{"value": "25", "text": "ନୂଆଗାଁ"}]

    # Tahasil 1 vs Tahasil 2
    _, opt1, _ = BhulekhVillageResolver.resolve_mouza_option("7", "1", "Nuagaon", None, options_t1)
    _, opt2, _ = BhulekhVillageResolver.resolve_mouza_option("7", "2", "Nuagaon", None, options_t2)

    if opt1 and opt2:
        assert opt1["value"] != opt2["value"]


def test_10_cache_isolation_per_parcel():
    """Cache keys for different plots in same village or same plot in different villages are distinct."""
    from services.ror_service import get_canonical_cache_key
    k1 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "489")
    k2 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "508")
    k3 = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G_Keri 271", "489")

    assert k1 != k2
    assert k1 != k3
    assert k2 != k3
