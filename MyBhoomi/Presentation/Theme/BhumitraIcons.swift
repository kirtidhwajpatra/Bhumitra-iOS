//
//  BhumitraIcons.swift
//  MyBhoomi
//
//  Razor-Sharp Subpixel Vector Icon Suite matching Figma Screen node 1114:769.
//  Colors: Primary Electric Purple (#7600FF), Yellow Accent (#FFE100), and Contrast Accents.
//  Features consistent circular containers, optical centering, and infinite vector sharpness.
//

import SwiftUI

public enum BhumitraIcon {
    
    // MARK: - Circular Plate Background
    private struct CirclePlate: View {
        let size: CGFloat
        @Environment(\.colorScheme) private var colorScheme
        
        private var isDark: Bool {
            if let explicit = AppearanceManager.shared.colorScheme {
                return explicit == .dark
            }
            return colorScheme == .dark
        }
        
        var body: some View {
            Circle()
                .fill(isDark ? Color(hex: "#282834") : Color(hex: "#E7E7E7"))
                .overlay(
                    Circle()
                        .stroke(isDark ? Color.white.opacity(0.08) : Color.clear, lineWidth: 0.5)
                )
                .frame(width: size, height: size)
        }
    }
    
    // MARK: - 1. Find Land (Person inside circular container)
    public struct FindLand: View {
        public var size: CGFloat
        
        public init(size: CGFloat = 36) {
            self.size = size
        }
        
        public var body: some View {
            ZStack {
                CirclePlate(size: size)
                
                Image("IconFindLandPerson")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.72, height: size * 0.75)
            }
            .frame(width: size, height: size)
        }
    }
    
    // MARK: - 2. Land Record (Folded Document inside circular container)
    public struct LandRecord: View {
        public var size: CGFloat
        
        public init(size: CGFloat = 36) {
            self.size = size
        }
        
        public var body: some View {
            ZStack {
                CirclePlate(size: size)
                
                Image("IconLandRecordDoc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.68, height: size * 0.80)
            }
            .frame(width: size, height: size)
        }
    }
    
    // MARK: - 3. Govt Value (Cash Banknotes inside circular container)
    public struct GovtValue: View {
        public var size: CGFloat
        
        public init(size: CGFloat = 36) {
            self.size = size
        }
        
        public var body: some View {
            ZStack {
                CirclePlate(size: size)
                
                Image("IconGovtValueCash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.95, height: size * 0.58)
            }
            .frame(width: size, height: size)
        }
    }
    
    // MARK: - 4. Regd Cost (Checkmark inside circular container)
    public struct RegdCost: View {
        public var size: CGFloat
        
        public init(size: CGFloat = 36) {
            self.size = size
        }
        
        public var body: some View {
            ZStack {
                CirclePlate(size: size)
                
                Image("IconRegdCostCheck")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.75, height: size * 0.75)
            }
            .frame(width: size, height: size)
        }
    }
    
    // MARK: - 5. Detailed Report (Magnifying Glass)
    public struct DetailedReport: View {
        public var size: CGFloat
        
        public init(size: CGFloat = 35) {
            self.size = size
        }
        
        public var body: some View {
            Image("IconDetailedReportMagnifier")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }
}

