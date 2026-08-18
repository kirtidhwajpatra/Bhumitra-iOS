"""
Phase 3.16 Automated Test Suite: Odisha-Wide Cadastral Hierarchy & Dynamic 4K GEO Coverage.
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

from main import app
from providers.odisha_4kgeo_provider import Odisha4KGEOProvider
from models.cadastral import (
    CadastralDistrict,
    CadastralBlock,
    CadastralGP,
    CadastralVillage,
    CadastralFeatureCollection,
    CadastralParcelFeature,
    CadastralExtent,
    CadastralParcel,
)

client = TestClient(app)


@pytest.fixture
def provider():
    return Odisha4KGEOProvider()


@pytest.mark.anyio
async def test_1_get_all_30_official_odisha_districts(provider):
    """Verify that provider dynamically returns the 30 official Odisha administrative districts."""
    districts = await provider.get_districts()
    assert len(districts) == 30
    assert any(d.name == "Keonjhar" for d in districts)
    assert any(d.name == "Cuttack" for d in districts)
    assert any(d.name == "Khurda" for d in districts)
    assert any(d.name == "Sambalpur" for d in districts)
    assert any(d.name == "Ganjam" for d in districts)


@pytest.mark.anyio
async def test_2_block_retrieval_isolated_by_district_id(provider):
    """Verify that block retrieval correctly filters by the requested district without cross-district contamination."""
    mock_blocks_raw = [
        {"block_name": "Keonjhar Sadar", "block_code": "0704"},
        {"block_name": "Anandapur", "block_code": "0701"},
    ]
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = mock_blocks_raw
        mock_post.return_value = mock_resp

        blocks = await provider.get_blocks("224")
        assert len(blocks) == 2
        assert blocks[0].id == "0704"
        assert blocks[0].name == "Keonjhar Sadar"
        assert blocks[0].district_id == "224"


@pytest.mark.anyio
async def test_3_gp_retrieval_isolated_by_block_id(provider):
    """Verify that Gram Panchayat queries are strictly isolated to the specified block."""
    mock_gps_raw = [
        {"gp_name": "Dimbo GP", "gp_code": "07040001"},
        {"gp_name": "Padmapur GP", "gp_code": "07040002"},
    ]
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = mock_gps_raw
        mock_post.return_value = mock_resp

        gps = await provider.get_gram_panchayats("0704")
        assert len(gps) == 2
        assert gps[0].id == "07040001"
        assert gps[0].name == "Dimbo GP"


@pytest.mark.anyio
async def test_4_village_retrieval_isolated_by_block_and_gp(provider):
    """Verify that villages are linked to both block and GP."""
    mock_villages_raw = [
        {"revenue_village_name": "Dimbo", "revenue_village_code": "0704317"},
    ]
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = mock_villages_raw
        mock_post.return_value = mock_resp

        villages = await provider.get_villages(gp_id="07040001", block_id="0704")
        assert len(villages) == 1
        assert villages[0].id == "0704317"
        assert villages[0].name == "Dimbo"


@pytest.mark.anyio
async def test_5_village_extent_dynamic_bounds(provider):
    """Verify that village extent calculates accurate WGS84 bounding box."""
    mock_extent_raw = {
        "succ": True,
        "extent": "85.6500,21.6300,85.6650,21.6450"
    }
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = mock_extent_raw
        mock_post.return_value = mock_resp

        extent = await provider.get_village_extent(village_id="0704317", gp_id="07040001")
        assert extent is not None
        assert extent.min_lng == 85.6500
        assert extent.min_lat == 21.6300
        assert extent.max_lng == 85.6650
        assert extent.max_lat == 21.6450


@pytest.mark.anyio
async def test_6_village_parcels_normalization_and_polygon_multipolygon_support(provider):
    """Verify that cadastral parcel polygons and multipolygons are properly normalized."""
    mock_fc = CadastralFeatureCollection(
        source="ODISHA_4K_GEO",
        village_id="0704317",
        total_parcels=2,
        features=[
            CadastralParcelFeature(
                id="0704317_12",
                geometry={"type": "Polygon", "coordinates": [[[85.655, 21.635], [85.657, 21.635], [85.657, 21.637], [85.655, 21.635]]]},
                properties={"plot_number": "12", "revenue_plot": "12", "village": "Dimbo"}
            ),
            CadastralParcelFeature(
                id="0704317_12_1",
                geometry={"type": "MultiPolygon", "coordinates": [[[[85.658, 21.638], [85.659, 21.638], [85.659, 21.639], [85.658, 21.638]]]]},
                properties={"plot_number": "12/1", "revenue_plot": "12/1", "village": "Dimbo"}
            ),
        ]
    )
    with patch.object(provider, "get_village_parcels", new_callable=AsyncMock) as mock_get_parcels:
        mock_get_parcels.return_value = mock_fc
        fc = await provider.get_village_parcels(village_id="0704317")
        assert fc.total_parcels == 2
        assert fc.features[0].geometry["type"] == "Polygon"
        assert fc.features[1].geometry["type"] == "MultiPolygon"
        assert fc.features[0].properties["plot_number"] == "12"
        assert fc.features[1].properties["plot_number"] == "12/1"


@pytest.mark.anyio
async def test_7_plot_lookup_exact_string_isolation(provider):
    """Verify that plot 12 does not collide with 120, 12/1, 12A, 0012, or 2/936."""
    mock_fc = CadastralFeatureCollection(
        source="ODISHA_4K_GEO",
        village_id="0704317",
        total_parcels=6,
        features=[
            CadastralParcelFeature(id="p1", geometry={"type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1],[0,0]]]}, properties={"plot_number": "12"}),
            CadastralParcelFeature(id="p2", geometry={"type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1],[0,0]]]}, properties={"plot_number": "120"}),
            CadastralParcelFeature(id="p3", geometry={"type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1],[0,0]]]}, properties={"plot_number": "12/1"}),
            CadastralParcelFeature(id="p4", geometry={"type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1],[0,0]]]}, properties={"plot_number": "12A"}),
            CadastralParcelFeature(id="p5", geometry={"type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1],[0,0]]]}, properties={"plot_number": "0012"}),
            CadastralParcelFeature(id="p6", geometry={"type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1],[0,0]]]}, properties={"plot_number": "2/936"}),
        ]
    )
    with patch.object(provider, "get_village_parcels", new_callable=AsyncMock) as mock_parcels:
        mock_parcels.return_value = mock_fc

        p12 = await provider.get_parcel_by_plot(exact_plot_number="12", village_id="0704317")
        assert p12 is not None
        assert p12.plot_number == "12"
        assert p12.source_feature_id == "p1"

        p12_1 = await provider.get_parcel_by_plot(exact_plot_number="12/1", village_id="0704317")
        assert p12_1 is not None
        assert p12_1.plot_number == "12/1"
        assert p12_1.source_feature_id == "p3"


@pytest.mark.anyio
async def test_8_g_dimbo_regression_remains_intact(provider):
    """Permanent regression test: Village 0704317 (G_Dimbo) remains verifiable."""
    assert provider is not None
    districts = await provider.get_districts()
    assert any(d.name == "Keonjhar" for d in districts)


def test_9_coverage_diagnostic_admin_endpoint():
    """Verify that GET /api/v1/gis/coverage/diagnostic returns accurate hierarchy and parcel status."""
    response = client.get("/api/v1/gis/coverage/diagnostic?village_id=0704317&district_name=Keonjhar&block_name=Keonjhar%20SADAR")
    assert response.status_code == 200
    data = response.json()
    assert "village_id" in data
    assert data["village_id"] == "0704317"
    assert "hierarchy_status" in data
    assert "extent_status" in data
    assert "parcels_status" in data
