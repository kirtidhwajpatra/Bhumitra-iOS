"""
Step 2 — Location Search Provider Adapter & Intent Router Test Suite
====================================================================
Comprehensive automated tests for Bhumitra's backend location search layer.
Verifies all 16 required matrix scenarios, provider abstraction, intent routing,
local 51k village search, and error resilience.
"""

import os
import asyncio
import pytest
from httpx import AsyncClient, ASGITransport

from app import create_app
from services.location_search_service import (
    LocationSearchService,
    MockGeocoderProvider,
    PhotonGeocoderProvider,
    LocationIQGeocoderProvider,
    GeoapifyGeocoderProvider,
    create_geocoder_provider,
    LocationSearchResultType,
    SearchIntentType,
    detect_search_intent,
)


@pytest.fixture
def mock_provider():
    return MockGeocoderProvider()


@pytest.fixture
def search_service(mock_provider):
    # Isolated test instance using MockGeocoderProvider
    service = LocationSearchService(provider=mock_provider)
    return service


@pytest.fixture
def app():
    return create_app()


# ==============================================================================
# Matrix Tests (1 to 16) + Provider Isolation (17)
# ==============================================================================

@pytest.mark.anyio
async def test_01_patia_local_village_result(search_service):
    """
    Test 1: 'Patia' -> local Bhumitra canonical village result
    Must resolve from local 51k catalog without external geocoder dependency.
    """
    res = await search_service.search("Patia", limit=5)
    assert res.totalResults > 0
    first = res.results[0]

    assert "Patia" in first.title
    assert first.type == LocationSearchResultType.REVENUE_VILLAGE
    assert first.source == "BHUMITRA_CANONICAL_CATALOG"
    assert first.latitude is not None and abs(first.latitude - 20.3541) < 0.05
    assert first.longitude is not None and abs(first.longitude - 85.8193) < 0.05
    assert "Khurda" in first.subtitle or "Khordha" in first.subtitle


@pytest.mark.anyio
async def test_02_raghunathpur_duplicate_candidates_distinguishable(search_service):
    """
    Test 2: 'Raghunathpur' -> duplicate candidates with distinguishing context
    Must return multiple candidates whose subtitles clearly distinguish them.
    """
    res = await search_service.search("Raghunathpur", limit=10)
    assert res.totalResults >= 2

    # Check that subtitles are distinct and contain Tahasil/District context
    subtitles = [r.subtitle for r in res.results]
    assert len(set(subtitles)) > 1, f"Duplicate candidates must not have identical subtitles: {subtitles}"

    # Confirm that Bhubaneswar and other tahasils are identified
    all_context = " ".join(subtitles)
    assert "Bhubaneswar" in all_context or "Banapur" in all_context or "Bolagarh" in all_context


@pytest.mark.anyio
async def test_03_dimbo_canonical_village(search_service):
    """
    Test 3: 'Dimbo' -> correct canonical village candidate (Keonjhar Sadar)
    """
    res = await search_service.search("Dimbo", limit=5)
    assert res.totalResults > 0
    dimbo_match = next((r for r in res.results if "dimbo" in r.title.lower()), None)
    assert dimbo_match is not None
    assert dimbo_match.type == LocationSearchResultType.REVENUE_VILLAGE
    assert "Keonjhar" in dimbo_match.subtitle or "Kendujhar" in dimbo_match.subtitle
    assert dimbo_match.latitude is not None and abs(dimbo_match.latitude - 21.6289) < 0.05


@pytest.mark.anyio
async def test_04_khordha_normalized_to_khurda(search_service):
    """
    Test 4: 'Khordha' -> normalized/matched appropriately to Khurda district
    """
    res = await search_service.search("Khordha", limit=5)
    assert res.totalResults > 0
    first = res.results[0]
    assert first.type == LocationSearchResultType.BROAD_DISTRICT
    assert "Khordha" in first.title or "Khurda" in first.title
    assert first.source == "ODISHA_ADMIN_CATALOG"


@pytest.mark.anyio
async def test_05_kiit_university_external_landmark(search_service, mock_provider):
    """
    Test 5: 'KIIT University' -> external landmark result with coordinates
    The landmark name is discovery metadata only; coordinates are preserved.
    """
    res = await search_service.search("KIIT University", limit=5)
    assert res.totalResults > 0
    first = res.results[0]

    assert "KIIT University" in first.title
    assert first.type == LocationSearchResultType.LANDMARK
    assert first.latitude is not None and abs(first.latitude - 20.3533) < 0.01
    assert first.longitude is not None and abs(first.longitude - 85.8193) < 0.01
    assert mock_provider.call_count >= 1


@pytest.mark.anyio
async def test_06_bare_plot_never_calls_external_geocoder(search_service, mock_provider):
    """
    Test 6: '547' -> PLOT_ONLY -> external geocoder NOT called.
    Bare plot must return structured PLOT_ONLY asking for village context.
    """
    initial_calls = mock_provider.call_count
    res = await search_service.search("547", limit=5)

    assert mock_provider.call_count == initial_calls, "External geocoder MUST NEVER be called for bare plot number!"
    assert res.intent == SearchIntentType.PLOT_ONLY
    assert len(res.results) == 1
    first = res.results[0]
    assert first.type == LocationSearchResultType.PLOT_ONLY
    assert first.parsedPlotNumber == "547"
    assert "village" in first.subtitle.lower()


@pytest.mark.anyio
async def test_07_compound_plot_patia(search_service):
    """
    Test 7: 'Plot 547 Patia' -> COMPOUND_PLOT -> plot 547 + Patia location
    """
    res = await search_service.search("Plot 547 Patia", limit=5)
    assert res.intent == SearchIntentType.COMPOUND_PLOT
    assert res.totalResults > 0
    first = res.results[0]

    assert first.type == LocationSearchResultType.COMPOUND_PLOT
    assert first.parsedPlotNumber == "547"
    assert "Plot 547 in Patia" in first.title
    assert first.latitude is not None and abs(first.latitude - 20.3541) < 0.05


@pytest.mark.anyio
async def test_08_coordinate_direct_input(search_service, mock_provider):
    """
    Test 8: '20.35410, 85.81930' -> COORDINATE intent, geocoder not called
    """
    initial_calls = mock_provider.call_count
    res = await search_service.search("20.35410, 85.81930", limit=5)

    assert mock_provider.call_count == initial_calls, "External geocoder must not be called for coordinates!"
    assert res.intent == SearchIntentType.COORDINATE
    assert len(res.results) == 1
    first = res.results[0]
    assert first.type == LocationSearchResultType.COORDINATE
    assert first.latitude == 20.35410
    assert first.longitude == 85.81930
    assert first.source == "COORDINATE_INPUT"


@pytest.mark.anyio
async def test_09_bhubaneswar_broad_city_no_arbitrary_village(search_service):
    """
    Test 9: 'Bhubaneswar' -> BROAD_CITY -> no arbitrary revenue-village assignment
    """
    res = await search_service.search("Bhubaneswar", limit=5)
    assert res.intent == SearchIntentType.BROAD_CITY
    assert len(res.results) >= 1
    first = res.results[0]
    assert first.type == LocationSearchResultType.BROAD_CITY
    assert first.title == "Bhubaneswar"
    assert first.source == "ODISHA_CITY_CATALOG"
    assert first.latitude is not None and abs(first.latitude - 20.2961) < 0.01


@pytest.mark.anyio
async def test_10_pin_code_locality_result(search_service):
    """
    Test 10: '751024' -> PIN_CODE intent with appropriate locality result
    """
    res = await search_service.search("751024", limit=5)
    assert res.intent == SearchIntentType.PIN_CODE
    assert res.totalResults > 0
    first = res.results[0]
    assert first.type == LocationSearchResultType.LOCALITY
    assert "751024" in first.title or "751024" in first.id
    assert first.latitude is not None and first.longitude is not None


@pytest.mark.anyio
async def test_11_external_provider_timeout_graceful(search_service, mock_provider):
    """
    Test 11: External provider timeout -> graceful failure, no crash
    """
    mock_provider.simulate_timeout = True
    # Query landmark that requires external geocoder
    res = await search_service.search("Some Unknown Remote Landmark", limit=5)
    # Must not raise an exception, returns clean response
    assert isinstance(res.results, list)


@pytest.mark.anyio
async def test_12_external_provider_http_error_graceful(search_service, mock_provider):
    """
    Test 12: External provider HTTP 500 error -> graceful failure, no crash
    """
    mock_provider.simulate_http_error = True
    res = await search_service.search("Some Unknown Hospital", limit=5)
    assert isinstance(res.results, list)


@pytest.mark.anyio
async def test_13_provider_unavailable_local_village_still_works(search_service, mock_provider):
    """
    Test 13: External provider completely unavailable -> local village search still works!
    Crucial guarantee: 'Patia' must succeed even if external provider throws an error.
    """
    mock_provider.simulate_timeout = True
    mock_provider.simulate_http_error = True

    res = await search_service.search("Patia", limit=5)
    assert res.totalResults > 0
    first = res.results[0]
    assert "Patia" in first.title
    assert first.type == LocationSearchResultType.REVENUE_VILLAGE
    assert first.source == "BHUMITRA_CANONICAL_CATALOG"


@pytest.mark.anyio
async def test_14_empty_provider_result_clean(search_service):
    """
    Test 14: Empty provider result -> clean empty result, no crash
    """
    res = await search_service.search("XYZNonExistentRandomPlace99999", limit=5)
    assert res.totalResults == 0
    assert res.results == []


@pytest.mark.anyio
async def test_15_malformed_provider_result_clean_error_handling(search_service, mock_provider):
    """
    Test 15: Malformed provider result -> clean error handling, no crash
    """
    mock_provider.simulate_malformed = True
    res = await search_service.search("Unknown Malformed Landmark", limit=5)
    assert isinstance(res.results, list)


@pytest.mark.anyio
async def test_16_rapid_repeated_searches_concurrency(search_service):
    """
    Test 16: Rapid repeated searches at service level -> concurrency test
    Ensures that parallel async requests complete without race conditions or data corruption.
    """
    queries = ["Patia", "Dimbo", "20.3541, 85.8193", "547", "Plot 547 Patia", "KIIT University"]
    tasks = [search_service.search(q, limit=5) for q in queries]
    responses = await asyncio.gather(*tasks)

    assert len(responses) == len(queries)
    for q, r in zip(queries, responses):
        assert r.query == q
        assert isinstance(r.results, list)


# ==============================================================================
# Provider Isolation & Factory Tests
# ==============================================================================

def test_17_provider_isolation_and_factory(monkeypatch):
    """
    Test 17: Provider Isolation Test
    Proves that changing GEOSPATIAL_SEARCH_PROVIDER creates the expected GeocoderProvider
    without modifying any client or application code.
    """
    monkeypatch.setenv("GEOSPATIAL_SEARCH_PROVIDER", "MOCK")
    p_mock = create_geocoder_provider()
    assert isinstance(p_mock, MockGeocoderProvider)
    assert p_mock.provider_name == "MOCK"

    monkeypatch.setenv("GEOSPATIAL_SEARCH_PROVIDER", "PHOTON")
    p_photon = create_geocoder_provider()
    assert isinstance(p_photon, PhotonGeocoderProvider)
    assert p_photon.provider_name == "PHOTON"

    monkeypatch.setenv("GEOSPATIAL_SEARCH_PROVIDER", "LOCATIONIQ")
    p_loc = create_geocoder_provider()
    assert isinstance(p_loc, LocationIQGeocoderProvider)
    assert p_loc.provider_name == "LOCATIONIQ"

    monkeypatch.setenv("GEOSPATIAL_SEARCH_PROVIDER", "GEOAPIFY")
    p_geo = create_geocoder_provider()
    assert isinstance(p_geo, GeoapifyGeocoderProvider)
    assert p_geo.provider_name == "GEOAPIFY"


# ==============================================================================
# End-to-End FastAPI HTTP API Tests
# ==============================================================================

@pytest.mark.anyio
async def test_18_api_get_location_search(app):
    """
    Test 18: HTTP GET /api/v1/location/search
    Tests the live REST API route mounted on FastAPI.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # Test 1: Village search
        resp = await ac.get("/api/v1/location/search", params={"q": "Patia", "limit": 5})
        assert resp.status_code == 200
        data = resp.json()
        assert data["totalResults"] > 0
        assert "Patia" in data["results"][0]["title"]
        assert data["results"][0]["type"] == "REVENUE_VILLAGE"

        # Test 2: Bare Plot
        resp_plot = await ac.get("/api/v1/location/search", params={"q": "547"})
        assert resp_plot.status_code == 200
        plot_data = resp_plot.json()
        assert plot_data["intent"] == "PLOT_ONLY"
        assert plot_data["results"][0]["parsedPlotNumber"] == "547"

        # Test 3: Coordinate
        resp_coord = await ac.get("/api/v1/location/search", params={"q": "20.35410, 85.81930"})
        assert resp_coord.status_code == 200
        coord_data = resp_coord.json()
        assert coord_data["intent"] == "COORDINATE"
        assert coord_data["results"][0]["latitude"] == 20.35410


# ==============================================================================
# Odisha-Only Hard Safety Gate & Ranking Hardening Tests
# ==============================================================================

@pytest.mark.anyio
async def test_19_odisha_only_gate_discards_rajasthan_and_delhi(search_service):
    """
    Test 19: Strict Gate 1 (Odisha-only) + Gate 2 (Relevance).
    Searching 'Jaipur' must fail closed with zero results when no genuine Odisha Jaipur exists,
    and must never return Rajasthan or unrelated Odisha homophones (Jhumpura, Erasama, Jajpur).
    """
    res = await search_service.search("Jaipur", limit=10)
    assert res.totalResults == 0, f"Expected 0 results for 'Jaipur', got: {[r.title for r in res.results]}"
    assert len(res.results) == 0


@pytest.mark.anyio
async def test_20_non_odisha_query_returns_no_non_odisha_results(search_service):
    """
    Test 20: Querying an explicit non-Odisha place like 'Connaught Place'
    must NOT return Delhi results to the user.
    """
    res = await search_service.search("Connaught Place", limit=5)
    for item in res.results:
        if item.latitude is not None and item.longitude is not None:
            assert 17.70 <= item.latitude <= 22.65
            assert 81.30 <= item.longitude <= 87.60
        assert "delhi" not in item.subtitle.lower()


@pytest.mark.anyio
async def test_21_bare_plot_does_not_guess_global_village(search_service):
    """
    Test 21: '547' -> PLOT_ONLY. Requires village context, never guesses an arbitrary Odisha village.
    """
    res = await search_service.search("547")
    assert res.intent == SearchIntentType.PLOT_ONLY
    assert len(res.results) == 1
    assert res.results[0].type == LocationSearchResultType.PLOT_ONLY
    assert res.results[0].latitude is None
    assert res.results[0].longitude is None
    assert res.results[0].extraMetadata.get("requires_village_context") is True


@pytest.mark.anyio
async def test_22_compound_plot_patia(search_service):
    """
    Test 22: 'Plot 547 Patia' -> COMPOUND_PLOT. Preserves compound plot flow and extracts 547.
    """
    res = await search_service.search("Plot 547 Patia", limit=5)
    assert res.intent == SearchIntentType.COMPOUND_PLOT
    assert res.totalResults > 0
    first = res.results[0]
    assert first.type == LocationSearchResultType.COMPOUND_PLOT
    assert first.parsedPlotNumber == "547"
    assert "Patia" in first.title
    assert first.latitude is not None and abs(first.latitude - 20.3541) < 0.05


@pytest.mark.anyio
async def test_23_ranking_patia_prominent_first(search_service):
    """
    Test 23: 'Patia' -> exact Patia matches rank ahead of any fuzzy matches.
    Prominent Patia in Bhubaneswar, Khurda appears at index 0.
    """
    res = await search_service.search("Patia", limit=5)
    assert res.totalResults > 0
    first = res.results[0]
    # The prominent Patia (Bhubaneswar Tahasil, Khurda) must be #1
    assert "Patia" in first.title
    assert "Khurda" in first.subtitle or "Khordha" in first.subtitle or "Bhubaneswar" in first.subtitle
    assert first.latitude is not None and abs(first.latitude - 20.3541) < 0.01


@pytest.mark.anyio
async def test_24_coordinate_input_outside_odisha_fails_gate(search_service):
    """
    Test 24: Direct coordinate input outside Odisha (e.g. Jaipur, Rajasthan: 26.9124, 75.7873)
    must be discarded by the final Odisha gate.
    """
    res = await search_service.search("26.9124, 75.7873")
    # Intent is COORDINATE, but because it is outside Odisha, the safety gate drops it
    assert len(res.results) == 0, "Coordinate outside Odisha must not produce results"


@pytest.mark.anyio
async def test_25_replaceable_provider_adapter():
    """
    Test 25: Provider abstraction allows seamless swapping without affecting the rest of Bhumitra.
    """
    mock1 = MockGeocoderProvider()
    service = LocationSearchService(provider=mock1)
    assert service.provider.provider_name == "MOCK"

    mock2 = MockGeocoderProvider()
    service.set_provider(mock2)
    assert service.provider == mock2


@pytest.mark.anyio
async def test_26_jaipur_strict_relevance_zero_results(search_service):
    """
    Test 26: 'Jaipur' -> no unrelated Odisha results (Jhumpura, Erasama, Jajpur, Keonjhar).
    If no genuine Odisha Jaipur exists, return exactly 0 results.
    """
    res = await search_service.search("Jaipur", limit=10)
    assert res.totalResults == 0
    assert len(res.results) == 0


@pytest.mark.anyio
async def test_27_kiit_landmarks_prominently_featured(search_service):
    """
    Test 27: 'Kiit' -> KIIT landmarks appear prominently.
    Unrelated villages (e.g. Kitumba, Kitabeda) must not crowd out or precede KIIT.
    """
    res = await search_service.search("Kiit", limit=10)
    assert res.totalResults > 0
    # All returned results must be genuine KIIT matches
    for item in res.results:
        clean_t = item.title.lower()
        sub = item.subtitle.lower()
        assert "kiit" in clean_t or "kiit" in sub, f"Unrelated result returned for 'Kiit': {item.title}"


@pytest.mark.anyio
async def test_28_patia_prominent_khurda_first(search_service):
    """
    Test 28: 'Patia' -> Patia results appear prominently with Bhubaneswar/Khurda #1.
    """
    res = await search_service.search("Patia", limit=5)
    assert res.totalResults > 0
    top = res.results[0]
    assert "Patia" in top.title
    assert "Bhubaneswar" in top.subtitle or "Khordha" in top.subtitle or "Khurda" in top.subtitle


@pytest.mark.anyio
async def test_29_xyzqwerty123_zero_results(search_service):
    """
    Test 29: 'xyzqwerty123' -> zero results. Fail closed rather than weak fuzzy match.
    """
    res = await search_service.search("xyzqwerty123", limit=10)
    assert res.totalResults == 0
    assert len(res.results) == 0


@pytest.mark.anyio
async def test_30_mixed_external_provider_response_filtered():
    """
    Test 30: Mixed external-provider response containing:
    - Jaipur Rajasthan (out of state)
    - Jaipur District Rajasthan (out of state)
    - unrelated Odisha villages (e.g. Jhumpura, Erasama)
    - genuine Odisha Patia/KIIT candidates
    Expected:
    - Rajasthan candidates removed by Gate 1
    - Unrelated Odisha candidates removed by Gate 2
    - Genuine matching Odisha candidates retained
    """
    from services.location_search_service import GeocoderProvider, GeocodedPlace

    class MixedPollutedProvider(GeocoderProvider):
        @property
        def provider_name(self) -> str:
            return "MIXED_POLLUTED"

        async def search(self, query: str, bbox=None, limit=10):
            return [
                # Non-Odisha items
                GeocodedPlace(
                    id="ext:jaipur_raj",
                    name="Jaipur",
                    display_name="Jaipur, Jaipur District, Rajasthan, India",
                    place_type="city",
                    latitude=26.9124,
                    longitude=75.7873,
                    source="POLLUTED",
                    metadata={"state": "Rajasthan", "country": "India"},
                ),
                GeocodedPlace(
                    id="ext:jaipur_dist_raj",
                    name="Jaipur District",
                    display_name="Jaipur District, Rajasthan, India",
                    place_type="administrative",
                    latitude=26.9000,
                    longitude=75.8000,
                    source="POLLUTED",
                    metadata={"state": "Rajasthan", "country": "India"},
                ),
                # Unrelated Odisha locations
                GeocodedPlace(
                    id="ext:jhumpura_odisha",
                    name="Jhumpura",
                    display_name="Jhumpura, Keonjhar District, Odisha, India",
                    place_type="village",
                    latitude=21.8200,
                    longitude=85.5800,
                    source="POLLUTED",
                    metadata={"state": "Odisha", "country": "India"},
                ),
                GeocodedPlace(
                    id="ext:erasama_odisha",
                    name="Erasama",
                    display_name="Erasama, Jagatsinghpur District, Odisha, India",
                    place_type="village",
                    latitude=20.1900,
                    longitude=86.3500,
                    source="POLLUTED",
                    metadata={"state": "Odisha", "country": "India"},
                ),
                # Genuine matching Odisha candidate
                GeocodedPlace(
                    id="ext:kiit_road_odisha",
                    name="KIIT Road",
                    display_name="KIIT Road, Patia, Bhubaneswar, Khordha, Odisha",
                    place_type="landmark",
                    latitude=20.3533,
                    longitude=85.8263,
                    source="POLLUTED",
                    metadata={"state": "Odisha", "country": "India", "keywords": ["kiit", "patia"]},
                ),
            ]

    custom_service = LocationSearchService(provider=MixedPollutedProvider())

    # Query for "Kiit"
    res = await custom_service.search("Kiit", limit=10)

    # 1. Non-Odisha Rajasthan candidates must be absent
    assert not any("rajasthan" in f"{r.title} {r.subtitle}".lower() for r in res.results)
    # 2. Unrelated Odisha candidates (Jhumpura, Erasama) must be absent
    assert not any("jhumpura" in f"{r.title} {r.subtitle}".lower() for r in res.results)
    assert not any("erasama" in f"{r.title} {r.subtitle}".lower() for r in res.results)
    # 3. Genuine matching Odisha candidate must be retained
    assert any("kiit" in r.title.lower() for r in res.results)


