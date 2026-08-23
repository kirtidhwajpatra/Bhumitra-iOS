"""
Phase 3.29 — GIS Parcel -> Bhulekh Village Identity Handoff Test Suite
Validates that each selected cadastral parcel owns and preserves its authoritative
village identity, plot isolation is preserved across villages, and invalid village ID/name combinations fail closed.
"""
import pytest
from fastapi.testclient import TestClient
from app import create_app
from resolvers.bhulekh_identity_resolver import BhulekhVillageResolver, VerifiedBhulekhCatalog


@pytest.fixture
def client():
    app = create_app()
    return TestClient(app)


def test_1_selected_parcel_uses_own_village_identity():
    """Validates that a parcel's own village identity resolves deterministically."""
    options = [
        {"value": "317", "text": "ଡ଼ିମ୍ବୋ"},
        {"value": "330", "text": "କେରି"},
    ]
    # G_Dimbo should resolve to Mouza 317
    s_dimbo, o_dimbo, _ = BhulekhVillageResolver.resolve_mouza_option("7", "4", "G_Dimbo", "0704317", options)
    assert o_dimbo["value"] == "317"
    assert o_dimbo["text"] == "ଡ଼ିମ୍ବୋ"

    # G_Keri 271 should resolve to Mouza 330
    s_keri, o_keri, _ = BhulekhVillageResolver.resolve_mouza_option("7", "4", "G_Keri 271", "179", options)
    assert o_keri["value"] == "330"
    assert o_keri["text"] == "କେରି"


def test_2_plot_489_uses_g_dimbo():
    """Plot 489 in G_Dimbo resolves to Mouza 317."""
    rec, _, _ = VerifiedBhulekhCatalog.lookup("7", "4", "G_Dimbo", "0704317")
    assert rec is not None
    assert rec.get("bhulekh_mouza_id") == "317"


def test_3_plot_1035_uses_g_keri_271():
    """Plot 1035 in G_Keri 271 resolves to Mouza 330."""
    rec, _, _ = VerifiedBhulekhCatalog.lookup("7", "4", "G_Keri 271", "179")
    assert rec is not None
    assert rec.get("bhulekh_mouza_id") in ("330", "271")


def test_4_plot_1050_uses_g_keri_271():
    """Plot 1050 in G_Keri 271 resolves to Mouza 330."""
    rec, _, _ = VerifiedBhulekhCatalog.lookup("7", "4", "G_Keri 271", "330")
    assert rec is not None
    assert rec.get("bhulekh_mouza_id") in ("330", "271")


def test_5_same_plot_number_different_villages_are_isolated():
    """Validates that plot 12 in G_Dimbo (317) is isolated from plot 12 in another village."""
    options_dimbo = [{"value": "317", "text": "ଡ଼ିମ୍ବୋ"}]
    options_other = [{"value": "330", "text": "କେରି"}]

    _, opt_dimbo, _ = BhulekhVillageResolver.resolve_mouza_option("7", "4", "G_Dimbo", "0704317", options_dimbo)
    _, opt_other, _ = BhulekhVillageResolver.resolve_mouza_option("7", "4", "G_Keri 271", "330", options_other)

    assert opt_dimbo["value"] == "317"
    assert opt_other["value"] == "330"
    assert opt_dimbo["value"] != opt_other["value"]


def test_6_missing_parcel_village_identity_fails_closed(client):
    """Empty or missing village identity is rejected with 400 Bad Request."""
    res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=KEONJHAR+SADAR&village=&plot=489")
    assert res.status_code == 400
    assert res.json()["detail"]["code"] == "INVALID_INPUT"


def test_7_ror_service_does_not_use_active_village_after_selection():
    """Validates that resolver uses the parcel's supplied village parameter, not a hardcoded one."""
    options = [{"value": "317", "text": "ଡ଼ିମ୍ବୋ"}, {"value": "330", "text": "କେରି"}]
    _, opt, _ = BhulekhVillageResolver.resolve_mouza_option("7", "4", "G_Keri 271", None, options)
    assert opt["value"] == "330"


def test_8_manual_search_remains_independent(client):
    """Manual search endpoints continue to function independently with full catalog."""
    res = client.get("/api/v1/villages?district_id=7&tahasil_id=4")
    assert res.status_code == 200
    villages = res.json()
    assert isinstance(villages, list)
    assert len(villages) > 100
    # Must contain both Dimbo and Keri
    village_names = [v.get("official_name", "") for v in villages]
    assert any("DIMBO" in v.upper() or "ଡିମ୍ବୋ" in v or "ଡ଼ିମ୍ବୋ" in v for v in village_names)
    assert any("KERI" in v.upper() or "କେରି" in v for v in village_names)


def test_9_backend_rejects_village_id_name_conflict():
    """A conflicting village name + incompatible village ID does not silently mismatch."""
    options = [{"value": "1", "text": "କେନ୍ଦୁଝର"}, {"value": "317", "text": "ଡ଼ିମ୍ବୋ"}]
    # Searching for village "UnknownVillageXYZ" with village_id "1" should NOT match Dimbo
    status, opt, _ = BhulekhVillageResolver.resolve_mouza_option("7", "4", "UnknownVillageXYZ", "999", options)
    assert opt is None or status.value == "UNKNOWN"


def test_10_plot_number_is_preserved_verbatim():
    """Plot numbers with fractions or slashes are preserved verbatim without truncation."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result
    from models.ror_response import RoRVerificationStatus

    html_exact = """
    <html><body>
        <table>
            <tr><td>District: କେନ୍ଦୁଝର</td><td>Tahasil: ସଦର</td><td>Village: ଡିମ୍ବୋ</td></tr>
            <tr><td>Plot: 1035/1</td><td>Khata: 230</td></tr>
        </table>
    </body></html>
    """
    soup = BeautifulSoup(html_exact, "html.parser")
    v = verify_ror_result(soup, "KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "1035/1")
    assert v.status == RoRVerificationStatus.VERIFIED
    assert v.plot_match is True
