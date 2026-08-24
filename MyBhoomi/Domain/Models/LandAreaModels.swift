import Foundation
import SwiftUI

/// Semantic Region context for Land Area Units.
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

/// Semantic Category for Land Area Units.
public enum LandAreaCategory: String, Codable, CaseIterable {
    case primary = "Primary Units"
    case regional = "Regional Units"
    case metric = "Standard Metric"
}

/// Supported Land Area Units with high-precision conversion factors relative to 1 Square Meter (m²).
public enum LandAreaUnit: String, Codable, CaseIterable, Identifiable {
    // MARK: - Primary / Universal Units
    case acres = "acre"
    case decimal = "decimal"
    case squareFeet = "sq_ft"
    case squareMeters = "sq_m"
    case squareYards = "gaj"
    case hectares = "hectare"
    
    // MARK: - Regional Units
    case guntha = "guntha"
    case mana = "mana"
    case bighaOdisha = "bigha_odisha"
    case kathaOdisha = "katha_odisha"
    case cent = "cent"

    public var id: String { rawValue }

    /// Human-readable display title.
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

    /// Short symbol or unit abbreviation.
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
    
    /// Representative SF symbol icon.
    public var iconName: String {
        switch self {
        case .acres: return "leaf.fill"
        case .decimal: return "chart.pie.fill"
        case .squareFeet: return "ruler.fill"
        case .squareMeters: return "square.fill"
        case .squareYards: return "grid"
        case .hectares: return "globe.asia.australia.fill"
        case .guntha: return "square.split.2x2.fill"
        case .mana: return "scalemass.fill"
        case .bighaOdisha: return "square.3.layers.3d"
        case .kathaOdisha: return "rectangle.grid.1x2.fill"
        case .cent: return "circle.circle.fill"
        }
    }
    
    /// Representative vibrant brand color for unit badge.
    public var iconColor: Color {
        switch self {
        case .acres: return Color(red: 34/255, green: 160/255, blue: 60/255)
        case .decimal: return Color(red: 124/255, green: 58/255, blue: 237/255)
        case .squareFeet: return Color(red: 0/255, green: 122/255, blue: 255/255)
        case .squareMeters: return Color(red: 14/255, green: 165/255, blue: 160/255)
        case .squareYards: return Color(red: 245/255, green: 130/255, blue: 32/255)
        case .hectares: return Color(red: 99/255, green: 102/255, blue: 241/255)
        case .guntha: return Color(red: 234/255, green: 88/255, blue: 12/255)
        case .mana: return Color(red: 225/255, green: 29/255, blue: 72/255)
        case .bighaOdisha: return Color(red: 217/255, green: 70/255, blue: 239/255)
        case .kathaOdisha: return Color(red: 6/255, green: 182/255, blue: 212/255)
        case .cent: return Color(red: 16/255, green: 185/255, blue: 129/255)
        }
    }

    /// Grouping category.
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
    
    /// Indicates whether this unit is a universal standard unit across all regions.
    public var isUniversal: Bool {
        switch self {
        case .acres, .decimal, .squareFeet, .squareMeters, .squareYards, .hectares, .cent:
            return true
        case .guntha, .mana, .bighaOdisha, .kathaOdisha:
            return false
        }
    }
    
    /// Checks if this unit has a verified, trustworthy conversion rule in the specified region.
    /// Strict safety rule: returns `false` instead of guessing or fabricating numbers.
    public func isSupported(in region: LandAreaRegion) -> Bool {
        if isUniversal { return true }
        switch region {
        case .odisha:
            return true // Verified Odisha revenue rules
        case .nationalStandard:
            return false // Bigha/Katha vary drastically across states without universal standard
        }
    }

    /// Canonical Base: Exact number of Square Meters (m²) in 1 unit of this measurement for the given region.
    /// Returns `nil` if the unit is unsupported/undefined in that region.
    public func sqMetersPerUnit(in region: LandAreaRegion = .odisha) -> Double? {
        guard isSupported(in: region) else { return nil }
        
        switch self {
        // 1 Acre = 43,560 sq ft = 4,046.8564224 m²
        case .acres:
            return 4046.8564224
        
        // 1 Decimal = 0.01 Acre = 435.6 sq ft = 40.468564224 m²
        case .decimal:
            return 40.468564224
            
        // 1 Square Foot = 0.09290304 m²
        case .squareFeet:
            return 0.09290304
            
        // 1 Square Meter = 1.0 m²
        case .squareMeters:
            return 1.0
            
        // 1 Square Yard / Gaj = 9 sq ft = 0.83612736 m²
        case .squareYards:
            return 0.83612736
            
        // 1 Hectare = 10,000 m² = 2.47105 Acres
        case .hectares:
            return 10000.0
            
        // 1 Guntha (Odisha) = 4 Decimals = 1,742.4 sq ft = 161.874256896 m² (25 Guntha = 1 Acre)
        case .guntha:
            return 161.874256896
            
        // 1 Mana (Traditional Coastal Odisha) = 1 Acre = 25 Guntha = 100 Decimals = 4,046.8564224 m²
        case .mana:
            return 4046.8564224
            
        // 1 Bigha (Standard Odisha Revenue) = 33.3333 Decimals = 1/3rd Acre = 14,520 sq ft = 1,348.9521408 m²
        case .bighaOdisha:
            return 1348.9521408
            
        // 1 Katha / Biswa (Odisha) = 1/20th Bigha = 1.6666 Decimals = 726 sq ft = 67.44760704 m²
        case .kathaOdisha:
            return 67.44760704
            
        // 1 Cent = 1 Decimal = 435.6 sq ft = 40.468564224 m²
        case .cent:
            return 40.468564224
        }
    }

    /// Regional notes or official revenue definitions.
    public func explanation(in region: LandAreaRegion = .odisha) -> String? {
        switch self {
        case .decimal:
            return "Standard division (100 Decimals = 1 Acre = 43,560 sq ft)."
        case .acres:
            return "Standard revenue unit across Indian RoR records."
        case .squareFeet:
            return "Commonly used for residential plots & architectural layouts."
        case .squareYards:
            return "Standard Gaj measurement (1 Gaj = 1 Sq Yard = 9 Sq Ft)."
        case .guntha:
            return region == .odisha ? "Standard in Southern Odisha / Ganjam (25 Guntha = 1 Acre; 1 Guntha = 4 Decimals)." : nil
        case .mana:
            return region == .odisha ? "Traditional Coastal Odisha measurement (1 Mana = 25 Guntha = 1 Acre)." : nil
        case .bighaOdisha:
            return region == .odisha ? "Standard Odisha definition (1 Bigha = 1/3 Acre = 33.33 Decimals = 14,520 sq ft)." : nil
        case .kathaOdisha:
            return region == .odisha ? "1/20th of an Odisha Bigha (1 Katha = 1.666 Decimals = 726 sq ft)." : nil
        case .cent:
            return "Identical in area to 1 Decimal (435.6 sq ft)."
        default:
            return nil
        }
    }

    /// Formats a numeric unit value with human-friendly precision and grouping.
    public func format(value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        
        // If whole integer within floating point tolerance, format without decimal point
        if abs(value.rounded() - value) < 0.0001 && value < 1_000_000_000_000 {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        } else {
            switch self {
            case .decimal, .cent:
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
            case .squareFeet, .squareYards:
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
            case .squareMeters:
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
            case .acres, .hectares:
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 4
            case .guntha, .mana, .bighaOdisha, .kathaOdisha:
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
            }
        }
        
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// Formats a canonical area in square meters into this unit for the given region.
    public func format(sqMeters: Double, in region: LandAreaRegion = .odisha) -> String? {
        guard let factor = sqMetersPerUnit(in: region), factor > 0 else { return nil }
        let value = sqMeters / factor
        return format(value: value)
    }
}

/// Structured conversion result item for quick comparison UI presentation.
public struct LandAreaConversionItem: Identifiable, Equatable {
    public var id: String { unit.id }
    public let unit: LandAreaUnit
    public let formattedValue: String
    public let rawValue: Double
    public let symbol: String
    public let isPrimary: Bool
    public let note: String?
    
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
        self.note = unit.explanation(in: region)
    }
}
