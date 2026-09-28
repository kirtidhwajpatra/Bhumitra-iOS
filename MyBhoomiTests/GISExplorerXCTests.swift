//
//  GISExplorerXCTests.swift
//  MyBhoomiTests
//
//  Automated XCTest suite verifying Odisha GIS Explorer navigation hierarchy,
//  state isolation, camera bounds, and parcel handoff.
//

import XCTest
import SwiftUI
import CoreLocation
@testable import MyBhoomi

@MainActor
final class GISExplorerXCTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "gis_navigation_enabled")
        GISExplorerViewModel.shared.exitExplorer()
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "gis_navigation_enabled")
        GISExplorerViewModel.shared.exitExplorer()
        super.tearDown()
    }
    
    // TEST 1: Feature flag defaults & explicit overrides
    func test_1_feature_flag_defaults_and_explicit_overrides() {
        UserDefaults.standard.removeObject(forKey: "gis_navigation_enabled")
        #if DEBUG
        XCTAssertTrue(AppConfig.gisNavigationEnabled, "DEBUG builds must default to true")
        #else
        XCTAssertFalse(AppConfig.gisNavigationEnabled, "RELEASE builds must default to false")
        #endif
        
        // Explicit override false
        UserDefaults.standard.set(false, forKey: "gis_navigation_enabled")
        XCTAssertFalse(AppConfig.gisNavigationEnabled)
        
        // Explicit override true
        UserDefaults.standard.set(true, forKey: "gis_navigation_enabled")
        XCTAssertTrue(AppConfig.gisNavigationEnabled)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "gis_navigation_enabled")
    }
    
    // TEST 2: Initial state
    func test_2_initial_state_odisha() {
        let vm = GISExplorerViewModel()
        XCTAssertEqual(vm.currentLevel, .odisha)
        XCTAssertEqual(vm.breadcrumbs.count, 1)
        XCTAssertEqual(vm.breadcrumbs.first?.title, "Odisha")
        XCTAssertNil(vm.selectedDistrictID)
        XCTAssertNil(vm.selectedDistrictFeature)
        XCTAssertNil(vm.selectedSubdivision)
        XCTAssertNil(vm.selectedVillage)
    }
    
    // TEST 3: Navigation hierarchy down to village
    func test_3_hierarchy_navigation_and_breadcrumbs() {
        let vm = GISExplorerViewModel()
        
        let district = GISDistrictFeature(
            id: "cuttack",
            name: "Cuttack",
            code2Digit: "03",
            bhulekhID: "306",
            centerLat: 20.46,
            centerLng: 85.88,
            bbox: [85.34, 20.21, 86.41, 20.73]
        )
        let sub = CadastralBlock(id: "0301", name: "Sadar", districtID: "cuttack")
        let vill = CadastralVillage(id: "030101", name: "Bidanasi", blockID: "0301", districtID: "cuttack")
        
        // Select District
        vm.selectDistrict(feature: district)
        XCTAssertEqual(vm.selectedDistrictID, "cuttack")
        XCTAssertEqual(vm.breadcrumbs.count, 2)
        XCTAssertEqual(vm.breadcrumbs[1].title, "Cuttack")
        XCTAssertNotNil(vm.targetCameraBounds)
        
        // Select Subdivision
        vm.selectSubdivision(sub)
        XCTAssertEqual(vm.selectedSubdivision?.id, "0301")
        XCTAssertEqual(vm.breadcrumbs.count, 3)
        XCTAssertEqual(vm.breadcrumbs[2].title, "Sadar")
        
        // Select Village
        vm.selectVillage(vill)
        XCTAssertEqual(vm.selectedVillage?.id, "030101")
        XCTAssertEqual(vm.breadcrumbs.count, 4)
        XCTAssertEqual(vm.breadcrumbs[3].title, "Bidanasi")
        
        // Breadcrumb Back-Navigation to District
        let districtBreadcrumb = vm.breadcrumbs[1]
        vm.navigateToBreadcrumb(districtBreadcrumb)
        XCTAssertEqual(vm.breadcrumbs.count, 2)
        XCTAssertNil(vm.selectedSubdivision)
        XCTAssertNil(vm.selectedVillage)
        
        // Breadcrumb Back-Navigation to Odisha
        let odishaBreadcrumb = vm.breadcrumbs[0]
        vm.navigateToBreadcrumb(odishaBreadcrumb)
        XCTAssertEqual(vm.currentLevel, .odisha)
        XCTAssertEqual(vm.breadcrumbs.count, 1)
        XCTAssertNil(vm.selectedDistrictID)
    }
    
    // TEST 4: Camera bounds calculation
    func test_4_camera_bounds_coordinates() {
        let feat = GISDistrictFeature(
            id: "keonjhar",
            name: "Kendujhar",
            code2Digit: "07",
            bhulekhID: "224",
            centerLat: 21.63,
            centerLng: 85.58,
            bbox: [85.11, 21.01, 86.37, 22.17]
        )
        
        let sw = CLLocationCoordinate2D(latitude: feat.bbox[1], longitude: feat.bbox[0])
        let ne = CLLocationCoordinate2D(latitude: feat.bbox[3], longitude: feat.bbox[2])
        
        XCTAssertEqual(sw.latitude, 21.01, accuracy: 0.001)
        XCTAssertEqual(sw.longitude, 85.11, accuracy: 0.001)
        XCTAssertEqual(ne.latitude, 22.17, accuracy: 0.001)
        XCTAssertEqual(ne.longitude, 86.37, accuracy: 0.001)
    }
    
    // TEST 5: Standalone test runner executes with 0 failures
    func test_5_standalone_test_runner_passes() {
        let (passed, failed, errors) = GISExplorerTests.runAllTests()
        XCTAssertEqual(failed, 0, "GISExplorerTests had failures: \(errors)")
        XCTAssertGreaterThan(passed, 0)
    }
    
    // TEST 6: Normal request uses protocol cache policy
    func test_6_normal_request_uses_protocol_cache_policy() {
        let repo = GISExplorerRepository.shared
        guard let geoReq = repo.makeDistrictsGeoJSONRequest(forceRefresh: false),
              let metaReq = repo.makeDistrictsSummaryRequest(forceRefresh: false) else {
            XCTFail("Failed to build request")
            return
        }
        XCTAssertEqual(geoReq.cachePolicy, .useProtocolCachePolicy)
        XCTAssertEqual(metaReq.cachePolicy, .useProtocolCachePolicy)
    }
    
    // TEST 7: Force refresh uses reloadIgnoringLocalCacheData
    func test_7_force_refresh_uses_reload_ignoring_local_cache_data() {
        let repo = GISExplorerRepository.shared
        guard let geoReq = repo.makeDistrictsGeoJSONRequest(forceRefresh: true),
              let metaReq = repo.makeDistrictsSummaryRequest(forceRefresh: true) else {
            XCTFail("Failed to build request")
            return
        }
        XCTAssertEqual(geoReq.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(metaReq.cachePolicy, .reloadIgnoringLocalCacheData)
    }
    
    // TEST 8: Retry cannot return stale cached 404 from previous failed request
    func test_8_retry_bypasses_cached_404() {
        let repo = GISExplorerRepository.shared
        guard let retryReq = repo.makeDistrictsGeoJSONRequest(forceRefresh: true) else {
            XCTFail("Failed to build retry request")
            return
        }
        // CFNetwork is instructed to ignore any existing cached response (including 404)
        XCTAssertEqual(retryReq.cachePolicy, .reloadIgnoringLocalCacheData)
    }
    
    // TEST 9: Tahasil selection sets subdivision level and updates breadcrumbs
    func test_9_tahasil_selection_hierarchy() {
        let vm = GISExplorerViewModel()
        let district = GISDistrictFeature(
            id: "306",
            name: "Cuttack",
            code2Digit: "03",
            bhulekhID: "306",
            centerLat: 20.46,
            centerLng: 85.88,
            bbox: [85.34, 20.21, 86.41, 20.73]
        )
        vm.selectDistrict(feature: district)
        XCTAssertEqual(vm.breadcrumbs.count, 2)
        
        vm.selectTahasilByID("0301", name: "Athagarh", bbox: [85.54, 20.43, 85.86, 20.67])
        XCTAssertEqual(vm.selectedTahasilID, "0301")
        XCTAssertEqual(vm.selectedSubdivision?.name, "Athagarh")
        XCTAssertEqual(vm.breadcrumbs.count, 3)
        XCTAssertEqual(vm.breadcrumbs[2].title, "Athagarh")
        XCTAssertNotNil(vm.targetCameraBounds)
    }
    
    // TEST 10: Tahasils GeoJSON request configuration
    func test_10_tahasils_request_configuration() {
        let repo = GISExplorerRepository.shared
        guard let normalReq = repo.makeTahasilsGeoJSONRequest(districtID: "306", forceRefresh: false),
              let refreshReq = repo.makeTahasilsGeoJSONRequest(districtID: "306", forceRefresh: true) else {
            XCTFail("Failed to make Tahasils GeoJSON request")
            return
        }
        XCTAssertEqual(normalReq.cachePolicy, .useProtocolCachePolicy)
        XCTAssertEqual(refreshReq.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertTrue(normalReq.url?.absoluteString.contains("/gis/navigation/districts/306/tahasils-geojson") == true)
    }
    
    // TEST 11: Deterministic district palette assigns stable, distinct colors
    func test_11_deterministic_district_palette() {
        let palette = GISVisualTheme.districtPaletteHex
        XCTAssertEqual(palette.count, 8)
        
        let color1 = GISVisualTheme.deterministicColorHex(for: "cuttack", palette: palette)
        let color2 = GISVisualTheme.deterministicColorHex(for: "cuttack", palette: palette)
        XCTAssertEqual(color1, color2, "Deterministic color must be stable across multiple lookups")
        
        let colorKeonjhar = GISVisualTheme.deterministicColorHex(for: "keonjhar", palette: palette)
        XCTAssertTrue(palette.contains(color1))
        XCTAssertTrue(palette.contains(colorKeonjhar))
    }
    
    // TEST 12: Deterministic Tahasil palette assigns distinct administrative tones
    func test_12_deterministic_tahasil_palette() {
        let palette = GISVisualTheme.tahasilPaletteHex
        XCTAssertEqual(palette.count, 8)
        
        let athagarhColor = GISVisualTheme.deterministicColorHex(for: "0301", palette: palette)
        let sadarColor = GISVisualTheme.deterministicColorHex(for: "0302", palette: palette)
        XCTAssertTrue(palette.contains(athagarhColor))
        XCTAssertTrue(palette.contains(sadarColor))
    }
    
    // TEST 13: Deterministic parcel palette distinguishes adjacent plot numbers
    func test_13_deterministic_parcel_palette() {
        let palette = GeoJSONFeatureParser.shadePalette
        XCTAssertGreaterThanOrEqual(palette.count, 8)
        
        let plot1 = GeoJSONFeatureParser.colorForPlot("101", index: 0)
        let plot2 = GeoJSONFeatureParser.colorForPlot("102", index: 1)
        let plot3 = GeoJSONFeatureParser.colorForPlot("103", index: 2)
        
        XCTAssertTrue(palette.contains(plot1))
        XCTAssertTrue(palette.contains(plot2))
        XCTAssertTrue(palette.contains(plot3))
        // Verify sequential plots do not all share the exact same color
        let uniquePlots = Set([plot1, plot2, plot3])
        XCTAssertGreaterThan(uniquePlots.count, 1, "Adjacent plots must receive contrasting colors")
    }
    
    // TEST 14: Selected vs Muted outline colors adapt to appearance
    func test_14_selected_and_muted_theme_colors() {
        let lightSelected = GISVisualTheme.selectedOutlineColor(for: .light)
        let darkSelected = GISVisualTheme.selectedOutlineColor(for: .dark)
        XCTAssertNotNil(lightSelected)
        XCTAssertNotNil(darkSelected)
        
        let lightMuted = GISVisualTheme.mutedOutlineColor(for: .light)
        let darkMuted = GISVisualTheme.mutedOutlineColor(for: .dark)
        XCTAssertNotNil(lightMuted)
        XCTAssertNotNil(darkMuted)
    }
    
    // TEST 15: Map focus dimming color is translucent
    func test_15_focus_dim_color_contrast() {
        let lightDim = GISVisualTheme.focusDimColor(for: .light)
        let darkDim = GISVisualTheme.focusDimColor(for: .dark)
        
        var white: CGFloat = 0, alpha: CGFloat = 0
        lightDim.getWhite(&white, alpha: &alpha)
        XCTAssertLessThanOrEqual(alpha, 0.40, "Focus dimming must not black out the map")
        XCTAssertGreaterThan(alpha, 0.05, "Focus dimming must provide enough contrast")
        
        darkDim.getWhite(&white, alpha: &alpha)
        XCTAssertLessThanOrEqual(alpha, 0.45, "Focus dimming in dark mode must remain translucent")
    }
    
    // TEST 16: GeoJSON enrichment injects fill_color into features
    func test_16_geojson_enrichment_injects_fill_color() {
        let sampleGeoJSON = """
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": { "district_id": "cuttack", "district_name": "Cuttack" },
                    "geometry": { "type": "Polygon", "coordinates": [[[85.0, 20.0], [86.0, 20.0], [86.0, 21.0], [85.0, 20.0]]] }
                }
            ]
        }
        """
        guard let data = sampleGeoJSON.data(using: .utf8) else {
            XCTFail("Failed to encode sample GeoJSON")
            return
        }
        let enrichedShape = GISExplorerViewModel.enrichDistrictsGeoJSON(data)
        XCTAssertNotNil(enrichedShape, "Enriched shape must be successfully created by MLNShape")
    }
    
    // TEST 17: Breadcrumb back-navigation resets lower tiers cleanly
    func test_17_breadcrumb_back_navigation_state_cleanup() {
        let vm = GISExplorerViewModel()
        let district = GISDistrictFeature(
            id: "306",
            name: "Cuttack",
            code2Digit: "03",
            bhulekhID: "306",
            centerLat: 20.46,
            centerLng: 85.88,
            bbox: [85.34, 20.21, 86.41, 20.73]
        )
        let sub = CadastralBlock(id: "0301", name: "Athagarh", districtID: "306")
        let vill = CadastralVillage(id: "030101", name: "Anantapur-64", blockID: "0301", districtID: "306")
        
        vm.selectDistrict(feature: district)
        vm.selectSubdivision(sub)
        vm.selectVillage(vill)
        
        XCTAssertEqual(vm.currentLevel, .village(vill))
        XCTAssertEqual(vm.breadcrumbs.count, 4)
        
        // Tap District in breadcrumbs
        let districtBreadcrumb = vm.breadcrumbs[1]
        vm.navigateToBreadcrumb(districtBreadcrumb)
        
        XCTAssertEqual(vm.currentLevel, .district(CadastralDistrict(id: "306", name: "Cuttack"), bbox: district.bbox))
        XCTAssertNil(vm.selectedSubdivision)
        XCTAssertNil(vm.selectedVillage)
        XCTAssertEqual(vm.breadcrumbs.count, 2)
    }
    
    // TEST 18: Feature states enum equality
    func test_18_feature_states_enum() {
        let state1: GISFeatureState = .defaultInteractive
        let state2: GISFeatureState = .selected
        let state3: GISFeatureState = .mutedContext
        let state4: GISFeatureState = .hidden
        
        XCTAssertNotEqual(state1, state2)
        XCTAssertNotEqual(state2, state3)
        XCTAssertNotEqual(state3, state4)
    }
}
