import SwiftUI

/// Main screen for searching Odisha official land records directly with Liquid Glass visual hierarchy.
public struct OfficialLandRecordsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OfficialLandRecordsViewModel()
    @State private var selectedResultForDetail: OfficialSearchResult? = nil
    
    // Physical press & micro-interaction states
    @State private var isPressingShowPlots: Bool = false
    @State private var isShowingGlow: Bool = false
    
    public var onPlotSelected: ((OfficialSearchResult) -> Void)? = nil
    
    public init(onPlotSelected: ((OfficialSearchResult) -> Void)? = nil) {
        self.onPlotSelected = onPlotSelected
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // 1. Liquid Glass Soft Gradient Background
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.96, blue: 0.99),
                        Color(red: 0.97, green: 0.98, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Header Section
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Official Land Records")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Text("Search Odisha land records directly")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                            .padding(.horizontal, 4)
                            
                            // 2. The 4 Interactive Location Cards
                            VStack(spacing: 12) {
                                // Row 1: District
                                GlassLocationRow(
                                    icon: "calendar",
                                    title: "District",
                                    value: viewModel.selectedDistrict?.officialName.capitalized,
                                    placeholder: "Select District",
                                    isEnabled: true,
                                    action: {
                                        viewModel.loadDistricts()
                                        viewModel.activePicker = .district
                                    }
                                )
                                
                                // Row 2: Tahasil
                                GlassLocationRow(
                                    icon: "person.2.fill",
                                    title: "Tahsil",
                                    value: viewModel.selectedTahasil?.officialName.capitalized,
                                    placeholder: viewModel.selectedDistrict == nil ? "Select District first" : "Select Tahsil",
                                    isEnabled: viewModel.selectedDistrict != nil,
                                    badgeText: viewModel.selectedDistrict != nil && viewModel.selectedTahasil == nil ? "12+" : nil,
                                    action: {
                                        if let d = viewModel.selectedDistrict {
                                            viewModel.loadTahasils(for: d.id)
                                            viewModel.activePicker = .tahasil
                                        }
                                    }
                                )
                                
                                // Row 3: Panchayat
                                GlassLocationRow(
                                    icon: "clock.fill",
                                    title: "Panchayat",
                                    value: viewModel.selectedPanchayat ?? (viewModel.selectedTahasil != nil ? "Maidankel" : nil),
                                    placeholder: viewModel.selectedTahasil == nil ? "Select Tahsil first" : "Select Panchayat",
                                    isEnabled: viewModel.selectedTahasil != nil,
                                    action: {
                                        if viewModel.selectedTahasil != nil {
                                            viewModel.activePicker = .panchayat
                                        }
                                    }
                                )
                                
                                // Row 4: Expandable Inline Village Card
                                ExpandableVillageGlassCard(viewModel: viewModel)
                            }
                            .padding(.top, 6)
                            
                            // 3. Search Mode & Results Section (Revealed when ready or Show Plots tapped)
                            if viewModel.isPlotsSectionVisible || viewModel.isSelectionComplete {
                                VStack(alignment: .leading, spacing: 14) {
                                    // Segmented Control [ Khatian ] [ Plot ]
                                    HStack(spacing: 6) {
                                        ForEach(LandRecordSearchMode.allCases) { mode in
                                            Button(action: {
                                                hapticFeedback(.light)
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                    viewModel.searchMode = mode
                                                }
                                            }) {
                                                Text(mode.rawValue)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(viewModel.searchMode == mode ? .white : .black.opacity(0.75))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(viewModel.searchMode == mode ? Theme.myBhoomiBlue : Color.black.opacity(0.04))
                                                    )
                                            }
                                            .buttonStyle(ScaledButtonStyle())
                                        }
                                    }
                                    .padding(4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.85))
                                            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                                    )
                                    
                                    // Search Input Container
                                    HStack(spacing: 10) {
                                        TextField(
                                            viewModel.searchMode == .plot ? "Enter plot number" : "Enter khatian number",
                                            text: $viewModel.searchQuery
                                        )
                                        .font(.system(size: 15))
                                        .keyboardType(viewModel.searchMode == .plot ? .numbersAndPunctuation : .default)
                                        .autocorrectionDisabled(true)
                                        .onSubmit {
                                            viewModel.executeSearch()
                                        }
                                        
                                        if !viewModel.searchQuery.isEmpty {
                                            Button(action: { viewModel.searchQuery = "" }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(Color.black.opacity(0.3))
                                            }
                                        }
                                        
                                        // Go Action Button
                                        Button(action: {
                                            hapticFeedback(.medium)
                                            viewModel.executeSearch()
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.black.opacity(0.08) : Theme.myBhoomiBlue)
                                                    .frame(width: 36, height: 36)
                                                
                                                Image(systemName: "arrow.right")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSearching)
                                        .buttonStyle(ScaledButtonStyle())
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.9))
                                            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                    )
                                    
                                    // Search Results State Section
                                    if viewModel.isSearching {
                                        HStack(spacing: 12) {
                                            ProgressView()
                                                .tint(Theme.myBhoomiBlue)
                                            Text("Searching official land records...")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 24)
                                    } else if viewModel.isNoRecordFound {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "questionmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.orange)
                                                Text("No Record Found")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.black)
                                            }
                                            
                                            Text("No \(viewModel.searchMode == .plot ? "plot" : "Khatian") matching \"\(viewModel.searchedQuery)\" was found for the selected village.")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                                .lineSpacing(2)
                                        }
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white)
                                                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                        )
                                    } else if let err = viewModel.searchError {
                                        VStack(spacing: 12) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.red)
                                                Text(err)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.black)
                                            }
                                            
                                            Button(action: {
                                                hapticFeedback(.medium)
                                                viewModel.executeSearch()
                                            }) {
                                                Text("Try Again")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 20)
                                                    .padding(.vertical, 8)
                                                    .background(Theme.myBhoomiBlue)
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(ScaledButtonStyle())
                                        }
                                        .padding(16)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                                        )
                                    } else if !viewModel.searchResults.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("\(viewModel.searchResults.count) \(viewModel.searchMode == .plot ? "plot" : "Khatian") matching \"\(viewModel.searchedQuery)\"")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .padding(.leading, 4)
                                            
                                            ForEach(viewModel.searchResults) { result in
                                                Button(action: {
                                                    hapticFeedback(.light)
                                                    selectedResultForDetail = result
                                                    onPlotSelected?(result)
                                                }) {
                                                    HStack(alignment: .center, spacing: 12) {
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(viewModel.searchMode == .plot ? "Plot \(result.plotNumber)" : "Khatian \(result.khatianNumber)")
                                                                .font(.system(size: 18, weight: .bold))
                                                                .foregroundColor(Theme.myBhoomiBlue)
                                                            
                                                            Text(viewModel.searchMode == .plot ? "Khatian \(result.khatianNumber)" : "Plot \(result.plotNumber)")
                                                                .font(.system(size: 13, weight: .medium))
                                                                .foregroundColor(.secondary)
                                                        }
                                                        
                                                        Spacer()
                                                        
                                                        Image(systemName: "doc.text.magnifyingglass")
                                                            .font(.system(size: 20))
                                                            .foregroundColor(Theme.myBhoomiBlue.opacity(0.8))
                                                    }
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 14)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                            .fill(Color.white)
                                                            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                                    )
                                                }
                                                .buttonStyle(ScaledButtonStyle())
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            Spacer(minLength: 90)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    // 4. Floating Bottom Action Bar
                    HStack {
                        // Reset All Button
                        Button(action: {
                            hapticFeedback(.light)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.resetAll()
                            }
                        }) {
                            Text("Reset all")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Theme.myBhoomiBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        
                        Spacer()
                        
                        // Show Plots Button
                        Button(action: {
                            hapticFeedback(.medium)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                viewModel.isPlotsSectionVisible = true
                            }
                            if let village = viewModel.selectedVillage, viewModel.searchQuery.isEmpty {
                                // Default prompt or load first plot if desired
                                viewModel.searchQuery = "489"
                                viewModel.executeSearch()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Text("Show Plots")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 28, height: 28)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Theme.myBhoomiBlue)
                                }
                            }
                            .padding(.leading, 20)
                            .padding(.trailing, 8)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Theme.myBhoomiBlue)
                                    .shadow(color: Theme.myBhoomiBlue.opacity(viewModel.isSelectionComplete ? 0.45 : 0.2), radius: viewModel.isSelectionComplete ? 12 : 6, x: 0, y: 4)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .scaleEffect(isPressingShowPlots ? 0.96 : 1.0)
                        }
                        .disabled(!viewModel.isSelectionComplete && viewModel.selectedVillage == nil)
                        .opacity((viewModel.isSelectionComplete || viewModel.selectedVillage != nil) ? 1.0 : 0.5)
                        .buttonStyle(ScaledButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        Color.white.opacity(0.8)
                            .background(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: -4)
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        hapticFeedback(.light)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.myBhoomiBlue)
                }
            }
            .sheet(item: $viewModel.activePicker) { pickerType in
                switch pickerType {
                case .district:
                    OfficialLocationPickerSheet(
                        title: "District",
                        items: viewModel.districts.map {
                            LocationPickerItem(id: $0.id, title: $0.officialName.capitalized)
                        },
                        selectedID: viewModel.selectedDistrict?.id,
                        isLoading: viewModel.isLoadingDistricts,
                        errorMessage: viewModel.districtError,
                        onSelect: { item in
                            if let match = viewModel.districts.first(where: { $0.id == item.id }) {
                                viewModel.selectDistrict(match)
                            }
                        },
                        onRetry: {
                            viewModel.loadDistricts()
                        }
                    )
                    
                case .tahasil:
                    OfficialLocationPickerSheet(
                        title: "Tahasil",
                        items: viewModel.tahasils.map {
                            LocationPickerItem(id: $0.id, title: $0.officialName.capitalized)
                        },
                        selectedID: viewModel.selectedTahasil?.id,
                        isLoading: viewModel.isLoadingTahasils,
                        errorMessage: viewModel.tahasilError,
                        onSelect: { item in
                            if let match = viewModel.tahasils.first(where: { $0.id == item.id }) {
                                viewModel.selectTahasil(match)
                            }
                        },
                        onRetry: {
                            if let d = viewModel.selectedDistrict {
                                viewModel.loadTahasils(for: d.id)
                            }
                        }
                    )
                    
                case .panchayat:
                    OfficialLocationPickerSheet(
                        title: "Panchayat",
                        items: viewModel.panchayats.map {
                            LocationPickerItem(id: $0, title: $0)
                        },
                        selectedID: viewModel.selectedPanchayat,
                        isLoading: false,
                        errorMessage: nil,
                        onSelect: { item in
                            viewModel.selectPanchayat(item.title)
                        },
                        onRetry: {}
                    )
                    
                case .village:
                    OfficialLocationPickerSheet(
                        title: "Village",
                        items: viewModel.villages.map {
                            LocationPickerItem(id: $0.id, title: $0.officialName)
                        },
                        selectedID: viewModel.selectedVillage?.id,
                        isLoading: viewModel.isLoadingVillages,
                        errorMessage: viewModel.villageError,
                        onSelect: { item in
                            if let match = viewModel.villages.first(where: { $0.id == item.id }) {
                                viewModel.selectVillage(match)
                            }
                        },
                        onRetry: {
                            if let d = viewModel.selectedDistrict, let t = viewModel.selectedTahasil {
                                viewModel.loadVillages(districtID: d.id, tahasilID: t.id)
                            }
                        }
                    )
                }
            }
            .sheet(item: $selectedResultForDetail) { result in
                KhatianDetailView(result: result)
            }
        }
    }
}

// MARK: - Premium Liquid Glass Location Row

struct GlassLocationRow: View {
    let icon: String
    let title: String
    let value: String?
    let placeholder: String
    let isEnabled: Bool
    var badgeText: String? = nil
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            if isEnabled {
                hapticFeedback(.light)
                action()
            }
        }) {
            HStack(spacing: 14) {
                // Left Icon
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.myBhoomiBlue)
                    .frame(width: 24, height: 24)
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                
                Spacer()
                
                // Right Value / Badge
                if let badge = badgeText {
                    HStack(spacing: 6) {
                        // Avatar stack representation
                        HStack(spacing: -8) {
                            Circle().fill(Color.blue.opacity(0.8)).frame(width: 20, height: 20)
                            Circle().fill(Color.indigo.opacity(0.8)).frame(width: 20, height: 20)
                            Circle().fill(Color.teal.opacity(0.8)).frame(width: 20, height: 20)
                        }
                        Text(badge)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.myBhoomiBlue)
                    }
                } else {
                    Text(value ?? placeholder)
                        .font(.system(size: 16, weight: value != nil ? .semibold : .regular))
                        .foregroundColor(value != nil ? Theme.myBhoomiBlue : Color.black.opacity(0.3))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.black.opacity(isEnabled ? 0.25 : 0.08))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.85))
                    .shadow(color: Color(red: 0.05, green: 0.15, blue: 0.35).opacity(0.04), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.6)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(ScaledButtonStyle())
        .disabled(!isEnabled)
    }
}

// MARK: - Expandable Inline Village Glass Card

struct ExpandableVillageGlassCard: View {
    @ObservedObject var viewModel: OfficialLandRecordsViewModel
    
    var isEnabled: Bool {
        viewModel.selectedTahasil != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Row Header (Tappable to expand/collapse)
            Button(action: {
                if isEnabled {
                    hapticFeedback(.light)
                    if viewModel.villages.isEmpty, let d = viewModel.selectedDistrict, let t = viewModel.selectedTahasil {
                        viewModel.loadVillages(districtID: d.id, tahasilID: t.id)
                    }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        viewModel.isVillageExpanded.toggle()
                    }
                }
            }) {
                HStack(spacing: 14) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.myBhoomiBlue)
                        .frame(width: 24, height: 24)
                    
                    Text("Village")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    if !viewModel.isVillageExpanded {
                        Text(viewModel.selectedVillage?.officialName ?? "Select")
                            .font(.system(size: 16, weight: viewModel.selectedVillage != nil ? .semibold : .regular))
                            .foregroundColor(viewModel.selectedVillage != nil ? Theme.myBhoomiBlue : Color.black.opacity(0.3))
                    }
                    
                    Image(systemName: viewModel.isVillageExpanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(viewModel.isVillageExpanded ? Theme.myBhoomiBlue : Color.black.opacity(isEnabled ? 0.25 : 0.08))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaledButtonStyle())
            .disabled(!isEnabled)
            
            // Expanded Inline Selection Panel
            if viewModel.isVillageExpanded {
                VStack(spacing: 10) {
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.35))
                        
                        TextField("Search village", text: $viewModel.villageSearchText)
                            .font(.system(size: 15))
                            .autocorrectionDisabled(true)
                        
                        if !viewModel.villageSearchText.isEmpty {
                            Button(action: { viewModel.villageSearchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color.black.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                    )
                    .padding(.horizontal, 16)
                    
                    // Village Items List
                    if viewModel.isLoadingVillages {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Theme.myBhoomiBlue)
                            Text("Loading villages...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 16)
                    } else if viewModel.filteredVillages.isEmpty {
                        Text("No villages found")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 16)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.filteredVillages.prefix(20)) { village in
                                let isSelected = viewModel.selectedVillage?.id == village.id
                                Button(action: {
                                    hapticFeedback(.light)
                                    viewModel.selectVillage(village)
                                }) {
                                    HStack {
                                        Text(village.officialName)
                                            .font(.system(size: 15, weight: isSelected ? .bold : .regular))
                                            .foregroundColor(isSelected ? Theme.myBhoomiBlue : .black)
                                        
                                        Spacer()
                                        
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(Theme.myBhoomiBlue)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        isSelected ? Theme.myBhoomiBlue.opacity(0.08) : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(ScaledButtonStyle())
                                
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .shadow(color: Color(red: 0.05, green: 0.15, blue: 0.35).opacity(0.04), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

#Preview {
    OfficialLandRecordsView()
}
