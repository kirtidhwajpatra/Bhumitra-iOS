//
//  FloatingDockBar.swift
//  MyBhoomi
//
//  Figma Pixel-Perfect Implementation of Floating Bottom Dock (Node ID: 772:531)
//

import SwiftUI

public enum AppTab: Int, CaseIterable, Identifiable {
    case home = 0
    case map = 1
    case saved = 2
    case share = 3
    
    public var id: Int { rawValue }
    
    public var iconName: String {
        switch self {
        case .home: return "DockIconHome"
        case .map: return "DockIconMap"
        case .saved: return "DockIconSave"
        case .share: return "DockIconShare"
        }
    }
}

public struct FloatingDockBar: View {
    @Binding public var selectedTab: AppTab
    public var onShareTap: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Outer dock dimensions engineered for 100% concentric alignment with inner circular cards
    private let dockHeight: CGFloat = 66.0
    private let circleSize: CGFloat = 58.0
    private let itemSpacing: CGFloat = 12.0
    private let edgePadding: CGFloat = 4.0
    
    // Total width = edgePadding(4) + 4 * circleSize(58) + 3 * itemSpacing(12) + edgePadding(4) = 276.0 pt
    private var totalDockWidth: CGFloat {
        (edgePadding * 2) + (circleSize * 4) + (itemSpacing * 3)
    }
    
    // Touch column width for each of the 4 tabs
    private var tabTouchWidth: CGFloat {
        (totalDockWidth - (edgePadding * 2)) / 4.0
    }
    
    // Real-time drag gesture tracking state
    @State private var isDragging: Bool = false
    @State private var dragPositionX: CGFloat = 0.0
    @State private var hoveredTabIndex: Int = 0
    
    public init(
        selectedTab: Binding<AppTab>,
        onShareTap: (() -> Void)? = nil
    ) {
        self._selectedTab = selectedTab
        self.onShareTap = onShareTap
    }
    
    // Computed center X position for a given tab index (relative to dock leading edge)
    private func centerPosition(for index: Int) -> CGFloat {
        edgePadding + (CGFloat(index) * tabTouchWidth) + (tabTouchWidth / 2.0)
    }
    
    // Current indicator center X (tracks finger 1:1 during drag, or rests at selectedTab)
    private var currentIndicatorCenterX: CGFloat {
        let minX = centerPosition(for: 0)
        let maxX = centerPosition(for: 3)
        if isDragging {
            return min(max(dragPositionX, minX), maxX)
        } else {
            return centerPosition(for: selectedTab.rawValue)
        }
    }
    
    // Find closest tab index from an X coordinate
    private func closestTabIndex(for x: CGFloat) -> Int {
        let rawIndex = Int(round((x - edgePadding - (tabTouchWidth / 2.0)) / tabTouchWidth))
        return min(max(rawIndex, 0), 3)
    }
    
    // Outer dock surface tint matching Apple Liquid Glass controls
    private var dockSurfaceTint: Color {
        colorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.90)
    }
    
    // Adaptive fill for active button circle
    private var circleFillColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.22)
        } else {
            return Color.white
        }
    }
    
    // Adaptive glass tint for active button circle
    private var circleGlassTint: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.18)
        } else {
            return Color.white.opacity(0.45)
        }
    }
    
    public var body: some View {
        ZStack(alignment: .leading) {
            // 1. Dock Background Pill - Apple Native Ultra-Thin Liquid Glass (Single seamless rim, no double-edge glitch)
            Capsule()
                .fill(.ultraThinMaterial)
                .glassEffect(
                    .regular.tint(dockSurfaceTint).interactive(),
                    in: .capsule
                )
                .frame(width: totalDockWidth, height: dockHeight)
            
            // 2. Sliding / Dragging Apple Native Liquid Glass Indicator Circle (Harmonious in Light & Dark Mode)
            Circle()
                .fill(circleFillColor)
                .glassEffect(
                    .regular.tint(circleGlassTint).interactive(),
                    in: .circle
                )
                .frame(width: circleSize, height: circleSize)
                // Apple Liquid Glass dynamic interactive expansion on touch/press
                .scaleEffect(isDragging ? 1.15 : 1.0)
                // Position tracks finger 1:1 during drag, or spring animates on selection change
                .position(x: currentIndicatorCenterX, y: dockHeight / 2.0)
                .animation(isDragging ? nil : .spring(response: 0.36, dampingFraction: 0.65), value: selectedTab)
                .animation(.spring(response: 0.24, dampingFraction: 0.60), value: isDragging)
            
            // 3. 4 Tab Icons (Interactive tap & drag hit-testing layer)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    let isHighlighted = isDragging ? (hoveredTabIndex == tab.rawValue) : (selectedTab == tab)
                    
                    VStack {
                        Image(tab.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: tab == .map ? 38 : 31,
                                height: tab == .map ? 31 : 31
                            )
                            .scaleEffect(isHighlighted ? (isDragging ? 1.15 : 1.08) : 0.94)
                            .grayscale(isHighlighted ? 0.0 : 1.0)
                            .opacity(isHighlighted ? 1.0 : 0.38)
                            .animation(.spring(response: 0.24, dampingFraction: 0.65), value: isHighlighted)
                    }
                    .frame(width: tabTouchWidth, height: dockHeight)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, edgePadding)
            .frame(width: totalDockWidth, height: dockHeight)
        }
        .frame(width: totalDockWidth, height: dockHeight)
        // Continuous Smooth Drag & Tap Gesture (Never snaps until user releases finger)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        hoveredTabIndex = closestTabIndex(for: value.location.x)
                    }
                    
                    // Directly track finger position without premature state resets
                    dragPositionX = value.location.x
                    
                    let newHoverIndex = closestTabIndex(for: dragPositionX)
                    if newHoverIndex != hoveredTabIndex {
                        hoveredTabIndex = newHoverIndex
                    }
                }
                .onEnded { value in
                    let finalIndex = closestTabIndex(for: value.location.x)
                    
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.65)) {
                        isDragging = false
                        dragPositionX = centerPosition(for: finalIndex)
                        if let finalTab = AppTab(rawValue: finalIndex) {
                            selectedTab = finalTab
                            hoveredTabIndex = finalIndex
                            if finalTab == .share, let onShare = onShareTap {
                                onShare()
                            }
                        }
                    }
                }
        )
        .onAppear {
            hoveredTabIndex = selectedTab.rawValue
            dragPositionX = centerPosition(for: selectedTab.rawValue)
        }
        .onChange(of: selectedTab) { newTab in
            if !isDragging {
                hoveredTabIndex = newTab.rawValue
                dragPositionX = centerPosition(for: newTab.rawValue)
            }
        }
    }
}
