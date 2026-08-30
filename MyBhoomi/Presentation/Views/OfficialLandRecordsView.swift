import SwiftUI

/// Floating Official Land Records selection card with Apple Liquid Glass aesthetic, semantic icons, and inline expandable dropdowns.
public struct OfficialLandRecordsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OfficialLandRecordsViewModel()
    @State private var selectedResultForDetail: OfficialSearchResult? = nil
    
    public var onDismiss: (() -> Void)? = nil
    public var onPlotSelected: ((OfficialSearchResult) -> Void)? = nil
    public var onShowPlotsOnMap: ((CadastralVillage) -> Void)? = nil
    
    public init(
        onDismiss: (() -> Void)? = nil,
        onPlotSelected: ((OfficialSearchResult) -> Void)? = nil,
        onShowPlotsOnMap: ((CadastralVillage) -> Void)? = nil
    ) {
        self.onDismiss = onDismiss
        self.onPlotSelected = onPlotSelected
        self.onShowPlotsOnMap = onShowPlotsOnMap
    }
    
    private func handleDismiss() {
        Theme.haptic(.light)
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    public var body: some View {
        ZStack {
            // 1. Semi-transparent backdrop over the map (tap outside to close)
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    handleDismiss()
                }
            
            // 2. Single Floating Rounded Panel over the Map
            VStack(spacing: 0) {
                // Top Header Row with Grabber and Close Button
                HStack(alignment: .center) {
                    Spacer()
                    
                    // Top Sheet Grabber Capsule
                    Capsule()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 40, height: 4)
                        .padding(.leading, Theme.Spacing.xxl)
                    
                    Spacer()
                    
                    Button(action: handleDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.Color.tertiaryText)
                    }
                    .buttonStyle(ScaledButtonStyle())
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.sm)
                
                // Scrollable Controls Body
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.sm) {
                        // 1. District Card
                        InlineDropdownCard(
                            type: .district,
                            icon: "map",
                            title: "District",
                            value: viewModel.selectedDistrict?.name.capitalized,
                            placeholder: "Select District",
                            isEnabled: true,
                            badgeText: nil,
                            isExpanded: viewModel.expandedCard == .district,
                            searchText: $viewModel.districtSearchText,
                            searchPlaceholder: "Search district",
                            items: viewModel.filteredDistricts.map {
                                DropdownItem(id: $0.id, title: $0.name.capitalized)
                            },
                            selectedID: viewModel.selectedDistrict?.id,
                            isLoading: viewModel.isLoadingDistricts,
                            onToggle: {
                                viewModel.toggleExpansion(for: .district)
                            },
                            onSelect: { item in
                                if let match = viewModel.districts.first(where: { $0.id == item.id }) {
                                    viewModel.selectDistrict(match)
                                }
                            }
                        )
                        
                        // 2. Tahasil Card
                        InlineDropdownCard(
                            type: .tahasil,
                            icon: "building.columns",
                            title: "Tahsil",
                            value: viewModel.selectedTahasil?.name.capitalized,
                            placeholder: viewModel.selectedDistrict == nil ? "Select District first" : (viewModel.isLoadingTahasils ? "Loading..." : "Select Tahsil"),
                            isEnabled: viewModel.selectedDistrict != nil && !viewModel.isLoadingTahasils,
                            badgeText: viewModel.selectedDistrict != nil && viewModel.selectedTahasil == nil && !viewModel.tahasils.isEmpty ? "\(viewModel.tahasils.count)+" : nil,
                            isExpanded: viewModel.expandedCard == .tahasil,
                            searchText: $viewModel.tahasilSearchText,
                            searchPlaceholder: "Search tahasil",
                            items: viewModel.filteredTahasils.map {
                                DropdownItem(id: $0.id, title: $0.name.capitalized)
                            },
                            selectedID: viewModel.selectedTahasil?.id,
                            isLoading: viewModel.isLoadingTahasils,
                            onToggle: {
                                viewModel.toggleExpansion(for: .tahasil)
                            },
                            onSelect: { item in
                                if let match = viewModel.tahasils.first(where: { $0.id == item.id }) {
                                    viewModel.selectTahasil(match)
                                }
                            }
                        )
                        
                        // 3. Panchayat Card
                        InlineDropdownCard(
                            type: .panchayat,
                            icon: "person.3",
                            title: "Panchayat",
                            value: viewModel.selectedPanchayat?.name,
                            placeholder: viewModel.selectedTahasil == nil ? "Select Tahsil first" : (viewModel.isLoadingPanchayats ? "Loading..." : (viewModel.panchayats.isEmpty ? "All Panchayats" : "Select Panchayat")),
                            isEnabled: viewModel.selectedTahasil != nil && !viewModel.isLoadingPanchayats && !viewModel.panchayats.isEmpty,
                            badgeText: nil,
                            isExpanded: viewModel.expandedCard == .panchayat,
                            searchText: $viewModel.panchayatSearchText,
                            searchPlaceholder: "Search panchayat",
                            items: viewModel.filteredPanchayats.map {
                                DropdownItem(id: $0.id, title: $0.name)
                            },
                            selectedID: viewModel.selectedPanchayat?.id,
                            isLoading: viewModel.isLoadingPanchayats,
                            onToggle: {
                                viewModel.toggleExpansion(for: .panchayat)
                            },
                            onSelect: { item in
                                if let match = viewModel.panchayats.first(where: { $0.id == item.id }) {
                                    viewModel.selectPanchayat(match)
                                }
                            }
                        )
                        
                        // 4. Village Card
                        InlineDropdownCard(
                            type: .village,
                            icon: UIImage(systemName: "house.and.flag") != nil ? "house.and.flag" : "house",
                            title: "Village",
                            value: viewModel.selectedVillage?.name,
                            placeholder: viewModel.selectedTahasil == nil ? "Select Tahsil first" : (viewModel.isLoadingVillages ? "Loading..." : "Select Village"),
                            isEnabled: viewModel.selectedTahasil != nil && !viewModel.isLoadingVillages,
                            badgeText: nil,
                            isExpanded: viewModel.expandedCard == .village,
                            searchText: $viewModel.villageSearchText,
                            searchPlaceholder: "Search village",
                            items: viewModel.filteredVillages.map {
                                DropdownItem(id: $0.id, title: $0.name)
                            },
                            selectedID: viewModel.selectedVillage?.id,
                            isLoading: viewModel.isLoadingVillages,
                            onToggle: {
                                viewModel.toggleExpansion(for: .village)
                            },
                            onSelect: { item in
                                if let match = viewModel.villages.first(where: { $0.id == item.id }) {
                                    viewModel.selectVillage(match)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.lg)
                }
                
                // Bottom Fixed Action Bar
                HStack(alignment: .center) {
                    // Reset all
                    Button(action: {
                        Theme.haptic(.light)
                        withAnimation(Theme.Animation.spring) {
                            viewModel.resetAll()
                        }
                    }) {
                        Text("Reset all")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.glass)
                    .clipShape(Capsule())
                    .accessibilityLabel("Reset all selections")
                    
                    Spacer()
                    
                    showPlotsButton
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.sm)
                .background(
                    Theme.Color.surface.opacity(0.92)
                        .background(.ultraThinMaterial)
                        .shadow(color: Theme.Shadow.subtle, radius: 8, x: 0, y: -2)
                )
            }
            .liquidGlassCard(tint: Theme.Color.primary, radius: Theme.Radius.card, isEmphasized: viewModel.isSelectionComplete)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.section)
            .padding(.bottom, Theme.Spacing.md)
        }
        .fullScreenCover(item: $selectedResultForDetail) { result in
            LandPassportDetailView(result: result)
        }
    }
    
    private var canShowPlots: Bool {
        viewModel.isSelectionComplete || viewModel.selectedVillage != nil
    }
    
    private var showPlotsButton: some View {
        Button(action: handleShowPlots) {
            HStack(spacing: Theme.Spacing.xs) {
                Text("Show Plots")
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .buttonStyle(.glassProminent)
        .tint(.accentColor)
        .clipShape(Capsule())
        .disabled(!canShowPlots)
        .opacity(canShowPlots ? 1.0 : 0.55)
        .accessibilityLabel("Show Plots for selected location")
    }
    
    private func handleShowPlots() {
        Theme.haptic(.medium)
        guard let village = viewModel.selectedVillage else { return }
        
        let resolved = CadastralVillage(
            id: village.id,
            name: village.name,
            gpID: viewModel.selectedPanchayat?.id ?? village.gpID,
            blockID: viewModel.selectedTahasil?.id ?? village.blockID,
            districtID: viewModel.selectedDistrict?.id ?? village.districtID,
            blockName: viewModel.selectedTahasil?.name,
            districtName: viewModel.selectedDistrict?.name
        )
        
        if let onShowPlotsOnMap = onShowPlotsOnMap {
            onShowPlotsOnMap(resolved)
        }
    }
}

// MARK: - Dropdown Item Model

struct DropdownItem: Identifiable, Hashable {
    let id: String
    let title: String
}

// MARK: - Inline Expandable Dropdown Glass Card

struct InlineDropdownCard: View {
    let type: LocationPickerType
    let icon: String
    let title: String
    let value: String?
    let placeholder: String
    let isEnabled: Bool
    let badgeText: String?
    let isExpanded: Bool
    @Binding var searchText: String
    let searchPlaceholder: String
    let items: [DropdownItem]
    let selectedID: String?
    let isLoading: Bool
    let onToggle: () -> Void
    let onSelect: (DropdownItem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Collapsed Row Header (Height ~72pt)
            Button(action: {
                guard isEnabled else { return }
                Theme.haptic(.light)
                withAnimation(Theme.Animation.spring) {
                    onToggle()
                }
            }) {
                HStack(spacing: Theme.Spacing.md) {
                    // Semantic Rounded Icon Box (44x44pt)
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                            .fill(value != nil ? Theme.Color.primaryLight : Color(white: 0.94))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(value != nil ? Theme.Color.primary : Theme.Color.secondaryText)
                    }
                    
                    // Title and Selected Value
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(Theme.Typography.captionMedium)
                            .foregroundColor(Theme.Color.secondaryText)
                        
                        if let val = value, !val.isEmpty {
                            Text(val)
                                .font(Theme.Typography.primaryBodyBold)
                                .foregroundColor(Theme.Color.primaryText)
                                .lineLimit(1)
                        } else {
                            Text(placeholder)
                                .font(Theme.Typography.secondaryBody)
                                .foregroundColor(Theme.Color.tertiaryText)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.85)
                            .padding(.trailing, 2)
                    } else if let badge = badgeText {
                        Text(badge)
                            .font(Theme.Typography.captionMedium)
                            .foregroundColor(Theme.Color.primary)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .padding(.vertical, 3)
                            .background(Theme.Color.primaryLight)
                            .clipShape(Capsule())
                    }
                    
                    // Chevron Indicator (Smoothly rotates 180° on expansion)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isEnabled ? Theme.Color.secondaryText : Theme.Color.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .frame(minHeight: 70)
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaledButtonStyle())
            .disabled(!isEnabled)
            
            // Expanded List View (Spring transition inline)
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, Theme.Spacing.md)
                    
                    // Integrated Search Bar inside Card
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Color.tertiaryText)
                        
                        TextField(searchPlaceholder, text: $searchText)
                            .font(Theme.Typography.secondaryBody)
                            .autocorrectionDisabled(true)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                Theme.haptic(.light)
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Color.tertiaryText)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Color.black.opacity(0.03))
                    
                    Divider()
                    
                    // Filtered List of Items (Max Height 220pt)
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if items.isEmpty {
                                Text("No items available")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Color.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.Spacing.lg)
                            } else {
                                ForEach(items) { item in
                                    DropdownRowView(
                                        title: item.title,
                                        isSelected: item.id == selectedID,
                                        onTap: {
                                            handleItemSelection(item)
                                        }
                                    )
                                    
                                    if item.id != items.last?.id {
                                        Divider()
                                            .padding(.leading, Theme.Spacing.md)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .liquidGlassCard(tint: value == nil ? Theme.Color.indigo : Theme.Color.primary, radius: Theme.Radius.card, isEmphasized: isExpanded || value != nil)
        .opacity(isEnabled ? 1.0 : 0.55)
    }
    
    private func handleItemSelection(_ item: DropdownItem) {
        Theme.selectionHaptic()
        withAnimation(Theme.Animation.spring) {
            onSelect(item)
        }
    }
}

// MARK: - Dedicated Dropdown Row View

struct DropdownRowView: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(isSelected ? Theme.Typography.secondaryBodyMedium.weight(.bold) : Theme.Typography.secondaryBody)
                    .foregroundColor(isSelected ? Theme.Color.primary : Theme.Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.Color.primary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? Theme.Color.primaryLight : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaledButtonStyle())
    }
}
