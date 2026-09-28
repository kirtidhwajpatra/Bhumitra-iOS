import SwiftUI

// ============================================================
// MARK: - VERTICAL FLOATING MAP CONTROLS PILL (PARCELS EYE & GPS LOCATION)
// ============================================================

public struct LiquidGlassMapControlsCapsule: View {
    @ObservedObject public var viewModel: MapViewModel
    
    public init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Plot boundary layer toggle
            controlButton(
                symbol: viewModel.showParcels ? "square.3.layers.3d" : "square.3.layers.3d.slash",
                isActive: viewModel.showParcels,
                label: viewModel.showParcels ? "Hide plot boundaries" : "Show plot boundaries"
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleParcels()
                }
            }
            
            MapChromeDivider(.horizontal)
            
            // 2. Current location (outline = idle, filled accent = following)
            controlButton(
                symbol: viewModel.isTrackingUser ? "location.fill" : "location",
                isActive: viewModel.isTrackingUser,
                label: viewModel.isTrackingUser ? "Stop following location" : "Show my location"
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleUserTracking()
                }
            }
        }
        .frame(width: MapChrome.controlHeight)
        .mapChromeSurface(in: Capsule())
    }
    
    private func controlButton(
        symbol: String,
        isActive: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: MapChrome.iconSize, weight: .medium))
                .foregroundColor(isActive ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraPrimaryText)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: MapChrome.controlHeight, height: MapChrome.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(MapChromePressStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
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
            Theme.Color.bhumitraPrimary,
            Theme.Color.bhumitraPrimaryPressed
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let brandAccentColor = Theme.Color.bhumitraPrimary
    
    private var mapGlassTint: Color {
        if isActive {
            return Theme.Color.bhumitraSelection
        }
        return Theme.Color.bhumitraMapSurface
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
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
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

