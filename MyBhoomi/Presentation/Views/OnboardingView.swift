import SwiftUI

// ============================================================
// MARK: - BHUMITRA ONBOARDING EXPERIENCE (EXACT REFERENCE DESIGN)
// ============================================================

/// Pixel-perfect onboarding modal matching the reference design:
/// - Lighter regular-weight Google Sans headline
/// - Clean, compact byline and subtitle
/// - Small dark circle badges with outlined icons
/// - Plot card matched .buttonStyle(.glassProminent) CTA
/// - Clean compliance disclosure footer
public struct OnboardingView: View {
    public let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDisclaimerSheet: Bool = false
    
    public init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // 1. Pure Deep Black Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Top-Right Liquid Glass Close Button
                HStack {
                    Spacer()
                    
                    Button {
                        Theme.haptic(.light)
                        markOnboardingCompleted()
                        onDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Close")
                    .padding(.trailing, 20)
                    .padding(.top, 14)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 16)
                        
                        // 3. Hero Icon: Outlined Minimalist Double-Sheet / Land Passport
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 46, weight: .light))
                            .foregroundColor(.white)
                            .padding(.bottom, 22)
                        
                        // 4. Headline: Google Sans Regular / Lighter Weight
                        Text("Introducing Bhumitra")
                            .font(.googleSans(size: 26, weight: .regular))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 6)
                        
                        // 5. Subtitle & Powered-by byline (Small & Refined)
                        HStack(spacing: 5) {
                            Text("Explore official land records | Powered by")
                                .font(.googleSans(size: 13.5, weight: .regular))
                                .foregroundColor(Color(white: 0.62))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(white: 0.70))
                                
                                Text("Odisha Bhulekh")
                                    .font(.googleSans(size: 13.5, weight: .medium))
                                    .foregroundColor(Color(white: 0.75))
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 34)
                        
                        // 6. Outlined Feature Rows with Small Dark Circular Badges
                        VStack(alignment: .leading, spacing: 22) {
                            featureRow(
                                icon: "bubble.left",
                                title: "Live vector parcels & cadastral maps"
                            )
                            
                            featureRow(
                                icon: "doc.on.doc",
                                title: "Instant official RoR & ownership lookup"
                            )
                            
                            featureRow(
                                icon: "slider.horizontal.3",
                                title: "Land area converter & offline PDF passes"
                            )
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 36)
                        
                        // 7. Plot-Card Matched Primary Action Button (.buttonStyle(.glassProminent))
                        Button {
                            Theme.haptic(.medium)
                            markOnboardingCompleted()
                            onDismiss()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text("Explore Bhumitra")
                                    .font(Theme.Typography.button)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Color.accentColor)
                        .padding(.bottom, 36)
                        
                        // 8. Legal & Compliance Disclosure Paragraph
                        Text("Land records and cadastral boundaries are sourced from Odisha Bhulekh (NIC) and official state cadastral portals. Records and offline exports are stored locally on your device in accordance with our [Privacy Policy](https://kirtidhwajpatra.github.io/privacy-policy). Official certified copies must be obtained from the respective Tahasil Revenue Office. [Learn more](https://kirtidhwajpatra.github.io/privacy-policy).")
                            .font(.googleSans(size: 11, weight: .regular))
                            .foregroundColor(Color(white: 0.48))
                            .tint(Color(white: 0.80))
                            .lineSpacing(3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .sheet(isPresented: $showDisclaimerSheet) {
            DisclaimerView()
        }
    }
    
    // MARK: - Feature Bullet Row Builder
    
    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            // Small Dark Circular Icon Badge (~34x34) with Outlined Symbol
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white)
            }
            
            // Feature Title (Google Sans Regular 15pt)
            Text(title)
                .font(.googleSans(size: 15, weight: .regular))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
    
    // MARK: - Onboarding Completion
    
    private func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: "has_completed_bhumitra_onboarding")
    }
}
