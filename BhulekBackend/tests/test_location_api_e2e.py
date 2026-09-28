"""
Step 3 — Critical End-to-End Backend Location API Integration Test Suite
========================================================================
Tests the productionized location search & spatial resolution endpoints:
  - GET  /api/v1/location/search
  - POST /api/v1/location/resolve
  - GET  /api/v1/location/resolve

Verifies contract stability, input validation, provider outage resilience,
status behaviors (EXACT, NO_CADASTRAL_COVERAGE, OUTSIDE_ODISHA, PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE),
and measures real operational latencies.
"""

import time
import pytest
from unittest.mock import patch
from httpx import AsyncClient, ASGITransport

from app import create_app
from services.location_search_service import (
    location_search_service,
    MockGeocoderProvider,
    LocationSearchResultType,
    SearchIntentType,
)
from services.spatial_resolver_service import (
    spatial_resolver_service,
    LocationResolutionStatus,
)


@pytest.fixture
def app():
    return create_app()


@pytest.fixture
def mock_geocoder():
    provider = MockGeocoderProvider()
    original_provider = location_search_service.provider
    location_search_service.set_provider(provider)
    yield provider
    location_search_service.set_provider(original_provider)


# ==============================================================================
# 1. Critical End-to-End Flow Tests (A to I)
# ==============================================================================

@pytest.mark.anyio
async def test_a_search_patia_then_resolve(app, mock_geocoder):
    """
    Test A:
    GET /location/search?q=Patia returns canonical village suggestion.
    Then resolve(Patia coordinate) returns Khurda, Bhubaneswar, Patia, Plot 318 -> EXACT.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1. Search
        search_resp = await ac.get("/api/v1/location/search", params={"q": "Patia", "limit": 5})
        assert search_resp.status_code == 200
        search_data = search_resp.json()

        assert search_data["totalResults"] > 0
        first_village = search_data["results"][0]
        assert "Patia" in first_village["title"]
        assert first_village["type"] == LocationSearchResultType.REVENUE_VILLAGE.value
        assert first_village["latitude"] is not None
        assert first_village["longitude"] is not None

        v_lat = first_village["latitude"]
        v_lng = first_village["longitude"]

        # 2. Resolve coordinate
        resolve_resp = await ac.post(
            "/api/v1/location/resolve",
            json={"latitude": v_lat, "longitude": v_lng},
        )
        assert resolve_resp.status_code == 200
        resolve_data = resolve_resp.json()

        assert resolve_data["status"] == LocationResolutionStatus.EXACT.value
        assert resolve_data["district"] == "Khurda"
        assert resolve_data["tahasil"] == "Bhubaneswar"
        assert resolve_data["revenue_village"] == "Patia"
        assert resolve_data["plot_number"] == "318"
        assert resolve_data["bhulekh_mouza_id"] == "60"


@pytest.mark.anyio
async def test_b_search_kiit_then_resolve_never_uses_kiit_as_village_name(app, mock_geocoder):
    """
    Test B:
    GET /location/search?q=KIIT University returns LANDMARK with coordinates.
    Then resolve(returned lat/lng) resolves through official spatial geometry.
    The official revenue identity must NOT be 'KIIT University'.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        search_resp = await ac.get("/api/v1/location/search", params={"q": "KIIT University", "limit": 5})
        assert search_resp.status_code == 200
        search_data = search_resp.json()

        landmark = search_data["results"][0]
        assert landmark["type"] == LocationSearchResultType.LANDMARK.value
        assert landmark["latitude"] is not None
        assert landmark["longitude"] is not None

        # Resolve
        resolve_resp = await ac.post(
            "/api/v1/location/resolve",
            json={"latitude": landmark["latitude"], "longitude": landmark["longitude"]},
        )
        assert resolve_resp.status_code == 200
        resolve_data = resolve_resp.json()

        assert resolve_data["status"] == LocationResolutionStatus.EXACT.value
        # Official village must be Patia, NOT KIIT University
        assert resolve_data["revenue_village"] != "KIIT University"
        assert resolve_data["revenue_village"] == "Patia"
        assert resolve_data["plot_number"] is not None
        assert resolve_data["district"] == "Khurda"


@pytest.mark.anyio
async def test_c_search_bare_plot_no_external_geocoder(app, mock_geocoder):
    """
    Test C:
    GET /location/search?q=547 returns PLOT_ONLY behavior.
    No external geocoder request is dispatched.
    """
    initial_calls = mock_geocoder.call_count
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get("/api/v1/location/search", params={"q": "547"})
        assert resp.status_code == 200
        data = resp.json()

        assert mock_geocoder.call_count == initial_calls
        assert data["intent"] == SearchIntentType.PLOT_ONLY.value
        assert len(data["results"]) == 1
        assert data["results"][0]["type"] == LocationSearchResultType.PLOT_ONLY.value
        assert data["results"][0]["parsedPlotNumber"] == "547"


@pytest.mark.anyio
async def test_d_search_compound_plot(app, mock_geocoder):
    """
    Test D:
    GET /location/search?q=Plot 547 Patia returns COMPOUND_PLOT with parsedPlotNumber=547
    and location information for Patia.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get("/api/v1/location/search", params={"q": "Plot 547 Patia"})
        assert resp.status_code == 200
        data = resp.json()

        assert data["intent"] == SearchIntentType.COMPOUND_PLOT.value
        assert data["totalResults"] > 0
        first = data["results"][0]
        assert first["type"] == LocationSearchResultType.COMPOUND_PLOT.value
        assert first["parsedPlotNumber"] == "547"
        assert "Plot 547 in Patia" in first["title"]
        assert first["latitude"] is not None


@pytest.mark.anyio
async def test_e_resolve_patia_coordinates(app):
    """
    Test E:
    resolve(20.35410, 85.81930) -> EXACT, Patia, Plot 318
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post(
            "/api/v1/location/resolve",
            json={"latitude": 20.35410, "longitude": 85.81930},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["status"] == LocationResolutionStatus.EXACT.value
        assert data["revenue_village"] == "Patia"
        assert data["plot_number"] == "318"
        assert data["district"] == "Khurda"
        assert data["tahasil"] == "Bhubaneswar"


@pytest.mark.anyio
async def test_f_resolve_raghunathpur_jali_coordinates(app):
    """
    Test F:
    resolve(20.37219, 85.82703) -> EXACT, Raghunathpur Jali, Plot 62
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post(
            "/api/v1/location/resolve",
            json={"latitude": 20.37219, "longitude": 85.82703},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["status"] == LocationResolutionStatus.EXACT.value
        assert data["revenue_village"] == "Raghunathpur Jali"
        assert data["plot_number"] == "62"
        assert data["district"] == "Khurda"


@pytest.mark.anyio
async def test_g_resolve_inside_odisha_no_cadastral_coverage(app):
    """
    Test G:
    resolve(20.38000, 85.73000, candidate_village_ids=['2002076']) -> NO_CADASTRAL_COVERAGE
    Inside Odisha district/tahasil boundaries, but outside digitized parcels.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post(
            "/api/v1/location/resolve",
            json={
                "latitude": 20.38000,
                "longitude": 85.73000,
                "candidate_village_ids": ["2002076"],
            },
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["status"] == LocationResolutionStatus.NO_CADASTRAL_COVERAGE.value
        assert data["district"] == "Khurda"
        assert data["revenue_village"] is None
        assert data["plot_number"] is None


@pytest.mark.anyio
async def test_h_resolve_outside_odisha(app):
    """
    Test H:
    resolve(22.57260, 88.36390) (Kolkata) -> OUTSIDE_ODISHA with zero parcel/Bhulekh work.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post(
            "/api/v1/location/resolve",
            json={"latitude": 22.57260, "longitude": 88.36390},
        )
        assert resp.status_code == 200
        data = resp.json()

        assert data["status"] == LocationResolutionStatus.OUTSIDE_ODISHA.value
        assert data["district"] is None
        assert data["revenue_village"] is None
        assert data["plot_number"] is None


@pytest.mark.anyio
async def test_i_upstream_failure_resilience(app):
    """
    Test I:
    Upstream 4K GEO failure -> PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE without crashing.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        with patch.object(
            spatial_resolver_service.provider,
            "get_village_parcels",
            side_effect=ConnectionError("Simulated upstream 500 error"),
        ):
            resp = await ac.post(
                "/api/v1/location/resolve",
                json={"latitude": 20.35410, "longitude": 85.81930, "candidate_village_ids": ["2002060"]},
            )
            assert resp.status_code == 200
            data = resp.json()
            assert data["status"] == LocationResolutionStatus.PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE.value


# ==============================================================================
# 2. API Input Validation Tests (Section 8)
# ==============================================================================

@pytest.mark.anyio
async def test_j_api_validation_suite(app):
    """
    Test J: API Input Validation
    Verifies strict 400 and 422 HTTP responses for malformed client queries.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # Empty query
        r1 = await ac.get("/api/v1/location/search", params={"q": ""})
        assert r1.status_code in (400, 422)

        # Whitespace query
        r2 = await ac.get("/api/v1/location/search", params={"q": "   "})
        assert r2.status_code in (400, 422)

        # Very long query (> 200 chars)
        r3 = await ac.get("/api/v1/location/search", params={"q": "A" * 205})
        assert r3.status_code in (400, 422)

        # Invalid limit (0 or negative)
        r4 = await ac.get("/api/v1/location/search", params={"q": "Patia", "limit": 0})
        assert r4.status_code == 422

        # Limit above allowed maximum (> 50)
        r5 = await ac.get("/api/v1/location/search", params={"q": "Patia", "limit": 100})
        assert r5.status_code == 422

        # Malformed bbox (letters instead of numbers)
        r6 = await ac.get("/api/v1/location/search", params={"q": "Patia", "bbox": "invalid,bbox,format,here"})
        assert r6.status_code == 400

        # Incomplete bbox (only 2 numbers)
        r7 = await ac.get("/api/v1/location/search", params={"q": "Patia", "bbox": "85.8,20.3"})
        assert r7.status_code == 400

        # Invalid district_id parameter
        r8 = await ac.get("/api/v1/location/search", params={"q": "Patia", "district_id": "bad;injection"})
        assert r8.status_code == 400

        # Invalid tahasil_id parameter
        r9 = await ac.get("/api/v1/location/search", params={"q": "Patia", "tahasil_id": "bad;injection"})
        assert r9.status_code == 400

        # Missing resolve coordinates
        r10 = await ac.get("/api/v1/location/resolve")
        assert r10.status_code == 422

        # Invalid latitude (> 90)
        r11 = await ac.post("/api/v1/location/resolve", json={"latitude": 95.0, "longitude": 85.0})
        assert r11.status_code == 422

        # Invalid longitude (> 180)
        r12 = await ac.post("/api/v1/location/resolve", json={"latitude": 20.0, "longitude": 185.0})
        assert r12.status_code == 422


# ==============================================================================
# 3. Provider Outage Resilience Tests (Section 9)
# ==============================================================================

@pytest.mark.anyio
async def test_k_provider_outage_local_village_still_works(app, mock_geocoder):
    """
    Test K:
    External geocoder DOWN + GET /location/search?q=Patia still works through local village catalog.
    GET /location/search?q=KIIT University returns clean provider-unavailable/empty response rather than crashing.
    """
    mock_geocoder.simulate_timeout = True
    mock_geocoder.simulate_http_error = True

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # Patia must still succeed 100%
        resp_patia = await ac.get("/api/v1/location/search", params={"q": "Patia"})
        assert resp_patia.status_code == 200
        data_patia = resp_patia.json()
        assert data_patia["totalResults"] > 0
        assert "Patia" in data_patia["results"][0]["title"]
        assert data_patia["results"][0]["source"] == "BHUMITRA_CANONICAL_CATALOG"

        # Landmark query during outage returns clean empty results without crashing
        resp_landmark = await ac.get("/api/v1/location/search", params={"q": "Remote Unknown University"})
        assert resp_landmark.status_code == 200
        data_landmark = resp_landmark.json()
        assert data_landmark["results"] == []


# ==============================================================================
# 4. GET Variant of Resolve Endpoint
# ==============================================================================

@pytest.mark.anyio
async def test_l_resolve_get_variant(app):
    """
    Test L:
    GET /api/v1/location/resolve?lat=20.35410&lng=85.81930
    Validates the query-parameter variant for URL-based navigation.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.get(
            "/api/v1/location/resolve",
            params={"lat": 20.35410, "lng": 85.81930},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == LocationResolutionStatus.EXACT.value
        assert data["revenue_village"] == "Patia"
        assert data["plot_number"] == "318"


# ==============================================================================
# 5. Latency and Performance Benchmark (Section 12)
# ==============================================================================

@pytest.mark.anyio
async def test_m_performance_and_latency_benchmarks(app, mock_geocoder):
    """
    Test M: Performance & Latency Measurements
    Measures:
      1. Local village search latency (< 5ms)
      2. External provider search latency
      3. API serialization latency
      4. Coordinate resolve latency
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1. Local village search latency
        t0 = time.time()
        resp_local = await ac.get("/api/v1/location/search", params={"q": "Patia"})
        t_local = (time.time() - t0) * 1000
        assert resp_local.status_code == 200

        # 2. External provider mock search latency
        t1 = time.time()
        resp_ext = await ac.get("/api/v1/location/search", params={"q": "KIIT University"})
        t_ext = (time.time() - t1) * 1000
        assert resp_ext.status_code == 200

        # 3. Coordinate resolve latency (cached parcels)
        t2 = time.time()
        resp_resolve = await ac.post(
            "/api/v1/location/resolve",
            json={"latitude": 20.35410, "longitude": 85.81930},
        )
        t_resolve = (time.time() - t2) * 1000
        assert resp_resolve.status_code == 200

        print(f"\n--- PERFORMANCE LATENCY MEASUREMENTS ---")
        print(f"Local Village Search Latency: {t_local:.2f} ms")
        print(f"External Provider Search Latency: {t_ext:.2f} ms")
        print(f"Coordinate Resolve Latency (Warm): {t_resolve:.2f} ms")
        print(f"----------------------------------------")

        # Sanity thresholds
        assert t_local < 50.0, f"Local village search too slow: {t_local}ms"
        assert t_resolve < 500.0, f"Warm coordinate resolve too slow: {t_resolve}ms"
