//
//  SupportContactView.swift
//  MyBhoomi
//
//  Help & Support. Topic-first: pick what the issue is about and a
//  pre-filled email opens with diagnostics attached. Direct email, copy,
//  help centre, and account reference are also available.
//

import SwiftUI
import UIKit

public struct SupportContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var toastMessage: String? = nil
    @State private var showMailUnavailable = false

    private let supportEmail = "bhumitra74@gmail.com"
    private let developerEmail = "kirtidhwajpatra@gmail.com"
    private let onlineDocsURL = URL(string: "https://kirtidhwajpatra.github.io/bhumitra-support/")!

    public init() {}

    private struct Topic: Identifiable {
        let id = UUID()
        let icon: String
        let tone: SettingsTone
        let title: String
        let subtitle: String
        let subject: String
    }

    private let topics: [Topic] = [
        Topic(icon: "creditcard", tone: .brand, title: "Payments & credits",
              subtitle: "Missing credits, charges or refunds",
              subject: "Bhumitra: Payments & Credits"),
        Topic(icon: "doc.text.magnifyingglass", tone: .info, title: "Land record issue",
              subtitle: "Wrong owner, area or plot details",
              subject: "Bhumitra: Land Record Issue"),
        Topic(icon: "ladybug", tone: .danger, title: "Report a problem",
              subtitle: "Crashes, errors or something not working",
              subject: "Bhumitra: Bug Report"),
        Topic(icon: "lightbulb", tone: .warning, title: "Suggest a feature",
              subtitle: "Ideas to make the app better",
              subject: "Bhumitra: Feature Suggestion")
    ]

    public var body: some View {
        ZStack {
            SheetChrome.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader("Help & support", subtitle: "We usually reply within 24 hours") { dismiss() }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        topicsSection
                        contactSection
                        selfServiceSection
                        if authManager.isAuthenticated { referenceSection }
                        SettingsAppFooter()
                    }
                    .padding(.horizontal, SettingsMetrics.horizontalPadding)
                    .padding(.top, 6)
                    .padding(.bottom, 48)
                }
            }
        }
        .settingsToast($toastMessage)
        .alert("No mail app available", isPresented: $showMailUnavailable) {
            Button("Copy Email Address") { copyEmail() }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Write to us at \(supportEmail) from any email app.")
        }
    }

    // MARK: - Sections

    private var topicsSection: some View {
        SettingsSection("What do you need help with?",
                        footer: "App version, iOS version, device model, account ID and credit balance are added to your email so we can help faster. No land search history is shared.") {
            ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                SettingsRow(icon: topic.icon, tone: topic.tone, title: topic.title, subtitle: topic.subtitle) {
                    sendSupportEmail(subject: topic.subject)
                }
                if index < topics.count - 1 { SettingsDivider() }
            }
        }
    }

    private var contactSection: some View {
        SettingsSection("Contact") {
            SettingsKeyValueRow("Email", value: supportEmail) { copyEmail() }
            SettingsDivider(inset: 16)
            SettingsRow(icon: "envelope", tone: .brand, title: "Write to us") {
                sendSupportEmail(subject: "Bhumitra: Support Request")
            }
        }
    }

    private var selfServiceSection: some View {
        SettingsSection("Self-service") {
            SettingsRow(icon: "book", tone: .info, title: "Help centre & FAQ",
                        subtitle: "Answers to common questions", accessory: .external) {
                openURL(onlineDocsURL)
            }
        }
    }

    private var referenceSection: some View {
        SettingsSection("Your reference",
                        footer: "Mention this ID if you contact us from a different email address.") {
            if let id = authManager.currentUser?.id {
                SettingsKeyValueRow("Account ID", value: id, monospaced: true) {
                    UIPasteboard.general.string = id
                    toastMessage = "Account ID copied"
                }
            }
        }
    }

    // MARK: - Actions

    private func copyEmail() {
        UIPasteboard.general.string = supportEmail
        toastMessage = "Email address copied"
    }

    private func sendSupportEmail(subject: String) {
        let userId = authManager.currentUser?.id ?? "Guest"
        let credits = subscriptionManager.authoritativeBalance
        let tier = subscriptionManager.isUnlimited ? "Unlimited" : "Pay as you go"

        let body = """
        Hello Bhumitra team,

        [Please describe your issue here]


        ------------------------------
        Diagnostics
        • App version: \(AppInfo.version) (\(AppInfo.build))
        • iOS version: \(UIDevice.current.systemVersion)
        • Device: \(UIDevice.current.model)
        • Account ID: \(userId)
        • Credit balance: \(credits) (\(tier))
        ------------------------------
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "cc", value: developerEmail),
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else {
            showMailUnavailable = true
            return
        }
        openURL(url) { accepted in
            if !accepted { showMailUnavailable = true }
        }
    }
}

#Preview {
    SupportContactView()
}
