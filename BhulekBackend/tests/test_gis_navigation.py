"""
Tests for Bhumitra GIS Navigation Router & Service
Validates the isolated 30-district geospatial navigation pipeline for Odisha.
"""

import pytest
from fastapi.testclient import TestClient
from main import app
from services.gis_navigation_service import gis_navigation_service

client = TestClient(app)


def test_get_districts_geojson():
    response = client.get("/api/v1/gis/navigation/districts-geojson")
    assert response.status_code == 200
    data = response.json()
    assert data.get("type") == "FeatureCollection"
    features = data.get("features", [])
    assert len(features) == 30, f"Expected 30 districts, got {len(features)}"

    # Verify attributes on each feature
    for feat in features:
        assert feat.get("type") == "Feature"
        props = feat.get("properties", {})
        assert "district_id" in props
        assert "district_name" in props
        assert "code_2digit" in props
        assert "center" in props
        assert "bbox" in props
        assert len(props["center"]) == 2
        assert len(props["bbox"]) == 4

        # Verify coordinate boundaries are within Odisha WGS84 bounding envelope (81-88°E, 17-23°N)
        lng, lat = props["center"]
        assert 81.0 <= lng <= 88.0, f"Longitude {lng} out of range for {props['district_name']}"
        assert 17.0 <= lat <= 23.0, f"Latitude {lat} out of range for {props['district_name']}"


def test_list_districts_summary():
    response = client.get("/api/v1/gis/navigation/districts")
    assert response.status_code == 200
    districts = response.json()
    assert len(districts) == 30
    cuttack = next((d for d in districts if d["name"] == "Cuttack"), None)
    assert cuttack is not None
    assert cuttack["id"] == "306"
    assert cuttack["code_2digit"] == "03"


def test_get_single_district():
    # By 4K GEO ID
    res_by_id = client.get("/api/v1/gis/navigation/districts/306")
    assert res_by_id.status_code == 200
    assert res_by_id.json()["name"] == "Cuttack"

    # By 2-digit code
    res_by_code = client.get("/api/v1/gis/navigation/districts/03")
    assert res_by_code.status_code == 200
    assert res_by_code.json()["name"] == "Cuttack"

    # Invalid ID
    res_invalid = client.get("/api/v1/gis/navigation/districts/9999")
    assert res_invalid.status_code == 404


def test_district_service_lookup():
    # Verify service get_district_by_id
    summary = gis_navigation_service.get_district_by_id("07")
    assert summary is not None
    assert summary.name == "Keonjhar"
    assert summary.id == "224"
    assert summary.code_2digit == "07"


def test_get_tahasils_geojson_keonjhar_and_cuttack():
    # Cuttack 14 Tahasils
    res_cuttack = client.get("/api/v1/gis/navigation/districts/306/tahasils-geojson")
    assert res_cuttack.status_code == 200
    assert len(res_cuttack.json().get("features", [])) == 14

    # Keonjhar 13 Tahasils
    res_keonjhar = client.get("/api/v1/gis/navigation/districts/224/tahasils-geojson")
    assert res_keonjhar.status_code == 200
    assert len(res_keonjhar.json().get("features", [])) == 13
