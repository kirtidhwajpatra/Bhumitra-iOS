import SwiftUI

// ============================================================
// MARK: - BHUMITRA ONBOARDING EXPERIENCE (EXACT REFERENCE REFINEMENT)
// ============================================================

/// Pixel-perfect onboarding modal matching the reference design:
/// - Light regular-weight Google Sans headline
/// - Clean 2-line centered byline
/// - Perfectly centered 3-4 word feature bullet rows with small dark circle outlined icons
/// - Plot card matched .buttonStyle(.glassProminent) CTA
/// - True absolute bottom compliance disclosure placement
public struct OnboardingView: View {
    public let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var startTime: Date = Date()
    @State private var showDisclaimerSheet: Bool = false
    
    public init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // 1. Looping Animated Video Background
            LoopingVideoBackgroundView(videoName: "onboarding_bg", videoExtension: "mp4")
                .ignoresSafeArea()
            
            // 2. Cinematic Dark Scrim & Gradient Overlay for pristine readability
            ZStack {
                Color.black.opacity(0.50)
                
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.70),
                        Color.black.opacity(0.40),
                        Color.black.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
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
                            .font(.system(size: 15, weight: .regular))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Close")
                    .padding(.trailing, 20)
                    .padding(.top, 14)
                }
                
                // 3. Main Center Body (Properly Vertically Distributed)
                VStack(spacing: 0) {
                    Spacer(minLength: 12)
                    
                    // A. Hero Icon (Outlined Minimalist Passport Book)
                    ZStack {
                        Image(systemName: "book.pages")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 20)
                    
                    // B. Headline: Google Sans Regular
                    Text("Introducing Bhumitra")
                        .font(.googleSans(size: 26, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                    
                    // C. Centered 2-Line Byline with Badge
                    VStack(spacing: 4) {
                        Text("Explore official land records | Powered by")
                            .font(.googleSans(size: 14, weight: .regular))
                            .foregroundColor(Color(white: 0.60))
                        
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(Color(white: 0.70))
                            
                            Text("Odisha Bhulekh")
                                .font(.googleSans(size: 14, weight: .medium))
                                .foregroundColor(Color(white: 0.82))
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    // D. Centered 3 Feature Bullet Rows
                    VStack(alignment: .leading, spacing: 18) {
                        featureRow(icon: "map", title: "Interactive cadastral village maps")
                        featureRow(icon: "doc.text.fill", title: "Authoritative RoR & plot details")
                        featureRow(icon: "shield.checkmark.fill", title: "Official land verification & offline save")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    
                    // E. Prominent Glass CTA Button
                    Button {
                        Theme.haptic(.medium)
                        markOnboardingCompleted()
                        onDismiss()
                        dismiss()
                    } label: {
                        Text("Get Started")
                            .font(.googleSans(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.accentColor)
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 28)
                    
                    // F. Absolute Bottom Legal & Compliance Disclosure
                    Text("Land records and cadastral boundaries are sourced from Odisha Bhulekh (NIC) and official state cadastral portals. Records and offline exports are stored locally on your device in accordance with our [Privacy Policy](https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/). Official certified copies must be obtained from the respective Tahasil Revenue Office. [Learn more](https://kirtidhwajpatra.github.io/bhumitra-support/).")
                        .font(.googleSans(size: 11, weight: .regular))
                        .foregroundColor(Color(white: 0.45))
                        .tint(Color(white: 0.78))
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 22)
                }
            }
        }
        .onAppear {
            startTime = Date()
            AnalyticsService.shared.log(.onboardingStarted(source: "first_launch"))
        }
        .sheet(isPresented: $showDisclaimerSheet) {
            DisclaimerView()
        }
    }
    
    // MARK: - Feature Bullet Row Builder
    
    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            // Small Dark Circular Icon Badge (~34x34) with Outlined Symbol
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white)
            }
            
            // Feature Title (Google Sans Regular 15.5pt)
            Text(title)
                .font(.googleSans(size: 15.5, weight: .regular))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Onboarding Completion
    
    private func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: "has_completed_bhumitra_onboarding")
        let duration = max(1, Int(Date().timeIntervalSince(startTime)))
        AnalyticsService.shared.log(.onboardingCompleted(durationSeconds: duration))
    }
}
