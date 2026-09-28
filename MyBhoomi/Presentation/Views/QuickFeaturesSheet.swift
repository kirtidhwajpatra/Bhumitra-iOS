//
//  QuickFeaturesSheet.swift
//  MyBhoomi
//
//  Settings home. Minimal grouped layout:
//  profile → credits → general → about → session → footer.
//  Built on SettingsKit so every child screen
//  shares the same visual language.
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
    @ObservedObject private var locationPermissionManager = LocationPermissionManager.shared

    @State private var showManageAccountSheet = false
    @State private var showSavedLandsSheet = false
    @State private var showSubscriptionCover = false
    @State private var showLoginCover = false
    @State private var showDisclaimerSheet = false
    @State private var showSignOutAlert = false
    @State private var showClearDataAlert = false
    @State private var showAppearanceSheet = false
    @State private var showCreditTransactionsSheet = false
    @State private var showSupportContactSheet = false
    @State private var showPrivacySecuritySheet = false
    @State private var toastMessage: String? = nil

    public init(viewModel: MapViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    private var isUnlimited: Bool { subscriptionManager.isUnlimited || subscriptionManager.isPremium }

    public var body: some View {
        ZStack {
            SheetChrome.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader("Settings", onClose: onDismiss)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        profileCard
                        creditsCard
                        generalCard
                        aboutCard
                        sessionCard
                        SettingsAppFooter()
                    }
                    .padding(.horizontal, SettingsMetrics.horizontalPadding)
                    .padding(.top, 6)
                    .padding(.bottom, 48)
                }
            }
        }
        .settingsToast($toastMessage)
        .fullScreenCover(isPresented: $showManageAccountSheet) { ManageAccountView() }
        .fullScreenCover(isPresented: $showSavedLandsSheet) { SavedLandsView() }
        .fullScreenCover(isPresented: $showSubscriptionCover) { SubscriptionView() }
        .fullScreenCover(isPresented: $showLoginCover) {
            LoginView(onDismiss: { showLoginCover = false })
        }
        .sheet(isPresented: $showDisclaimerSheet) { DisclaimerView() }
        .sheet(isPresented: $showAppearanceSheet) { AppearanceSettingsView(viewModel: viewModel) }
        .sheet(isPresented: $showCreditTransactionsSheet) { CreditTransactionsView() }
        .sheet(isPresented: $showSupportContactSheet) { SupportContactView() }
        .sheet(isPresented: $showPrivacySecuritySheet) { PrivacySecurityView() }
        .task {
            await subscriptionManager.fetchServerCreditBalance()
            locationPermissionManager.refresh()
        }
        .confirmSheet(
            isPresented: $showSignOutAlert,
            icon: "rectangle.portrait.and.arrow.right",
            title: "Sign out?",
            message: "Saved lands stay on this device. Your plot searches come back when you sign in again.",
            context: signedInContext,
            confirmTitle: "Sign out"
        ) {
            authManager.signOut()
            toastMessage = "Signed out"
        }
        .confirmSheet(
            isPresented: $showClearDataAlert,
            icon: "arrow.triangle.2.circlepath",
            tone: .standard,
            title: "Clear cached records?",
            message: "Frees space used by temporarily cached land records. Saved lands and plot searches aren't affected.",
            confirmTitle: "Clear cache"
        ) {
            VerifiedParcelCache.shared.clearHistory()
            toastMessage = "Cached records cleared"
        }
    }

    /// "Signed in as …" chip on the sign-out sheet, so it's clear which
    /// account is being signed out.
    private var signedInContext: String? {
        guard authManager.isAuthenticated, let user = authManager.currentUser else { return nil }
        if !user.email.isEmpty { return "Signed in as \(user.email)" }
        switch authManager.currentAuthProvider {
        case .apple: return "Signed in with Apple"
        case .google: return "Signed in with Google"
        case .guest: return nil
        }
    }

    // MARK: - Profile (tap = account details, or sign in for guests)

    private var profileCard: some View {
        SettingsCard {
            Button {
                Theme.selectionHaptic()
                if authManager.isAuthenticated { showManageAccountSheet = true } else { showLoginCover = true }
            } label: {
                HStack(spacing: 12) {
                    avatar
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profileTitle)
                            .font(.googleSans(size: 17, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            .lineLimit(1)
                        Text(profileSubtitle)
                            .font(.googleSans(size: 13, weight: .regular))
                            .foregroundColor(authManager.isAuthenticated ? Theme.Color.bhumitraSecondaryText : Theme.Color.bhumitraPrimary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(SettingsRowButtonStyle())
            .accessibilityHint(authManager.isAuthenticated ? "Opens account details" : "Opens sign in")
        }
    }

    private var avatar: some View {
        Circle()
            .fill(authManager.isAuthenticated ? Theme.Color.bhumitraTint : Theme.Color.bhumitraSurface)
            .frame(width: 44, height: 44)
            .overlay {
                if let initial = userInitial {
                    Text(initial)
                        .font(.googleSans(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                }
            }
            .accessibilityHidden(true)
    }

    private var userInitial: String? {
        guard authManager.isAuthenticated, let user = authManager.currentUser else { return nil }
        let name = user.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != "Apple User", name != "Google User", let first = name.first else { return nil }
        return String(first).uppercased()
    }

    private var profileTitle: String {
        guard authManager.isAuthenticated, let user = authManager.currentUser else { return "Guest" }
        let name = user.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty, name != "Apple User", name != "Google User" { return name }
        if !user.email.isEmpty { return user.email }
        return "Your account"
    }

    /// One quiet line: email when it adds information, otherwise the provider.
    private var profileSubtitle: String {
        guard authManager.isAuthenticated, let user = authManager.currentUser else { return "Sign in" }
        if !user.email.isEmpty, profileTitle != user.email { return user.email }
        switch authManager.currentAuthProvider {
        case .apple: return "Apple ID"
        case .google: return "Google account"
        case .guest: return "Account"
        }
    }

    // MARK: - Credits (one row: balance + Add; tap = activity)

    private var lowBalance: Bool {
        !isUnlimited && subscriptionManager.authoritativeBalance <= 3
    }

    private var creditsCard: some View {
        SettingsCard {
            HStack(spacing: 12) {
                Button {
                    Theme.selectionHaptic()
                    showCreditTransactionsSheet = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Plot searches")
                                .font(.googleSans(size: 13, weight: .regular))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            Text(isUnlimited ? "Unlimited" : "\(subscriptionManager.authoritativeBalance) left")
                                .font(.googleSans(size: 20, weight: .semibold))
                                .foregroundColor(lowBalance ? Theme.Color.bhumitraWarning : Theme.Color.bhumitraPrimaryText)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MapChromePressStyle())
                .accessibilityHint("Shows credit activity")

                if !isUnlimited {
                    Button {
                        Theme.haptic(.light)
                        showSubscriptionCover = true
                    } label: {
                        Text("Add")
                            .font(.googleSans(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .frame(height: 34)
                            .background(Capsule().fill(Theme.Color.bhumitraPrimary))
                    }
                    .buttonStyle(MapChromePressStyle())
                    .accessibilityLabel("Add plot searches")
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Rows

    private var generalCard: some View {
        SettingsCard {
            SettingsRow(icon: "bookmark", title: "Saved lands",
                        value: savedLandManager.totalSavedCount > 0 ? "\(savedLandManager.totalSavedCount)" : nil) {
                showSavedLandsSheet = true
            }
            SettingsDivider()
            SettingsRow(icon: "circle.lefthalf.filled", title: "Appearance") {
                showAppearanceSheet = true
            }
            SettingsDivider()
            SettingsRow(icon: "location", title: "Location access", value: locationValue) {
                locationPermissionManager.handleTap()
            }
            if UPFeature.isAvailable {
                SettingsDivider()
                SettingsRow(icon: "map", title: "Uttar Pradesh map",
                            subtitle: "Plot lines and plot lookup",
                            badge: (text: "Beta", tone: .neutral)) {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        viewModel.showUPPicker = true
                    }
                }
            }
        }
    }

    private var locationValue: String {
        switch locationPermissionManager.statusDisplay {
        case "Enabled": return "On"
        case "Not Determined": return "Not set"
        default: return "Off"
        }
    }

    private var aboutCard: some View {
        SettingsCard {
            SettingsRow(icon: "lock", title: "Privacy") {
                showPrivacySecuritySheet = true
            }
            SettingsDivider()
            SettingsRow(icon: "building.columns", title: "Data sources") {
                showDisclaimerSheet = true
            }
            SettingsDivider()
            SettingsRow(icon: "questionmark.circle", title: "Help") {
                showSupportContactSheet = true
            }
            SettingsDivider()
            SettingsRow(icon: "star", title: "Rate \(AppInfo.name)", accessory: .external) {
                AppFeedbackManager.shared.requestNativeAppStoreReview()
            }
        }
    }

    private var sessionCard: some View {
        SettingsCard {
            SettingsRow(icon: "arrow.triangle.2.circlepath", title: "Clear cached records", accessory: .none) {
                showClearDataAlert = true
            }
            if authManager.isAuthenticated {
                SettingsDivider()
                SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign out",
                            accessory: .none, isDestructive: true) {
                    showSignOutAlert = true
                }
            }
        }
    }
}

#Preview {
    QuickFeaturesSheet(viewModel: MapViewModel(), onDismiss: {})
}
