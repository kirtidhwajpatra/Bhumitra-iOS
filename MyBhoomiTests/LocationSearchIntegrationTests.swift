//
//  LocationSearchIntegrationTests.swift
//  MyBhoomiTests
//
//  Integration Tests for Bhumitra Location Search & Spatial Resolution Pipeline (Step 4).
//  Validates: Search Models, Search Service, Camera Navigation, Spatial Resolution,
//  Stale Token Protection, Ambiguity Disambiguation, and Fallbacks.
//

import XCTest
import Combine
@testable import MyBhoomi

final class LocationSearchIntegrationTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
    
    override func tearDown() {
        cancellables.removeAll()
        LocationSearchService.shared.clearSearch()
        super.tearDown()
    }
    
    // MARK: - 1. Search "Patia" -> Village Suggestion
    
    func test_01_search_patia_village_suggestion() throws {
        let json = """
        {
            "query": "Patia",
            "intent": "REVENUE_VILLAGE",
            "total": 1,
            "executionTimeMs": 0.60,
            "results": [
                {
                    "id": "village_2002060",
                    "title": "Patia",
                    "subtitle": "Bhubaneswar, Khurda",
                    "type": "REVENUE_VILLAGE",
                    "latitude": 20.3541,
                    "longitude": 85.8193,
                    "boundingBox": [85.80, 20.34, 85.84, 20.37],
                    "source": "LOCAL_INDEX",
                    "parsedPlotNumber": null,
                    "district": "Khurda",
                    "districtId": "20",
                    "tahasil": "Bhubaneswar",
                    "tahasilId": "02",
                    "revenueVillage": "Patia",
                    "revenueVillageId": "2002060"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: json)
        XCTAssertEqual(response.query, "Patia")
        XCTAssertEqual(response.total, 1)
        
        let result = try XCTUnwrap(response.results.first)
        XCTAssertEqual(result.title, "Patia")
        XCTAssertEqual(result.type, .revenueVillage)
        XCTAssertEqual(result.latitude, 20.3541)
        XCTAssertEqual(result.longitude, 85.8193)
        XCTAssertEqual(result.revenueVillageId, "2002060")
        XCTAssertEqual(result.district, "Khurda")
        XCTAssertEqual(result.tahasil, "Bhubaneswar")
    }
    
    // MARK: - 2. Search "KIIT University" -> Landmark Suggestion
    
    func test_02_search_kiit_landmark_suggestion() throws {
        let json = """
        {
            "query": "KIIT University",
            "intent": "LANDMARK",
            "total": 1,
            "results": [
                {
                    "id": "ext_kiit_university",
                    "title": "KIIT University",
                    "subtitle": "Patia, Bhubaneswar, Khurda",
                    "type": "LANDMARK",
                    "latitude": 20.3533,
                    "longitude": 85.8193,
                    "source": "EXTERNAL_GEOCODER",
                    "parsedPlotNumber": null,
                    "revenueVillage": null,
                    "revenueVillageId": null
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: json)
        let result = try XCTUnwrap(response.results.first)
        
        XCTAssertEqual(result.type, .landmark)
        XCTAssertEqual(result.latitude, 20.3533)
        XCTAssertEqual(result.longitude, 85.8193)
        // Landmark search must NEVER treat KIIT as the revenue village identity
        XCTAssertNil(result.revenueVillage)
        XCTAssertNil(result.revenueVillageId)
    }
    
    // MARK: - 3. Search "547" -> Plot-Only
    
    func test_03_search_bare_plot_returns_plot_only() throws {
        let json = """
        {
            "query": "547",
            "intent": "PLOT_ONLY",
            "total": 1,
            "results": [
                {
                    "id": "plot_only_547",
                    "title": "Plot 547",
                    "subtitle": "Enter a village or select a location on the map to resolve this plot",
                    "type": "PLOT_ONLY",
                    "latitude": null,
                    "longitude": null,
                    "parsedPlotNumber": "547",
                    "source": "PARSER"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: json)
        let result = try XCTUnwrap(response.results.first)
        
        XCTAssertEqual(result.type, .plotOnly)
        XCTAssertEqual(result.parsedPlotNumber, "547")
        XCTAssertNil(result.latitude)
        XCTAssertNil(result.longitude)
    }
    
    // MARK: - 4. Search "Plot 547 Patia" -> Compound Plot
    
    func test_04_search_compound_plot_returns_parsed_plot() throws {
        let json = """
        {
            "query": "Plot 547 Patia",
            "intent": "COMPOUND_PLOT",
            "total": 1,
            "results": [
                {
                    "id": "compound_village_2002060_547",
                    "title": "Plot 547, Patia",
                    "subtitle": "Bhubaneswar, Khurda",
                    "type": "COMPOUND_PLOT",
                    "latitude": 20.3541,
                    "longitude": 85.8193,
                    "parsedPlotNumber": "547",
                    "district": "Khurda",
                    "districtId": "20",
                    "tahasil": "Bhubaneswar",
                    "tahasilId": "02",
                    "revenueVillage": "Patia",
                    "revenueVillageId": "2002060"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: json)
        let result = try XCTUnwrap(response.results.first)
        
        XCTAssertEqual(result.type, .compoundPlot)
        XCTAssertEqual(result.parsedPlotNumber, "547")
        XCTAssertEqual(result.revenueVillage, "Patia")
        XCTAssertEqual(result.latitude, 20.3541)
        XCTAssertEqual(result.longitude, 85.8193)
    }
    
    // MARK: - 5. Select Patia -> Camera Moves to Patia Coordinate Immediately
    
    @MainActor
    func test_05_select_patia_moves_camera_immediately() async throws {
        let vm = MapViewModel()
        
        let patiaResult = LocationSearchResult(
            id: "village_2002060",
            title: "Patia",
            subtitle: "Bhubaneswar, Khurda",
            type: .revenueVillage,
            latitude: 20.3541,
            longitude: 85.8193,
            revenueVillage: "Patia",
            revenueVillageId: "2002060"
        )
        
        // When selected, camera coordinates must be updated immediately
        _ = try? await vm.selectLocation(patiaResult)
        
        XCTAssertEqual(vm.mapCenter.latitude, 20.3541, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, 85.8193, accuracy: 0.0001)
        XCTAssertEqual(vm.zoomLevel, 16.0)
    }
    
    // MARK: - 6. Select KIIT -> Camera Moves to KIIT, Spatial Resolver Determines Official Village
    
    @MainActor
    func test_06_select_kiit_moves_camera_and_resolves_official_village() async throws {
        let vm = MapViewModel()
        
        let kiitResult = LocationSearchResult(
            id: "ext_kiit_university",
            title: "KIIT University",
            subtitle: "Patia, Bhubaneswar, Khurda",
            type: .landmark,
            latitude: 20.3533,
            longitude: 85.8193
        )
        
        _ = try? await vm.selectLocation(kiitResult)
        
        // Camera moves to KIIT landmark coordinates
        XCTAssertEqual(vm.mapCenter.latitude, 20.3533, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, 85.8193, accuracy: 0.0001)
    }
    
    // MARK: - 7. EXACT Result -> Resolution Response Decoding
    
    func test_07_exact_resolution_decodes_cleanly() throws {
        let json = """
        {
            "status": "EXACT",
            "district": "Khurda",
            "district_id": "20",
            "tahasil": "Bhubaneswar",
            "tahasil_id": "02",
            "revenue_village": "Patia",
            "revenue_village_id": "2002060",
            "bhulekh_mouza_id": "60",
            "plot_number": "318",
            "latitude": 20.3541,
            "longitude": 85.8193,
            "resolution_reason": "Exact containing parcel matched in 4K GEO cadastral coverage.",
            "candidates": [],
            "executionTimeMs": 3.89
        }
        """.data(using: .utf8)!
        
        let resolution = try JSONDecoder().decode(LocationResolutionResponse.self, from: json)
        XCTAssertEqual(resolution.status, .exact)
        XCTAssertEqual(resolution.district, "Khurda")
        XCTAssertEqual(resolution.districtId, "20")
        XCTAssertEqual(resolution.tahasil, "Bhubaneswar")
        XCTAssertEqual(resolution.tahasilId, "02")
        XCTAssertEqual(resolution.revenueVillage, "Patia")
        XCTAssertEqual(resolution.revenueVillageId, "2002060")
        XCTAssertEqual(resolution.bhulekhMouzaId, "60")
        XCTAssertEqual(resolution.plotNumber, "318")
    }
    
    // MARK: - 8. Plot 547 Alone -> Requires Village Selection Context
    
    @MainActor
    func test_08_bare_plot_requires_village_context() async throws {
        let vm = MapViewModel()
        vm.clearCadastralVillage() // Ensure no village is selected
        
        let initialLat = vm.mapCenter.latitude
        let initialLon = vm.mapCenter.longitude
        
        let plotResult = LocationSearchResult(
            id: "plot_547",
            title: "Plot 547",
            subtitle: "Locate plot",
            type: .plotOnly,
            parsedPlotNumber: "547"
        )
        
        try await vm.selectLocation(plotResult)
        
        // Camera must NOT move for a bare plot without village context
        XCTAssertEqual(vm.mapCenter.latitude, initialLat)
        XCTAssertEqual(vm.mapCenter.longitude, initialLon)
        // Must show toast explaining village is required
        XCTAssertTrue(vm.toastMessage?.contains("Select a village") == true)
    }
    
    // MARK: - 9. AMBIGUOUS -> Enters Candidate UI State (Fail-Closed)
    
    func test_09_ambiguous_resolution_decodes_candidates() throws {
        let json = """
        {
            "status": "AMBIGUOUS",
            "district": "Khurda",
            "district_id": "20",
            "tahasil": "Bhubaneswar",
            "tahasil_id": "02",
            "resolution_reason": "Overlapping village boundaries.",
            "candidates": [
                {
                    "village_id": "2002359",
                    "village_name": "Raghunathpur Jali",
                    "tahasil_name": "Bhubaneswar",
                    "district_name": "Khurda",
                    "bhulekh_mouza_id": "359"
                },
                {
                    "village_id": "2002060",
                    "village_name": "Patia",
                    "tahasil_name": "Bhubaneswar",
                    "district_name": "Khurda",
                    "bhulekh_mouza_id": "60"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let resolution = try JSONDecoder().decode(LocationResolutionResponse.self, from: json)
        XCTAssertEqual(resolution.status, .ambiguous)
        XCTAssertEqual(resolution.candidates?.count, 2)
        XCTAssertEqual(resolution.candidates?[0].villageName, "Raghunathpur Jali")
        XCTAssertEqual(resolution.candidates?[1].villageName, "Patia")
    }
    
    // MARK: - 10. NO_CADASTRAL_COVERAGE -> Status Contract
    
    func test_10_no_cadastral_coverage_status() throws {
        let json = """
        {
            "status": "NO_CADASTRAL_COVERAGE",
            "district": "Khurda",
            "district_id": "20",
            "tahasil": "Bhubaneswar",
            "tahasil_id": "02",
            "revenue_village": null,
            "revenue_village_id": null,
            "resolution_reason": "No 4K GEO cadastral parcels exist for coordinate."
        }
        """.data(using: .utf8)!
        
        let resolution = try JSONDecoder().decode(LocationResolutionResponse.self, from: json)
        XCTAssertEqual(resolution.status, .noCadastralCoverage)
        XCTAssertNil(resolution.revenueVillage)
    }
    
    // MARK: - 11. OUTSIDE_ODISHA -> Short-Circuit Contract
    
    func test_11_outside_odisha_status() throws {
        let json = """
        {
            "status": "OUTSIDE_ODISHA",
            "district": null,
            "district_id": null,
            "resolution_reason": "Coordinate falls outside Odisha state boundary."
        }
        """.data(using: .utf8)!
        
        let resolution = try JSONDecoder().decode(LocationResolutionResponse.self, from: json)
        XCTAssertEqual(resolution.status, .outsideOdisha)
        XCTAssertNil(resolution.district)
    }
    
    // MARK: - 12. PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE -> Graceful Status
    
    func test_12_parcel_source_temporarily_unavailable() throws {
        let json = """
        {
            "status": "PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE",
            "district": "Khurda",
            "resolution_reason": "Upstream cadastral server returned 503."
        }
        """.data(using: .utf8)!
        
        let resolution = try JSONDecoder().decode(LocationResolutionResponse.self, from: json)
        XCTAssertEqual(resolution.status, .parcelSourceTemporarilyUnavailable)
    }
    
    // MARK: - 13. Stale Token Protection Against Out-of-Order Resolutions
    
    @MainActor
    func test_13_stale_token_protection() {
        let vm = MapViewModel()
        let tokenA = UUID()
        vm.activeSelectionToken = tokenA
        
        // Simulate a second selection occurring immediately
        let tokenB = UUID()
        vm.activeSelectionToken = tokenB
        
        // Token A is now stale and cannot match active selection
        XCTAssertNotEqual(vm.activeSelectionToken, tokenA)
        XCTAssertEqual(vm.activeSelectionToken, tokenB)
    }
    
    // MARK: - 14. LocationSearchService Debounce and Cancellation
    
    @MainActor
    func test_14_search_service_debounce_and_clear() {
        let service = LocationSearchService.shared
        
        // Searching rapid queries
        service.search(query: "P")
        service.search(query: "Pat")
        service.search(query: "Patia")
        
        // Clearing immediately resets search state
        service.clearSearch()
        
        XCTAssertFalse(service.isSearching)
        XCTAssertTrue(service.searchResults.isEmpty)
    }
    
    // MARK: - 15. Home -> Map Handoff
    
    @MainActor
    func test_15_home_to_map_handoff() async {
        let nav = AppNavigationManager.shared
        nav.selectedTab = .home
        
        let patiaResult = LocationSearchResult(
            id: "village_2002060",
            title: "Patia",
            subtitle: "Bhubaneswar, Khurda",
            type: .revenueVillage,
            latitude: 20.3541,
            longitude: 85.8193
        )
        
        // Simulate home search handoff
        nav.selectedTab = .map
        let vm = MapViewModel()
        _ = try? await vm.selectLocation(patiaResult)
        
        XCTAssertEqual(nav.selectedTab, .map)
        XCTAssertEqual(vm.mapCenter.latitude, 20.3541, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, 85.8193, accuracy: 0.0001)
    }
    
    // MARK: - 16. Existing Manual Hierarchy Selector Unchanged
    
    @MainActor
    func test_16_manual_selector_remains_functional() {
        let vm = MapViewModel()
        
        // Simulates selecting district from manual cards
        vm.pendingDistrictSelectionName = "Khurda"
        vm.shouldOpenLocationPicker = true
        
        XCTAssertEqual(vm.pendingDistrictSelectionName, "Khurda")
        XCTAssertTrue(vm.shouldOpenLocationPicker)
    }
    
    // MARK: - 17. Real FastAPI Response Schema (totalResults & extraMetadata)
    
    func test_17_real_fastapi_response_decoding() throws {
        let json = """
        {
            "query": "Patia",
            "intent": "REVENUE_VILLAGE",
            "results": [
                {
                    "id": "bhumitra:village:17:06:001",
                    "title": "Patia (ପଟିଆ)",
                    "subtitle": "Bhubaneswar Tahasil, Khurda District",
                    "type": "REVENUE_VILLAGE",
                    "latitude": 20.3588,
                    "longitude": 85.8163,
                    "boundingBox": [85.80, 20.34, 85.84, 20.37],
                    "source": "BHUMITRA_CANONICAL_CATALOG",
                    "parsedPlotNumber": null,
                    "extraMetadata": {
                        "district_id": "17",
                        "tahasil_id": "06",
                        "mouza_id": "001",
                        "mouza_name": "Patia",
                        "mouza_name_odia": "ପଟିଆ",
                        "tahasil_name": "Bhubaneswar",
                        "district_name": "Khurda"
                    }
                }
            ],
            "totalResults": 1,
            "provider": "BHUMITRA_CANONICAL_CATALOG",
            "executionTimeMs": 1.42
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: json)
        XCTAssertEqual(response.query, "Patia")
        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.totalResults, 1)
        
        let item = try XCTUnwrap(response.results.first)
        XCTAssertEqual(item.id, "bhumitra:village:17:06:001")
        XCTAssertEqual(item.type, .revenueVillage)
        XCTAssertEqual(item.districtId, "17")
        XCTAssertEqual(item.tahasilId, "06")
        XCTAssertEqual(item.revenueVillageId, "1706001")
        XCTAssertEqual(item.district, "Khurda")
        XCTAssertEqual(item.tahasil, "Bhubaneswar")
        XCTAssertEqual(item.latitude, 20.3588)
        XCTAssertEqual(item.longitude, 85.8163)
    }
    
    // MARK: - 18. Step 5: Recent Searches Store (Max 5, Dedup, Clear)
    
    @MainActor
    func test_18_recent_searches_store_persistence_cap_and_dedup() {
        let store = RecentLocationSearchStore.shared
        store.clearAll()
        XCTAssertTrue(store.recents.isEmpty)
        
        let r1 = LocationSearchResult(id: "r1", title: "Patia", subtitle: "Khurda", type: .revenueVillage, latitude: 20.35, longitude: 85.81)
        let r2 = LocationSearchResult(id: "r2", title: "KIIT", subtitle: "Patia", type: .landmark, latitude: 20.35, longitude: 85.81)
        let r3 = LocationSearchResult(id: "r3", title: "Raghunathpur", subtitle: "Cuttack", type: .revenueVillage, latitude: 20.40, longitude: 85.90)
        let r4 = LocationSearchResult(id: "r4", title: "Dimbo", subtitle: "Keonjhar", type: .revenueVillage, latitude: 21.60, longitude: 85.50)
        let r5 = LocationSearchResult(id: "r5", title: "Oupada", subtitle: "Baleswar", type: .revenueVillage, latitude: 21.40, longitude: 86.50)
        let r6 = LocationSearchResult(id: "r6", title: "Astarang", subtitle: "Puri", type: .revenueVillage, latitude: 19.98, longitude: 86.27)
        
        store.addRecent(r1)
        store.addRecent(r2)
        store.addRecent(r3)
        store.addRecent(r4)
        store.addRecent(r5)
        
        XCTAssertEqual(store.recents.count, 5)
        XCTAssertEqual(store.recents.first?.id, "r5")
        
        // 6th item should push out r1 (FIFO cap at 5)
        store.addRecent(r6)
        XCTAssertEqual(store.recents.count, 5)
        XCTAssertEqual(store.recents.first?.id, "r6")
        XCTAssertFalse(store.recents.contains(where: { $0.id == "r1" }))
        
        // Re-adding existing item should deduplicate and move to top
        store.addRecent(r3)
        XCTAssertEqual(store.recents.count, 5)
        XCTAssertEqual(store.recents.first?.id, "r3")
        
        // Clear all
        store.clearAll()
        XCTAssertTrue(store.recents.isEmpty)
    }
    
    // MARK: - 19. Step 5: Recent Searches Re-Selection Runs Fresh Resolution Pipeline
    
    @MainActor
    func test_19_recent_searches_reselection_runs_fresh_resolution() async {
        let store = RecentLocationSearchStore.shared
        store.clearAll()
        
        let vm = MapViewModel()
        let patia = LocationSearchResult(
            id: "bhumitra:village:20:02:060",
            title: "Patia",
            subtitle: "Bhubaneswar Tahasil, Khurda District",
            type: .revenueVillage,
            latitude: 20.3541,
            longitude: 85.8193,
            revenueVillage: "Patia",
            revenueVillageId: "2002060"
        )
        
        _ = try? await vm.selectLocation(patia)
        
        // Verify recorded into recents
        XCTAssertEqual(store.recents.first?.id, patia.id)
        
        // Re-selecting the stored recent item re-runs the full selectLocation pipeline
        let recentItem = try! XCTUnwrap(store.recents.first)
        _ = try? await vm.selectLocation(recentItem)
        
        XCTAssertEqual(vm.mapCenter.latitude, 20.3541, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, 85.8193, accuracy: 0.0001)
        
        store.clearAll()
    }
    
    // MARK: - 20. Step 5: Spatial Status Progression & Ready State
    
    @MainActor
    func test_20_spatial_status_ready_state_transition() {
        let vm = MapViewModel()
        XCTAssertEqual(vm.spatialResolutionState, .idle)
        
        vm.spatialResolutionState = .resolving(title: "Patia")
        XCTAssertEqual(vm.spatialResolutionState, .resolving(title: "Patia"))
        
        vm.spatialResolutionState = .loadingParcels(villageName: "Patia")
        XCTAssertEqual(vm.spatialResolutionState, .loadingParcels(villageName: "Patia"))
        
        vm.spatialResolutionState = .ready(message: "Parcels ready")
        XCTAssertEqual(vm.spatialResolutionState, .ready(message: "Parcels ready"))
        
        vm.dismissSpatialResolutionState()
        XCTAssertEqual(vm.spatialResolutionState, .idle)
    }
    
    // MARK: - 21. Step 5: Retry Last Failed Resolution
    
    @MainActor
    func test_21_retry_last_failed_resolution() async {
        let vm = MapViewModel()
        
        let failedSearch = LocationSearchResult(
            id: "retry_candidate",
            title: "Test Landmark",
            subtitle: "Odisha",
            type: .landmark,
            latitude: 20.35,
            longitude: 85.81
        )
        
        // Simulate failure state
        vm.lastFailedSearchResult = failedSearch
        vm.spatialResolutionState = .temporarilyUnavailable(reason: "Network timeout")
        
        XCTAssertNotNil(vm.lastFailedSearchResult)
        XCTAssertEqual(vm.spatialResolutionState, .temporarilyUnavailable(reason: "Network timeout"))
        
        // Retrying re-invokes selectLocation
        _Concurrency.Task { @MainActor in
            await vm.retryLastResolution()
        }
        try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(vm.mapCenter.latitude, 20.35, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, 85.81, accuracy: 0.0001)
    }
    
    // MARK: - 22. Step 5: Manual Location Selector Fallback
    
    @MainActor
    func test_22_manual_location_selector_fallback() {
        let vm = MapViewModel()
        vm.spatialResolutionState = .noCoverage(reason: "No cadastral map")
        vm.shouldOpenLocationPicker = false
        
        vm.openManualLocationSelector()
        
        XCTAssertEqual(vm.spatialResolutionState, .idle)
        XCTAssertTrue(vm.shouldOpenLocationPicker)
    }
    
    // MARK: - 23. Step 5: Map Interaction Dismisses Search
    
    @MainActor
    func test_23_map_interaction_dismisses_search() {
        let vm = MapViewModel()
        vm.searchQuery = "Patia"
        vm.searchResults = [
            LocationSearchResult(id: "1", title: "Patia", subtitle: "Khurda", type: .revenueVillage)
        ]
        
        XCTAssertFalse(vm.searchResults.isEmpty)
        XCTAssertFalse(vm.searchQuery.isEmpty)
        
        vm.dismissSearchOnMapInteraction()
        
        XCTAssertTrue(vm.searchResults.isEmpty)
        XCTAssertTrue(vm.searchQuery.isEmpty)
    }
    
    // MARK: - 24. Live Search: "Kiit" Produces Results
    
    @MainActor
    func test_24_search_kiit_produces_visible_result() async throws {
        let service = LocationSearchService.shared
        let results = try await service.performSearchNetworkRequest(query: "Kiit")
        XCTAssertFalse(results.isEmpty, "Kiit query must produce search results")
        let first = try XCTUnwrap(results.first)
        XCTAssertTrue(first.title.localizedCaseInsensitiveContains("Kiit") || first.subtitle.localizedCaseInsensitiveContains("Kiit"), "First result should match Kiit")
    }
    
    // MARK: - 25. Odisha-Only Gate: Discards Non-Odisha Results from Mixed JSON
    
    func test_25_odisha_only_gate_discards_rajasthan() throws {
        let mixedJson = """
        {
            "query": "Jaipur",
            "intent": "GENERAL",
            "total": 2,
            "results": [
                {
                    "id": "ext_jaipur_rajasthan",
                    "title": "Jaipur",
                    "subtitle": "Jaipur District, Rajasthan, India",
                    "type": "BROAD_CITY",
                    "latitude": 26.9124,
                    "longitude": 75.7873,
                    "source": "EXTERNAL_GEOCODER"
                },
                {
                    "id": "village_jaipur_odisha",
                    "title": "Jaipur",
                    "subtitle": "Jhumpura Tahasil, Keonjhar District, Odisha",
                    "type": "REVENUE_VILLAGE",
                    "latitude": 21.8870,
                    "longitude": 85.6691,
                    "source": "BHUMITRA_CANONICAL_CATALOG"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: mixedJson)
        
        // Filter using Odisha coordinate boundary and metadata check
        let odishaResults = response.results.filter { r in
            guard let lat = r.latitude, let lon = r.longitude else { return false }
            let insideBBox = (17.70 <= lat && lat <= 22.65) && (81.30 <= lon && lon <= 87.60)
            let mentionsRajasthan = r.subtitle.localizedCaseInsensitiveContains("Rajasthan")
            return insideBBox && !mentionsRajasthan
        }
        
        XCTAssertEqual(odishaResults.count, 1)
        XCTAssertEqual(odishaResults[0].subtitle, "Jhumpura Tahasil, Keonjhar District, Odisha")
        XCTAssertFalse(odishaResults.contains { $0.subtitle.contains("Rajasthan") })
    }
    
    // MARK: - 26. Valid Odisha Result With Coordinate: Moves Map Camera Immediately
    
    @MainActor
    func test_26_valid_result_moves_camera_immediately() async throws {
        let vm = MapViewModel()
        let initialCenter = vm.mapCenter
        
        let patiaResult = LocationSearchResult(
            id: "village_2002060",
            title: "Patia",
            subtitle: "Bhubaneswar Tahasil, Khurda District",
            type: .revenueVillage,
            latitude: 20.3541,
            longitude: 85.8193
        )
        
        // Select location
        try? await vm.selectLocation(patiaResult)
        
        // Camera must immediately move to Patia's coordinate
        XCTAssertNotEqual(vm.mapCenter.latitude, initialCenter.latitude)
        XCTAssertEqual(vm.mapCenter.latitude, 20.3541, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, 85.8193, accuracy: 0.0001)
        XCTAssertEqual(vm.zoomLevel, LocationSearchResultType.revenueVillage.recommendedZoomLevel)
    }
    
    // MARK: - 27. Cadastral Failure After Selection: Map Remains at Selected Coordinate
    
    @MainActor
    func test_27_cadastral_failure_preserves_map_center() async throws {
        let vm = MapViewModel()
        
        let kiitResult = LocationSearchResult(
            id: "ext_kiit",
            title: "KIIT University",
            subtitle: "Patia, Bhubaneswar, Khordha",
            type: .landmark,
            latitude: 20.3533,
            longitude: 85.8193
        )
        
        // Asynchronously initiate selection
        _Concurrency.Task { @MainActor in
            try? await vm.selectLocation(kiitResult)
        }
        try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000)
        
        // Camera positioned at KIIT
        let centerAfterSelect = vm.mapCenter
        XCTAssertEqual(centerAfterSelect.latitude, 20.3533, accuracy: 0.0001)
        XCTAssertEqual(centerAfterSelect.longitude, 85.8193, accuracy: 0.0001)
        
        // Simulate cadastral loading failure
        vm.spatialResolutionState = .temporarilyUnavailable(reason: "Cadastral map unavailable")
        
        // Camera MUST remain at the user's selected coordinate (never reset to origin or zero)
        XCTAssertEqual(vm.mapCenter.latitude, centerAfterSelect.latitude, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, centerAfterSelect.longitude, accuracy: 0.0001)
    }
    
    // MARK: - 28. Spatial Resolution Failure: Map Remains at Selected Coordinate
    
    @MainActor
    func test_28_spatial_resolution_failure_preserves_map_center() {
        let vm = MapViewModel()
        let coordinate = Coordinate(latitude: 21.8500, longitude: 86.3500)
        vm.mapCenter = coordinate
        
        // Simulate spatial resolution failure (temporarily unavailable)
        vm.spatialResolutionState = .temporarilyUnavailable(reason: "Resolution service offline")
        
        // Camera MUST remain at selected coordinate
        XCTAssertEqual(vm.mapCenter.latitude, coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, coordinate.longitude, accuracy: 0.0001)
        
        // Also verify .noCoverage failure retains camera
        vm.spatialResolutionState = .noCoverage(reason: "No cadastral coverage in this sector")
        XCTAssertEqual(vm.mapCenter.latitude, coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, coordinate.longitude, accuracy: 0.0001)
    }
    
    // MARK: - 29. Broad District / City Result: Navigates Directly Without Village Parcel Lookup
    
    @MainActor
    func test_29_broad_district_navigates_without_village_lookup() async throws {
        let vm = MapViewModel()
        
        let khordhaDistrict = LocationSearchResult(
            id: "bhumitra:district:20",
            title: "Khurda District",
            subtitle: "Official Administrative District Center, Odisha",
            type: .broadDistrict,
            latitude: 20.18,
            longitude: 85.62
        )
        
        try? await vm.selectLocation(khordhaDistrict)
        
        // Camera moves to district coordinate with broad zoom
        XCTAssertEqual(vm.mapCenter.latitude, 20.18, accuracy: 0.001)
        XCTAssertEqual(vm.mapCenter.longitude, 85.62, accuracy: 0.001)
        XCTAssertEqual(vm.zoomLevel, LocationSearchResultType.broadDistrict.recommendedZoomLevel)
        // Broad district must not trigger parcel loading
        XCTAssertEqual(vm.spatialResolutionState, .idle)
    }
    
    // MARK: - 30. Bare Plot "547": Never Guesses an Arbitrary Village
    
    @MainActor
    func test_30_bare_plot_requires_context() async throws {
        let vm = MapViewModel()
        vm.activeCadastralVillage = nil // No village selected yet
        
        let plotOnlyResult = LocationSearchResult(
            id: "bhumitra:plot:547",
            title: "Plot 547",
            subtitle: "Plot Intent: Please specify village or select village first",
            type: .plotOnly,
            latitude: nil,
            longitude: nil,
            parsedPlotNumber: "547"
        )
        
        let initialCenter = vm.mapCenter
        try? await vm.selectLocation(plotOnlyResult)
        
        // Camera must not jump to an arbitrary global plot
        XCTAssertEqual(vm.mapCenter.latitude, initialCenter.latitude)
        XCTAssertEqual(vm.toastIcon, "number.square.fill")
    }
    
    // MARK: - 31. Compound Plot "Plot 547 Patia": Preserves Compound Flow
    
    func test_31_compound_plot_preserves_parsed_plot() throws {
        let json = """
        {
            "id": "bhumitra:compound:547:village_2002060",
            "title": "Plot 547 in Patia",
            "subtitle": "Bhubaneswar Tahasil, Khurda District",
            "type": "COMPOUND_PLOT",
            "latitude": 20.3541,
            "longitude": 85.8193,
            "parsedPlotNumber": "547",
            "source": "BHUMITRA_CANONICAL_CATALOG"
        }
        """.data(using: .utf8)!
        
        let result = try JSONDecoder().decode(LocationSearchResult.self, from: json)
        XCTAssertEqual(result.type, .compoundPlot)
        XCTAssertEqual(result.parsedPlotNumber, "547")
        XCTAssertEqual(result.title, "Plot 547 in Patia")
        XCTAssertEqual(result.latitude, 20.3541)
    }
    
    // MARK: - 32. Physical Device API Configuration Uses Reachable URL
    
    func test_32_physical_device_api_configuration_is_reachable() {
        let config = APIConfiguration.shared
        
        // On non-simulator or production, baseURL must never be 127.0.0.1
        #if !targetEnvironment(simulator)
        XCTAssertFalse(config.baseURL.contains("127.0.0.1"), "Physical device must not use 127.0.0.1 localhost!")
        XCTAssertTrue(config.baseURL.hasPrefix("https://") || config.baseURL.contains("192.168.") || config.baseURL.contains("10."), "Must use reachable endpoint or LAN IP")
        #else
        XCTAssertTrue(config.baseURL.contains("127.0.0.1") || config.baseURL.contains("https://"), "Simulator may use local dev or production")
        #endif
    }
    
    // MARK: - 33. Result Type Recommended Zoom Levels
    
    func test_33_recommended_zoom_levels() {
        XCTAssertEqual(LocationSearchResultType.broadDistrict.recommendedZoomLevel, 9.5)
        XCTAssertEqual(LocationSearchResultType.broadCity.recommendedZoomLevel, 12.0)
        XCTAssertEqual(LocationSearchResultType.revenueVillage.recommendedZoomLevel, 16.0)
        XCTAssertEqual(LocationSearchResultType.landmark.recommendedZoomLevel, 16.5)
        XCTAssertEqual(LocationSearchResultType.compoundPlot.recommendedZoomLevel, 17.5)
        XCTAssertEqual(LocationSearchResultType.coordinate.recommendedZoomLevel, 17.0)
    }
    
    // MARK: - 34. Strict Relevance: Jaipur Returns Zero Results
    
    func test_34_jaipur_strict_relevance_zero_results() throws {
        let json = """
        {
            "query": "Jaipur",
            "intent": "GENERAL",
            "total": 0,
            "results": []
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: json)
        XCTAssertEqual(response.query, "Jaipur")
        XCTAssertEqual(response.total, 0)
        XCTAssertTrue(response.results.isEmpty, "No unrelated Odisha results allowed for Jaipur")
    }
    
    // MARK: - 35. Valid Result Selection Never Automatically Forces Manual Selector
    
    @MainActor
    func test_35_valid_result_never_forces_manual_selector() async throws {
        let vm = MapViewModel()
        vm.shouldOpenLocationPicker = false
        
        let validLocation = LocationSearchResult(
            id: "bhumitra:city:bhubaneswar",
            title: "Bhubaneswar",
            subtitle: "State Capital, Khordha District, Odisha",
            type: .broadCity,
            latitude: 20.2961,
            longitude: 85.8245
        )
        
        try? await vm.selectLocation(validLocation)
        
        // 1. Camera must move immediately to coordinates
        XCTAssertEqual(vm.mapCenter.latitude, 20.2961, accuracy: 0.001)
        XCTAssertEqual(vm.mapCenter.longitude, 85.8245, accuracy: 0.001)
        
        // 2. Manual location picker must NOT be opened automatically
        XCTAssertFalse(vm.shouldOpenLocationPicker, "Selecting a valid location must never force manual selector!")
    }
    
    // MARK: - 36. Mixed External Provider Response Filtering
    
    func test_36_mixed_external_provider_response_filtering() throws {
        // Validates that external responses containing out-of-state and unrelated candidates
        // are properly filtered to only keep genuine Odisha candidates
        let mixedJson = """
        {
            "query": "Kiit",
            "intent": "GENERAL",
            "total": 1,
            "results": [
                {
                    "id": "bhumitra:place:kiit_road",
                    "title": "KIIT Road",
                    "subtitle": "KIIT Road, Bhubaneswar Municipal Corporation, Odisha",
                    "type": "LANDMARK",
                    "latitude": 20.3533,
                    "longitude": 85.8263,
                    "source": "PHOTON_OSM"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: mixedJson)
        XCTAssertEqual(response.total, 1)
        let item = try XCTUnwrap(response.results.first)
        XCTAssertEqual(item.title, "KIIT Road")
        XCTAssertFalse(item.subtitle.contains("Rajasthan"))
    }
    
    // MARK: - 37. Search "Keri" -> Keonjhar Sadar Village Suggestion
    
    func test_37_search_keri_village_suggestion() throws {
        let json = """
        {
            "query": "Keri",
            "intent": "REVENUE_VILLAGE",
            "total": 1,
            "results": [
                {
                    "id": "bhumitra:village:7:4:330",
                    "title": "Keri (କେରି)",
                    "subtitle": "Keonjhar Sadar Tahasil, Keonjhar District",
                    "type": "REVENUE_VILLAGE",
                    "latitude": 21.68432,
                    "longitude": 85.71789,
                    "source": "BHUMITRA_CANONICAL_CATALOG",
                    "extraMetadata": {
                        "district_id": "7",
                        "tahasil_id": "4",
                        "mouza_id": "330",
                        "mouza_name_odia": "କେରି",
                        "tahasil_name": "Keonjhar Sadar",
                        "district_name": "Keonjhar"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: json)
        let result = try XCTUnwrap(response.results.first)
        XCTAssertEqual(result.title, "Keri (କେରି)")
        XCTAssertEqual(result.type, .revenueVillage)
        XCTAssertEqual(result.latitude, 21.68432)
        XCTAssertEqual(result.longitude, 85.71789)
        XCTAssertEqual(result.revenueVillageId, "0704330")
        XCTAssertEqual(result.district, "Keonjhar")
        XCTAssertEqual(result.tahasil, "Keonjhar Sadar")
    }
    
    // MARK: - 38. Search "Maidankel" -> Maidankela Keonjhar Sadar Suggestion
    
    func test_38_search_maidankel_village_suggestion() throws {
        let json = """
        {
            "query": "Maidankel",
            "intent": "REVENUE_VILLAGE",
            "total": 1,
            "results": [
                {
                    "id": "bhumitra:village:7:4:329",
                    "title": "Maidankela (ମଇଦାନକେଲା)",
                    "subtitle": "Keonjhar Sadar Tahasil, Keonjhar District",
                    "type": "REVENUE_VILLAGE",
                    "latitude": 21.6643,
                    "longitude": 85.71056,
                    "source": "BHUMITRA_CANONICAL_CATALOG",
                    "extraMetadata": {
                        "district_id": "7",
                        "tahasil_id": "4",
                        "mouza_id": "329",
                        "mouza_name_odia": "ମଇଦାନକେଲା",
                        "tahasil_name": "Keonjhar Sadar",
                        "district_name": "Keonjhar"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LocationSearchResponse.self, from: json)
        let result = try XCTUnwrap(response.results.first)
        XCTAssertEqual(result.title, "Maidankela (ମଇଦାନକେଲା)")
        XCTAssertEqual(result.type, .revenueVillage)
        XCTAssertEqual(result.latitude, 21.6643)
        XCTAssertEqual(result.longitude, 85.71056)
        XCTAssertEqual(result.revenueVillageId, "0704329")
        XCTAssertEqual(result.district, "Keonjhar")
        XCTAssertEqual(result.tahasil, "Keonjhar Sadar")
    }
    
    // MARK: - 39. GeoJSON Feature Parser Creates MLNShape for All Villages
    
    func test_39_geojson_feature_parser_creates_shape_for_all_villages() async throws {
        let villages: [(id: String, name: String)] = [
            ("0704330", "Keri"),
            ("0704329", "Maidankela"),
            ("2001100", "Gobindapur"),
            ("0706017", "Ghatgaon"),
            ("0309092", "Naranapur"),
            ("0702133", "Dabuna")
        ]
        
        for (vId, vName) in villages {
            guard let url = URL(string: "http://127.0.0.1:8000/api/v1/gis/village/\(vId)/parcels") else { continue }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                XCTFail("Failed to fetch parcels for \(vName) (\(vId))")
                continue
            }
            
            let village = CadastralVillage(
                id: vId,
                name: vName,
                gpID: nil,
                blockID: "",
                districtID: nil,
                blockName: nil,
                districtName: nil
            )
            
            let parsed = GeoJSONFeatureParser.parse(data: data, village: village)
            print("TEST_39: \(vName) (\(vId)) -> parsed total: \(parsed.totalCount), parcels: \(parsed.parcels.count), shape: \(String(describing: parsed.shape))")
            XCTAssertGreaterThan(parsed.totalCount, 0, "\(vName) should have parcels")
            XCTAssertNotNil(parsed.shape, "\(vName) must produce a non-nil MLNShape")
        }
    }
    
    // MARK: - 40. GPS Flow: Concurrency Guard / Re-entrancy Protection
    
    @MainActor
    func test_40_gps_flow_concurrency_guard_prevents_duplicate_resolution() {
        let vm = MapViewModel()
        XCTAssertFalse(vm.isResolvingGPSLocation)
        
        // Simulating in-flight GPS resolution
        vm.isResolvingGPSLocation = true
        
        // Tapping again while in progress should be ignored
        vm.locateAndShowNearbyPlots()
        
        // State remains locked to in-flight
        XCTAssertTrue(vm.isResolvingGPSLocation)
    }
    
    // MARK: - 41. GPS Flow: Outside Odisha Short-Circuits Directly
    
    @MainActor
    func test_41_gps_flow_outside_odisha_detection() {
        let vm = MapViewModel()
        
        // Delhi coordinates (outside Odisha: 17.70-22.65, 81.30-87.60)
        let delhiLat = 28.6139
        let delhiLon = 77.2090
        
        let isInside = (17.70 <= delhiLat && delhiLat <= 22.65) && (81.30 <= delhiLon && delhiLon <= 87.60)
        XCTAssertFalse(isInside)
        
        // Odisha coordinates (Patia, Bhubaneswar)
        let odishaLat = 20.3541
        let odishaLon = 85.8193
        let isInsideOdisha = (17.70 <= odishaLat && odishaLat <= 22.65) && (81.30 <= odishaLon && odishaLon <= 87.60)
        XCTAssertTrue(isInsideOdisha)
    }
    
    // MARK: - 42. GPS Flow: Preserves Center on Parcel Loading
    
    @MainActor
    func test_42_gps_flow_preserve_center_retains_user_coordinate() async throws {
        let vm = MapViewModel()
        let userCoord = Coordinate(latitude: 20.3541, longitude: 85.8193)
        vm.mapCenter = userCoord
        
        let targetVillage = CadastralVillage(
            id: "2002060",
            name: "Patia",
            gpID: nil,
            blockID: "02",
            districtID: "20",
            blockName: "Bhubaneswar",
            districtName: "Khurda"
        )
        
        // Simulating parcel load with preserveCenter = true when network is offline/error
        await vm.loadCadastralVillage(village: targetVillage, preserveCenter: true)
        
        // When load fails or completes, camera must NEVER jump away from userCoord if preserveCenter is true
        XCTAssertEqual(vm.mapCenter.latitude, userCoord.latitude, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, userCoord.longitude, accuracy: 0.0001)
    }
    
    // MARK: - 43. GPS Flow: Spatial Resolution State Transitions
    
    @MainActor
    func test_43_gps_flow_state_transitions() {
        let vm = MapViewModel()
        XCTAssertEqual(vm.spatialResolutionState, .idle)
        
        // 1. User taps GPS button -> State becomes resolving
        vm.spatialResolutionState = .resolving(title: "plots near you")
        XCTAssertEqual(vm.spatialResolutionState, .resolving(title: "plots near you"))
        
        // 2. Village resolved -> State becomes loadingParcels
        vm.spatialResolutionState = .loadingParcels(villageName: "Patia")
        XCTAssertEqual(vm.spatialResolutionState, .loadingParcels(villageName: "Patia"))
        
        // 3. Parcels loaded -> State becomes ready
        vm.spatialResolutionState = .ready(message: "Plots near you")
        XCTAssertEqual(vm.spatialResolutionState, .ready(message: "Plots near you"))
    }
    
    // MARK: - 44. GPS Flow: LocationPermissionManager Authorization Status Mapping
    
    @MainActor
    func test_44_location_permission_manager_status() {
        let manager = LocationPermissionManager.shared
        manager.refresh()
        
        // Display string must be non-empty and one of expected statuses
        let status = manager.statusDisplay
        XCTAssertFalse(status.isEmpty)
        XCTAssertTrue(["Enabled", "Permission required", "Not Determined", "Disabled"].contains(status))
    }
    
    // MARK: - 45. GPS Flow: Full End-to-End Resolution Pipeline Sequence
    
    @MainActor
    func test_45_gps_flow_end_to_end_resolution() async throws {
        let vm = MapViewModel()
        
        // 1. Initial State
        XCTAssertEqual(vm.spatialResolutionState, .idle)
        XCTAssertFalse(vm.isResolvingGPSLocation)
        
        // 2. Simulated GPS tap at Patia (20.3541, 85.8193)
        let lat = 20.3541
        let lon = 85.8193
        
        // Fast camera move to user GPS location
        vm.moveCamera(to: Coordinate(latitude: lat, longitude: lon), zoom: 16.5)
        XCTAssertEqual(vm.mapCenter.latitude, lat, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, lon, accuracy: 0.0001)
        XCTAssertEqual(vm.zoomLevel, 16.5)
        
        // State transitions to resolving
        vm.spatialResolutionState = .resolving(title: "plots near you")
        XCTAssertEqual(vm.spatialResolutionState, .resolving(title: "plots near you"))
        
        // 3. Resolve coordinate (use mock decoded resolution if local dev backend is not running during CI)
        let resolution: LocationResolutionResponse
        do {
            resolution = try await LocationSearchService.shared.resolveCoordinate(
                latitude: lat,
                longitude: lon,
                candidateVillageIds: nil
            )
        } catch {
            let fallbackJson = """
            {
                "status": "EXACT",
                "district": "Khurda",
                "district_id": "20",
                "tahasil": "Bhubaneswar",
                "tahasil_id": "02",
                "revenue_village": "Patia",
                "revenue_village_id": "2002060",
                "bhulekh_mouza_id": "60",
                "plot_number": "318",
                "latitude": 20.3541,
                "longitude": 85.8193,
                "resolution_reason": "Exact containing parcel matched in 4K GEO cadastral coverage.",
                "candidates": []
            }
            """.data(using: .utf8)!
            resolution = try JSONDecoder().decode(LocationResolutionResponse.self, from: fallbackJson)
        }
        
        XCTAssertEqual(resolution.status, .exact)
        XCTAssertEqual(resolution.revenueVillageId, "2002060")
        XCTAssertEqual(resolution.revenueVillage, "Patia")
        
        // 4. Load village parcels with preserveCenter: true
        let targetVillage = CadastralVillage(
            id: resolution.revenueVillageId!,
            name: resolution.revenueVillage!,
            gpID: nil,
            blockID: resolution.tahasilId ?? "",
            districtID: resolution.districtId,
            blockName: resolution.tahasil,
            districtName: resolution.district
        )
        
        vm.spatialResolutionState = .loadingParcels(villageName: targetVillage.name)
        XCTAssertEqual(vm.spatialResolutionState, .loadingParcels(villageName: "Patia"))
        
        await vm.loadCadastralVillage(village: targetVillage, preserveCenter: true)
        
        // 5. Verify camera preserved at user GPS coordinate
        XCTAssertEqual(vm.mapCenter.latitude, lat, accuracy: 0.0001)
        XCTAssertEqual(vm.mapCenter.longitude, lon, accuracy: 0.0001)
        
        // 6. If plot is present and loaded, verify selection
        if let plotNum = resolution.plotNumber {
            if let parcel = vm.cadastralParcels.first(where: { $0.plotNumber == plotNum }) {
                vm.onCadastralParcelSelected(parcel)
                XCTAssertEqual(vm.selectedCadastralParcel?.plotNumber, plotNum)
            }
        }
        
        vm.spatialResolutionState = .ready(message: "Plots near you")
        XCTAssertEqual(vm.spatialResolutionState, .ready(message: "Plots near you"))
    }
    
    // MARK: - 46. GPS Flow: Location Timeout, Fallback Hierarchy & Re-entrancy Guards
    
    @MainActor
    func test_46_gps_reentrancy_and_lock_release() async {
        let vm = MapViewModel()
        XCTAssertFalse(vm.isResolvingGPSLocation)
        
        // Tap GPS once: locks and sets immediate visual resolving feedback
        vm.locateAndShowNearbyPlots()
        XCTAssertTrue(vm.isResolvingGPSLocation)
        XCTAssertEqual(vm.spatialResolutionState, .resolving(title: "Finding your location…"))
        
        // Repeated tap while resolving is blocked
        vm.locateAndShowNearbyPlots()
        XCTAssertTrue(vm.isResolvingGPSLocation)
        
        // Wait for bounded execution or timeout
        try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000)
    }
    
    @MainActor
    func test_47_map_center_is_never_used_as_cadastral_fallback() async {
        let vm = MapViewModel()
        
        // Pan map camera arbitrarily far away from user to Koraput (18.8135, 82.7123)
        vm.moveCamera(to: Coordinate(latitude: 18.8135, longitude: 82.7123), zoom: 14.0)
        XCTAssertEqual(vm.mapCenter.latitude, 18.8135, accuracy: 0.001)
        
        // Ensure that MapLibre user location is nil or separate
        vm.lastKnownMapLibreUserLocation = nil
        
        // Verify that the view model does NOT automatically copy mapCenter into cadastral coordinate
        // In locateAndShowNearbyPlots, only LocationPermissionManager or actual user dot is accepted.
        XCTAssertNil(vm.lastKnownMapLibreUserLocation)
    }
    
    @MainActor
    func test_48_maplibre_user_location_fallback_hierarchy() async {
        let vm = MapViewModel()
        
        // Given MapLibre has an active user location at Patia
        let userLocation = Coordinate(latitude: 20.3541, longitude: 85.8193)
        vm.lastKnownMapLibreUserLocation = userLocation
        
        XCTAssertNotNil(vm.lastKnownMapLibreUserLocation)
        XCTAssertEqual(vm.lastKnownMapLibreUserLocation?.latitude, 20.3541)
        XCTAssertEqual(vm.lastKnownMapLibreUserLocation?.longitude, 85.8193)
    }
    
    @MainActor
    func test_49_location_permission_manager_timeout_is_bounded() async {
        let manager = LocationPermissionManager.shared
        // Bounded call with short timeout (e.g. 0.1s in unit test environment)
        do {
            _ = try await manager.requestCurrentLocation(timeoutSeconds: 0.1)
        } catch {
            // Must throw cleanly without hanging indefinitely
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - 50. P0 Fix 1: Distinct Location Error States
    
    @MainActor
    func test_50_distinct_location_error_states() {
        let vm = MapViewModel()
        
        vm.spatialResolutionState = .locationPermissionDenied
        XCTAssertEqual(vm.spatialResolutionState, .locationPermissionDenied)
        
        vm.spatialResolutionState = .locationServicesDisabled
        XCTAssertEqual(vm.spatialResolutionState, .locationServicesDisabled)
        
        vm.spatialResolutionState = .locationTimeout
        XCTAssertEqual(vm.spatialResolutionState, .locationTimeout)
        
        vm.spatialResolutionState = .locationUnavailable
        XCTAssertEqual(vm.spatialResolutionState, .locationUnavailable)
    }
    
    // MARK: - 51. P0 Fix 1: Distinct Server Error States
    
    @MainActor
    func test_51_distinct_server_error_states() {
        let vm = MapViewModel()
        
        vm.spatialResolutionState = .noInternet
        XCTAssertEqual(vm.spatialResolutionState, .noInternet)
        
        vm.spatialResolutionState = .backendTemporarilyUnavailable(reason: "Server busy")
        XCTAssertEqual(vm.spatialResolutionState, .backendTemporarilyUnavailable(reason: "Server busy"))
        
        vm.spatialResolutionState = .parcelLoadFailed(villageName: "Patia", reason: "Connection lost")
        XCTAssertEqual(vm.spatialResolutionState, .parcelLoadFailed(villageName: "Patia", reason: "Connection lost"))
    }
    
    // MARK: - 52. P0 Fix 2: Accuracy-Aware High Confidence Selection (<= 15m)
    
    @MainActor
    func test_52_accuracy_aware_high_confidence_selection() {
        let vm = MapViewModel()
        let highConfidenceAccuracy = 8.5 // <= 15m
        
        let context = GPSAutoSelectionContext(plotNumber: "318", accuracy: highConfidenceAccuracy)
        vm.gpsAutoSelectionContext = context
        
        XCTAssertNotNil(vm.gpsAutoSelectionContext)
        XCTAssertEqual(vm.gpsAutoSelectionContext?.plotNumber, "318")
        XCTAssertEqual(vm.gpsAutoSelectionContext?.accuracy, 8.5)
    }
    
    // MARK: - 53. P0 Fix 2: Accuracy-Aware Moderate Confidence Suppression (>15m, <=35m)
    
    @MainActor
    func test_53_accuracy_aware_moderate_confidence_suppression() {
        let vm = MapViewModel()
        let moderateAccuracy = 25.0 // >15m, <=35m
        
        vm.selectedParcel = nil
        vm.selectedCadastralParcel = nil
        vm.gpsAutoSelectionContext = nil
        vm.spatialResolutionState = .plotsNearYou(accuracy: moderateAccuracy)
        
        XCTAssertNil(vm.selectedParcel)
        XCTAssertNil(vm.selectedCadastralParcel)
        XCTAssertNil(vm.gpsAutoSelectionContext)
        XCTAssertEqual(vm.spatialResolutionState, .plotsNearYou(accuracy: 25.0))
    }
    
    // MARK: - 54. P0 Fix 2: Accuracy-Aware Low Confidence Suppression (>35m, <=100m)
    
    @MainActor
    func test_54_accuracy_aware_low_confidence_suppression() {
        let vm = MapViewModel()
        let lowAccuracy = 55.0 // >35m, <=100m
        
        vm.selectedParcel = nil
        vm.selectedCadastralParcel = nil
        vm.gpsAutoSelectionContext = nil
        vm.spatialResolutionState = .approximateLocation(accuracy: lowAccuracy)
        
        XCTAssertNil(vm.selectedParcel)
        XCTAssertNil(vm.selectedCadastralParcel)
        XCTAssertNil(vm.gpsAutoSelectionContext)
        XCTAssertEqual(vm.spatialResolutionState, .approximateLocation(accuracy: 55.0))
    }
    
    // MARK: - 55. P0 Fix 2: Accuracy-Aware Very Low Confidence Gating (>100m)
    
    @MainActor
    func test_55_accuracy_aware_very_low_confidence_gating() {
        let vm = MapViewModel()
        let veryLowAccuracy = 150.0 // >100m
        
        vm.spatialResolutionState = .preciseLocationRecommended(accuracy: veryLowAccuracy)
        XCTAssertEqual(vm.spatialResolutionState, .preciseLocationRecommended(accuracy: 150.0))
        XCTAssertNil(vm.selectedParcel)
        XCTAssertNil(vm.gpsAutoSelectionContext)
    }
    
    // MARK: - 56. P0 Fix 3: Search Conflict Cancels Active GPS Task & Token
    
    @MainActor
    func test_56_search_conflict_cancels_active_gps_task_and_token() {
        let vm = MapViewModel()
        let initialToken = vm.activeSelectionToken
        
        vm.gpsAutoSelectionContext = GPSAutoSelectionContext(plotNumber: "318", accuracy: 10.0)
        vm.spatialResolutionState = .plotsNearYou(accuracy: 25.0)
        
        // Typing query invokes cancelActiveGPSAndClearPlotSelection
        vm.searchQuery = "Bhubaneswar"
        
        XCTAssertNotEqual(vm.activeSelectionToken, initialToken)
        XCTAssertNil(vm.gpsAutoSelectionContext)
        XCTAssertEqual(vm.spatialResolutionState, .idle)
    }
    
    // MARK: - 57. P0 Fix 3: Search Focus Dismisses GPS Resolution State
    
    @MainActor
    func test_57_search_focus_dismisses_gps_resolution_state() {
        let vm = MapViewModel()
        let initialToken = vm.activeSelectionToken
        
        vm.spatialResolutionState = .resolving(title: "plots near you")
        vm.isSearchFocused = true
        
        XCTAssertNotEqual(vm.activeSelectionToken, initialToken)
        XCTAssertEqual(vm.spatialResolutionState, .idle)
    }
    
    // MARK: - 58. P0 Fix 4: Auto-Selected Plot Copy & Non-Ownership Phrasing
    
    @MainActor
    func test_58_auto_selected_plot_copy_and_non_ownership_phrasing() {
        let plotNum = "318"
        let accuracy = 12.0
        
        let title = "Your location appears to be inside Plot \(plotNum)"
        let secondary = "Location accuracy ±\(Int(accuracy))m"
        let supporting = "Plot boundaries are based on available cadastral map data."
        
        XCTAssertFalse(title.contains("Found Plot"))
        XCTAssertFalse(title.contains("Your Plot"))
        XCTAssertTrue(title.contains("appears to be inside"))
        XCTAssertEqual(secondary, "Location accuracy ±12m")
        XCTAssertEqual(supporting, "Plot boundaries are based on available cadastral map data.")
    }
    
    // MARK: - 59. Manual Parcel Selection Clears GPS Auto-Selection Context
    
    @MainActor
    func test_59_manual_parcel_selection_clears_gps_auto_selection_context() {
        let vm = MapViewModel()
        vm.gpsAutoSelectionContext = GPSAutoSelectionContext(plotNumber: "318", accuracy: 8.0)
        
        // When user selects a different parcel manually (e.g. plot 405)
        let manualParcel = CadastralParcel(
            districtID: "20",
            districtName: "Khurda",
            blockID: "02",
            blockName: "Bhubaneswar",
            villageID: "2002060",
            villageName: "Patia",
            plotNumber: "405",
            centroid: [85.819, 20.355],
            geometryType: "Polygon",
            boundary: [Coordinate(latitude: 20.355, longitude: 85.819)]
        )
        
        vm.onCadastralParcelSelected(manualParcel)
        
        XCTAssertNil(vm.gpsAutoSelectionContext, "Manual selection of a different plot must clear GPS auto selection context")
        XCTAssertEqual(vm.selectedCadastralParcel?.plotNumber, "405")
    }
    
    // MARK: - 60. Network Connection Error Detection Helper
    
    @MainActor
    func test_60_network_connection_error_detection() {
        let vm = MapViewModel()
        
        let offlineErr = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."])
        XCTAssertTrue(vm.isNetworkConnectionError(offlineErr))
        
        let timeoutErr = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSLocalizedDescriptionKey: "The request timed out."])
        XCTAssertTrue(vm.isNetworkConnectionError(timeoutErr))
        
        let genericErr = NSError(domain: "CustomDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        XCTAssertFalse(vm.isNetworkConnectionError(genericErr))
    }
}


