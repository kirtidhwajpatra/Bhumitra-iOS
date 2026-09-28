//
//  CreditTransactionModel.swift
//  MyBhoomi
//
//  Data models and local persistent audit store for search credit transactions.
//  Tracks additions (purchases, starter packs, promo grants) and usage (plot searches, RoR inspections).
//

import Foundation
import SwiftUI
import Combine

public enum CreditTransactionType: String, Codable {
    case added
    case spent
}

public enum CreditTransactionCategory: String, Codable {
    case starterPack = "Starter Allowance"
    case purchase = "Credit Top-Up"
    case plotSearch = "Plot Search"
    case rorInspection = "RoR Verification"
    case bonus = "Promotional Bonus"
    case refund = "Credit Adjustment"
}

public struct CreditTransactionItem: Identifiable, Codable, Equatable {
    public let id: String
    public let type: CreditTransactionType
    public let category: CreditTransactionCategory
    public let amount: Int
    public let title: String
    public let details: String?
    public let date: Date
    public let balanceAfter: Int
    
    public init(
        id: String = UUID().uuidString,
        type: CreditTransactionType,
        category: CreditTransactionCategory,
        amount: Int,
        title: String,
        details: String? = nil,
        date: Date = Date(),
        balanceAfter: Int
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.amount = amount
        self.title = title
        self.details = details
        self.date = date
        self.balanceAfter = balanceAfter
    }
}

@MainActor
public final class CreditTransactionManager: ObservableObject {
    public static let shared = CreditTransactionManager()
    
    private let userDefaultsKey = "bhumitra_credit_transactions_log_v1"
    
    @Published public private(set) var transactions: [CreditTransactionItem] = []
    
    private init() {
        loadTransactions()
    }
    
    // MARK: - Persistence
    
    private func loadTransactions() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        do {
            let decoder = JSONDecoder()
            transactions = try decoder.decode([CreditTransactionItem].self, from: data)
        } catch {
            debugLog("[CreditTransactionManager] Failed to decode transactions: \(error.localizedDescription)")
            transactions = []
        }
    }
    
    private func saveTransactions() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(transactions)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            debugLog("[CreditTransactionManager] Failed to encode transactions: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Transaction Logging
    
    public func recordCreditAdded(
        amount: Int,
        title: String,
        category: CreditTransactionCategory = .purchase,
        details: String? = nil,
        balanceAfter: Int
    ) {
        let item = CreditTransactionItem(
            type: .added,
            category: category,
            amount: amount,
            title: title,
            details: details,
            date: Date(),
            balanceAfter: balanceAfter
        )
        transactions.insert(item, at: 0)
        saveTransactions()
    }
    
    public func recordCreditSpent(
        amount: Int = 1,
        title: String,
        category: CreditTransactionCategory = .plotSearch,
        details: String? = nil,
        balanceAfter: Int
    ) {
        let item = CreditTransactionItem(
            type: .spent,
            category: category,
            amount: amount,
            title: title,
            details: details,
            date: Date(),
            balanceAfter: balanceAfter
        )
        transactions.insert(item, at: 0)
        saveTransactions()
    }
    
    // MARK: - Transaction History Reset
    public func clearAllTransactions() {
        transactions.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - Computed Summaries
    
    public var totalCreditsAdded: Int {
        transactions.filter { $0.type == .added }.reduce(0) { $0 + $1.amount }
    }
    
    public var totalCreditsSpent: Int {
        transactions.filter { $0.type == .spent }.reduce(0) { $0 + $1.amount }
    }
}
