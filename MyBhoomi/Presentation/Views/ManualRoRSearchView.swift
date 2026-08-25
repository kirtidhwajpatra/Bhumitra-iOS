import SwiftUI

/// Clean, production-quality Manual RoR Search View with Persistent Verified Parcel Cache & Smart Suggestions.
struct ManualRoRSearchView: View {
    @StateObject private var viewModel: ManualSearchViewModel
    @State private var activePicker: ActivePickerSheet? = nil
    @State private var pickerSearchText: String = ""
    @ObservedObject private var cache = VerifiedParcelCache.shared
    
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
    
    private var matchingSuggestions: [CachedVerifiedParcel] {
        let query = viewModel.searchValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return cache.searchSuggestions(query: query)
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
                    
                    // Smart Search Suggestions Dropdown
                    if !matchingSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SAVED VERIFIED SUGGESTIONS")
                                .font(.googleSans(size: 9, weight: .bold))
                                .foregroundColor(Color.accentColor)
                                .tracking(0.8)
                                .padding(.horizontal, 4)
                                .padding(.top, 4)
                            
                            ForEach(matchingSuggestions.prefix(3)) { suggestion in
                                Button {
                                    Theme.haptic(.light)
                                    viewModel.selectCachedParcel(suggestion)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Plot \(suggestion.plotNumber) · \(suggestion.villageName)")
                                                .font(.googleSans(size: 13, weight: .bold))
                                                .foregroundColor(Theme.Color.primaryText)
                                            Text("\(suggestion.tahasilName) · Khata \(suggestion.khataNumber)")
                                                .font(.googleSans(size: 11, weight: .regular))
                                                .foregroundColor(Theme.Color.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.googleSans(size: 12, weight: .regular))
                                            .foregroundColor(Color.accentColor)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(Theme.Color.surface)
                                    .cornerRadius(Theme.Radius.small)
                                }
                                .buttonStyle(ScaledButtonStyle())
                            }
                        }
                        .padding(8)
                        .background(Theme.Color.secondarySurface)
                        .cornerRadius(Theme.Radius.medium)
                    }
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
                
                // ── RECENT PARCELS SECTION (Placed directly below search controls) ──
                RecentParcelsSectionView(
                    onSelectParcel: { parcel in
                        viewModel.selectCachedParcel(parcel)
                    }
                )
                
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
                        // Cached vs Live Indicator Banner
                        if viewModel.isViewingCachedRecord {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(Color.accentColor)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("VERIFIED · SAVED RESULT")
                                            .font(.googleSans(size: 11, weight: .bold))
                                            .foregroundColor(Color.accentColor)
                                        if let date = viewModel.cachedVerifiedDate {
                                            Text("Saved \(date.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.googleSans(size: 10.5, weight: .regular))
                                                .foregroundColor(Theme.Color.secondaryText)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // Explicit Refresh Button
                                Button {
                                    Theme.haptic(.light)
                                    viewModel.performSearch(forceRefresh: true)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Refresh")
                                    }
                                    .font(.googleSans(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundColor(Color.accentColor)
                                    .cornerRadius(6)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.06))
                            .cornerRadius(Theme.Radius.small)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(Theme.Color.success)
                                Text("Official RoR Record Found")
                                    .font(Theme.Typography.primaryBodyBold)
                                    .foregroundColor(Theme.Color.success)
                            }
                        }
                        
                        if let refreshErr = viewModel.refreshErrorMessage {
                            Text(refreshErr)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
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
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundColor(Theme.Color.error)
                            Text("Search Error")
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
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle("Manual RoR Search")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activePicker) { picker in
            NavigationStack {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Color.secondaryText)
                        TextField("Search...", text: $pickerSearchText)
                            .font(Theme.Typography.secondaryBody)
                            .autocorrectionDisabled()
                        if !pickerSearchText.isEmpty {
                            Button(action: { pickerSearchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.Color.secondaryText)
                            }
                        }
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Color.secondarySurface)
                    .cornerRadius(Theme.Radius.small)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    
                    Divider()
                    
                    // List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            switch picker {
                            case .district:
                                let filtered = viewModel.districts.filter {
                                    pickerSearchText.isEmpty || $0.officialName.localizedCaseInsensitiveContains(pickerSearchText) || $0.id.contains(pickerSearchText)
                                }
                                if filtered.isEmpty {
                                    EmptyListView(message: "No districts match \"\(pickerSearchText)\"")
                                } else {
                                    ForEach(filtered) { item in
                                        PickerRow(
                                            title: item.officialName,
                                            subtitle: "District ID: \(item.id)",
                                            isSelected: viewModel.selectedDistrict?.id == item.id,
                                            onSelect: {
                                                viewModel.selectedDistrict = item
                                                activePicker = nil
                                            }
                                        )
                                    }
                                }
                            case .tahasil:
                                let filtered = viewModel.tahasils.filter {
                                    pickerSearchText.isEmpty || $0.officialName.localizedCaseInsensitiveContains(pickerSearchText) || $0.id.contains(pickerSearchText)
                                }
                                if filtered.isEmpty {
                                    EmptyListView(message: "No tahasils match \"\(pickerSearchText)\"")
                                } else {
                                    ForEach(filtered) { item in
                                        PickerRow(
                                            title: item.officialName,
                                            subtitle: "Tahasil ID: \(item.id)",
                                            isSelected: viewModel.selectedTahasil?.id == item.id,
                                            onSelect: {
                                                viewModel.selectedTahasil = item
                                                activePicker = nil
                                            }
                                        )
                                    }
                                }
                            case .village:
                                let filtered = viewModel.villages.filter {
                                    pickerSearchText.isEmpty || $0.officialName.localizedCaseInsensitiveContains(pickerSearchText) || $0.id.contains(pickerSearchText)
                                }
                                if filtered.isEmpty {
                                    EmptyListView(message: "No villages match \"\(pickerSearchText)\"")
                                } else {
                                    ForEach(filtered) { item in
                                        PickerRow(
                                            title: item.officialName,
                                            subtitle: "Village ID: \(item.id)",
                                            isSelected: viewModel.selectedVillage?.id == item.id,
                                            onSelect: {
                                                viewModel.selectedVillage = item
                                                activePicker = nil
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle(pickerTitle(for: picker))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            activePicker = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private func pickerTitle(for picker: ActivePickerSheet) -> String {
        switch picker {
        case .district: return "Select District"
        case .tahasil: return "Select Tahasil"
        case .village: return "Select Village / Mouza"
        }
    }
}

// MARK: - Supporting Subviews

private struct LocationStepRow: View {
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
            if isEnabled && !isLoading && errorMessage == nil {
                onTap()
            }
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                // Step badge
                ZStack {
                    Circle()
                        .fill(value != nil ? Theme.Color.primary : Theme.Color.secondarySurface)
                        .frame(width: 28, height: 28)
                    Text(stepNumber)
                        .font(Theme.Typography.captionMedium.weight(.bold))
                        .foregroundColor(value != nil ? .white : Theme.Color.secondaryText)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(Theme.Typography.subcaption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Color.secondaryText)
                        .tracking(0.8)
                    
                    if isLoading {
                        HStack(spacing: Theme.Spacing.xs) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading...")
                                .font(Theme.Typography.secondaryBody)
                                .foregroundColor(Theme.Color.secondaryText)
                        }
                    } else if let error = errorMessage {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Theme.Color.error)
                                .font(.caption)
                            Text("Failed to load")
                                .font(Theme.Typography.captionMedium)
                                .foregroundColor(Theme.Color.error)
                            Spacer()
                            Button("RETRY", action: onRetry)
                                .font(Theme.Typography.captionMedium.weight(.bold))
                                .foregroundColor(Theme.Color.primary)
                        }
                    } else {
                        Text(value ?? placeholder)
                            .font(Theme.Typography.secondaryBodyMedium)
                            .foregroundColor(value != nil ? Theme.Color.primaryText : Theme.Color.secondaryText.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isEnabled && !isLoading && errorMessage == nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.Color.secondaryText.opacity(0.5))
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaledButtonStyle())
        .disabled(!isEnabled || isLoading || errorMessage != nil)
        .opacity(isEnabled ? 1.0 : 0.45)
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Color.secondaryText)
            Spacer()
            Text(value)
                .font(Theme.Typography.captionMedium.weight(.semibold))
                .foregroundColor(Theme.Color.primaryText)
                .lineLimit(1)
        }
    }
}

private struct PickerRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            Theme.selectionHaptic()
            onSelect()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.secondaryBodyMedium)
                        .foregroundColor(Theme.Color.primaryText)
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Color.secondaryText)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundColor(Theme.Color.primary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? Theme.Color.primaryLight : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaledButtonStyle())
        Divider().padding(.leading, Theme.Spacing.md)
    }
}

private struct EmptyListView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(Theme.Color.secondaryText.opacity(0.5))
            Text(message)
                .font(Theme.Typography.captionMedium)
                .foregroundColor(Theme.Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }
}
