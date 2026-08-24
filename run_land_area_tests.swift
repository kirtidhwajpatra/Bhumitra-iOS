#!/usr/bin/env swift
import Foundation

// MARK: - Models

public enum LandAreaRegion: String, Codable, CaseIterable, Identifiable {
    case odisha = "odisha"
    case nationalStandard = "national"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .odisha: return "Odisha"
        case .nationalStandard: return "National (Standard)"
        }
    }
    
    public var shortName: String {
        switch self {
        case .odisha: return "Odisha"
        case .nationalStandard: return "Standard"
        }
    }
}

public enum LandAreaCategory: String, Codable, CaseIterable {
    case primary = "Primary Units"
    case regional = "Regional Units"
    case metric = "Standard Metric"
}

public enum LandAreaUnit: String, Codable, CaseIterable, Identifiable {
    case acres = "acre"
    case decimal = "decimal"
    case squareFeet = "sq_ft"
    case squareMeters = "sq_m"
    case squareYards = "gaj"
    case hectares = "hectare"
    
    case guntha = "guntha"
    case mana = "mana"
    case bighaOdisha = "bigha_odisha"
    case kathaOdisha = "katha_odisha"
    case cent = "cent"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .acres: return "Acre"
        case .decimal: return "Decimal"
        case .squareFeet: return "Square Feet"
        case .squareMeters: return "Square Meters"
        case .squareYards: return "Square Yard (Gaj)"
        case .hectares: return "Hectare"
        case .guntha: return "Guntha"
        case .mana: return "Mana"
        case .bighaOdisha: return "Bigha"
        case .kathaOdisha: return "Katha / Biswa"
        case .cent: return "Cent"
        }
    }

    public var symbol: String {
        switch self {
        case .acres: return "ac"
        case .decimal: return "dec"
        case .squareFeet: return "sq ft"
        case .squareMeters: return "sq m"
        case .squareYards: return "sq yd / gaj"
        case .hectares: return "ha"
        case .guntha: return "guntha"
        case .mana: return "mana"
        case .bighaOdisha: return "bigha"
        case .kathaOdisha: return "katha"
        case .cent: return "cent"
        }
    }

    public var category: LandAreaCategory {
        switch self {
        case .acres, .decimal, .squareFeet, .squareMeters, .squareYards:
            return .primary
        case .hectares:
            return .metric
        case .guntha, .mana, .bighaOdisha, .kathaOdisha, .cent:
            return .regional
        }
    }
    
    public var isUniversal: Bool {
        switch self {
        case .acres, .decimal, .squareFeet, .squareMeters, .squareYards, .hectares, .cent:
            return true
        case .guntha, .mana, .bighaOdisha, .kathaOdisha:
            return false
        }
    }
    
    public func isSupported(in region: LandAreaRegion) -> Bool {
        if isUniversal { return true }
        switch region {
        case .odisha:
            return true
        case .nationalStandard:
            return false
        }
    }

    public func sqMetersPerUnit(in region: LandAreaRegion = .odisha) -> Double? {
        guard isSupported(in: region) else { return nil }
        
        switch self {
        case .acres:
            return 4046.8564224
        case .decimal:
            return 40.468564224
        case .squareFeet:
            return 0.09290304
        case .squareMeters:
            return 1.0
        case .squareYards:
            return 0.83612736
        case .hectares:
            return 10000.0
        case .guntha:
            return 161.874256896
        case .mana:
            return 4046.8564224
        case .bighaOdisha:
            return 1348.9521408
        case .kathaOdisha:
            return 67.44760704
        case .cent:
            return 40.468564224
        }
    }

    public func format(value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        
        if abs(value.rounded() - value) < 0.0001 && value < 100_000_000 {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        } else {
            switch self {
            case .decimal, .cent, .squareFeet, .squareYards, .squareMeters, .guntha, .mana, .bighaOdisha, .kathaOdisha:
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
            case .acres, .hectares:
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 4
            }
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    public func format(sqMeters: Double, in region: LandAreaRegion = .odisha) -> String? {
        guard let factor = sqMetersPerUnit(in: region), factor > 0 else { return nil }
        let value = sqMeters / factor
        return format(value: value)
    }
}

public struct LandAreaConversionItem: Identifiable, Equatable {
    public var id: String { unit.id }
    public let unit: LandAreaUnit
    public let formattedValue: String
    public let rawValue: Double
    public let symbol: String
    public let isPrimary: Bool
    
    public init?(
        unit: LandAreaUnit,
        sqMeters: Double,
        region: LandAreaRegion = .odisha,
        isPrimary: Bool = true
    ) {
        guard let formatted = unit.format(sqMeters: sqMeters, in: region),
              let factor = unit.sqMetersPerUnit(in: region) else {
            return nil
        }
        self.unit = unit
        self.formattedValue = formatted
        self.rawValue = sqMeters / factor
        self.symbol = unit.symbol
        self.isPrimary = isPrimary
    }
}

// MARK: - Converter Service

public enum LandAreaUnitConverter {
    public static func convert(
        value: Double,
        from sourceUnit: LandAreaUnit,
        to targetUnit: LandAreaUnit,
        in region: LandAreaRegion = .odisha
    ) -> Double? {
        guard value >= 0 else { return nil }
        guard let sqMeters = toSqMeters(value: value, from: sourceUnit, in: region) else { return nil }
        return fromSqMeters(sqMeters, to: targetUnit, in: region)
    }
    
    public static func toSqMeters(
        value: Double,
        from unit: LandAreaUnit,
        in region: LandAreaRegion = .odisha
    ) -> Double? {
        guard value >= 0 else { return nil }
        guard let factor = unit.sqMetersPerUnit(in: region) else { return nil }
        return value * factor
    }
    
    public static func fromSqMeters(
        _ sqMeters: Double,
        to unit: LandAreaUnit,
        in region: LandAreaRegion = .odisha
    ) -> Double? {
        guard sqMeters >= 0 else { return nil }
        guard let factor = unit.sqMetersPerUnit(in: region), factor > 0 else { return nil }
        return sqMeters / factor
    }
    
    public static func parseToSqMeters(from rawArea: String?, in region: LandAreaRegion = .odisha) -> Double? {
        guard let raw = rawArea?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "—", raw != "-" else {
            return nil
        }
        
        let acreDecPattern = #"(\d+(?:\.\d+)?)\s*(?:Acre|Acres|Ac|A)\s+(\d+(?:\.\d+)?)\s*(?:Decimal|Decimals|Dec|D)?"#
        if let regex = try? NSRegularExpression(pattern: acreDecPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rAcre = Range(match.range(at: 1), in: raw),
               let rDec = Range(match.range(at: 2), in: raw) {
                let acreVal = Double(raw[rAcre]) ?? 0.0
                let decStr = String(raw[rDec])
                let decVal = parseDecimalTokenToDecimals(decStr)
                let totalAcres = acreVal + (decVal / 100.0)
                guard let acreSqM = LandAreaUnit.acres.sqMetersPerUnit(in: region) else { return nil }
                return totalAcres * acreSqM
            }
        }
        
        let decOnlyPattern = #"^(\d+(?:\.\d+)?)\s*(?:Decimal|Decimals|Dec|D)$"#
        if let regex = try? NSRegularExpression(pattern: decOnlyPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rDec = Range(match.range(at: 1), in: raw) {
                let decStr = String(raw[rDec])
                let decVal = parseDecimalTokenToDecimals(decStr)
                guard let decSqM = LandAreaUnit.decimal.sqMetersPerUnit(in: region) else { return nil }
                return decVal * decSqM
            }
        }
        
        let acreOnlyPattern = #"^(\d+(?:\.\d+)?)\s*(?:Acre|Acres|Ac|A)$"#
        if let regex = try? NSRegularExpression(pattern: acreOnlyPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rAcre = Range(match.range(at: 1), in: raw),
               let acreVal = Double(raw[rAcre]) {
                guard let acreSqM = LandAreaUnit.acres.sqMetersPerUnit(in: region) else { return nil }
                return acreVal * acreSqM
            }
        }
        
        let cleanNumeric = raw.replacingOccurrences(of: ",", with: "")
        if let num = Double(cleanNumeric), num >= 0 {
            guard let acreSqM = LandAreaUnit.acres.sqMetersPerUnit(in: region) else { return nil }
            return num * acreSqM
        }
        
        return nil
    }
    
    public static func parseStructuredExtent(from rawArea: String?) -> (value: Double, unit: LandAreaUnit)? {
        guard let raw = rawArea?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "—", raw != "-" else {
            return nil
        }
        
        let acreDecPattern = #"(\d+(?:\.\d+)?)\s*(?:Acre|Acres|Ac|A)\s+(\d+(?:\.\d+)?)\s*(?:Decimal|Decimals|Dec|D)?"#
        if let regex = try? NSRegularExpression(pattern: acreDecPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rAcre = Range(match.range(at: 1), in: raw),
               let rDec = Range(match.range(at: 2), in: raw) {
                let acreVal = Double(raw[rAcre]) ?? 0.0
                let decStr = String(raw[rDec])
                let decVal = parseDecimalTokenToDecimals(decStr)
                
                if acreVal == 0.0 && decVal > 0 {
                    return (decVal, .decimal)
                } else if acreVal > 0.0 && decVal == 0.0 {
                    return (acreVal, .acres)
                } else if acreVal > 0.0 && decVal > 0.0 {
                    let totalDecimals = (acreVal * 100.0) + decVal
                    return (totalDecimals, .decimal)
                } else {
                    return (0.0, .acres)
                }
            }
        }
        
        let decOnlyPattern = #"^(\d+(?:\.\d+)?)\s*(?:Decimal|Decimals|Dec|D)$"#
        if let regex = try? NSRegularExpression(pattern: decOnlyPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rDec = Range(match.range(at: 1), in: raw) {
                let decStr = String(raw[rDec])
                let decVal = parseDecimalTokenToDecimals(decStr)
                return (decVal, .decimal)
            }
        }
        
        let acreOnlyPattern = #"^(\d+(?:\.\d+)?)\s*(?:Acre|Acres|Ac|A)$"#
        if let regex = try? NSRegularExpression(pattern: acreOnlyPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rAcre = Range(match.range(at: 1), in: raw),
               let acreVal = Double(raw[rAcre]) {
                return (acreVal, .acres)
            }
        }
        
        let cleanNumeric = raw.replacingOccurrences(of: ",", with: "")
        if let num = Double(cleanNumeric), num >= 0 {
            return (num, .acres)
        }
        
        return nil
    }
    
    public static func parseDecimalTokenToDecimals(_ token: String) -> Double {
        let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let num = Double(clean) else { return 0.0 }
        
        if clean.contains(".") {
            return num
        }
        if clean.count == 4 {
            return num / 100.0
        }
        if clean.count == 3 {
            return num / 10.0
        }
        return num
    }
}

// MARK: - ViewModel Simulation

public final class LandAreaConverterViewModel {
    public var inputValueString: String = "1" { didSet { recalculate() } }
    public var sourceUnit: LandAreaUnit = .acres { didSet { recalculate() } }
    public var targetUnit: LandAreaUnit = .decimal { didSet { recalculate() } }
    public var selectedRegion: LandAreaRegion = .odisha { didSet { recalculate() } }
    
    public var parcelContext: String? = nil
    public var officialAreaString: String? = nil
    
    public var convertedValueFormatted: String = ""
    public var convertedRawValue: Double? = nil
    public var isConversionAvailable: Bool = true
    
    public init(officialArea: String? = nil, parcelContext: String? = nil, defaultRegion: LandAreaRegion = .odisha) {
        self.selectedRegion = defaultRegion
        self.parcelContext = parcelContext
        
        let cleanOfficial = officialArea?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let clean = cleanOfficial, !clean.isEmpty, clean != "—", clean != "-" {
            self.officialAreaString = clean
            if let structured = LandAreaUnitConverter.parseStructuredExtent(from: clean) {
                self.sourceUnit = structured.unit
                self.inputValueString = structured.unit.format(value: structured.value)
                switch structured.unit {
                case .decimal: self.targetUnit = .squareFeet
                case .acres: self.targetUnit = .decimal
                default: self.targetUnit = .acres
                }
            }
        } else {
            self.inputValueString = "1"
            self.sourceUnit = .acres
            self.targetUnit = .decimal
        }
        recalculate()
    }
    
    public func recalculate() {
        let cleanedInput = inputValueString.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedInput.isEmpty else {
            self.convertedValueFormatted = "—"
            self.convertedRawValue = nil
            self.isConversionAvailable = true
            return
        }
        guard let num = Double(cleanedInput), num >= 0 else {
            self.convertedValueFormatted = "Invalid"
            self.convertedRawValue = nil
            self.isConversionAvailable = false
            return
        }
        if let sqM = LandAreaUnitConverter.toSqMeters(value: num, from: sourceUnit, in: selectedRegion) {
            if let converted = LandAreaUnitConverter.fromSqMeters(sqM, to: targetUnit, in: selectedRegion) {
                self.convertedRawValue = converted
                self.convertedValueFormatted = targetUnit.format(value: converted)
                self.isConversionAvailable = true
            } else {
                self.convertedRawValue = nil
                self.convertedValueFormatted = "Unavailable"
                self.isConversionAvailable = false
            }
        } else {
            self.convertedRawValue = nil
            self.convertedValueFormatted = "Unavailable"
            self.isConversionAvailable = false
        }
    }
    
    public func swapUnits() {
        let oldSource = sourceUnit
        let oldTarget = targetUnit
        if let converted = convertedRawValue {
            sourceUnit = oldTarget
            targetUnit = oldSource
            inputValueString = oldTarget.format(value: converted)
        } else {
            sourceUnit = oldTarget
            targetUnit = oldSource
        }
    }
}

// MARK: - Execute All Tests

var passed = 0
var failed = 0
var errors: [String] = []

func runTest(_ name: String, _ block: () -> Bool) {
    if block() {
        passed += 1
        print("  ✓ \(name): PASSED")
    } else {
        failed += 1
        let err = "  ✗ \(name): FAILED"
        errors.append(err)
        print(err)
    }
}

print("============================================================")
print("BHUMITRA LAND AREA CONVERTER SPECIFICATION TEST SUITE")
print("============================================================")

runTest("1. 1 Acre -> 100 Decimal") {
    let res = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .decimal, in: .odisha)
    return res != nil && abs(res! - 100.0) < 0.0001
}

runTest("2. 1 Acre -> 43,560 Square Feet") {
    let res = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .squareFeet, in: .odisha)
    return res != nil && abs(res! - 43560.0) < 0.01
}

runTest("3. 1 Acre -> 4,046.856 Square Meter") {
    let res = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .squareMeters, in: .odisha)
    return res != nil && abs(res! - 4046.8564) < 0.01
}

runTest("4. 1 Acre -> 4,840 Square Yard (Gaj)") {
    let res = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .squareYards, in: .odisha)
    return res != nil && abs(res! - 4840.0) < 0.01
}

runTest("5. 0 Acre 3400 Decimal -> 34 Decimal (G_Baliabeda)") {
    guard let parsed = LandAreaUnitConverter.parseStructuredExtent(from: "0 Acre 3400 Decimal") else { return false }
    guard parsed.unit == .decimal && abs(parsed.value - 34.0) < 0.001 else { return false }
    guard let sqM = LandAreaUnitConverter.parseToSqMeters(from: "0 Acre 3400 Decimal") else { return false }
    let sqFt = LandAreaUnitConverter.fromSqMeters(sqM, to: .squareFeet) ?? 0
    return abs(sqFt - 14810.4) < 0.1
}

runTest("6. 1 Acre 4200 Decimal -> 142 Decimal / 1.42 Acre (Chandakuda)") {
    guard let parsed = LandAreaUnitConverter.parseStructuredExtent(from: "1 Acre 4200 Decimal") else { return false }
    guard parsed.unit == .decimal && abs(parsed.value - 142.0) < 0.001 else { return false }
    guard let sqM = LandAreaUnitConverter.parseToSqMeters(from: "1 Acre 4200 Decimal") else { return false }
    let acres = LandAreaUnitConverter.fromSqMeters(sqM, to: .acres) ?? 0
    let sqFt = LandAreaUnitConverter.fromSqMeters(sqM, to: .squareFeet) ?? 0
    return abs(acres - 1.42) < 0.001 && abs(sqFt - 61855.2) < 0.1
}

runTest("7. 0 Acre 0270 Decimal -> 2.7 Decimal / 0.027 Acre (Buxibazar)") {
    guard let parsed = LandAreaUnitConverter.parseStructuredExtent(from: "0 Acre 0270 Decimal") else { return false }
    guard parsed.unit == .decimal && abs(parsed.value - 2.7) < 0.001 else { return false }
    guard let sqM = LandAreaUnitConverter.parseToSqMeters(from: "0 Acre 0270 Decimal") else { return false }
    let acres = LandAreaUnitConverter.fromSqMeters(sqM, to: .acres) ?? 0
    return abs(acres - 0.027) < 0.0001
}

runTest("8. Decimal -> Acre") {
    let res = LandAreaUnitConverter.convert(value: 100.0, from: .decimal, to: .acres)
    return res != nil && abs(res! - 1.0) < 0.0001
}

runTest("9. Square Feet -> Acre") {
    let res = LandAreaUnitConverter.convert(value: 43560.0, from: .squareFeet, to: .acres)
    return res != nil && abs(res! - 1.0) < 0.0001
}

runTest("10. Square Meter -> Acre") {
    let res = LandAreaUnitConverter.convert(value: 4046.8564224, from: .squareMeters, to: .acres)
    return res != nil && abs(res! - 1.0) < 0.0001
}

runTest("11. Square Yard -> Acre") {
    let res = LandAreaUnitConverter.convert(value: 4840.0, from: .squareYards, to: .acres)
    return res != nil && abs(res! - 1.0) < 0.0001
}

runTest("12. Swap behavior (1 Acre <-> 100 Decimal)") {
    let vm = LandAreaConverterViewModel()
    vm.inputValueString = "1"
    vm.sourceUnit = .acres
    vm.targetUnit = .decimal
    guard vm.convertedValueFormatted == "100" else { return false }
    vm.swapUnits()
    return vm.sourceUnit == .decimal &&
           vm.targetUnit == .acres &&
           vm.inputValueString == "100" &&
           vm.convertedValueFormatted == "1"
}

runTest("13. Typing updates result immediately (2, 0.5, 1.25)") {
    let vm = LandAreaConverterViewModel()
    vm.sourceUnit = .acres
    vm.targetUnit = .decimal
    vm.inputValueString = "2"
    guard vm.convertedValueFormatted == "200" else { return false }
    vm.inputValueString = "0.5"
    guard vm.convertedValueFormatted == "50" else { return false }
    vm.inputValueString = "1.25"
    guard vm.convertedValueFormatted == "125" else { return false }
    return true
}

runTest("14. Invalid input handling") {
    let vm = LandAreaConverterViewModel()
    vm.inputValueString = "abc"
    return vm.convertedValueFormatted == "Invalid" && !vm.isConversionAvailable
}

runTest("15. Empty input handling") {
    let vm = LandAreaConverterViewModel()
    vm.inputValueString = ""
    return vm.convertedValueFormatted == "—" && vm.isConversionAvailable
}

runTest("16. Zero input handling") {
    let vm = LandAreaConverterViewModel()
    vm.inputValueString = "0"
    return vm.convertedValueFormatted == "0" && vm.convertedRawValue == 0.0
}

runTest("17. Large values precision") {
    let vm = LandAreaConverterViewModel()
    vm.inputValueString = "1000"
    vm.sourceUnit = .acres
    vm.targetUnit = .squareFeet
    guard let raw = vm.convertedRawValue else { return false }
    return abs(raw - 43560000.0) < 0.1 && !vm.convertedValueFormatted.isEmpty
}

runTest("18. Rounding & display formatting") {
    let acreFormatted = LandAreaUnit.acres.format(value: 0.34)
    let sqFtFormatted = LandAreaUnit.squareFeet.format(value: 14810.4)
    let sqMFormatted = LandAreaUnit.squareMeters.format(value: 4046.86)
    return acreFormatted == "0.34" && sqFtFormatted == "14,810.4" && sqMFormatted == "4,046.86"
}

runTest("19. Regional unit safety & unavailability (No fake conversions)") {
    let bighaInOdisha = LandAreaUnitConverter.convert(value: 1.0, from: .bighaOdisha, to: .squareFeet, in: .odisha)
    guard let odishaSqFt = bighaInOdisha, abs(odishaSqFt - 14520.0) < 0.1 else { return false }
    let bighaInNational = LandAreaUnitConverter.convert(value: 1.0, from: .bighaOdisha, to: .squareFeet, in: .nationalStandard)
    return bighaInNational == nil
}

runTest("20. Parcel prefill (Plot 45 G_Baliabeda)") {
    let vm = LandAreaConverterViewModel(
        officialArea: "0 Acre 3400 Decimal",
        parcelContext: "Plot 45 • G_Baliabeda"
    )
    return vm.parcelContext == "Plot 45 • G_Baliabeda" &&
           vm.officialAreaString == "0 Acre 3400 Decimal" &&
           vm.sourceUnit == .decimal &&
           vm.inputValueString == "34" &&
           vm.targetUnit == .squareFeet &&
           vm.convertedValueFormatted == "14,810.4"
}

runTest("21. Manual editing after parcel prefill") {
    let vm = LandAreaConverterViewModel(
        officialArea: "0 Acre 3400 Decimal",
        parcelContext: "Plot 45 • G_Baliabeda"
    )
    vm.inputValueString = "1"
    vm.sourceUnit = .decimal
    vm.targetUnit = .acres
    return vm.convertedValueFormatted == "0.01" &&
           vm.officialAreaString == "0 Acre 3400 Decimal"
}

runTest("22. Odisha regional units ratios (Guntha, Mana, Katha, Cent)") {
    let guntha = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .guntha, in: .odisha) ?? 0
    let mana = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .mana, in: .odisha) ?? 0
    let katha = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .kathaOdisha, in: .odisha) ?? 0
    let cent = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .cent, in: .odisha) ?? 0
    return abs(guntha - 25.0) < 0.001 &&
           abs(mana - 1.0) < 0.001 &&
           abs(katha - 60.0) < 0.001 &&
           abs(cent - 100.0) < 0.001
}

print("============================================================")
print("RESULTS: \(passed)/\(passed + failed) PASSED")
print("============================================================")
if failed > 0 {
    exit(1)
}
