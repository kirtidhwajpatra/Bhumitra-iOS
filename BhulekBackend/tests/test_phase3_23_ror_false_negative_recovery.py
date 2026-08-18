"""
Phase 3.23 — RoR False Negative Recovery & Precision Verification Test Suite
Validates fix for Case A (Plot 489 in G_Dimbo with Odia DOM labels) and Case B (Plot 1050 in G_Keri 271 / Mouza 330),
preserves strict adversarial plot number isolation, and enforces negative security boundaries.
"""
import pytest
from bs4 import BeautifulSoup

from scrapers.bhulekh_scraper import verify_ror_result
from models.ror_response import RoRVerificationStatus
from resolvers.bhulekh_identity_resolver import (
    CadastralParcelIdentity,
    resolve_bhulekh_identity,
    VerifiedBhulekhCatalog,
)


def test_1_case_a_dimbo_489_bilingual_verification_success():
    """Case A Fix: Odia labels (କେନ୍ଦୁଝର, ସଦର, ଡିମ୍ବୋ) match requested Keonjhar/Sadar/G_Dimbo."""
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


def test_2_case_b_keri_1050_mouza_330_resolution():
    """Case B Fix: G_Keri 271 in Keonjhar Sadar resolves to Mouza 330 (କେରି) and verifies."""
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


def test_3_cuttack_anantapur_odia_verification():
    """Bilingual: Odia labels for Cuttack / Athagarh / Anantapur match."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କଟକ</td><td>Tahasil: ଆଠଗଡ</td><td>Village: ଅନନ୍ତପୁର</td></tr>
            <tr><td>Plot: 101</td><td>Khata: 125/110</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "CUTTACK", "ATHAGARH", "Anantapur-64", "101")
    assert v.status == RoRVerificationStatus.VERIFIED
    assert v.location_match is True
    assert v.plot_match is True


def test_4_negative_security_wrong_plot_fails_closed():
    """Negative Security: Requested 489 but returned 489/1 fails closed."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: ଡିମ୍ବୋ</td></tr>
            <tr><td>Plot: 489/1</td><td>Khata: 212</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "489")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.plot_match is False


def test_5_negative_security_wrong_tahasil_fails_closed():
    """Negative Security: Returned Anandapur when Keonjhar Sadar requested fails closed."""
    html = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ଆନନ୍ଦପୁର</td><td>Village: କେରି</td></tr>
            <tr><td>Plot: 1050</td><td>Khata: 139/57</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Keri 271", "1050")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.location_match is False


def test_6_negative_security_wrong_district_fails_closed():
    """Negative Security: Returned Mayurbhanj when Keonjhar requested fails closed."""
    html = """
    <html><body>
        <table>
            <tr><td>District: ମୟୂରଭଞ୍ଜ</td><td>Tahasil: ସଦର</td><td>Village: ଡିମ୍ବୋ</td></tr>
            <tr><td>Plot: 489</td><td>Khata: 212</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "489")
    assert v.status == RoRVerificationStatus.MISMATCH
    assert v.location_match is False
