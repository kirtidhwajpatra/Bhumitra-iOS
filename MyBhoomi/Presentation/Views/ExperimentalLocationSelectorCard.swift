import SwiftUI

/// Top-Tier Minimalist Location Selector Card.
/// Engineered with:
/// - Prominent, elegant 19.5pt typography with generous touch targets
/// - Seamless dynamic field morphing (hiding inactive tiers, morphing into Search)
/// - Inline search clearing & auto-focus ergonomics
/// - Cascading state reset & downstream data loading
/// - Apple fluid spring dynamics and tactile haptic feedback
public struct ExperimentalLocationSelectorCard: View {
    @ObservedObject public var mapViewModel: MapViewModel
    @StateObject private var locationVM = OfficialLandRecordsViewModel()
    
    @State private var isExpanded: Bool = false
    @State private var isBouncing: Bool = false
    @State private var activePicker: LocationPickerType? = nil
    
    @FocusState private var isSearchFocused: Bool
    
    // Vibrant royal purple accent from the wireframe
    private let accentPurple = Color(red: 0.44, green: 0.10, blue: 0.98)
    
    public init(mapViewModel: MapViewModel) {
        self.mapViewModel = mapViewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isExpanded {
                collapsedPill
                    .scaleEffect(isBouncing ? 0.92 : 1.0)
            } else {
                expandedCard
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0.10), value: isExpanded)
        .animation(.spring(response: 0.34, dampingFraction: 0.80, blendDuration: 0.08), value: activePicker)
        .onAppear {
            locationVM.loadDistricts()
        }
    }
    
    // MARK: - 1. Collapsed Resting Pill ("Set location")
    private var collapsedPill: some View {
        Button(action: {
            withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) {
                isBouncing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0.10)) {
                    isBouncing = false
                    isExpanded = true
                }
            }
        }) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(uiColor: .systemGray3))
                    .frame(width: 15, height: 15)
                
                Text(currentPillTitle)
                    .font(.system(size: 17.5, weight: .medium, design: .default))
                    .foregroundColor(Color(uiColor: .label))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.96))
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.regularMaterial))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Set location")
    }
    
    // MARK: - 2. Expanded Card with Dynamic Morphing
    private var expandedCard: some View {
        VStack(alignment: .trailing, spacing: 14) {
            // Minimal Close Button (x)
            HStack {
                Spacer()
                Button(action: {
                    isSearchFocused = false
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                        activePicker = nil
                        isExpanded = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                        .padding(5)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Close location selector")
            }
            
            // Dynamic Cascading Fields
            VStack(spacing: 18) {
                districtTierView
                tahasilTierView
                panchayatTierView
                villageTierView
                loadPlotsCTAView
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .frame(width: 264)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.98))
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
        )
    }
    
    // MARK: - Sub-Tiers View Builders
    
    @ViewBuilder
    private var districtTierView: some View {
        if activePicker == nil || activePicker == .district {
            underlinedSelectorRow(
                type: .district,
                label: "District",
                selectedText: locationVM.selectedDistrict?.name,
                isEnabled: true,
                searchText: $locationVM.districtSearchText
            )
            
            if activePicker == .district {
                districtListSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    @ViewBuilder
    private var tahasilTierView: some View {
        if activePicker == nil || activePicker == .tahasil {
            underlinedSelectorRow(
                type: .tahasil,
                label: "Tehsil",
                selectedText: locationVM.selectedTahasil?.name,
                isEnabled: locationVM.selectedDistrict != nil,
                searchText: $locationVM.tahasilSearchText
            )
            
            if activePicker == .tahasil {
                tahasilListSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    @ViewBuilder
    private var panchayatTierView: some View {
        if activePicker == nil || activePicker == .panchayat {
            underlinedSelectorRow(
                type: .panchayat,
                label: "Panchayat",
                selectedText: locationVM.selectedPanchayat?.name,
                isEnabled: locationVM.selectedTahasil != nil,
                searchText: $locationVM.panchayatSearchText
            )
            
            if activePicker == .panchayat {
                panchayatListSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    @ViewBuilder
    private var villageTierView: some View {
        if activePicker == nil || activePicker == .village {
            underlinedSelectorRow(
                type: .village,
                label: "Village",
                selectedText: locationVM.selectedVillage?.name ?? mapViewModel.activeCadastralVillage?.name,
                isEnabled: locationVM.selectedPanchayat != nil || locationVM.selectedTahasil != nil,
                searchText: $locationVM.villageSearchText
            )
            
            if activePicker == .village {
                villageListSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    @ViewBuilder
    private var loadPlotsCTAView: some View {
        if activePicker == nil && (locationVM.selectedVillage != nil || mapViewModel.activeCadastralVillage != nil) {
            LiquidEmeraldButton(title: "Load plots") {
                if let village = locationVM.selectedVillage ?? mapViewModel.activeCadastralVillage {
                    _Concurrency.Task { @MainActor in
                        await mapViewModel.loadCadastralVillage(village: village)
                    }
                }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    isExpanded = false
                }
            }
            .padding(.top, 4)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }
    
    // MARK: - 3. Underlined Field Row (Large Typography + In-Place Search)
    private func underlinedSelectorRow(
        type: LocationPickerType,
        label: String,
        selectedText: String?,
        isEnabled: Bool,
        searchText: Binding<String>
    ) -> some View {
        let isActive = activePicker == type
        let hasValue = selectedText != nil && !selectedText!.isEmpty
        
        return VStack(spacing: 6) {
            Button(action: {
                guard isEnabled else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                    if activePicker == type {
                        activePicker = nil
                        isSearchFocused = false
                    } else {
                        // Reset search text to show all items cleanly
                        searchText.wrappedValue = ""
                        activePicker = type
                        isSearchFocused = true
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if isActive {
                        // In-Place Active Search Input Line
                        TextField("Search", text: searchText)
                            .font(.system(size: 19.5, weight: .regular, design: .default))
                            .foregroundColor(Color(uiColor: .label))
                            .focused($isSearchFocused)
                            .autocorrectionDisabled()
                    } else {
                        // Display Selected Value or Clean Placeholder
                        Text(selectedText ?? label)
                            .font(.system(size: 19.5, weight: hasValue ? .semibold : .regular, design: .default))
                            .foregroundColor(
                                hasValue
                                    ? Color(uiColor: .label)
                                    : (isEnabled ? Color(uiColor: .systemGray2) : Color(uiColor: .systemGray4))
                            )
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Action controls: Clear icon when searching vs Chevron indicators
                    if isActive && !searchText.wrappedValue.isEmpty {
                        Button(action: {
                            searchText.wrappedValue = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(uiColor: .tertiaryLabel))
                        }
                    } else {
                        Image(systemName: isActive ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(
                                isActive
                                    ? Color(uiColor: .label)
                                    : (isEnabled ? Color(uiColor: .systemGray2) : Color(uiColor: .systemGray4))
                            )
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isEnabled)
            
            // Minimal Baseline Underline Rule
            Rectangle()
                .fill(
                    isActive
                        ? Color(uiColor: .label).opacity(0.85)
                        : (isEnabled ? Color(uiColor: .separator).opacity(0.85) : Color(uiColor: .separator).opacity(0.35))
                )
                .frame(height: isActive ? 1.5 : 1)
        }
    }
    
    // MARK: - 4. Dropdown List: District
    @ViewBuilder
    private var districtListSection: some View {
        let currentSelectedID = locationVM.selectedDistrict?.id ?? ""
        let items = locationVM.filteredDistricts
        
        if locationVM.isLoadingDistricts {
            ProgressView()
                .tint(accentPurple)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 90)
        } else if let error = locationVM.districtError {
            VStack(spacing: 8) {
                Text(error)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    locationVM.loadDistricts(force: true)
                }) {
                    Text("Retry")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentPurple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(accentPurple.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 14)
        } else if items.isEmpty {
            VStack(spacing: 8) {
                Text("No districts found")
                    .font(.system(size: 16.5, weight: .regular))
                    .foregroundColor(Color(uiColor: .secondaryLabel))
                
                Button(action: {
                    locationVM.loadDistricts(force: true)
                }) {
                    Text("Reload")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(accentPurple)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(items) { district in
                        MinimalListRow(
                            title: district.name,
                            isSelected: district.id == currentSelectedID,
                            accentColor: accentPurple
                        ) {
                            locationVM.selectDistrict(district)
                            isSearchFocused = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                                activePicker = nil
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .frame(height: 260)
        }
    }
    
    // MARK: - 5. Dropdown List: Tehsil
    @ViewBuilder
    private var tahasilListSection: some View {
        let currentSelectedID = locationVM.selectedTahasil?.id ?? ""
        let items = locationVM.filteredTahasils
        
        if locationVM.isLoadingTahasils {
            ProgressView()
                .tint(accentPurple)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 90)
        } else if items.isEmpty {
            Text("No tehsils found")
                .font(.system(size: 16.5, weight: .regular))
                .foregroundColor(Color(uiColor: .secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(items) { tahasil in
                        MinimalListRow(
                            title: tahasil.name,
                            isSelected: tahasil.id == currentSelectedID,
                            accentColor: accentPurple
                        ) {
                            locationVM.selectTahasil(tahasil)
                            isSearchFocused = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                                activePicker = nil
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .frame(height: 260)
        }
    }
    
    // MARK: - 6. Dropdown List: Panchayat
    @ViewBuilder
    private var panchayatListSection: some View {
        let currentSelectedID = locationVM.selectedPanchayat?.id ?? ""
        let items = locationVM.filteredPanchayats
        
        if locationVM.isLoadingPanchayats {
            ProgressView()
                .tint(accentPurple)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 90)
        } else if items.isEmpty {
            Text("No panchayats found")
                .font(.system(size: 16.5, weight: .regular))
                .foregroundColor(Color(uiColor: .secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(items) { gp in
                        MinimalListRow(
                            title: gp.name,
                            isSelected: gp.id == currentSelectedID,
                            accentColor: accentPurple
                        ) {
                            locationVM.selectPanchayat(gp)
                            isSearchFocused = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                                activePicker = nil
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .frame(height: 260)
        }
    }
    
    // MARK: - 7. Dropdown List: Village
    @ViewBuilder
    private var villageListSection: some View {
        let activeID = locationVM.selectedVillage?.id ?? (mapViewModel.activeCadastralVillage?.id ?? "")
        let items = locationVM.filteredVillages
        
        if locationVM.isLoadingVillages {
            ProgressView()
                .tint(accentPurple)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 90)
        } else if items.isEmpty {
            Text("No villages found")
                .font(.system(size: 16.5, weight: .regular))
                .foregroundColor(Color(uiColor: .secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(items) { village in
                        MinimalListRow(
                            title: village.name,
                            isSelected: village.id == activeID,
                            accentColor: accentPurple
                        ) {
                            locationVM.selectVillage(village)
                            isSearchFocused = false
                            
                            _Concurrency.Task { @MainActor in
                                await mapViewModel.loadCadastralVillage(village: village)
                            }
                            
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                                activePicker = nil
                                isExpanded = false
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .frame(height: 260)
        }
    }
    
    // MARK: - Helper Titles
    private var currentPillTitle: String {
        if let v = mapViewModel.activeCadastralVillage {
            return v.name
        }
        if let d = locationVM.selectedDistrict {
            return d.name
        }
        return "Set location"
    }
}

// MARK: - Minimal List Row Component

private struct MinimalListRow: View {
    let title: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 19.5, weight: isSelected ? .bold : .regular, design: .default))
                .foregroundColor(isSelected ? accentColor : Color(uiColor: .label))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
