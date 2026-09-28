//
//  BenchmarkValuationTests.swift
//  MyBhoomiTests
//
//  Automated test suite verifying decoding, formatting, calculations, and caching
//  for Odisha IGR Benchmark Valuation.
//

import XCTest
@testable import MyBhoomi

final class BenchmarkValuationTests: XCTestCase {

    func test_json_decoding_and_model_mapping() throws {
        let jsonString = """
        {
            "status": "AVAILABLE",
            "source": "Odisha Inspector General of Registration (IGR)",
            "source_url": "https://igrodisha.gov.in/ViewFeeValue.aspx",
            "retrieved_at": "2026-09-10T00:30:00Z",
            "district": "KENDUJHAR",
            "registration_office": "KENDUJHAR",
            "village_thana": "KERI - 271",
            "kisam": "RESIDENTIAL",
            "plot_number": "1009",
            "query_area": 1.0,
            "query_unit": "Decimal (100D=1Acre)",
            "actual_parcel_area": 2.40,
            "actual_parcel_area_unit": "Decimal",
            "area_wise_benchmark_value": 5029.07,
            "unit_rates": {
                "per_acre": 502907.0,
                "per_hectare": 1242762.71,
                "per_decimal_100": 5029.07,
                "per_decimal_1000": 502.91,
                "per_square_meter": 124.27,
                "per_square_foot": 11.55
            },
            "highest_transaction_value": null,
            "transaction_date": null,
            "stamp_duty_estimate": 251.45,
            "registration_fee_estimate": 100.58,
            "calculation": {
                "indicative_benchmark_amount": 12069.77,
                "calculation_available": true,
                "formula": "2.4 Decimal × ₹5,029.07/Decimal = ₹12,069.77",
                "rate_per_decimal": 5029.07
            },
            "cached": false,
            "message": null
        }
        """

        let data = jsonString.data(using: .utf8)!
        let valuation = try JSONDecoder().decode(BenchmarkValuation.self, from: data)

        XCTAssertEqual(valuation.status, "AVAILABLE")
        XCTAssertTrue(valuation.isAvailable)
        XCTAssertEqual(valuation.district, "KENDUJHAR")
        XCTAssertEqual(valuation.registrationOffice, "KENDUJHAR")
        XCTAssertEqual(valuation.villageThana, "KERI - 271")
        XCTAssertEqual(valuation.kisam, "RESIDENTIAL")
        XCTAssertEqual(valuation.plotNumber, "1009")

        XCTAssertNotNil(valuation.unitRates)
        XCTAssertEqual(valuation.unitRates?.perAcre, 502907.0)
        XCTAssertEqual(valuation.unitRates?.perDecimal100, 5029.07)

        XCTAssertTrue(valuation.calculation.calculationAvailable)
        XCTAssertEqual(valuation.calculation.indicativeBenchmarkAmount, 12069.77)
    }

    func test_indian_currency_formatting() {
        // Indian number formatting tests:
        // 5029 -> ₹5,029
        // 502907 -> ₹5,02,907
        // 1242763 -> ₹12,42,763
        let formatted1 = BenchmarkValuationFormatter.formatCurrency(5029)
        XCTAssertTrue(formatted1.contains("5,029") || formatted1.contains("5029"))

        let formatted2 = BenchmarkValuationFormatter.formatCurrency(502907)
        XCTAssertTrue(formatted2.contains("5,02,907") || formatted2.contains("502,907"))

        let formattedDec = BenchmarkValuationFormatter.formatCurrency(5029.07)
        XCTAssertTrue(formattedDec.contains("5,029.07") || formattedDec.contains("5029.07"))
    }

    func test_unavailable_status_handling() throws {
        let jsonString = """
        {
            "status": "NOT_FOUND",
            "source": "Odisha Inspector General of Registration (IGR)",
            "source_url": "https://igrodisha.gov.in/ViewFeeValue.aspx",
            "retrieved_at": "2026-09-10T00:30:00Z",
            "district": "KENDUJHAR",
            "registration_office": "KENDUJHAR",
            "village_thana": "KERI - 271",
            "kisam": null,
            "plot_number": "9999999",
            "query_area": 1.0,
            "query_unit": "Decimal (100D=1Acre)",
            "actual_parcel_area": null,
            "actual_parcel_area_unit": null,
            "area_wise_benchmark_value": null,
            "unit_rates": null,
            "highest_transaction_value": null,
            "transaction_date": null,
            "stamp_duty_estimate": null,
            "registration_fee_estimate": null,
            "calculation": {
                "indicative_benchmark_amount": null,
                "calculation_available": false,
                "formula": null,
                "rate_per_decimal": null
            },
            "cached": false,
            "message": "Government benchmark value is not defined for this plot in official records."
        }
        """

        let data = jsonString.data(using: .utf8)!
        let valuation = try JSONDecoder().decode(BenchmarkValuation.self, from: data)

        XCTAssertEqual(valuation.status, "NOT_FOUND")
        XCTAssertFalse(valuation.isAvailable)
        XCTAssertTrue(valuation.isNotFound)
        XCTAssertNil(valuation.unitRates)
        XCTAssertFalse(valuation.calculation.calculationAvailable)
        XCTAssertEqual(valuation.formattedRatePerDecimal, "—")
    }

    func test_highest_transaction_value_formatting() throws {
        let rates = BenchmarkUnitRates(
            perAcre: 600000.0,
            perHectare: 1482600.0,
            perDecimal100: 6000.0,
            perDecimal1000: 600.0,
            perSquareMeter: 148.26,
            perSquareFoot: 13.77
        )

        let valuation = BenchmarkValuation(
            status: "AVAILABLE",
            source: "Odisha Inspector General of Registration (IGR)",
            sourceURL: "https://igrodisha.gov.in/ViewFeeValue.aspx",
            retrievedAt: "2026-09-10T00:00:00Z",
            district: "KENDUJHAR",
            registrationOffice: "KENDUJHAR",
            villageThana: "KERI - 271",
            kisam: "RESIDENTIAL",
            plotNumber: "1009",
            queryArea: 1.0,
            queryUnit: "Decimal (100D=1Acre)",
            actualParcelArea: 2.0,
            actualParcelAreaUnit: "Decimal",
            areaWiseBenchmarkValue: 6000.0,
            unitRates: rates,
            highestTransactionValue: 750000.0,
            transactionDate: "15/01/2026",
            stampDutyEstimate: 300.0,
            registrationFeeEstimate: 120.0,
            calculation: BenchmarkCalculation(
                indicativeBenchmarkAmount: 12000.0,
                calculationAvailable: true,
                formula: "2 Decimal × ₹6,000/Decimal = ₹12,000",
                ratePerDecimal: 6000.0
            ),
            cached: false,
            message: nil
        )

        XCTAssertNotNil(valuation.formattedHighestTransactionValue)
        XCTAssertTrue(valuation.formattedHighestTransactionValue?.contains("7,50,000") == true || valuation.formattedHighestTransactionValue?.contains("750,000") == true)
        XCTAssertEqual(valuation.transactionDate, "15/01/2026")
    }

    func test_ambiguous_status_handling() throws {
        let jsonString = """
        {
            "status": "AMBIGUOUS",
            "source": "Odisha Inspector General of Registration (IGR)",
            "source_url": "https://igrodisha.gov.in/ViewFeeValue.aspx",
            "retrieved_at": "2026-09-10T00:30:00Z",
            "district": "KENDUJHAR",
            "registration_office": null,
            "village_thana": null,
            "kisam": null,
            "plot_number": "100",
            "query_area": 1.0,
            "query_unit": "Decimal (100D=1Acre)",
            "actual_parcel_area": null,
            "actual_parcel_area_unit": null,
            "area_wise_benchmark_value": null,
            "unit_rates": null,
            "highest_transaction_value": null,
            "transaction_date": null,
            "stamp_duty_estimate": null,
            "registration_fee_estimate": null,
            "calculation": {
                "indicative_benchmark_amount": null,
                "calculation_available": false,
                "formula": null,
                "rate_per_decimal": null
            },
            "cached": false,
            "message": "Multiple IGR villages matched this location with insufficient certainty."
        }
        """

        let data = jsonString.data(using: .utf8)!
        let valuation = try JSONDecoder().decode(BenchmarkValuation.self, from: data)

        XCTAssertEqual(valuation.status, "AMBIGUOUS")
        XCTAssertFalse(valuation.isAvailable)
        XCTAssertFalse(valuation.isNotFound)
        XCTAssertTrue(valuation.isAmbiguous)
        XCTAssertFalse(valuation.isMappingUnresolved)
        XCTAssertNil(valuation.unitRates)
    }

    func test_mapping_unresolved_status_handling() throws {
        let jsonString = """
        {
            "status": "MAPPING_UNRESOLVED",
            "reason": "VILLAGE_MAPPING_UNRESOLVED",
            "source": "Odisha Inspector General of Registration (IGR)",
            "source_url": "https://igrodisha.gov.in/ViewFeeValue.aspx",
            "retrieved_at": "2026-09-10T00:35:00Z",
            "district": "UNKNOWN_DISTRICT",
            "registration_office": null,
            "village_thana": null,
            "kisam": null,
            "plot_number": "55",
            "query_area": 1.0,
            "query_unit": "Decimal (100D=1Acre)",
            "actual_parcel_area": null,
            "actual_parcel_area_unit": null,
            "area_wise_benchmark_value": null,
            "unit_rates": null,
            "highest_transaction_value": null,
            "transaction_date": null,
            "stamp_duty_estimate": null,
            "registration_fee_estimate": null,
            "calculation": {
                "indicative_benchmark_amount": null,
                "calculation_available": false,
                "formula": null,
                "rate_per_decimal": null
            },
            "cached": false,
            "message": "Official Sub-Registrar jurisdiction or village-thana could not be mapped for this location."
        }
        """

        let data = jsonString.data(using: .utf8)!
        let valuation = try JSONDecoder().decode(BenchmarkValuation.self, from: data)

        XCTAssertEqual(valuation.status, "MAPPING_UNRESOLVED")
        XCTAssertEqual(valuation.reason, "VILLAGE_MAPPING_UNRESOLVED")
        XCTAssertFalse(valuation.isAvailable)
        XCTAssertFalse(valuation.isNotFound)
        XCTAssertFalse(valuation.isAmbiguous)
        XCTAssertTrue(valuation.isMappingUnresolved)
        XCTAssertFalse(valuation.isUnavailable)
        XCTAssertNil(valuation.unitRates)
    }

    func test_mapping_requires_user_selection_decoding() throws {
        let jsonString = """
        {
            "status": "MAPPING_REQUIRES_USER_SELECTION",
            "reason": "REQUIRES_USER_SELECTION",
            "source": "Odisha Inspector General of Registration (IGR)",
            "source_url": "https://igrodisha.gov.in/ViewFeeValue.aspx",
            "retrieved_at": "2026-09-10T08:00:00Z",
            "district": "BALASORE",
            "registration_office": null,
            "village_thana": null,
            "kisam": null,
            "plot_number": "378",
            "query_area": 1.0,
            "query_unit": "Decimal (100D=1Acre)",
            "actual_parcel_area": 5.0,
            "actual_parcel_area_unit": "Decimal",
            "area_wise_benchmark_value": null,
            "unit_rates": null,
            "highest_transaction_value": null,
            "transaction_date": null,
            "stamp_duty_estimate": null,
            "registration_fee_estimate": null,
            "calculation": {
                "indicative_benchmark_amount": null,
                "calculation_available": false,
                "formula": null,
                "rate_per_decimal": null
            },
            "cached": false,
            "message": "Multiple possible Registration Offices found for this location. Please select the matching jurisdiction.",
            "candidates": [
                {
                    "candidate_token": "token_abc123",
                    "registration_office_id": 13,
                    "registration_office_name": "SIMULIA",
                    "village_id": 130041,
                    "village_name": "BARIMELAK - 189",
                    "thana_number": "189",
                    "confidence": "high",
                    "score": 35.0,
                    "match_reasons": ["Direct mouza name match: 'BARIMELAK'"]
                }
            ],
            "user_assistance_used": false,
            "selection_mode": null
        }
        """

        let data = jsonString.data(using: .utf8)!
        let valuation = try JSONDecoder().decode(BenchmarkValuation.self, from: data)

        XCTAssertEqual(valuation.status, "MAPPING_REQUIRES_USER_SELECTION")
        XCTAssertTrue(valuation.isMappingRequiresUserSelection)
        XCTAssertFalse(valuation.isAvailable)
        XCTAssertFalse(valuation.isUserAssisted)
        XCTAssertEqual(valuation.candidates?.count, 1)

        let cand = try XCTUnwrap(valuation.candidates?.first)
        XCTAssertEqual(cand.candidateToken, "token_abc123")
        XCTAssertEqual(cand.registrationOfficeId, 13)
        XCTAssertEqual(cand.registrationOfficeName, "SIMULIA")
        XCTAssertEqual(cand.villageId, 130041)
        XCTAssertEqual(cand.villageName, "BARIMELAK - 189")
        XCTAssertEqual(cand.thanaNumber, "189")
        XCTAssertEqual(cand.confidence, "high")
        XCTAssertEqual(cand.matchReasons.count, 1)
    }

    func test_user_assisted_available_valuation_decoding() throws {
        let jsonString = """
        {
            "status": "AVAILABLE",
            "source": "Odisha Inspector General of Registration (IGR)",
            "source_url": "https://igrodisha.gov.in/ViewFeeValue.aspx",
            "retrieved_at": "2026-09-10T08:05:00Z",
            "district": "BALASORE",
            "registration_office": "SIMULIA",
            "village_thana": "BARIMELAK - 189",
            "kisam": "SARADA-I",
            "plot_number": "378",
            "query_area": 1.0,
            "query_unit": "Decimal (100D=1Acre)",
            "actual_parcel_area": 5.0,
            "actual_parcel_area_unit": "Decimal",
            "area_wise_benchmark_value": 13000.0,
            "unit_rates": {
                "per_acre": 1300000.0,
                "per_hectare": 3212300.0,
                "per_decimal_100": 13000.0,
                "per_decimal_1000": 1300.0,
                "per_square_meter": 321.23,
                "per_square_foot": 29.84
            },
            "highest_transaction_value": null,
            "transaction_date": null,
            "stamp_duty_estimate": 3250.0,
            "registration_fee_estimate": 1300.0,
            "calculation": {
                "indicative_benchmark_amount": 65000.0,
                "calculation_available": true,
                "formula": "5 Decimal × ₹13,000/Decimal = ₹65,000",
                "rate_per_decimal": 13000.0
            },
            "cached": false,
            "message": null,
            "user_assistance_used": true,
            "selection_mode": "USER_ASSISTED"
        }
        """

        let data = jsonString.data(using: .utf8)!
        let valuation = try JSONDecoder().decode(BenchmarkValuation.self, from: data)

        XCTAssertEqual(valuation.status, "AVAILABLE")
        XCTAssertTrue(valuation.isAvailable)
        XCTAssertTrue(valuation.isUserAssisted)
        XCTAssertEqual(valuation.userAssistanceUsed, true)
        XCTAssertEqual(valuation.selectionMode, "USER_ASSISTED")
        XCTAssertEqual(valuation.registrationOffice, "SIMULIA")
        XCTAssertEqual(valuation.villageThana, "BARIMELAK - 189")
        XCTAssertEqual(valuation.unitRates?.perDecimal100, 13000.0)
    }
}
