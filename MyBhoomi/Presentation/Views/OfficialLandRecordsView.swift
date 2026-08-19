import SwiftUI

/// Main screen for searching Odisha official land records directly.
public struct OfficialLandRecordsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OfficialLandRecordsViewModel()
    @State private var selectedResultForDetail: OfficialSearchResult? = nil
    
    public var onPlotSelected: ((OfficialSearchResult) -> Void)? = nil
    
    public init(onPlotSelected: ((OfficialSearchResult) -> Void)? = nil) {
        self.onPlotSelected = onPlotSelected
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Apple-style very light background
                Color(white: 0.98).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
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
                        
                        // Location Hierarchy Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Location")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 8) {
                                // 1. District Row
                                LocationSelectionCard(
                                    title: "District",
                                    value: viewModel.selectedDistrict?.officialName,
                                    placeholder: "Select District",
                                    isEnabled: true,
                                    action: {
                                        viewModel.loadDistricts()
                                        viewModel.activePicker = .district
                                    }
                                )
                                
                                // 2. Tahasil Row
                                LocationSelectionCard(
                                    title: "Tahasil",
                                    value: viewModel.selectedTahasil?.officialName,
                                    placeholder: viewModel.selectedDistrict == nil ? "Select District first" : "Select Tahasil",
                                    isEnabled: viewModel.selectedDistrict != nil,
                                    action: {
                                        if let d = viewModel.selectedDistrict {
                                            viewModel.loadTahasils(for: d.id)
                                            viewModel.activePicker = .tahasil
                                        }
                                    }
                                )
                                
                                // 3. Village Row
                                LocationSelectionCard(
                                    title: "Village",
                                    value: viewModel.selectedVillage?.officialName,
                                    placeholder: viewModel.selectedTahasil == nil ? "Select Tahasil first" : "Select Village",
                                    isEnabled: viewModel.selectedTahasil != nil,
                                    action: {
                                        if let d = viewModel.selectedDistrict, let t = viewModel.selectedTahasil {
                                            viewModel.loadVillages(districtID: d.id, tahasilID: t.id)
                                            viewModel.activePicker = .village
                                        }
                                    }
                                )
                            }
                        }
                        
                        // Search Mode & Inputs (Visible once Village is selected)
                        if viewModel.selectedDistrict != nil && viewModel.selectedTahasil != nil && viewModel.selectedVillage != nil {
                            VStack(alignment: .leading, spacing: 14) {
                                // Segmented Control [ Khatian ] [ Plot ]
                                HStack(spacing: 8) {
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
                                                        .fill(viewModel.searchMode == mode ? Theme.emeraldGreen : Color.black.opacity(0.04))
                                                )
                                        }
                                        .buttonStyle(ScaledButtonStyle())
                                    }
                                }
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                                )
                                
                                // Search Input Container
                                HStack(spacing: 10) {
                                    TextField(
                                        viewModel.searchMode == .plot ? "Search plot number (e.g. 1050)" : "Search Khatian number (e.g. 139/57)",
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
                                    
                                    // Search / Go Action Button
                                    Button(action: {
                                        hapticFeedback(.medium)
                                        viewModel.executeSearch()
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.black.opacity(0.08) : Theme.emeraldGreen)
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
                                        .fill(Color.white)
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
                                            .tint(Theme.emeraldGreen)
                                        Text("Searching official land records...")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                                } else if viewModel.isNoRecordFound {
                                    // No Record Found State
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
                                    // Error State with Try Again
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
                                                .background(Theme.emeraldGreen)
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
                                    // Result Count & Result Cards
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
                                                            .foregroundColor(Theme.emeraldGreen)
                                                        
                                                        Text(viewModel.searchMode == .plot ? "Khatian \(result.khatianNumber)" : "Plot \(result.plotNumber)")
                                                            .font(.system(size: 13, weight: .medium))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "doc.text.magnifyingglass")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(Theme.emeraldGreen.opacity(0.8))
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
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
                    .foregroundColor(Theme.emeraldGreen)
                }
            }
            .sheet(item: $viewModel.activePicker) { pickerType in
                switch pickerType {
                case .district:
                    OfficialLocationPickerSheet(
                        title: "District",
                        items: viewModel.districts.map {
                            LocationPickerItem(id: $0.id, title: $0.officialName)
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
                            LocationPickerItem(id: $0.id, title: $0.officialName)
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

/// Large rounded selection card for District / Tahasil / Village rows.
struct LocationSelectionCard: View {
    let title: String
    let value: String?
    let placeholder: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if isEnabled {
                hapticFeedback(.light)
                action()
            }
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(isEnabled ? .black : Color.black.opacity(0.4))
                
                Spacer()
                
                Text(value ?? placeholder)
                    .font(.system(size: 16, weight: value != nil ? .bold : .regular))
                    .foregroundColor(value != nil ? .black : Color.black.opacity(0.3))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.black.opacity(isEnabled ? 0.2 : 0.08))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(ScaledButtonStyle())
        .disabled(!isEnabled)
    }
}

#Preview {
    OfficialLandRecordsView()
}
