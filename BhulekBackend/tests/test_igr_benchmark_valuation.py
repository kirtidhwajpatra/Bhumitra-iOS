"""
Unit and Integration Tests for Odisha IGR Benchmark Valuation
Validates Sub-Registrar resolution, live upstream integration, exact decimal math,
caching, deduplication, and error handling.
"""
import pytest
from fastapi.testclient import TestClient

from app import create_app
from services.igr_benchmark_service import igr_benchmark_service, IGRBenchmarkService
from models.igr_benchmark import IGRUnitRates


@pytest.fixture
def client():
    app = create_app()
    with TestClient(app) as test_client:
        yield test_client


@pytest.mark.anyio
async def test_known_plot_kendujhar_keri_1009():
    """
    Validates known test plot from official IGR benchmark portal:
    District: KENDUJHAR
    Tahasil: KEONJHAR SADAR
    Village: G KERI 271
    Plot: 1009
    Area: 2.40 Decimal
    """
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
    assert resp.district == "KENDUJHAR"
    assert resp.registration_office == "KENDUJHAR"
    assert "KERI - 271" in resp.village_thana
    assert resp.kisam == "RESIDENTIAL"
    assert resp.plot_number == "1009"
    assert resp.unit_rates is not None
    assert resp.unit_rates.per_acre == 502907.0
    assert resp.unit_rates.per_decimal_100 == 5029.07
    assert resp.unit_rates.per_decimal_1000 == 502.91
    assert resp.unit_rates.per_hectare == 1242762.71
    assert resp.unit_rates.per_square_meter == 124.27
    assert resp.unit_rates.per_square_foot == 11.55

    assert resp.calculation.calculation_available is True
    assert resp.calculation.indicative_benchmark_amount == 12069.77
    assert "2.4 Decimal × ₹5,029.07/Decimal = ₹12,069.77" in resp.calculation.formula


@pytest.mark.anyio
async def test_invalid_plot_handling():
    """Validates that a non-existent plot returns status NOT_FOUND without throwing 500."""
    service = IGRBenchmarkService()
    resp = await service.get_benchmark_valuation(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="9999999",
    )
    assert resp.status == "NOT_FOUND"
    assert resp.unit_rates is None
    assert resp.calculation.calculation_available is False


@pytest.mark.anyio
async def test_invalid_district_handling():
    """Validates that an unrecognized district returns status MAPPING_UNRESOLVED gracefully."""
    service = IGRBenchmarkService()
    resp = await service.get_benchmark_valuation(
        district="UNKNOWN_DISTRICT_XYZ",
        tahasil="ANY_TAHASIL",
        village="ANY_VILLAGE",
        plot="100",
    )
    assert resp.status == "MAPPING_UNRESOLVED"
    assert resp.reason in ("VILLAGE_MAPPING_UNRESOLVED", "REGISTRATION_OFFICE_UNRESOLVED")
    assert resp.unit_rates is None


def test_exact_decimal_arithmetic():
    """Validates exact decimal arithmetic avoiding floating point inaccuracy."""
    service = IGRBenchmarkService()
    rates = IGRUnitRates(
        per_acre=502907.0,
        per_hectare=1242762.71,
        per_decimal_100=5029.07,
        per_decimal_1000=502.91,
        per_square_meter=124.27,
        per_square_foot=11.55,
    )

    # 1. Decimal calculation: 2.40 * 5029.07 = 12069.768 -> 12069.77
    calc1 = service._calculate_indicative_amount(2.40, "Decimal", rates)
    assert calc1.calculation_available is True
    assert calc1.indicative_benchmark_amount == 12069.77

    # 2. Acre calculation: 0.5 Acre * 502907 = 251453.50
    calc2 = service._calculate_indicative_amount(0.5, "Acre", rates)
    assert calc2.calculation_available is True
    assert calc2.indicative_benchmark_amount == 251453.50

    # 3. None / 0 area handling
    calc3 = service._calculate_indicative_amount(None, "Decimal", rates)
    assert calc3.calculation_available is False
    assert calc3.indicative_benchmark_amount is None

    calc4 = service._calculate_indicative_amount(0, "Decimal", rates)
    assert calc4.calculation_available is False
    assert calc4.indicative_benchmark_amount is None


@pytest.mark.anyio
async def test_caching_behavior():
    """Validates that consecutive calls return cached responses."""
    service = IGRBenchmarkService()
    resp1 = await service.get_benchmark_valuation(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1009",
    )
    assert resp1.cached is False

    resp2 = await service.get_benchmark_valuation(
        district="KENDUJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="1009",
    )
    assert resp2.cached is True
    assert resp2.status == resp1.status


def test_benchmark_endpoint_fastapi(client):
    """Validates GET /api/v1/ror/benchmark-valuation via FastAPI TestClient."""
    response = client.get(
        "/api/v1/ror/benchmark-valuation",
        params={
            "district": "KENDUJHAR",
            "tahasil": "KEONJHAR SADAR",
            "village": "G KERI 271",
            "plot": "1009",
            "actual_area": 2.40,
            "actual_area_unit": "Decimal",
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "AVAILABLE"
    assert data["district"] == "KENDUJHAR"
    assert data["registration_office"] == "KENDUJHAR"
    assert data["kisam"] == "RESIDENTIAL"
    assert data["unit_rates"]["per_decimal_100"] == 5029.07
    assert data["calculation"]["indicative_benchmark_amount"] == 12069.77


@pytest.mark.anyio
async def test_real_gis_parcel_buxibazar_cuttack():
    """
    Validates real GIS parcel with urban prefix / space divergence:
    District: Cuttack -> KATAKA
    Tahasil: Cuttack Sadar -> KATAKA
    Village: Buxibazar -> UNIT-18 BUXI BAZAR - 4
    Plot: 1110
    """
    service = IGRBenchmarkService()
    resp = await service.get_benchmark_valuation(
        district="Cuttack",
        tahasil="Cuttack Sadar",
        village="Buxibazar",
        plot="1110",
        actual_area=1.0,
        actual_area_unit="Decimal",
    )
    assert resp.status == "AVAILABLE"
    assert resp.district == "KATAKA"
    assert resp.registration_office == "KATAKA"
    assert "BUXI BAZAR" in resp.village_thana
    assert resp.kisam == "ROAD SIDE"
    assert resp.unit_rates is not None
    assert resp.unit_rates.per_decimal_100 == 1200000.00
    assert resp.unit_rates.per_acre == 120000000.00
    assert resp.highest_transaction_value == 80000000.00


@pytest.mark.anyio
async def test_real_gis_parcel_barimelak_baleswar():
    """
    Validates real GIS parcel:
    District: Baleswar -> BALESHWAR
    Tahasil: Simulia -> SIMULIA
    Village: Barimelak -> BARIMELAK - 189
    Plot: 378
    """
    service = IGRBenchmarkService()
    resp = await service.get_benchmark_valuation(
        district="Baleswar",
        tahasil="Simulia",
        village="Barimelak",
        plot="378",
        actual_area=5.0,
        actual_area_unit="Decimal",
    )
    assert resp.status == "AVAILABLE"
    assert resp.district == "BALESHWAR"
    assert resp.registration_office == "SIMULIA"
    assert "BARIMELAK - 189" in resp.village_thana
    assert resp.kisam == "RESIDENTIAL"
    assert resp.unit_rates is not None
    assert resp.unit_rates.per_decimal_100 == 13000.00


@pytest.mark.anyio
async def test_real_gis_parcel_baliabeda_keonjhar():
    """
    Validates real GIS parcel with prefix G_ and tahasil affinity:
    District: Keonjhar -> KENDUJHAR
    Tahasil: Keonjhar Sadar -> KENDUJHAR
    Village: G_Baliabeda -> BALIABEDA - 272
    Plot: 45
    """
    service = IGRBenchmarkService()
    resp = await service.get_benchmark_valuation(
        district="Keonjhar",
        tahasil="Keonjhar Sadar",
        village="G_Baliabeda",
        plot="45",
        actual_area=1.0,
        actual_area_unit="Decimal",
    )
    assert resp.status == "AVAILABLE"
    assert resp.district == "KENDUJHAR"
    assert resp.registration_office == "KENDUJHAR"
    assert "BALIABEDA - 272" in resp.village_thana
    assert resp.unit_rates is not None
    assert resp.unit_rates.per_decimal_100 == 1770.23


def test_debug_resolve_endpoint(client):
    """Validates GET /api/v1/ror/benchmark-valuation/debug-resolve returns full diagnostic trace."""
    response = client.get(
        "/api/v1/ror/benchmark-valuation/debug-resolve",
        params={
            "district": "Cuttack",
            "tahasil": "Cuttack Sadar",
            "village": "Buxibazar",
            "plot": "1110",
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "AVAILABLE"
    assert data["district_resolved"]["name"] == "KATAKA"
    assert data["resolved_office"]["name"] == "KATAKA"
    assert "BUXI BAZAR" in data["resolved_village"]["name"]
    assert data["kisam"] == "ROAD SIDE"
    assert "@$" in data["mrval_raw"]
    assert "elapsed_ms" in data
