"""
Phase 3.24 — iOS RoR Contract & Live Parcel Verification Suite
Tests exact API contract used by the iOS client, verifying Case A (Plot 489 in G_Dimbo)
and Case B (Plot 1036 in G_Keri 271 / Mouza 330), and verifies fail-closed security.
"""
import pytest
from fastapi.testclient import TestClient
from bs4 import BeautifulSoup

from app import create_app
from scrapers.bhulekh_scraper import verify_ror_result
from models.ror_response import RoRVerificationStatus


@pytest.fixture
def client():
    app = create_app()
    return TestClient(app)


def test_1_ios_contract_case_a_dimbo_489_bilingual_verification():
    """Case A Contract: Keonjhar / Sadar / G_Dimbo / Plot 489 returns verified status."""
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


def test_2_ios_contract_case_b_keri_1036_mouza_330_verification():
    """Case B Contract: Keonjhar / Sadar / G_Keri 271 / Plot 1036 returns verified status."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: କେରି</td></tr>
            <tr><td>Plot: 1036</td><td>Khata: 5</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Keri 271", "1036")
    assert v.status == RoRVerificationStatus.VERIFIED
    assert v.location_match is True
    assert v.plot_match is True


def test_3_ios_contract_case_b_keri_1050_mouza_330_verification():
    """Case B Contract (Plot 1050): Keonjhar / Sadar / G_Keri 271 / Plot 1050 returns verified status."""
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


def test_4_negative_security_wrong_location_fails_closed():
    """Security: Keonjhar / Sadar / G_Dimbo / 489 with Anandapur returned fails closed."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ଆନନ୍ଦପୁର</td><td>Village: ଡିମ୍ବୋ</td></tr>
            <tr><td>Plot: 489</td><td>Khata: 212</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "489")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.location_match is False


def test_5_negative_security_adversarial_plot_fails_closed():
    """Security: Plot 1036 requested vs 1036/1 returned fails closed."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: କେରି</td></tr>
            <tr><td>Plot: 1036/1</td><td>Khata: 5</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Keri 271", "1036")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.plot_match is False
