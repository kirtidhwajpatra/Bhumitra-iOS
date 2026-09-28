//
//  RegistrationCostModels.swift
//  MyBhoomi
//
//  Normalized Domain Models for Odisha IGR Registration Fee & Stamp Duty Estimation.
//  Uses exact Decimal arithmetic for currency and financial calculations.
//

import Foundation

public struct RegistrationCostEstimate: Codable, Hashable, Sendable, Identifiable {
    public var id: String {
        "\(district):\(registrationOffice ?? ""):\(villageThana ?? ""):\(plotNumber):\(selectedArea):\(selectedUnit):\(deedId):\(buyerCategory)"
    }

    public let status: String
    public let reason: String?
    public let source: String
    public let sourceURL: String
    public let calculatedAt: String

    public let district: String
    public let registrationOffice: String?
    public let villageThana: String?
    public let kisam: String?
    public let plotNumber: String

    public let selectedArea: Decimal
    public let selectedUnit: String

    // Official statutory rates
    public let benchmarkRatePerDecimal: Decimal?
    public let benchmarkRatePerAcre: Decimal?
    public let benchmarkRatePerHectare: Decimal?
    public let benchmarkRatePerSqMeter: Decimal?
    public let benchmarkRatePerSqFoot: Decimal?

    public let benchmarkValueForArea: Decimal?

    public let deedType: String
    public let deedId: Int
    public let buyerCategory: String

    // Statutory government charges
    public let stampDuty: Decimal?
    public let registrationFee: Decimal?
    public let totalGovernmentCharges: Decimal?

    // Concession breakdown
    public let womenBuyerConcessionApplicable: Bool
    public let concessionAmount: Decimal?
    public let totalAfterConcession: Decimal?

    public let formula: String?
    public let cached: Bool
    public let message: String?

    // User-assisted candidate jurisdictions
    public let candidates: [IGRValuationCandidate]?
    public let userAssistanceUsed: Bool?
    public let selectionMode: String?

    enum CodingKeys: String, CodingKey {
        case status
        case reason
        case source
        case sourceURL = "source_url"
        case calculatedAt = "calculated_at"
        case district
        case registrationOffice = "registration_office"
        case villageThana = "village_thana"
        case kisam
        case plotNumber = "plot_number"
        case selectedArea = "selected_area"
        case selectedUnit = "selected_unit"
        case benchmarkRatePerDecimal = "benchmark_rate_per_decimal"
        case benchmarkRatePerAcre = "benchmark_rate_per_acre"
        case benchmarkRatePerHectare = "benchmark_rate_per_hectare"
        case benchmarkRatePerSqMeter = "benchmark_rate_per_sq_meter"
        case benchmarkRatePerSqFoot = "benchmark_rate_per_sq_foot"
        case benchmarkValueForArea = "benchmark_value_for_area"
        case deedType = "deed_type"
        case deedId = "deed_id"
        case buyerCategory = "buyer_category"
        case stampDuty = "stamp_duty"
        case registrationFee = "registration_fee"
        case totalGovernmentCharges = "total_government_charges"
        case womenBuyerConcessionApplicable = "women_buyer_concession_applicable"
        case concessionAmount = "concession_amount"
        case totalAfterConcession = "total_after_concession"
        case formula
        case cached
        case message
        case candidates
        case userAssistanceUsed = "user_assistance_used"
        case selectionMode = "selection_mode"
    }

    public init(
        status: String,
        reason: String? = nil,
        source: String = "Odisha Inspector General of Registration (IGR)",
        sourceURL: String = "https://igrodisha.gov.in/StampDutyCalc.aspx",
        calculatedAt: String,
        district: String,
        registrationOffice: String? = nil,
        villageThana: String? = nil,
        kisam: String? = nil,
        plotNumber: String,
        selectedArea: Decimal = 1.0,
        selectedUnit: String = "Decimal",
        benchmarkRatePerDecimal: Decimal? = nil,
        benchmarkRatePerAcre: Decimal? = nil,
        benchmarkRatePerHectare: Decimal? = nil,
        benchmarkRatePerSqMeter: Decimal? = nil,
        benchmarkRatePerSqFoot: Decimal? = nil,
        benchmarkValueForArea: Decimal? = nil,
        deedType: String = "SALE IMMOVABLE",
        deedId: Int = 1,
        buyerCategory: String = "STANDARD",
        stampDuty: Decimal? = nil,
        registrationFee: Decimal? = nil,
        totalGovernmentCharges: Decimal? = nil,
        womenBuyerConcessionApplicable: Bool = false,
        concessionAmount: Decimal? = nil,
        totalAfterConcession: Decimal? = nil,
        formula: String? = nil,
        cached: Bool = false,
        message: String? = nil,
        candidates: [IGRValuationCandidate]? = nil,
        userAssistanceUsed: Bool? = nil,
        selectionMode: String? = nil
    ) {
        self.status = status
        self.reason = reason
        self.source = source
        self.sourceURL = sourceURL
        self.calculatedAt = calculatedAt
        self.district = district
        self.registrationOffice = registrationOffice
        self.villageThana = villageThana
        self.kisam = kisam
        self.plotNumber = plotNumber
        self.selectedArea = selectedArea
        self.selectedUnit = selectedUnit
        self.benchmarkRatePerDecimal = benchmarkRatePerDecimal
        self.benchmarkRatePerAcre = benchmarkRatePerAcre
        self.benchmarkRatePerHectare = benchmarkRatePerHectare
        self.benchmarkRatePerSqMeter = benchmarkRatePerSqMeter
        self.benchmarkRatePerSqFoot = benchmarkRatePerSqFoot
        self.benchmarkValueForArea = benchmarkValueForArea
        self.deedType = deedType
        self.deedId = deedId
        self.buyerCategory = buyerCategory
        self.stampDuty = stampDuty
        self.registrationFee = registrationFee
        self.totalGovernmentCharges = totalGovernmentCharges
        self.womenBuyerConcessionApplicable = womenBuyerConcessionApplicable
        self.concessionAmount = concessionAmount
        self.totalAfterConcession = totalAfterConcession
        self.formula = formula
        self.cached = cached
        self.message = message
        self.candidates = candidates
        self.userAssistanceUsed = userAssistanceUsed
        self.selectionMode = selectionMode
    }

    public var isAvailable: Bool {
        status == "AVAILABLE" && totalGovernmentCharges != nil
    }

    public var isNotFound: Bool {
        status.uppercased() == "NOT_FOUND"
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

    // MARK: - Formatted Currency Helpers (Exact Decimal)

    public var formattedBenchmarkValue: String {
        guard let val = benchmarkValueForArea else { return "—" }
        return RegistrationCostFormatter.format(val)
    }

    public var formattedStampDuty: String {
        guard let val = stampDuty else { return "—" }
        return RegistrationCostFormatter.format(val)
    }

    public var formattedRegistrationFee: String {
        guard let val = registrationFee else { return "—" }
        return RegistrationCostFormatter.format(val)
    }

    public var formattedTotalCharges: String {
        guard let val = totalGovernmentCharges else { return "—" }
        return RegistrationCostFormatter.format(val)
    }

    public var formattedConcessionAmount: String? {
        guard let val = concessionAmount, val > 0 else { return nil }
        return RegistrationCostFormatter.format(val)
    }

    public var formattedTotalAfterConcession: String {
        guard let val = totalAfterConcession else { return formattedTotalCharges }
        return RegistrationCostFormatter.format(val)
    }

    public var formattedRatePerDecimal: String {
        guard let val = benchmarkRatePerDecimal else { return "—" }
        return RegistrationCostFormatter.format(val)
    }
}

public struct IGRDeedOption: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String?
    public let womenConcessionEligible: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case womenConcessionEligible = "women_concession_eligible"
    }

    public init(id: Int, name: String, description: String? = nil, womenConcessionEligible: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.womenConcessionEligible = womenConcessionEligible
    }

    public static let standardDeeds: [IGRDeedOption] = [
        IGRDeedOption(id: 1, name: "SALE IMMOVABLE", description: "Standard sale conveyance", womenConcessionEligible: true),
        IGRDeedOption(id: 36, name: "GIFT IMMOVABLE", description: "Gift deed", womenConcessionEligible: true),
        IGRDeedOption(id: 34, name: "EXCHANGE OF PROPERTY ", description: "Exchange deed", womenConcessionEligible: false),
        IGRDeedOption(id: 49, name: "PARTITION", description: "Partition deed", womenConcessionEligible: false),
        IGRDeedOption(id: 56, name: "POA WITH POSSESSION", description: "Power of Attorney", womenConcessionEligible: false),
        IGRDeedOption(id: 77, name: "SETTLEMENT", description: "Settlement deed", womenConcessionEligible: false),
        IGRDeedOption(id: 190, name: "SALE IMMOVABLE WITH  AGREEMENT", description: "Sale with agreement", womenConcessionEligible: false),
    ]
}

public enum BuyerCategoryOption: String, CaseIterable, Identifiable, Sendable {
    case standard = "STANDARD"
    case womanBuyer = "WOMEN_BUYER"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .womanBuyer:
            return "Woman Buyer"
        }
    }

    public var subtitle: String {
        switch self {
        case .standard:
            return "Standard statutory 5% Stamp Duty"
        case .womanBuyer:
            return "1% statutory concession (4% Stamp Duty on Sale/Gift)"
        }
    }
}

public enum RegistrationCostFormatter {
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

    public static func format(_ value: Decimal) -> String {
        let doubleVal = NSDecimalNumber(decimal: value).doubleValue
        let hasDecimals = doubleVal.truncatingRemainder(dividingBy: 1) != 0
        let formatter = hasDecimals ? preciseCurrencyFormatter : currencyFormatter
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "₹\(doubleVal)"
    }
}
