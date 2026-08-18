import SwiftUI

struct ManualRoRSearchView: View {
    @StateObject private var viewModel: ManualSearchViewModel
    @State private var activePicker: ActivePickerSheet? = nil
    @State private var pickerSearchText: String = ""
    
    public init(
        initialDistrict: String? = nil,
        initialTahasil: String? = nil,
        initialVillage: String? = nil,
        suggestedPlot: String? = nil,
        initialMode: ManualSearchMode = .plot
    ) {
        _viewModel = StateObject(
            wrappedValue: ManualSearchViewModel(
                initialDistrict: initialDistrict,
                initialTahasil: initialTahasil,
                initialVillage: initialVillage,
                suggestedPlot: suggestedPlot,
                initialMode: initialMode
            )
        )
    }
    
    enum ActivePickerSheet: Identifiable {
        case district, tahasil, village
        var id: Int { hashValue }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header Banner
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.primary)
                        Text("DIRECT BHULEKH LOOKUP")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.primary)
                            .tracking(1.0)
                    }
                    Text("Search Official Record of Rights")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                    Text("Search Odisha land records directly by administrative hierarchy without requiring map navigation.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                
                // Cascading Steps Container
                VStack(spacing: 16) {
                    // Step 1: District
                    LocationStepRow(
                        stepNumber: "1",
                        title: "District",
                        value: viewModel.selectedDistrict?.officialName,
                        placeholder: "Select District",
                        icon: "building.columns.fill",
                        isLoading: viewModel.isLoadingDistricts,
                        isEnabled: true,
                        errorMessage: viewModel.districtError,
                        onTap: {
                            pickerSearchText = ""
                            activePicker = .district
                        },
                        onRetry: { viewModel.loadDistricts() }
                    )
                    
                    // Step 2: Tahasil
                    LocationStepRow(
                        stepNumber: "2",
                        title: "Tahasil",
                        value: viewModel.selectedTahasil?.officialName,
                        placeholder: viewModel.selectedDistrict == nil ? "Select District first" : "Select Tahasil",
                        icon: "map.fill",
                        isLoading: viewModel.isLoadingTahasils,
                        isEnabled: viewModel.selectedDistrict != nil,
                        errorMessage: viewModel.tahasilError,
                        onTap: {
                            pickerSearchText = ""
                            activePicker = .tahasil
                        },
                        onRetry: {
                            if let d = viewModel.selectedDistrict { viewModel.loadTahasils(for: d.id) }
                        }
                    )
                    
                    // Step 3: Village (Mouza)
                    LocationStepRow(
                        stepNumber: "3",
                        title: "Revenue Village (Mouza)",
                        value: viewModel.selectedVillage?.officialName,
                        placeholder: viewModel.selectedTahasil == nil ? "Select Tahasil first" : "Select Village / Mouza",
                        icon: "house.fill",
                        isLoading: viewModel.isLoadingVillages,
                        isEnabled: viewModel.selectedTahasil != nil,
                        errorMessage: viewModel.villageError,
                        onTap: {
                            pickerSearchText = ""
                            activePicker = .village
                        },
                        onRetry: {
                            if let d = viewModel.selectedDistrict, let t = viewModel.selectedTahasil {
                                viewModel.loadVillages(districtID: d.id, tahasilID: t.id)
                            }
                        }
                    )
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
                
                // Step 4: Search Mode & Value
                VStack(alignment: .leading, spacing: 14) {
                    Text("4. CHOOSE SEARCH CRITERIA")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.8)
                    
                    Picker("Search Mode", selection: $viewModel.searchMode) {
                        ForEach(ManualSearchMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if let sp = viewModel.suggestedPlotFromMap, viewModel.searchMode == .plot && viewModel.searchValue != sp {
                        HStack {
                            Text("Map plot suggestion: \(sp)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Use \(sp)") {
                                viewModel.searchValue = sp
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.primary.opacity(0.06))
                        .cornerRadius(10)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.searchMode.icon)
                            .foregroundColor(Theme.primary)
                            .font(.system(size: 16))
                        TextField(viewModel.searchMode.placeholder, text: $viewModel.searchValue)
                            .font(.system(size: 15))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
                
                // Summary & Search Action Button
                if viewModel.isFormComplete {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SEARCH SUMMARY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                        
                        VStack(spacing: 6) {
                            SummaryRow(label: "District", value: "\(viewModel.selectedDistrict?.officialName ?? "") (ID: \(viewModel.selectedDistrict?.id ?? ""))")
                            SummaryRow(label: "Tahasil", value: "\(viewModel.selectedTahasil?.officialName ?? "") (ID: \(viewModel.selectedTahasil?.id ?? ""))")
                            SummaryRow(label: "Village", value: "\(viewModel.selectedVillage?.officialName ?? "") (ID: \(viewModel.selectedVillage?.id ?? ""))")
                            SummaryRow(label: viewModel.searchMode.rawValue, value: viewModel.searchValue)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.02))
                        .cornerRadius(12)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
                }
                
                // Search Submit Button
                Button(action: {
                    hapticFeedback(.medium)
                    viewModel.performSearch()
                }) {
                    HStack(spacing: 10) {
                        if viewModel.state == .loading {
                            ProgressView().tint(.white)
                            Text("Cross-verifying official records...")
                                .font(.system(size: 16, weight: .bold))
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                            Text("Search Official RoR")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(viewModel.isFormComplete ? Theme.primary : Color.gray.opacity(0.4))
                    .cornerRadius(18)
                    .shadow(color: viewModel.isFormComplete ? Theme.primary.opacity(0.3) : Color.clear, radius: 12, y: 6)
                }
                .disabled(!viewModel.isFormComplete || viewModel.state == .loading)
                
                // Results State Presentation
                switch viewModel.state {
                case .idle:
                    EmptyView()
                case .loading:
                    EmptyView()
                case .success(let ror, let verif):
                    ManualSearchResultView(ror: ror, verif: verif, viewModel: viewModel)
                case .unverified(let verif):
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.slash.fill")
                                .foregroundColor(.orange)
                            Text("UNABLE TO VERIFY PARCEL")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        Text("Ownership information is withheld because the returned portal record could not be authoritatively cross-verified.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        ForEach(verif.reasons, id: \.self) { reason in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").foregroundColor(.orange)
                                Text(reason).font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(16)
                case .error(let msg):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Lookup Error")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                        }
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color.red.opacity(0.06))
                    .cornerRadius(16)
                }
            }
            .padding(20)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .district:
                SearchableHierarchySheet(
                    title: "Select District",
                    items: viewModel.districts.map { ($0.id, $0.officialName) },
                    searchText: $pickerSearchText
                ) { id, name in
                    if let d = viewModel.districts.first(where: { $0.id == id }) {
                        viewModel.selectedDistrict = d
                    }
                    activePicker = nil
                }
            case .tahasil:
                SearchableHierarchySheet(
                    title: "Select Tahasil",
                    items: viewModel.tahasils.map { ($0.id, $0.officialName) },
                    searchText: $pickerSearchText
                ) { id, name in
                    if let t = viewModel.tahasils.first(where: { $0.id == id }) {
                        viewModel.selectedTahasil = t
                    }
                    activePicker = nil
                }
            case .village:
                SearchableHierarchySheet(
                    title: "Select Village (Mouza)",
                    items: viewModel.villages.map { ($0.id, $0.officialName) },
                    searchText: $pickerSearchText
                ) { id, name in
                    if let v = viewModel.villages.first(where: { $0.id == id }) {
                        viewModel.selectedVillage = v
                    }
                    activePicker = nil
                }
            }
        }
    }
}

// MARK: - Step Row Helper

struct LocationStepRow: View {
    let stepNumber: String
    let title: String
    let value: String?
    let placeholder: String
    let icon: String
    let isLoading: Bool
    let isEnabled: Bool
    let errorMessage: String?
    let onTap: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? Theme.primary.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isEnabled ? Theme.primary : Color.gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stepNumber). \(title.uppercased())")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    if let v = value {
                        Text(v)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                    } else {
                        Text(placeholder)
                            .font(.system(size: 14))
                            .foregroundColor(isEnabled ? .secondary : Color.gray.opacity(0.6))
                    }
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if errorMessage != nil {
                    Button("RETRY", action: onRetry)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.primary)
                } else if isEnabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Searchable Hierarchy Modal Sheet

struct SearchableHierarchySheet: View {
    let title: String
    let items: [(id: String, name: String)]
    @Binding var searchText: String
    let onSelect: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var filteredItems: [(id: String, name: String)] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search \(title.lowercased())...", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No matching locations found.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(filteredItems, id: \.id) { item in
                        Button(action: {
                            onSelect(item.id, item.name)
                        }) {
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.black)
                                Spacer()
                                Text("ID: \(item.id)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Summary & Result Rows

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black)
        }
    }
}

struct ManualSearchResultView: View {
    let ror: RoRResponse
    let verif: ParcelVerificationResult
    @ObservedObject var viewModel: ManualSearchViewModel
    
    var body: some View {
        UnifiedRoRResultView(
            ror: ror,
            verification: verif,
            onDownloadPDF: {
                viewModel.downloadPDF()
            },
            isDownloadingPDF: viewModel.isDownloadingPDF,
            downloadedPDFURL: viewModel.downloadedPDFURL,
            onSelectPlot: { plot in
                // Select associated plot and trigger search
                viewModel.searchValue = plot.plotNumber
                viewModel.performSearch()
            }
        )
    }
}
