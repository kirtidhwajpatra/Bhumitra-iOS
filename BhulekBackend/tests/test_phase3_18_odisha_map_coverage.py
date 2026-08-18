import pytest
import json
from unittest.mock import AsyncMock, patch, MagicMock
from httpx import Response
from fastapi.testclient import TestClient

from main import app
from providers.odisha_4kgeo_provider import (
    Odisha4KGEOProvider,
    OFFICIAL_4KGEO_DISTRICTS,
    ODISHA_DISTRICT_CODE_MAP,
)
from models.cadastral import (
    CadastralDistrict,
    CadastralBlock,
    CadastralGP,
    CadastralVillage,
    CadastralExtent,
    CadastralFeatureCollection,
    CadastralParcelFeature,
)


@pytest.fixture
def provider():
    return Odisha4KGEOProvider(timeout_seconds=5.0)


@pytest.fixture
def client():
    return TestClient(app)


# ==============================================================================
# 1. Statewide District, Block, GP, Village Dynamic Hierarchy Tests
# ==============================================================================

@pytest.mark.anyio
async def test_1_dynamic_district_selection(provider):
    """Verify all 30 Odisha districts are available and strictly typed."""
    districts = await provider.get_districts()
    assert len(districts) == 30
    names = [d.name for d in districts]
    assert "Cuttack" in names
    assert "Khurda" in names
    assert "Puri" in names
    assert "Ganjam" in names
    assert "Keonjhar" in names
    assert "Sundargarh" in names
    assert "Mayurbhanj" in names
    assert "Sambalpur" in names
    assert "Koraput" in names
    assert "Bolangir" in names


@pytest.mark.anyio
async def test_2_dynamic_block_and_gp_selection_isolated(provider):
    """Verify blocks and GPs are correctly isolated by their parent IDs."""
    with patch.object(provider, "_get_client") as mock_client_factory:
        mock_client = AsyncMock()
        mock_client_factory.return_value.__aenter__.return_value = mock_client

        # Mock blocks response for Cuttack (306)
        mock_client.post.return_value = Response(
            200,
            json=[
                {"block_name": "Athagarh", "block_code": "0301"},
                {"block_name": "Banki", "block_code": "0302"},
            ],
        )
        blocks = await provider.get_blocks(district_id="306")
        assert len(blocks) == 2
        assert blocks[0].name == "Athagarh"
        assert blocks[0].id == "0301"

        # Mock GPs response for Athagarh (0301)
        mock_client.post.return_value = Response(
            200,
            json=[
                {"grampanchayat_name": "Anantapur", "grampanchayat_code": "0301001"},
                {"grampanchayat_name": "Badabhuin", "grampanchayat_code": "0301002"},
            ],
        )
        gps = await provider.get_gps(block_id="0301")
        assert len(gps) == 2
        assert gps[0].name == "Anantapur"
        assert gps[0].id == "0301001"


@pytest.mark.anyio
async def test_3_dynamic_village_selection_with_leading_zeros(provider):
    """Verify village code preservation with string types and leading zeros."""
    with patch.object(provider, "_get_client") as mock_client_factory:
        mock_client = AsyncMock()
        mock_client_factory.return_value.__aenter__.return_value = mock_client

        mock_client.post.return_value = Response(
            200,
            json=[
                {"revenue_village_name": "Anantapur-64", "revenue_village_code": "0301088"},
                {"revenue_village_name": "Baindolo", "revenue_village_code": "2008007"},
            ],
        )
        villages = await provider.get_villages(block_id="0301", gp_id="0301001")
        assert len(villages) == 2
        assert isinstance(villages[0].id, str)
        assert villages[0].id == "0301088"
        assert villages[0].id.startswith("0")


# ==============================================================================
# 2. Automated District & Block Resolution from Village ID Prefix
# ==============================================================================

@pytest.mark.anyio
async def test_4_automated_district_and_block_resolution(provider):
    """
    Verify that when district_name and block_name are omitted, provider
    resolves them from ODISHA_DISTRICT_CODE_MAP and get_blocks.
    """
    sample_geojson = {
        "type": "FeatureCollection",
        "crs": {"type": "name", "properties": {"name": "EPSG:3857"}},
        "features": [
            {
                "type": "Feature",
                "properties": {"revenue_plot": "501"},
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[[9544177.0, 2330000.0], [9544200.0, 2330000.0], [9544200.0, 2330050.0], [9544177.0, 2330000.0]]],
                },
            }
        ],
    }

    with patch.object(provider, "_get_client") as mock_client_factory:
        mock_client = AsyncMock()
        mock_client_factory.return_value.__aenter__.return_value = mock_client

        # Mock block resolution query: 1st call get_blocks, 2nd call viewCadistrialResult
        mock_client.post.side_effect = [
            Response(200, json=[{"block_name": "Athagarh", "block_code": "0301"}]),
            Response(200, text=json.dumps(sample_geojson)),
        ]

        fc = await provider.get_village_parcels(village_id="0301088")
        assert fc.total_parcels == 1
        assert fc.features[0].properties["plot_number"] == "501"


# ==============================================================================
# 3. GeoJSON Normalization (Polygon, MultiPolygon, EPSG:3857 -> WGS84)
# ==============================================================================

@pytest.mark.anyio
async def test_5_polygon_and_multipolygon_crs_transformation(provider):
    """Verify correct WGS84 conversion for both Polygon and MultiPolygon."""
    mock_geojson = {
        "type": "FeatureCollection",
        "crs": {"type": "name", "properties": {"name": "EPSG:3857"}},
        "features": [
            {
                "type": "Feature",
                "properties": {"revenue_plot": "100"},
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[[9544177.75, 2330000.50], [9544200.00, 2330000.50], [9544200.00, 2330050.50], [9544177.75, 2330000.50]]],
                },
            },
            {
                "type": "Feature",
                "properties": {"revenue_plot": "100/1"},
                "geometry": {
                    "type": "MultiPolygon",
                    "coordinates": [[[[9544177.75, 2330000.50], [9544200.00, 2330000.50], [9544200.00, 2330050.50], [9544177.75, 2330000.50]]]],
                },
            },
        ],
    }

    with patch.object(provider, "_get_client") as mock_client_factory:
        mock_client = AsyncMock()
        mock_client_factory.return_value.__aenter__.return_value = mock_client
        mock_client.post.return_value = Response(200, text=json.dumps(mock_geojson))

        fc = await provider.get_village_parcels(
            village_id="0301088",
            district_name="Cuttack",
            block_name="Athagarh",
        )
        assert fc.total_parcels == 2
        # Coordinates in Odisha are ~85-87° E longitude and ~19-22° N latitude
        c1 = fc.features[0].properties["centroid"]
        assert 80.0 <= c1[0] <= 90.0
        assert 18.0 <= c1[1] <= 23.0

        c2 = fc.features[1].properties["centroid"]
        assert 80.0 <= c2[0] <= 90.0
        assert 18.0 <= c2[1] <= 23.0


# ==============================================================================
# 4. Exact Plot Matching (String Isolation)
# ==============================================================================

@pytest.mark.anyio
async def test_6_exact_plot_string_isolation_non_dimbo(provider):
    """Verify plot string distinction (12 != 12/1 != 120 != 12A) in non-Dimbo villages."""
    mock_geojson = {
        "type": "FeatureCollection",
        "features": [
            {"type": "Feature", "properties": {"revenue_plot": "12"}, "geometry": {"type": "Polygon", "coordinates": [[[85.8, 20.4], [85.81, 20.4], [85.81, 20.41], [85.8, 20.4]]]}},
            {"type": "Feature", "properties": {"revenue_plot": "12/1"}, "geometry": {"type": "Polygon", "coordinates": [[[85.8, 20.4], [85.81, 20.4], [85.81, 20.41], [85.8, 20.4]]]}},
            {"type": "Feature", "properties": {"revenue_plot": "120"}, "geometry": {"type": "Polygon", "coordinates": [[[85.8, 20.4], [85.81, 20.4], [85.81, 20.41], [85.8, 20.4]]]}},
            {"type": "Feature", "properties": {"revenue_plot": "12A"}, "geometry": {"type": "Polygon", "coordinates": [[[85.8, 20.4], [85.81, 20.4], [85.81, 20.41], [85.8, 20.4]]]}},
        ],
    }

    with patch.object(provider, "_get_client") as mock_client_factory:
        mock_client = AsyncMock()
        mock_client_factory.return_value.__aenter__.return_value = mock_client
        mock_client.post.return_value = Response(200, text=json.dumps(mock_geojson))

        p12 = await provider.get_parcel_by_plot(village_id="2008007", exact_plot_number="12", district_name="Khurda", block_name="Balianta")
        p12_1 = await provider.get_parcel_by_plot(village_id="2008007", exact_plot_number="12/1", district_name="Khurda", block_name="Balianta")
        p120 = await provider.get_parcel_by_plot(village_id="2008007", exact_plot_number="120", district_name="Khurda", block_name="Balianta")
        p12A = await provider.get_parcel_by_plot(village_id="2008007", exact_plot_number="12A", district_name="Khurda", block_name="Balianta")

        assert p12.plot_number == "12"
        assert p12_1.plot_number == "12/1"
        assert p120.plot_number == "120"
        assert p12A.plot_number == "12A"


# ==============================================================================
# 5. Cache Isolation Across Distinct Villages
# ==============================================================================

@pytest.mark.anyio
async def test_7_cache_isolation_across_distinct_villages(provider):
    """Verify Village A and Village B caches are completely isolated by village ID."""
    mock_a = {
        "type": "FeatureCollection",
        "features": [{"type": "Feature", "properties": {"revenue_plot": "101"}, "geometry": {"type": "Polygon", "coordinates": [[[85.0, 20.0], [85.1, 20.0], [85.1, 20.1], [85.0, 20.0]]]}}],
    }
    mock_b = {
        "type": "FeatureCollection",
        "features": [{"type": "Feature", "properties": {"revenue_plot": "202"}, "geometry": {"type": "Polygon", "coordinates": [[[86.0, 21.0], [86.1, 21.0], [86.1, 21.1], [86.0, 21.0]]]}}],
    }

    with patch.object(provider, "_get_client") as mock_client_factory:
        mock_client = AsyncMock()
        mock_client_factory.return_value.__aenter__.return_value = mock_client

        mock_client.post.return_value = Response(200, text=json.dumps(mock_a))
        fc_a = await provider.get_village_parcels(village_id="0301088", district_name="Cuttack", block_name="Athagarh")

        mock_client.post.return_value = Response(200, text=json.dumps(mock_b))
        fc_b = await provider.get_village_parcels(village_id="2008007", district_name="Khurda", block_name="Balianta")

        assert fc_a.village_id == "0301088"
        assert fc_a.features[0].properties["plot_number"] == "101"

        assert fc_b.village_id == "2008007"
        assert fc_b.features[0].properties["plot_number"] == "202"


# ==============================================================================
# 6. Data Unavailable vs Error vs Empty GeoJSON Handling
# ==============================================================================

@pytest.mark.anyio
async def test_8_empty_parcels_returns_clean_zero_collection(provider):
    """Verify villages with no surveyed parcels return 0 parcels without crash or fallback."""
    with patch.object(provider, "_get_client") as mock_client_factory:
        mock_client = AsyncMock()
        mock_client_factory.return_value.__aenter__.return_value = mock_client
        mock_client.post.return_value = Response(200, text='{"type":"FeatureCollection","features":[]}')

        fc = await provider.get_village_parcels(village_id="9999999", district_name="Cuttack", block_name="Test")
        assert fc.total_parcels == 0
        assert len(fc.features) == 0


@pytest.mark.anyio
async def test_9_whitespace_prefixed_geojson_tolerant_parsing(provider):
    """Verify tolerance against 4K GEO PHP leading tabs and Windows CRLF whitespace."""
    raw_php_output = '\t\t\r\n{"type":"FeatureCollection","crs":{"type":"name","properties":{"name":"EPSG:3857"}},"features":[{"type":"Feature","properties":{"revenue_plot":"888"},"geometry":{"type":"Polygon","coordinates":[[[9544177.0, 2330000.0], [9544200.0, 2330000.0], [9544200.0, 2330050.0], [9544177.0, 2330000.0]]]}}]}'

    with patch.object(provider, "_get_client") as mock_client_factory:
        mock_client = AsyncMock()
        mock_client_factory.return_value.__aenter__.return_value = mock_client
        mock_client.post.return_value = Response(200, text=raw_php_output)

        fc = await provider.get_village_parcels(village_id="1108050", district_name="Puri", block_name="Astarang")
        assert fc.total_parcels == 1
        assert fc.features[0].properties["plot_number"] == "888"


# ==============================================================================
# 7. Endpoint Integration (FastAPI Client)
# ==============================================================================

def test_10_api_endpoint_village_parcels_with_district_block(client):
    """Verify GET /api/v1/gis/village/{village_id}/parcels route passes query params."""
    response = client.get("/api/v1/gis/village/2008007/parcels?district_name=Khurda&block_name=Balianta")
    assert response.status_code == 200
    data = response.json()
    assert data["village_id"] == "2008007"
    assert "features" in data


def test_11_api_endpoint_village_extent_with_fallback(client):
    """Verify GET /api/v1/gis/village/{village_id}/extent route."""
    response = client.get("/api/v1/gis/village/2008007/extent?gp_id=2008001")
    assert response.status_code in [200, 404]

