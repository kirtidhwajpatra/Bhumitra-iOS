//  LandValueFormat.swift
//  MyBhoomi
//
//  Plain-language rupee formatting for land values: "₹12.4 lakh", "₹1.25 crore".
//  Shared by the compact plot overview and the report's Land value card.
//

import Foundation

enum LandValueFormat {
    /// Short Indian-unit amount a buyer reads at a glance.
    static func compact(_ value: Double) -> String {
        let crore = 10_000_000.0
        let lakh = 100_000.0
        if value >= crore {
            return "₹\(trimmed(value / crore)) crore"
        }
        if value >= lakh {
            return "₹\(trimmed(value / lakh)) lakh"
        }
        if value >= 1_000 {
            return "₹\(trimmed(value / 1_000))K"
        }
        return "₹\(Int(value.rounded()))"
    }

    /// Up to two decimals, trailing zeros dropped: 12.40 -> "12.4", 3.00 -> "3".
    private static func trimmed(_ n: Double) -> String {
        var s = String(format: "%.2f", n)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
