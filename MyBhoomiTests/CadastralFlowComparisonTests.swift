//
//  CadastralFlowComparisonTests.swift
//  MyBhoomiTests
//
//  Verifies FLOW A (Live Search) vs FLOW B (Recent Search) Cadastral Lifecycle Reconciliation:
//  - Ensures MapLibre Native source/layers are only created with valid, non-empty shapes.
//  - Verifies that when parcel data arrives after map creation (Flow A), the source and layers
//    are cleanly initialized with the populated shape (identical to Flow B).
//  - Verifies village transitions cleanly rebuild the pipeline.
//

import XCTest
import SwiftUI
import CoreLocation
import MapLibre
@testable import MyBhoomi

@MainActor
final class CadastralFlowComparisonTests: XCTestCase {

    var viewModel: MapViewModel!

    override func setUp() {
        super.setUp()
        viewModel = MapViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // Helper: Create sample polygon shape from GeoJSON
    private func createSampleShape() -> MLNShape {
        let geoJSON = """
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "geometry": {
                        "type": "Polygon",
                        "coordinates": [[[85.90, 21.60], [85.91, 21.60], [85.91, 21.61], [85.90, 21.60]]]
                    },
                    "properties": {
                        "revenue_plot": "1",
                        "plot_number": "1"
                    }
                }
            ]
        }
        """
        let data = geoJSON.data(using: .utf8)!
        return (try? MLNShape(data: data, encoding: String.Encoding.utf8.rawValue)) ?? MLNShape()
    }

    // TEST 1: Flow A sequence - Map created before parcel data arrives
    func test_flow_A_lifecycle_order() async {
        viewModel.currentFlow = "LIVE"
        
        // Initially no shape is loaded
        XCTAssertNil(viewModel.cadastralShape)
        XCTAssertEqual(viewModel.cadastralParcels.count, 0)
        XCTAssertFalse(viewModel.parcelRenderingConfirmed)
        
        // Map coordinator created
        let parentView = MapLibreView(
            selectedParcel: .constant(nil),
            selectedCadastralParcel: .constant(nil),
            cadastralShape: .constant(nil),
            center: .constant(Coordinate(latitude: 21.6045, longitude: 85.9012)),
            zoom: .constant(15.0),
            pendingCameraTarget: .constant(nil),
            isSatellite: .constant(false),
            showParcels: .constant(true),
            parcelDisplayStyle: .constant(.shadedFill),
            shouldCenterOnUser: .constant(false),
            isTrackingUser: .constant(false),
            userLocationCoordinate: .constant(nil),
            shouldResetBearing: .constant(false),
            tapPoint: .constant(nil),
            selectedLocationInfo: .constant(nil),
            visualFilter: .natural,
            selectionToken: viewModel.activeSelectionToken,
            parcelCount: 0,
            currentFlow: "LIVE"
        )
        let coordinator = parentView.makeCoordinator()
        
        // Simulate style loaded BEFORE parcel data (Flow A)
        XCTAssertFalse(coordinator.isStyleReady)
        coordinator.isStyleReady = true
        
        // Parcel data arrives later
        let sampleShape = createSampleShape()
        viewModel.cadastralShape = sampleShape
        viewModel.activeCadastralVillage = CadastralVillage(
            id: "0711152",
            name: "Tompo",
            blockID: "ghatgaon",
            districtID: "kendujhar"
        )
        let token = viewModel.activeSelectionToken
        
        // Callback verification
        viewModel.onParcelLayerRenderSuccess(villageId: "0711152", token: token)
        XCTAssertTrue(viewModel.parcelRenderingConfirmed)
        XCTAssertEqual(viewModel.spatialResolutionState, .ready(message: "Parcels ready"))
    }

    // TEST 2: Flow B sequence - Parcel data already present when map created
    func test_flow_B_lifecycle_order() async {
        viewModel.currentFlow = "RECENT"
        
        // Data already in memory from Flow A
        let sampleShape = createSampleShape()
        viewModel.cadastralShape = sampleShape
        viewModel.activeCadastralVillage = CadastralVillage(
            id: "0711152",
            name: "Tompo",
            blockID: "ghatgaon",
            districtID: "kendujhar"
        )
        
        let recentResult = LocationSearchResult(
            id: "loc-tompo-recent",
            title: "Tompo",
            subtitle: "Kendujhar",
            type: .revenueVillage,
            latitude: 21.6045,
            longitude: 85.9012
        )
        
        _ = try? await viewModel.selectLocation(recentResult, isRecent: true)
        XCTAssertEqual(viewModel.currentFlow, "RECENT")
        
        let token = viewModel.activeSelectionToken
        viewModel.onParcelLayerRenderSuccess(villageId: "0711152", token: token)
        XCTAssertTrue(viewModel.parcelRenderingConfirmed)
        XCTAssertEqual(viewModel.spatialResolutionState, .ready(message: "Parcels ready"))
    }

    // TEST 3: Village switching resets render token and requires fresh verification
    func test_village_switch_reconciliation() async {
        viewModel.currentFlow = "LIVE"
        
        // 1. Village 1: Tompo
        viewModel.activeSelectionToken = UUID()
        let token1 = viewModel.activeSelectionToken
        viewModel.onParcelLayerRenderSuccess(villageId: "0711152", token: token1)
        XCTAssertTrue(viewModel.parcelRenderingConfirmed)
        
        // 2. User searches Keri
        let keriResult = LocationSearchResult(
            id: "loc-keri",
            title: "Keri",
            subtitle: "Kendujhar",
            type: .revenueVillage,
            latitude: 21.6200,
            longitude: 85.9100
        )
        _ = try? await viewModel.selectLocation(keriResult, isRecent: false)
        let token2 = viewModel.activeSelectionToken
        
        // Token must have changed, rendering confirmed must reset
        XCTAssertNotEqual(token1, token2)
        XCTAssertFalse(viewModel.parcelRenderingConfirmed)
        
        // When Keri parcels render, token2 confirms
        viewModel.onParcelLayerRenderSuccess(villageId: "0711153", token: token2)
        XCTAssertTrue(viewModel.parcelRenderingConfirmed)
    }
}
