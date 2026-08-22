import SwiftUI

/// Clean, production-quality Manual RoR Search View using unified Design Tokens.
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
            VStack(spacing: Theme.Spacing.lg) {
                // Header Banner
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Color.primary)
                        Text("DIRECT BHULEKH LOOKUP")
                            .font(Theme.Typography.subcaption)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Color.primary)
                            .tracking(1.0)
                    }
                    Text("Search Official Record of Rights")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Color.primaryText)
                    Text("Search Odisha land records directly by administrative hierarchy without requiring map navigation.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Color.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Theme.Spacing.xs)
                
                // Cascading Steps Container
                VStack(spacing: Theme.Spacing.md) {
                    // Step 1: District
                    LocationStepRow(
                        stepNumber: "1",
                        title: "District",
                        value: viewModel.selectedDistrict?.officialName,
                        placeholder: "Select District",
                        icon: "map",
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
                        icon: "building.columns",
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
                        icon: UIImage(systemName: "house.and.flag") != nil ? "house.and.flag" : "house",
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
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface)
                .cornerRadius(Theme.Radius.card)
                .shadow(color: Theme.Shadow.subtle, radius: 10, y: 4)
                
                // Step 4: Search Mode & Value
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("4. CHOOSE SEARCH CRITERIA")
                        .font(Theme.Typography.subcaption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Color.secondaryText)
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
                                .font(Theme.Typography.captionMedium)
                                .foregroundColor(Theme.Color.secondaryText)
                            Spacer()
                            Button("Use \(sp)") {
                                viewModel.searchValue = sp
                            }
                            .font(Theme.Typography.captionMedium.weight(.bold))
                            .foregroundColor(Theme.Color.primary)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Color.primaryLight)
                        .cornerRadius(Theme.Radius.small)
                    }
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: viewModel.searchMode.icon)
                            .foregroundColor(Theme.Color.primary)
                            .font(.system(size: 16))
                        TextField(viewModel.searchMode.placeholder, text: $viewModel.searchValue)
                            .font(Theme.Typography.secondaryBody)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Color.secondarySurface)
                    .cornerRadius(Theme.Radius.small)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface)
                .cornerRadius(Theme.Radius.card)
                .shadow(color: Theme.Shadow.subtle, radius: 10, y: 4)
                
                // Summary & Search Action Button
                if viewModel.isFormComplete {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("SEARCH SUMMARY")
                            .font(Theme.Typography.subcaption)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Color.secondaryText)
                            .tracking(1.0)
                        
                        VStack(spacing: Theme.Spacing.xxs) {
                            SummaryRow(label: "District", value: "\(viewModel.selectedDistrict?.officialName ?? "") (ID: \(viewModel.selectedDistrict?.id ?? ""))")
                            SummaryRow(label: "Tahasil", value: "\(viewModel.selectedTahasil?.officialName ?? "") (ID: \(viewModel.selectedTahasil?.id ?? ""))")
                            SummaryRow(label: "Village", value: "\(viewModel.selectedVillage?.officialName ?? "") (ID: \(viewModel.selectedVillage?.id ?? ""))")
                            SummaryRow(label: "Criterion", value: "\(viewModel.searchMode.rawValue): \(viewModel.searchValue)")
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Color.secondarySurface)
                        .cornerRadius(Theme.Radius.small)
                    }
                    
                    Button(action: {
                        Theme.haptic(.medium)
                        viewModel.performSearch()
                    }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            if viewModel.state == .loading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.headline)
                            }
                            Text(viewModel.state == .loading ? "Searching Bhulekh..." : "SEARCH RECORD")
                                .font(.headline)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.accentColor)
                    .clipShape(Capsule())
                    .disabled(viewModel.state == .loading)
                    .opacity(viewModel.state == .loading ? 0.65 : 1.0)
                }
                
                // Result / State Views
                switch viewModel.state {
                case .idle:
                    EmptyView()
                case .loading:
                    VStack(spacing: Theme.Spacing.sm) {
                        ProgressView().tint(Theme.Color.primary)
                        Text("Fetching authentic Bhulekh record...")
                            .font(Theme.Typography.captionMedium)
                            .foregroundColor(Theme.Color.secondaryText)
                    }
                    .padding(Theme.Spacing.xl)
                case .success(let ror, let ver):
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Theme.Color.success)
                            Text("Official RoR Record Found")
                                .font(Theme.Typography.primaryBodyBold)
                                .foregroundColor(Theme.Color.success)
                        }
                        
                        UnifiedRoRResultView(
                            ror: ror,
                            verification: ver,
                            onDownloadPDF: {
                                viewModel.downloadPDF()
                            },
                            isDownloadingPDF: viewModel.isDownloadingPDF,
                            downloadedPDFURL: viewModel.downloadedPDFURL
                        )
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.surface)
                    .cornerRadius(Theme.Radius.card)
                    .shadow(color: Theme.Shadow.subtle, radius: 12, y: 4)
                case .unverified(let ver):
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.Color.warning)
                            Text("Record Found (Unverified)")
                                .font(Theme.Typography.secondaryBodyMedium.weight(.bold))
                                .foregroundColor(Theme.Color.warning)
                        }
                        Text("Record retrieved from Bhulekh but could not be fully verified against cadastral geometry: \(ver.reasons.joined(separator: ", "))")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Color.secondaryText)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.warning.opacity(0.08))
                    .cornerRadius(Theme.Radius.medium)
                case .notFound(let msg):
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(Theme.Color.warning)
                            Text("No Record Found")
                                .font(Theme.Typography.secondaryBodyMedium.weight(.bold))
                                .foregroundColor(Theme.Color.warning)
                        }
                        Text(msg)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Color.secondaryText)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.warning.opacity(0.08))
                    .cornerRadius(Theme.Radius.medium)
                case .temporarilyUnavailable(let msg):
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(Theme.Color.primary)
                            Text("Service Unavailable")
                                .font(Theme.Typography.secondaryBodyMedium.weight(.bold))
                                .foregroundColor(Theme.Color.primary)
                            Spacer()
                            Button("TRY AGAIN") {
                                viewModel.performSearch()
                            }
                            .font(Theme.Typography.captionMedium.weight(.bold))
                            .foregroundColor(Theme.Color.primary)
                        }
                        Text(msg)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Color.secondaryText)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.primaryLight)
                    .cornerRadius(Theme.Radius.medium)
                case .error(let msg):
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.Color.error)
                            Text("Lookup Error")
                                .font(Theme.Typography.secondaryBodyMedium.weight(.bold))
                                .foregroundColor(Theme.Color.error)
                            Spacer()
                            Button("RETRY") {
                                viewModel.performSearch()
                            }
                            .font(Theme.Typography.captionMedium.weight(.bold))
                            .foregroundColor(Theme.Color.error)
                        }
                        Text(msg)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Color.secondaryText)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Color.error.opacity(0.08))
                    .cornerRadius(Theme.Radius.medium)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Color.background)
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .district:
                SearchableHierarchySheet(
                    title: "Select District",
                    items: viewModel.districts.map { ($0.id, $0.officialName) },
                    searchText: $pickerSearchText
                ) { id, _ in
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
                ) { id, _ in
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
                ) { id, _ in
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
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? Theme.Color.primaryLight : Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isEnabled ? Theme.Color.primary : Color.gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stepNumber). \(title.uppercased())")
                        .font(Theme.Typography.subcaption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Color.secondaryText)
                    
                    if let v = value {
                        Text(v)
                            .font(Theme.Typography.secondaryBodyMedium)
                            .foregroundColor(Theme.Color.primaryText)
                    } else {
                        Text(placeholder)
                            .font(Theme.Typography.secondaryBody)
                            .foregroundColor(isEnabled ? Theme.Color.secondaryText : Theme.Color.tertiaryText)
                    }
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(Theme.Typography.subcaption)
                            .foregroundColor(Theme.Color.error)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if errorMessage != nil {
                    Button("RETRY", action: onRetry)
                        .font(Theme.Typography.subcaption.weight(.bold))
                        .foregroundColor(Theme.Color.primary)
                } else if isEnabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Color.tertiaryText)
                }
            }
            .padding(.vertical, Theme.Spacing.xxs)
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
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Color.tertiaryText)
                    TextField("Search \(title.lowercased())...", text: $searchText)
                        .font(Theme.Typography.secondaryBody)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Color.tertiaryText)
                        }
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Color.secondarySurface)
                .cornerRadius(Theme.Radius.small)
                .padding(Theme.Spacing.md)
                
                // List
                List(filteredItems, id: \.id) { item in
                    Button(action: {
                        onSelect(item.id, item.name)
                    }) {
                        HStack {
                            Text(item.name)
                                .font(Theme.Typography.secondaryBody)
                                .foregroundColor(Theme.Color.primaryText)
                            Spacer()
                            Text("ID: \(item.id)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Color.tertiaryText)
                        }
                        .padding(.vertical, Theme.Spacing.xxs)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Color.primary)
                }
            }
        }
    }
}

// MARK: - Summary Row Helper

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Typography.captionMedium)
                .foregroundColor(Theme.Color.secondaryText)
            Spacer()
            Text(value)
                .font(Theme.Typography.captionMedium.weight(.semibold))
                .foregroundColor(Theme.Color.primaryText)
        }
    }
}
