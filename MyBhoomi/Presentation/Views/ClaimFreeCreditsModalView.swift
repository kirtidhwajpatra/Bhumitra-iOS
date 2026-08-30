import SwiftUI

// ============================================================
// MARK: - CLAIM FREE PLOT SEARCHES MODAL (5 FREE CREDITS)
// ============================================================

/// Pixel-perfect modal presenting the "5 Free plot search." reward when a user runs out of credits.
/// Matches the design with split dual-tone card, flame with "Free" badge, and "Claim now!" button.
public struct ClaimFreeCreditsModalView: View {
    public let onDismiss: () -> Void
    public var onClaim: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    public init(
        onDismiss: @escaping () -> Void,
        onClaim: (() -> Void)? = nil
    ) {
        self.onDismiss = onDismiss
        self.onClaim = onClaim
    }
    
    // Theme Colors
    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 14/255, green: 14/255, blue: 17/255)
            : Color(red: 247/255, green: 247/255, blue: 248/255)
    }
    
    private var cardTopBg: Color {
        colorScheme == .dark
            ? Color(red: 26/255, green: 27/255, blue: 31/255)
            : Color(red: 239/255, green: 240/255, blue: 242/255)
    }
    
    private var cardBottomBg: Color {
        colorScheme == .dark
            ? Color(red: 20/255, green: 21/255, blue: 24/255)
            : Color.white
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 10/255, green: 12/255, blue: 16/255)
    }
    
    private var buttonBg: Color {
        Color(red: 35/255, green: 35/255, blue: 38/255)
    }
    
    public var body: some View {
        ZStack {
            // Flat Clean Background
            pageBackground
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissModal()
                }
            
            VStack(spacing: 0) {
                // Top Dismiss Button (Flat Circle with Hairline Border)
                HStack {
                    Spacer()
                    
                    Button {
                        Theme.haptic(.light)
                        dismissModal()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(colorScheme == .dark ? Color(white: 0.20) : Color.white)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06),
                                            lineWidth: 1
                                        )
                                )
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? Color(white: 0.85) : Color(red: 120/255, green: 125/255, blue: 135/255))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }
                
                Spacer()
                
                // ── CENTER DUAL-TONE REWARD CARD ──
                VStack(spacing: 0) {
                    // 1. Top Section: Soft Grey Canvas with Flame & "Free" Badge
                    ZStack {
                        cardTopBg
                        
                        // Flame Vector & Attached "Free" Badge
                        ZStack(alignment: .topTrailing) {
                            // Large Flame Vector
                            FlameIconShape()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 168/255, green: 85/255, blue: 247/255), // Top: #A855F7
                                            Color(red: 106/255, green: 13/255, blue: 173/255)  // Bottom: #6A0DAD
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 72, height: 102)
                            
                            // "Free" Capsule Badge
                            Text("Free")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 17/255, green: 24/255, blue: 39/255))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
                                )
                                .offset(x: 32, y: -4)
                        }
                    }
                    .frame(height: 250)
                    
                    // 2. Bottom Section: Crisp White Surface with "5 Free plot search."
                    ZStack {
                        cardBottomBg
                        
                        Text("5 Free plot search.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(height: 120)
                }
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06),
                            lineWidth: 1
                        )
                )
                
                Spacer()
                    .frame(height: 50)
                
                // ── BOTTOM "CLAIM NOW!" ACTION PILL ──
                Button {
                    handleClaim()
                } label: {
                    Text("Claim now!")
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(buttonBg)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                Spacer()
            }
        }
    }
    
    // MARK: - Claim Action
    
    private func handleClaim() {
        // Grant 5 free plot search credits
        subscriptionManager.addCredits(amount: 5)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        SavedLandManager.shared.showToast(
            title: "5 Free Searches Claimed!",
            subtitle: "Total searches available: \(subscriptionManager.remainingPlotCredits)"
        )
        onClaim?()
        dismissModal()
    }
    
    private func dismissModal() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
            onDismiss()
        }
    }
}

#Preview {
    ClaimFreeCreditsModalView(
        onDismiss: {}
    )
}
