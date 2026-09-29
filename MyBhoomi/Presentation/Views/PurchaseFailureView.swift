//
//  PurchaseFailureView.swift
//  MyBhoomi
//
//  A dedicated, product-quality failure screen for the purchase flow. Replaces
//  the previous generic "Purchase Notice" alert (OK-only, no retry) so a user
//  whose purchase failed always has a clear reason, a way to retry, and — when a
//  payment did occur — reassurance that they were not double-charged.
//
//  Styling mirrors PurchaseSuccessModalView for a cohesive payment experience.
//

import SwiftUI

// MARK: - Design Tokens (aligned with PurchaseSuccessModalView)
private enum PaymentFailureTokens {
    static let primaryPurple = Color(hex: "#008B48")
    static let canvasBgStart = Color(hex: "#3A1D66")
    static let canvasBgEnd = Color(hex: "#241046")
    static let pillBg = Color.white.opacity(0.16)
    static let pillBorder = Color.white.opacity(0.32)
    static let closeBorder = Color.white.opacity(0.25)

    static let textTitle = Color(hex: "#FFFFFF")
    static let textSubtitle = Color(hex: "#E5D4FF")
    static let textMuted = Color(hex: "#CFA6FF")

    // Amber for "payment safe" reassurance, soft red for "not charged" failures.
    static let safeAccent = Color(hex: "#F6A623")
    static let errorAccent = Color(hex: "#FF6B6B")
}

public struct PurchaseFailureView: View {
    /// Human-readable reason for the failure.
    public let reason: String
    /// Whether Apple actually took a payment. Drives the reassurance copy.
    public let charged: Bool
    /// Whether retrying the same purchase makes sense.
    public let retryable: Bool

    /// Retry the purchase. Only shown when `retryable`.
    public var onRetry: (() -> Void)? = nil
    /// Restore / sync existing purchases.
    public var onRestore: (() -> Void)? = nil
    /// Contact support.
    public var onContactSupport: (() -> Void)? = nil
    /// Dismiss the failure screen.
    public let onDismiss: () -> Void

    @State private var appearAnimation: Bool = false

    public init(
        reason: String,
        charged: Bool,
        retryable: Bool,
        onRetry: (() -> Void)? = nil,
        onRestore: (() -> Void)? = nil,
        onContactSupport: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.reason = reason
        self.charged = charged
        self.retryable = retryable
        self.onRetry = onRetry
        self.onRestore = onRestore
        self.onContactSupport = onContactSupport
        self.onDismiss = onDismiss
    }

    private var accent: Color {
        charged ? PaymentFailureTokens.safeAccent : PaymentFailureTokens.errorAccent
    }

    private var iconName: String {
        charged ? "clock.badge.exclamationmark.fill" : "exclamationmark.triangle.fill"
    }

    private var headline: String {
        if !charged { return "Purchase didn't go through" }
        return retryable ? "Payment received — activation needed" : "Payment received — needs a quick fix"
    }

    /// The reassurance line shown under the specific reason. Only mentions
    /// buttons that are actually on screen.
    private var reassurance: String {
        if !charged {
            return "You have not been charged. You can try again whenever you're ready."
        }
        if retryable {
            return "Your payment is safe and you will not be charged again. Tap Retry to finish activating, or Restore to sync it now."
        }
        return "Your payment is safe and you will not be charged again. Contact Support and we'll add it to your account."
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: PaymentFailureTokens.canvasBgStart, location: 0.0),
                    .init(color: PaymentFailureTokens.canvasBgEnd, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close bar
                HStack {
                    Spacer()
                    Button {
                        Theme.haptic(.light)
                        onDismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(PaymentFailureTokens.closeBorder, lineWidth: 1.8)
                                .background(Circle().fill(Color.black.opacity(0.20)))
                                .frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }

                Spacer(minLength: 8)

                // Icon
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 104, height: 104)
                    Circle()
                        .stroke(accent.opacity(0.5), lineWidth: 2)
                        .frame(width: 104, height: 104)
                    Image(systemName: iconName)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(accent)
                }
                .scaleEffect(appearAnimation ? 1.0 : 0.8)
                .opacity(appearAnimation ? 1.0 : 0.0)
                .padding(.bottom, 24)

                // Headline
                Text(headline)
                    .font(.stackSansHeadline(size: 24, weight: .bold))
                    .foregroundColor(PaymentFailureTokens.textTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)

                // Specific reason
                Text(reason)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(PaymentFailureTokens.textSubtitle)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 14)

                // Reassurance pill
                Text(reassurance)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(charged ? PaymentFailureTokens.textTitle : PaymentFailureTokens.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(PaymentFailureTokens.pillBg)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(PaymentFailureTokens.pillBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 28)

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    if retryable, let onRetry {
                        Button {
                            Theme.haptic(.medium)
                            onRetry()
                        } label: {
                            Text(charged ? "Retry Activation" : "Try Again")
                        }
                        .buttonStyle(.inverseCTA)
                        .padding(.horizontal, 28)
                    }

                    if let onRestore {
                        Button {
                            Theme.selectionHaptic()
                            onRestore()
                        } label: {
                            Text("Restore Purchases")
                                .font(.stackSansHeadline(size: 15.5, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1.4)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 28)
                    }

                    HStack(spacing: 24) {
                        if let onContactSupport {
                            Button {
                                Theme.selectionHaptic()
                                onContactSupport()
                            } label: {
                                Text("Contact Support")
                                    .font(.stackSansHeadline(size: 14, weight: .medium))
                                    .foregroundColor(PaymentFailureTokens.textMuted)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            Theme.selectionHaptic()
                            onDismiss()
                        } label: {
                            Text("Dismiss")
                                .font(.stackSansHeadline(size: 14, weight: .medium))
                                .foregroundColor(PaymentFailureTokens.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(charged ? .warning : .error)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                appearAnimation = true
            }
        }
    }
}

#if DEBUG
struct PurchaseFailureView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PurchaseFailureView(
                reason: "The App Store couldn't complete the payment.",
                charged: false,
                retryable: true,
                onRetry: {}, onRestore: {}, onContactSupport: {}, onDismiss: {}
            )
            PurchaseFailureView(
                reason: "We couldn't reach the server to activate your plot searches.",
                charged: true,
                retryable: true,
                onRetry: {}, onRestore: {}, onContactSupport: {}, onDismiss: {}
            )
        }
    }
}
#endif
