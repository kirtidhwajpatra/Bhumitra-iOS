import SwiftUI
import XCTest
import MapLibre
@testable import MyBhoomi

@MainActor
final class CadastralParcelLoadingPerformanceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        APIConfiguration.shared.switchToAWSBackend()
    }

    func test_measure_real_village_parcel_loading_breakdown() async throws {
        let repo = CadastralRepository.shared
        let village = CadastralVillage(
            id: "0706003",
            name: "Badajamuposi",
            gpID: "07060005",
            blockID: "0706",
            districtID: "224",
            blockName: "Ghatagaon",
            districtName: "Kendujhar"
        )
        
        // 1. Measure Extent fetch alone
        let t0 = CFAbsoluteTimeGetCurrent()
        let extent = try await repo.getVillageExtent(village: village, state: "ODISHA")
        let tExtent = CFAbsoluteTimeGetCurrent() - t0
        print("[BREAKDOWN] Extent fetch time: \(String(format: "%.3f", tExtent))s (Center: \(extent.centerLat), \(extent.centerLng))")
        
        // 2. Measure Raw Parcels fetch
        let t1 = CFAbsoluteTimeGetCurrent()
        let rawData = try await CadastralAPIClient.shared.fetchVillageParcelsRawGeoJSON(
            villageID: village.id,
            districtName: village.districtName,
            blockName: village.blockName,
            gpName: village.gpID,
            villageName: village.name,
            sheetNo: nil,
            state: "ODISHA"
        )
        let tRaw = CFAbsoluteTimeGetCurrent() - t1
        print("[BREAKDOWN] Raw GeoJSON fetch time: \(String(format: "%.3f", tRaw))s (Bytes: \(rawData.count))")
        
        // 3. Measure GeoJSON Feature Parsing alone
        let t2 = CFAbsoluteTimeGetCurrent()
        let parsed = GeoJSONFeatureParser.parse(data: rawData, village: village)
        let tParse = CFAbsoluteTimeGetCurrent() - t2
        print("[BREAKDOWN] GeoJSONFeatureParser time: \(String(format: "%.3f", tParse))s (Parcels: \(parsed.totalCount))")
        
        // 4. Measure MapLibre MLNShapeSource installation
        let t3 = CFAbsoluteTimeGetCurrent()
        let sourceID = "cadastral-parcels-source"
        let source = MLNShapeSource(identifier: sourceID, shape: parsed.shape, options: nil)
        let tSource = CFAbsoluteTimeGetCurrent() - t3
        print("[BREAKDOWN] MLNShapeSource creation time: \(String(format: "%.3f", tSource))s")
        
        XCTAssertEqual(parsed.totalCount, 2087)
    }
}
