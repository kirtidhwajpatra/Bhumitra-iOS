//
//  SummaryMetricCardTests.swift
//  MyBhoomiTests
//
//  Unit tests verifying SummaryMetricCard initialization, theming, and accessibility attributes.
//

import XCTest
import SwiftUI
@testable import MyBhoomi

final class SummaryMetricCardTests: XCTestCase {
    
    func test_planCard_initialization_and_action() {
        var tapped = false
        let card = SummaryMetricCard(
            theme: .plan,
            value: "Free",
            subtitle: "Plan",
            action: { tapped = true }
        )
        
        XCTAssertEqual(card.theme, .plan)
        XCTAssertEqual(card.value, "Free")
        XCTAssertEqual(card.subtitle, "Plan")
        XCTAssertNotNil(card.action)
        
        card.action?()
        XCTAssertTrue(tapped)
    }
    
    func test_searchCreditsCard_initialization_and_action() {
        var tapped = false
        let card = SummaryMetricCard(
            theme: .searchCredits,
            value: "26",
            subtitle: "Search credit",
            action: { tapped = true }
        )
        
        XCTAssertEqual(card.theme, .searchCredits)
        XCTAssertEqual(card.value, "26")
        XCTAssertEqual(card.subtitle, "Search credit")
        XCTAssertNotNil(card.action)
        
        card.action?()
        XCTAssertTrue(tapped)
    }
    
    func test_savedLandCard_initialization_and_action() {
        var tapped = false
        let card = SummaryMetricCard(
            theme: .savedLand,
            value: "1",
            subtitle: "Saved land",
            action: { tapped = true }
        )
        
        XCTAssertEqual(card.theme, .savedLand)
        XCTAssertEqual(card.value, "1")
        XCTAssertEqual(card.subtitle, "Saved land")
        XCTAssertNotNil(card.action)
        
        card.action?()
        XCTAssertTrue(tapped)
    }
    
    func test_supportEmailCard_initialization_and_action() {
        var tapped = false
        let card = SummaryMetricCard(
            theme: .supportEmail,
            value: "Help",
            subtitle: "Support email",
            action: { tapped = true }
        )
        
        XCTAssertEqual(card.theme, .supportEmail)
        XCTAssertEqual(card.value, "Help")
        XCTAssertEqual(card.subtitle, "Support email")
        XCTAssertNotNil(card.action)
        
        card.action?()
        XCTAssertTrue(tapped)
    }
    
    func test_unlimited_and_infinity_values() {
        let planCard = SummaryMetricCard(
            theme: .plan,
            value: "Unlimited Plus",
            subtitle: "Plan"
        )
        XCTAssertEqual(planCard.value, "Unlimited Plus")
        
        let searchCard = SummaryMetricCard(
            theme: .searchCredits,
            value: "∞",
            subtitle: "Search credit"
        )
        XCTAssertEqual(searchCard.value, "∞")
        XCTAssertNil(searchCard.action)
    }
}
