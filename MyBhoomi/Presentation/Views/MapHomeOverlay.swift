import SwiftUI

/// Clean, map-first floating controls overlay for MyBhoomi home screen.
public struct MapHomeOverlay: View {
    @ObservedObject public var viewModel: MapViewModel
    @Binding public var showVillagePicker: Bool
    @Binding public var showQuickFeatures: Bool
    @Binding public var showOfficialLandRecords: Bool
    @Binding public var showLandAreaConverter: Bool
    @Binding public var showSubscription: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var quickFeaturesBounce = false
    @State private var premiumBounce = false
    
    public init(
        viewModel: MapViewModel,
        showVillagePicker: Binding<Bool>,
        showQuickFeatures: Binding<Bool>,
        showOfficialLandRecords: Binding<Bool>,
        showLandAreaConverter: Binding<Bool> = .constant(false),
        showSubscription: Binding<Bool> = .constant(false)
    ) {
        self.viewModel = viewModel
        self._showVillagePicker = showVillagePicker
        self._showQuickFeatures = showQuickFeatures
        self._showOfficialLandRecords = showOfficialLandRecords
        self._showLandAreaConverter = showLandAreaConverter
        self._showSubscription = showSubscription
    }
    
    private var topBarIconColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. TOP FLOATING CONTROL ROW (Hero Location Selector + Fixed Top-Right Settings Button)
            ZStack(alignment: .top) {
                // Top-Right Fixed Controls (Balanced Credits Pill + Settings Button)
                HStack(spacing: 8) {
                    Spacer()
                    
                    // Plot Search Credits Liquid Glass Pill (Comfortable compact size, bold prominent typography)
                    Button {
                        Theme.haptic(.light)
                        showSubscription = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: SubscriptionManager.shared.isUnlimited ? "infinity" : "bolt.fill")
                                .font(.system(size: 15, weight: .black))
                                .foregroundColor(SubscriptionManager.shared.isUnlimited ? Theme.neonPurple : (SubscriptionManager.shared.remainingPlotCredits > 0 ? Color(red: 245/255, green: 155/255, blue: 0/255) : .red))
                            
                            Text(SubscriptionManager.shared.isUnlimited ? "∞" : "\(SubscriptionManager.shared.remainingPlotCredits)")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(topBarIconColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(colorScheme == .dark ? 0.35 : 0.85),
                                                    Color.white.opacity(colorScheme == .dark ? 0.10 : 0.30)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                        }
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(TactileGlassButtonStyle())
                    .frame(height: 48)
                    .accessibilityLabel("Search Credits")
                    
                    // Settings Button
                    Button {
                        Theme.haptic(.light)
                        quickFeaturesBounce.toggle()
                        showQuickFeatures = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(topBarIconColor)
                            .frame(width: 32, height: 32)
                            .symbolEffect(.bounce, value: quickFeaturesBounce)
                    }
                    .buttonStyle(.glass)
                    .frame(height: 48) // Fixed container matching the top bar height
                    .accessibilityLabel("Settings & Digital Services")
                }
                
                // Top-Left Location Selector (Strictly Left-Anchored, expands downwards independently)
                HStack {
                    LiquidGlassLocationSelector(mapViewModel: viewModel, style: .compact)
                    Spacer()
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            
            Spacer()
            
            // 2. BOTTOM FLOATING CONTROLS (Larger Eye & Location buttons with Active Fill states)
            if viewModel.selectedParcel == nil && viewModel.selectedLocationInfo == nil {
                VStack(spacing: Theme.Spacing.md) {
                    // Trailing Floating Map Controls
                    HStack {
                        Spacer()
                        
                        // Unified Globe (Parcels) + Location Floating Glass Capsule
                        LiquidGlassMapControlsCapsule(viewModel: viewModel)
                    }
                    .padding(.leading, Theme.Spacing.md)
                    .padding(.trailing, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.lg)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.Animation.spring, value: viewModel.selectedParcel == nil)
    }
}

// MARK: - In-Place Expanding Liquid Glass Location Selector Card

public struct InPlaceLocationSelectorCard: View {
    @ObservedObject public var mapViewModel: MapViewModel
    @StateObject private var locationVM = OfficialLandRecordsViewModel()
    
    @State private var isExpanded: Bool = false
    @State private var isBouncing: Bool = false
    @State private var openSection: LocationPickerType? = nil
    
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
        .animation(.spring(response: 0.46, dampingFraction: 0.70, blendDuration: 0.12), value: isExpanded)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: openSection)
        .onAppear {
            locationVM.loadDistricts()
        }
    }
    
    // MARK: - 1. Collapsed Resting Pill (Top-Left)
    private var collapsedPill: some View {
        Button(action: {
            Theme.haptic(.medium)
            withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) {
                isBouncing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.70, blendDuration: 0.12)) {
                    isBouncing = false
                    isExpanded = true
                    if locationVM.selectedDistrict == nil {
                        openSection = .district
                    } else if locationVM.selectedTahasil == nil {
                        openSection = .tahasil
                    } else if locationVM.selectedPanchayat == nil {
                        openSection = .panchayat
                    } else if locationVM.selectedVillage == nil {
                        openSection = .village
                    }
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Color.primary)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(currentLocationTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(uiColor: .label))
                        .lineLimit(1)
                    
                    if let subtitle = currentLocationSubtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                            .lineLimit(1)
                    }
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8.5)
            .background(
                Capsule()
                    .fill(Color(uiColor: .systemBackground).opacity(0.92))
                    .background(Capsule().fill(.regularMaterial))
                    .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1.2))
                    .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Location selector")
    }
    
    // MARK: - 2. In-Place Expanded Location Panel (Compact 282pt Width & Safe Bounds)
    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Title & Close Action
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Color.primary)
                    
                    Text("Select Location")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(uiColor: .label))
                }
                
                Spacer()
                
                // Collapse Button
                Button(action: {
                    Theme.haptic(.light)
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        openSection = nil
                        isExpanded = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 1)
            
            // Selector 1: District
            selectorSection(
                type: .district,
                icon: "building.columns.fill",
                title: "District",
                selectedName: locationVM.selectedDistrict?.name,
                isEnabled: true,
                itemsCount: locationVM.filteredDistricts.count,
                isLoading: locationVM.isLoadingDistricts
            )
            
            if openSection == .district {
                districtDropdownList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Selector 2: Tahasil / Sub-District
            selectorSection(
                type: .tahasil,
                icon: "square.split.2x2.fill",
                title: "Tahsil / Block",
                selectedName: locationVM.selectedTahasil?.name,
                isEnabled: locationVM.selectedDistrict != nil,
                itemsCount: locationVM.filteredTahasils.count,
                isLoading: locationVM.isLoadingTahasils
            )
            
            if openSection == .tahasil {
                tahasilDropdownList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Selector 3: GP / Gram Panchayat
            selectorSection(
                type: .panchayat,
                icon: "building.2.crop.circle.fill",
                title: "GP / Gram Panchayat",
                selectedName: locationVM.selectedPanchayat?.name,
                isEnabled: locationVM.selectedTahasil != nil,
                itemsCount: locationVM.filteredPanchayats.count,
                isLoading: locationVM.isLoadingPanchayats
            )
            
            if openSection == .panchayat {
                panchayatDropdownList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Selector 4: Village
            selectorSection(
                type: .village,
                icon: "house.and.flag.fill",
                title: "Village",
                selectedName: locationVM.selectedVillage?.name ?? mapViewModel.activeCadastralVillage?.name,
                isEnabled: locationVM.selectedPanchayat != nil || locationVM.selectedTahasil != nil,
                itemsCount: locationVM.filteredVillages.count,
                isLoading: locationVM.isLoadingVillages
            )
            
            if openSection == .village {
                villageDropdownList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .frame(width: 282)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.96))
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.regularMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 10)
        )
    }
    
    // MARK: - Section Header Row / Button
    private func selectorSection(
        type: LocationPickerType,
        icon: String,
        title: String,
        selectedName: String?,
        isEnabled: Bool,
        itemsCount: Int,
        isLoading: Bool
    ) -> some View {
        let isOpen = openSection == type
        let isSelected = selectedName != nil
        
        return Button(action: {
            guard isEnabled else { return }
            Theme.haptic(.light)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
                if openSection == type {
                    openSection = nil
                } else {
                    openSection = type
                }
            }
        }) {
            HStack(spacing: 10) {
                // Circular Frosted Icon Badge with Distinct States
                ZStack {
                    if isOpen {
                        Circle()
                            .fill(LinearGradient(colors: [Theme.Color.primary, Theme.Color.primary.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Theme.Color.primary.opacity(0.35), radius: 5, y: 2)
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    } else if isSelected {
                        Circle()
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .overlay(Circle().stroke(Theme.Color.primary.opacity(0.4), lineWidth: 1))
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Color.primary)
                    } else {
                        Circle()
                            .fill(Color(uiColor: .tertiarySystemFill).opacity(0.6))
                        Image(systemName: icon)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(isEnabled ? Color(uiColor: .secondaryLabel) : Color(uiColor: .tertiaryLabel))
                    }
                }
                .frame(width: 28, height: 28)
                
                // Typography: Category Label + Selected Value
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(isOpen ? Theme.Color.primary : Color(uiColor: .secondaryLabel))
                        .tracking(0.4)
                    
                    if let sel = selectedName, !sel.isEmpty {
                        Text(sel)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color(uiColor: .label))
                            .lineLimit(1)
                    } else {
                        Text("Select \(title)")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(Color(uiColor: .tertiaryLabel))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Right State Trailing Indicator
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.75)
                        .tint(Theme.Color.primary)
                } else if isOpen {
                    ZStack {
                        Capsule()
                            .fill(Theme.Color.primary.opacity(0.14))
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.Color.primary)
                    }
                    .frame(width: 26, height: 20)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Color.primary.opacity(0.85))
                } else {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(uiColor: .tertiaryLabel))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8.5)
            .background(
                Group {
                    if isOpen {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Theme.Color.primary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Theme.Color.primary, Theme.Color.primary.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: Theme.Color.primary.opacity(0.12), radius: 8, y: 3)
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemFill).opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                            )
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.50)
    }
    
    // MARK: - 3. In-Place District Dropdown (Drawer Well)
    private var districtDropdownList: some View {
        VStack(spacing: 6) {
            // Glass Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Color.primary)
                
                TextField("Search district...", text: $locationVM.districtSearchText)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(Color(uiColor: .label))
                
                if !locationVM.districtSearchText.isEmpty {
                    Button(action: { locationVM.districtSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.90))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
            )
            .padding(.horizontal, 2)
            
            // Scrollable list showing 5-6 items
            let selectedDistID = locationVM.selectedDistrict?.id
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 3) {
                    ForEach(locationVM.filteredDistricts) { district in
                        DistrictSelectorRowItem(
                            name: district.name,
                            isChosen: district.id == selectedDistID,
                            onSelect: {
                                handleDistrictSelected(district)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 195)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .systemFill).opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 4. In-Place Tahasil Dropdown (Drawer Well)
    private var tahasilDropdownList: some View {
        VStack(spacing: 6) {
            // Glass Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Color.primary)
                
                TextField("Search tahsil...", text: $locationVM.tahasilSearchText)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(Color(uiColor: .label))
                
                if !locationVM.tahasilSearchText.isEmpty {
                    Button(action: { locationVM.tahasilSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.90))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
            )
            .padding(.horizontal, 2)
            
            if locationVM.filteredTahasils.isEmpty {
                VStack(spacing: 6) {
                    if locationVM.isLoadingTahasils {
                        ProgressView()
                            .tint(Theme.Color.primary)
                        Text("Loading tahsils...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    } else {
                        Text("No tahsils found")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
                .frame(height: 110)
            } else {
                let selectedTahID = locationVM.selectedTahasil?.id
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 3) {
                        ForEach(locationVM.filteredTahasils) { tahasil in
                            TahasilSelectorRowItem(
                                name: tahasil.name,
                                isChosen: tahasil.id == selectedTahID,
                                onSelect: {
                                    handleTahasilSelected(tahasil)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 195)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .systemFill).opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 5. In-Place GP / Gram Panchayat Dropdown (Drawer Well)
    private var panchayatDropdownList: some View {
        VStack(spacing: 6) {
            // Glass Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Color.primary)
                
                TextField("Search gram panchayat...", text: $locationVM.panchayatSearchText)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(Color(uiColor: .label))
                
                if !locationVM.panchayatSearchText.isEmpty {
                    Button(action: { locationVM.panchayatSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.90))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
            )
            .padding(.horizontal, 2)
            
            if locationVM.filteredPanchayats.isEmpty {
                VStack(spacing: 6) {
                    if locationVM.isLoadingPanchayats {
                        ProgressView()
                            .tint(Theme.Color.primary)
                        Text("Loading gram panchayats...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    } else {
                        Text("No gram panchayats found")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
                .frame(height: 110)
            } else {
                let selectedGPID = locationVM.selectedPanchayat?.id
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 3) {
                        ForEach(locationVM.filteredPanchayats) { gp in
                            PanchayatSelectorRowItem(
                                name: gp.name,
                                isChosen: gp.id == selectedGPID,
                                onSelect: {
                                    handlePanchayatSelected(gp)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 195)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .systemFill).opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 6. In-Place Village Dropdown (Drawer Well)
    private var villageDropdownList: some View {
        VStack(spacing: 6) {
            // Glass Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Color.primary)
                
                TextField("Search village...", text: $locationVM.villageSearchText)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(Color(uiColor: .label))
                
                if !locationVM.villageSearchText.isEmpty {
                    Button(action: { locationVM.villageSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.90))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
            )
            .padding(.horizontal, 2)
            
            if locationVM.filteredVillages.isEmpty {
                VStack(spacing: 6) {
                    if locationVM.isLoadingVillages {
                        ProgressView()
                            .tint(Theme.Color.primary)
                        Text("Loading villages...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    } else {
                        Text("No villages found")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
                .frame(height: 110)
            } else {
                let activeVillageID = locationVM.selectedVillage?.id ?? mapViewModel.activeCadastralVillage?.id
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 3) {
                        ForEach(locationVM.filteredVillages) { village in
                            VillageSelectorRowItem(
                                village: village,
                                isChosen: village.id == activeVillageID,
                                onSelect: {
                                    handleVillageSelected(village)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 195)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .systemFill).opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Handlers & Helpers
    private func handleDistrictSelected(_ district: CadastralDistrict) {
        Theme.haptic(.light)
        locationVM.selectDistrict(district)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            openSection = .tahasil
        }
    }
    
    private func handleTahasilSelected(_ tahasil: CadastralBlock) {
        Theme.haptic(.light)
        locationVM.selectTahasil(tahasil)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            openSection = .panchayat
        }
    }
    
    private func handlePanchayatSelected(_ gp: CadastralGP) {
        Theme.haptic(.light)
        locationVM.selectPanchayat(gp)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            openSection = .village
        }
    }
    
    private func handleVillageSelected(_ village: CadastralVillage) {
        Theme.haptic(.medium)
        locationVM.selectVillage(village)
        
        _Concurrency.Task { @MainActor in
            await mapViewModel.loadCadastralVillage(village: village)
        }
        
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            openSection = nil
            isExpanded = false
        }
    }
    
    private var currentLocationTitle: String {
        if let v = mapViewModel.activeCadastralVillage {
            return v.name
        }
        return "Select Location"
    }
    
    private var currentLocationSubtitle: String? {
        if let v = mapViewModel.activeCadastralVillage {
            if let d = v.districtName, !d.isEmpty {
                return d
            }
            return v.blockName
        }
        return nil
    }
}

// MARK: - Row Subviews for Distinct High-Contrast Liquid Glass Items

private struct DistrictSelectorRowItem: View {
    let name: String
    let isChosen: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                if isChosen {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.primary.opacity(0.20))
                        .frame(width: 5, height: 5)
                        .padding(.leading, 3)
                }
                
                Text(name)
                    .font(.system(size: 14.5, weight: isChosen ? .bold : .medium, design: .rounded))
                    .foregroundColor(isChosen ? .white : Color(uiColor: .label))
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isChosen {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Color.primary, Theme.Color.primary.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Theme.Color.primary.opacity(0.30), radius: 5, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.clear)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct TahasilSelectorRowItem: View {
    let name: String
    let isChosen: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                if isChosen {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.primary.opacity(0.20))
                        .frame(width: 5, height: 5)
                        .padding(.leading, 3)
                }
                
                Text(name)
                    .font(.system(size: 14.5, weight: isChosen ? .bold : .medium, design: .rounded))
                    .foregroundColor(isChosen ? .white : Color(uiColor: .label))
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isChosen {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Color.primary, Theme.Color.primary.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Theme.Color.primary.opacity(0.30), radius: 5, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.clear)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct PanchayatSelectorRowItem: View {
    let name: String
    let isChosen: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                if isChosen {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.primary.opacity(0.20))
                        .frame(width: 5, height: 5)
                        .padding(.leading, 3)
                }
                
                Text(name)
                    .font(.system(size: 14.5, weight: isChosen ? .bold : .medium, design: .rounded))
                    .foregroundColor(isChosen ? .white : Color(uiColor: .label))
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isChosen {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Color.primary, Theme.Color.primary.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Theme.Color.primary.opacity(0.30), radius: 5, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.clear)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct VillageSelectorRowItem: View {
    let village: CadastralVillage
    let isChosen: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                if isChosen {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.primary.opacity(0.20))
                        .frame(width: 5, height: 5)
                        .padding(.leading, 3)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(village.name)
                        .font(.system(size: 14.5, weight: isChosen ? .bold : .medium, design: .rounded))
                        .foregroundColor(isChosen ? .white : Color(uiColor: .label))
                    
                    if !village.id.isEmpty {
                        Text("ID: \(village.id)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(isChosen ? Color.white.opacity(0.8) : Color(uiColor: .secondaryLabel))
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Group {
                    if isChosen {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Color.primary, Theme.Color.primary.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Theme.Color.primary.opacity(0.30), radius: 5, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.clear)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
