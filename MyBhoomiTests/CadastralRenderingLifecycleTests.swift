//
//  CadastralRenderingLifecycleTests.swift
//  MyBhoomiTests
//
//  Verifies the event-driven MapLibre Cadastral Rendering Lifecycle:
//  1. activeSelectionToken issuance and isolation
//  2. State isolation: raw feature loading != parcels ready
//  3. Token matching on verification callback
//  4. Stale token rejection
//  5. Render failure contract
//

import XCTest
import SwiftUI
import CoreLocation
@testable import MyBhoomi

@MainActor
final class CadastralRenderingLifecycleTests: XCTestCase {

    var viewModel: MapViewModel!

    override func setUp() {
        super.setUp()
        viewModel = MapViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // TEST 1: Initial state requires parcelRenderingConfirmed to be false
    func test_1_initial_state_is_not_confirmed() {
        XCTAssertFalse(viewModel.parcelRenderingConfirmed, "Fresh MapViewModel must have parcelRenderingConfirmed = false")
        XCTAssertEqual(viewModel.spatialResolutionState, .idle, "Fresh MapViewModel must have spatialResolutionState = .idle")
    }

    // TEST 2: Active selection token changes on new selection
    func test_2_token_generation_uniqueness() {
        let token1 = viewModel.activeSelectionToken
        let token2 = UUID()
        viewModel.activeSelectionToken = token2
        XCTAssertNotEqual(token1, viewModel.activeSelectionToken)
    }

    // TEST 3: Matching token triggers successful render state transition
    func test_3_matching_token_render_success() {
        let testVillageId = "0711152"
        let token = UUID()
        viewModel.activeSelectionToken = token
        viewModel.parcelRenderingConfirmed = false
        viewModel.spatialResolutionState = .resolving(title: "Tompo")

        viewModel.onParcelLayerRenderSuccess(villageId: testVillageId, token: token)

        XCTAssertTrue(viewModel.parcelRenderingConfirmed, "parcelRenderingConfirmed must transition to true upon render success with matching token")
        XCTAssertEqual(viewModel.spatialResolutionState, .ready(message: "Parcels ready"), "State must be .ready(\"Parcels ready\")")
    }

    // TEST 4: Stale token render callback is rejected and preserves unready state
    func test_4_stale_token_render_callback_rejected() {
        let testVillageId = "0711152"
        let currentToken = UUID()
        let staleToken = UUID()

        viewModel.activeSelectionToken = currentToken
        viewModel.parcelRenderingConfirmed = false
        viewModel.spatialResolutionState = .resolving(title: "Tompo")

        // Callback arrives with STALE token
        viewModel.onParcelLayerRenderSuccess(villageId: testVillageId, token: staleToken)

        XCTAssertFalse(viewModel.parcelRenderingConfirmed, "Stale token must NOT set parcelRenderingConfirmed to true")
        XCTAssertEqual(viewModel.spatialResolutionState, .resolving(title: "Tompo"), "spatialResolutionState must remain resolving while waiting for current token")
    }

    // TEST 5: Render failure callback with matching token records failure state
    func test_5_render_failure_handling() {
        let testVillageId = "0711152"
        let token = UUID()
        viewModel.activeSelectionToken = token
        viewModel.parcelRenderingConfirmed = false
        viewModel.spatialResolutionState = .resolving(title: "Tompo")

        let failureReason = "Outline layer missing, Zoom level below 10.0"
        viewModel.onParcelLayerRenderFailure(villageId: testVillageId, token: token, reason: failureReason)

        XCTAssertFalse(viewModel.parcelRenderingConfirmed, "Render failure must NOT set parcelRenderingConfirmed to true")
        XCTAssertEqual(viewModel.spatialResolutionState, .temporarilyUnavailable(reason: "Parcel display unavailable: \(failureReason)"))
    }

    // TEST 6: Stale failure callback is rejected
    func test_6_stale_failure_callback_rejected() {
        let testVillageId = "0711152"
        let currentToken = UUID()
        let staleToken = UUID()

        viewModel.activeSelectionToken = currentToken
        viewModel.parcelRenderingConfirmed = false
        viewModel.spatialResolutionState = .resolving(title: "Tompo")

        viewModel.onParcelLayerRenderFailure(villageId: testVillageId, token: staleToken, reason: "Stale failure")

        XCTAssertFalse(viewModel.parcelRenderingConfirmed)
        XCTAssertEqual(viewModel.spatialResolutionState, .resolving(title: "Tompo"), "State should remain unaffected by stale failure")
    }
}
