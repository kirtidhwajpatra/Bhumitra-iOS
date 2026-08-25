import SwiftUI
import AuthenticationServices
import CoreLocation

// ============================================================
// MARK: - BHUMITRA DIGITAL SERVICES & SETTINGS (FULL SCREEN REDESIGN)
// ============================================================

/// Streamlined, Apple-grade Full Screen Digital Services & Settings.
/// Features a prominent Bhumitra Pro banner, Apple ID Account management,
/// essential map preferences, and legal/support compliance links.
public struct QuickFeaturesSheet: View {
    @ObservedObject public var viewModel: MapViewModel
    public let onDismiss: () -> Void
    
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showSubscriptionCover: Bool = false
    @State private var showOnboardingCover: Bool = false
    @State private var showLoginCover: Bool = false
    @State private var showDisclaimerSheet: Bool = false
    @State private var showSignOutAlert: Bool = false
    
    public init(viewModel: MapViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.85)
    }
    
    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }
    
    public var body: some View {
        ZStack {
            // App Atmosphere Backdrop
            AppAtmosphereBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. TOP FULL-SCREEN NAVIGATION BAR
                topNavigationBar
                
                // 2. SCROLLABLE FOCUSED SETTINGS CONTENT
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Section 1: Bhumitra Pro Hero Card
                        proHeroBanner
                        
                        // Section 2: Account & Apple Sign-In
                        accountSection
                        
                        // Section 3: Map & Layer Preferences
                        mapPreferencesSection
                        
                        // Section 4: Help, Support & Legal Compliance
                        supportAndLegalSection
                        
                        // Section 5: App Version & Attribution Footer
                        appVersionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: $showSubscriptionCover) {
            SubscriptionView()
        }
        .fullScreenCover(isPresented: $showOnboardingCover) {
            OnboardingView(onDismiss: {
                showOnboardingCover = false
            })
        }
        .fullScreenCover(isPresented: $showLoginCover) {
            LoginView(onDismiss: {
                showLoginCover = false
            })
        }
        .sheet(isPresented: $showDisclaimerSheet) {
            DisclaimerView()
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Theme.haptic(.medium)
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out of your Apple ID account? Your local cached records will remain on device.")
        }
    }
    
    // ============================================================
    // MARK: - 1. TOP NAVIGATION BAR
    // ============================================================
    
    private var topNavigationBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Settings & Services")
                    .font(.googleSans(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Color.primaryText)
                
                Text("Preferences, account & land intelligence")
                    .font(.googleSans(size: 13, weight: .regular))
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            
            Spacer()
            
            Button {
                Theme.haptic(.light)
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Color.primaryText)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Close settings")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
    
    // ============================================================
    // MARK: - 2. BHUMITRA PRO HERO BANNER
    // ============================================================
    
    private var proHeroBanner: some View {
        Button {
            Theme.haptic(.medium)
            showSubscriptionCover = true
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        // Glowing Crown Emblem
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.neonPurple.opacity(0.35), Color.accentColor.opacity(0.20)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                            
                            Image(systemName: subscriptionManager.isPremium ? "crown.fill" : "sparkles")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Theme.neonPurple)
                                .shadow(color: Theme.neonPurple.opacity(0.6), radius: 8)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Bhumitra Pro")
                                    .font(.googleSans(size: 18, weight: .bold))
                                    .foregroundColor(Theme.Color.primaryText)
                                
                                Text(subscriptionManager.isPremium ? "ACTIVE" : "UNLIMITED")
                                    .font(.googleSans(size: 9.5, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Theme.neonPurple, Color(red: 130/255, green: 50/255, blue: 240/255)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                            }
                            
                            Text(subscriptionManager.isPremium ?
                                 "Full access to 4K cadastral overlays & PDF exports" :
                                 "Unlock unlimited official RoR downloads & 4K GIS tools")
                                .font(.googleSans(size: 13, weight: .regular))
                                .foregroundColor(Theme.Color.secondaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                    }
                    
                    // Native Action Button inside Banner
                    HStack {
                        Text(subscriptionManager.isPremium ? "Manage Membership" : "Upgrade to Pro")
                            .font(Theme.Typography.button)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.neonPurple, Color.accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundColor(.white)
                    .shadow(color: Theme.neonPurple.opacity(0.30), radius: 8, y: 3)
                }
                .padding(18)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.neonPurple.opacity(0.12),
                                        Color.accentColor.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Theme.neonPurple.opacity(0.50),
                                    Color.accentColor.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.25
                        )
                )
                .shadow(color: Theme.neonPurple.opacity(0.14), radius: 16, y: 6)
            }
        }
        .buttonStyle(ScaledButtonStyle())
    }
    
    // ============================================================
    // MARK: - 3. ACCOUNT & SIGN-IN SECTION
    // ============================================================
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACCOUNT & PROFILE")
                .font(.googleSans(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.8)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                if authManager.isAuthenticated, let user = authManager.currentUser {
                    // Authenticated User Profile Row
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name.isEmpty ? "Apple User" : user.name)
                                .font(.googleSans(size: 15, weight: .semibold))
                                .foregroundColor(Theme.Color.primaryText)
                            
                            if !user.email.isEmpty {
                                Text(user.email)
                                    .font(.googleSans(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("Signed in with Apple ID")
                                    .font(.googleSans(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Sign Out") {
                            Theme.haptic(.light)
                            showSignOutAlert = true
                        }
                        .font(.googleSans(size: 12, weight: .bold))
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.10))
                        .clipShape(Capsule())
                    }
                    .padding(14)
                } else {
                    // Sign in with Apple CTA Row
                    Button {
                        Theme.haptic(.light)
                        showLoginCover = true
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "applelogo")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Theme.Color.primaryText)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign in with Apple")
                                    .font(.googleSans(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.Color.primaryText)
                                
                                Text("Sync verified parcels & saved searches")
                                    .font(.googleSans(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
        }
    }
    
    // ============================================================
    // MARK: - 4. MAP & LAYER PREFERENCES
    // ============================================================
    
    private var mapPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MAP & LAYER CONTROLS")
                .font(.googleSans(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.8)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                // Satellite Toggle
                HStack(spacing: 14) {
                    settingIcon(icon: "square.3.layers.3d.fill", color: .teal)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("High-Res Satellite Imagery")
                            .font(.googleSans(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Color.primaryText)
                        Text(viewModel.isSatellite ? "High-res satellite terrain" : "Standard vector base map")
                            .font(.googleSans(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { viewModel.isSatellite },
                        set: { _ in
                            Theme.haptic(.light)
                            viewModel.toggleSatellite()
                        }
                    ))
                    .labelsHidden()
                }
                .padding(14)
                
                Divider()
                    .padding(.leading, 56)
                
                // Cadastral Parcels Toggle
                HStack(spacing: 14) {
                    settingIcon(icon: "map.fill", color: Theme.Color.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cadastral Parcel Boundaries")
                            .font(.googleSans(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Color.primaryText)
                        Text(viewModel.showParcels ? "Survey boundaries visible" : "Parcels hidden")
                            .font(.googleSans(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { viewModel.showParcels },
                        set: { _ in
                            Theme.haptic(.light)
                            viewModel.toggleParcels()
                        }
                    ))
                    .labelsHidden()
                }
                .padding(14)
                
                Divider()
                    .padding(.leading, 56)
                
                // Location Permission / System Settings
                Button {
                    Theme.haptic(.light)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 14) {
                        settingIcon(icon: "location.fill", color: .blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location Services")
                                .font(.googleSans(size: 15, weight: .semibold))
                                .foregroundColor(Theme.Color.primaryText)
                            Text("On-demand GPS position access")
                                .font(.googleSans(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("System Settings")
                                .font(.googleSans(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
        }
    }
    
    // ============================================================
    // MARK: - 5. SUPPORT & LEGAL COMPLIANCE
    // ============================================================
    
    private var supportAndLegalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HELP & COMPLIANCE")
                .font(.googleSans(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.8)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                // 1. App Introduction Tour
                Button {
                    Theme.haptic(.light)
                    showOnboardingCover = true
                } label: {
                    linkRow(
                        icon: "sparkles",
                        iconColor: .purple,
                        title: "App Introduction & Tour",
                        subtitle: "Welcome guide & feature overview"
                    )
                }
                .buttonStyle(.plain)
                
                Divider().padding(.leading, 56)
                
                // 2. Legal Disclaimer
                Button {
                    Theme.haptic(.light)
                    showDisclaimerSheet = true
                } label: {
                    linkRow(
                        icon: "exclamationmark.shield.fill",
                        iconColor: .orange,
                        title: "Legal Disclaimer",
                        subtitle: "Non-government data notice & terms"
                    )
                }
                .buttonStyle(.plain)
                
                Divider().padding(.leading, 56)
                
                // 3. Help & Support
                if let supportURL = URL(string: "https://kirtidhwajpatra.github.io/bhumitra-support/") {
                    Link(destination: supportURL) {
                        linkRow(
                            icon: "questionmark.circle.fill",
                            iconColor: .blue,
                            title: "Help & Contact",
                            subtitle: "Documentation, user guides & support"
                        )
                    }
                }
                
                Divider().padding(.leading, 56)
                
                // 4. Privacy Policy
                if let privacyURL = URL(string: "https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/") {
                    Link(destination: privacyURL) {
                        linkRow(
                            icon: "hand.raised.fill",
                            iconColor: .indigo,
                            title: "Privacy Policy",
                            subtitle: "Data encryption & privacy compliance"
                        )
                    }
                }
                
                Divider().padding(.leading, 56)
                
                // 5. Terms of Service
                if let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    Link(destination: termsURL) {
                        linkRow(
                            icon: "doc.plaintext.fill",
                            iconColor: .gray,
                            title: "Terms of Service",
                            subtitle: "Apple Standard EULA terms"
                        )
                    }
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
        }
    }
    
    // ============================================================
    // MARK: - 6. APP VERSION & FOOTER
    // ============================================================
    
    private var appVersionFooter: some View {
        VStack(spacing: 6) {
            Text("Bhumitra for iOS • Version 1.0.0 (Build 6)")
                .font(.googleSans(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Odisha Cadastral Mapping & RoR Intelligence")
                .font(.googleSans(size: 11, weight: .regular))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
    
    // ============================================================
    // MARK: - ROW BUILDERS & HELPERS
    // ============================================================
    
    private func linkRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            settingIcon(icon: icon, color: iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.googleSans(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Color.primaryText)
                
                Text(subtitle)
                    .font(.googleSans(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(14)
    }
    
    private func settingIcon(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: 36, height: 36)
            
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
    }
}
