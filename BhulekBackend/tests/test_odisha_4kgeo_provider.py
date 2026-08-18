import json
import pytest
import httpx
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient

from main import app
from utils.crs_converter import (
    epsg3857_to_epsg4326,
    epsg4326_to_epsg3857,
    transform_geojson_geometry,
    calculate_polygon_centroid,
    point_in_polygon,
    is_likely_epsg3857,
)
from providers.odisha_4kgeo_provider import Odisha4KGEOProvider
from models.cadastral import CadastralParcel, CadastralFeatureCollection
from routers.gis import provider as global_gis_provider

client = TestClient(app)

@pytest.fixture(autouse=True)
def clean_gis_caches():
    global_gis_provider._districts_cache.clear()
    global_gis_provider._blocks_cache.clear()
    global_gis_provider._gps_cache.clear()
    global_gis_provider._villages_cache.clear()
    global_gis_provider._parcels_cache.clear()
    global_gis_provider._extents_cache.clear()
    yield

SAMPLE_4KGEO_GEOJSON = {
    "type": "FeatureCollection",
    "features": [
        {
            "type": "Feature",
            "properties": {"revenue_plot": "12", "village": "G_Dimbo", "block": "Keonjhar Sadar"},
            "geometry": {
                "type": "Polygon",
                "coordinates": [
                    [
                        [9535165.31135894, 2467631.10797475, 0],
                        [9535148.93615052, 2467642.44257391, 0],
                        [9535141.06853419, 2467603.09772211, 0],
                        [9535165.31135894, 2467631.10797475, 0],
                    ]
                ],
            },
        },
        {
            "type": "Feature",
            "properties": {"revenue_plot": "120", "village": "G_Dimbo", "block": "Keonjhar Sadar"},
            "geometry": {
                "type": "Polygon",
                "coordinates": [
                    [
                        [9535180.12486621, 2467618.29045471, 0],
                        [9535180.25945148, 2467619.99960054, 0],
                        [9535169.94759309, 2467593.73623195, 0],
                        [9535180.12486621, 2467618.29045471, 0],
                    ]
                ],
            },
        },
        {
            "type": "Feature",
            "properties": {"revenue_plot": "12/1", "village": "G_Dimbo", "block": "Keonjhar Sadar"},
            "geometry": {
                "type": "Polygon",
                "coordinates": [
                    [
                        [9535187.21024049, 2467671.96564214, 0],
                        [9535174.57870654, 2467679.14654499, 0],
                        [9535186.5369802, 2467670.73539354, 0],
                        [9535187.21024049, 2467671.96564214, 0],
                    ]
                ],
            },
        },
        {
            "type": "Feature",
            "properties": {"revenue_plot": "12A", "village": "G_Dimbo", "block": "Keonjhar Sadar"},
            "geometry": {
                "type": "Polygon",
                "coordinates": [
                    [
                        [9535170.88679563, 2467681.05389235, 0],
                        [9535163.58123141, 2467684.71589928, 0],
                        [9535153.61758038, 2467651.46685923, 0],
                        [9535170.88679563, 2467681.05389235, 0],
                    ]
                ],
            },
        },
    ],
}


# ==============================================================================
# 1. CRS CONVERSION TESTS
# ==============================================================================

def test_crs_known_keonjhar_coordinate_conversion():
    """Validates EPSG:3857 to WGS84 conversion against known Keonjhar control point."""
    x = 9535165.31135894
    y = 2467631.10797475
    lng, lat = epsg3857_to_epsg4326(x, y)
    
    assert 85.65 <= lng <= 85.66
    assert 21.63 <= lat <= 21.64
    assert is_likely_epsg3857(x, y) is True
    assert is_likely_epsg3857(lng, lat) is False


def test_crs_round_trip_accuracy():
    """Validates round-trip conversion accuracy between WGS84 and EPSG:3857."""
    orig_lng, orig_lat = 85.6565012, 21.6365421
    x, y = epsg4326_to_epsg3857(orig_lng, orig_lat)
    res_lng, res_lat = epsg3857_to_epsg4326(x, y)
    
    assert pytest.approx(orig_lng, abs=1e-5) == res_lng
    assert pytest.approx(orig_lat, abs=1e-5) == res_lat


def test_transform_geojson_geometry_polygon():
    """Validates transformation of nested GeoJSON Polygon coordinates."""
    raw_geom = {
        "type": "Polygon",
        "coordinates": [
            [
                [9535165.31, 2467631.11, 0],
                [9535148.94, 2467642.44, 0],
                [9535141.07, 2467603.10, 0],
                [9535165.31, 2467631.11, 0],
            ]
        ],
    }
    wgs84_geom = transform_geojson_geometry(raw_geom)
    assert wgs84_geom["type"] == "Polygon"
    first_pt = wgs84_geom["coordinates"][0][0]
    assert 85.65 <= first_pt[0] <= 85.66
    assert 21.63 <= first_pt[1] <= 21.64


def test_point_in_polygon_ray_casting():
    """Validates 2D point-in-polygon containment test."""
    triangle = [[[0.0, 0.0], [10.0, 0.0], [5.0, 10.0], [0.0, 0.0]]]
    assert point_in_polygon(5.0, 3.0, triangle) is True
    assert point_in_polygon(15.0, 5.0, triangle) is False
    assert point_in_polygon(-1.0, 0.0, triangle) is False


# ==============================================================================
# 2. PROVIDER HIERARCHY & PARCEL TESTS
# ==============================================================================

@pytest.mark.anyio
async def test_provider_get_districts_returns_30_official_districts():
    """Validates district list retrieval."""
    provider = Odisha4KGEOProvider()
    districts = await provider.get_districts()
    assert len(districts) == 30
    assert any(d.name == "Keonjhar" and d.id == "224" for d in districts)
    assert any(d.name == "Khurda" and d.id == "234" for d in districts)


@pytest.mark.anyio
async def test_provider_get_blocks_success():
    """Validates block retrieval for Keonjhar (224)."""
    provider = Odisha4KGEOProvider()
    mock_res = [
        {"block_name": "Keonjhar Sadar", "block_code": "0704"},
        {"block_name": "Champua", "block_code": "0703"},
    ]
    with patch.object(httpx.AsyncClient, "post", AsyncMock(return_value=MagicMock(status_code=200, json=lambda: mock_res))):
        blocks = await provider.get_blocks(district_id="224")
        assert len(blocks) == 2
        assert blocks[0].name == "Keonjhar Sadar"
        assert blocks[0].id == "0704"


@pytest.mark.anyio
async def test_provider_get_gram_panchayats_success():
    """Validates GP retrieval for block 0704."""
    provider = Odisha4KGEOProvider()
    mock_res = [
        {"grampanchayat_name": "Dimbo", "grampanchayat_code": "07040001"},
    ]
    with patch.object(httpx.AsyncClient, "post", AsyncMock(return_value=MagicMock(status_code=200, json=lambda: mock_res))):
        gps = await provider.get_gram_panchayats(block_id="0704")
        assert len(gps) == 1
        assert gps[0].name == "Dimbo"
        assert gps[0].id == "07040001"


@pytest.mark.anyio
async def test_provider_get_villages_success():
    """Validates village retrieval for Dimbo GP (07040001)."""
    provider = Odisha4KGEOProvider()
    mock_res = [
        {"revenue_village_name": "G_Dimbo", "revenue_village_code": "0704317"},
    ]
    with patch.object(httpx.AsyncClient, "post", AsyncMock(return_value=MagicMock(status_code=200, json=lambda: mock_res))):
        villages = await provider.get_villages(gp_id="07040001", block_id="0704")
        assert len(villages) == 1
        assert villages[0].name == "G_Dimbo"
        assert villages[0].id == "0704317"


# ==============================================================================
# 3. EXACT PLOT NUMBER FIDELITY & SPATIAL LOOKUP
# ==============================================================================

@pytest.mark.anyio
async def test_provider_plot_number_exact_isolation():
    """Validates that plot 12, 120, 12/1, and 12A are strictly preserved as distinct strings."""
    provider = Odisha4KGEOProvider()
    with patch.object(httpx.AsyncClient, "post", AsyncMock(return_value=MagicMock(status_code=200, text=json.dumps(SAMPLE_4KGEO_GEOJSON)))):
        # Test 12
        p12 = await provider.get_parcel_by_plot(village_id="0704317", exact_plot_number="12")
        assert p12 is not None
        assert p12.plot_number == "12"

        # Test 120
        p120 = await provider.get_parcel_by_plot(village_id="0704317", exact_plot_number="120")
        assert p120 is not None
        assert p120.plot_number == "120"

        # Test 12/1
        p12_1 = await provider.get_parcel_by_plot(village_id="0704317", exact_plot_number="12/1")
        assert p12_1 is not None
        assert p12_1.plot_number == "12/1"

        # Test 12A
        p12A = await provider.get_parcel_by_plot(village_id="0704317", exact_plot_number="12A")
        assert p12A is not None
        assert p12A.plot_number == "12A"

        # Test Non-Existent 999
        p999 = await provider.get_parcel_by_plot(village_id="0704317", exact_plot_number="999")
        assert p999 is None


@pytest.mark.anyio
async def test_provider_empty_and_malformed_village_handling():
    """Validates graceful handling of empty or HTML responses from 4K GEO."""
    provider = Odisha4KGEOProvider()
    with patch.object(httpx.AsyncClient, "post", AsyncMock(return_value=MagicMock(status_code=200, text="<p>Notice: Undefined index</p>"))):
        fc = await provider.get_village_parcels(village_id="9999999")
        assert fc.total_parcels == 0
        assert len(fc.features) == 0


@pytest.mark.anyio
async def test_provider_upstream_timeout_and_errors_raise():
    """Validates that upstream timeouts raise appropriate errors."""
    provider = Odisha4KGEOProvider()
    with patch.object(httpx.AsyncClient, "post", AsyncMock(side_effect=httpx.TimeoutException("Timeout"))):
        with pytest.raises(TimeoutError, match="timed out"):
            await provider.get_blocks(district_id="224")


# ==============================================================================
# 4. FASTAPI GIS ROUTER INTEGRATION
# ==============================================================================

def test_api_get_districts():
    """Tests GET /api/v1/gis/districts endpoint."""
    res = client.get("/api/v1/gis/districts")
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 30
    assert data[0]["name"] == "Anugul"


def test_api_get_blocks():
    """Tests GET /api/v1/gis/blocks endpoint with mock."""
    mock_res = [{"block_name": "Keonjhar Sadar", "block_code": "0704"}]
    with patch.object(httpx.AsyncClient, "post", AsyncMock(return_value=MagicMock(status_code=200, json=lambda: mock_res))):
        res = client.get("/api/v1/gis/blocks?district_id=224")
        assert res.status_code == 200
        data = res.json()
        assert len(data) == 1
        assert data[0]["name"] == "Keonjhar Sadar"


def test_api_get_village_parcels():
    """Tests GET /api/v1/gis/village/{village_id}/parcels endpoint."""
    with patch.object(httpx.AsyncClient, "post", AsyncMock(return_value=MagicMock(status_code=200, text=json.dumps(SAMPLE_4KGEO_GEOJSON)))):
        res = client.get("/api/v1/gis/village/0704317/parcels?district_name=Keonjhar&block_name=Keonjhar%20Sadar")
        assert res.status_code == 200
        data = res.json()
        assert data["type"] == "FeatureCollection"
        assert data["total_parcels"] == 4
        assert data["source"] == "ODISHA_4K_GEO"
        assert data["features"][0]["properties"]["revenue_plot"] == "12"


def test_api_get_single_parcel_by_plot():
    """Tests GET /api/v1/gis/village/{village_id}/plot/{plot_number} endpoint."""
    with patch.object(httpx.AsyncClient, "post", AsyncMock(return_value=MagicMock(status_code=200, text=json.dumps(SAMPLE_4KGEO_GEOJSON)))):
        res = client.get("/api/v1/gis/village/0704317/plot/12/1")
        assert res.status_code == 200
        data = res.json()
        assert data["plot_number"] == "12/1"
        assert data["village_id"] == "0704317"
        assert "geometry" in data
        assert "centroid" in data


def test_api_plot_not_found_returns_404():
    """Tests 404 behavior for unknown plot in village."""
    with patch.object(httpx.AsyncClient, "post", AsyncMock(return_value=MagicMock(status_code=200, text=json.dumps(SAMPLE_4KGEO_GEOJSON)))):
        res = client.get("/api/v1/gis/village/0704317/plot/UNKNOWN_999")
        assert res.status_code == 404
        assert "not found" in res.json()["detail"]


def test_api_upstream_failure_returns_503_cadastral_unavailable():
    """Tests 503 error contract when 4K GEO is unreachable."""
    with patch.object(httpx.AsyncClient, "post", AsyncMock(side_effect=ConnectionError("Upstream portal down"))):
        res = client.get("/api/v1/gis/blocks?district_id=224")
        assert res.status_code == 503
        data = res.json()
        assert data["error_code"] == "CADASTRAL_SOURCE_UNAVAILABLE"
        assert data["success"] is False
