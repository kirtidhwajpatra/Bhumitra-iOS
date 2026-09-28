//  LandAreaFormat.swift
//  MyBhoomi
//
//  Turns a raw Bhulekh extent ("1 Acre 0000 Decimal") into what a person reads:
//  a short primary figure ("1 acre") and a one-line secondary ("100 decimal ·
//  43,560 sq ft"). Returns nil when the string can't be parsed — never guesses.
//

import Foundation

enum LandAreaFormat {
    private static func sqMeters(_ raw: String?) -> Double? {
        guard let sqM = LandAreaUnitConverter.parseToSqMeters(from: raw), sqM > 0 else { return nil }
        return sqM
    }

    /// "1 acre", "2.5 acres", or "45 decimal" for plots under an acre.
    static func primary(_ raw: String?) -> String? {
        guard let sqM = sqMeters(raw),
              let acres = LandAreaUnitConverter.fromSqMeters(sqM, to: .acres) else { return nil }
        if acres >= 1 {
            let n = trimmed(acres)
            return n == "1" ? "1 acre" : "\(n) acres"
        }
        guard let dec = LandAreaUnitConverter.fromSqMeters(sqM, to: .decimal) else { return nil }
        return "\(trimmed(dec)) decimal"
    }

    /// The same area in the two other units buyers ask about.
    static func secondary(_ raw: String?) -> String? {
        guard let sqM = sqMeters(raw),
              let acres = LandAreaUnitConverter.fromSqMeters(sqM, to: .acres),
              let dec = LandAreaUnitConverter.fromSqMeters(sqM, to: .decimal),
              let sqFt = LandAreaUnitConverter.fromSqMeters(sqM, to: .squareFeet) else { return nil }
        let feet = sqFtFormatter.string(from: NSNumber(value: sqFt.rounded())) ?? "\(Int(sqFt.rounded()))"
        let lead = acres >= 1 ? "\(trimmed(dec)) decimal" : "\(trimmed(acres)) acre"
        return "\(lead) · \(feet) sq ft"
    }

    private static let sqFtFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_IN")
        f.maximumFractionDigits = 0
        return f
    }()

    /// Up to two decimals, trailing zeros dropped: 1.00 -> "1", 2.50 -> "2.5".
    private static func trimmed(_ n: Double) -> String {
        var s = String(format: "%.2f", n)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
