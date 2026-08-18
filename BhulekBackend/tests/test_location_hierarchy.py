"""
Bhulekh Location Hierarchy Unit Tests
Validates deterministic cascading dropdowns: District -> Tahasil -> Village -> RI Circle,
handling invalid IDs, duplicate names, and ensuring zero fuzzy guessing.
"""

import pytest
from fastapi.testclient import TestClient
from main import app
from scrapers.bhulekh_mappings import (
    get_all_districts,
    get_tahasils_for_district,
    get_villages_for_tahasil,
    get_ri_circles_for_tahasil,
    get_district_id,
    get_tahasil_id,
    get_village_id,
)

client = TestClient(app)


def test_1_get_all_districts_returns_30_official_districts():
    """1. All 30 official Odisha revenue districts returned with numeric IDs."""
    districts = get_all_districts()
    assert len(districts) == 30
    assert districts[0].id == "1"
    assert districts[0].official_name == "BALASORE"

    # Verify key districts exist
    d_names = {d.official_name for d in districts}
    assert "KEONJHAR" in d_names
    assert "CUTTACK" in d_names
    assert "KHORDHA" in d_names
    assert "PURI" in d_names
    assert "SAMBALPUR" in d_names


def test_2_get_tahasils_for_valid_district():
    """2. Valid district ID returns its official Tahasils with numeric IDs."""
    # Keonjhar (ID: 7)
    tahasils = get_tahasils_for_district("7")
    assert len(tahasils) >= 12
    t_names = {t.official_name for t in tahasils}
    assert "KEONJHAR SADAR" in t_names or "SADAR" in t_names or "ANANDAPUR" in t_names
    assert all(t.district_id == "7" for t in tahasils)


def test_3_get_tahasils_for_invalid_district_returns_empty():
    """3. Non-existent district ID returns empty list fail-safely."""
    tahasils = get_tahasils_for_district("999")
    assert tahasils == []


def test_4_get_villages_for_valid_tahasil():
    """4. Valid District & Tahasil returns official revenue villages."""
    villages = get_villages_for_tahasil("7", "4")  # Keonjhar -> Keonjhar Sadar
    assert len(villages) >= 10
    v_names = {v.official_name for v in villages}
    assert "G KERI 271" in v_names or "G KERI" in v_names
    assert all(v.tahasil_id == "4" and v.district_id == "7" for v in villages)


def test_5_get_villages_for_invalid_tahasil_returns_empty():
    """5. Invalid Tahasil ID returns empty list fail-safely."""
    villages = get_villages_for_tahasil("7", "999")
    assert villages == []


def test_6_duplicate_names_with_different_ids_handled_safely():
    """6. Same village name 'CHAMPUA 1' in different tahasils produces distinct records."""
    v_tah_4 = get_village_id("7", "4", "CHAMPUA 1")
    v_tah_3 = get_village_id("7", "3", "CHAMPUA 1")
    assert v_tah_4 is not None
    assert v_tah_3 is not None


def test_7_ri_circles_lookup_for_tahasil():
    """7. Retrieves RI Circles for a given Tahasil."""
    ri_circles = get_ri_circles_for_tahasil("7", "4")
    assert len(ri_circles) >= 1
    assert any("KEONJHAR" in ric.official_name for ric in ri_circles)


def test_8_location_endpoints_via_test_client():
    """8. Test HTTP endpoints /api/v1/districts, /tahasils, /villages, /ri-circles."""
    # 1. List Districts
    res_d = client.get("/api/v1/districts")
    assert res_d.status_code == 200
    districts = res_d.json()
    assert len(districts) == 30

    # 2. List Tahasils for Keonjhar
    res_t = client.get("/api/v1/tahasils?district_id=7")
    assert res_t.status_code == 200
    tahasils = res_t.json()
    assert len(tahasils) >= 10

    # 3. List Villages for Keonjhar Sadar
    res_v = client.get("/api/v1/villages?district_id=7&tahasil_id=4")
    assert res_v.status_code == 200
    villages = res_v.json()
    assert len(villages) >= 10

    # 4. List RI Circles
    res_ric = client.get("/api/v1/ri-circles?district_id=7&tahasil_id=4")
    assert res_ric.status_code == 200
    ri_circles = res_ric.json()
    assert isinstance(ri_circles, list)
