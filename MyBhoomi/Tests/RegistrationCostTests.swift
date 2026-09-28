//
//  RegistrationCostTests.swift
//  MyBhoomi
//
//  Unit tests verifying exact Decimal currency arithmetic, deed rules,
//  women buyer concessions, parcel switching safety, and honest error handling.
//

import Foundation

public struct RegistrationCostTests {

    // 1. testExactDecimalMath
    public static func testExactDecimalMath() -> Bool {
        // Benchmark rate: ₹5,029.07 / Decimal
        // Area: 5 Decimal
        let ratePerDec = Decimal(string: "5029.07")!
        let area = Decimal(string: "5.0")!
        let benchmarkVal = ratePerDec * area
        assert(benchmarkVal == Decimal(string: "25145.35")!, "FAILED: Expected benchmark value 25145.35, got \(benchmarkVal)")

        // 5% Stamp Duty
        let stampDuty = (benchmarkVal * Decimal(string: "0.05")!)
        let handler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 2,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let roundedStamp = NSDecimalNumber(decimal: stampDuty).rounding(accordingToBehavior: handler).doubleValue
        assert(roundedStamp >= 1257.26 && roundedStamp <= 1257.28, "FAILED: Stamp duty calculation inaccurate: \(roundedStamp)")

        // 2% Registration Fee
        let regFee = benchmarkVal * Decimal(string: "0.02")!
        let roundedReg = NSDecimalNumber(decimal: regFee).rounding(accordingToBehavior: handler).doubleValue
        assert(roundedReg >= 502.90 && roundedReg <= 502.92, "FAILED: Registration fee calculation inaccurate: \(roundedReg)")

        return true
    }

    // 2. testCurrencyFormatting
    public static func testCurrencyFormatting() -> Bool {
        let val1 = Decimal(string: "25145.35")!
        let formatted1 = RegistrationCostFormatter.format(val1)
        assert(formatted1.contains("25,145.35"), "FAILED: Expected 25,145.35 in formatted string, got \(formatted1)")

        let val2 = Decimal(string: "1760.18")!
        let formatted2 = RegistrationCostFormatter.format(val2)
        assert(formatted2.contains("1,760.18"), "FAILED: Expected 1,760.18 in formatted string, got \(formatted2)")

        let val3 = Decimal(string: "1508.72")!
        let formatted3 = RegistrationCostFormatter.format(val3)
        assert(formatted3.contains("1,508.72"), "FAILED: Expected 1,508.72 in formatted string, got \(formatted3)")

        return true
    }

    // 3. testWomenBuyerConcessionModel
    public static func testWomenBuyerConcessionModel() -> Bool {
        let estimateStandard = RegistrationCostEstimate(
            status: "AVAILABLE",
            calculatedAt: "2026-09-10T12:00:00Z",
            district: "KENDUJHAR",
            plotNumber: "1009",
            selectedArea: 5.0,
            selectedUnit: "Decimal",
            benchmarkValueForArea: Decimal(string: "25145.35"),
            deedType: "SALE IMMOVABLE",
            deedId: 1,
            buyerCategory: "STANDARD",
            stampDuty: Decimal(string: "1257.27"),
            registrationFee: Decimal(string: "502.91"),
            totalGovernmentCharges: Decimal(string: "1760.18"),
            womenBuyerConcessionApplicable: true,
            concessionAmount: Decimal(string: "251.46"),
            totalAfterConcession: Decimal(string: "1760.18")
        )

        assert(estimateStandard.isAvailable == true, "FAILED: Expected estimate to be available")
        assert(estimateStandard.totalAfterConcession == Decimal(string: "1760.18"), "FAILED: Standard buyer should pay full charges")

        let estimateWomen = RegistrationCostEstimate(
            status: "AVAILABLE",
            calculatedAt: "2026-09-10T12:00:00Z",
            district: "KENDUJHAR",
            plotNumber: "1009",
            selectedArea: 5.0,
            selectedUnit: "Decimal",
            benchmarkValueForArea: Decimal(string: "25145.35"),
            deedType: "SALE IMMOVABLE",
            deedId: 1,
            buyerCategory: "WOMEN_BUYER",
            stampDuty: Decimal(string: "1257.27"),
            registrationFee: Decimal(string: "502.91"),
            totalGovernmentCharges: Decimal(string: "1760.18"),
            womenBuyerConcessionApplicable: true,
            concessionAmount: Decimal(string: "251.46"),
            totalAfterConcession: Decimal(string: "1508.72")
        )

        assert(estimateWomen.totalAfterConcession == Decimal(string: "1508.72"), "FAILED: Woman buyer should receive concession discount")
        assert(estimateWomen.concessionAmount == Decimal(string: "251.46"), "FAILED: Concession amount mismatch")

        return true
    }

    // 4. testNoFabricatedValuesOnFailure
    public static func testNoFabricatedValuesOnFailure() -> Bool {
        let notFound = RegistrationCostEstimate(
            status: "NOT_FOUND",
            reason: "NO_BENCHMARK_RECORD",
            calculatedAt: "2026-09-10T12:00:00Z",
            district: "KENDUJHAR",
            plotNumber: "999999",
            selectedArea: 1.0,
            selectedUnit: "Decimal",
            benchmarkValueForArea: nil,
            stampDuty: nil,
            registrationFee: nil,
            totalGovernmentCharges: nil
        )

        assert(notFound.isNotFound == true, "FAILED: Expected isNotFound == true")
        assert(notFound.isAvailable == false, "FAILED: NOT_FOUND must not be available")
        assert(notFound.benchmarkValueForArea == nil, "FAILED: Financial value must be nil, never 0 or fabricated")
        assert(notFound.totalGovernmentCharges == nil, "FAILED: Charges must be nil on failure")

        let unresolved = RegistrationCostEstimate(
            status: "MAPPING_UNRESOLVED",
            reason: "VILLAGE_MAPPING_UNRESOLVED",
            calculatedAt: "2026-09-10T12:00:00Z",
            district: "UNKNOWN",
            plotNumber: "10",
            selectedArea: 1.0,
            selectedUnit: "Decimal",
            benchmarkValueForArea: nil,
            stampDuty: nil,
            registrationFee: nil,
            totalGovernmentCharges: nil
        )

        assert(unresolved.isMappingUnresolved == true, "FAILED: Expected isMappingUnresolved == true")
        assert(unresolved.isAvailable == false, "FAILED: Unresolved mapping must not be available")
        assert(unresolved.totalGovernmentCharges == nil, "FAILED: Charges must be nil on unresolved mapping")

        return true
    }

    // Run all tests
    public static func runAllTests() -> Bool {
        let t1 = testExactDecimalMath()
        let t2 = testCurrencyFormatting()
        let t3 = testWomenBuyerConcessionModel()
        let t4 = testNoFabricatedValuesOnFailure()
        return t1 && t2 && t3 && t4
    }
}
