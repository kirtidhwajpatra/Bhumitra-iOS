//
//  PrivacySecurityView.swift
//  MyBhoomi
//
//  Privacy & Security. Plain-language disclosure of what data is used and
//  why, legal documents, the public-record notice, and the account deletion
//  path (App Store Guideline 5.1.1(v)).
//

import SwiftUI

public struct PrivacySecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @ObservedObject private var authManager = AuthManager.shared
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteErrorMessage: String? = nil
    @State private var showDeleteErrorAlert = false

    public init() {}

    public var body: some View {
        ZStack {
            SheetChrome.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader("Privacy & security", subtitle: "How \(AppInfo.name) handles your data") { dismiss() }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        commitmentCard
                        dataUseSection
                        paymentsSection
                        publicRecordSection
                        legalSection
                        if authManager.isAuthenticated { deletionSection }
                        SettingsAppFooter()
                    }
                    .padding(.horizontal, SettingsMetrics.horizontalPadding)
                    .padding(.top, 6)
                    .padding(.bottom, 48)
                }
            }
        }
        .confirmSheet(
            isPresented: $showDeleteConfirmation,
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
            Text(deleteErrorMessage ?? "Something went wrong while contacting the server. Please try again.")
        }
    }

    // MARK: - Commitment

    private var commitmentCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    SettingsIconTile("lock.shield", tone: .success, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your data stays yours")
                            .font(.googleSans(size: 17, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        Text("Our commitments to you")
                            .font(.googleSans(size: 13, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    commitment("We never sell your personal data.")
                    commitment("No tracking across other apps or websites.")
                    commitment("Location is used only while the app is open.")
                    commitment("Saved lands are stored privately on your device.")
                }
            }
            .padding(16)
        }
    }

    private func commitment(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Color.bhumitraSuccess)
                .accessibilityHidden(true)
            Text(text)
                .font(.googleSans(size: 14, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Data use

    private var dataUseSection: some View {
        SettingsSection("What we use and why") {
            SettingsInfoRow(icon: "location", tone: .info, title: "Location",
                            message: "Centres the map on where you are and shows nearby surveyed plots. Used only in the foreground and never shared.")
            SettingsDivider()
            SettingsInfoRow(icon: "person.badge.key", tone: .info, title: "Sign-in",
                            message: "Sign in with Apple or Google links your search credits to your account. Tokens are kept in the device's encrypted Keychain.")
            SettingsDivider()
            SettingsInfoRow(icon: "bookmark", tone: .info, title: "Saved lands",
                            message: "Plots you save stay on this device. They are not uploaded to our servers.")
            SettingsDivider()
            SettingsInfoRow(icon: "chart.bar", tone: .info, title: "Usage & crash reports",
                            message: "App usage statistics and crash reports help us find and fix problems. See the privacy policy for full details.")
        }
    }

    private var paymentsSection: some View {
        SettingsSection("Payments") {
            SettingsInfoRow(icon: "creditcard", tone: .brand, title: "Handled by Apple",
                            message: "Purchases are processed by the App Store. We receive a confirmation of the purchase, never your card or bank details.")
        }
    }

    // MARK: - Public record notice

    private var publicRecordSection: some View {
        SettingsSection("Public record notice") {
            SettingsInfoRow(icon: "building.columns", tone: .warning, title: "Independent information service",
                            message: "\(AppInfo.name) is not affiliated with or endorsed by the Government of Odisha. Land records and maps come from public government portals such as Bhulekh (bhulekh.ori.nic.in). For legal purposes, always verify with the official record or your Tahasil office.")
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        SettingsSection("Legal") {
            SettingsRow(icon: "hand.raised", tone: .neutral, title: "Privacy policy", accessory: .external) {
                openURL(AppInfo.privacyPolicyURL)
            }
            SettingsDivider()
            SettingsRow(icon: "doc.text", tone: .neutral, title: "Terms of use",
                        subtitle: "Apple standard licence agreement", accessory: .external) {
                openURL(AppInfo.termsURL)
            }
        }
    }

    // MARK: - Deletion

    private var deletionSection: some View {
        SettingsSection("Account",
                        footer: "Deletes your profile, remaining credits and server records. Saved lands on this device are removed too.") {
            SettingsRow(icon: "trash", title: "Delete account and data",
                        accessory: isDeletingAccount ? .progress : .none,
                        isDestructive: true) {
                showDeleteConfirmation = true
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
                deleteErrorMessage = error.localizedDescription
                showDeleteErrorAlert = true
            }
            isDeletingAccount = false
        }
    }
}

#Preview {
    PrivacySecurityView()
}
