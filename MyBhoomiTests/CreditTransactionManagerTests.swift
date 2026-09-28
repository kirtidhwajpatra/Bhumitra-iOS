//
//  CreditTransactionManagerTests.swift
//  MyBhoomiTests
//
//  Unit tests verifying CreditTransactionManager logging, totals, and audit records.
//

import XCTest
import SwiftUI
@testable import MyBhoomi

@MainActor
final class CreditTransactionManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    func test_recordCreditAdded_appendsItemAndCalculatesTotals() {
        let manager = CreditTransactionManager.shared
        let initialCount = manager.transactions.count
        let initialAdded = manager.totalCreditsAdded
        
        manager.recordCreditAdded(
            amount: 50,
            title: "+50 Plots Search Pack",
            category: .purchase,
            details: "Apple In-App Purchase",
            balanceAfter: 74
        )
        
        XCTAssertEqual(manager.transactions.count, initialCount + 1)
        XCTAssertEqual(manager.totalCreditsAdded, initialAdded + 50)
        
        let latest = manager.transactions.first
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.amount, 50)
        XCTAssertEqual(latest?.type, .added)
        XCTAssertEqual(latest?.category, .purchase)
        XCTAssertEqual(latest?.title, "+50 Plots Search Pack")
        XCTAssertEqual(latest?.balanceAfter, 74)
    }
    
    func test_recordCreditSpent_appendsItemAndCalculatesTotals() {
        let manager = CreditTransactionManager.shared
        let initialCount = manager.transactions.count
        let initialSpent = manager.totalCreditsSpent
        
        manager.recordCreditSpent(
            amount: 1,
            title: "Plot #99 Cadastral Search",
            category: .plotSearch,
            details: "Nuagaon, Athagarh, Cuttack",
            balanceAfter: 23
        )
        
        XCTAssertEqual(manager.transactions.count, initialCount + 1)
        XCTAssertEqual(manager.totalCreditsSpent, initialSpent + 1)
        
        let latest = manager.transactions.first
        XCTAssertNotNil(latest)
        XCTAssertEqual(latest?.amount, 1)
        XCTAssertEqual(latest?.type, .spent)
        XCTAssertEqual(latest?.category, .plotSearch)
        XCTAssertEqual(latest?.title, "Plot #99 Cadastral Search")
        XCTAssertEqual(latest?.details, "Nuagaon, Athagarh, Cuttack")
        XCTAssertEqual(latest?.balanceAfter, 23)
    }
    
    func test_transactionItem_codable() throws {
        let original = CreditTransactionItem(
            type: .added,
            category: .purchase,
            amount: 20,
            title: "+20 Plot Searches",
            details: "App Store",
            balanceAfter: 25
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CreditTransactionItem.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.type, decoded.type)
        XCTAssertEqual(original.category, decoded.category)
        XCTAssertEqual(original.amount, decoded.amount)
        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.details, decoded.details)
        XCTAssertEqual(original.balanceAfter, decoded.balanceAfter)
    }
}
