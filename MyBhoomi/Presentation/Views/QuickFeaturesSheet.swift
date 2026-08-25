import SwiftUI
import AuthenticationServices
import CoreLocation

// ============================================================
// MARK: - BHUMITRA DIGITAL SERVICES & SETTINGS (GOOGLE / APPLE GRADE REDESIGN)
// ============================================================

/// Full screen Settings & Digital Services matching the exact clean card architecture:
/// Profile Header -> Manage Account Pill -> Grouped Settings List -> Privacy/Terms & Version Footer.
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
    
    // Dynamic background matching theme
    private var pageBackground: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.10),
                        Color(red: 0.04, green: 0.05, blue: 0.07)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 242/255, green: 245/255, blue: 250/255),
                        Color(red: 234/255, green: 240/255, blue: 248/255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.07)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.07, green: 0.10, blue: 0.16)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.65) : Color(red: 95/255, green: 99/255, blue: 104/255)
    }
    
    private var chevronColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.40) : Color(red: 180/255, green: 185/255, blue: 192/255)
    }
    
    public var body: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar with "Done" action button
                topBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // 1. Profile / Account Header Card (Liquid Glass)
                        profileHeaderCard
                        
                        // 2. Manage Account Capsule Pill (Liquid Glass)
                        manageAccountPill
                        
                        // 3. Main Grouped Settings List (Liquid Glass)
                        groupedSettingsCard
                        
                        // 4. Footer: Privacy Policy • Terms of Service & Version
                        footerSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 36)
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
            Text("Are you sure you want to sign out of your account? Your local saved plots and cached records will remain safe on your device.")
        }
    }
    
    // ============================================================
    // MARK: - 1. TOP BAR
    // ============================================================
    
    private var topBar: some View {
        HStack {
            Spacer()
            
            Button(action: {
                Theme.haptic(.light)
                onDismiss()
            }) {
                Text("Done")
                    .font(.googleSans(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 26/255, green: 115/255, blue: 232/255))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(
                        .regular.interactive(),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
    
    // ============================================================
    // MARK: - 2. USER PROFILE HEADER CARD (LIQUID GLASS)
    // ============================================================
    
    private var profileHeaderCard: some View {
        Button(action: {
            Theme.haptic(.light)
            if authManager.isAuthenticated {
                showSignOutAlert = true
            } else {
                showLoginCover = true
            }
        }) {
            HStack(spacing: 16) {
                // Profile Avatar Circle with edit badge
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 74/255, green: 20/255, blue: 140/255), Color(red: 106/255, green: 27/255, blue: 154/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                    
                    Text(avatarInitial)
                        .font(.googleSans(size: 26, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                    
                    // Edit pencil badge
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white)
                            .frame(width: 22, height: 22)
                        
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color(red: 238/255, green: 242/255, blue: 246/255))
                            .frame(width: 18, height: 18)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(primaryTextColor)
                    }
                    .offset(x: 2, y: 2)
                }
                
                // User Details
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.googleSans(size: 18, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    Text(displayEmail)
                        .font(.googleSans(size: 13.5, weight: .regular))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Dropdown / chevron circular pill
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.05))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(secondaryTextColor)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.05), radius: 10, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // ============================================================
    // MARK: - 3. MANAGE ACCOUNT PILL CARD (LIQUID GLASS)
    // ============================================================
    
    private var manageAccountPill: some View {
        Button(action: {
            Theme.haptic(.light)
            if authManager.isAuthenticated {
                showSignOutAlert = true
            } else {
                showLoginCover = true
            }
        }) {
            HStack(spacing: 12) {
                // Account Icon
                Image(systemName: "applelogo")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                    .frame(width: 24)
                
                Text(authManager.isAuthenticated ? "Manage your Account" : "Sign in to sync saved parcels")
                    .font(.googleSans(size: 15, weight: .medium))
                    .foregroundColor(primaryTextColor)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .glassEffect(
                .regular.interactive(),
                in: Capsule()
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.05), radius: 10, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // ============================================================
    // MARK: - 4. MAIN GROUPED SETTINGS CARD
    // ============================================================
    
    private var groupedSettingsCard: some View {
        VStack(spacing: 0) {
            // Row 1: Bhumitra Pro / Subscription
            Button(action: {
                Theme.haptic(.medium)
                showSubscriptionCover = true
            }) {
                rowLayout(
                    icon: "crown",
                    title: "Bhumitra Pro",
                    badgeText: subscriptionManager.isPremium ? "Active" : nil,
                    badgeColor: subscriptionManager.isPremium ? .green : nil
                )
            }
            .buttonStyle(.plain)
            
            divider
            
            // Row 2: High-Res Satellite Imagery Toggle
            HStack(spacing: 14) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(primaryTextColor)
                    .frame(width: 24)
                
                Text("Satellite High-Res Imagery")
                    .font(.googleSans(size: 15.5, weight: .medium))
                    .foregroundColor(primaryTextColor)
                
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
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            
            divider
            
            // Row 3: Cadastral Boundaries Toggle
            HStack(spacing: 14) {
                Image(systemName: "map")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(primaryTextColor)
                    .frame(width: 24)
                
                Text("Cadastral Parcel Boundaries")
                    .font(.googleSans(size: 15.5, weight: .medium))
                    .foregroundColor(primaryTextColor)
                
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
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            
            divider
            
            // Row 4: Location Services
            Button(action: {
                Theme.haptic(.light)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                rowLayout(
                    icon: "location",
                    title: "Location Services",
                    badgeText: nil,
                    badgeColor: nil
                )
            }
            .buttonStyle(.plain)
            
            divider
            
            // Row 5: App Introduction & Tour
            Button(action: {
                Theme.haptic(.light)
                showOnboardingCover = true
            }) {
                rowLayout(
                    icon: "sparkles",
                    title: "App Introduction & Tour",
                    badgeText: "New",
                    badgeColor: Color(red: 26/255, green: 115/255, blue: 232/255)
                )
            }
            .buttonStyle(.plain)
            
            divider
            
            // Row 6: Legal Disclaimer
            Button(action: {
                Theme.haptic(.light)
                showDisclaimerSheet = true
            }) {
                rowLayout(
                    icon: "exclamationmark.shield",
                    title: "Legal Disclaimer",
                    badgeText: nil,
                    badgeColor: nil
                )
            }
            .buttonStyle(.plain)
            
            divider
            
            // Row 7: Report a Problem / Feedback
            if let supportURL = URL(string: "https://kirtidhwajpatra.github.io/bhumitra-support/") {
                Link(destination: supportURL) {
                    rowLayout(
                        icon: "bubble.left.and.exclamationmark.bubble.right",
                        title: "Report a problem",
                        badgeText: nil,
                        badgeColor: nil
                    )
                }
            }
            
            divider
            
            // Row 8: Help & Guides
            if let supportURL = URL(string: "https://kirtidhwajpatra.github.io/bhumitra-support/") {
                Link(destination: supportURL) {
                    rowLayout(
                        icon: "questionmark.circle",
                        title: "Help & User Guide",
                        badgeText: nil,
                        badgeColor: nil
                    )
                }
            }
        }
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.05), radius: 10, y: 2)
    }
    
    // Row layout helper matching Google / Apple Settings
    private func rowLayout(icon: String, title: String, badgeText: String? = nil, badgeColor: Color? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(primaryTextColor)
                .frame(width: 24)
            
            Text(title)
                .font(.googleSans(size: 15.5, weight: .medium))
                .foregroundColor(primaryTextColor)
            
            Spacer()
            
            if let badge = badgeText, let color = badgeColor {
                Text(badge)
                    .font(.googleSans(size: 11.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(color)
                    )
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(chevronColor)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
    
    private var divider: some View {
        Divider()
            .background(dividerColor)
            .padding(.leading, 56)
    }
    
    // ============================================================
    // MARK: - 5. FOOTER (Privacy Policy • Terms of Service & Version)
    // ============================================================
    
    private var footerSection: some View {
        VStack(spacing: 10) {
            // Inline Privacy Policy • Terms of Service links
            HStack(spacing: 12) {
                if let privacyURL = URL(string: "https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/") {
                    Link("Privacy Policy", destination: privacyURL)
                        .font(.googleSans(size: 13, weight: .medium))
                        .foregroundColor(primaryTextColor)
                }
                
                Text("•")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(secondaryTextColor)
                
                if let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    Link("Terms of Service", destination: termsURL)
                        .font(.googleSans(size: 13, weight: .medium))
                        .foregroundColor(primaryTextColor)
                }
            }
            .padding(.top, 14)
            
            // App Version & Copyright notice
            Text("Bhumitra for iOS • Version 1.0.0 (Build 6)")
                .font(.googleSans(size: 11.5, weight: .regular))
                .foregroundColor(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
    
    // ============================================================
    // MARK: - COMPUTED PROPERTIES
    // ============================================================
    
    private var displayName: String {
        if authManager.isAuthenticated, let name = authManager.currentUser?.name, !name.isEmpty && name != "Apple User" {
            return name
        }
        return "Kirtidhwaj Patra"
    }
    
    private var displayEmail: String {
        if authManager.isAuthenticated, let email = authManager.currentUser?.email, !email.isEmpty {
            return email
        }
        return "kirtidhwajpatra@gmail.com"
    }
    
    private var avatarInitial: String {
        let name = displayName
        if let first = name.first {
            return String(first).uppercased()
        }
        return "K"
    }
}
