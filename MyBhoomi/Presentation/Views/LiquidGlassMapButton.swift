import SwiftUI

// ============================================================
// MARK: - COMPACT NEUTRAL LIQUID GLASS MAP CAPSULE
// ============================================================

public struct LiquidGlassMapControlsCapsule: View {
    @ObservedObject public var viewModel: MapViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    public init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Cadastral Parcels Layer Toggle (Eye)
            Button {
                Theme.haptic(.medium)
                withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                    viewModel.toggleParcels()
                }
            } label: {
                Image(systemName: viewModel.showParcels ? "eye.fill" : "eye.slash")
                    .font(.system(size: 16.5, weight: .medium))
                    .foregroundColor(viewModel.showParcels ? activeColor : inactiveColor)
                    .frame(width: 38, height: 38)
                    .contentTransition(.symbolEffect(.replace))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.showParcels ? "Hide cadastral parcels" : "Show cadastral parcels")
            
            // Subtle Neutral Divider
            Rectangle()
                .fill(dividerColor)
                .frame(width: 18, height: 0.6)
            
            // 2. User GPS Location Tracking (Location)
            Button {
                Theme.haptic(.medium)
                withAnimation(.spring(response: 0.30, dampingFraction: 0.75)) {
                    viewModel.toggleUserTracking()
                }
            } label: {
                Image(systemName: viewModel.isTrackingUser ? "location.fill" : "location")
                    .font(.system(size: 16.5, weight: .medium))
                    .foregroundColor(viewModel.isTrackingUser ? activeColor : inactiveColor)
                    .frame(width: 38, height: 38)
                    .contentTransition(.symbolEffect(.replace))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.isTrackingUser ? "Stop location tracking" : "Track GPS location")
        }
        .padding(1.5)
        .glassEffect(
            .regular.tint(mapSurfaceTint).interactive(),
            in: .capsule
        )
    }
    
    // Neutral adaptive colors for Dark / Light appearances
    private var activeColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var inactiveColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.40) : Color.black.opacity(0.62)
    }
    
    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.16)
    }

    private var mapSurfaceTint: Color {
        colorScheme == .dark ? Color.black.opacity(0.16) : Color.white.opacity(0.94)
    }
}

// Single button variant for compatibility
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
        case .eye(let active):
            return active
        case .location(let active):
            return active
        }
    }
    
    private var iconName: String {
        switch type {
        case .eye(let active):
            return active ? "eye.fill" : "eye.slash"
        case .location(let active):
            return active ? "location.fill" : "location"
        }
    }

    private var mapSurfaceTint: Color {
        colorScheme == .dark ? Color.black.opacity(0.16) : Color.white.opacity(0.94)
    }
    
    public var body: some View {
        Button {
            Theme.haptic(.medium)
            action()
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 16.5, weight: .medium))
                .foregroundColor(isActive ? (colorScheme == .dark ? .white : .black) : (colorScheme == .dark ? Color.white.opacity(0.40) : Color.black.opacity(0.62)))
                .frame(width: 38, height: 38)
                .contentTransition(.symbolEffect(.replace))
                .contentShape(Circle())
        }
        .padding(1.5)
        .glassEffect(
            .regular.tint(mapSurfaceTint).interactive(),
            in: .circle
        )
    }
}
