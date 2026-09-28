//
//  GISVisualTheme.swift
//  MyBhoomi
//
//  Centralized design system for Bhumitra GIS Explorer.
//  Provides semantic cartographic palettes, deterministic color assignments,
//  MapLibre expressions, and visual state rules for all hierarchy tiers:
//  State -> District -> Tahasil -> Village -> Parcel -> Plot.
//

import UIKit
import SwiftUI
import MapLibre

// ============================================================
// MARK: - GIS FEATURE INTERACTION STATE
// ============================================================

public enum GISFeatureState: Equatable {
    case defaultInteractive
    case selected
    case mutedContext
    case hidden
}

// ============================================================
// MARK: - GIS VISUAL THEME ENGINE
// ============================================================

public struct GISVisualTheme {
    
    // MARK: - Core Bhumitra Accent (Brand Purple)
    public static let brandPurpleHex = "#7600FF"
    public static let brandPurple = UIColor(red: 118/255, green: 0/255, blue: 255/255, alpha: 1.0)
    public static let brandPurpleDark = UIColor(red: 168/255, green: 85/255, blue: 247/255, alpha: 1.0)
    
    public static func dynamicBrandPurple(for colorScheme: ColorScheme) -> UIColor {
        colorScheme == .dark ? brandPurpleDark : brandPurple
    }
    
    // MARK: - Map Focus Dimming ("Focus Mode" Base Layer)
    // Darkens the base satellite layer gently to make administrative boundaries pop
    public static func focusDimColor(for colorScheme: ColorScheme) -> UIColor {
        if colorScheme == .dark {
            return UIColor.black.withAlphaComponent(0.28)
        } else {
            return UIColor.black.withAlphaComponent(0.18)
        }
    }
    
    // MARK: - 1. District Palette (8 Restrained Cartographic Colors)
    public static let districtPaletteHex: [String] = [
        "#4A6C82", // Slate Blue
        "#8A6E9C", // Dusky Heather
        "#5C8470", // Sage Moss
        "#A87C5A", // Warm Terracotta
        "#588892", // Muted Teal
        "#987884", // Dusty Rose
        "#76885C", // Olive Meadow
        "#6E7494"  // Dusk Indigo
    ]
    
    public static let districtPaletteLight: [UIColor] = districtPaletteHex.map {
        UIColor(hex: $0).withAlphaComponent(0.22)
    }
    
    public static let districtPaletteDark: [UIColor] = districtPaletteHex.map {
        UIColor(hex: $0).withAlphaComponent(0.30)
    }
    
    // MARK: - 2. Tahasil Palette (8 Distinct Cool Administrative Colors)
    public static let tahasilPaletteHex: [String] = [
        "#1E78D2", // Azure
        "#109484", // Cyan Teal
        "#22A060", // Emerald
        "#D78223", // Amber
        "#D25564", // Soft Coral
        "#875FD7", // Violet Iris
        "#329BBE", // Ocean Blue
        "#AF913C"  // Golden Sand
    ]
    
    public static let tahasilPaletteLight: [UIColor] = tahasilPaletteHex.map {
        UIColor(hex: $0).withAlphaComponent(0.20)
    }
    
    public static let tahasilPaletteDark: [UIColor] = tahasilPaletteHex.map {
        UIColor(hex: $0).withAlphaComponent(0.28)
    }
    
    // MARK: - 3. Village Palette (8 Soft Pastel Administrative Colors)
    public static let villagePaletteHex: [String] = [
        "#8CC8A0", // Pastel Green
        "#96B9E1", // Soft Sky
        "#EBB9AA", // Muted Peach
        "#E6D79B", // Pale Yellow
        "#C3AFE1", // Lavender Mist
        "#9BD2D2", // Soft Teal
        "#DCAFC3", // Rose Mauve
        "#D2C8A5"  // Linen Sand
    ]
    
    public static let villagePaletteLight: [UIColor] = villagePaletteHex.map {
        UIColor(hex: $0).withAlphaComponent(0.18)
    }
    
    public static let villagePaletteDark: [UIColor] = villagePaletteHex.map {
        UIColor(hex: $0).withAlphaComponent(0.24)
    }
    
    // MARK: - 4. Cadastral Parcel Palette (8 Deterministic Distinct Subtle Fills)
    // Ensures adjacent cadastral parcels in a village never look like a solid wall of purple
    public static let parcelPaletteHex: [String] = [
        "#3B82F6", // Light Blue
        "#F97316", // Soft Peach / Orange
        "#EAB308", // Warm Amber
        "#10B981", // Soft Emerald
        "#8B5CF6", // Lavender Violet
        "#0EA5E9", // Pale Cyan
        "#EC4899", // Soft Rose
        "#14B8A6"  // Cool Teal
    ]
    
    public static let parcelPaletteLight: [UIColor] = parcelPaletteHex.map {
        UIColor(hex: $0).withAlphaComponent(0.22)
    }
    
    public static let parcelPaletteDark: [UIColor] = parcelPaletteHex.map {
        UIColor(hex: $0).withAlphaComponent(0.28)
    }
    
    // MARK: - Deterministic Color Picker
    // Uses djb2 hash to ensure stability across redraws and sessions
    public static func deterministicColor(for identifier: String, palette: [UIColor]) -> UIColor {
        guard !palette.isEmpty else { return brandPurple }
        var hash: UInt64 = 5381
        for byte in identifier.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        let index = Int(hash % UInt64(palette.count))
        return palette[index]
    }
    
    public static func deterministicColorHex(for identifier: String, palette: [String]) -> String {
        guard !palette.isEmpty else { return brandPurpleHex }
        var hash: UInt64 = 5381
        for byte in identifier.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        let index = Int(hash % UInt64(palette.count))
        return palette[index]
    }
    
    // MARK: - White High-Contrast Cartography Design System (On Darkened Terrain)
    public static let whiteVectorStroke = UIColor(white: 1.0, alpha: 0.88)
    public static let whiteVectorFill = UIColor(white: 1.0, alpha: 0.06)
    
    public static let selectedWhiteStroke = UIColor.white
    public static let selectedWhiteFill = UIColor(white: 1.0, alpha: 0.18)
    
    public static let mutedWhiteStroke = UIColor(white: 1.0, alpha: 0.16)
    public static let mutedWhiteFill = UIColor(white: 1.0, alpha: 0.01)
    
    public static let tahasilWhiteStroke = UIColor(white: 1.0, alpha: 0.90)
    public static let tahasilWhiteFill = UIColor(white: 1.0, alpha: 0.08)
    
    public static let labelWhiteText = UIColor.white
    public static let labelDarkHalo = UIColor.black.withAlphaComponent(0.92)

    // MARK: - Selected vs Muted State Colors
    public static func selectedOutlineColor(for colorScheme: ColorScheme) -> UIColor {
        selectedWhiteStroke
    }
    
    public static func selectedFillColor(for colorScheme: ColorScheme) -> UIColor {
        selectedWhiteFill
    }
    
    public static func mutedOutlineColor(for colorScheme: ColorScheme) -> UIColor {
        mutedWhiteStroke
    }
    
    public static func mutedFillColor(for colorScheme: ColorScheme) -> UIColor {
        mutedWhiteFill
    }
}

// MARK: - UIColor Hex Extension
private extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
