//
//  OdishaStatutoryRates.swift
//  MyBhoomi
//
//  Single source of truth for Odisha statutory stamp-duty and registration-fee
//  rates used in indicative (user-assisted) valuation. Kept isolated so a rate
//  revision is a one-line change and the math can never drift from the formula
//  string shown to the user.
//

import Foundation

public enum OdishaStatutoryRates {
    /// Standard stamp duty on immovable-property sale consideration.
    public static let stampDutyStandard: Double = 0.05
    /// Concessional stamp duty when the buyer is a woman.
    public static let stampDutyWomanBuyer: Double = 0.04
    /// Registration fee on sale consideration.
    public static let registrationFee: Double = 0.02

    /// Render a fractional rate as a percentage string, e.g. 0.05 -> "5%".
    public static func percentString(_ rate: Double) -> String {
        let pct = rate * 100.0
        if pct == pct.rounded() {
            return "\(Int(pct))%"
        }
        return String(format: "%.1f%%", pct)
    }
}
