import SwiftUI

/// Floating Official Land Records selection card with Apple Liquid Glass aesthetic and inline expandable dropdowns.
public struct OfficialLandRecordsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OfficialLandRecordsViewModel()
    @State private var selectedResultForDetail: OfficialSearchResult? = nil
    @State private var isPressingShowPlots: Bool = false
    
    public var onPlotSelected: ((OfficialSearchResult) -> Void)? = nil
    
    public init(onPlotSelected: ((OfficialSearchResult) -> Void)? = nil) {
        self.onPlotSelected = onPlotSelected
    }
    
    public var body: some View {
        ZStack {
            // Liquid Glass Soft Gradient Sheet Background
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.98, green: 0.98, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Sheet Content Container
            VStack(spacing: 0) {
                // Top Sheet Drag Grabber
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 38, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                
                // Header Bar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Official Land Records")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Search Odisha land records directly")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        hapticFeedback(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.black.opacity(0.2))
                    }
                    .buttonStyle(ScaledButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)
                
                // Scrollable Controls Body
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // 1. District Card
                        InlineDropdownCard(
                            type: .district,
                            icon: "calendar",
                            title: "District",
                            value: viewModel.selectedDistrict?.officialName.capitalized,
                            placeholder: "Select District",
                            isEnabled: true,
                            badgeText: nil,
                            isExpanded: viewModel.expandedCard == .district,
                            searchText: $viewModel.districtSearchText,
                            searchPlaceholder: "Search district",
                            items: viewModel.filteredDistricts.map {
                                DropdownItem(id: $0.id, title: $0.officialName.capitalized)
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
                            icon: "person.2.fill",
                            title: "Tahsil",
                            value: viewModel.selectedTahasil?.officialName.capitalized,
                            placeholder: viewModel.selectedDistrict == nil ? "Select District first" : "Select Tahsil",
                            isEnabled: viewModel.selectedDistrict != nil,
                            badgeText: viewModel.selectedDistrict != nil && viewModel.selectedTahasil == nil ? "12+" : nil,
                            isExpanded: viewModel.expandedCard == .tahasil,
                            searchText: $viewModel.tahasilSearchText,
                            searchPlaceholder: "Search tahasil",
                            items: viewModel.filteredTahasils.map {
                                DropdownItem(id: $0.id, title: $0.officialName.capitalized)
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
                            icon: "clock.fill",
                            title: "Panchayat",
                            value: viewModel.selectedPanchayat?.name,
                            placeholder: viewModel.selectedTahasil == nil ? "Select Tahsil first" : (viewModel.panchayats.isEmpty ? "All Panchayats" : "Select Panchayat"),
                            isEnabled: viewModel.selectedTahasil != nil && !viewModel.panchayats.isEmpty,
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
                            icon: "music.note.list",
                            title: "Village",
                            value: viewModel.selectedVillage?.officialName,
                            placeholder: viewModel.selectedTahasil == nil ? "Select Tahsil first" : "Select Village",
                            isEnabled: viewModel.selectedTahasil != nil,
                            badgeText: nil,
                            isExpanded: viewModel.expandedCard == .village,
                            searchText: $viewModel.villageSearchText,
                            searchPlaceholder: "Search village",
                            items: viewModel.filteredVillages.map {
                                DropdownItem(id: $0.id, title: $0.officialName)
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
                        
                        // 5. Plots Search & Results Section (When Plots Visible or Selection Complete)
                        if viewModel.isPlotsSectionVisible || viewModel.isSelectionComplete {
                            VStack(alignment: .leading, spacing: 12) {
                                // Mode Segmented Bar
                                HStack(spacing: 6) {
                                    ForEach(LandRecordSearchMode.allCases) { mode in
                                        Button(action: {
                                            hapticFeedback(.light)
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                viewModel.searchMode = mode
                                            }
                                        }) {
                                            Text(mode.rawValue)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(viewModel.searchMode == mode ? .white : .black.opacity(0.75))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(viewModel.searchMode == mode ? Theme.myBhoomiBlue : Color.black.opacity(0.04))
                                                )
                                        }
                                        .buttonStyle(ScaledButtonStyle())
                                    }
                                }
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
                                )
                                
                                // Search Input Box
                                HStack(spacing: 10) {
                                    TextField(
                                        viewModel.searchMode == .plot ? "Enter plot number (e.g. 489)" : "Enter khatian number",
                                        text: $viewModel.searchQuery
                                    )
                                    .font(.system(size: 14))
                                    .keyboardType(viewModel.searchMode == .plot ? .numbersAndPunctuation : .default)
                                    .autocorrectionDisabled(true)
                                    .onSubmit {
                                        viewModel.executeSearch()
                                    }
                                    
                                    if !viewModel.searchQuery.isEmpty {
                                        Button(action: { viewModel.searchQuery = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 15))
                                                .foregroundColor(Color.black.opacity(0.3))
                                        }
                                    }
                                    
                                    // Search Go Button
                                    Button(action: {
                                        hapticFeedback(.medium)
                                        viewModel.executeSearch()
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.black.opacity(0.08) : Theme.myBhoomiBlue)
                                                .frame(width: 32, height: 32)
                                            
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSearching)
                                    .buttonStyle(ScaledButtonStyle())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                                )
                                
                                // Results / State
                                if viewModel.isSearching {
                                    HStack(spacing: 10) {
                                        ProgressView().tint(Theme.myBhoomiBlue)
                                        Text("Searching official records...")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                } else if viewModel.isNoRecordFound {
                                    Text("No record found matching \"\(viewModel.searchedQuery)\".")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                } else if let err = viewModel.searchError {
                                    Text(err)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 4)
                                } else if !viewModel.searchResults.isEmpty {
                                    ForEach(viewModel.searchResults) { result in
                                        Button(action: {
                                            hapticFeedback(.light)
                                            selectedResultForDetail = result
                                            onPlotSelected?(result)
                                        }) {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(viewModel.searchMode == .plot ? "Plot \(result.plotNumber)" : "Khatian \(result.khatianNumber)")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(Theme.myBhoomiBlue)
                                                    
                                                    Text(viewModel.searchMode == .plot ? "Khatian \(result.khatianNumber)" : "Plot \(result.plotNumber)")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "doc.text.magnifyingglass")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(Theme.myBhoomiBlue.opacity(0.8))
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                                            )
                                        }
                                        .buttonStyle(ScaledButtonStyle())
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                
                // Bottom Fixed Action Bar
                HStack {
                    // Reset all
                    Button(action: {
                        hapticFeedback(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.resetAll()
                        }
                    }) {
                        Text("Reset all")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.myBhoomiBlue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                    }
                    
                    Spacer()
                    
                    // Show Plots CTA
                    Button(action: {
                        hapticFeedback(.medium)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.isPlotsSectionVisible = true
                        }
                        if viewModel.searchQuery.isEmpty {
                            viewModel.searchQuery = "489"
                        }
                        viewModel.executeSearch()
                    }) {
                        HStack(spacing: 10) {
                            Text("Show Plots")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.myBhoomiBlue)
                            }
                        }
                        .padding(.leading, 18)
                        .padding(.trailing, 8)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Theme.myBhoomiBlue)
                                .shadow(color: Theme.myBhoomiBlue.opacity(viewModel.isSelectionComplete ? 0.4 : 0.15), radius: viewModel.isSelectionComplete ? 10 : 4, x: 0, y: 3)
                        )
                        .scaleEffect(isPressingShowPlots ? 0.96 : 1.0)
                    }
                    .disabled(!viewModel.isSelectionComplete && viewModel.selectedVillage == nil)
                    .opacity((viewModel.isSelectionComplete || viewModel.selectedVillage != nil) ? 1.0 : 0.5)
                    .buttonStyle(ScaledButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(
                    Color.white.opacity(0.9)
                        .background(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: -2)
                )
            }
        }
        .sheet(item: $selectedResultForDetail) { result in
            KhatianDetailView(result: result)
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
    var badgeText: String? = nil
    let isExpanded: Bool
    @Binding var searchText: String
    let searchPlaceholder: String
    let items: [DropdownItem]
    let selectedID: String?
    let isLoading: Bool
    let onToggle: () -> Void
    let onSelect: (DropdownItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Card Row Header
            Button(action: {
                if isEnabled {
                    hapticFeedback(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        onToggle()
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.myBhoomiBlue)
                        .frame(width: 22, height: 22)
                    
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    if !isExpanded {
                        if let badge = badgeText {
                            HStack(spacing: 6) {
                                HStack(spacing: -7) {
                                    Circle().fill(Color.blue.opacity(0.8)).frame(width: 18, height: 18)
                                    Circle().fill(Color.indigo.opacity(0.8)).frame(width: 18, height: 18)
                                    Circle().fill(Color.teal.opacity(0.8)).frame(width: 18, height: 18)
                                }
                                Text(badge)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.myBhoomiBlue)
                            }
                        } else {
                            Text(value ?? placeholder)
                                .font(.system(size: 15, weight: value != nil ? .semibold : .regular))
                                .foregroundColor(value != nil ? Theme.myBhoomiBlue : Color.black.opacity(0.3))
                        }
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isExpanded ? Theme.myBhoomiBlue : Color.black.opacity(isEnabled ? 0.25 : 0.08))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaledButtonStyle())
            .disabled(!isEnabled)
            
            // Expanded Searchable List Panel (Rendered Inline)
            if isExpanded {
                VStack(spacing: 8) {
                    // Search Bar Inside Card
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.35))
                        
                        TextField(searchPlaceholder, text: $searchText)
                            .font(.system(size: 14))
                            .autocorrectionDisabled(true)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.black.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                    
                    // List of Options
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView().tint(Theme.myBhoomiBlue).scaleEffect(0.8)
                            Text("Loading...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                    } else if items.isEmpty {
                        Text("No results found")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 14)
                    } else {
                        ScrollView(showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(items) { item in
                                    DropdownRowView(
                                        title: item.title,
                                        isSelected: item.id == selectedID,
                                        onTap: {
                                            handleItemSelection(item)
                                        }
                                    )
                                    Divider().padding(.horizontal, 14)
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                        .padding(.bottom, 6)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color(red: 0.05, green: 0.15, blue: 0.35).opacity(0.04), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .opacity(isEnabled ? 1.0 : 0.55)
    }
    
    private func handleItemSelection(_ item: DropdownItem) {
        hapticFeedback(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
                    .font(.system(size: 15, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Theme.myBhoomiBlue : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.myBhoomiBlue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(isSelected ? Theme.myBhoomiBlue.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaledButtonStyle())
    }
}

#Preview {
    OfficialLandRecordsView()
}
