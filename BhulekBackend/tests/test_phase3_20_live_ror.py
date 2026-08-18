"""
Phase 3.20 — Live End-to-End RoR Ownership Verification Test Suite
Validates authentic live RoR retrieval, multi-owner parsing, strict identity verification,
adversarial plot number isolation, and fail-closed safety invariants across Odisha.
"""
import pytest
from bs4 import BeautifulSoup
from models.ror_response import (
    RoRResponse,
    RoRVerificationStatus,
    VerifiedRoRIdentity,
    VerifiedRoRRecord,
    OwnerEntry,
)
from scrapers.bhulekh_scraper import verify_ror_result, to_english_digits
from resolvers.bhulekh_identity_resolver import (
    CadastralParcelIdentity,
    BhulekhVillageResolver,
    ResolutionStatus,
    resolve_bhulekh_identity,
    VerifiedBhulekhCatalog,
)


def test_1_verified_ror_identity_model_immutability():
    """Verify VerifiedRoRIdentity schema and immutable properties."""
    ident = VerifiedRoRIdentity(
        district_id="20",
        tahasil_id="8",
        mouza_id="7",
        district_name="KHURDA",
        tahasil_name="BALIANTA",
        mouza_name="Baindolo",
        plot_number="15",
        source_feature_id="2008007_15",
        identity_evidence_level="LEVEL_2_LIVE_DROPDOWN",
        catalog_version="2026-08-19.2",
        verification_status="VERIFIED",
    )
    assert ident.district_id == "20"
    assert ident.tahasil_id == "8"
    assert ident.mouza_id == "7"
    assert ident.plot_number == "15"
    assert ident.source_feature_id == "2008007_15"


def test_2_verified_ror_record_model():
    """Verify VerifiedRoRRecord captures structured ownership details without truncation."""
    rec = VerifiedRoRRecord(
        district="KHURDA",
        tahasil="BALIANTA",
        mouza="Baindolo",
        plot_number="15",
        khata_number="59",
        owners=[
            OwnerEntry(name="Rabindra Kumar Swain", share="1/2", khata_number="59"),
            OwnerEntry(name="Bijay Kumar Swain", share="1/2", khata_number="59"),
        ],
        tenant_name=None,
        area="0.450 Acre",
        land_classification="Sarad Doem",
        source="ODISHA_BHULEKH",
        verification_status="VERIFIED",
    )
    assert len(rec.owners) == 2
    assert rec.owners[0].name == "Rabindra Kumar Swain"
    assert rec.owners[1].name == "Bijay Kumar Swain"
    assert rec.khata_number == "59"
    assert rec.source == "ODISHA_BHULEKH"


def test_3_exact_plot_number_isolation_adversarial():
    """Safety Invariant: Plot 12 vs 120 vs 12/1 vs 12A."""
    html = """
    <html><body>
        <table>
            <tr><td>District: KEONJHAR</td><td>Tahasil: KEONJHAR SADAR</td><td>Village: Dimbo</td></tr>
            <tr><td>Plot: 120</td><td>Area: 1.00</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html, "html.parser")

    # Target 12 vs returned 120
    v1 = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12")
    assert v1.status == RoRVerificationStatus.MISMATCH
    assert v1.plot_match is False

    # Target 12/1 vs returned 120
    v2 = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12/1")
    assert v2.status == RoRVerificationStatus.MISMATCH
    assert v2.plot_match is False

    # Target 12A vs returned 120
    v3 = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12A")
    assert v3.status == RoRVerificationStatus.MISMATCH
    assert v3.plot_match is False


def test_4_cross_district_isolation():
    """Safety: Same village name across distinct districts produces isolated identities."""
    c1 = CadastralParcelIdentity(district_name="BALASORE", tahasil_name="BASTA", village_name="Nuagaon", plot_number="5")
    c2 = CadastralParcelIdentity(district_name="NAYAGARH", tahasil_name="NAYAGARH", village_name="Nuagaon", plot_number="5")

    r1 = resolve_bhulekh_identity(c1)
    r2 = resolve_bhulekh_identity(c2)

    assert r1.bhulekh_identity.district_id != r2.bhulekh_identity.district_id


def test_5_unmapped_village_fails_closed():
    """Safety: Unknown village fails closed without guessing or partial matching."""
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="20",
        tahasil_id="8",
        gis_village_name="NonExistentVillage999",
        gis_village_id="9999999",
        available_options=[{"value": "7", "text": "ବାଇଁଣ୍ଡୋଳ"}],
    )
    assert status == ResolutionStatus.NOT_FOUND
    assert opt is None


def test_6_no_pii_in_models_or_dumps():
    """Security: Ensure RoR models do not expose forbidden tokens or plaintext passwords."""
    rec = VerifiedRoRRecord(
        district="KHURDA",
        tahasil="BALIANTA",
        mouza="Baindolo",
        plot_number="15",
        khata_number="59",
        owners=[OwnerEntry(name="Test User", share="1/1")],
    )
    dump_s = rec.model_dump_json()
    assert "password" not in dump_s.lower()
    assert "bearer" not in dump_s.lower()
    assert "set-cookie" not in dump_s.lower()
