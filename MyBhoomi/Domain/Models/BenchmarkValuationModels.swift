//
//  BenchmarkValuationModels.swift
//  MyBhoomi
//
//  Normalized Domain Models for Odisha IGR Benchmark Valuation
//

import Foundation

public struct BenchmarkUnitRates: Codable, Hashable, Sendable {
    public let perAcre: Double
    public let perHectare: Double
    public let perDecimal100: Double
    public let perDecimal1000: Double
    public let perSquareMeter: Double
    public let perSquareFoot: Double

    enum CodingKeys: String, CodingKey {
        case perAcre = "per_acre"
        case perHectare = "per_hectare"
        case perDecimal100 = "per_decimal_100"
        case perDecimal1000 = "per_decimal_1000"
        case perSquareMeter = "per_square_meter"
        case perSquareFoot = "per_square_foot"
    }

    public init(
        perAcre: Double,
        perHectare: Double,
        perDecimal100: Double,
        perDecimal1000: Double,
        perSquareMeter: Double,
        perSquareFoot: Double
    ) {
        self.perAcre = perAcre
        self.perHectare = perHectare
        self.perDecimal100 = perDecimal100
        self.perDecimal1000 = perDecimal1000
        self.perSquareMeter = perSquareMeter
        self.perSquareFoot = perSquareFoot
    }

    public var formattedPerDecimal: String {
        BenchmarkValuationFormatter.formatCurrency(perDecimal100)
    }

    public var formattedPerAcre: String {
        BenchmarkValuationFormatter.formatCurrency(perAcre)
    }

    public var formattedPerHectare: String {
        BenchmarkValuationFormatter.formatCurrency(perHectare)
    }

    public var formattedPerSqFt: String {
        BenchmarkValuationFormatter.formatCurrency(perSquareFoot)
    }

    public var formattedPerSqMeter: String {
        BenchmarkValuationFormatter.formatCurrency(perSquareMeter)
    }

    public var formattedPerDecimal1000: String {
        BenchmarkValuationFormatter.formatCurrency(perDecimal1000)
    }
}

public struct BenchmarkCalculation: Codable, Hashable, Sendable {
    public let indicativeBenchmarkAmount: Double?
    public let calculationAvailable: Bool
    public let formula: String?
    public let ratePerDecimal: Double?

    enum CodingKeys: String, CodingKey {
        case indicativeBenchmarkAmount = "indicative_benchmark_amount"
        case calculationAvailable = "calculation_available"
        case formula
        case ratePerDecimal = "rate_per_decimal"
    }

    public init(
        indicativeBenchmarkAmount: Double? = nil,
        calculationAvailable: Bool = false,
        formula: String? = nil,
        ratePerDecimal: Double? = nil
    ) {
        self.indicativeBenchmarkAmount = indicativeBenchmarkAmount
        self.calculationAvailable = calculationAvailable
        self.formula = formula
        self.ratePerDecimal = ratePerDecimal
    }

    public var formattedAmount: String? {
        guard let amount = indicativeBenchmarkAmount else { return nil }
        return BenchmarkValuationFormatter.formatCurrency(amount)
    }
}

public struct IGRValuationCandidate: Codable, Hashable, Sendable, Identifiable {
    public var id: String {
        "\(registrationOfficeId):\(villageId)"
    }

    public let candidateToken: String
    public let registrationOfficeId: Int
    public let registrationOfficeName: String
    public let villageId: Int
    public let villageName: String
    public let thanaNumber: String?
    public let confidence: String
    public let score: Double
    public let matchReasons: [String]

    enum CodingKeys: String, CodingKey {
        case candidateToken = "candidate_token"
        case registrationOfficeId = "registration_office_id"
        case registrationOfficeName = "registration_office_name"
        case villageId = "village_id"
        case villageName = "village_name"
        case thanaNumber = "thana_number"
        case confidence
        case score
        case matchReasons = "match_reasons"
    }

    public init(
        candidateToken: String,
        registrationOfficeId: Int,
        registrationOfficeName: String,
        villageId: Int,
        villageName: String,
        thanaNumber: String? = nil,
        confidence: String = "medium",
        score: Double = 0.0,
        matchReasons: [String] = []
    ) {
        self.candidateToken = candidateToken
        self.registrationOfficeId = registrationOfficeId
        self.registrationOfficeName = registrationOfficeName
        self.villageId = villageId
        self.villageName = villageName
        self.thanaNumber = thanaNumber
        self.confidence = confidence
        self.score = score
        self.matchReasons = matchReasons
    }
}

public struct BenchmarkValuation: Codable, Hashable, Sendable, Identifiable {
    public var id: String {
        "\(district):\(registrationOffice ?? ""):\(villageThana ?? ""):\(plotNumber)"
    }

    public let status: String
    public let source: String
    public let sourceURL: String
    public let retrievedAt: String

    public let district: String
    public let registrationOffice: String?
    public let villageThana: String?
    public let kisam: String?
    public let plotNumber: String

    public let queryArea: Double
    public let queryUnit: String

    public let actualParcelArea: Double?
    public let actualParcelAreaUnit: String?

    public let areaWiseBenchmarkValue: Double?
    public let unitRates: BenchmarkUnitRates?

    public let highestTransactionValue: Double?
    public let transactionDate: String?

    public let stampDutyEstimate: Double?
    public let registrationFeeEstimate: Double?

    public let calculation: BenchmarkCalculation
    public let cached: Bool
    public let message: String?
    public let reason: String?

    public let candidates: [IGRValuationCandidate]?
    public let userAssistanceUsed: Bool?
    public let selectionMode: String?

    enum CodingKeys: String, CodingKey {
        case status
        case source
        case sourceURL = "source_url"
        case retrievedAt = "retrieved_at"
        case district
        case registrationOffice = "registration_office"
        case villageThana = "village_thana"
        case kisam
        case plotNumber = "plot_number"
        case queryArea = "query_area"
        case queryUnit = "query_unit"
        case actualParcelArea = "actual_parcel_area"
        case actualParcelAreaUnit = "actual_parcel_area_unit"
        case areaWiseBenchmarkValue = "area_wise_benchmark_value"
        case unitRates = "unit_rates"
        case highestTransactionValue = "highest_transaction_value"
        case transactionDate = "transaction_date"
        case stampDutyEstimate = "stamp_duty_estimate"
        case registrationFeeEstimate = "registration_fee_estimate"
        case calculation
        case cached
        case message
        case reason
        case candidates
        case userAssistanceUsed = "user_assistance_used"
        case selectionMode = "selection_mode"
    }

    public init(
        status: String,
        source: String = "Odisha Inspector General of Registration (IGR)",
        sourceURL: String = "https://igrodisha.gov.in/ViewFeeValue.aspx",
        retrievedAt: String,
        district: String,
        registrationOffice: String? = nil,
        villageThana: String? = nil,
        kisam: String? = nil,
        plotNumber: String,
        queryArea: Double = 1.0,
        queryUnit: String = "Decimal (100D=1Acre)",
        actualParcelArea: Double? = nil,
        actualParcelAreaUnit: String? = nil,
        areaWiseBenchmarkValue: Double? = nil,
        unitRates: BenchmarkUnitRates? = nil,
        highestTransactionValue: Double? = nil,
        transactionDate: String? = nil,
        stampDutyEstimate: Double? = nil,
        registrationFeeEstimate: Double? = nil,
        calculation: BenchmarkCalculation = BenchmarkCalculation(),
        cached: Bool = false,
        message: String? = nil,
        reason: String? = nil,
        candidates: [IGRValuationCandidate]? = nil,
        userAssistanceUsed: Bool? = nil,
        selectionMode: String? = nil
    ) {
        self.status = status
        self.source = source
        self.sourceURL = sourceURL
        self.retrievedAt = retrievedAt
        self.district = district
        self.registrationOffice = registrationOffice
        self.villageThana = villageThana
        self.kisam = kisam
        self.plotNumber = plotNumber
        self.queryArea = queryArea
        self.queryUnit = queryUnit
        self.actualParcelArea = actualParcelArea
        self.actualParcelAreaUnit = actualParcelAreaUnit
        self.areaWiseBenchmarkValue = areaWiseBenchmarkValue
        self.unitRates = unitRates
        self.highestTransactionValue = highestTransactionValue
        self.transactionDate = transactionDate
        self.stampDutyEstimate = stampDutyEstimate
        self.registrationFeeEstimate = registrationFeeEstimate
        self.calculation = calculation
        self.cached = cached
        self.message = message
        self.reason = reason
        self.candidates = candidates
        self.userAssistanceUsed = userAssistanceUsed
        self.selectionMode = selectionMode
    }

    public var isAvailable: Bool {
        status == "AVAILABLE" && unitRates != nil
    }

    public var isNotFound: Bool {
        status.uppercased() == "NOT_FOUND"
    }

    public var isAmbiguous: Bool {
        status.uppercased() == "AMBIGUOUS"
    }

    public var isMappingUnresolved: Bool {
        status.uppercased() == "MAPPING_UNRESOLVED"
    }

    public var isMappingRequiresUserSelection: Bool {
        status.uppercased() == "MAPPING_REQUIRES_USER_SELECTION"
    }

    public var isUserAssisted: Bool {
        userAssistanceUsed == true || selectionMode == "USER_ASSISTED"
    }

    public var isUnavailable: Bool {
        status.uppercased() == "UNAVAILABLE"
    }

    public var formattedRatePerDecimal: String {
        guard let rates = unitRates else { return "—" }
        return rates.formattedPerDecimal
    }

    public var formattedHighestTransactionValue: String? {
        guard let val = highestTransactionValue, val > 0 else { return nil }
        return BenchmarkValuationFormatter.formatCurrency(val)
    }
}

public enum BenchmarkValuationFormatter {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter
    }()

    private static let preciseCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter
    }()

    public static func formatCurrency(_ value: Double) -> String {
        let hasDecimals = value.truncatingRemainder(dividingBy: 1) != 0
        let formatter = hasDecimals ? preciseCurrencyFormatter : currencyFormatter
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}
