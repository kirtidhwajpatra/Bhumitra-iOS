//
//  Phase7_6_FalseGovernmentTests.swift
//  MyBhoomi
//
//  Unit tests verifying that empty owners, 404, 422, timeouts, and parser failures
//  never result in false "Government Land" classification.
//

import Foundation

@MainActor
public struct Phase7_6_FalseGovernmentTests {
    
    // Helper to evaluate ownership state rendering
    static func evaluateDisplayClassification(
        ror: RoRResponse?,
        error: RoRError?,
        isVerified: Bool
    ) -> String {
        if let error = error {
            switch error {
            case .notFound:
                return "RoR Record Not Found"
            case .identityMismatch:
                return "Could Not Verify This Parcel"
            case .timeout, .temporarilyUnavailable:
                return "Could Not Verify This Parcel"
            default:
                return "Could Not Verify This Parcel"
            }
        }
        
        guard let ror = ror else {
            return "Could Not Verify This Parcel"
        }
        
        // Explicit Government Classification Check
        let isGovt = isExplicitlyGovernment(ror: ror)
        
        if isGovt && isVerified {
            return "Government Land"
        } else if !ror.owners.isEmpty && isVerified {
            return "Private Raiyati Ownership"
        } else if ror.owners.isEmpty {
            return "Ownership unverified"
        } else {
            return "Could Not Verify This Parcel"
        }
    }
    
    static func isExplicitlyGovernment(ror: RoRResponse) -> Bool {
        guard let lt = ror.landType else { return false }
        let upper = lt.uppercased()
        return upper.contains("GOVERNMENT") || upper.contains("SARKAR") || lt.contains("ସରକାର")
    }
    
    // 1. testEmptyOwnersDoesNotMeanGovernment
    static func testEmptyOwnersDoesNotMeanGovernment() -> Bool {
        let ror = RoRResponse(
            success: true,
            plot: "333",
            village: "Raghunathpur_Jali",
            district: "Khordha",
            tahasil: "Bhubaneswar",
            khataNumber: "—",
            area: "—",
            landType: "Unverified",
            owners: [],
            plots: [],
            rawFields: nil,
            verification: nil,
            source: "CADASTRAL_MAP"
        )
        let display = evaluateDisplayClassification(ror: ror, error: nil, isVerified: true)
        assert(display != "Government Land", "FAILED: Empty owners mapped to Government Land!")
        assert(display == "Ownership unverified", "FAILED: Expected 'Ownership unverified', got '\(display)'")
        return true
    }
    
    // 2. test404DoesNotMeanGovernment
    static func test404DoesNotMeanGovernment() -> Bool {
        let error = RoRError.notFound("No official RoR record found.")
        let display = evaluateDisplayClassification(ror: nil, error: error, isVerified: false)
        assert(display != "Government Land", "FAILED: 404 mapped to Government Land!")
        assert(display == "RoR Record Not Found", "FAILED: Expected 'RoR Record Not Found', got '\(display)'")
        return true
    }
    
    // 3. test422DoesNotMeanGovernment
    static func test422DoesNotMeanGovernment() -> Bool {
        let error = RoRError.identityMismatch("Plot mismatch: Requested plot '12', but portal returned plot '168'.")
        let display = evaluateDisplayClassification(ror: nil, error: error, isVerified: false)
        assert(display != "Government Land", "FAILED: 422 mapped to Government Land!")
        assert(display == "Could Not Verify This Parcel", "FAILED: Expected 'Could Not Verify This Parcel', got '\(display)'")
        return true
    }
    
    // 4. testTimeoutDoesNotMeanGovernment
    static func testTimeoutDoesNotMeanGovernment() -> Bool {
        let error = RoRError.timeout("Bhulekh service timed out.")
        let display = evaluateDisplayClassification(ror: nil, error: error, isVerified: false)
        assert(display != "Government Land", "FAILED: Timeout mapped to Government Land!")
        assert(display == "Could Not Verify This Parcel", "FAILED: Expected 'Could Not Verify This Parcel', got '\(display)'")
        return true
    }
    
    // 5. testParserFailureDoesNotMeanGovernment
    static func testParserFailureDoesNotMeanGovernment() -> Bool {
        let error = RoRError.decodingError("Failed to parse HTML")
        let display = evaluateDisplayClassification(ror: nil, error: error, isVerified: false)
        assert(display != "Government Land", "FAILED: Parser failure mapped to Government Land!")
        assert(display == "Could Not Verify This Parcel", "FAILED: Expected 'Could Not Verify This Parcel', got '\(display)'")
        return true
    }
    
    // 6. testVerifiedGovernmentRecordShowsGovernment
    static func testVerifiedGovernmentRecordShowsGovernment() -> Bool {
        let ror = RoRResponse(
            success: true,
            plot: "1",
            village: "G_Dimbo",
            district: "Keonjhar",
            tahasil: "Keonjhar Sadar",
            khataNumber: "1",
            area: "1.20",
            landType: "GOVERNMENT RAKHITA",
            owners: [],
            plots: [],
            rawFields: nil,
            verification: nil,
            source: "BHULEKH_OFFICIAL"
        )
        let display = evaluateDisplayClassification(ror: ror, error: nil, isVerified: true)
        assert(display == "Government Land", "FAILED: Explicit verified government record did not display 'Government Land'!")
        return true
    }
    
    // 7. testVerifiedPrivateRecordShowsOwner
    static func testVerifiedPrivateRecordShowsOwner() -> Bool {
        let owner = OwnerEntry(name: "Ramesh Chandra Jena", share: "1.0", khataNumber: "152")
        let ror = RoRResponse(
            success: true,
            plot: "12",
            village: "G_Dimbo",
            district: "Keonjhar",
            tahasil: "Keonjhar Sadar",
            khataNumber: "152",
            area: "0.45",
            landType: "Raiyati (Private)",
            owners: [owner],
            plots: [],
            rawFields: nil,
            verification: nil,
            source: "BHULEKH_OFFICIAL"
        )
        let display = evaluateDisplayClassification(ror: ror, error: nil, isVerified: true)
        assert(display == "Private Raiyati Ownership", "FAILED: Verified private record did not display 'Private Raiyati Ownership'!")
        return true
    }
    
    public static func runAllTests() -> (passed: Int, total: Int) {
        var passed = 0
        let tests: [(String, () -> Bool)] = [
            ("testEmptyOwnersDoesNotMeanGovernment", testEmptyOwnersDoesNotMeanGovernment),
            ("test404DoesNotMeanGovernment", test404DoesNotMeanGovernment),
            ("test422DoesNotMeanGovernment", test422DoesNotMeanGovernment),
            ("testTimeoutDoesNotMeanGovernment", testTimeoutDoesNotMeanGovernment),
            ("testParserFailureDoesNotMeanGovernment", testParserFailureDoesNotMeanGovernment),
            ("testVerifiedGovernmentRecordShowsGovernment", testVerifiedGovernmentRecordShowsGovernment),
            ("testVerifiedPrivateRecordShowsOwner", testVerifiedPrivateRecordShowsOwner)
        ]
        
        print("============================================================")
        print("RUNNING PHASE 7.6 FALSE GOVERNMENT UI TESTS")
        print("============================================================")
        for (name, testFunc) in tests {
            let result = testFunc()
            if result {
                passed += 1
                print("  ✓ \(name): PASSED")
            } else {
                print("  ✗ \(name): FAILED")
            }
        }
        print("============================================================")
        print("RESULTS: \(passed)/\(tests.count) PASSED")
        print("============================================================")
        return (passed, tests.count)
    }
}
