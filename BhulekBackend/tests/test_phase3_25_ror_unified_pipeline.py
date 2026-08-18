"""
Phase 3.25 — Unified RoR Pipeline & Manual Search Alignment Test Suite
Validates that Map Selection and Manual Search share the exact same canonical location hierarchy,
official Bhulekh IDs from catalog_v3.json, and identical verification standards.
"""
import pytest
from fastapi.testclient import TestClient
from bs4 import BeautifulSoup

from app import create_app
from scrapers.bhulekh_scraper import verify_ror_result
from models.ror_response import RoRVerificationStatus
from resolvers.bhulekh_identity_resolver import VerifiedBhulekhCatalog


@pytest.fixture
def client():
    app = create_app()
    return TestClient(app)


def test_1_hierarchy_endpoints_use_catalog_v3(client):
    """Hierarchy: /districts, /tahasils, /villages are populated from catalog_v3."""
    # Districts
    res_d = client.get("/api/v1/districts")
    assert res_d.status_code == 200
    assert len(res_d.json()) == 30

    # Tahasils for Keonjhar (7)
    res_t = client.get("/api/v1/tahasils?district_id=7")
    assert res_t.status_code == 200
    assert len(res_t.json()) == 13

    # Villages for Keonjhar Sadar (7, 4)
    res_v = client.get("/api/v1/villages?district_id=7&tahasil_id=4")
    assert res_v.status_code == 200
    villages = res_v.json()
    assert len(villages) >= 250

    # Ensure Mouza 330 (Keri) and 317 (Dimbo) are present with exact official IDs
    keri = next((v for v in villages if v["id"] == "330"), None)
    dimbo = next((v for v in villages if v["id"] == "317"), None)
    assert keri is not None
    assert dimbo is not None


def test_2_unified_case_a_dimbo_489(client):
    """Case A: G_Dimbo / Plot 489 passes canonical verification."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: ଡିମ୍ବୋ</td></tr>
            <tr><td>Plot: 489</td><td>Khata: 212</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "489")
    assert v.status == RoRVerificationStatus.VERIFIED
    assert v.location_match is True
    assert v.plot_match is True


def test_3_unified_case_b_keri_1050(client):
    """Case B: G_Keri 271 / Mouza 330 / Plot 1050 passes canonical verification."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: କେରି</td></tr>
            <tr><td>Plot: 1050</td><td>Khata: 139/57</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Keri 271", "1050")
    assert v.status == RoRVerificationStatus.VERIFIED
    assert v.location_match is True
    assert v.plot_match is True


def test_4_negative_security_mismatch_fails_closed():
    """Security: Returning wrong village or wrong plot fails closed."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: ମାଳିଗାଁ</td></tr>
            <tr><td>Plot: 1050</td><td>Khata: 139/57</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Keri 271", "1050")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.location_match is False
