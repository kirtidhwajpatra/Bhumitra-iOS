//  CTAButtonStyle.swift
//  MyBhoomi
//
//  The ONE style for full-width call-to-action buttons app-wide. Every CTA
//  gets the same 52pt capsule, the same type, the same press feedback and the
//  same disabled look, so "Search now", "Get 50 Searches", "Update now" etc.
//  are visibly the same control.
//
//  Usage:
//      Button("Search now") { … }.buttonStyle(.primaryCTA)
//      Button { … } label: { Label("Retry", systemImage: "arrow.clockwise") }
//          .buttonStyle(.secondaryCTA)
//
//  Labels should carry only content (Text / Image / ProgressView) — no fonts,
//  colours, frames or backgrounds; the style owns all of that.

import SwiftUI

public struct CTAButtonStyle: ButtonStyle {
    public enum Kind {
        /// Solid brand fill, white text — the main action on a screen.
        case primary
        /// Soft brand tint, brand text — an alternative action.
        case secondary
        /// White fill, brand text — for use ON a brand-coloured surface.
        case inverse
        /// Quiet grey fill, primary text — a low-emphasis companion action.
        case neutral
        /// Soft red tint, red text — sign out, delete, remove.
        case destructive
        /// Ink fill (black in light, white in dark), inverted text —
        /// Sign in with Apple, per Apple's button guidelines.
        case contrast
        /// Background fill with a hairline outline, primary text —
        /// third-party sign-in (Google) beside a `.contrast` button.
        case outline
    }

    public enum Size {
        /// 52pt, full width — the screen's main action.
        case regular
        /// 36pt, hugs its label — actions inside cards and notices.
        case compact
    }

    let kind: Kind
    let size: Size
    @Environment(\.isEnabled) private var isEnabled

    public init(_ kind: Kind = .primary, size: Size = .regular) {
        self.kind = kind
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .regular
                  ? .stackSansHeadline(size: 17, weight: .semibold)
                  : .system(size: 14, weight: .semibold))
            .labelStyle(CTALabelStyle())
            .foregroundStyle(foreground)
            .tint(foreground) // ProgressView inside the label
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, size == .regular ? 20 : 14)
            .frame(maxWidth: size == .regular ? .infinity : nil)
            .frame(height: size == .regular ? Theme.ButtonHeight.cta : 36)
            .background(Capsule().fill(background))
            .overlay {
                if kind == .outline {
                    Capsule().strokeBorder(Theme.Color.bhumitraBorder, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        guard isEnabled else { return Theme.Color.bhumitraTertiaryText }
        switch kind {
        case .primary: return .white
        case .secondary, .inverse: return Theme.Color.bhumitraPrimary
        case .neutral, .outline: return Theme.Color.bhumitraPrimaryText
        case .destructive: return Theme.Color.bhumitraError
        case .contrast: return SheetChrome.background
        }
    }

    private var background: Color {
        guard isEnabled else { return SheetChrome.controlFill }
        switch kind {
        case .primary: return Theme.Color.bhumitraPrimary
        case .secondary: return Theme.Color.bhumitraTint
        case .inverse: return .white
        case .neutral: return SheetChrome.controlFill
        case .destructive: return Theme.Color.bhumitraErrorSurface
        case .contrast: return Theme.Color.bhumitraPrimaryText
        case .outline: return SheetChrome.background
        }
    }
}

/// Title + icon with one consistent gap and icon weight.
private struct CTALabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.font(.system(size: 15, weight: .semibold))
            configuration.title
        }
    }
}

extension ButtonStyle where Self == CTAButtonStyle {
    public static var primaryCTA: CTAButtonStyle { CTAButtonStyle(.primary) }
    public static var secondaryCTA: CTAButtonStyle { CTAButtonStyle(.secondary) }
    public static var inverseCTA: CTAButtonStyle { CTAButtonStyle(.inverse) }
}

/// Round companion to a CTA (reset, bookmark…): same 52pt height as the CTA
/// it sits next to, quiet fill, one glyph.
public struct CTAIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isEnabled ? Theme.Color.bhumitraPrimaryText : Theme.Color.bhumitraTertiaryText)
            .frame(width: Theme.ButtonHeight.cta, height: Theme.ButtonHeight.cta)
            .background(Circle().fill(SheetChrome.controlFill))
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CTAIconButtonStyle {
    public static var ctaIcon: CTAIconButtonStyle { CTAIconButtonStyle() }
}
