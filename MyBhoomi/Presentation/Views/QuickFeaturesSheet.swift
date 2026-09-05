//
//  QuickFeaturesSheet.swift
//  MyBhoomi
//
//  Pixel-perfect implementation of Settings / Profile Screen.
//  Matching Figma / user specification:
//  - Top navigation bar with circular back button and centered "Settings" title
//  - Grey circular user avatar with bold user email
//  - 3 Pastel lavender stat cards (Plan, Search credit, Saved land)
//  - Pastel yellow "Get unlimited plot search" banner with purple flame
//  - Grouped clean menu list (Account, Subscription, Saved lands, Appearance, Location services, Data, Bug report & feedback, Rate us, Privacy security, Sign out)
//

import SwiftUI
import AuthenticationServices
import CoreLocation
import StoreKit

public struct QuickFeaturesSheet: View {
    @ObservedObject public var viewModel: MapViewModel
    public let onDismiss: () -> Void
    
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var savedLandManager = SavedLandManager.shared
    @ObservedObject private var navManager = AppNavigationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    
    @State private var showManageAccountSheet: Bool = false
    @State private var showSavedLandsSheet: Bool = false
    @State private var showSubscriptionCover: Bool = false
    @State private var showLoginCover: Bool = false
    @State private var showDisclaimerSheet: Bool = false
    @State private var showSignOutAlert: Bool = false
    @State private var showClearDataAlert: Bool = false
    @State private var showDataClearedToast: Bool = false
    @State private var showAppearanceSheet: Bool = false
    
    // Palette Colors matching design
    private let cardBackground = Color(red: 248 / 255, green: 244 / 255, blue: 254 / 255) // #F8F4FE
    private let bannerBackground = Color(red: 254 / 255, green: 247 / 255, blue: 200 / 255) // #FEF7C8
    private let electricPurple = Color(red: 116 / 255, green: 18 / 255, blue: 250 / 255) // #7412FA
    private let rowTextColor = Color(red: 60 / 255, green: 60 / 255, blue: 64 / 255)     // #3C3C40
    private let subtitleGrey = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255) // #8E8E93
    
    public init(viewModel: MapViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // White Canvas Background
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Top Navigation Bar
                topNavBar
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 2. User Avatar & Email
                        profileSection
                            .padding(.top, 10)
                            .padding(.bottom, 22)
                        
                        // 3. Three Stat Cards (Plan, Search credit, Saved land)
                        statsRow
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                        
                        // 4. Upgrade Banner ("Get unlimited plot search 🔥")
                        upgradeBanner
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                        
                        // 5. Menu Items List
                        menuListSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 100)
                    }
                }
            }
            
            // Data Cleared Toast
            if showDataClearedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Cached data cleared successfully")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
        .fullScreenCover(isPresented: $showManageAccountSheet) {
            ManageAccountView()
        }
        .fullScreenCover(isPresented: $showSavedLandsSheet) {
            SavedLandsView()
        }
        .fullScreenCover(isPresented: $showSubscriptionCover) {
            SubscriptionView()
        }
        .fullScreenCover(isPresented: $showLoginCover) {
            LoginView(onDismiss: { showLoginCover = false })
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
            Text("Are you sure you want to sign out? Your saved plots and offline data will remain safe on this device.")
        }
        .alert("Clear Local Data & Cache", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Cache", role: .destructive) {
                Theme.haptic(.medium)
                VerifiedParcelCache.shared.clearHistory()
                withAnimation {
                    showDataClearedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showDataClearedToast = false
                    }
                }
            }
        } message: {
            Text("This will purge temporary offline map tiles and cached land records. Your saved bookmark lands will NOT be deleted.")
        }
    }
    
    // ============================================================
    // MARK: - 1. TOP NAVIGATION BAR
    // ============================================================
    
    private var topNavBar: some View {
        HStack {
            // Circular Back Button
            Button {
                onDismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#EAEAEA"), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#444444"))
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Home")
            
            Spacer()
            
            Text("Settings")
                .font(.stackSansHeadline(size: 26, weight: .bold))
                .foregroundColor(Color.black)
            
            Spacer()
            
            // Balancing spacer for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    // ============================================================
    // MARK: - 2. USER PROFILE SECTION
    // ============================================================
    
    private var profileSection: some View {
        Button {
            if authManager.isAuthenticated {
                showManageAccountSheet = true
            } else {
                showLoginCover = true
            }
        } label: {
            VStack(spacing: 10) {
                // Avatar Disc
                ZStack {
                    if authManager.isAuthenticated, let user = authManager.currentUser, !user.name.isEmpty && user.name != "Apple User" && user.name != "Google User" {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 116 / 255, green: 18 / 255, blue: 250 / 255), Color(red: 70 / 255, green: 0 / 255, blue: 199 / 255)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 68, height: 68)
                        
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .fill(Color(hex: "#E5E5EA"))
                            .frame(width: 68, height: 68)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Color(hex: "#8E8E93"))
                    }
                }
                
                // User Email / Identifier / Name
                VStack(spacing: 6) {
                    Text(userPrimaryIdentifierDisplay)
                        .font(.stackSansHeadline(size: 16.5, weight: .bold))
                        .foregroundColor(Color.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                    
                    // Auth Provider / Method Badge
                    authMethodBadge
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var userPrimaryIdentifierDisplay: String {
        if authManager.isAuthenticated, let user = authManager.currentUser {
            if !user.email.isEmpty {
                return user.email
            } else if !user.name.isEmpty && user.name != "Apple User" && user.name != "Google User" {
                return user.name
            } else if !user.id.isEmpty {
                let raw = user.id.replacingOccurrences(of: "google_", with: "")
                let cleanId: String
                if let dotIndex = raw.firstIndex(of: ".") {
                    let prefix = String(raw[..<dotIndex])
                    cleanId = prefix.isEmpty ? String(raw.prefix(8)) : prefix
                } else if raw.count > 8 {
                    cleanId = String(raw.prefix(8))
                } else {
                    cleanId = raw
                }
                return "User ID: \(cleanId)"
            }
        }
        return "Guest User"
    }
    
    @ViewBuilder
    private var authMethodBadge: some View {
        switch authManager.currentAuthProvider {
        case .apple:
            HStack(spacing: 5) {
                Image(systemName: "applelogo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#1D1D1F"))
                Text("Signed in with Apple")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#555555"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: "#F2F2F7"))
            .clipShape(Capsule())
            
        case .google:
            HStack(spacing: 5) {
                GoogleLogoView(size: 12)
                Text("Signed in with Google")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#555555"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: "#F2F2F7"))
            .clipShape(Capsule())
            
        case .guest:
            HStack(spacing: 5) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("Sign In with Apple or Google")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(electricPurple)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(electricPurple.opacity(0.10))
            .clipShape(Capsule())
        }
    }
    
    // ============================================================
    // MARK: - 3. THREE STAT CARDS ROW
    // ============================================================
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            // Card 1: Plan (Free / Pro / Unlimited)
            statCard(
                value: planDisplayValue,
                subtitle: "Plan"
            )
            
            // Card 2: Search credit (Live sync with remaining plot search credits)
            statCard(
                value: searchCreditDisplayValue,
                subtitle: "Search credit"
            )
            
            // Card 3: Saved land (Live sync with saved land records)
            statCard(
                value: "\(savedLandManager.totalSavedCount)",
                subtitle: "Saved land"
            )
        }
    }
    
    private var planDisplayValue: String {
        if subscriptionManager.isPremium {
            return "Pro"
        } else if subscriptionManager.isUnlimited {
            return "Unlimited"
        } else {
            return "Free"
        }
    }
    
    private var searchCreditDisplayValue: String {
        if subscriptionManager.isUnlimited || subscriptionManager.isPremium {
            return "∞"
        } else {
            return "\(subscriptionManager.remainingPlotCredits)"
        }
    }
    
    private func statCard(value: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.stackSansHeadline(size: 24, weight: .bold))
                .foregroundColor(Color.black)
            
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(subtitleGrey)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
    
    // ============================================================
    // MARK: - 4. UPGRADE BANNER
    // ============================================================
    
    private var upgradeBanner: some View {
        Button {
            showSubscriptionCover = true
        } label: {
            HStack {
                Text("Get unlimited plot search")
                    .font(.stackSansHeadline(size: 16.5, weight: .bold))
                    .foregroundColor(Color.black)
                
                Spacer()
                
                Image("PurpleFlameGraphic")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 38)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(bannerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // ============================================================
    // MARK: - 5. MENU ITEMS LIST
    // ============================================================
    
    private var menuListSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Section 1: Account, Subscription, Saved lands
            VStack(alignment: .leading, spacing: 18) {
                menuRow(icon: "at", title: "Account") {
                    if authManager.isAuthenticated {
                        showManageAccountSheet = true
                    } else {
                        showLoginCover = true
                    }
                }
                
                menuRow(icon: "cloud", title: "Subscription") {
                    showSubscriptionCover = true
                }
                
                menuRow(icon: "folder", title: "Saved lands") {
                    showSavedLandsSheet = true
                }
            }
            
            // Section 2: Appearance, Location services, Data
            VStack(alignment: .leading, spacing: 18) {
                menuRow(icon: "person.2", title: "Appearance") {
                    // Appearance details / theme preferences
                }
                
                menuRow(icon: "location", title: "Location services") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                
                menuRow(icon: "doc.text", title: "Data") {
                    showClearDataAlert = true
                }
            }
            
            // Section 3: Bug report & feedback, Rate us, Privacy security
            VStack(alignment: .leading, spacing: 18) {
                menuRow(icon: "bubble.left.and.bubble.right", title: "Bug report & feedback") {
                    if let supportURL = URL(string: "https://kirtidhwajpatra.github.io/bhumitra-support/") {
                        openURL(supportURL)
                    }
                }
                
                menuRow(icon: "hand.thumbsup", title: "Rate us") {
                    AppFeedbackManager.shared.requestNativeAppStoreReview()
                }
                
                menuRow(icon: "lock.shield", title: "Privacy security") {
                    if let privacyURL = URL(string: "https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/") {
                        openURL(privacyURL)
                    } else {
                        showDisclaimerSheet = true
                    }
                }
            }
            
            // Section 4: Sign out / Sign in
            VStack(alignment: .leading, spacing: 18) {
                if authManager.isAuthenticated {
                    menuRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign out") {
                        showSignOutAlert = true
                    }
                } else {
                    menuRow(icon: "person.crop.circle.badge.plus", title: "Sign in") {
                        showLoginCover = true
                    }
                }
            }
        }
    }
    
    private func menuRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(rowTextColor)
                    .frame(width: 24, alignment: .leading)
                
                Text(title)
                    .font(.stackSansHeadline(size: 17, weight: .medium))
                    .foregroundColor(rowTextColor)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickFeaturesSheet(viewModel: MapViewModel(), onDismiss: {})
}
