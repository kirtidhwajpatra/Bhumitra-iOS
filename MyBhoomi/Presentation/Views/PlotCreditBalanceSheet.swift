//
//  PlotCreditBalanceSheet.swift
//  MyBhoomi
//
//  Bottom sheet presented when the user taps the plot search credits pill on
//  the home screen. Uses the SAME top branding header as the subscription
//  (payment) screen — the SubscriptionProLogo graphic presented centered on
//  top, in the app's stackSans design language — then shows the live credit
//  balance from SubscriptionManager and routes to the subscription screen
//  from the CTA.
//
//  All displayed values are real state; no hardcoded balances.
//

import SwiftUI

public struct PlotCreditBalanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    private let onUpgrade: () -> Void

    public init(onUpgrade: @escaping () -> Void) {
        self.onUpgrade = onUpgrade
    }

    private var isUnlimited: Bool {
        subscriptionManager.isUnlimited || subscriptionManager.isPremium
    }

    private var remaining: Int {
        subscriptionManager.remainingPlotCredits
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Theme.Color.bhumitraDivider)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Spacer(minLength: 12)

            // Top branding header — identical presentation to the payment
            // (subscription) screen's topBrandingHeader: the plot search power
            // graphic centered on top, above the balance and copy.
            plotSearchGraphic
                .frame(width: 58, height: 86)
                .padding(.bottom, 10)

            // Live balance figure (real state)
            Group {
                if isUnlimited {
                    Text("Unlimited")
                        .font(.stackSansHeadline(size: 32, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                } else {
                    Text("\(remaining)")
                        .font(.stackSansHeadline(size: 50, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(remaining) searches left")
                }
            }
            .frame(maxWidth: .infinity)

            Text(headingText)
                .font(.stackSansHeadline(size: 20.5, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(-3)
                .padding(.top, 12)

            Text(subtitleText)
                .font(.stackSansHeadline(size: 14.5, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Spacer(minLength: 16)

            Button {
                Theme.haptic(.light)
                onUpgrade()
            } label: {
                Text(ctaTitle)
            }
            .buttonStyle(.primaryCTA)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Plot search power graphic (same asset as the payment screen)

    private var plotSearchGraphic: some View {
        Group {
            if let img = UIImage(named: "SubscriptionProLogo") ?? UIImage(named: "subscription_pro_logo") {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image("SubscriptionProLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Real-state copy

    private var headingText: String {
        if isUnlimited { return "Unlimited searches active" }
        if remaining == 1 { return "You have 1 search left" }
        return "You have \(remaining) searches left"
    }

    private var subtitleText: String {
        if isUnlimited { return "Verify as many land records as you need" }
        if remaining == 0 { return "Top up to keep verifying land records" }
        return "Each search verifies one land record"
    }

    private var ctaTitle: String {
        isUnlimited ? "View plans" : "Get more searches"
    }
}

#Preview {
    PlotCreditBalanceSheet(onUpgrade: {})
}
