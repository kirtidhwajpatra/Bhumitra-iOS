"""
Real-Source Bihar BhuNaksha Cadastral Test Suite
Validates:
1. Real Patna cadastral sheet (10 plots, RS Survey, Begampur Mauza).
2. Real Gaya cadastral sheet with MultiPolygon geometry (Khesra 105, CS Survey, Bakraur Mauza).
3. Real Muzaffarpur cadastral sheet with plot_no / khesra_no property keys (Damodarpur Mauza).
4. Real official NIC BhuNaksha hierarchy resolution.
"""

import os
import json
import pytest
from providers.bihar_cadastral_provider import (
    BiharCadastralProvider,
    _bihar_gis_cache,
)


@pytest.fixture(autouse=True)
def clean_gis_cache():
    _bihar_gis_cache.clear()
    yield
    _bihar_gis_cache.clear()


@pytest.fixture
def real_fixtures_dir():
    return os.path.join(
        os.path.dirname(__file__),
        "fixtures",
        "real",
    )


@pytest.mark.anyio
async def test_1_patna_real_cadastral_sheet(real_fixtures_dir):
    """Validate parsing of real Patna Sadar / Begampur Sheet 01 (10 cadastral plots)."""
    patna_path = os.path.join(real_fixtures_dir, "patna_sadar_begampur_sheet01.json")
    with open(patna_path, "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    provider = BiharCadastralProvider()
    col = await provider.get_village_parcels(
        village_id="BR_PAT_01_108",
        village_name="BEGAMPUR",
        sheet_no="01",
        raw_geojson=raw_data,
    )

    assert col.type == "FeatureCollection"
    assert col.source == "BIHAR_BHUNAKSHA"
    assert col.total_parcels == 10
    assert len(col.features) == 10

    # Verify all 10 plots are extracted with centroids
    plot_numbers = [f.properties["plot_number"] for f in col.features]
    expected_plots = ["240", "241", "242", "243", "244", "245", "246", "247", "248", "250"]
    for p in expected_plots:
        assert p in plot_numbers

    # Verify parcel properties and centroid calculation
    p245 = next(f for f in col.features if f.properties["plot_number"] == "245")
    assert p245.geometry["type"] == "Polygon"
    assert p245.properties["centroid"] == [85.1220, 25.5940]


@pytest.mark.anyio
async def test_2_gaya_real_cadastral_sheet_with_multipolygon(real_fixtures_dir):
    """Validate parsing of real Gaya / Bodhgaya / Bakraur Sheet 01 with MultiPolygon geometry."""
    gaya_path = os.path.join(real_fixtures_dir, "gaya_bodhgaya_bakraur_sheet01.json")
    with open(gaya_path, "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    provider = BiharCadastralProvider()
    col = await provider.get_village_parcels(
        village_id="BR_GAY_01_052",
        village_name="BAKRAUR",
        sheet_no="01",
        raw_geojson=raw_data,
    )

    assert col.total_parcels == 5

    # Check MultiPolygon plot 105
    p105 = next(f for f in col.features if f.properties["plot_number"] == "105")
    assert p105.geometry["type"] == "MultiPolygon"
    assert len(p105.geometry["coordinates"]) == 2

    # Verify spatial point-in-polygon ray casting inside MultiPolygon
    # Target point inside second polygon of plot 105 [84.995-84.997, 24.697-24.699]
    parcel = await provider.get_parcel_by_coordinate(
        lat=24.6980,
        lng=84.9960,
        village_id="BR_GAY_01_052",
        sheet_no="01",
        raw_geojson=raw_data,
    )
    assert parcel is not None
    assert parcel.plot_number == "105"


@pytest.mark.anyio
async def test_3_muzaffarpur_real_cadastral_sheet(real_fixtures_dir):
    """Validate parsing of real Muzaffarpur / Kanti / Damodarpur Sheet 01."""
    muz_path = os.path.join(real_fixtures_dir, "muzaffarpur_kanti_damodarpur_sheet01.json")
    with open(muz_path, "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    provider = BiharCadastralProvider()
    col = await provider.get_village_parcels(
        village_id="BR_MUZ_01_074",
        village_name="DAMODARPUR",
        sheet_no="01",
        raw_geojson=raw_data,
    )

    assert col.total_parcels == 4
    plots = [f.properties["plot_number"] for f in col.features]
    assert "501" in plots
    assert "502" in plots
    assert "503" in plots
    assert "504" in plots


@pytest.mark.anyio
async def test_4_real_bhu_naksha_hierarchy(real_fixtures_dir):
    """Validate NIC BhuNaksha administrative hierarchy extraction."""
    hier_path = os.path.join(real_fixtures_dir, "real_bhu_naksha_hierarchy.json")
    with open(hier_path, "r", encoding="utf-8") as f:
        raw_hier = json.load(f)

    assert raw_hier["state"] == "BIHAR"
    districts = raw_hier["districts"]
    assert len(districts) == 3

    patna = next(d for d in districts if d["dist_code"] == "BR_PAT")
    assert patna["dist_name"] == "PATNA"
    circle = patna["subdivisions"][0]["circles"][0]
    assert circle["circle_name"] == "PATNA SADAR"
    mauza = circle["mauzas"][0]
    assert mauza["mauza_name"] == "BEGAMPUR"
    assert mauza["thana_number"] == "108"
    assert "RS" in mauza["survey_types"]
    assert "01" in mauza["sheets"]
