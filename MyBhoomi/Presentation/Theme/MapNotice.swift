//  MapNotice.swift
//  MyBhoomi
//
//  The ONE family for transient status UI: progress ("Loading land parcels…"),
//  confirmations ("Plots near you"), toasts, connectivity ("You're offline")
//  and actionable notices ("Location access required"). Everything sits on
//  the same glass surface as the map controls (MapChrome), uses one type
//  scale, and colours only the leading glyph by meaning.

import SwiftUI

// MARK: - Tone

public enum NoticeTone: Equatable {
    case neutral, progress, success, warning, danger

    var glyphColor: Color {
        switch self {
        case .neutral, .progress: return Theme.Color.bhumitraPrimary
        case .success: return Theme.Color.bhumitraSuccess
        case .warning: return Theme.Color.bhumitraWarning
        case .danger: return Theme.Color.bhumitraError
        }
    }
}

// MARK: - Status pill (one line, optional detail, optional dismiss)

/// Compact capsule for progress, confirmations and toasts.
public struct MapStatusPill: View {
    let icon: String?
    let tone: NoticeTone
    let title: String
    let detail: String?
    let action: NoticeAction?
    let onDismiss: (() -> Void)?

    public init(
        icon: String? = nil,
        tone: NoticeTone = .neutral,
        title: String,
        detail: String? = nil,
        action: NoticeAction? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.tone = tone
        self.title = title
        self.detail = detail
        self.action = action
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 8) {
            Group {
                if tone == .progress {
                    ProgressView()
                        .controlSize(.small)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(tone.glyphColor)
                }
            }
            .frame(width: 16)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .lineLimit(1)

            if let detail {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineLimit(1)
            }

            // Optional inline text action ("Add"), deliberately quiet: brand
            // text, no filled button.
            if let action {
                Rectangle()
                    .fill(MapChrome.dividerColor)
                    .frame(width: 1, height: 16)
                Button {
                    Theme.haptic(.light)
                    action.action()
                } label: {
                    Text(action.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MapChromePressStyle())
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, onDismiss == nil ? 14 : 8)
        .frame(height: 36)
        .mapChromeSurface(in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Notice card (title, message, actions)

public struct NoticeAction {
    public let title: String
    public let icon: String?
    public let action: () -> Void

    public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

/// Card for states that need the user to act (permissions, failures,
/// low credits). Actions use the compact CTA styles.
public struct MapNoticeCard: View {
    let icon: String
    let tone: NoticeTone
    let title: String
    let message: String?
    let primary: NoticeAction?
    let secondary: NoticeAction?
    let onDismiss: (() -> Void)?

    public init(
        icon: String,
        tone: NoticeTone = .neutral,
        title: String,
        message: String? = nil,
        primary: NoticeAction? = nil,
        secondary: NoticeAction? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.tone = tone
        self.title = title
        self.message = message
        self.primary = primary
        self.secondary = secondary
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tone.glyphColor)
                    .frame(width: 20)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 4)

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
            }

            if primary != nil || secondary != nil {
                HStack(spacing: 8) {
                    if let primary {
                        Button {
                            Theme.haptic(.light)
                            primary.action()
                        } label: {
                            noticeLabel(primary)
                        }
                        .buttonStyle(CTAButtonStyle(.primary, size: .compact))
                    }
                    if let secondary {
                        Button {
                            Theme.haptic(.light)
                            secondary.action()
                        } label: {
                            noticeLabel(secondary)
                        }
                        .buttonStyle(CTAButtonStyle(.neutral, size: .compact))
                    }
                }
                .padding(.leading, 30)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mapChromeSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func noticeLabel(_ a: NoticeAction) -> some View {
        if let icon = a.icon {
            Label(a.title, systemImage: icon)
        } else {
            Text(a.title)
        }
    }
}
