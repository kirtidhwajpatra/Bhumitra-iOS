//
//  GISExplorerView.swift
//  MyBhoomi
//
//  Apple Maps-style GIS Explorer overlay with clear semantic visual hierarchy,
//  non-overlapping top navigation, and safe bottom-sheet floating above dock bar.
//

import SwiftUI
import CoreLocation

// ============================================================
// MARK: - GIS EXPLORER VIEW (APPLE MAPS-STYLE OVERLAY)
// ============================================================

public struct GISExplorerView: View {
    @ObservedObject public var viewModel: GISExplorerViewModel
    @ObservedObject public var mapViewModel: MapViewModel
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isListExpanded: Bool = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-expandList") {
            return true
        }
        #endif
        return false
    }()
    @State private var filterQuery: String = ""
    
    private var bhumitraPurple: Color {
        Theme.Color.bhumitraPrimary
    }
    
    public init(
        viewModel: GISExplorerViewModel = .shared,
        mapViewModel: MapViewModel
    ) {
        self.viewModel = viewModel
        self.mapViewModel = mapViewModel
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // 1. TOP BREADCRUMB / LOCATION TRACKER
            HStack(alignment: .center, spacing: 0) {
                breadcrumbBar
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            
            // 2. SUBTLE GLASS LOADING CAPSULE
            if case .loading(let message) = viewModel.navigationState {
                glassLoadingPill(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 3. ERROR BANNER (WITH RETRY)
            if case .error(let err) = viewModel.navigationState {
                glassErrorBar(message: err)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
            
            // 4. BOTTOM FLOATING SELECTION CARD (FOR CURRENT ADMINISTRATIVE LEVEL)
            if shouldShowSelectionDrawer {
                HStack {
                    Spacer(minLength: 0)
                    bottomSelectionCard
                        .frame(maxWidth: 320)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24) // Floats cleanly above screen bottom (FloatingDockBar is hidden)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: viewModel.currentLevel)
        .animation(.spring(response: 0.34, dampingFraction: 0.80), value: viewModel.navigationState)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isListExpanded)
        .onChange(of: viewModel.currentLevel) { newLevel in
            #if DEBUG
            if CommandLine.arguments.contains("-expandList") {
                isListExpanded = true
                filterQuery = ""
                return
            }
            #endif
            switch newLevel {
            case .subdivision:
                // Entering a Tahasil: villages do NOT have polygon boundaries on the map.
                // Automatically open the village list so the user is immediately prompted to pick or search a village!
                isListExpanded = true
            default:
                isListExpanded = false
            }
            filterQuery = ""
        }
        .onAppear {
            viewModel.setMapViewModel(mapViewModel)
            if case .subdivision = viewModel.currentLevel {
                isListExpanded = true
            }
        }
    }
    
    // MARK: - 1. Compact Liquid-Glass Breadcrumb / Location Tracker
    
    private var breadcrumbBar: some View {
        HStack(spacing: 5) {
            // Exit / Reset Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.exitExplorer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            
            // Breadcrumb path: Odisha › Keonjhar › Sadar › Village
            HStack(spacing: 2) {
                ForEach(viewModel.breadcrumbs) { item in
                    breadcrumbPill(item: item)
                    
                    if item.id != viewModel.breadcrumbs.last?.id {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraTertiaryText.opacity(0.55))
                            .padding(.horizontal, 1)
                    }
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5.5)
        .background(
            Capsule()
                .fill(Theme.Color.bhumitraMapSurface)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(
                    Capsule()
                        .stroke(Theme.Color.bhumitraBorder.opacity(0.7), lineWidth: 0.7)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        )
    }
    
    private func breadcrumbPill(item: GISBreadcrumbItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.navigateToBreadcrumb(item)
        } label: {
            Text(item.title)
                .font(.system(size: 12.5, weight: item.isCurrent ? .semibold : .medium, design: .rounded))
                .foregroundColor(
                    item.isCurrent
                        ? Theme.Color.bhumitraPrimaryText
                        : Theme.Color.bhumitraSecondaryText
                )
                .lineLimit(1)
                .padding(.horizontal, item.isCurrent ? 5 : 2)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(item.isCurrent ? Theme.Color.bhumitraPrimary.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Subtle Glass Loading Indicator
    
    private func glassLoadingPill(message: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: bhumitraPurple))
                .scaleEffect(0.85)
            
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Theme.Color.bhumitraMapSurface)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(
                    Capsule()
                        .stroke(bhumitraPurple.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - 3. Glass Error Notice
    
    private func glassErrorBar(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.Color.bhumitraWarning)
            
            Text(message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .lineLimit(1)
            
            Spacer()
            
            Button {
                if case .district(let d, _) = viewModel.currentLevel {
                    viewModel.selectDistrictByID(d.id)
                } else {
                    viewModel.resetToOdisha(forceRefresh: true)
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(bhumitraPurple)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Color.bhumitraElevatedSurface)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial))
        )
    }
    
    // MARK: - 4. Bottom Selection Card (Map-First Floating HUD)
    
    private var shouldShowSelectionDrawer: Bool {
        switch viewModel.currentLevel {
        case .odisha:
            return true
        case .district:
            return true
        case .subdivision:
            return true
        case .village:
            return false
        }
    }
    
    @ViewBuilder
    private var bottomSelectionCard: some View {
        switch viewModel.currentLevel {
        case .odisha:
            // State Level: Non-intrusive floating hint capsule to let user tap directly on the map
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text("Tap any district on the map to explore")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.75))
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
            )
            
        case .district(let d, _):
            if viewModel.tahasilGeometryAvailable && !viewModel.tahasils.isEmpty {
                // Geometry is available (Cuttack, Keonjhar) — tap on map
                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.stepBack()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Odisha")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("Tap a tahasil in \(d.name) on the map")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.75))
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
                )
            } else {
                // Geometry unavailable (other 28 districts) — dropdown card
                tahasilSelectionCard(district: d)
            }
            
        case .subdivision(let b):
            villageSelectionCard(block: b)
            
        case .village:
            EmptyView()
        }
    }
    
    // MARK: - Tahasil Selection Card (For districts without map boundaries)
    
    private func tahasilSelectionCard(district: CadastralDistrict) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            // Header: Back button + Title & Count
            HStack(spacing: 8) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.stepBack()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Odisha")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Theme.Color.bhumitraSurfaceSecondary)
                    )
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(district.name) Tahasils")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    Text(viewModel.subdivisions.isEmpty ? "Loading tahasils…" : "\(filteredSubdivisions.count) available")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                }
                
                Spacer()
            }
            
            // Ultra-simple Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                
                TextField("Search Tahasil…", text: $filterQuery)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .autocorrectionDisabled()
                
                if !filterQuery.isEmpty {
                    Button { filterQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.Color.bhumitraSurfaceSecondary)
            )
            
            // Minimalist Simple List
            if viewModel.subdivisions.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: bhumitraPurple))
                        .scaleEffect(0.85)
                    Text("Loading tahasils…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if filteredSubdivisions.isEmpty {
                HStack {
                    Spacer()
                    Text("No tahasils found")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    Spacer()
                }
                .padding(.vertical, 14)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredSubdivisions) { block in
                            subdivisionRow(block)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Color.bhumitraMapSurface)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Color.bhumitraBorder.opacity(0.8), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 3)
        )
    }
    
    // MARK: - Village Selection Card
    
    private func villageSelectionCard(block: CadastralBlock) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            // Header: Back button + Title & Count
            HStack(spacing: 8) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.stepBack()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text(viewModel.selectedDistrictFeature?.name ?? "District")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Theme.Color.bhumitraSurfaceSecondary)
                    )
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(block.name) Villages")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    Text(viewModel.villages.isEmpty ? "Loading villages…" : "\(filteredVillages.count) available")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                }
                
                Spacer()
            }
            
            // Ultra-simple Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                
                TextField("Search Village…", text: $filterQuery)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .autocorrectionDisabled()
                
                if !filterQuery.isEmpty {
                    Button { filterQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.Color.bhumitraSurfaceSecondary)
            )
            
            // Minimalist Simple List
            if viewModel.villages.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: bhumitraPurple))
                        .scaleEffect(0.85)
                    Text("Loading villages…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if filteredVillages.isEmpty {
                HStack {
                    Spacer()
                    Text("No villages found")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    Spacer()
                }
                .padding(.vertical, 14)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredVillages) { village in
                            villageRow(village)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Color.bhumitraMapSurface)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Color.bhumitraBorder.opacity(0.8), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 3)
        )
    }
    
    // MARK: - Filters
    
    private var filteredSubdivisions: [CadastralBlock] {
        if filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.subdivisions
        }
        let q = filterQuery.lowercased()
        return viewModel.subdivisions.filter { $0.name.lowercased().contains(q) }
    }
    
    private var filteredVillages: [CadastralVillage] {
        if filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.villages
        }
        let q = filterQuery.lowercased()
        return viewModel.villages.filter { $0.name.lowercased().contains(q) || $0.id.contains(q) }
    }
    
    // MARK: - Ultra-Simple Rows
    
    private func subdivisionRow(_ block: CadastralBlock) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            filterQuery = ""
            viewModel.selectSubdivision(block)
        } label: {
            HStack {
                Text(block.name)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.Color.bhumitraSurfaceSecondary.opacity(0.65))
            )
        }
        .buttonStyle(.plain)
    }
    
    private func villageRow(_ village: CadastralVillage) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            filterQuery = ""
            viewModel.selectVillage(village)
        } label: {
            HStack {
                Text(village.name)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8.5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.Color.bhumitraSurfaceSecondary.opacity(0.65))
            )
        }
        .buttonStyle(.plain)
    }
}
