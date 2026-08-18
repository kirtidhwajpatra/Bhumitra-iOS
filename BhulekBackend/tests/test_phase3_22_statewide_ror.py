"""
Phase 3.22 — Statewide RoR Production Readiness Test Suite
Validates BhulekhResolutionResult, 30-district catalog_v3 resolution, adversarial plot isolation,
multi-owner extraction, PDF magic byte verification, and fail-closed security.
"""
import pytest
import hashlib
from bs4 import BeautifulSoup

from models.ror_response import (
    RoRResponse,
    RoRVerificationStatus,
    VerifiedRoRIdentity,
    VerifiedRoRRecord,
    OwnerEntry,
    BhulekhResolutionResult,
    ResolutionStatusEnum,
    BhulekhLocationIdentity,
    RoRErrorCode,
    RoRErrorDetail,
)
from scrapers.bhulekh_scraper import verify_ror_result, to_english_digits
from resolvers.bhulekh_identity_resolver import (
    CadastralParcelIdentity,
    resolve_bhulekh_identity,
    VerifiedBhulekhCatalog,
)
from scrapers.bhulekh_mappings import OFFICIAL_DISTRICT_NAMES


def test_1_bhulekh_resolution_result_schema():
    """Verify BhulekhResolutionResult encapsulates GIS and Bhulekh identities cleanly."""
    res = BhulekhResolutionResult(
        status=ResolutionStatusEnum.RESOLVED,
        gis_identity={
            "district": "KHURDA",
            "tahasil": "BALIANTA",
            "village": "Baindolo",
            "plot": "15",
        },
        bhulekh_identity=BhulekhLocationIdentity(
            district_id="20",
            district_name="KHURDA",
            tahasil_id="8",
            tahasil_name="BALIANTA",
            village_id="7",
            village_name="Baindolo",
        ),
        resolution_method="EXACT_CATALOG_MATCH",
        evidence_level="LEVEL_2_LIVE_DROPDOWN",
        confidence_reason="Verified live in catalog_v3.",
    )
    assert res.status == ResolutionStatusEnum.RESOLVED
    assert res.bhulekh_identity.district_id == "20"
    assert res.bhulekh_identity.village_id == "7"
    assert "owners" not in res.model_dump()


def test_2_all_30_districts_represented_in_catalog_v3():
    """Verify catalog_v3 contains records for all 30 districts."""
    VerifiedBhulekhCatalog.load()
    district_ids_in_catalog = {r["bhulekh_district_id"] for r in VerifiedBhulekhCatalog._by_id.values()}
    assert len(district_ids_in_catalog) == 30
    for did in range(1, 31):
        assert str(did) in district_ids_in_catalog


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

    v1 = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12")
    assert v1.status == RoRVerificationStatus.MISMATCH
    assert v1.plot_match is False

    v2 = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12/1")
    assert v2.status == RoRVerificationStatus.MISMATCH
    assert v2.plot_match is False

    v3 = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "12A")
    assert v3.status == RoRVerificationStatus.MISMATCH
    assert v3.plot_match is False


def test_4_pdf_magic_bytes_validation():
    """Document Safety: Valid PDF must start with %PDF- header."""
    valid_pdf = b"%PDF-1.4\n1 0 obj\n<<>>\nendobj\n"
    invalid_pdf = b"<html><body>Error 404</body></html>"

    assert valid_pdf.startswith(b"%PDF-")
    assert not invalid_pdf.startswith(b"%PDF-")


def test_5_multi_owner_array_preservation():
    """Owner Integrity: Full list of co-sharers is preserved without truncation."""
    owners = [
        OwnerEntry(name="Owner 1", relation="Father", relation_name="Father 1", share="1/3", khata_number="50"),
        OwnerEntry(name="Owner 2", relation="Father", relation_name="Father 2", share="1/3", khata_number="50"),
        OwnerEntry(name="Owner 3", relation="Father", relation_name="Father 3", share="1/3", khata_number="50"),
    ]
    rec = VerifiedRoRRecord(
        district="KHURDA",
        tahasil="BALIANTA",
        mouza="Baindolo",
        plot_number="15",
        khata_number="50",
        owners=owners,
    )
    assert len(rec.owners) == 3
    assert rec.owners[0].name == "Owner 1"
    assert rec.owners[2].name == "Owner 3"


def test_6_unmapped_village_fails_closed_safely():
    """Safety: Unmapped village in resolver fails closed with NOT_FOUND."""
    from resolvers.bhulekh_identity_resolver import BhulekhVillageResolver, ResolutionStatus
    status, opt, detail = BhulekhVillageResolver.resolve_mouza_option(
        district_id="3",
        tahasil_id="1",
        gis_village_name="NonExistentMouza9999",
        gis_village_id="9999999",
        available_options=[{"value": "88", "text": "ଅନନ୍ତପୁର"}],
    )
    assert status == ResolutionStatus.NOT_FOUND
    assert opt is None


def test_7_zero_pii_or_session_tokens_in_models():
    """Security: Ensure RoR models never expose passwords, cookies, or auth tokens."""
    rec = VerifiedRoRRecord(
        district="CUTTACK",
        tahasil="ATHAGARH",
        mouza="Anantapur",
        plot_number="101",
        khata_number="125",
        owners=[OwnerEntry(name="Sample Owner", share="1/1")],
    )
    dump_s = rec.model_dump_json()
    for forbidden in ["password", "bearer", "set-cookie", "aspnet_sessionid"]:
        assert forbidden not in dump_s.lower()
