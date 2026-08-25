import SwiftUI

// ============================================================
// MARK: - BHUMITRA ONBOARDING EXPERIENCE
// ============================================================

/// Pixel-perfect onboarding screen matching the reference minimalist design:
/// Centered hero icon, bold headline, powered-by byline, dark circular feature badges,
/// centered primary action capsule, and compliance footer with active links.
public struct OnboardingView: View {
    public let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showDisclaimerSheet: Bool = false
    @State private var showPrivacySheet: Bool = false
    @State private var appearAnimation: Bool = false
    
    public init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // 1. Pure Deep Black Canvas
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Top Navigation Bar: Right Close Button
                HStack {
                    Spacer()
                    
                    Button {
                        Theme.haptic(.light)
                        markOnboardingCompleted()
                        onDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.googleSans(size: 16.5, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaledButtonStyle())
                    .accessibilityLabel("Close")
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 20)
                        
                        // 3. Hero Icon (Outlined Minimalist Double Sheet / Land Passport)
                        ZStack {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 56, weight: .light))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 24)
                        
                        // 4. Main Headline
                        Text("Introducing Bhumitra")
                            .font(.googleSans(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                        
                        // 5. Byline / Powered By Tag
                        VStack(spacing: 4) {
                            Text("Explore official Odisha land records")
                                .font(.googleSans(size: 15.5, weight: .regular))
                                .foregroundColor(Color(white: 0.70))
                            
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(white: 0.65))
                                
                                Text("Odisha Bhulekh & Cadastral GIS")
                                    .font(.googleSans(size: 15, weight: .medium))
                                    .foregroundColor(Color(white: 0.78))
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 36)
                        
                        // 6. Feature Bullets with Dark Circular Icon Badges
                        VStack(alignment: .leading, spacing: 20) {
                            featureRow(
                                icon: "map.fill",
                                title: "Live vector parcels & cadastral maps"
                            )
                            
                            featureRow(
                                icon: "doc.text.fill",
                                title: "Instant official RoR & ownership lookup"
                            )
                            
                            featureRow(
                                icon: "slider.horizontal.3",
                                title: "Land area converter & offline PDF passes"
                            )
                        }
                        .padding(.horizontal, 36)
                        .padding(.bottom, 38)
                        
                        // 7. Centered Primary Action Capsule Button
                        Button {
                            Theme.haptic(.medium)
                            markOnboardingCompleted()
                            onDismiss()
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Explore Bhumitra")
                                    .font(.googleSans(size: 16.5, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color(red: 26/255, green: 86/255, blue: 219/255))
                            )
                        }
                        .buttonStyle(ScaledButtonStyle())
                        .padding(.bottom, 38)
                        
                        // 8. Legal & Compliance Disclosure Paragraph
                        Text("Land records and cadastral boundaries are sourced from Odisha Bhulekh (NIC) and official state cadastral portals. Records and offline exports are stored locally on your device in accordance with our [Privacy Policy](https://kirtidhwajpatra.github.io/privacy-policy). Official certified copies must be obtained from the respective Tahasil Revenue Office. [Learn more](https://kirtidhwajpatra.github.io/privacy-policy).")
                            .font(.googleSans(size: 11.5, weight: .regular))
                            .foregroundColor(Color(white: 0.55))
                            .tint(Color(white: 0.85))
                            .lineSpacing(3.5)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
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
        HStack(spacing: 16) {
            // Dark Circular Icon Badge
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Feature Title
            Text(title)
                .font(.googleSans(size: 16.5, weight: .regular))
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
