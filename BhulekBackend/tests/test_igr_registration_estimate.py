"""
Unit and Integration Tests for Odisha IGR Registration & Stamp Duty Calculation
Validates official IGR calculation, exact Decimal arithmetic, deed types,
women buyer concession, caching, error states, and API endpoints.
"""
import pytest
from decimal import Decimal
from fastapi.testclient import TestClient

from app import create_app
from services.igr_benchmark_service import IGRBenchmarkService, igr_benchmark_service
from models.igr_benchmark import (
    IGRRegistrationEstimateRequest,
    IGRRegistrationEstimateResponse,
    IGR_OFFICIAL_DEEDS,
)


@pytest.fixture
def client():
    app = create_app()
    with TestClient(app) as test_client:
        yield test_client


@pytest.mark.anyio
async def test_registration_estimate_known_plot_kendujhar():
    """
    Validates known plot from official IGR benchmark portal:
    District: KENDUJHAR
    Tahasil: KEONJHAR SADAR
    Village: G KERI 271
    Plot: 1009
    Area: 5.0 Decimal
    Deed: SALE IMMOVABLE
    """
    service = IGRBenchmarkService()
    resp = await service.get_registration_estimate(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1009",
        area=5.0,
        unit="Decimal",
        deed_type="SALE IMMOVABLE",
        buyer_category="STANDARD",
    )

    assert resp.status == "AVAILABLE"
    assert resp.district == "KENDUJHAR"
    assert resp.registration_office == "KENDUJHAR"
    assert "KERI - 271" in resp.village_thana
    assert resp.plot_number == "1009"
    assert resp.selected_area == 5.0
    assert resp.selected_unit == "Decimal"

    # Official rate: ~₹5,029.07 / Decimal -> For 5 Decimal: ₹25,145.35
    assert resp.benchmark_value_for_area == 25145.35
    assert resp.benchmark_rate_per_decimal == 5029.07
    assert resp.benchmark_rate_per_acre == 502907.0

    # Statutory charges: 5% stamp duty, 2% registration fee
    assert resp.stamp_duty == 1257.27
    assert resp.registration_fee == 502.91
    assert resp.total_government_charges == 1760.18

    # Standard buyer: no discount applied to total_after_concession
    assert resp.women_buyer_concession_applicable is True
    assert resp.concession_amount == 251.46
    assert resp.total_after_concession == 1760.18
    assert "Benchmark ₹25,145.35 + Stamp Duty ₹1,257.27 + Registration Fee ₹502.91 = ₹1,760.18" in resp.formula


@pytest.mark.anyio
async def test_registration_estimate_women_buyer_concession():
    """
    Validates that when buyer_category is WOMEN_BUYER,
    the 1% stamp duty concession is applied to total_after_concession.
    """
    service = IGRBenchmarkService()
    resp = await service.get_registration_estimate(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1009",
        area=5.0,
        unit="Decimal",
        deed_type="SALE IMMOVABLE",
        buyer_category="WOMEN_BUYER",
    )

    assert resp.status == "AVAILABLE"
    assert resp.buyer_category == "WOMEN_BUYER"
    assert resp.total_government_charges == 1760.18
    assert resp.women_buyer_concession_applicable is True
    assert resp.concession_amount == 251.46

    # 4% Stamp Duty (1005.81) + 2% Reg Fee (502.91) = 1508.72
    assert resp.total_after_concession == 1508.72


@pytest.mark.anyio
async def test_registration_estimate_partition_deed():
    """
    Validates Partition Deed (Deed ID 49), where women concession does not apply.
    """
    service = IGRBenchmarkService()
    resp = await service.get_registration_estimate(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1009",
        area=5.0,
        unit="Decimal",
        deed_id=49,
        buyer_category="WOMEN_BUYER",
    )

    assert resp.status == "AVAILABLE"
    assert resp.deed_id == 49
    assert resp.deed_type == "PARTITION"
    assert resp.women_buyer_concession_applicable is False
    assert resp.concession_amount is None
    # For partition, both stamp duty and registration fee are equal to 502.91
    assert resp.stamp_duty == 502.91
    assert resp.registration_fee == 502.91
    assert resp.total_government_charges == 1005.82
    assert resp.total_after_concession == 1005.82


@pytest.mark.anyio
async def test_registration_estimate_not_found():
    """Validates non-existent plot returns status NOT_FOUND without error."""
    service = IGRBenchmarkService()
    resp = await service.get_registration_estimate(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="9999999",
        area=1.0,
    )

    assert resp.status == "NOT_FOUND"
    assert resp.reason == "NO_BENCHMARK_RECORD"
    assert resp.benchmark_value_for_area is None
    assert resp.stamp_duty is None
    assert resp.registration_fee is None


@pytest.mark.anyio
async def test_registration_estimate_unresolved_district():
    """Validates unrecognized district returns status MAPPING_UNRESOLVED gracefully."""
    service = IGRBenchmarkService()
    resp = await service.get_registration_estimate(
        district="INVALID_DISTRICT_XYZ",
        tahasil="ANY_TAHASIL",
        village="ANY_VILLAGE",
        plot="100",
        area=1.0,
    )

    assert resp.status == "MAPPING_UNRESOLVED"
    assert resp.reason == "REGISTRATION_OFFICE_UNRESOLVED"
    assert resp.benchmark_value_for_area is None


@pytest.mark.anyio
async def test_registration_estimate_caching():
    """Validates subsequent calls with identical inputs are served from memory cache."""
    service = IGRBenchmarkService()
    resp1 = await service.get_registration_estimate(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1009",
        area=2.0,
        unit="Decimal",
        deed_type="SALE IMMOVABLE",
        buyer_category="STANDARD",
        force_refresh=True,
    )
    assert resp1.cached is False

    resp2 = await service.get_registration_estimate(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1009",
        area=2.0,
        unit="Decimal",
        deed_type="SALE IMMOVABLE",
        buyer_category="STANDARD",
        force_refresh=False,
    )
    assert resp2.cached is True
    assert resp2.total_government_charges == resp1.total_government_charges


def test_supported_deeds_endpoint(client):
    """Validates GET /api/v1/igr/deeds and alias."""
    resp = client.get("/api/v1/igr/deeds")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 7
    sale_deed = next((d for d in data if d["id"] == 1), None)
    assert sale_deed is not None
    assert sale_deed["name"] == "SALE IMMOVABLE"
    assert sale_deed["women_concession_eligible"] is True

    alias_resp = client.get("/api/v1/ror/registration-estimate/deeds")
    assert alias_resp.status_code == 200
    assert alias_resp.json() == data


def test_registration_estimate_fastapi_endpoints(client):
    """Validates POST /api/v1/igr/registration-estimate and GET alias."""
    # Test POST
    payload = {
        "district": "KENDUJHAR",
        "tahasil": "KEONJHAR SADAR",
        "village": "G KERI 271",
        "plot": "1009",
        "area": 5.0,
        "unit": "Decimal",
        "deed_type": "SALE IMMOVABLE",
        "buyer_category": "WOMEN_BUYER",
    }
    post_resp = client.post("/api/v1/igr/registration-estimate", json=payload)
    assert post_resp.status_code == 200
    data = post_resp.json()
    assert data["status"] == "AVAILABLE"
    assert data["total_government_charges"] == 1760.18
    assert data["total_after_concession"] == 1508.72

    # Test GET alias
    get_resp = client.get(
        "/api/v1/ror/registration-estimate",
        params={
            "district": "KENDUJHAR",
            "tahasil": "KEONJHAR SADAR",
            "village": "G KERI 271",
            "plot": "1009",
            "area": 5.0,
            "unit": "Decimal",
            "deed_type": "SALE IMMOVABLE",
            "buyer_category": "STANDARD",
        }
    )
    assert get_resp.status_code == 200
    get_data = get_resp.json()
    assert get_data["status"] == "AVAILABLE"
    assert get_data["total_government_charges"] == 1760.18
