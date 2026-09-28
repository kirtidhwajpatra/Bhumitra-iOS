"""
Statewide GIS Tahasil Coverage Tests
Validates that get_tahasils_geojson_for_district() returns valid geometry for all
26 of 30 Odisha districts, and honest geometry_available=false for the 4 absent ones.
"""

import pytest
from services.gis_navigation_service import GISNavigationService

# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def svc():
    return GISNavigationService()


# ---------------------------------------------------------------------------
# Coverage matrix for all 30 districts
# (district_id, district_name, expected_min_features, is_custom_file)
# ---------------------------------------------------------------------------

ALL_DISTRICTS = [
    ("161", "Anugul",        10, False),
    ("218", "Baleswar",      10, False),
    ("171", "Baragarh",       8, False),
    ("178", "Bhadrak",        8, False),
    ("162", "Bolangir",       8, False),
    ("177", "Boudh",          3, False),
    ("150", "Deogarh",        3, False),
    ("107", "Dhenkanal",      8, False),
    ("133", "Gajapati",       5, False),
    ("104", "Ganjam",        15, False),
    ("202", "Jagatsingpur",   5, False),
    ("73",  "Jajpur",        10, False),
    ("51",  "Jharsuguda",     5, False),
    ("52",  "Kalahandi",      8, False),
    ("278", "Kandhamal",     10, False),
    ("200", "Kendrapada",     8, False),
    ("234", "Khurda",        10, False),
    ("282", "Mayurbhanj",    15, False),
    ("111", "Nayagarh",       8, False),
    ("130", "Nuapada",        3, False),
    ("60",  "Puri",          10, False),
    ("47",  "Sambalpur",     10, False),
    ("238", "Sonepur",        5, False),
    ("72",  "Sundargarh",    15, False),
    ("224", "Keonjhar",      10, True),
    ("306", "Cuttack",       14, True),
    ("120", "Koraput",        0, False),
    ("116", "Malkanagiri",    0, False),
    ("300", "Nawarangpur",    0, False),
    ("22",  "Rayagada",       0, False),
]

DISTRICTS_WITH_GEOMETRY = [(d, n) for d, n, m, _ in ALL_DISTRICTS if m > 0]


@pytest.mark.parametrize("district_id,district_name,min_features,_", ALL_DISTRICTS)
def test_tahasil_feature_count(svc, district_id, district_name, min_features, _):
    result = svc.get_tahasils_geojson_for_district(district_id)
    features = result.get("features", [])
    assert isinstance(features, list)
    if min_features > 0:
        assert len(features) >= min_features, (
            f"{district_name}: expected >= {min_features} features, got {len(features)}"
        )
    else:
        assert len(features) == 0
        assert result.get("geometry_available") is False, (
            f"{district_name}: geometry_available must be False"
        )


@pytest.mark.parametrize("district_id,district_name", DISTRICTS_WITH_GEOMETRY)
def test_tahasil_feature_schema(svc, district_id, district_name):
    result = svc.get_tahasils_geojson_for_district(district_id)
    for i, feat in enumerate(result.get("features", [])):
        props = feat.get("properties", {})
        label = f"{district_name}[{i}]"
        assert props.get("tahasil_id"), f"{label}: missing tahasil_id"
        assert props.get("tahasil_name"), f"{label}: missing tahasil_name"
        assert props.get("district_id"), f"{label}: missing district_id"
        bbox = props.get("bbox", [])
        assert len(bbox) == 4, f"{label}: bbox must have 4 elements"
        assert bbox[0] < bbox[2], f"{label}: bbox min_lng >= max_lng"
        assert bbox[1] < bbox[3], f"{label}: bbox min_lat >= max_lat"
        assert 78.0 <= bbox[0] <= 90.0, f"{label}: bbox lng out of Odisha range"
        assert 15.0 <= bbox[1] <= 24.0, f"{label}: bbox lat out of Odisha range"
        center = props.get("center", [])
        assert len(center) == 2, f"{label}: center must have 2 elements"
        assert props.get("is_visualization_boundary") is True, f"{label}: is_visualization_boundary must be True"
        assert "visualization" in (props.get("classification") or "").lower(), f"{label}: missing classification"
        assert feat.get("geometry") is not None, f"{label}: geometry must not be null"
        assert feat["geometry"].get("type") in ("Polygon", "MultiPolygon")


@pytest.mark.parametrize("district_id,district_name", DISTRICTS_WITH_GEOMETRY)
def test_no_duplicate_tahasil_ids(svc, district_id, district_name):
    result = svc.get_tahasils_geojson_for_district(district_id)
    ids = [f["properties"]["tahasil_id"] for f in result.get("features", [])]
    assert len(ids) == len(set(ids)), f"{district_name}: duplicate tahasil_ids: {[x for x in ids if ids.count(x) > 1]}"


@pytest.mark.parametrize("district_id,district_name", DISTRICTS_WITH_GEOMETRY)
def test_geometry_available_true_for_present(svc, district_id, district_name):
    result = svc.get_tahasils_geojson_for_district(district_id)
    assert result.get("geometry_available", True) is True


def test_keonjhar_custom_file_names(svc):
    result = svc.get_tahasils_geojson_for_district("224")
    names = {f["properties"]["tahasil_name"] for f in result.get("features", [])}
    expected = {"Anandapur", "Barbil", "Champua", "Kendujhar Sadar", "Telkoi",
                "Ghatgaon", "Hatadihi", "Patna", "Harichandanpur", "Banspal",
                "Ghasipura", "Jhumpura", "Saharpada"}
    assert expected == names, f"Keonjhar missing: {expected - names}, extra: {names - expected}"


def test_per_district_cache(svc):
    r1 = svc.get_tahasils_geojson_for_district("107")
    r2 = svc.get_tahasils_geojson_for_district("107")
    assert r1 is r2, "Second call should return cached dict (same object)"


def test_census_index_loaded_once(svc):
    svc2 = GISNavigationService()
    assert svc2._census_index is None
    svc2.get_tahasils_geojson_for_district("107")
    assert svc2._census_index is not None
    idx_id = id(svc2._census_index)
    svc2.get_tahasils_geojson_for_district("161")
    assert id(svc2._census_index) == idx_id, "Census index must not be reloaded"


def test_bbox_and_centroid_polygon():
    geom = {
        "type": "Polygon",
        "coordinates": [[[80.0, 20.0], [82.0, 20.0], [82.0, 22.0], [80.0, 22.0], [80.0, 20.0]]]
    }
    bbox, center = GISNavigationService._bbox_and_centroid(geom)
    assert bbox == [80.0, 20.0, 82.0, 22.0]
    assert center == [81.0, 21.0]


def test_bbox_and_centroid_empty():
    bbox, center = GISNavigationService._bbox_and_centroid({"type": "Polygon", "coordinates": []})
    assert bbox == [0.0, 0.0, 0.0, 0.0]
    assert center == [0.0, 0.0]
