import SwiftUI
import StoreKit
import UIKit

// ============================================================
// MARK: - ACCOUNT DETAILS (FULL SCREEN)
// ============================================================
//
// Profile, plan, payments, storage and account actions. Every value shown
// is real state from AuthManager / SubscriptionManager / SavedLandManager.

public struct ManageAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var savedLandManager = SavedLandManager.shared

    #if DEBUG
    @ObservedObject private var testCreditManager = TestCreditManager.shared
    #endif

    @State private var showSubscriptionModal = false
    @State private var showLoginModal = false
    @State private var showSavedLandsModal = false
    @State private var showSignOutDialog = false
    @State private var showDeleteAccountDialog = false
    @State private var showClearCacheDialog = false
    @State private var isDeletingAccount = false
    @State private var isRestoring = false
    @State private var deleteAccountErrorMessage: String? = nil
    @State private var showDeleteErrorAlert = false
    @State private var showCreditTransactionsSheet = false
    @State private var showSupportContactSheet = false
    @State private var toastMessage: String? = nil
    @State private var toastTone: SettingsTone = .success

    public init() {}

    private var isUnlimited: Bool { subscriptionManager.isUnlimited || subscriptionManager.isPremium }

    public var body: some View {
        ZStack {
            SheetChrome.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader("Account", closeStyle: .done) { dismiss() }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        identityCard
                        if subscriptionManager.isSyncPending { pendingPaymentCard }
                        planSection
                        paymentsSection
                        if authManager.isAuthenticated { accountInfoSection }
                        storageSection
                        accountActionsSection
                        #if DEBUG
                        developerSection
                        #endif
                        legalLinks
                        SettingsAppFooter()
                    }
                    .padding(.horizontal, SettingsMetrics.horizontalPadding)
                    .padding(.top, 6)
                    .padding(.bottom, 48)
                }
            }
        }
        .settingsToast($toastMessage, tone: toastTone)
        .fullScreenCover(isPresented: $showSubscriptionModal) { SubscriptionView() }
        .fullScreenCover(isPresented: $showLoginModal) {
            LoginView(onDismiss: { showLoginModal = false })
        }
        .fullScreenCover(isPresented: $showSavedLandsModal) { SavedLandsView() }
        .sheet(isPresented: $showCreditTransactionsSheet) { CreditTransactionsView() }
        .sheet(isPresented: $showSupportContactSheet) { SupportContactView() }
        .confirmSheet(
            isPresented: $showSignOutDialog,
            icon: "rectangle.portrait.and.arrow.right",
            title: "Sign out?",
            message: "Saved lands stay on this device. Your plot searches come back when you sign in again.",
            context: authManager.currentUser.flatMap { $0.email.isEmpty ? nil : "Signed in as \($0.email)" },
            confirmTitle: "Sign out"
        ) {
            authManager.signOut()
            dismiss()
        }
        .confirmSheet(
            isPresented: $showDeleteAccountDialog,
            icon: "trash",
            title: "Delete your account?",
            message: "Your profile, remaining plot searches and server records are deleted permanently. This can't be undone. Apple subscriptions are billed by Apple; cancel them in Settings › Apple ID › Subscriptions.",
            confirmTitle: "Delete account"
        ) {
            deleteAccount()
        }
        .alert("Couldn't delete account", isPresented: $showDeleteErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteAccountErrorMessage ?? "Something went wrong while contacting the server. Please try again.")
        }
        .confirmSheet(
            isPresented: $showClearCacheDialog,
            icon: "arrow.triangle.2.circlepath",
            tone: .standard,
            title: "Clear cached records?",
            message: "Frees space used by temporarily cached land records. Saved lands and plot searches aren't affected.",
            confirmTitle: "Clear cache"
        ) {
            VerifiedParcelCache.shared.clearHistory()
            showToast("Cached records cleared")
        }
    }

    // MARK: - Identity

    private var identityCard: some View {
        SettingsCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(authManager.isAuthenticated ? Theme.Color.bhumitraTint : Theme.Color.bhumitraSurface)
                    .frame(width: 60, height: 60)
                    .overlay {
                        if let initial = userInitial {
                            Text(initial)
                                .font(.googleSans(size: 24, weight: .bold))
                                .foregroundColor(Theme.Color.bhumitraPrimary)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(authManager.isAuthenticated ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraSecondaryText)
                        }
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.googleSans(size: 17, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .lineLimit(1)
                    if let email = authManager.currentUser?.email, authManager.isAuthenticated, !email.isEmpty {
                        Text(email)
                            .font(.googleSans(size: 13, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            .lineLimit(1)
                    }
                    if authManager.isAuthenticated {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.Color.bhumitraSuccess)
                            Text(providerVerifiedText)
                                .font(.googleSans(size: 12, weight: .medium))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        }
                    } else {
                        Text("Not signed in")
                            .font(.googleSans(size: 12.5, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .accessibilityElement(children: .combine)

            if !authManager.isAuthenticated {
                SettingsDivider(inset: 16)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign in so your search credits and purchases are tied to your account and never lost.")
                        .font(.googleSans(size: 13, weight: .regular))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        Theme.haptic(.light)
                        showLoginModal = true
                    } label: {
                        Text("Sign in with Apple or Google")
                            .font(.googleSans(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Theme.Color.bhumitraPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaledButtonStyle())
                }
                .padding(16)
            }
        }
    }

    private var userInitial: String? {
        guard authManager.isAuthenticated, let user = authManager.currentUser else { return nil }
        let name = user.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != "Apple User", name != "Google User", let first = name.first else { return nil }
        return String(first).uppercased()
    }

    private var displayName: String {
        guard authManager.isAuthenticated, let user = authManager.currentUser else { return "Guest" }
        let name = user.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty, name != "Apple User", name != "Google User" { return name }
        return user.id.hasPrefix("google_") ? "Google account" : "Apple account"
    }

    private var providerVerifiedText: String {
        switch authManager.currentAuthProvider {
        case .google: return "Verified with Google"
        case .apple: return "Verified with Apple"
        case .guest: return "Guest"
        }
    }

    // MARK: - Pending payment (only when real pending state exists)

    private var pendingPaymentCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    SettingsIconTile("clock.arrow.circlepath", tone: .warning)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Payment received, activation pending")
                            .font(.googleSans(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        Text("Apple confirmed your payment. We're adding your searches. You won't be charged again.")
                            .font(.googleSans(size: 13, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button {
                    Theme.haptic(.light)
                    Task {
                        let ok = await subscriptionManager.retryPendingSync()
                        showToast(ok ? "Purchase activated" : "Still activating. We'll keep trying automatically.",
                                  tone: ok ? .success : .warning)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if subscriptionManager.isActivating {
                            ProgressView().tint(.white).controlSize(.small)
                        }
                        Text(subscriptionManager.isActivating ? "Activating…" : "Activate now")
                            .font(.googleSans(size: 14.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.Color.bhumitraWarning)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ScaledButtonStyle())
                .disabled(subscriptionManager.isActivating)
            }
            .padding(16)
        }
    }

    // MARK: - Plan

    private var planSection: some View {
        SettingsSection("Plan") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isUnlimited ? "Unlimited searches" : "\(subscriptionManager.authoritativeBalance) \(subscriptionManager.authoritativeBalance == 1 ? "search" : "searches") left")
                        .font(.googleSans(size: 18, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .contentTransition(.numericText())
                    Text(isUnlimited ? "Monthly subscription is active" : "Credits never expire")
                        .font(.googleSans(size: 12.5, weight: .regular))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                }
                Spacer()
                SettingsBadge(isUnlimited ? "Unlimited" : "Pay as you go", tone: isUnlimited ? .brand : .neutral)
            }
            .padding(16)
            .accessibilityElement(children: .combine)

            SettingsDivider(inset: 16)
            if !isUnlimited {
                SettingsRow(icon: "plus.circle", tone: .brand, title: "Add searches") {
                    showSubscriptionModal = true
                }
                SettingsDivider()
            }
            SettingsRow(icon: "list.bullet.rectangle", tone: .brand, title: "Credit activity") {
                showCreditTransactionsSheet = true
            }
            SettingsDivider()
            SettingsRow(icon: "applelogo", tone: .neutral, title: "Manage Apple subscriptions", accessory: .external) {
                openURL(AppInfo.manageSubscriptionsURL)
            }
        }
    }

    // MARK: - Payments

    private var paymentsSection: some View {
        SettingsSection("Payments",
                        footer: "Payments are processed securely by Apple. \(AppInfo.name) never sees your card details.") {
            SettingsRow(icon: "arrow.clockwise", tone: .info, title: "Restore purchases",
                        subtitle: "Recover an active subscription on this Apple ID",
                        accessory: isRestoring ? .progress : .chevron) {
                restorePurchases()
            }
            SettingsDivider()
            SettingsRow(icon: "envelope", tone: .info, title: "Billing help",
                        subtitle: "Missing credits or a payment question") {
                showSupportContactSheet = true
            }
        }
    }

    // MARK: - Account info

    private var accountInfoSection: some View {
        SettingsSection("Account information",
                        footer: "Share your account ID with support so we can find your purchases quickly.") {
            SettingsKeyValueRow("Sign-in method", value: authManager.currentAuthProvider.rawValue)
            SettingsDivider(inset: 16)
            if let id = authManager.currentUser?.id {
                SettingsKeyValueRow("Account ID", value: id, monospaced: true) {
                    UIPasteboard.general.string = id
                    showToast("Account ID copied")
                }
            }
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        SettingsSection("Storage", footer: "Saved lands are stored privately on this device.") {
            SettingsRow(icon: "bookmark", tone: .brand, title: "Saved lands",
                        value: "\(savedLandManager.totalSavedCount)") {
                showSavedLandsModal = true
            }
            SettingsDivider()
            SettingsRow(icon: "arrow.triangle.2.circlepath", tone: .neutral, title: "Clear cached records",
                        accessory: .none) {
                showClearCacheDialog = true
            }
        }
    }

    // MARK: - Account actions

    private var accountActionsSection: some View {
        SettingsSection(footer: authManager.isAuthenticated
                        ? "Deleting your account permanently removes your profile and remaining credits."
                        : nil) {
            if authManager.isAuthenticated {
                SettingsRow(icon: "rectangle.portrait.and.arrow.right", tone: .neutral, title: "Sign out",
                            accessory: .none) {
                    showSignOutDialog = true
                }
                SettingsDivider()
            }
            SettingsRow(icon: "trash", title: "Delete account",
                        accessory: isDeletingAccount ? .progress : .none,
                        isDestructive: true) {
                showDeleteAccountDialog = true
            }
        }
    }

    // MARK: - Legal

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Button("Terms of Use") { openURL(AppInfo.termsURL) }
            Text("·").accessibilityHidden(true)
            Button("Privacy Policy") { openURL(AppInfo.privacyPolicyURL) }
        }
        .font(.googleSans(size: 13, weight: .medium))
        .foregroundColor(Theme.Color.bhumitraSecondaryText)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    #if DEBUG
    // MARK: - Developer (DEBUG only)

    private var developerSection: some View {
        SettingsSection("Developer · Debug only") {
            SettingsKeyValueRow("Test credits", value: "\(testCreditManager.testCredits)")
            SettingsDivider(inset: 16)
            HStack(spacing: 8) {
                debugButton("+10") { testCreditManager.addCredits(10) }
                debugButton("+50") { testCreditManager.addCredits(50) }
                debugButton("Reset", destructive: true) { testCreditManager.resetCredits() }
            }
            .padding(12)
        }
    }

    private func debugButton(_ title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Theme.haptic(.medium)
            action()
        } label: {
            Text(title)
                .font(.googleSans(size: 13.5, weight: .semibold))
                .foregroundColor(destructive ? Theme.Color.bhumitraError : Theme.Color.bhumitraPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(destructive ? Theme.Color.bhumitraErrorSurface : Theme.Color.bhumitraTint)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - Actions

    private func showToast(_ message: String, tone: SettingsTone = .success) {
        toastTone = tone
        toastMessage = message
    }

    private func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true
        Task {
            let result = await subscriptionManager.restorePurchases()
            isRestoring = false
            switch result {
            case .success:
                Theme.notificationHaptic(.success)
                showToast("Subscription restored")
            case .failure(let error):
                if (error as NSError).code == 404 {
                    showToast("No active subscription found. Your credit balance is up to date.", tone: .neutral)
                } else {
                    Theme.notificationHaptic(.error)
                    showToast("Couldn't reach the App Store. Please try again.", tone: .danger)
                }
            }
        }
    }

    private func deleteAccount() {
        Theme.haptic(.heavy)
        Task {
            isDeletingAccount = true
            do {
                try await authManager.deleteAccount()
                SavedLandManager.shared.remove(at: IndexSet(integersIn: 0..<SavedLandManager.shared.savedRecords.count))
                dismiss()
            } catch {
                deleteAccountErrorMessage = error.localizedDescription
                showDeleteErrorAlert = true
            }
            isDeletingAccount = false
        }
    }
}

#Preview {
    ManageAccountView()
}
