//
//  RoRIdentitySafetyTests.swift
//  MyBhoomiTests
//
//  Zero-Regression Safety Tests for RoR Identity Cross-Verification
//  Enforces: CURRENT PARCEL IDENTITY + VALID OFFICIAL RESPONSE = DISPLAYABLE RECORD
//

import XCTest
@testable import MyBhoomi

final class RoRIdentitySafetyTests: XCTestCase {
    
    // MARK: - Exact Bug Regression: Anugul / Athmallik / Kahnupur / Plot 116
    
    func test_exactBug_Anugul_Kahnupur_Plot116_wrong_response_rejected() {
        let currentIdentity = CanonicalParcelIdentity(
            parcelID: "14:2:4:116",
            plotNumber: "116",
            districtName: "Anugul",
            districtID: "14",
            tahasilName: "Athmallik",
            tahasilID: "2",
            villageName: "Kahnupur",
            villageID: "4",
            panchayatName: "Kahnupur GP"
        )
        
        // Synthetic / Wrong response (Trilochan Panda / Khatian 302 with mismatch or unverified status)
        let wrongResponse = RoRResponse(
            success: true,
            plot: "116",
            village: "KAHNUPUR",
            district: "ODISHA", // Unresolved district
            tahasil: "KISHORENAGAR", // Wrong tahasil
            khataNumber: "302",
            area: "0.50 Acre",
            landType: "Stitiban",
            owners: [
                OwnerEntry(name: "Trilochan Panda S/o Late Gopal Panda", share: "1.000", khataNumber: "302")
            ],
            plots: [AssociatedPlot(plotNumber: "116", area: "0.50 Acre", landType: "Stitiban")],
            verification: RoRVerification(
                status: .mismatch,
                requestedDistrict: "Anugul",
                requestedTahasil: "Athmallik",
                requestedVillage: "Kahnupur",
                requestedPlot: "116",
                returnedDistrict: "ODISHA",
                returnedTahasil: "KISHORENAGAR",
                returnedVillage: "KAHNUPUR",
                returnedPlot: "116",
                locationMatch: false,
                plotMatch: true,
                details: "Tahasil mismatch: Athmallik vs Kishorenagar"
            )
        )
        
        let verif = ParcelCrossVerifier.verify(
            gisIdentity: currentIdentity,
            rorResponse: wrongResponse,
            gisAreaInAcre: 0.50
        )
        
        // INVARIANT: Must REJECT response, never AVAILABLE
        XCTAssertFalse(verif.isVerified, "Wrong response with tahasil mismatch MUST NOT be verified!")
        XCTAssertEqual(verif.status, ParcelVerificationStatus.mismatch)
        XCTAssertFalse(verif.tahasilMatch)
    }
    
    func test_exactBug_Anugul_Kahnupur_Plot116_plotMismatch_rejected() {
        let currentIdentity = CanonicalParcelIdentity(
            parcelID: "14:2:4:116",
            plotNumber: "116",
            districtName: "Anugul",
            districtID: "14",
            tahasilName: "Athmallik",
            tahasilID: "2",
            villageName: "Kahnupur",
            villageID: "4"
        )
        
        // Response with different plot (e.g. 116/1 or 999)
        let wrongPlotResponse = RoRResponse(
            success: true,
            plot: "999",
            village: "Kahnupur",
            district: "Anugul",
            tahasil: "Athmallik",
            khataNumber: "302",
            area: "0.50 Acre",
            landType: "Stitiban",
            owners: [OwnerEntry(name: "Trilochan Panda")],
            verification: RoRVerification(
                status: .verified,
                requestedDistrict: "Anugul",
                requestedTahasil: "Athmallik",
                requestedVillage: "Kahnupur",
                requestedPlot: "116",
                returnedDistrict: "Anugul",
                returnedTahasil: "Athmallik",
                returnedVillage: "Kahnupur",
                returnedPlot: "999",
                locationMatch: true,
                plotMatch: false,
                details: "Plot mismatch"
            )
        )
        
        let verif = ParcelCrossVerifier.verify(
            gisIdentity: currentIdentity,
            rorResponse: wrongPlotResponse
        )
        
        XCTAssertFalse(verif.isVerified, "Mismatched plot MUST NOT be verified!")
        XCTAssertFalse(verif.plotMatch)
        XCTAssertEqual(verif.status, ParcelVerificationStatus.mismatch)
    }
    
    func test_unverifiedBackendStatus_rejected() {
        let currentIdentity = CanonicalParcelIdentity(
            parcelID: "14:2:4:116",
            plotNumber: "116",
            districtName: "Anugul",
            districtID: "14",
            tahasilName: "Athmallik",
            tahasilID: "2",
            villageName: "Kahnupur",
            villageID: "4"
        )
        
        let unverifiedResponse = RoRResponse(
            success: true,
            plot: "116",
            village: "Kahnupur",
            district: "Anugul",
            tahasil: "Athmallik",
            khataNumber: "302",
            owners: [OwnerEntry(name: "Trilochan Panda")],
            verification: RoRVerification(
                status: .mismatch,
                details: "Portal unverified"
            )
        )
        
        let verif = ParcelCrossVerifier.verify(
            gisIdentity: currentIdentity,
            rorResponse: unverifiedResponse
        )
        
        XCTAssertFalse(verif.isVerified)
        XCTAssertEqual(verif.status, ParcelVerificationStatus.mismatch)
    }
    
    func test_nilRoR_sourceUnavailable() {
        let currentIdentity = CanonicalParcelIdentity(
            parcelID: "14:2:4:116",
            plotNumber: "116",
            districtName: "Anugul",
            districtID: "14",
            tahasilName: "Athmallik",
            tahasilID: "2",
            villageName: "Kahnupur",
            villageID: "4"
        )
        
        let verif = ParcelCrossVerifier.verify(
            gisIdentity: currentIdentity,
            rorResponse: nil,
            error: RoRError.temporarilyUnavailable("Service down")
        )
        
        XCTAssertFalse(verif.isVerified)
        XCTAssertEqual(verif.status, ParcelVerificationStatus.sourceUnavailable)
    }
    
    func test_knownGoodParcel_remainsVerified() {
        let currentIdentity = CanonicalParcelIdentity(
            parcelID: "24:1:100:1182",
            plotNumber: "1182",
            districtName: "Keonjhar",
            districtID: "24",
            tahasilName: "Keonjhar Sadar",
            tahasilID: "1",
            villageName: "G KERI 271",
            villageID: "100"
        )
        
        let validResponse = RoRResponse(
            success: true,
            plot: "1182",
            village: "G KERI 271",
            district: "KEONJHAR",
            tahasil: "KEONJHAR SADAR",
            khataNumber: "112",
            area: "0.41 Acre",
            landType: "Sarada-1",
            owners: [OwnerEntry(name: "MOHAN PATRA", share: "1.000", khataNumber: "112")],
            plots: [AssociatedPlot(plotNumber: "1182", area: "0.41 Acre", landType: "Sarada-1")],
            verification: RoRVerification(
                status: .verified,
                requestedDistrict: "KEONJHAR",
                requestedTahasil: "KEONJHAR SADAR",
                requestedVillage: "G KERI 271",
                requestedPlot: "1182",
                returnedDistrict: "KEONJHAR",
                returnedTahasil: "KEONJHAR SADAR",
                returnedVillage: "G KERI 271",
                returnedPlot: "1182",
                locationMatch: true,
                plotMatch: true,
                details: "Verified Official RoR"
            )
        )
        
        let verif = ParcelCrossVerifier.verify(
            gisIdentity: currentIdentity,
            rorResponse: validResponse,
            gisAreaInAcre: 0.41
        )
        
        XCTAssertTrue(verif.isVerified, "Known good parcel must remain verified!")
        XCTAssertEqual(verif.status, ParcelVerificationStatus.verified)
        XCTAssertTrue(verif.districtMatch)
        XCTAssertTrue(verif.tahasilMatch)
        XCTAssertTrue(verif.villageMatch)
        XCTAssertTrue(verif.plotMatch)
    }
    
    // MARK: - RoR Error Taxonomy & UX Safety Tests
    
    func test_errorTaxonomy_notFound_hasNoRetry() {
        let error = RoRError.notFound("No official RoR record found for plot '223'.")
        let state = RoRErrorState.from(error: error)
        
        XCTAssertEqual(state, .notFound)
        XCTAssertEqual(state.title, "No official record found for this plot.")
        XCTAssertFalse(state.isRetryable, "notFound must NOT display retry button!")
        XCTAssertEqual(state.iconName, "doc.text.magnifyingglass")
    }
    
    func test_errorTaxonomy_timeout_isRetryable() {
        let error = RoRError.timeout("Request timed out")
        let state = RoRErrorState.from(error: error)
        
        XCTAssertEqual(state, .slow)
        XCTAssertEqual(state.title, "Official record is taking longer than expected.")
        XCTAssertTrue(state.isRetryable, "timeout must display retry button!")
        XCTAssertEqual(state.iconName, "clock.badge.exclamationmark")
    }
    
    func test_errorTaxonomy_unavailable_isRetryable() {
        let error = RoRError.temporarilyUnavailable("Service down")
        let state = RoRErrorState.from(error: error)
        
        XCTAssertEqual(state, .unavailable)
        XCTAssertEqual(state.title, "The official land-record service is temporarily unavailable.")
        XCTAssertTrue(state.isRetryable, "temporarilyUnavailable must display retry button!")
        XCTAssertEqual(state.iconName, "exclamationmark.triangle.fill")
    }
    
    func test_errorTaxonomy_networkError_isRetryable() {
        let error = RoRError.networkError("Connection lost")
        let state = RoRErrorState.from(error: error)
        
        XCTAssertEqual(state, .networkProblem)
        XCTAssertEqual(state.title, "Couldn't connect to the official record service.")
        XCTAssertTrue(state.isRetryable, "networkError must display retry button!")
        XCTAssertEqual(state.iconName, "wifi.slash")
    }
    
    func test_errorTaxonomy_missingMetadata_identityUnresolved_noRetry() {
        let error = RoRError.missingMetadata("District")
        let state = RoRErrorState.from(error: error)
        
        XCTAssertEqual(state, .identityUnresolved)
        XCTAssertEqual(state.title, "Government location mapping could not be confirmed.")
        XCTAssertFalse(state.isRetryable, "missingMetadata must NOT display retry button!")
    }
    
    func test_errorTaxonomy_identityMismatch_noRetry() {
        let error = RoRError.identityMismatch("Mismatch")
        let state = RoRErrorState.from(error: error)
        
        XCTAssertEqual(state, .identityMismatch)
        XCTAssertEqual(state.title, "Official record could not be safely matched to this plot.")
        XCTAssertFalse(state.isRetryable, "identityMismatch must NOT display retry button!")
    }
    
    func test_errorTaxonomy_loadingSlow_isNotRetryable() {
        let fastLoading = RoRErrorState.loading(isSlow: false)
        XCTAssertEqual(fastLoading.title, "Checking official record…")
        XCTAssertNil(fastLoading.subtitle)
        XCTAssertFalse(fastLoading.isRetryable, "In-flight fast loading must never show a retry button!")
        
        let slowLoading = RoRErrorState.loading(isSlow: true)
        XCTAssertEqual(slowLoading.title, "Still checking the official record…")
        XCTAssertEqual(slowLoading.subtitle, "The government land-record service is taking a little longer.")
        XCTAssertFalse(slowLoading.isRetryable, "In-flight slow loading must never show a retry button!")
    }
}



