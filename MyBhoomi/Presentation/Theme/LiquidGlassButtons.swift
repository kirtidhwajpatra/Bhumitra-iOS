import SwiftUI
import UIKit

// MARK: - 1. Bhumitra Native Liquid Glass Buttons (From LiquidGlassButtonsDemo)

/// Primary Pill Button from LiquidGlassButtonsDemo Section 10
public struct LiquidPrimaryButton: View {
    public let title: String
    public let icon: String?
    public let isEnabled: Bool
    public let height: CGFloat
    public let action: () -> Void
    
    public init(
        _ title: String = "Load plots",
        icon: String? = nil,
        isEnabled: Bool = true,
        height: CGFloat = 50,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.height = height
        self.action = action
    }
    
    public init(
        title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        height: CGFloat = 50,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.height = height
        self.action = action
    }
    
    public var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(.accentColor)
        .clipShape(Capsule())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.55)
    }
}

/// Secondary Action Button from LiquidGlassButtonsDemo Section 6
public struct LiquidSecondaryButton: View {
    public let title: String
    public let icon: String?
    public let isEnabled: Bool
    public let height: CGFloat
    public let action: () -> Void
    
    public init(
        _ title: String = "Cancel",
        icon: String? = nil,
        isEnabled: Bool = true,
        height: CGFloat = 50,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.height = height
        self.action = action
    }
    
    public init(
        title: String,
        icon: String? = nil,
        isEnabled: Bool = true,
        height: CGFloat = 50,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.height = height
        self.action = action
    }
    
    public var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.headline)
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.55)
    }
}

/// Circular Glass Button from LiquidGlassButtonsDemo Section 4 & 8
public struct LiquidFABButton: View {
    public let icon: String
    public let diameter: CGFloat
    public let isProminent: Bool
    public let accessibilityLabel: String?
    public let action: () -> Void
    
    public init(
        icon: String = "plus",
        diameter: CGFloat = 64,
        isProminent: Bool = true,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.diameter = diameter
        self.isProminent = isProminent
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
    
    public var body: some View {
        if isProminent {
            Button {
                action()
            } label: {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .frame(width: diameter, height: diameter)
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
            .accessibilityLabel(accessibilityLabel ?? icon)
        } else {
            Button {
                action()
            } label: {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .frame(width: diameter, height: diameter)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(accessibilityLabel ?? icon)
        }
    }
}

// MARK: - 2. Convenient Typealiases

public typealias LiquidEmeraldButton = LiquidPrimaryButton
public typealias LiquidMintButton = LiquidSecondaryButton
public typealias LiquidCircularButton = LiquidFABButton
