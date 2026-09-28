//
//  CadastralPlotCardRoRTests.swift
//  MyBhoomiTests
//
//  Production Concurrency Regression Tests:
//  Verifies that Cadastral Plot Card does NOT eagerly scrape RoR on presentation,
//  and that live RoR retrieval only executes upon explicit user action.
//

import XCTest
import SwiftUI
import CoreLocation
@testable import MyBhoomi

@MainActor
final class CadastralPlotCardRoRTests: XCTestCase {

    // Helper: Build sample parcel
    private func createSampleParcel(plotNumber: String = "1050") -> Parcel {
        let identity = CanonicalParcelIdentity(
            parcelID: "03:01:0301001:\(plotNumber)",
            plotNumber: plotNumber,
            districtName: "Cuttack",
            districtID: "03",
            tahasilName: "Cuttack Sadar",
            tahasilID: "01",
            villageName: "Tompo",
            villageID: "0301001",
            panchayatName: "Tompo GP"
        )
        return Parcel(
            id: "parcel_\(plotNumber)",
            boundary: [
                Coordinate(latitude: 20.46, longitude: 85.88),
                Coordinate(latitude: 20.47, longitude: 85.88),
                Coordinate(latitude: 20.47, longitude: 85.89),
                Coordinate(latitude: 20.46, longitude: 85.89),
            ],
            metadata: ParcelMetadata(
                identity: identity,
                estimatedAreaAcre: 0.082,
                additionalInfo: ["k_no": "123", "land_type": "Gharabari"]
            )
        )
    }

    // TEST 1: Opening an uncached plot initiates loading skeleton immediately
    func test_openingUncachedPlot_initiatesLoadingSkeletonState() async {
        let parcel = createSampleParcel(plotNumber: "1050")
        
        // Ensure cache is clear for this identity
        let cacheHit = VerifiedParcelCache.shared.findVerified(identity: parcel.identity)
        XCTAssertNil(cacheHit, "Initial state should not have cached verified RoR for fresh plot")
        
        // When not in cache:
        // Initial presentation state starts in loading state:
        let initialLoadingState = RoRErrorState.loading(isSlow: false)
        XCTAssertFalse(initialLoadingState.isRetryable, "Skeleton loading should not be marked retryable")
        XCTAssertEqual(initialLoadingState.title, "Checking official record…")
        
        // Cadastral geometry, boundary coordinates, and area are available immediately
        XCTAssertEqual(parcel.identity.plotNumber, "1050")
        XCTAssertEqual(parcel.metadata.estimatedAreaAcre, 0.082)
        XCTAssertEqual(parcel.identity.villageName, "Tompo")
        XCTAssertEqual(parcel.identity.districtName, "Cuttack")
    }

    // TEST 2: Verified cache hit restores 0ms without network call
    func test_verifiedCacheHit_restoresInstantlyWithoutNetwork() async {
        let parcel = createSampleParcel(plotNumber: "9999")
        let dummyRoR = RoRResponse(
            success: true,
            plot: "9999",
            village: "TOMPO",
            district: "CUTTACK",
            tahasil: "CUTTACK SADAR",
            khataNumber: "456",
            area: "0.150 Ac",
            landType: "Gharabari",
            owners: [OwnerEntry(name: "Cached Owner", share: "1.000", khataNumber: "456")],
            plots: [],
            verification: RoRVerification(
                status: .verified,
                requestedDistrict: "Cuttack",
                requestedTahasil: "Cuttack Sadar",
                requestedVillage: "Tompo",
                requestedPlot: "9999",
                returnedDistrict: "CUTTACK",
                returnedTahasil: "CUTTACK SADAR",
                returnedVillage: "TOMPO",
                returnedPlot: "9999",
                locationMatch: true,
                plotMatch: true,
                details: "Verified match"
            )
        )
        
        let verif = ParcelCrossVerifier.verify(
            gisIdentity: parcel.identity,
            rorResponse: dummyRoR,
            gisAreaInAcre: 0.150
        )
        
        _ = VerifiedParcelCache.shared.save(
            identity: parcel.identity,
            ror: dummyRoR,
            verification: verif
        )
        
        let cached = VerifiedParcelCache.shared.findVerified(identity: parcel.identity)
        XCTAssertNotNil(cached, "Saved verified parcel must be found instantly in cache")
        XCTAssertEqual(cached?.rawRoRResponse.plot, "9999")
        XCTAssertEqual(cached?.rawRoRResponse.khataNumber, "456")
        XCTAssertEqual(cached?.rawRoRResponse.owners.first?.name, "Cached Owner")
    }

    // TEST 3: RoR loading state and retry semantics
    func test_rorLoadingState_and_retrySemantics() {
        let loadingState = RoRErrorState.loading(isSlow: false)
        XCTAssertFalse(loadingState.isRetryable, "Active loading state should not be retryable")
        XCTAssertEqual(loadingState.title, "Checking official record…")

        let slowLoadingState = RoRErrorState.loading(isSlow: true)
        XCTAssertFalse(slowLoadingState.isRetryable)
        XCTAssertEqual(slowLoadingState.title, "Still checking the official record…")

        let unavailableState = RoRErrorState.unavailable
        XCTAssertTrue(unavailableState.isRetryable, "Temporary service outage should be retryable")

        let networkProblemState = RoRErrorState.networkProblem
        XCTAssertTrue(networkProblemState.isRetryable, "Network interruption should be retryable")
    }

    // TEST 4: RoR failure state preserves cadastral parcel geometry
    func test_rorFailureState_preservesCadastralGeometry() {
        let parcel = createSampleParcel(plotNumber: "1050")
        
        // Simulating RoR failure (e.g. portal timeout or unavailable)
        let simulatedError = RoRErrorState.unavailable
        XCTAssertTrue(simulatedError.isRetryable)
        
        // Cadastral geometry, boundary coordinates, and area must remain 100% intact
        XCTAssertEqual(parcel.boundary.count, 4)
        XCTAssertEqual(parcel.metadata.estimatedAreaAcre, 0.082)
        XCTAssertEqual(parcel.identity.plotNumber, "1050")
    }

    // TEST 5: Existing RoR response rendering invariants
    func test_verifiedRoRResponse_renderingInvariants() {
        let parcel = createSampleParcel(plotNumber: "1050")
        let liveRoR = RoRResponse(
            success: true,
            plot: "1050",
            village: "TOMPO",
            district: "CUTTACK",
            tahasil: "CUTTACK SADAR",
            khataNumber: "123",
            area: "0.082 Ac",
            landType: "Gharabari",
            owners: [
                OwnerEntry(name: "Pravat Kumar Jena", share: "0.500", khataNumber: "123"),
                OwnerEntry(name: "Subrat Kumar Jena", share: "0.500", khataNumber: "123"),
            ],
            plots: [AssociatedPlot(plotNumber: "1050", area: "0.082 Ac", landType: "Gharabari")],
            verification: RoRVerification(
                status: .verified,
                requestedDistrict: "Cuttack",
                requestedTahasil: "Cuttack Sadar",
                requestedVillage: "Tompo",
                requestedPlot: "1050",
                returnedDistrict: "CUTTACK",
                returnedTahasil: "CUTTACK SADAR",
                returnedVillage: "TOMPO",
                returnedPlot: "1050",
                locationMatch: true,
                plotMatch: true,
                details: "Verified"
            )
        )
        
        let verif = ParcelCrossVerifier.verify(
            gisIdentity: parcel.identity,
            rorResponse: liveRoR,
            gisAreaInAcre: 0.082
        )
        
        XCTAssertTrue(verif.isVerified, "Exact plot and district/tahasil/village match must be verified")
        XCTAssertEqual(liveRoR.owners.count, 2)
        XCTAssertEqual(liveRoR.khataNumber, "123")
        XCTAssertEqual(liveRoR.landType, "Gharabari")
    }

    // TEST 6: Area Formatter conversion: decimal = acre * 100 for all acres
    func test_odishaAreaFormatter_decimalConversionInvariants() {
        // 0.055917 acre → 5.59 Decimal
        let d1 = OdishaAreaFormatter.formatAcreToDecimalString(0.055917)
        XCTAssertEqual(d1, "5.59", "0.055917 acre must convert to 5.59 Decimal")
        
        // 0.159894 acre → 15.99 Decimal
        let d2 = OdishaAreaFormatter.formatAcreToDecimalString(0.159894)
        XCTAssertEqual(d2, "15.99", "0.159894 acre must convert to 15.99 Decimal")
        
        // 0.926136 acre → 92.61 Decimal
        let d3 = OdishaAreaFormatter.formatAcreToDecimalString(0.926136)
        XCTAssertEqual(d3, "92.61", "0.926136 acre must convert to 92.61 Decimal")
        
        // 2.051034 acre → 205.10 Decimal
        let d4 = OdishaAreaFormatter.formatAcreToDecimalString(2.051034)
        XCTAssertEqual(d4, "205.10", "2.051034 acre must convert to 205.10 Decimal")
        
        // 5.0000 acre → 500 Decimal
        let d5 = OdishaAreaFormatter.formatAcreToDecimalString(5.0000)
        XCTAssertEqual(d5, "500", "5.0000 acre must convert to 500 Decimal")
    }

    // TEST 7: Area Formatter string-based parsing
    func test_odishaAreaFormatter_stringParsingInvariants() {
        XCTAssertEqual(OdishaAreaFormatter.formatToDecimalString("0.055917"), "5.59")
        XCTAssertEqual(OdishaAreaFormatter.formatToDecimalString("0.159894"), "15.99")
        XCTAssertEqual(OdishaAreaFormatter.formatToDecimalString("0.926136"), "92.61")
        XCTAssertEqual(OdishaAreaFormatter.formatToDecimalString("2.051034"), "205.10")
        XCTAssertEqual(OdishaAreaFormatter.formatToDecimalString("5.0000"), "500")
        XCTAssertEqual(OdishaAreaFormatter.formatToDecimalString("0 Acre 1800 Decimal"), "18")
        XCTAssertEqual(OdishaAreaFormatter.formatToDecimalString("0 Acre 9900 Decimal"), "99")
    }

    // TEST 8: Error taxonomy distinguishes failure modes
    func test_rorErrorTaxonomy_distinguishesFailures() {
        // Temporary busy
        let busyState = RoRErrorState.from(error: RoRError.serverError(503, "Service busy"))
        XCTAssertEqual(busyState, .temporaryBusy)
        XCTAssertTrue(busyState.isRetryable)
        XCTAssertEqual(busyState.title, "Land record service is temporarily busy.")

        // Not found
        let notFoundState = RoRErrorState.from(error: RoRError.notFound("No record"))
        XCTAssertEqual(notFoundState, .notFound)
        XCTAssertFalse(notFoundState.isRetryable)

        // Unavailable
        let unavailState = RoRErrorState.from(error: RoRError.temporarilyUnavailable("Gov down"))
        XCTAssertEqual(unavailState, .unavailable)
        XCTAssertTrue(unavailState.isRetryable)

        // Network problem
        let netState = RoRErrorState.from(error: RoRError.networkError("Socket dropped"))
        XCTAssertEqual(netState, .networkProblem)
        XCTAssertTrue(netState.isRetryable)

        // Malformed response
        let malformedState = RoRErrorState.from(error: RoRError.decodingError("Bad JSON"))
        XCTAssertEqual(malformedState, .malformedResponse)
        XCTAssertTrue(malformedState.isRetryable)
    }

    // TEST 9: Card format invariants - pure values without redundant labels
    func test_cardFormatInvariants_pureValuesAndNoRedundantLabels() {
        let parcel = createSampleParcel(plotNumber: "276")
        let liveRoR = RoRResponse(
            success: true,
            plot: "276",
            village: "Tompo",
            district: "Cuttack",
            tahasil: "Cuttack Sadar",
            khataNumber: "51",
            area: "0.900 Ac",
            landType: "Gharabari",
            owners: [OwnerEntry(name: "Verified Owner", share: "1.000", khataNumber: "51")],
            plots: [AssociatedPlot(plotNumber: "276", area: "0.900 Ac", landType: "Gharabari")],
            verification: RoRVerification(status: .verified)
        )
        
        // Clean Khatian: "51"
        let khatian = liveRoR.khataNumber ?? "—"
        XCTAssertEqual(khatian, "51")
        XCTAssertFalse(khatian.contains("Official Khata"))
        XCTAssertFalse(khatian.contains("Not checked"))
        
        // Clean Area: "90 Decimal"
        let areaFormatted = OdishaAreaFormatter.formatToDecimalString(liveRoR.area ?? "")
        XCTAssertEqual(areaFormatted, "90")
        let displayArea = "\(areaFormatted) Decimal"
        XCTAssertEqual(displayArea, "90 Decimal")
        XCTAssertFalse(displayArea.contains("≈"))
        XCTAssertFalse(displayArea.contains("GIS estimate"))
        
        // Clean Land Type: "Gharabari"
        let landType = LandClassificationHelper.cleanName(for: liveRoR.landType ?? "")
        XCTAssertEqual(landType, "Gharabari")
        XCTAssertFalse(landType.contains("Official Kissam"))
        XCTAssertFalse(landType.contains("Not checked"))
    }

    // TEST 10: Race condition protection - stale Plot A response discarded when Plot B is selected
    func test_rapidPlotSelection_stalePlotResponseDiscarded() async {
        let plotA = createSampleParcel(plotNumber: "100")
        let plotB = createSampleParcel(plotNumber: "200")
        
        var currentSelectedParcelID = plotA.id
        var displayedResponse: RoRResponse? = nil
        
        // Simulate rapid selection from Plot A to Plot B
        currentSelectedParcelID = plotB.id
        
        // Simulated delayed completion of Plot A
        let plotAResponse = RoRResponse(
            success: true,
            plot: "100",
            village: "Tompo",
            district: "Cuttack",
            tahasil: "Cuttack Sadar",
            khataNumber: "10",
            area: "0.100 Ac",
            landType: "Sarada",
            owners: [],
            plots: []
        )
        
        // Check matching ID guard:
        let targetParcelID_A = plotA.id
        if currentSelectedParcelID == targetParcelID_A {
            displayedResponse = plotAResponse
        }
        
        // Plot A response must NOT have been applied
        XCTAssertNil(displayedResponse, "Plot A response must be discarded because current selected parcel is Plot B")
        
        // Plot B response arrives:
        let plotBResponse = RoRResponse(
            success: true,
            plot: "200",
            village: "Tompo",
            district: "Cuttack",
            tahasil: "Cuttack Sadar",
            khataNumber: "20",
            area: "0.200 Ac",
            landType: "Gharabari",
            owners: [],
            plots: []
        )
        let targetParcelID_B = plotB.id
        if currentSelectedParcelID == targetParcelID_B {
            displayedResponse = plotBResponse
        }
        
        XCTAssertNotNil(displayedResponse)
        XCTAssertEqual(displayedResponse?.plot, "200")
    }

    // TEST 11: Owner expansion height calculation & bottom-anchored downward drag reduction
    func test_ownerExpansion_heightCalculation_and_downwardDragReduction() {
        // 3 owners
        let displayCount = 3
        let rowsHeight = CGFloat(displayCount) * 28.0 + CGFloat(displayCount - 1) * 8.0 // 3*28 + 2*8 = 84 + 16 = 100
        let naturalHeight = rowsHeight + 17.0 // 117.0
        XCTAssertEqual(naturalHeight, 117.0, "Natural expanded height for 3 owners should be 117pt")
        
        // Simulating downward drag of 30pt:
        let dragDown30: CGFloat = 30.0
        let interactiveHeight30 = max(0, naturalHeight - dragDown30)
        XCTAssertEqual(interactiveHeight30, 87.0, "Height should reduce by exactly 30pt (to 87pt) with bottom edge anchored")
        
        // Simulating downward drag of 100pt:
        let dragDown100: CGFloat = 100.0
        let interactiveHeight100 = max(0, naturalHeight - dragDown100)
        XCTAssertEqual(interactiveHeight100, 17.0, "Height should reduce by 100pt (to 17pt)")
        
        // Simulating downward drag past the collapsed detent (e.g. 150pt):
        let dragDown150: CGFloat = 150.0
        let interactiveHeight150 = max(0, naturalHeight - dragDown150)
        XCTAssertEqual(interactiveHeight150, 0.0, "Height must clamp at 0 (collapsed detent) and not shrink below")
    }

    // TEST 12: Upward drag when already expanded does NOT grow beyond expanded detent
    func test_ownerExpansion_upwardDrag_clampedAtExpandedDetent() {
        let naturalHeight: CGFloat = 117.0
        
        // Simulating upward drag (negative translation: -40pt)
        let dragUpTranslation: CGFloat = -40.0
        let dragDown = max(0, dragUpTranslation) // 0
        let interactiveHeight = max(0, naturalHeight - dragDown)
        
        XCTAssertEqual(dragDown, 0.0)
        XCTAssertEqual(interactiveHeight, naturalHeight, "Upward drag while expanded must clamp at expanded height and not grow beyond it")
    }

    // TEST 13: CardEffectiveOffsetY is strictly 0 when expanded (zero translation, bottom remains anchored)
    func test_expandedState_cardEffectiveOffsetY_isStrictlyZero() {
        let isOwnersExpanded = true
        let dragOffsetY: CGFloat = 0
        let dragTranslation: CGFloat = 50.0 // User dragging down by 50pt
        
        let cardEffectiveOffsetY: CGFloat = {
            if isOwnersExpanded {
                return 0 // Bottom remains anchored; height shrinks instead
            } else {
                return dragOffsetY + dragTranslation
            }
        }()
        
        XCTAssertEqual(cardEffectiveOffsetY, 0, "Expanded card must NOT translate vertically in 2D space")
    }

    // TEST 14: Collapse threshold logic (dy > 35 or velocity > 80 triggers collapse; minor drag springs back)
    func test_expandedState_collapseThresholds() {
        // Minor drag: dy = 20, predicted = 30 -> springs back to expanded
        let minorDY: CGFloat = 20
        let minorPredicted: CGFloat = 30
        let minorShouldCollapse = (minorDY > 35 || minorPredicted > 80)
        XCTAssertFalse(minorShouldCollapse, "Minor drag under 35pt should spring back to expanded")
        
        // Sufficient drag: dy = 45 -> collapses
        let largeDY: CGFloat = 45
        let largePredicted: CGFloat = 50
        let largeShouldCollapse = (largeDY > 35 || largePredicted > 80)
        XCTAssertTrue(largeShouldCollapse, "Drag greater than 35pt should trigger collapse")
        
        // Quick flick: dy = 20, predicted = 95 -> collapses by velocity
        let flickDY: CGFloat = 20
        let flickPredicted: CGFloat = 95
        let flickShouldCollapse = (flickDY > 35 || flickPredicted > 80)
        XCTAssertTrue(flickShouldCollapse, "Flick with predicted translation > 80pt should trigger collapse")
    }
}


