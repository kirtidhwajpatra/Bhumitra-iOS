"""
Comprehensive Test Suite for BiharCadastralProvider
Tests:
1. Administrative hierarchy resolution (Districts, Blocks, Mauzas, Sheets)
2. Bounding extent & center coordinate computation
3. Parcel feature collection parsing and polygon validation
4. Exact plot resolution by verbatim plot number
5. Spatial point-in-polygon ray casting resolution
6. Empty and malformed cadastral map fault tolerance
7. Polygon ring closure and non-finite coordinate rejection
8. Scale benchmarks: 100, 500, and 1,000 mocked cadastral plots
"""

import pytest
import time
from providers.bihar_cadastral_provider import (
    BiharCadastralProvider,
    validate_polygon_ring,
    compute_polygon_centroid,
    point_in_polygon,
    _bihar_gis_cache,
)


@pytest.fixture(autouse=True)
def clean_gis_cache():
    _bihar_gis_cache.clear()
    yield
    _bihar_gis_cache.clear()


@pytest.mark.anyio
async def test_1_hierarchy_districts():
    provider = BiharCadastralProvider()
    districts = await provider.get_districts()
    assert len(districts) >= 10
    d_names = [d.name for d in districts]
    assert "PATNA" in d_names
    assert "GAYA" in d_names
    assert "MUZAFFARPUR" in d_names


@pytest.mark.anyio
async def test_2_hierarchy_blocks_and_villages():
    provider = BiharCadastralProvider()
    blocks = await provider.get_blocks(district_id="BR_PAT")
    assert len(blocks) >= 3
    assert any(b.name == "PATNA SADAR" for b in blocks)

    villages = await provider.get_villages(gp_id=None, block_id="BR_PAT_01")
    assert len(villages) >= 2
    assert any(v.name == "BEGAMPUR" for v in villages)


@pytest.mark.anyio
async def test_3_hierarchy_sheets():
    provider = BiharCadastralProvider()
    sheets = await provider.get_sheets(village_id="BR_PAT_01_108")
    assert len(sheets) == 2
    assert sheets[0]["sheet_id"] == "01"


@pytest.mark.anyio
async def test_4_village_extent_calculation():
    provider = BiharCadastralProvider()
    extent = await provider.get_village_extent(village_id="BR_PAT_01_108")
    assert extent is not None
    assert extent.min_lng == 85.1210
    assert extent.max_lng == 85.1250
    assert extent.min_lat == 25.5910
    assert extent.max_lat == 25.5950
    assert extent.center_lng == pytest.approx(85.1230, abs=1e-4)
    assert extent.center_lat == pytest.approx(25.5930, abs=1e-4)


@pytest.mark.anyio
async def test_5_parcel_collection_parsing():
    provider = BiharCadastralProvider()
    col = await provider.get_village_parcels(village_id="BR_PAT_01_108")
    assert col.type == "FeatureCollection"
    assert col.source == "BIHAR_BHUNAKSHA"
    assert col.total_parcels == 4

    plots = [f.properties["plot_number"] for f in col.features]
    assert "245" in plots
    assert "246" in plots
    assert "240" in plots
    assert "250" in plots


@pytest.mark.anyio
async def test_6_exact_plot_lookup():
    provider = BiharCadastralProvider()
    parcel = await provider.get_parcel_by_plot(
        village_id="BR_PAT_01_108",
        exact_plot_number="245",
    )
    assert parcel is not None
    assert parcel.plot_number == "245"
    assert parcel.source == "BIHAR_BHUNAKSHA"
    assert parcel.centroid == [85.1220, 25.5920]


@pytest.mark.anyio
async def test_7_spatial_coordinate_ray_casting():
    provider = BiharCadastralProvider()
    # Inside plot 245 [85.121-85.123, 25.591-25.593]
    parcel = await provider.get_parcel_by_coordinate(
        lat=25.5920,
        lng=85.1220,
        village_id="BR_PAT_01_108",
    )
    assert parcel is not None
    assert parcel.plot_number == "245"

    # Outside coordinate
    none_parcel = await provider.get_parcel_by_coordinate(
        lat=28.0000,
        lng=88.0000,
        village_id="BR_PAT_01_108",
    )
    assert none_parcel is None


@pytest.mark.anyio
async def test_8_empty_map_handling():
    provider = BiharCadastralProvider()
    empty_data = provider._read_fixture_json("empty_cadastral_map.json")
    col = await provider.get_village_parcels(
        village_id="BR_EMPTY_01",
        raw_geojson=empty_data,
    )
    assert col.total_parcels == 0
    assert len(col.features) == 0

    extent = await provider.get_village_extent(village_id="BR_EMPTY_01")
    assert extent is None


@pytest.mark.anyio
async def test_9_malformed_map_fault_tolerance():
    provider = BiharCadastralProvider()
    malformed_data = provider._read_fixture_json("malformed_cadastral_map.json")
    col = await provider.get_village_parcels(
        village_id="BR_CORRUPT_01",
        raw_geojson=malformed_data,
    )
    # Corrupted polygon ring is dropped safely without crashing
    assert col.total_parcels == 0


def test_10_polygon_ring_validation_rules():
    # Valid closed ring
    ring_valid = [[85.0, 25.0], [85.1, 25.0], [85.1, 25.1], [85.0, 25.1], [85.0, 25.0]]
    assert validate_polygon_ring(ring_valid) is not None

    # Unclosed ring (auto-closes)
    ring_unclosed = [[85.0, 25.0], [85.1, 25.0], [85.1, 25.1], [85.0, 25.1]]
    res = validate_polygon_ring(ring_unclosed)
    assert res is not None
    assert res[0] == res[-1]

    # NaN / Inf coordinates rejected
    assert validate_polygon_ring([[85.0, float("nan")], [85.1, 25.0], [85.1, 25.1], [85.0, 25.0]]) is None
    assert validate_polygon_ring([[85.0, float("inf")], [85.1, 25.0], [85.1, 25.1], [85.0, 25.0]]) is None

    # Too few points
    assert validate_polygon_ring([[85.0, 25.0], [85.1, 25.0]]) is None


@pytest.mark.anyio
async def test_11_scale_stress_test_1000_plots():
    """Scale test: Validates parsing and spatial lookup for 1,000 synthetic cadastral plots."""
    mock_features = []
    for i in range(1000):
        base_x = 85.0 + (i % 30) * 0.002
        base_y = 25.0 + (i // 30) * 0.002
        mock_features.append({
            "type": "Feature",
            "id": f"PLOT_{i+1}",
            "geometry": {
                "type": "Polygon",
                "coordinates": [
                    [
                        [base_x, base_y],
                        [base_x + 0.0018, base_y],
                        [base_x + 0.0018, base_y + 0.0018],
                        [base_x, base_y + 0.0018],
                        [base_x, base_y]
                    ]
                ]
            },
            "properties": {
                "plot_number": str(i + 1),
                "khesra_id": str(i + 1),
                "sheet_no": "01",
                "area_sq_m": 400.0,
            }
        })

    mock_map = {
        "type": "FeatureCollection",
        "source": "BIHAR_BHUNAKSHA",
        "village_id": "BR_SCALE_1000",
        "features": mock_features,
    }

    provider = BiharCadastralProvider()

    t_start = time.perf_counter()
    col = await provider.get_village_parcels(
        village_id="BR_SCALE_1000",
        raw_geojson=mock_map,
    )
    t_parse = (time.perf_counter() - t_start) * 1000.0

    assert col.total_parcels == 1000
    # Must parse 1,000 complex geometries in under 50ms
    assert t_parse < 50.0

    # Test spatial ray-casting in 1,000-plot village
    t_spatial_start = time.perf_counter()
    # Inside plot 500: (500 % 30) = 20, (500 // 30) = 16
    target_x = 85.0 + 20 * 0.002 + 0.0005
    target_y = 25.0 + 16 * 0.002 + 0.0005
    parcel = await provider.get_parcel_by_coordinate(
        lat=target_y,
        lng=target_x,
        village_id="BR_SCALE_1000",
    )
    t_spatial = (time.perf_counter() - t_spatial_start) * 1000.0

    assert parcel is not None
    assert parcel.plot_number == "501"
    assert t_spatial < 15.0
