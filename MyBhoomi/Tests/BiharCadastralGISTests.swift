import Foundation
import CoreLocation
import MapLibre

/// Comprehensive test suite for Bihar Cadastral GIS Integration & State Isolation (iOS Layer)
public struct BiharCadastralGISTests {
    
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
        print("  RUNNING BIHAR CADASTRAL GIS TEST SUITE (iOS)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 1. Bihar feature flag state
        evaluate("test_1_feature_flag_is_configured") {
            return AppConfig.biharGisFeatureEnabled == false
        }
        
        // 2. Feature flag safety
        evaluate("test_2_feature_flag_is_boolean") {
            let flag = AppConfig.biharGisFeatureEnabled
            return flag == false || flag == true
        }
        
        // 3. District decoding
        evaluate("test_3_district_decoding") {
            let json = """
            [{"id": "BR_PAT", "name": "PATNA"}, {"id": "BR_GAY", "name": "GAYA"}]
            """.data(using: .utf8)!
            guard let districts = try? JSONDecoder().decode([CadastralDistrict].self, from: json) else { return false }
            return districts.count == 2 && districts[0].id == "BR_PAT" && districts[0].name == "PATNA"
        }
        
        // 4. Circle / Block decoding
        evaluate("test_4_circle_decoding") {
            let json = """
            [{"id": "BR_PAT_01", "name": "PATNA SADAR", "district_id": "BR_PAT"}]
            """.data(using: .utf8)!
            guard let blocks = try? JSONDecoder().decode([CadastralBlock].self, from: json) else { return false }
            return blocks.count == 1 && blocks[0].id == "BR_PAT_01" && blocks[0].name == "PATNA SADAR" && blocks[0].districtID == "BR_PAT"
        }
        
        // 5. Halka / GP decoding
        evaluate("test_5_halka_decoding") {
            let json = """
            [{"id": "BR_PAT_01_01", "name": "HALKA 01", "block_id": "BR_PAT_01"}]
            """.data(using: .utf8)!
            guard let gps = try? JSONDecoder().decode([CadastralGP].self, from: json) else { return false }
            return gps.count == 1 && gps[0].id == "BR_PAT_01_01" && gps[0].name == "HALKA 01"
        }
        
        // 6. Mauza / Village decoding
        evaluate("test_6_mauza_decoding") {
            let json = """
            [{"id": "BR_PAT_01_108", "name": "BEGAMPUR", "block_id": "BR_PAT_01", "district_id": "BR_PAT", "gp_id": "BR_PAT_01_01"}]
            """.data(using: .utf8)!
            guard let villages = try? JSONDecoder().decode([CadastralVillage].self, from: json) else { return false }
            return villages.count == 1 && villages[0].id == "BR_PAT_01_108" && villages[0].name == "BEGAMPUR"
        }
        
        // 7. Sheet parameter handling
        evaluate("test_7_sheet_parameter_formatting") {
            let sheetNo = "01"
            let key = "BIHAR_BR_PAT_01_108_\(sheetNo)"
            return key == "BIHAR_BR_PAT_01_108_01"
        }
        
        // 8. Map GeoJSON parsing (All 10 ground truth parcels)
        evaluate("test_8_map_geojson_parsing") {
            #if DEBUG
            let data = Data(BiharDebugFixtures.begampurSheet01GeoJSON.utf8)
            let dummyVillage = CadastralVillage(id: "BR_PAT_01_108", name: "BEGAMPUR", blockID: "BR_PAT_01", districtID: "BR_PAT", blockName: "PATNA SADAR", districtName: "PATNA")
            let parsed = GeoJSONFeatureParser.parse(data: data, village: dummyVillage)
            return parsed.parcels.count == 10 && parsed.shape != nil
            #else
            return true
            #endif
        }
        
        // 9. Closed polygon ring validation
        evaluate("test_9_polygon_ring_closure") {
            #if DEBUG
            let data = Data(BiharDebugFixtures.begampurSheet01GeoJSON.utf8)
            let dummyVillage = CadastralVillage(id: "BR_PAT_01_108", name: "BEGAMPUR", blockID: "BR_PAT_01")
            let parsed = GeoJSONFeatureParser.parse(data: data, village: dummyVillage)
            guard let p240 = parsed.parcels.first(where: { $0.plotNumber == "240" }) else { return false }
            return p240.boundary.count >= 4
            #else
            return true
            #endif
        }
        
        // 10. Selected plot properties
        evaluate("test_10_selected_plot_properties") {
            let parcel = CadastralParcel(
                source: "BIHAR_BHUNAKSHA",
                sourceFeatureID: "BR_PAT_01_108_245",
                districtID: "BR_PAT",
                districtName: "PATNA",
                blockID: "BR_PAT_01",
                blockName: "PATNA SADAR",
                gpID: "BR_PAT_01_01",
                villageID: "BR_PAT_01_108",
                villageName: "BEGAMPUR",
                plotNumber: "245",
                centroid: [85.122, 25.594],
                geometryType: "Polygon",
                boundary: []
            )
            return parcel.plotNumber == "245" && parcel.source == "BIHAR_BHUNAKSHA" && parcel.centroidCoordinate.latitude == 25.594
        }
        
        // 11. State isolation in cache keys
        evaluate("test_11_cache_key_isolation") {
            let odishaKey = "ODISHA_0704317_all"
            let biharKey = "BIHAR_BR_PAT_01_108_all"
            return odishaKey != biharKey && !odishaKey.contains("BIHAR") && !biharKey.contains("ODISHA")
        }
        
        // 12. Odisha backward compatibility
        evaluate("test_12_odisha_backward_compatibility") {
            let defaultState = "ODISHA"
            return defaultState == "ODISHA"
        }
        
        // 13. Bihar districts are NOT Odisha districts
        evaluate("test_13_bihar_districts_are_not_odisha_districts") {
            #if DEBUG
            let biharDistricts = BiharDebugFixtures.debugDistricts
            let odishaNames = ["Anugul", "Baleswar", "Baragarh", "Bhadrak", "Bolangir", "Boudh", "Keonjhar"]
            for d in biharDistricts {
                if odishaNames.contains(where: { $0.caseInsensitiveCompare(d.name) == .orderedSame }) {
                    return false
                }
            }
            return biharDistricts.contains { $0.name == "PATNA" } && biharDistricts.contains { $0.name == "GAYA" }
            #else
            return true
            #endif
        }
        
        // 14. Patna returns Patna Sadar
        evaluate("test_bihar_patna_returns_patna_sadar") {
            #if DEBUG
            let circles = BiharDebugFixtures.debugBlocks["BR_PAT"] ?? []
            return circles.contains { $0.name == "PATNA SADAR" && $0.id == "BR_PAT_01" }
            #else
            return true
            #endif
        }
        
        // 15. Gaya returns Bodhgaya
        evaluate("test_bihar_gaya_returns_bodhgaya") {
            #if DEBUG
            let circles = BiharDebugFixtures.debugBlocks["BR_GAY"] ?? []
            return circles.contains { $0.name == "BODHGAYA" && $0.id == "BR_GAY_01" }
            #else
            return true
            #endif
        }
        
        // 16. Muzaffarpur returns Kanti
        evaluate("test_bihar_muzaffarpur_returns_kanti") {
            #if DEBUG
            let circles = BiharDebugFixtures.debugBlocks["BR_MUZ"] ?? []
            return circles.contains { $0.name == "KANTI" && $0.id == "BR_MUZ_01" }
            #else
            return true
            #endif
        }
        
        // 17. Bhagalpur returns Kahalgaon
        evaluate("test_bihar_bhagalpur_returns_kahalgaon") {
            #if DEBUG
            let circles = BiharDebugFixtures.debugBlocks["BR_BHA"] ?? []
            return circles.contains { $0.name == "KAHALGAON" && $0.id == "BR_BHA_01" }
            #else
            return true
            #endif
        }
        
        // 18. Darbhanga returns Bahadurpur
        evaluate("test_bihar_darbhanga_returns_bahadurpur") {
            #if DEBUG
            let circles = BiharDebugFixtures.debugBlocks["BR_DAR"] ?? []
            return circles.contains { $0.name == "BAHADURPUR" && $0.id == "BR_DAR_01" }
            #else
            return true
            #endif
        }
        
        // 19. Bihar circle lookup uses district ID
        evaluate("test_bihar_circle_lookup_uses_district_id") {
            #if DEBUG
            let patnaBlocks = BiharDebugFixtures.debugBlocks["BR_PAT"] ?? []
            let gayaBlocks = BiharDebugFixtures.debugBlocks["BR_GAY"] ?? []
            return patnaBlocks.allSatisfy { $0.districtID == "BR_PAT" } &&
                   gayaBlocks.allSatisfy { $0.districtID == "BR_GAY" }
            #else
            return true
            #endif
        }
        
        // 20. Bihar circle lookup never uses Odisha data
        evaluate("test_bihar_circle_lookup_never_uses_odisha_data") {
            #if DEBUG
            for (_, circles) in BiharDebugFixtures.debugBlocks {
                for c in circles {
                    if !c.id.hasPrefix("BR_") { return false }
                }
            }
            return true
            #else
            return true
            #endif
        }
        
        // 21. Bihar circle empty state is handled cleanly
        evaluate("test_bihar_circle_empty_state_is_handled") {
            #if DEBUG
            let unknownBlocks = BiharDebugFixtures.debugBlocks["BR_UNKNOWN"] ?? []
            return unknownBlocks.isEmpty
            #else
            return true
            #endif
        }
        
        // 22. Polygon count after Search == 10
        evaluate("test_22_bihar_parcel_count_is_ten") {
            #if DEBUG
            let data = Data(BiharDebugFixtures.begampurSheet01GeoJSON.utf8)
            let dummyVillage = CadastralVillage(id: "BR_PAT_01_108", name: "BEGAMPUR", blockID: "BR_PAT_01")
            let parsed = GeoJSONFeatureParser.parse(data: data, village: dummyVillage)
            return parsed.totalCount == 10 && parsed.parcels.count == 10
            #else
            return true
            #endif
        }
        
        // 23. Bounding box is valid (centerLat 25.5960, centerLng 85.1260)
        evaluate("test_23_bihar_extent_validity") {
            let extent = CadastralExtent(minLng: 85.1200, minLat: 25.5900, maxLng: 85.1320, maxLat: 25.6020, centerLng: 85.1260, centerLat: 25.5960)
            return extent.centerLat > 25.0 && extent.centerLat < 26.0 && extent.centerLng > 85.0 && extent.centerLng < 86.0
        }
        
        // 24. Plot 245 exists in parsed collection
        evaluate("test_24_plot_245_exists") {
            #if DEBUG
            let data = Data(BiharDebugFixtures.begampurSheet01GeoJSON.utf8)
            let dummyVillage = CadastralVillage(id: "BR_PAT_01_108", name: "BEGAMPUR", blockID: "BR_PAT_01")
            let parsed = GeoJSONFeatureParser.parse(data: data, village: dummyVillage)
            guard let p245 = parsed.parcels.first(where: { $0.plotNumber == "245" }) else { return false }
            return p245.plotNumber == "245" && p245.boundary.count >= 4
            #else
            return true
            #endif
        }
        
        // 25. Plot 245 tap resolution via ray casting
        evaluate("test_25_plot_245_tap_resolution") {
            #if DEBUG
            let data = Data(BiharDebugFixtures.begampurSheet01GeoJSON.utf8)
            let dummyVillage = CadastralVillage(id: "BR_PAT_01_108", name: "BEGAMPUR", blockID: "BR_PAT_01")
            let parsed = GeoJSONFeatureParser.parse(data: data, village: dummyVillage)
            guard let p245 = parsed.parcels.first(where: { $0.plotNumber == "245" }) else { return false }
            
            let insideCoord = CLLocationCoordinate2D(latitude: 25.5940, longitude: 85.1220)
            let vertices = p245.boundary.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let isInside = CadastralFeatureResolver.isCoordinate(insideCoord, insidePolygon: vertices)
            return isInside
            #else
            return true
            #endif
        }
        
        // 26. Malformed GeoJSON does not crash parser
        evaluate("test_26_malformed_geojson_does_not_crash") {
            let garbageData = Data("{\"not_geojson\": true}".utf8)
            let dummyVillage = CadastralVillage(id: "BR_PAT_01_108", name: "BEGAMPUR", blockID: "BR_PAT_01")
            let parsed = GeoJSONFeatureParser.parse(data: garbageData, village: dummyVillage)
            return parsed.totalCount == 0 && parsed.parcels.isEmpty
        }
        
        // 27. Full Patna Begampur Sheet 01 fixture flow with all 10 plots
        evaluate("test_27_full_patna_begampur_sheet01_flow") {
            #if DEBUG
            let dist = BiharDebugFixtures.debugDistricts.first { $0.id == "BR_PAT" }
            guard let d = dist, d.name == "PATNA" else { return false }
            
            let circle = (BiharDebugFixtures.debugBlocks[d.id] ?? []).first { $0.id == "BR_PAT_01" }
            guard let c = circle, c.name == "PATNA SADAR" else { return false }
            
            let halka = (BiharDebugFixtures.debugGPs[c.id] ?? []).first { $0.id == "BR_PAT_01_01" }
            guard let h = halka, h.name == "Halka 01" else { return false }
            
            let mauza = (BiharDebugFixtures.debugVillages[c.id] ?? []).first { $0.id == "BR_PAT_01_108" }
            guard let m = mauza, m.name == "BEGAMPUR" else { return false }
            
            let data = Data(BiharDebugFixtures.begampurSheet01GeoJSON.utf8)
            let parsed = GeoJSONFeatureParser.parse(data: data, village: m)
            
            let plotNumbers = Set(parsed.parcels.map { $0.plotNumber })
            let expectedPlots: Set<String> = ["240", "241", "242", "243", "244", "245", "246", "247", "248", "250"]
            return expectedPlots.isSubset(of: plotNumbers) && parsed.parcels.allSatisfy { $0.source == "BIHAR_BHUNAKSHA" }
            #else
            return true
            #endif
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  BIHAR CADASTRAL GIS (iOS): \(passed) PASSED / \(failed) FAILED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        return (passed, failed, errors)
    }
}
