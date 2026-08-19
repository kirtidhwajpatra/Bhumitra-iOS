"""
Phase 3.22B — Live Odia RoR Identity Verification Test Suite
Validates deterministic ID-backed cross-script verification for G_Dimbo Plot 671, G_Dimbo Plot 489,
and G_Keri 271 Plot 1050, and enforces strict fail-closed adversarial security boundaries.
"""
import pytest
from bs4 import BeautifulSoup
from fastapi.testclient import TestClient

from app import create_app
from scrapers.bhulekh_scraper import verify_ror_result
from models.ror_response import RoRVerificationStatus


@pytest.fixture
def client():
    app = create_app()
    return TestClient(app)


def test_1_phase3_22b_dimbo_671_odia_verification():
    """Screenshot Case: Keonjhar / Sadar / G_Dimbo / Plot 671 with Odia portal labels verifies."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: ଡିମ୍ବୋ</td></tr>
            <tr><td>Plot: 671</td><td>Khata: 230</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "671")
    assert v.status == RoRVerificationStatus.VERIFIED
    assert v.location_match is True
    assert v.plot_match is True


def test_2_phase3_22b_dimbo_489_odia_verification():
    """Case A: Keonjhar / Sadar / G_Dimbo / Plot 489 with Odia portal labels verifies."""
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


def test_3_phase3_22b_keri_1050_odia_verification():
    """Case B: Keonjhar / Sadar / G_Keri 271 / Plot 1050 with Odia portal labels verifies."""
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


def test_4_adversarial_plot_fraction_fails_closed():
    """Adversarial: Requested 671 vs returned 671/1 fails closed."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: ଡିମ୍ବୋ</td></tr>
            <tr><td>Plot: 671/1</td><td>Khata: 230</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "671")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.plot_match is False


def test_5_adversarial_wrong_tahasil_fails_closed():
    """Adversarial: Requested Keonjhar Sadar vs returned Anandapur fails closed."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ଆନନ୍ଦପୁର</td><td>Village: ଡିମ୍ବୋ</td></tr>
            <tr><td>Plot: 671</td><td>Khata: 230</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "671")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.location_match is False
