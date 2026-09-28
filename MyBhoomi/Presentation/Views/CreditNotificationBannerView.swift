//
//  CreditNotificationBannerView.swift
//  MyBhoomi
//
//  Gentle low-credit hint. One compact pill ("2 searches left · Add") that
//  appears once per credit level and fades out by itself after a few
//  seconds; the persistent signal lives on the credit count in the top-right
//  capsule (tinted amber when low). Only "No searches left" stays until the
//  user dismisses it, because at zero a search will actually be blocked.
//

import SwiftUI

public struct CreditNotificationBannerView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    public var onUpgradeTapped: () -> Void

    /// Last credit level the user has already been told about (2, 1 or 0).
    @AppStorage("dismissed_low_credit_level") private var dismissedCreditLevel: Int = -999

    /// How long a 1–2 credit hint stays before fading out on its own.
    private let autoHideSeconds: UInt64 = 5

    public init(onUpgradeTapped: @escaping () -> Void) {
        self.onUpgradeTapped = onUpgradeTapped
    }

    private var credits: Int { subscriptionManager.remainingPlotCredits }

    private var isVisible: Bool {
        if subscriptionManager.isUnlimited || subscriptionManager.isPremium { return false }
        guard credits <= 2 else { return false }
        return dismissedCreditLevel != credits
    }

    private func markSeen() {
        withAnimation(.easeInOut(duration: 0.25)) {
            dismissedCreditLevel = credits
        }
    }

    public var body: some View {
        if isVisible {
            MapStatusPill(
                icon: credits == 0 ? "exclamationmark.circle" : "magnifyingglass",
                tone: credits == 0 ? .warning : .neutral,
                title: credits == 0
                    ? "No searches left"
                    : "\(credits) \(credits == 1 ? "search" : "searches") left",
                action: NoticeAction("Add") { onUpgradeTapped() },
                onDismiss: credits == 0 ? { markSeen() } : nil
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
            // 1–2 credits: informational only — show once, then get out of the way.
            .task(id: credits) {
                guard credits > 0 else { return }
                try? await _Concurrency.Task.sleep(nanoseconds: autoHideSeconds * 1_000_000_000)
                if !_Concurrency.Task.isCancelled { markSeen() }
            }
        }
    }
}
