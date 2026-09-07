import SwiftUI

// ============================================================
// MARK: - VERTICAL FLOATING MAP CONTROLS (PARCELS EYE, COMPASS, GPS)
// ============================================================

public struct LiquidGlassMapControlsCapsule: View {
    @ObservedObject public var viewModel: MapViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    public init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    private let brandAccentGradient = LinearGradient(
        colors: [
            Color(red: 168/255, green: 85/255, blue: 247/255),
            Color(red: 126/255, green: 34/255, blue: 206/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let brandAccentColor = Color(red: 147/255, green: 51/255, blue: 234/255)
    
    private func glassTint(isActive: Bool, isAccent: Bool = false) -> Color {
        if isActive && isAccent {
            return colorScheme == .dark
                ? Color(red: 147/255, green: 51/255, blue: 234/255).opacity(0.24)
                : Color(red: 248/255, green: 243/255, blue: 255/255).opacity(0.96)
        }
        return colorScheme == .dark ? Color.black.opacity(0.20) : Color.white.opacity(0.94)
    }
    
    private var defaultIconColor: Color {
        colorScheme == .dark ? Color.white : Color(red: 25/255, green: 25/255, blue: 30/255)
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 1. Cadastral Plot Maps Visibility Toggle (Eye Button)
            mapCircleButton(
                icon: viewModel.showParcels ? "eye.fill" : "eye.slash",
                accessibilityLabel: viewModel.showParcels ? "Hide plot parcels" : "Show plot parcels",
                isActive: viewModel.showParcels,
                isAccent: true
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                    viewModel.toggleParcels()
                }
            }
            
            // 2. Compass / Bearing Reset (Orient North)
            mapCircleButton(
                icon: "location.north.line.fill",
                accessibilityLabel: "Orient map to North",
                isActive: false,
                isAccent: false
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                    viewModel.resetBearingToNorth()
                }
            }
            
            // 3. Current GPS Location Tracker
            mapCircleButton(
                icon: viewModel.isTrackingUser ? "scope" : "location.fill",
                accessibilityLabel: viewModel.isTrackingUser ? "Stop GPS tracking" : "Center on GPS location",
                isActive: viewModel.isTrackingUser,
                isAccent: true
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                    viewModel.toggleUserTracking()
                }
            }
        }
    }
    
    @ViewBuilder
    private func mapCircleButton(
        icon: String,
        accessibilityLabel: String,
        isActive: Bool,
        isAccent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isActive && isAccent {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(brandAccentGradient)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(defaultIconColor)
                }
            }
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .glassEffect(
            .regular.tint(glassTint(isActive: isActive, isAccent: isAccent)).interactive(),
            in: .circle
        )
        .shadow(
            color: (isActive && isAccent)
                ? brandAccentColor.opacity(colorScheme == .dark ? 0.35 : 0.18)
                : Color.black.opacity(colorScheme == .dark ? 0.32 : 0.12),
            radius: 8,
            x: 0,
            y: 3
        )
        .accessibilityLabel(accessibilityLabel)
    }
}

// Single button variant for backward compatibility
public struct LiquidGlassMapButton: View {
    public enum ButtonType {
        case eye(isActive: Bool)
        case location(isActive: Bool)
    }
    
    public let type: ButtonType
    public let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    public init(type: ButtonType, action: @escaping () -> Void) {
        self.type = type
        self.action = action
    }
    
    private var isActive: Bool {
        switch type {
        case .eye(let active): return active
        case .location(let active): return active
        }
    }
    
    private var iconName: String {
        switch type {
        case .eye(let active): return active ? "eye.fill" : "eye.slash"
        case .location(let active): return active ? "scope" : "location.fill"
        }
    }
    
    private let brandAccentGradient = LinearGradient(
        colors: [
            Color(red: 168/255, green: 85/255, blue: 247/255),
            Color(red: 126/255, green: 34/255, blue: 206/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let brandAccentColor = Color(red: 147/255, green: 51/255, blue: 234/255)
    
    private var mapGlassTint: Color {
        if isActive {
            return colorScheme == .dark
                ? Color(red: 147/255, green: 51/255, blue: 234/255).opacity(0.24)
                : Color(red: 248/255, green: 243/255, blue: 255/255).opacity(0.96)
        }
        return colorScheme == .dark ? Color.black.opacity(0.20) : Color.white.opacity(0.94)
    }
    
    public var body: some View {
        Button(action: action) {
            Group {
                if isActive {
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(brandAccentGradient)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 25/255, green: 25/255, blue: 30/255))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .glassEffect(
            .regular.tint(mapGlassTint).interactive(),
            in: .circle
        )
        .shadow(
            color: isActive
                ? brandAccentColor.opacity(colorScheme == .dark ? 0.35 : 0.18)
                : Color.black.opacity(colorScheme == .dark ? 0.32 : 0.12),
            radius: 8,
            x: 0,
            y: 3
        )
    }
}

