import SwiftUI
import StoreKit

// ============================================================
// MARK: - MANAGE ACCOUNT & SUBSCRIPTION HUB (FULL SCREEN)
// ============================================================

public struct ManageAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var savedLandManager = SavedLandManager.shared
    
    // Presentation States
    @State private var showSubscriptionModal: Bool = false
    @State private var showLoginModal: Bool = false
    @State private var showSavedLandsModal: Bool = false
    @State private var showSignOutDialog: Bool = false
    @State private var showDeleteAccountDialog: Bool = false
    @State private var showClearCacheDialog: Bool = false
    @State private var cacheClearedToast: Bool = false
    
    public init() {}
    
    // Theme Colors
    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 14/255, green: 14/255, blue: 18/255)
            : Color(red: 246/255, green: 247/255, blue: 250/255)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 24/255, green: 25/255, blue: 30/255)
            : Color.white
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 20/255, green: 24/255, blue: 32/255)
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? Color(white: 0.65) : Color(red: 110/255, green: 115/255, blue: 125/255)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
    
    public var body: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                customNavigationBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // 1. Identity & Profile Card
                        identityProfileCard
                        
                        // 2. Active Subscription & Quota Card
                        subscriptionQuotaCard
                        
                        // 3. On-Device Vault & Cache Management Card
                        storageAndVaultCard
                        
                        // 4. Account Actions Card
                        accountActionsCard
                        
                        // 5. Legal & Compliance Footer
                        legalFooter
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                }
            }
        }
        .fullScreenCover(isPresented: $showSubscriptionModal) {
            SubscriptionView()
        }
        .fullScreenCover(isPresented: $showLoginModal) {
            LoginView(onDismiss: { showLoginModal = false })
        }
        .fullScreenCover(isPresented: $showSavedLandsModal) {
            SavedLandsView()
        }
        // Confirmation Dialogs
        .confirmationDialog(
            "Sign Out of Bhumitra?",
            isPresented: $showSignOutDialog,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Theme.haptic(.medium)
                authManager.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to sign in again to sync your identity. Your on-device saved lands remain safely stored.")
        }
        .confirmationDialog(
            "Delete Account & Data?",
            isPresented: $showDeleteAccountDialog,
            titleVisibility: .visible
        ) {
            Button("Delete My Account", role: .destructive) {
                Theme.haptic(.heavy)
                authManager.deleteAccount()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action is permanent and compliant with App Store guidelines. Your user profile, identity tokens, and server-synced records will be permanently deleted.")
        }
        .confirmationDialog(
            "Clear Cached Parcel Records?",
            isPresented: $showClearCacheDialog,
            titleVisibility: .visible
        ) {
            Button("Clear All Caches", role: .destructive) {
                VerifiedParcelCache.shared.clearHistory()
                cacheClearedToast = true
                Theme.haptic(.light)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears temporary offline verified land cache to free disk space. Your saved plots remain intact.")
        }
        .overlay(alignment: .top) {
            if cacheClearedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Temporary offline cache cleared successfully.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(primaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(cardBackground)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                        withAnimation { cacheClearedToast = false }
                    }
                }
            }
        }
    }
    
    // ============================================================
    // MARK: - TOP BAR
    // ============================================================
    
    private var customNavigationBar: some View {
        HStack {
            Text("Account Settings")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(primaryText)
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Text("Done")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .glassEffect(
                        .regular.interactive(),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
    
    // ============================================================
    // MARK: - 1. IDENTITY & PROFILE CARD
    // ============================================================
    
    private var identityProfileCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Avatar Disc
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: authManager.isAuthenticated
                                    ? [Color(red: 74/255, green: 20/255, blue: 140/255), Color(red: 106/255, green: 27/255, blue: 154/255)]
                                    : [Color(red: 140/255, green: 145/255, blue: 155/255), Color(red: 100/255, green: 105/255, blue: 115/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    if authManager.isAuthenticated, let user = authManager.currentUser, !user.name.isEmpty && user.name != "Apple User" && user.name != "Google User" {
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    if authManager.isAuthenticated, let user = authManager.currentUser {
                        Text(user.name.isEmpty ? (user.id.hasPrefix("google_") ? "Google User" : "Apple User") : user.name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(primaryText)
                        
                        if !user.email.isEmpty {
                            Text(user.email)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(secondaryText)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 4) {
                            if user.id.hasPrefix("google_") {
                                GoogleLogoView(size: 12)
                                Text("Google Account Verified")
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(red: 66/255, green: 133/255, blue: 244/255))
                            } else {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(red: 46/255, green: 125/255, blue: 50/255))
                                Text("Apple ID Verified")
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(red: 46/255, green: 125/255, blue: 50/255))
                            }
                        }
                        .padding(.top, 1)
                    } else {
                        Text("Guest Account")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(primaryText)
                        
                        Text("Sign in to sync your saved parcels across devices")
                            .font(.system(size: 12.5, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            // Sign in CTA if not authenticated
            if !authManager.isAuthenticated {
                Divider()
                    .background(cardBorder)
                
                Button {
                    showLoginModal = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Sign in with Apple or Google")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        )
    }
    
    // ============================================================
    // MARK: - 2. SUBSCRIPTION & SEARCH QUOTA CARD
    // ============================================================
    
    private var subscriptionQuotaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack {
                Text("Subscription & Search Quota")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
                
                Spacer()
                
                // Tier Badge
                Text(activeTierBadgeText)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        subscriptionManager.isPremium || subscriptionManager.isUnlimited
                            ? LinearGradient(colors: [Color(red: 116/255, green: 18/255, blue: 250/255), Color(red: 70/255, green: 0/255, blue: 199/255)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color(red: 75/255, green: 85/255, blue: 99/255), Color(red: 55/255, green: 65/255, blue: 81/255)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
            
            Divider()
                .background(cardBorder)
            
            // Search Quota Highlight Row
            HStack(spacing: 12) {
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
                    .frame(width: 20, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(remainingCreditsDisplayTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                    
                    Text(quotaSubtitle)
                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                        .foregroundColor(secondaryText)
                }
                
                Spacer()
                
                // Top-Up / Upgrade Button
                Button {
                    showSubscriptionModal = true
                } label: {
                    Text("Top Up")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 116/255, green: 18/255, blue: 250/255))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(red: 116/255, green: 18/255, blue: 250/255).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            
            Divider()
                .background(cardBorder)
            
            // Manage Apple Subscription Link
            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    openURL(url)
                }
            } label: {
                HStack {
                    Image(systemName: "creditcard")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryText)
                    
                    Text("Manage Apple ID Subscriptions")
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundColor(primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(secondaryText)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        )
    }
    
    // ============================================================
    // MARK: - 3. STORAGE & DATA VAULT CARD
    // ============================================================
    
    private var storageAndVaultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Vault & Storage")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(primaryText)
            
            Divider()
                .background(cardBorder)
            
            // Saved Lands Shortcut
            Button {
                showSavedLandsModal = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 116/255, green: 18/255, blue: 250/255))
                        .frame(width: 18)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved Lands Vault")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(primaryText)
                        
                        Text("On-device private storage")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                    }
                    
                    Spacer()
                    
                    Text("\(savedLandManager.totalSavedCount) \(savedLandManager.totalSavedCount == 1 ? "Plot" : "Plots")")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(secondaryText)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(secondaryText.opacity(0.6))
                }
            }
            
            Divider()
                .background(cardBorder)
            
            // Cache Clear Option
            Button {
                showClearCacheDialog = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryText)
                        .frame(width: 18)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear Temporary Parcel Caches")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(primaryText)
                        
                        Text("Frees cached offline records")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(secondaryText.opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        )
    }
    
    // ============================================================
    // MARK: - 4. ACCOUNT ACTIONS CARD
    // ============================================================
    
    private var accountActionsCard: some View {
        VStack(spacing: 0) {
            if authManager.isAuthenticated {
                // Sign Out Row
                Button {
                    showSignOutDialog = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(primaryText)
                            .frame(width: 20)
                        
                        Text("Sign Out")
                            .font(.system(size: 14.5, weight: .medium, design: .rounded))
                            .foregroundColor(primaryText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                
                Divider()
                    .background(cardBorder)
            }
            
            // Delete Account Row (App Store Guideline 5.1.1(v) Compliant)
            Button {
                showDeleteAccountDialog = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.red)
                        .frame(width: 20)
                    
                    Text("Delete Account & Data")
                        .font(.system(size: 14.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.red)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        )
    }
    
    // ============================================================
    // MARK: - 5. LEGAL & TERMS FOOTER
    // ============================================================
    
    private var legalFooter: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button("Terms of Use") {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        openURL(url)
                    }
                }
                
                Text("•")
                
                Button("Privacy Policy") {
                    if let url = URL(string: "https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/") {
                        openURL(url)
                    }
                }
            }
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundColor(secondaryText)
            
            Text("Bhumitra v1.0 • Odisha Land Records")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(secondaryText.opacity(0.8))
        }
        .padding(.top, 8)
    }
    
    // MARK: - Subscriptions Helpers
    
    private var activeTierBadgeText: String {
        if subscriptionManager.isUnlimited {
            return "Unlimited+ Active"
        }
        if subscriptionManager.isPremium {
            return "Pro Active"
        }
        if subscriptionManager.remainingPlotCredits > 0 {
            return "Active Credits"
        }
        return "Free Starter"
    }
    
    private var remainingCreditsDisplayTitle: String {
        if subscriptionManager.isUnlimited {
            return "Unlimited Searches"
        }
        let count = subscriptionManager.remainingPlotCredits
        return "\(count) Plot \(count == 1 ? "Search" : "Searches") Left"
    }
    
    private var quotaSubtitle: String {
        if subscriptionManager.isUnlimited {
            return "Unrestricted RoR verification across all 30 districts"
        }
        if subscriptionManager.remainingPlotCredits > 0 {
            return "Instant official cadastral verification power"
        }
        return "You've reached your free limit. Top up to continue."
    }
}

#Preview {
    ManageAccountView()
}
