//
//  SettingsKit.swift
//  MyBhoomi
//
//  Shared building blocks for Settings and its child screens.
//  One visual language everywhere: grouped cards, quiet section captions,
//  muted icon tiles, 52pt rows, hairline dividers. Built only on Theme tokens
//  so light/dark mode and brand colours stay consistent.
//

import SwiftUI
import UIKit

// MARK: - Tone

/// Semantic colour role for icon tiles and status badges.
public enum SettingsTone {
    case brand, info, success, warning, danger, neutral

    var foreground: Color {
        switch self {
        case .brand: return Theme.Color.bhumitraPrimary
        case .info: return Theme.Color.bhumitraInfo
        case .success: return Theme.Color.bhumitraSuccess
        case .warning: return Theme.Color.bhumitraWarning
        case .danger: return Theme.Color.bhumitraError
        case .neutral: return Theme.Color.bhumitraSecondaryText
        }
    }

    var background: Color {
        switch self {
        case .brand: return Theme.Color.bhumitraTint
        case .info: return Theme.Color.bhumitraInfoSurface
        case .success: return Theme.Color.bhumitraSuccessSurface
        case .warning: return Theme.Color.bhumitraWarningSurface
        case .danger: return Theme.Color.bhumitraErrorSurface
        case .neutral: return Theme.Color.bhumitraSurfaceSecondary
        }
    }
}

// MARK: - Metrics

public enum SettingsMetrics {
    public static let horizontalPadding: CGFloat = 20
    public static let cardRadius: CGFloat = 14
    public static let rowMinHeight: CGFloat = 50
    /// Width reserved for a row's monochrome glyph.
    public static let iconTile: CGFloat = 22
    /// Leading inset for dividers so they align with row text, not the icon.
    public static let dividerInset: CGFloat = 16 + iconTile + 12
}

// MARK: - Header

/// Screen header: large title, optional subtitle, trailing close/done control.
public struct SettingsHeader: View {
    let title: String
    let subtitle: String?
    let closeStyle: CloseStyle
    let onClose: () -> Void

    public enum CloseStyle { case close, done }

    public init(_ title: String, subtitle: String? = nil, closeStyle: CloseStyle = .close, onClose: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.closeStyle = closeStyle
        self.onClose = onClose
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.stackSansHeadline(size: 26, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.googleSans(size: 13.5, weight: .regular))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                }
            }
            Spacer(minLength: 8)
            switch closeStyle {
            case .close:
                SheetIconButton("xmark", accessibilityLabel: "Close", action: onClose)
            case .done:
                Button(action: onClose) {
                    Text("Done")
                        .font(.googleSans(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                        .frame(minHeight: SheetChrome.iconButtonSize)
                }
                .buttonStyle(MapChromePressStyle())
            }
        }
        .padding(.horizontal, SettingsMetrics.horizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}

// MARK: - Card & Section

/// Flat grouped surface: a quiet fill on the screen's single background —
/// no border, no shadow.
public struct SettingsCard<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        VStack(spacing: 0) { content }
            .background(SheetChrome.controlFill)
            .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.cardRadius, style: .continuous))
    }
}

/// Section = quiet caption above + grouped card + optional explanatory footer.
public struct SettingsSection<Content: View>: View {
    let title: String?
    let footer: String?
    let content: Content

    public init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.googleSans(size: 13, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            SettingsCard { content }
            if let footer {
                Text(footer)
                    .font(.googleSans(size: 12, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// Divider inset to align with row titles.
public struct SettingsDivider: View {
    let inset: CGFloat
    public init(inset: CGFloat = SettingsMetrics.dividerInset) { self.inset = inset }
    public var body: some View {
        Rectangle()
            .fill(Theme.Color.bhumitraBorder)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

// MARK: - Icon Tile

/// Monochrome glyph. `tone` only matters for `.danger` (destructive rows);
/// colour is reserved for state (badges), not decoration.
public struct SettingsIconTile: View {
    let systemName: String
    let tone: SettingsTone
    let size: CGFloat

    public init(_ systemName: String, tone: SettingsTone = .neutral, size: CGFloat = SettingsMetrics.iconTile) {
        self.systemName = systemName
        self.tone = tone
        self.size = size
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(tone == .danger ? Theme.Color.bhumitraError : Theme.Color.bhumitraSecondaryText)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Badge

public struct SettingsBadge: View {
    let text: String
    let tone: SettingsTone
    public init(_ text: String, tone: SettingsTone = .neutral) {
        self.text = text
        self.tone = tone
    }
    public var body: some View {
        Text(text)
            .font(.googleSans(size: 12, weight: .semibold))
            .foregroundColor(tone.foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tone.background)
            .clipShape(Capsule())
    }
}

// MARK: - Row

public enum SettingsAccessory {
    case chevron
    case external
    case none
    case progress
    case checkmark
}

/// Standard tappable settings row.
public struct SettingsRow: View {
    let icon: String?
    let tone: SettingsTone
    let title: String
    let subtitle: String?
    let value: String?
    let badge: (text: String, tone: SettingsTone)?
    let accessory: SettingsAccessory
    let isDestructive: Bool
    let action: (() -> Void)?

    public init(
        icon: String? = nil,
        tone: SettingsTone = .neutral,
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        badge: (text: String, tone: SettingsTone)? = nil,
        accessory: SettingsAccessory = .chevron,
        isDestructive: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.tone = tone
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.badge = badge
        self.accessory = accessory
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        if let action {
            Button {
                Theme.selectionHaptic()
                action()
            } label: { rowContent }
                .buttonStyle(SettingsRowButtonStyle())
                .disabled(accessory == .progress)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            if let icon {
                SettingsIconTile(icon, tone: isDestructive ? .danger : tone)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.googleSans(size: 16, weight: .regular))
                    .foregroundColor(isDestructive ? Theme.Color.bhumitraError : Theme.Color.bhumitraPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.googleSans(size: 12.5, weight: .regular))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.googleSans(size: 14, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineLimit(1)
            }
            if let badge {
                SettingsBadge(badge.text, tone: badge.tone)
            }
            accessoryView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: SettingsMetrics.rowMinHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(accessory == .external ? "Opens outside the app" : "")
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
        case .external:
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
        case .progress:
            ProgressView().controlSize(.small)
        case .checkmark:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.Color.bhumitraPrimary)
        case .none:
            EmptyView()
        }
    }
}

/// Row press feedback: subtle background highlight like native grouped lists.
public struct SettingsRowButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.Color.bhumitraBorder : Color.clear)
            .animation(Theme.Animation.micro, value: configuration.isPressed)
    }
}

// MARK: - Info row (non-interactive, multi-line)

/// Read-only explanatory row: icon + title + paragraph. Used for disclosures.
public struct SettingsInfoRow: View {
    let icon: String
    let tone: SettingsTone
    let title: String
    let message: String

    public init(icon: String, tone: SettingsTone = .neutral, title: String, message: String) {
        self.icon = icon
        self.tone = tone
        self.title = title
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SettingsIconTile(icon, tone: tone)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.googleSans(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                Text(message)
                    .font(.googleSans(size: 13, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Key/value row

/// Label on the left, value on the right, optional copy action.
public struct SettingsKeyValueRow: View {
    let label: String
    let value: String
    let monospaced: Bool
    let onCopy: (() -> Void)?

    public init(_ label: String, value: String, monospaced: Bool = false, onCopy: (() -> Void)? = nil) {
        self.label = label
        self.value = value
        self.monospaced = monospaced
        self.onCopy = onCopy
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.googleSans(size: 14.5, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
            Spacer(minLength: 12)
            Text(value)
                .font(monospaced ? .system(size: 13.5, weight: .medium, design: .monospaced) : .googleSans(size: 14.5, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            if let onCopy {
                Button {
                    Theme.haptic(.light)
                    onCopy()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy \(label)")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Toast

/// Lightweight confirmation toast pinned to the bottom of a screen.
public struct SettingsToastModifier: ViewModifier {
    @Binding var message: String?
    let tone: SettingsTone

    public func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                MapStatusPill(
                    icon: tone == .danger ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                    tone: tone == .danger ? .danger : .success,
                    title: message
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
                .task(id: message) {
                    UIAccessibility.post(notification: .announcement, argument: message)
                    try? await Task.sleep(nanoseconds: 2_400_000_000)
                    withAnimation(Theme.Animation.standard) { self.message = nil }
                }
            }
        }
        .animation(Theme.Animation.spring, value: message)
    }
}

public extension View {
    func settingsToast(_ message: Binding<String?>, tone: SettingsTone = .success) -> some View {
        modifier(SettingsToastModifier(message: message, tone: tone))
    }
}

// MARK: - App info

public enum AppInfo {
    public static var name: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Bhumitra"
    }
    public static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    public static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    public static let privacyPolicyURL = URL(string: "https://kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/")!
    public static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}

// MARK: - App footer

/// Standard footer: app name + version + independence notice (trust signal).
public struct SettingsAppFooter: View {
    public init() {}
    public var body: some View {
        VStack(spacing: 4) {
            Text("\(AppInfo.name) \(AppInfo.version) (\(AppInfo.build))")
                .font(.googleSans(size: 12, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
            Text("Independent app. Not affiliated with the Government of Odisha.")
                .font(.googleSans(size: 11.5, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}
