//
//  SavedLandsView.swift
//  MyBhoomi
//
//  Redesigned Saved Lands Screen with:
//  - Top navigation bar with circular back button and "Saved Lands" header + count subtitle
//  - Home-style dynamic search indicator for real-time plot/village filtering
//  - Horizontal cards styled with signature Apple Liquid Glass (frosted material, rim highlight, depth shadow)
//  - High-definition satellite map thumbnails with purple plot polygon highlights
//  - Interactive swipe-to-reveal delete gesture and bookmark tap removal
//

import SwiftUI

public struct SavedLandsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var savedManager = SavedLandManager.shared
    @ObservedObject private var navManager = AppNavigationManager.shared
    
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedRecordForDetail: SavedLandRecord? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var recordToDelete: SavedLandRecord? = nil
    
    // Theme Colors
    private let electricPurple = Color(hex: "#7600FF")
    private var subtitleColor: Color {
        Theme.Color.dynamic(
            light: Color(red: 100 / 255, green: 100 / 255, blue: 110 / 255),
            dark: Color(red: 160 / 255, green: 160 / 255, blue: 175 / 255)
        )
    }
    private var pillBorderColor: Color {
        Theme.Color.dynamic(
            light: Color(hex: "#7600FF").opacity(0.35),
            dark: Color(hex: "#AF52FF").opacity(0.40)
        )
    }
    private var pillBackground: Color {
        Theme.Color.dynamic(
            light: Color(hex: "#7600FF").opacity(0.08),
            dark: Color(hex: "#7600FF").opacity(0.20)
        )
    }
    
    // Filtered Saved Records based on search query
    private var filteredRecords: [SavedLandRecord] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return savedManager.savedRecords
        }
        return savedManager.savedRecords.filter { r in
            r.plotNumber.lowercased().contains(q) ||
            r.villageName.lowercased().contains(q) ||
            r.districtName.lowercased().contains(q) ||
            r.tahasilName.lowercased().contains(q) ||
            r.khatianNumber.lowercased().contains(q) ||
            (r.customTag?.lowercased().contains(q) ?? false)
        }
    }
    
    public var onDismiss: (() -> Void)? = nil
    
    public init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Canvas Background
            Theme.Color.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Top Navigation Bar (Back button, Title, Subtitle count)
                topNavBar
                
                if savedManager.savedRecords.isEmpty {
                    emptyStateView
                } else {
                    // 2. Search Indicator (Identical to HomeScreenView design)
                    searchBarView
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                    
                    if filteredRecords.isEmpty {
                        noSearchResultsView
                    } else {
                        // 3. Saved Lands Cards Scrollable List
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredRecords) { record in
                                    SwipeableSavedLandCard(
                                        onDelete: {
                                            recordToDelete = record
                                            showDeleteConfirmation = true
                                        }
                                    ) {
                                        savedLandCard(record: record)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 6)
                            .padding(.bottom, 120)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedRecordForDetail) { record in
            LandPassportDetailView(
                result: record.toSearchResult,
                selectedBoundary: record.boundary ?? []
            )
        }
        .confirmSheet(
            isPresented: $showDeleteConfirmation,
            icon: "bookmark.slash",
            title: "Remove saved land?",
            message: "It's removed from your saved lands on this device. You can save it again anytime.",
            context: recordToDelete.map { "Plot \($0.plotNumber) · \($0.villageName)" },
            confirmTitle: "Remove"
        ) {
            if let target = recordToDelete {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    savedManager.remove(recordID: target.id)
                }
                recordToDelete = nil
            }
        }
    }
    
    // MARK: - 1. Top Navigation Bar
    
    private var topNavBar: some View {
        HStack(spacing: 12) {
            // Circular Liquid Glass Back Button
            LiquidGlassBackButton(
                diameter: 42,
                iconSize: 16,
                accessibilityLabel: "Back"
            ) {
                onDismiss?()
                dismiss()
            }
            
            // Header with Plot Count Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text("Saved Lands")
                    .font(.stackSansHeadline(size: 26, weight: .bold))
                    .foregroundColor(Theme.Color.primaryText)
                
                let count = savedManager.savedRecords.count
                Text("\(count) \(count == 1 ? "property" : "properties") saved")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(subtitleColor)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
    
    // MARK: - 2. Search Bar View (Matching HomeScreenView Styling)
    
    private var searchBarView: some View {
        HStack(spacing: 8) {
            TextField("Search saved plots, village...", text: $searchText)
                .font(.stackSansHeadline(size: 17, weight: .regular))
                .foregroundColor(colorScheme == .dark ? Color(hex: "#F0F6FC") : Color(hex: "#202020"))
                .focused($isSearchFocused)
                .submitLabel(.search)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "#9E9E9E"))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? Color(hex: "#8B949E") : Color(hex: "#747474"))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isSearchFocused
                        ? Color(hex: "#7600FF").opacity(0.6)
                        : (colorScheme == .dark ? Color.white.opacity(0.16) : Color(hex: "#E5E5E5")),
                    lineWidth: 1.5
                )
        )
    }
    
    // MARK: - 3. Saved Land Card (Liquid Glass Horizontal Layout)
    
    private func savedLandCard(record: SavedLandRecord) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Left: Map View / Satellite Thumbnail with Highlighted Plot Polygon
            PlotMapThumbnailView(record: record, size: 104)
            
            // Right: Plot Details
            VStack(alignment: .leading, spacing: 4) {
                // Top Row: PLOT NUMBER (Left) & Bookmark Icon (Right)
                HStack(alignment: .center) {
                    Text("PLOT \(record.plotNumber)")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(electricPurple)
                        .tracking(0.6)
                    
                    Spacer()
                    
                    Button {
                        recordToDelete = record
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(electricPurple)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove Plot \(record.plotNumber) from saved")
                }
                
                // Village Name (Bold Title, Line Limit 2)
                Text(record.villageName.capitalized)
                    .font(.stackSansHeadline(size: 18.5, weight: .bold))
                    .foregroundColor(Theme.Color.primaryText)
                    .lineLimit(2)
                    .padding(.top, 1)
                
                // Location Subtitle: Pin + tahasil, district
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(electricPurple)
                    
                    Text("\(record.tahasilName), \(record.districtName)".lowercased())
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(subtitleColor)
                        .lineLimit(1)
                }
                .padding(.top, 2)
                
                Spacer(minLength: 4)
                
                // Bottom Row: "View details →" Pill Button
                HStack {
                    Spacer()
                    
                    Button {
                        selectedRecordForDetail = record
                    } label: {
                        HStack(spacing: 4) {
                            Text("View details")
                                .font(.system(size: 12.5, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(electricPurple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(pillBackground)
                        )
                        .overlay(
                            Capsule()
                                .stroke(pillBorderColor, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(ScaledButtonStyle())
                }
            }
        }
        .padding(14)
        .background {
            let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
            ZStack {
                // Solid surface background matching app theme to eliminate any background bleed-through
                shape.fill(colorScheme == .dark ? Color(hex: "#161B22") : Color.white)
                shape.fill(.ultraThinMaterial)
                shape.fill(
                    LinearGradient(
                        colors: [
                            electricPurple.opacity(colorScheme == .dark ? 0.10 : 0.05),
                            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.25),
                            electricPurple.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(colorScheme == .dark ? 0.14 : 0.55), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .padding(1)
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.35 : 0.85),
                            electricPurple.opacity(0.25),
                            .white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 14, x: 0, y: 6)
            .shadow(color: electricPurple.opacity(colorScheme == .dark ? 0.14 : 0.04), radius: 8, x: 0, y: 2)
        }
    }
    
    // MARK: - 4. No Search Results State
    
    private var noSearchResultsView: some View {
        VStack(spacing: 14) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(subtitleColor)
            
            Text("No Plots Found")
                .font(.stackSansHeadline(size: 18, weight: .bold))
                .foregroundColor(Theme.Color.primaryText)
            
            Text("No saved lands match \"\(searchText)\". Check plot number, village, or district spelling.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(subtitleColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            
            Button {
                searchText = ""
            } label: {
                Text("Clear Search")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(electricPurple)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(pillBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(pillBorderColor, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            
            Spacer()
        }
        .padding(.bottom, 80)
    }
    
    // MARK: - 5. Empty State View (Zero Saved Lands)
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.70))
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(pillBorderColor, lineWidth: 1)
                    )
                
                Image(systemName: "bookmark")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(electricPurple)
            }
            
            VStack(spacing: 8) {
                Text("No Saved Lands Yet")
                    .font(.stackSansHeadline(size: 22, weight: .bold))
                    .foregroundColor(Theme.Color.primaryText)
                
                Text("Tap the bookmark button on any plot or cadastral map details to store official land records securely on your device for instant offline access.")
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundColor(subtitleColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }
            
            Button {
                onDismiss?()
                dismiss()
                navManager.navigate(to: .map)
            } label: {
                Text("Explore Map")
                    .font(.stackSansHeadline(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(electricPurple)
                    .clipShape(Capsule())
                    .shadow(color: electricPurple.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.bottom, 60)
    }
}

// MARK: - Interactive Swipe-To-Reveal Container

private struct SwipeableSavedLandCard<Content: View>: View {
    let onDelete: () -> Void
    let content: Content
    
    @State private var offset: CGFloat = 0
    private let actionWidth: CGFloat = 80
    
    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete Action Surface behind the card
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    offset = 0
                }
                onDelete()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 235 / 255, green: 53 / 255, blue: 53 / 255))
                    
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Delete")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: actionWidth)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
            .opacity(offset < -5 ? 1 : 0)
            
            // Foreground Card
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .local)
                        .onChanged { value in
                            let translation = value.translation.width
                            if translation < 0 {
                                // Dragging left - rubber-band past reveal width
                                if translation < -actionWidth {
                                    let extra = translation + actionWidth
                                    offset = -actionWidth + (extra * 0.35)
                                } else {
                                    offset = translation
                                }
                            } else if offset < 0 {
                                // Dragging right to dismiss
                                offset = min(0, -actionWidth + translation)
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            let velocity = value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                if translation < -actionWidth * 0.6 || velocity < -100 {
                                    offset = -actionWidth - 8
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
                .onTapGesture {
                    if offset < 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            offset = 0
                        }
                    }
                }
        }
    }
}

#Preview {
    SavedLandsView()
}
