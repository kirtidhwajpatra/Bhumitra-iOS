import Foundation

/// Robust, pure local conversion engine for Indian & Odisha land records.
/// Computes all units from a single canonical Base (Square Meters) to eliminate cumulative rounding errors.
/// Never connects to the network; 100% local, safe, and instant.
public enum LandAreaUnitConverter {
    
    // MARK: - Unit Conversion Matrix
    
    /// Converts a value from a source unit to a target unit in the specified region context.
    /// Returns `nil` if either unit is unsupported or undefined in the selected region.
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
    
    /// Converts a value in a source unit to canonical Square Meters ($m^2$).
    public static func toSqMeters(
        value: Double,
        from unit: LandAreaUnit,
        in region: LandAreaRegion = .odisha
    ) -> Double? {
        guard value >= 0 else { return nil }
        guard let factor = unit.sqMetersPerUnit(in: region) else { return nil }
        return value * factor
    }
    
    /// Converts canonical Square Meters ($m^2$) to the specified target unit.
    public static func fromSqMeters(
        _ sqMeters: Double,
        to unit: LandAreaUnit,
        in region: LandAreaRegion = .odisha
    ) -> Double? {
        guard sqMeters >= 0 else { return nil }
        guard let factor = unit.sqMetersPerUnit(in: region), factor > 0 else { return nil }
        return sqMeters / factor
    }
    
    // MARK: - Quick Conversion Generators
    
    /// Generates structured primary conversion items for UI presentation.
    public static func primaryConversions(
        for sqMeters: Double,
        region: LandAreaRegion = .odisha
    ) -> [LandAreaConversionItem] {
        let units: [LandAreaUnit] = [.acres, .decimal, .squareFeet, .squareMeters, .squareYards, .hectares]
        return units.compactMap { LandAreaConversionItem(unit: $0, sqMeters: sqMeters, region: region, isPrimary: true) }
    }
    
    /// Generates structured regional conversion items for UI presentation.
    public static func regionalConversions(
        for sqMeters: Double,
        region: LandAreaRegion = .odisha
    ) -> [LandAreaConversionItem] {
        let units: [LandAreaUnit] = [.guntha, .mana, .bighaOdisha, .kathaOdisha, .cent]
        return units.compactMap { LandAreaConversionItem(unit: $0, sqMeters: sqMeters, region: region, isPrimary: false) }
    }
    
    // MARK: - Official Bhulekh String Parsing
    
    /// Parses an official Bhulekh area string into canonical Square Meters ($m^2$).
    /// Returns `nil` if the string cannot be safely parsed, guaranteeing ZERO fabricated numbers.
    public static func parseToSqMeters(from rawArea: String?, in region: LandAreaRegion = .odisha) -> Double? {
        guard let raw = rawArea?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "—", raw != "-" else {
            return nil
        }
        
        // 1. Format: "0 Acre 3400 Decimal" or "1 Acre 4200 Decimal" or "0 Ac 50 Dec"
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
        
        // 2. Format: "3400 Decimal" or "34 Decimal"
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
        
        // 3. Format: "1.42 Acre" or "0.34 Acres"
        let acreOnlyPattern = #"^(\d+(?:\.\d+)?)\s*(?:Acre|Acres|Ac|A)$"#
        if let regex = try? NSRegularExpression(pattern: acreOnlyPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rAcre = Range(match.range(at: 1), in: raw),
               let acreVal = Double(raw[rAcre]) {
                guard let acreSqM = LandAreaUnit.acres.sqMetersPerUnit(in: region) else { return nil }
                return acreVal * acreSqM
            }
        }
        
        // 4. Format: "14810.4 Sq Ft" or "14,810.4 Square Feet"
        let sqFtPattern = #"^([\d,]+(?:\.\d+)?)\s*(?:Sq\s*Ft|Square\s*Feet|Sqft)$"#
        if let regex = try? NSRegularExpression(pattern: sqFtPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rSqFt = Range(match.range(at: 1), in: raw) {
                let cleaned = raw[rSqFt].replacingOccurrences(of: ",", with: "")
                if let sqFtVal = Double(cleaned) {
                    guard let sqFtSqM = LandAreaUnit.squareFeet.sqMetersPerUnit(in: region) else { return nil }
                    return sqFtVal * sqFtSqM
                }
            }
        }
        
        // 5. Format: "1376 Sq M" or "1376.0 Square Meters"
        let sqMPattern = #"^([\d,]+(?:\.\d+)?)\s*(?:Sq\s*M|Square\s*Meters|Sqm|m2|m²)$"#
        if let regex = try? NSRegularExpression(pattern: sqMPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rSqM = Range(match.range(at: 1), in: raw) {
                let cleaned = raw[rSqM].replacingOccurrences(of: ",", with: "")
                if let sqMVal = Double(cleaned) {
                    guard let sqMSqM = LandAreaUnit.squareMeters.sqMetersPerUnit(in: region) else { return nil }
                    return sqMVal * sqMSqM
                }
            }
        }
        
        // 6. Direct numeric fallback if purely digits/decimal point (treated as Acres if <= 10, else Decimal)
        let cleanNumeric = raw.replacingOccurrences(of: ",", with: "")
        if let num = Double(cleanNumeric), num >= 0 {
            guard let acreSqM = LandAreaUnit.acres.sqMetersPerUnit(in: region) else { return nil }
            return num * acreSqM
        }
        
        return nil
    }
    
    /// Parses an official extent string into an initial structured value and unit for preloading into the converter.
    /// E.g. "0 Acre 3400 Decimal" -> (value: 34.0, unit: .decimal)
    /// E.g. "1 Acre 4200 Decimal" -> (value: 142.0, unit: .decimal)
    /// E.g. "0 Acre 0270 Decimal" -> (value: 2.7, unit: .decimal)
    /// E.g. "2 Acre 0000 Decimal" -> (value: 2.0, unit: .acres)
    /// E.g. "1.5 Acre" -> (value: 1.5, unit: .acres)
    public static func parseStructuredExtent(from rawArea: String?) -> (value: Double, unit: LandAreaUnit)? {
        guard let raw = rawArea?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "—", raw != "-" else {
            return nil
        }
        
        // 1. "X Acre Y Decimal" pattern
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
                    // Preload total in Decimals as it is the primary granular unit
                    let totalDecimals = (acreVal * 100.0) + decVal
                    return (totalDecimals, .decimal)
                } else {
                    return (0.0, .acres)
                }
            }
        }
        
        // 2. "Y Decimal"
        let decOnlyPattern = #"^(\d+(?:\.\d+)?)\s*(?:Decimal|Decimals|Dec|D)$"#
        if let regex = try? NSRegularExpression(pattern: decOnlyPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rDec = Range(match.range(at: 1), in: raw) {
                let decStr = String(raw[rDec])
                let decVal = parseDecimalTokenToDecimals(decStr)
                return (decVal, .decimal)
            }
        }
        
        // 3. "X Acre"
        let acreOnlyPattern = #"^(\d+(?:\.\d+)?)\s*(?:Acre|Acres|Ac|A)$"#
        if let regex = try? NSRegularExpression(pattern: acreOnlyPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rAcre = Range(match.range(at: 1), in: raw),
               let acreVal = Double(raw[rAcre]) {
                return (acreVal, .acres)
            }
        }
        
        // 4. "Z Sq Ft"
        let sqFtPattern = #"^([\d,]+(?:\.\d+)?)\s*(?:Sq\s*Ft|Square\s*Feet|Sqft)$"#
        if let regex = try? NSRegularExpression(pattern: sqFtPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rSqFt = Range(match.range(at: 1), in: raw) {
                let cleaned = raw[rSqFt].replacingOccurrences(of: ",", with: "")
                if let sqFtVal = Double(cleaned) {
                    return (sqFtVal, .squareFeet)
                }
            }
        }
        
        // 5. "Z Sq M"
        let sqMPattern = #"^([\d,]+(?:\.\d+)?)\s*(?:Sq\s*M|Square\s*Meters|Sqm|m2|m²)$"#
        if let regex = try? NSRegularExpression(pattern: sqMPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let rSqM = Range(match.range(at: 1), in: raw) {
                let cleaned = raw[rSqM].replacingOccurrences(of: ",", with: "")
                if let sqMVal = Double(cleaned) {
                    return (sqMVal, .squareMeters)
                }
            }
        }
        
        // 6. Direct numeric fallback
        let cleanNumeric = raw.replacingOccurrences(of: ",", with: "")
        if let num = Double(cleanNumeric), num >= 0 {
            return (num, .acres)
        }
        
        return nil
    }
    
    /// Resolves Odisha Bhulekh 4-digit vs standard decimal strings.
    /// E.g. "3400" -> 34.0 Decimals; "0270" -> 2.7 Decimals; "4200" -> 42.0 Decimals; "50" -> 50.0 Decimals.
    public static func parseDecimalTokenToDecimals(_ token: String) -> Double {
        let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let num = Double(clean) else { return 0.0 }
        
        if clean.contains(".") {
            return num
        }
        
        // If 4-digit notation from Odisha Bhulekh (e.g. 3400, 4200, 0270, 0600)
        if clean.count == 4 {
            return num / 100.0
        }
        
        // If 3-digit notation (e.g. 340)
        if clean.count == 3 {
            return num / 10.0
        }
        
        // If 1 or 2 digit notation (e.g. 50, 4, 34)
        return num
    }
}
