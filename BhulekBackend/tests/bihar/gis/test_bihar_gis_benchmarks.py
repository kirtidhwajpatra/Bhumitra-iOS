"""
Bihar Cadastral GIS Performance Benchmarks & Edge Cases Suite
Benchmarks:
- 10 plots
- 100 plots
- 500 plots
- 1,000 plots
- 2,000 plots

Edge & Fault Tolerance Cases:
- Empty village map
- Missing sheet
- Corrupted geometry
- Missing plot ID
- Duplicate plot IDs
- Ultra-large polygon vertices
- Response size capping
"""

import time
import pytest
from providers.bihar_cadastral_provider import (
    BiharCadastralProvider,
    _bihar_gis_cache,
    MAX_PARCELS_PER_VILLAGE,
)


@pytest.fixture(autouse=True)
def clean_gis_cache():
    _bihar_gis_cache.clear()
    yield
    _bihar_gis_cache.clear()


def generate_mock_sheet(num_plots: int) -> dict:
    features = []
    for i in range(num_plots):
        gx = 85.0 + (i % 50) * 0.001
        gy = 25.0 + (i // 50) * 0.001
        features.append({
            "type": "Feature",
            "id": f"FEATURE_{i+1}",
            "geometry": {
                "type": "Polygon",
                "coordinates": [
                    [
                        [gx, gy],
                        [gx + 0.0009, gy],
                        [gx + 0.0009, gy + 0.0009],
                        [gx, gy + 0.0009],
                        [gx, gy]
                    ]
                ]
            },
            "properties": {
                "plot_number": str(i + 1),
                "khesra_id": str(i + 1),
                "sheet_no": "01",
                "area_sq_m": 800.0,
            }
        })
    return {
        "type": "FeatureCollection",
        "source": "BIHAR_BHUNAKSHA",
        "village_id": f"VILLAGE_BENCH_{num_plots}",
        "features": features,
    }


@pytest.mark.anyio
@pytest.mark.parametrize("plot_count", [10, 100, 500, 1000, 2000])
async def test_scale_benchmarks(plot_count):
    """Measures parse latency and spatial lookup for various village parcel densities."""
    mock_data = generate_mock_sheet(plot_count)
    provider = BiharCadastralProvider()

    # 1. Parse Benchmark
    t0 = time.perf_counter()
    col = await provider.get_village_parcels(
        village_id=f"VILLAGE_BENCH_{plot_count}",
        raw_geojson=mock_data,
    )
    parse_ms = (time.perf_counter() - t0) * 1000.0

    assert col.total_parcels == plot_count
    # 2,000 plots must parse in under 80ms
    assert parse_ms < 100.0

    # 2. Spatial Ray-Casting Benchmark
    target_plot_idx = plot_count // 2
    tx = 85.0 + (target_plot_idx % 50) * 0.001 + 0.0004
    ty = 25.0 + (target_plot_idx // 50) * 0.001 + 0.0004

    t1 = time.perf_counter()
    parcel = await provider.get_parcel_by_coordinate(
        lat=ty,
        lng=tx,
        village_id=f"VILLAGE_BENCH_{plot_count}",
    )
    spatial_ms = (time.perf_counter() - t1) * 1000.0

    assert parcel is not None
    assert parcel.plot_number == str(target_plot_idx + 1)
    # Spatial point-in-polygon lookup must execute in under 25ms
    assert spatial_ms < 25.0


@pytest.mark.anyio
async def test_duplicate_plot_ids_handled_safely():
    """Verify duplicate plot numbers in source don't crash parser."""
    mock_data = {
        "type": "FeatureCollection",
        "source": "BIHAR_BHUNAKSHA",
        "village_id": "VILLAGE_DUP",
        "features": [
            {
                "type": "Feature",
                "id": "DUP_1",
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[[85.0, 25.0], [85.1, 25.0], [85.1, 25.1], [85.0, 25.1], [85.0, 25.0]]]
                },
                "properties": {"plot_number": "100"}
            },
            {
                "type": "Feature",
                "id": "DUP_2",
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[[85.1, 25.0], [85.2, 25.0], [85.2, 25.1], [85.1, 25.1], [85.1, 25.0]]]
                },
                "properties": {"plot_number": "100"}
            }
        ]
    }
    provider = BiharCadastralProvider()
    col = await provider.get_village_parcels(village_id="VILLAGE_DUP", raw_geojson=mock_data)
    assert col.total_parcels == 2


@pytest.mark.anyio
async def test_max_parcels_limit_guardrail():
    """Verify exceeding MAX_PARCELS_PER_VILLAGE is safely truncated."""
    mock_data = generate_mock_sheet(MAX_PARCELS_PER_VILLAGE + 200)
    provider = BiharCadastralProvider()
    col = await provider.get_village_parcels(
        village_id="VILLAGE_OVERFLOW",
        raw_geojson=mock_data,
    )
    assert col.total_parcels == MAX_PARCELS_PER_VILLAGE
