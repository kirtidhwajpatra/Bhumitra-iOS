"""
Bhumitra - Tests for User-Assisted IGR Jurisdiction Resolution
Validates candidate generation, candidate ranking, server-side validation,
plot existence verification, transparency flags, and backward compatibility.
"""
import pytest
from fastapi.testclient import TestClient

from app import create_app
from services.igr_benchmark_service import IGRBenchmarkService, igr_benchmark_service


@pytest.fixture
def client():
    app = create_app()
    with TestClient(app) as test_client:
        yield test_client


@pytest.mark.anyio
async def test_automatic_exact_match_preserved():
    """Validates that known automatic parcels still resolve with zero user interaction."""
    service = IGRBenchmarkService()
    resp = await service.get_benchmark_valuation(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1009",
        actual_area=2.40,
        actual_area_unit="Decimal",
    )
    assert resp.status == "AVAILABLE"
    assert resp.user_assistance_used is False
    assert resp.selection_mode == "AUTOMATIC"
    assert resp.candidates is None
    assert resp.unit_rates is not None
    assert resp.unit_rates.per_decimal_100 == 5029.07


@pytest.mark.anyio
async def test_candidate_generation_for_unresolved_mouza():
    """
    Validates that a mouza needing disambiguation returns candidate jurisdictions
    with status MAPPING_REQUIRES_USER_SELECTION and valid candidate tokens.
    """
    service = IGRBenchmarkService()
    # Query with generic tahasil so automatic confidence is below 45
    resp = await service.get_benchmark_valuation(
        district="BALASORE",
        tahasil="BALASORE",
        village="Barimelak",
        plot="378",
    )
    assert resp.status == "MAPPING_REQUIRES_USER_SELECTION"
    assert resp.reason == "REQUIRES_USER_SELECTION"
    assert resp.candidates is not None
    assert len(resp.candidates) > 0

    # Ensure candidates are well-structured
    top_cand = resp.candidates[0]
    assert top_cand.candidate_token is not None
    assert top_cand.registration_office_id > 0
    assert top_cand.village_id > 0
    assert "BARIMELAK" in top_cand.village_name
    assert top_cand.confidence in ("high", "medium", "low")
    assert len(top_cand.match_reasons) > 0


@pytest.mark.anyio
async def test_user_selected_valid_candidate_retrieval():
    """
    Validates that when the user selects a candidate jurisdiction,
    the backend validates the selection, verifies the plot, and returns rates.
    """
    service = IGRBenchmarkService()
    # First get candidate for Barimelak
    cand_resp = await service.get_benchmark_valuation(
        district="BALASORE",
        tahasil="BALASORE",
        village="Barimelak",
        plot="378",
    )
    assert cand_resp.status == "MAPPING_REQUIRES_USER_SELECTION"
    candidate = cand_resp.candidates[0]

    # User submits selection using candidate_token
    selected_resp = await service.get_benchmark_valuation(
        district="BALASORE",
        tahasil="BALASORE",
        village="Barimelak",
        plot="378",
        actual_area=5.0,
        actual_area_unit="Decimal",
        selected_regoff_id=candidate.registration_office_id,
        selected_village_id=candidate.village_id,
        candidate_token=candidate.candidate_token,
    )
    assert selected_resp.status == "AVAILABLE"
    assert selected_resp.user_assistance_used is True
    assert selected_resp.selection_mode == "USER_ASSISTED"
    assert selected_resp.unit_rates is not None
    assert selected_resp.unit_rates.per_decimal_100 == 13000.00
    assert selected_resp.registration_office == candidate.registration_office_name
    assert selected_resp.village_thana == candidate.village_name


@pytest.mark.anyio
async def test_user_selected_invalid_office_rejected():
    """Validates that arbitrary/fake registration office IDs are rejected with INVALID_CANDIDATE_SELECTION."""
    service = IGRBenchmarkService()
    resp = await service.get_benchmark_valuation(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1009",
        selected_regoff_id=999999,  # Fake office ID
        selected_village_id=1000299,
    )
    assert resp.status == "MAPPING_REQUIRES_USER_SELECTION"
    assert resp.reason == "INVALID_CANDIDATE_SELECTION"
    assert resp.candidates is not None


@pytest.mark.anyio
async def test_user_selected_mismatched_plot_rejected():
    """
    CRITICAL INVARIANT (Section 11):
    If user selects a valid jurisdiction, but the plot does NOT exist in that jurisdiction,
    the server must reject it with PLOT_NOT_FOUND_IN_JURISDICTION and return the candidate list.
    """
    service = IGRBenchmarkService()
    # Keri (regoff 100, vill 1000299) does not contain plot 9999999
    resp = await service.get_benchmark_valuation(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="9999999",  # Fake plot
        selected_regoff_id=100,
        selected_village_id=1000299,
    )
    assert resp.status == "MAPPING_REQUIRES_USER_SELECTION"
    assert resp.reason == "PLOT_NOT_FOUND_IN_JURISDICTION"
    assert "does not contain Plot 9999999" in resp.message
    assert resp.candidates is not None


@pytest.mark.anyio
async def test_conflicting_thana_disqualified():
    """
    Validates that candidate jurisdictions with conflicting thana numbers
    are rejected and never included in the candidate list.
    """
    service = IGRBenchmarkService()
    # Village with explicit thana 271
    resp = await service.get_benchmark_valuation(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="TEST_VILLAGE 271",
        plot="100",
    )
    if resp.candidates:
        for c in resp.candidates:
            if c.thana_number:
                # If thana extracted from candidate, it MUST NOT conflict with 271
                assert c.thana_number == "271"


def test_candidate_token_integrity():
    """Validates cryptographic integrity of server-signed candidate verification tokens."""
    service = IGRBenchmarkService()
    token = service._generate_candidate_token(17, 100, 1000299)
    assert isinstance(token, str)

    verified = service._verify_candidate_token(token)
    assert verified == (17, 100, 1000299)

    # Corrupted token
    corrupted = token[:-2] + "xx"
    assert service._verify_candidate_token(corrupted) is None


def test_fastapi_user_assisted_endpoint(client):
    """Validates GET /api/v1/ror/benchmark-valuation accepts user candidate parameters."""
    response = client.get(
        "/api/v1/ror/benchmark-valuation",
        params={
            "district": "BALASORE",
            "tahasil": "BALASORE",
            "village": "Barimelak",
            "plot": "378",
            "selected_regoff_id": 13,
            "selected_village_id": 130041,
            "actual_area": 5.0,
            "actual_area_unit": "Decimal",
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "AVAILABLE"
    assert data["user_assistance_used"] is True
    assert data["selection_mode"] == "USER_ASSISTED"
    assert data["unit_rates"]["per_decimal_100"] == 13000.00
