//
//  BhumitraMotion.swift
//  MyBhoomi
//
//  Premium Motion & Transition System for Bhumitra iOS.
//  Provides standardized spatial timing curves, non-bouncy spring physics,
//  tactile press micro-interactions, and accessibility Reduce Motion compliance.
//

import SwiftUI
import UIKit

// MARK: - Motion Design Tokens
public enum BhumitraMotion {
    
    // MARK: - Standardized Timing Constants
    public static let quickDuration: Double = 0.16
    public static let standardDuration: Double = 0.26
    public static let emphasisDuration: Double = 0.36
    public static let morphDuration: Double = 0.40
    public static let tabDuration: Double = 0.18
    public static let documentDuration: Double = 0.36
    
    // MARK: - Animation Presets (Respecting Reduce Motion)
    
    /// Quick micro-interaction (buttons, haptic feedback releases)
    public static var quick: Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .linear(duration: 0.08)
        }
        return .easeOut(duration: quickDuration)
    }
    
    /// Standard interface transition (toasts, alerts, secondary navigation)
    public static var standard: Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .easeOut(duration: 0.15)
        }
        return .easeOut(duration: standardDuration)
    }
    
    /// Tab switching transition (fast, lightweight, subtle crossfade)
    public static var tabSwitch: Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .linear(duration: 0.05)
        }
        return .easeOut(duration: tabDuration)
    }
    
    /// Bottom sheet presentation (attached, smooth non-oscillating spring)
    public static var sheetPresentation: Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .easeOut(duration: 0.20)
        }
        return .spring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.06)
    }
    
    /// Shared-element / vertical morph expansion (Card -> Land Passport)
    public static var morphExpand: Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .easeOut(duration: 0.20)
        }
        return .spring(response: 0.40, dampingFraction: 0.86, blendDuration: 0.08)
    }
    
    /// Document / Official RoR reveal (physical document metaphor)
    public static var documentReveal: Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .easeOut(duration: 0.18)
        }
        return .easeOut(duration: documentDuration)
    }
    
    /// Tactile press animation
    public static var tactilePress: Animation {
        .spring(response: 0.20, dampingFraction: 0.76, blendDuration: 0)
    }
}

// MARK: - Tactile Press Button Styles

/// Subtle tactile card press style: scales down to 0.985 with no exaggerated bounce
public struct BhumitraCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(BhumitraMotion.tactilePress, value: configuration.isPressed)
    }
}

/// Primary Action Button Style: subtle 0.975 compression with smooth return
public struct BhumitraPrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(BhumitraMotion.tactilePress, value: configuration.isPressed)
    }
}

// MARK: - Custom Transitions

public extension AnyTransition {
    
    /// Tab crossfade with micro-scale (0.995 -> 1.0)
    static var bhumitraTabTransition: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.995, anchor: .center)),
            removal: .opacity
        )
    }
    
    /// Plot bottom sheet attached upward reveal
    static var bhumitraPlotSheet: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.975, anchor: .bottom)),
            removal: .move(edge: .bottom)
                .combined(with: .opacity)
        )
    }
    
    /// Upward card materialization for search results
    static var bhumitraResultMaterialization: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.985, anchor: .bottom)),
            removal: .opacity
        )
    }
    
    /// Physical document vertical reveal (scale 0.985 -> 1.0, opacity 0 -> 1)
    static var bhumitraDocumentReveal: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.985, anchor: .center))
                .combined(with: .offset(y: 12)),
            removal: .opacity.combined(with: .offset(y: -8))
        )
    }
    
    /// Full screen passport modal expansion
    static var bhumitraPassportCover: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.98, anchor: .center))
                .combined(with: .offset(y: 16)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .center))
        )
    }
}

// MARK: - View Extension Helpers
public extension View {
    func bhumitraCardPress() -> some View {
        self.buttonStyle(BhumitraCardButtonStyle())
    }
    
    func bhumitraPrimaryButtonPress() -> some View {
        self.buttonStyle(BhumitraPrimaryActionButtonStyle())
    }
}
