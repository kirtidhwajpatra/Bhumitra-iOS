//
//  SummaryMetricCard.swift
//  MyBhoomi
//
//  Premium Summary Metric Card for QuickFeatures / Settings Screen.
//  Provides distinct visual identities for Plan (Purple), Search Credit (Blue),
//  and Saved Land (Green) with Apple-like materials, layered vector artwork,
//  and full Light & Dark mode contrast compliance.
//

import SwiftUI

public enum SummaryCardTheme {
    case plan
    case searchCredits
    case savedLand
    case supportEmail
}

public struct SummaryMetricCard: View {
    public let theme: SummaryCardTheme
    public let value: String
    public let subtitle: String
    public var action: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        theme: SummaryCardTheme,
        value: String,
        subtitle: String,
        action: (() -> Void)? = nil
    ) {
        self.theme = theme
        self.value = value
        self.subtitle = subtitle
        self.action = action
    }
    
    // MARK: - Color Identities
    
    private var accentColor: Color {
        switch theme {
        case .plan:
            return Theme.Color.dynamic(
                light: Color(hex: "#7600FF"),
                dark: Color(hex: "#A855F7")
            )
        case .searchCredits:
            return Theme.Color.dynamic(
                light: Color(hex: "#0066EE"),
                dark: Color(hex: "#38BDF8")
            )
        case .savedLand:
            return Theme.Color.dynamic(
                light: Color(hex: "#059669"),
                dark: Color(hex: "#34D399")
            )
        case .supportEmail:
            return Theme.Color.dynamic(
                light: Color(hex: "#EA580C"),
                dark: Color(hex: "#FB923C")
            )
        }
    }
    
    private var cardGradient: LinearGradient {
        switch theme {
        case .plan:
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [Color(hex: "#26153E"), Color(hex: "#160B26")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color(hex: "#FAF5FF"), Color(hex: "#EFE5FD")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
        case .searchCredits:
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [Color(hex: "#102347"), Color(hex: "#09142A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color(hex: "#F0F7FF"), Color(hex: "#E0EEFD")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
        case .savedLand:
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [Color(hex: "#0E2F23"), Color(hex: "#071B14")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color(hex: "#F0FDF6"), Color(hex: "#DEF7EA")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
        case .supportEmail:
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [Color(hex: "#34170B"), Color(hex: "#1F0E07")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color(hex: "#FFF7ED"), Color(hex: "#FFEDD5")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private var cardBorderColor: Color {
        accentColor.opacity(colorScheme == .dark ? 0.28 : 0.16)
    }
    
    private var badgeBackground: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.10)
        } else {
            return Color.white.opacity(0.85)
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(SummaryCardButtonStyle())
            } else {
                cardContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value), \(subtitle)")
        .accessibilityHint(action != nil ? "Double tap to open \(subtitle)" : "")
    }
    
    private var cardContent: some View {
        Group {
            switch theme {
            case .plan, .supportEmail, .searchCredits:
                assetCardContent
            case .savedLand:
                legacyVectorCardContent
            }
        }
    }
    
    // MARK: - 3D Reference Asset Card Content
    
    private var assetCardContent: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Color for Support Email Card
            if theme == .supportEmail {
                Color.white
            }
            
            // Background 3D Illustration Asset
            Image(cardBackgroundImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            
            // Labels positioned at bottom-left matching design reference
            VStack(alignment: .leading, spacing: 0) {
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .lineLimit(1)
                
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
            }
            .padding(.leading, 14)
            .padding(.bottom, 14)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.14)
                        : (theme == .supportEmail ? Color.black.opacity(0.04) : Color.clear),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06),
            radius: 8,
            x: 0,
            y: 3
        )
    }
    
    private var cardBackgroundImageName: String {
        switch theme {
        case .plan:
            return "CardBgPlanHeart"
        case .supportEmail:
            return "CardIllustrationSupportChat"
        case .searchCredits:
            return "CardBgCreditFlame"
        case .savedLand:
            return "CardBgPlanHeart"
        }
    }
    
    // MARK: - Fallback / Legacy Vector Card
    
    private var legacyVectorCardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Artwork & Icon Atmosphere
            HStack(alignment: .top) {
                thematicArtwork
                Spacer(minLength: 0)
            }
            .frame(height: 38)
            .clipped()
            
            Spacer(minLength: 10)
            
            // Primary Metric Value
            Text(value)
                .font(.stackSansHeadline(size: value.count > 6 ? 16 : 22, weight: .bold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            
            // Secondary Label Row
            HStack(spacing: 3) {
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText.opacity(0.75))
            }
            .padding(.top, 3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1.0)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.04),
            radius: 8,
            x: 0,
            y: 3
        )
    }
    
    // MARK: - Thematic SwiftUI Vector Artwork
    
    @ViewBuilder
    private var thematicArtwork: some View {
        ZStack(alignment: .leading) {
            switch theme {
            case .plan:
                planArtwork
            case .searchCredits:
                searchArtwork
            case .savedLand:
                savedLandArtwork
            case .supportEmail:
                supportEmailArtwork
            }
        }
        .accessibilityHidden(true)
    }
    
    // 1. Plan Artwork: Crown + Cadastral Geometry
    private var planArtwork: some View {
        ZStack(alignment: .leading) {
            // Background Cadastral Diamond Facet
            Path { path in
                path.move(to: CGPoint(x: 32, y: 4))
                path.addLine(to: CGPoint(x: 62, y: 16))
                path.addLine(to: CGPoint(x: 48, y: 36))
                path.addLine(to: CGPoint(x: 18, y: 24))
                path.closeSubpath()
            }
            .fill(accentColor.opacity(colorScheme == .dark ? 0.14 : 0.08))
            .offset(x: 4, y: 0)
            
            // Overlapping Cadastral Boundary Stroke
            Path { path in
                path.move(to: CGPoint(x: 28, y: 2))
                path.addLine(to: CGPoint(x: 66, y: 18))
                path.addLine(to: CGPoint(x: 44, y: 38))
            }
            .stroke(accentColor.opacity(colorScheme == .dark ? 0.25 : 0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            .offset(x: 6, y: 0)
            
            // Ambient Radial Glow & Foreground Badge
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(badgeBackground)
                        .frame(width: 32, height: 32)
                        .shadow(color: accentColor.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 6, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(colorScheme == .dark ? 0.35 : 0.20), lineWidth: 1)
                        )
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                
                // Subtle sparkle dot
                Circle()
                    .fill(accentColor.opacity(0.40))
                    .frame(width: 3.5, height: 3.5)
                    .offset(y: -8)
            }
        }
    }
    
    // 2. Search Credit Artwork: Discovery Lens + Topographic Grid Rings
    private var searchArtwork: some View {
        ZStack(alignment: .leading) {
            // Concentric Topographic / Radar Rings
            Circle()
                .stroke(accentColor.opacity(colorScheme == .dark ? 0.16 : 0.10), lineWidth: 1)
                .frame(width: 44, height: 44)
                .offset(x: 14, y: -2)
            
            Circle()
                .stroke(accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: 30, height: 30)
                .offset(x: 21, y: 5)
            
            // Horizontal Coordinate Survey Guide Line
            Rectangle()
                .fill(accentColor.opacity(colorScheme == .dark ? 0.20 : 0.12))
                .frame(width: 34, height: 1)
                .offset(x: 24, y: 20)
            
            // Ambient Radial Glow & Foreground Discovery Lens Badge
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(badgeBackground)
                        .frame(width: 32, height: 32)
                        .shadow(color: accentColor.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 6, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(colorScheme == .dark ? 0.35 : 0.20), lineWidth: 1)
                        )
                    
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                
                // Discovery coordinate cross-tick
                Rectangle()
                    .fill(accentColor.opacity(0.40))
                    .frame(width: 2, height: 6)
                    .offset(y: -7)
            }
        }
    }
    
    // 3. Saved Land Artwork: Map Pin + Cadastral Parcel Polygon
    private var savedLandArtwork: some View {
        ZStack(alignment: .leading) {
            // Cadastral Survey Land Parcel Polygon
            Path { path in
                path.move(to: CGPoint(x: 24, y: 8))
                path.addLine(to: CGPoint(x: 52, y: 4))
                path.addLine(to: CGPoint(x: 64, y: 26))
                path.addLine(to: CGPoint(x: 42, y: 38))
                path.addLine(to: CGPoint(x: 18, y: 28))
                path.closeSubpath()
            }
            .fill(accentColor.opacity(colorScheme == .dark ? 0.14 : 0.08))
            .offset(x: 8, y: -2)
            
            // Cadastral Boundary Dashed Outline
            Path { path in
                path.move(to: CGPoint(x: 24, y: 8))
                path.addLine(to: CGPoint(x: 52, y: 4))
                path.addLine(to: CGPoint(x: 64, y: 26))
                path.addLine(to: CGPoint(x: 42, y: 38))
                path.addLine(to: CGPoint(x: 18, y: 28))
                path.closeSubpath()
            }
            .stroke(accentColor.opacity(colorScheme == .dark ? 0.25 : 0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            .offset(x: 8, y: -2)
            
            // Ambient Radial Glow & Foreground Map Pin Badge
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(badgeBackground)
                        .frame(width: 32, height: 32)
                        .shadow(color: accentColor.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 6, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(colorScheme == .dark ? 0.35 : 0.20), lineWidth: 1)
                        )
                    
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                
                // Centroid property marker dot
                Circle()
                    .fill(accentColor.opacity(0.40))
                    .frame(width: 3.5, height: 3.5)
                    .offset(x: 10, y: 2)
            }
        }
    }
    
    // 4. Support Email Artwork: Concentric Rings + Envelope Badge
    private var supportEmailArtwork: some View {
        ZStack(alignment: .leading) {
            // Concentric Signal / Radar Rings
            Circle()
                .stroke(accentColor.opacity(colorScheme == .dark ? 0.16 : 0.10), lineWidth: 1)
                .frame(width: 44, height: 44)
                .offset(x: 14, y: -2)
            
            Circle()
                .stroke(accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: 30, height: 30)
                .offset(x: 21, y: 5)
            
            // Ambient Radial Glow & Foreground Mail Badge
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(badgeBackground)
                        .frame(width: 32, height: 32)
                        .shadow(color: accentColor.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 6, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(colorScheme == .dark ? 0.35 : 0.20), lineWidth: 1)
                        )
                    
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                
                // Signal tick dot
                Circle()
                    .fill(accentColor.opacity(0.40))
                    .frame(width: 3.5, height: 3.5)
                    .offset(y: -7)
            }
        }
    }
}

// MARK: - Native Tactile Button Style

public struct SummaryCardButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - SwiftUI Preview

#Preview("Summary Cards - Light Mode") {
    HStack(spacing: 10) {
        SummaryMetricCard(theme: .plan, value: "Free", subtitle: "Plan")
        SummaryMetricCard(theme: .supportEmail, value: "Email", subtitle: "Support")
        SummaryMetricCard(theme: .searchCredits, value: "24", subtitle: "Credit")
    }
    .padding(20)
    .preferredColorScheme(.light)
    .background(Color(hex: "#1A1A1A"))
}

#Preview("Summary Cards - Dark Mode") {
    HStack(spacing: 10) {
        SummaryMetricCard(theme: .plan, value: "Free", subtitle: "Plan")
        SummaryMetricCard(theme: .supportEmail, value: "Email", subtitle: "Support")
        SummaryMetricCard(theme: .searchCredits, value: "24", subtitle: "Credit")
    }
    .padding(20)
    .preferredColorScheme(.dark)
    .background(Color(hex: "#000000"))
}
