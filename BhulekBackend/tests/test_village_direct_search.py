"""
Village-level direct search
===========================
Search results for revenue villages must carry the full identity the manual
District → Tahasil → Village picker produces, so clients can open the village
directly without a coordinate re-resolution step. Also covers proximity ranking,
correct district naming, speed of the precomputed indexes, and the `near` API
parameter.
"""
import time

import pytest
from httpx import AsyncClient, ASGITransport

from app import create_app
from services.location_search_service import (
    LocationSearchService,
    LocationSearchResultType,
    LocalVillageCatalogIndex,
    MockGeocoderProvider,
)


@pytest.fixture
def svc():
    return LocationSearchService(provider=MockGeocoderProvider())


@pytest.fixture
def index():
    return LocalVillageCatalogIndex.get_instance()


def _villages(res):
    return [r for r in res.results if r.type == LocationSearchResultType.REVENUE_VILLAGE]


@pytest.mark.anyio
async def test_village_result_carries_full_direct_load_identity(svc):
    res = await svc.search("Patia", limit=5)
    patia = next(r for r in _villages(res) if r.revenueVillageId == "2002060")

    assert patia.directLoad is True
    assert patia.revenueVillage == "Patia"
    assert patia.villageNameOdia == "ପଟିଆ"
    assert patia.district == "Khordha"
    assert patia.districtId == "20"
    assert patia.tahasil == "Bhubaneswar"
    assert patia.tahasilId == "2"
    assert patia.bhulekhMouzaId == "60"
    # Same identity the map picker uses: 4K GEO district id + DDTT block code
    assert patia.gisDistrictId == "234"
    assert patia.gisBlockId == "2002"


@pytest.mark.anyio
async def test_district_name_comes_from_official_mapping_not_catalog_label(svc):
    # Catalog labels district 22 "Nawarangpur"; Fategarh tahasil is in Nayagarh.
    res = await svc.search("Patia", limit=10)
    fategarh = [r for r in _villages(res) if r.gisBlockId and r.gisBlockId.startswith("22")]
    assert fategarh, "expected a Patia in district 22"
    for r in fategarh:
        assert r.district == "Nayagarh"
        assert "Nayagarh District" in r.subtitle
        assert "Nawarangpur" not in r.subtitle


@pytest.mark.anyio
async def test_same_named_villages_are_not_merged(svc):
    res = await svc.search("raghunathpur", limit=10)
    ids = [r.revenueVillageId for r in _villages(res)]
    assert len(ids) == len(set(ids))
    assert len(ids) >= 5, "many distinct Raghunathpur villages exist; none should be deduped away"


@pytest.mark.anyio
async def test_proximity_hint_ranks_nearest_same_named_village_first(svc):
    far = await svc.search("raghunathpur", limit=5)
    near = await svc.search("raghunathpur", limit=5, near=(21.63, 85.58))  # Keonjhar town
    assert _villages(far)[0].district != "Keonjhar"
    assert _villages(near)[0].district == "Keonjhar"
    # The proximity hint must not change the result type mix or leak other tiers ahead
    assert all(r.type == LocationSearchResultType.REVENUE_VILLAGE for r in near.results)


@pytest.mark.anyio
async def test_compound_plot_keeps_village_identity(svc):
    res = await svc.search("plot 547 patia", limit=5)
    assert res.results and res.results[0].type == LocationSearchResultType.COMPOUND_PLOT
    top = res.results[0]
    assert top.parsedPlotNumber == "547"
    assert top.revenueVillageId == "2002060"
    assert top.directLoad is True
    assert top.gisBlockId == "2002"


def test_large_mouza_ids_are_not_marked_direct_loadable(index):
    # Mouza ids above 999 don't fit the DDTTVVV code, so clients must fall back.
    results = index.search_villages("ଆହାରି", district_id="9", tahasil_id="1", limit=10)
    big = [r for r in results if r.bhulekhMouzaId and int(r.bhulekhMouzaId) > 999]
    assert big, "fixture village with mouza id > 999 not found"
    assert all(r.directLoad is False for r in big)


def test_prefix_index_matches_brute_force(index):
    for prefix in ["tam", "ragh", "pati", "keri", "gob"]:
        brute = sorted((k for k in index.by_exact_norm if k.startswith(prefix) and k != prefix), key=lambda k: (len(k), k))
        assert index._prefix_keys(prefix, max_keys=50) == brute[:50]


def test_typo_buckets_cover_all_candidates_within_distance(index):
    q, max_d = "maidankel", 2
    expected = {k for k in index.by_exact_norm if k and k[0] == q[0] and abs(len(k) - len(q)) <= max_d}
    assert set(index._typo_keys(q, max_d)) == expected


@pytest.mark.anyio
async def test_village_search_is_fast(svc):
    queries = ["tam", "tamp", "kera", "naran", "gobind", "balia", "sundar", "ramapur", "patya", "maidankel"]
    t0 = time.perf_counter()
    for q in queries:
        svc._cache.clear()
        await svc.search(q, limit=10)
    avg_ms = (time.perf_counter() - t0) * 1000 / len(queries)
    assert avg_ms < 150, f"average village search took {avg_ms:.0f}ms"


@pytest.mark.anyio
async def test_near_parameter_over_http():
    transport = ASGITransport(app=create_app())
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        ok = await ac.get("/api/v1/location/search", params={"q": "raghunathpur", "limit": 5, "near": "21.63,85.58"})
        assert ok.status_code == 200
        top = ok.json()["results"][0]
        assert top["district"] == "Keonjhar"
        assert top["directLoad"] is True
        assert top["gisBlockId"].startswith("07")

        bad = await ac.get("/api/v1/location/search", params={"q": "patia", "near": "not-a-point"})
        assert bad.status_code == 400

        # Outside Odisha: accepted but ignored (normal ranking)
        outside = await ac.get("/api/v1/location/search", params={"q": "patia", "limit": 3, "near": "28.6,77.2"})
        assert outside.status_code == 200
        assert outside.json()["results"][0]["revenueVillageId"] == "2002060"


@pytest.mark.anyio
async def test_village_then_bare_plot_number_is_compound_plot(svc):
    for q in ["Patia 547", "patia 1182/2", "ପଟିଆ 547"]:
        res = await svc.search(q, limit=5)
        assert res.results, q
        top = res.results[0]
        assert top.type == LocationSearchResultType.COMPOUND_PLOT, q
        assert top.revenueVillageId == "2002060", q
        assert top.directLoad is True


def test_bare_suffix_does_not_swallow_other_intents():
    from services.location_search_service import detect_search_intent, SearchIntentType
    assert detect_search_intent("20.35, 85.81")[0] == SearchIntentType.COORDINATE
    assert detect_search_intent("751024")[0] == SearchIntentType.PIN_CODE
    assert detect_search_intent("547")[0] == SearchIntentType.PLOT_ONLY
    assert detect_search_intent("Plot 547 Patia")[0] == SearchIntentType.COMPOUND_PLOT
    assert detect_search_intent("Patia")[0] == SearchIntentType.GENERAL
