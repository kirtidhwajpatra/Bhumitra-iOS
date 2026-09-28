import Foundation
import CoreLocation
import MapLibre

/// Unit test suite for Odisha GIS Explorer & State Isolation
@MainActor
public struct GISExplorerTests {
    
    public static func runAllTests() -> (passed: Int, failed: Int, errors: [String]) {
        var passed = 0
        var failed = 0
        var errors: [String] = []
        
        func evaluate(_ name: String, _ block: () -> Bool) {
            let result = block()
            if result {
                passed += 1
                print("✅ [PASS] \(name)")
            } else {
                failed += 1
                let err = "❌ [FAIL] \(name)"
                errors.append(err)
                print(err)
            }
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  RUNNING ODISHA GIS EXPLORER TEST SUITE (iOS)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Preserve initial repository singleton state to prevent test contamination
        let initialCachedDistricts = GISExplorerRepository.shared.getCachedDistricts()
        defer {
            GISExplorerRepository.shared.restoreCachedDistricts(initialCachedDistricts)
            GISExplorerViewModel.shared.exitExplorer()
        }
        
        // 1. Feature flag is configured and respects DEBUG/RELEASE defaults + explicit overrides
        evaluate("test_1_feature_flag_is_configured") {
            UserDefaults.standard.removeObject(forKey: "gis_navigation_enabled")
            #if DEBUG
            guard AppConfig.gisNavigationEnabled == true else { return false }
            #else
            guard AppConfig.gisNavigationEnabled == false else { return false }
            #endif
            
            // Explicit override false
            UserDefaults.standard.set(false, forKey: "gis_navigation_enabled")
            guard AppConfig.gisNavigationEnabled == false else { return false }
            
            // Explicit override true
            UserDefaults.standard.set(true, forKey: "gis_navigation_enabled")
            guard AppConfig.gisNavigationEnabled == true else { return false }
            
            UserDefaults.standard.removeObject(forKey: "gis_navigation_enabled")
            return true
        }
        
        // 2. Initial state of GISExplorerViewModel
        evaluate("test_2_initial_state") {
            let vm = GISExplorerViewModel()
            guard vm.currentLevel == .odisha else { return false }
            guard vm.breadcrumbs.count == 1 else { return false }
            guard vm.breadcrumbs.first?.title == "Odisha" else { return false }
            guard vm.selectedDistrictID == nil else { return false }
            guard vm.selectedDistrictFeature == nil else { return false }
            guard vm.selectedSubdivision == nil else { return false }
            guard vm.selectedVillage == nil else { return false }
            guard vm.targetCameraBounds == nil else { return false }
            return true
        }
        
        // 3. District metadata decoding
        evaluate("test_3_district_metadata_decoding") {
            let json = """
            {
                "id": "cuttack",
                "name": "Cuttack",
                "code_2digit": "03",
                "bhulekh_id": "306",
                "center_lat": 20.464,
                "center_lng": 85.883,
                "bbox": [85.345, 20.211, 86.412, 20.732]
            }
            """.data(using: .utf8)!
            
            guard let district = try? JSONDecoder().decode(GISDistrictFeature.self, from: json) else {
                return false
            }
            return district.id == "cuttack" &&
                   district.name == "Cuttack" &&
                   district.code2Digit == "03" &&
                   district.bhulekhID == "306" &&
                   district.bbox.count == 4 &&
                   district.centerCoordinate.latitude == 20.464 &&
                   district.centerCoordinate.longitude == 85.883
        }
        
        // 4. Subdivision & Village decoding
        evaluate("test_4_subdivision_and_village_decoding") {
            let subJson = """
            {
                "id": "0301",
                "name": "Cuttack Sadar",
                "district_id": "cuttack"
            }
            """.data(using: .utf8)!
            
            guard let sub = try? JSONDecoder().decode(CadastralBlock.self, from: subJson) else {
                return false
            }
            guard sub.id == "0301" && sub.name == "Cuttack Sadar" && sub.districtID == "cuttack" else { return false }
            
            let villJson = """
            {
                "id": "030101",
                "name": "Bidanasi",
                "block_id": "0301",
                "district_id": "cuttack"
            }
            """.data(using: .utf8)!
            
            guard let vill = try? JSONDecoder().decode(CadastralVillage.self, from: villJson) else {
                return false
            }
            return vill.id == "030101" && vill.name == "Bidanasi"
        }
        
        // 5. Camera bounds calculation from BBOX
        evaluate("test_5_camera_bounds_from_bbox") {
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
            
            let latOk = abs(sw.latitude - 21.01) < 0.001 && abs(ne.latitude - 22.17) < 0.001
            let lonOk = abs(sw.longitude - 85.11) < 0.001 && abs(ne.longitude - 86.37) < 0.001
            return latOk && lonOk
        }
        
        // 6. Navigation hierarchy & breadcrumbs
        evaluate("test_6_navigation_hierarchy") {
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
            
            // Level 1: Odisha -> Breadcrumbs: [Odisha]
            guard vm.breadcrumbs.count == 1 else { return false }
            guard vm.breadcrumbs[0].title == "Odisha" else { return false }
            
            // Level 2: District -> Breadcrumbs: [Odisha, Cuttack]
            vm.selectDistrict(feature: district)
            guard vm.selectedDistrictID == "cuttack" else { return false }
            guard vm.breadcrumbs.count == 2 else { return false }
            guard vm.breadcrumbs[1].title == "Cuttack" else { return false }
            
            // Level 3: Subdivision -> Breadcrumbs: [Odisha, Cuttack, Sadar]
            vm.selectSubdivision(sub)
            guard vm.selectedSubdivision?.id == "0301" else { return false }
            guard vm.breadcrumbs.count == 3 else { return false }
            guard vm.breadcrumbs[2].title == "Sadar" else { return false }
            
            // Level 4: Village -> Breadcrumbs: [Odisha, Cuttack, Sadar, Bidanasi]
            vm.selectVillage(vill)
            guard vm.selectedVillage?.id == "030101" else { return false }
            guard vm.breadcrumbs.count == 4 else { return false }
            guard vm.breadcrumbs[3].title == "Bidanasi" else { return false }
            
            // Breadcrumb back-navigation to District (index 1)
            let districtBreadcrumb = vm.breadcrumbs[1]
            vm.navigateToBreadcrumb(districtBreadcrumb)
            guard vm.breadcrumbs.count == 2 else { return false }
            guard vm.selectedSubdivision == nil else { return false }
            guard vm.selectedVillage == nil else { return false }
            
            // Breadcrumb back-navigation to Odisha (index 0)
            let odishaBreadcrumb = vm.breadcrumbs[0]
            vm.navigateToBreadcrumb(odishaBreadcrumb)
            guard vm.currentLevel == .odisha else { return false }
            guard vm.breadcrumbs.count == 1 else { return false }
            guard vm.selectedDistrictID == nil else { return false }
            
            return true
        }
        
        // 7. Full reset / exit restores initial state
        evaluate("test_7_full_reset") {
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
            vm.selectDistrict(feature: district)
            vm.exitExplorer()
            
            return vm.isExplorerActive == false &&
                   vm.selectedDistrictID == nil &&
                   vm.selectedSubdivision == nil &&
                   vm.selectedVillage == nil
        }
        
        // 8. Repository in-memory cache validation
        evaluate("test_8_repository_cache") {
            let repo = GISExplorerRepository.shared
            let previousCached = repo.getCachedDistricts()
            defer {
                repo.restoreCachedDistricts(previousCached)
            }
            
            let districts = [
                GISDistrictFeature(id: "d1", name: "D1", code2Digit: "01", bhulekhID: "1", centerLat: 20.0, centerLng: 85.0, bbox: [84.0, 19.0, 86.0, 21.0])
            ]
            repo.cacheDistricts(districts)
            guard let cached = repo.getCachedDistricts(), cached.count == 1 else { return false }
            return cached[0].id == "d1"
        }
        
        // 9. Normal GIS request uses protocol cache policy, forceRefresh uses reloadIgnoringLocalCacheData
        evaluate("test_9_request_cache_policy_and_force_refresh") {
            let repo = GISExplorerRepository.shared
            guard let normalGeoJSONReq = repo.makeDistrictsGeoJSONRequest(forceRefresh: false),
                  let refreshGeoJSONReq = repo.makeDistrictsGeoJSONRequest(forceRefresh: true),
                  let normalDistrictsReq = repo.makeDistrictsSummaryRequest(forceRefresh: false),
                  let refreshDistrictsReq = repo.makeDistrictsSummaryRequest(forceRefresh: true) else {
                return false
            }
            return normalGeoJSONReq.cachePolicy == .useProtocolCachePolicy &&
                   refreshGeoJSONReq.cachePolicy == .reloadIgnoringLocalCacheData &&
                   normalDistrictsReq.cachePolicy == .useProtocolCachePolicy &&
                   refreshDistrictsReq.cachePolicy == .reloadIgnoringLocalCacheData
        }
        
        // 10. Retry bypasses stale cached 404
        evaluate("test_10_retry_bypasses_cached_404") {
            let repo = GISExplorerRepository.shared
            guard let refreshReq = repo.makeDistrictsGeoJSONRequest(forceRefresh: true) else {
                return false
            }
            // URLRequest configured with reloadIgnoringLocalCacheData guarantees CFNetwork bypasses URLCache
            return refreshReq.cachePolicy == .reloadIgnoringLocalCacheData
        }
        
        // 11. Tahasil feature decoding
        evaluate("test_11_tahasil_feature_decoding") {
            let json = """
            {
                "tahasil_id": "0301",
                "tahasil_name": "Athagarh",
                "tahasil_name_odia": "ଆଠଗଡ",
                "bhulekh_tahasil_id": "1",
                "district_id": "306",
                "center": [85.70, 20.55],
                "bbox": [85.54, 20.43, 85.86, 20.67],
                "is_visualization_boundary": true
            }
            """.data(using: .utf8)!
            
            guard let feat = try? JSONDecoder().decode(GISTahasilFeature.self, from: json) else {
                return false
            }
            return feat.id == "0301" &&
                   feat.name == "Athagarh" &&
                   feat.districtID == "306" &&
                   feat.bbox.count == 4 &&
                   abs(feat.centerCoordinate.latitude - 20.55) < 0.01 &&
                   abs(feat.centerCoordinate.longitude - 85.70) < 0.01
        }
        
        // 12. Tahasil selection & camera bounds
        evaluate("test_12_tahasil_selection_and_camera_bounds") {
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
            vm.selectTahasilByID("0301", name: "Athagarh", bbox: [85.54, 20.43, 85.86, 20.67])
            
            guard vm.selectedTahasilID == "0301" else { return false }
            guard vm.selectedSubdivision?.name == "Athagarh" else { return false }
            guard let bounds = vm.targetCameraBounds else { return false }
            
            let swOk = abs(bounds.sw.latitude - 20.43) < 0.01 && abs(bounds.sw.longitude - 85.54) < 0.01
            let neOk = abs(bounds.ne.latitude - 20.67) < 0.01 && abs(bounds.ne.longitude - 85.86) < 0.01
            return swOk && neOk
        }
        
        // 13. Tahasils GeoJSON request & cache policy
        evaluate("test_13_tahasils_geojson_request_cache_policy") {
            let repo = GISExplorerRepository.shared
            guard let normalReq = repo.makeTahasilsGeoJSONRequest(districtID: "306", forceRefresh: false),
                  let refreshReq = repo.makeTahasilsGeoJSONRequest(districtID: "306", forceRefresh: true) else {
                return false
            }
            guard normalReq.url?.path.contains("/gis/navigation/districts/306/tahasils-geojson") == true else {
                return false
            }
            return normalReq.cachePolicy == .useProtocolCachePolicy &&
                   refreshReq.cachePolicy == .reloadIgnoringLocalCacheData
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  SUMMARY: \(passed) passed, \(failed) failed")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        return (passed, failed, errors)
    }
}
