//
//  UPMapPrototypeTests.swift
//  MyBhoomiTests
//
//  Contract tests for the Uttar Pradesh map prototype models and fail-safe
//  remote config decoding. Network/provider behavior is covered by backend tests.
//

import XCTest
@testable import MyBhoomi

final class UPMapPrototypeTests: XCTestCase {

    func test_old_remote_config_without_up_flag_still_decodes() throws {
        let json = """
        {
          "min_supported_version":"1.0.0",
          "latest_version":"1.0.0",
          "maintenance_mode":false,
          "subscription_enabled":true,
          "premium_enabled":true,
          "map_data_version":"2026-08-18",
          "features":{
            "advanced_search":true,
            "property_history":false,
            "valuation":false,
            "pdf_download":true,
            "satellite_view":true
          },
          "paywall":{
            "headline":"Test",
            "subheadline":"Test",
            "default_tier":"test",
            "available_tiers":[]
          }
        }
        """
        let config = try JSONDecoder().decode(RemoteAppConfig.self, from: Data(json.utf8))
        XCTAssertNil(config.upMapEnabled)
    }

    func test_plot_model_ignores_any_unknown_owner_fields() throws {
        let json = """
        {
          "gis_code":"15900830145758",
          "plot_no":"522",
          "plot_id":"safe_id",
          "bbox":[79.37,27.47,79.371,27.471],
          "records":[{"khata_no":"00007","plot_no":"522/2","area":0.162,"area_unit":"Hectare","owner_name":"Never retain this"}],
          "owner_details":"Never retain this",
          "official_record_url":"https://upbhulekh.gov.in/",
          "note":"Map view (beta)"
        }
        """
        let plot = try JSONDecoder().decode(UPPlotResult.self, from: Data(json.utf8))
        XCTAssertEqual(plot.plotNo, "522")
        XCTAssertEqual(plot.records.first?.khataNo, "00007")
        let reencoded = String(data: try JSONEncoder().encode(plot), encoding: .utf8) ?? ""
        XCTAssertFalse(reencoded.contains("owner"))
        XCTAssertFalse(reencoded.contains("Never retain this"))
    }

    func test_village_fitting_zoom_is_bounded() {
        func session(_ bbox: [Double]) -> UPVillageSession {
            UPVillageSession(
                extent: UPVillageExtent(
                    gisCode: "15900830145758", districtCode: "159", tehsilCode: "00830",
                    villageCode: "145758", crs: "EPSG:32644", bbox: bbox,
                    centerLat: 27.47, centerLng: 79.37),
                districtName: "District", tehsilName: "Tehsil", villageName: "Village")
        }
        XCTAssertEqual(session([79, 27, 89, 37]).fittingZoom, 13.5)
        XCTAssertEqual(session([79.36999, 27.46999, 79.37001, 27.47001]).fittingZoom, 17.5)
        XCTAssertTrue((13.5...17.5).contains(session([79.35, 27.45, 79.39, 27.49]).fittingZoom))
    }

    func test_tile_template_uses_our_backend_and_maplibre_bbox_token() {
        let template = UPMapService.shared.tileURLTemplate(gisCode: "15900830145758")
        XCTAssertTrue(template.contains("/api/v1/gis/up/wms/base/15900830145758"))
        XCTAssertTrue(template.contains("{bbox-epsg-3857}"))
        XCTAssertFalse(template.contains("upbhunaksha.gov.in"))
    }

    private func plot(token: String?) -> UPPlotResult {
        UPPlotResult(gisCode: "15900830145758", plotNo: "454", plotId: "dSRjxTJlScGZtXq4tn32og",
                     bbox: [79.3698, 27.4698, 79.3720, 27.4721], selectionToken: token)
    }

    func test_selection_template_uses_signed_token_not_raw_plot_id() throws {
        let token = "v1.1790635385.15900830145758.dSRjxTJlScGZtXq4tn32og.AbC_-0123456789abcdefghijklmnopqrstuvwxyzAB"
        let template = try XCTUnwrap(UPMapService.shared.selectionTileURLTemplate(for: plot(token: token)))
        XCTAssertTrue(template.contains("/api/v1/gis/up/wms/selection/\(token)?"))
        XCTAssertTrue(template.contains("{bbox-epsg-3857}"))
        XCTAssertFalse(template.contains("plot_id="))
        XCTAssertFalse(template.contains("upbhunaksha.gov.in"))
    }

    func test_selection_template_rejects_missing_or_unsafe_token() {
        XCTAssertNil(UPMapService.shared.selectionTileURLTemplate(for: plot(token: nil)))
        XCTAssertNil(UPMapService.shared.selectionTileURLTemplate(for: plot(token: "")))
        XCTAssertNil(UPMapService.shared.selectionTileURLTemplate(for: plot(token: "v1.1/../../x")))
        XCTAssertNil(UPMapService.shared.selectionTileURLTemplate(for: plot(token: "v1.1?bbox=x")))
        XCTAssertNil(UPMapService.shared.selectionTileURLTemplate(for: plot(token: "v1.१२३")))
    }

    func test_plot_decodes_selection_token() throws {
        let json = """
        {"gis_code":"15900830145758","plot_no":"454","plot_id":"abc","bbox":[1,2,3,4],
         "records":[],"selection_token":"v1.1.2.abc.sig"}
        """
        let decoded = try JSONDecoder().decode(UPPlotResult.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.selectionToken, "v1.1.2.abc.sig")
    }

    @MainActor
    func test_switching_up_villages_keeps_original_odisha_return_state() {
        let vm = MapViewModel()
        UserDefaults.standard.set(true, forKey: UPFeature.debugOverrideKey)
        defer { UserDefaults.standard.removeObject(forKey: UPFeature.debugOverrideKey) }
        vm.zoomLevel = 12.25
        func session(_ gis: String, _ name: String) -> UPVillageSession {
            UPVillageSession(
                extent: UPVillageExtent(gisCode: gis, districtCode: "159", tehsilCode: "00830",
                                        villageCode: "145758", crs: "EPSG:32644",
                                        bbox: [79.35, 27.45, 79.39, 27.49], centerLat: 27.47, centerLng: 79.37),
                districtName: "D", tehsilName: "T", villageName: name)
        }
        vm.enterUP(session("15900830145758", "A"))
        let savedZoom = vm.upReturnZoom
        vm.enterUP(session("15900830145759", "B"))
        XCTAssertEqual(vm.upReturnZoom, savedZoom)
        XCTAssertEqual(savedZoom, 12.25)
        XCTAssertEqual(vm.upSession?.villageName, "B")
        XCTAssertNil(vm.selectedUPPlot)
        XCTAssertFalse(vm.isUPIdentifying)
    }
}
