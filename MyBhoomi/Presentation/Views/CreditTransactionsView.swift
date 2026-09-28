//
//  CreditTransactionsView.swift
//  MyBhoomi
//
//  Credit activity ledger: current balance, lifetime totals, and an itemised
//  history grouped by day. Every figure comes from SubscriptionManager
//  (authoritative server balance) and CreditTransactionManager (activity log).
//

import SwiftUI

public struct CreditTransactionsView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var transactionManager = CreditTransactionManager.shared

    @State private var selectedFilter: TransactionFilter = .all
    @State private var showSubscriptionModal = false

    public enum TransactionFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case added = "Added"
        case spent = "Used"
        public var id: String { rawValue }
    }

    public init() {}

    private var isUnlimited: Bool { subscriptionManager.isUnlimited || subscriptionManager.isPremium }

    private var filteredTransactions: [CreditTransactionItem] {
        switch selectedFilter {
        case .all: return transactionManager.transactions
        case .added: return transactionManager.transactions.filter { $0.type == .added }
        case .spent: return transactionManager.transactions.filter { $0.type == .spent }
        }
    }

    /// Transactions grouped by calendar day, newest first.
    private var groupedTransactions: [(day: Date, items: [CreditTransactionItem])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredTransactions) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    public var body: some View {
        ZStack {
            SheetChrome.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader("Credit activity", subtitle: "Your plot search balance and history") { dismiss() }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        balanceCard
                        filterPicker
                        if groupedTransactions.isEmpty {
                            emptyState
                        } else {
                            ForEach(groupedTransactions, id: \.day) { group in
                                SettingsSection(dayTitle(group.day)) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, tx in
                                        transactionRow(tx)
                                        if index < group.items.count - 1 { SettingsDivider() }
                                    }
                                }
                            }
                        }
                        Text("Balance shown is confirmed by our server. Activity history is kept on this device.")
                            .font(.googleSans(size: 12, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                    }
                    .padding(.horizontal, SettingsMetrics.horizontalPadding)
                    .padding(.top, 6)
                    .padding(.bottom, 48)
                }
                .refreshable {
                    await subscriptionManager.fetchServerCreditBalance()
                }
            }
        }
        .task { await subscriptionManager.fetchServerCreditBalance() }
        .fullScreenCover(isPresented: $showSubscriptionModal) { SubscriptionView() }
    }

    // MARK: - Balance

    private var balanceCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current balance")
                        .font(.googleSans(size: 13, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(isUnlimited ? "Unlimited" : "\(subscriptionManager.authoritativeBalance)")
                            .font(.googleSans(size: 40, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            .contentTransition(.numericText())
                        if !isUnlimited {
                            Text(subscriptionManager.authoritativeBalance == 1 ? "search" : "searches")
                                .font(.googleSans(size: 16, weight: .regular))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        }
                    }
                }
                .accessibilityElement(children: .combine)

                HStack(spacing: 0) {
                    statColumn(title: "Added", value: "+\(transactionManager.totalCreditsAdded)", tone: .success)
                    Rectangle()
                        .fill(Theme.Color.bhumitraDivider)
                        .frame(width: 0.5, height: 32)
                    statColumn(title: "Used", value: "\(transactionManager.totalCreditsSpent)", tone: .neutral)
                        .padding(.leading, 16)
                }

                if !isUnlimited {
                    Button {
                        Theme.haptic(.light)
                        showSubscriptionModal = true
                    } label: {
                        Text("Add searches")
                            .font(.googleSans(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Theme.Color.bhumitraPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaledButtonStyle())
                }
            }
            .padding(16)
        }
    }

    private func statColumn(title: String, value: String, tone: SettingsTone) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.googleSans(size: 12, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
            Text(value)
                .font(.googleSans(size: 17, weight: .semibold))
                .foregroundColor(tone == .success ? Theme.Color.bhumitraSuccess : Theme.Color.bhumitraPrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Filter

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(TransactionFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedFilter) { _, _ in Theme.selectionHaptic() }
    }

    // MARK: - Row

    private func transactionRow(_ tx: CreditTransactionItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsIconTile(icon(for: tx), tone: tx.type == .added ? .success : .neutral)

            VStack(alignment: .leading, spacing: 2) {
                Text(tx.title)
                    .font(.appText(tx.title, size: 15, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .lineLimit(1)
                Text(rowSubtitle(tx))
                    .font(.appText(rowSubtitle(tx), size: 12.5, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(tx.type == .added ? "+\(tx.amount)" : "−\(abs(tx.amount))")
                    .font(.googleSans(size: 15.5, weight: .semibold))
                    .foregroundColor(tx.type == .added ? Theme.Color.bhumitraSuccess : Theme.Color.bhumitraPrimaryText)
                    .monospacedDigit()
                Text("Bal \(tx.balanceAfter)")
                    .font(.googleSans(size: 12, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(tx))
    }

    private func icon(for tx: CreditTransactionItem) -> String {
        switch tx.category {
        case .purchase: return "creditcard"
        case .starterPack: return "gift"
        case .bonus: return "sparkles"
        case .refund: return "arrow.uturn.backward"
        case .plotSearch: return "map"
        case .rorInspection: return "doc.text.magnifyingglass"
        }
    }

    private func rowSubtitle(_ tx: CreditTransactionItem) -> String {
        let time = Self.timeFormatter.string(from: tx.date)
        if let details = tx.details, !details.isEmpty { return "\(details) · \(time)" }
        return "\(tx.category.rawValue) · \(time)"
    }

    private func accessibilityText(_ tx: CreditTransactionItem) -> String {
        let change = tx.type == .added ? "added \(tx.amount)" : "used \(abs(tx.amount))"
        return "\(tx.title), \(change) searches, balance \(tx.balanceAfter), \(Self.timeFormatter.string(from: tx.date))"
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            SettingsIconTile("list.bullet.rectangle", tone: .neutral, size: 44)
            Text(selectedFilter == .all ? "No activity yet" : "Nothing here yet")
                .font(.googleSans(size: 16, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
            Text("Credits you add and searches you run will appear here.")
                .font(.googleSans(size: 13, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Dates

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return Self.dayFormatter.string(from: day)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

#Preview {
    CreditTransactionsView()
}
