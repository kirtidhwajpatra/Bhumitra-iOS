//
//  AppearanceManager.swift
//  MyBhoomi
//
//  Created for Profile & Appearance Customization.
//  Central manager for app theme, appearance styling, and display preferences.
//

import SwiftUI
import Combine

// MARK: - App Theme Mode
public enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .system: return "Match device settings"
        case .light: return "Clean paper white"
        case .dark: return "OLED night mode"
        }
    }
    
    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Appearance Manager
@MainActor
public final class AppearanceManager: ObservableObject {
    public static let shared = AppearanceManager()
    
    // Theme Preference (persisted)
    @AppStorage("app_theme_mode") public var themeModeRaw: String = AppThemeMode.system.rawValue {
        didSet {
            objectWillChange.send()
        }
    }
    
    // Preferred Land Area Unit
    @AppStorage("preferred_land_area_unit") public var preferredUnitRaw: String = LandAreaUnit.acres.rawValue {
        didSet {
            objectWillChange.send()
        }
    }
    
    // Haptics Enabled Preference
    @AppStorage("app_haptics_enabled") public var isHapticsEnabled: Bool = true {
        didSet {
            objectWillChange.send()
        }
    }
    
    // High-Contrast Boundaries Preference
    @AppStorage("high_contrast_boundaries") public var highContrastBoundaries: Bool = false {
        didSet {
            objectWillChange.send()
        }
    }
    
    private init() {}
    
    // MARK: - Computed Properties
    
    public var themeMode: AppThemeMode {
        get {
            AppThemeMode(rawValue: themeModeRaw) ?? .system
        }
        set {
            themeModeRaw = newValue.rawValue
        }
    }
    
    public var colorScheme: ColorScheme? {
        themeMode.colorScheme
    }
    
    public var preferredUnit: LandAreaUnit {
        get {
            LandAreaUnit(rawValue: preferredUnitRaw) ?? .acres
        }
        set {
            preferredUnitRaw = newValue.rawValue
        }
    }
    
    // MARK: - Haptic Helper
    
    public func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func triggerSelectionHaptic() {
        guard isHapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
