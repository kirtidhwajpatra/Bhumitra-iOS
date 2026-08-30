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
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var quickFeaturesBounce = false
    @State private var premiumBounce = false
    @State private var showClaimFreeModal = false
    
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

    /// Live satellite imagery must not determine the light-mode control surface.
    private var mapControlGlassTint: Color {
        colorScheme == .dark ? Color.black.opacity(0.16) : Color.white.opacity(0.94)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Status Bar Tint & Retracting Drop Banner
            NetworkStatusBannerView()
            
            // 1. TOP FLOATING CONTROL ROW (Hero Location Selector + Fixed Top-Right Settings Button)
            ZStack(alignment: .top) {
                // Top-Right Fixed Controls (Balanced Credits Pill + Settings Button)
                HStack(spacing: 8) {
                    Spacer()
                    
                    // Plot Search Credits Pill (Custom SVG Flame + SF Pro Rounded Medium + Crisp White Pill)
                    PlotSearchCreditButton(
                        credits: subscriptionManager.remainingPlotCredits,
                        isUnlimited: subscriptionManager.isUnlimited,
                        isCoverPresented: showSubscription || showClaimFreeModal
                    ) {
                        Theme.haptic(.light)
                        if subscriptionManager.remainingPlotCredits == 0 && !subscriptionManager.isUnlimited && !subscriptionManager.isPremium {
                            showClaimFreeModal = true
                        } else {
                            showSubscription = true
                        }
                    }
                    .frame(height: 48)
                    
                    // Settings Button
                    Button {
                        Theme.haptic(.light)
                        quickFeaturesBounce.toggle()
                        showQuickFeatures = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(topBarIconColor)
                            .frame(width: 22, height: 32)
                            .symbolEffect(.bounce, value: quickFeaturesBounce)
                    }
                    .buttonStyle(.glass)
                    .tint(mapControlGlassTint)
                    .frame(height: 48) // Fixed container matching the top bar height
                    .accessibilityLabel("Settings & Digital Services")
                }
                
                // Top-Left Location Selector (Hidden when a parcel/location sheet is active)
                if viewModel.selectedParcel == nil && viewModel.selectedLocationInfo == nil {
                    HStack {
                        LiquidGlassLocationSelector(mapViewModel: viewModel, style: .compact)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.selectedParcel != nil || viewModel.selectedLocationInfo != nil)
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
        .fullScreenCover(isPresented: $showClaimFreeModal) {
            ClaimFreeCreditsModalView(
                onDismiss: {
                    showClaimFreeModal = false
                }
            )
        }
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
                        .font(.system(size: 15, weight: .medium, design: .rounded))
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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Color.primary)
                    
                    Text("Select Location")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
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

// MARK: - Plot Search Credit Pill View & SVG Flame Icon

public struct FlameIconShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 15.5684
        let sy = rect.height / 22.4258
        
        var path = Path()
        path.move(to: CGPoint(x: 13.7891 * sx, y: 10.5838 * sy))
        path.addCurve(
            to: CGPoint(x: 11.7754 * sx, y: 8.06724 * sy),
            control1: CGPoint(x: 13.1699 * sx, y: 9.70298 * sy),
            control2: CGPoint(x: 12.459 * sx, y: 8.86893 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.3379 * sx, y: 6.31646 * sy),
            control1: CGPoint(x: 11.2656 * sx, y: 7.47047 * sy),
            control2: CGPoint(x: 10.7695 * sx, y: 6.88807 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.07812 * sx, y: 4.10193 * sy),
            control1: CGPoint(x: 9.76758 * sx, y: 5.5651 * sy),
            control2: CGPoint(x: 9.31055 * sx, y: 4.83172 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.07812 * sx, y: 0.0 * sy),
            control1: CGPoint(x: 8.56641 * sx, y: 2.50933 * sy),
            control2: CGPoint(x: 8.91992 * sx, y: 0.722601 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.84375 * sx, y: 3.74961 * sy),
            control1: CGPoint(x: 7.99805 * sx, y: 0.744171 * sy),
            control2: CGPoint(x: 7.26172 * sx, y: 2.22532 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.45312 * sx, y: 7.27634 * sy),
            control1: CGPoint(x: 6.49414 * sx, y: 5.02944 * sy),
            control2: CGPoint(x: 6.36914 * sx, y: 6.34163 * sy)
        )
        path.addLine(to: CGPoint(x: 6.52344 * sx, y: 8.04208 * sy))
        path.addCurve(
            to: CGPoint(x: 6.59766 * sx, y: 10.7024 * sy),
            control1: CGPoint(x: 6.60547 * sx, y: 8.95162 * sy),
            control2: CGPoint(x: 6.67969 * sx, y: 9.92228 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.56836 * sx, y: 12.259 * sy),
            control1: CGPoint(x: 6.50781 * sx, y: 11.5616 * sy),
            control2: CGPoint(x: 6.22852 * sx, y: 12.1907 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.47266 * sx, y: 12.0757 * sy),
            control1: CGPoint(x: 5.14648 * sx, y: 12.3022 * sy),
            control2: CGPoint(x: 4.78711 * sx, y: 12.2303 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.29688 * sx, y: 10.9217 * sy),
            control1: CGPoint(x: 3.99023 * sx, y: 11.842 * sy),
            control2: CGPoint(x: 3.61719 * sx, y: 11.4142 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 2.64258 * sx, y: 9.75331 * sy),
            control1: CGPoint(x: 3.05664 * sx, y: 10.5514 * sy),
            control2: CGPoint(x: 2.8457 * sx, y: 10.1452 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 0.00195312 * sx, y: 15.02 * sy),
            control1: CGPoint(x: 1.06445 * sx, y: 11.0475 * sy),
            control2: CGPoint(x: 0.0527344 * sx, y: 12.9241 * sy)
        )
        path.addLine(to: CGPoint(x: 0.0 * sx, y: 15.2573 * sy))
        path.addCurve(
            to: CGPoint(x: 7.78516 * sx, y: 22.4258 * sy),
            control1: CGPoint(x: 0.0390625 * sx, y: 19.2226 * sy),
            control2: CGPoint(x: 3.50977 * sx, y: 22.4258 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 15.5684 * sx, y: 15.2825 * sy),
            control1: CGPoint(x: 12.0508 * sx, y: 22.4258 * sy),
            control2: CGPoint(x: 15.5137 * sx, y: 19.237 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.9238 * sx, y: 12.5251 * sy),
            control1: CGPoint(x: 15.5586 * sx, y: 14.3082 * sy),
            control2: CGPoint(x: 15.3145 * sx, y: 13.3915 * sy)
        )
        path.addLine(to: CGPoint(x: 14.8965 * sx, y: 12.4676 * sy))
        path.addCurve(
            to: CGPoint(x: 13.7891 * sx, y: 10.5838 * sy),
            control1: CGPoint(x: 14.5977 * sx, y: 11.8205 * sy),
            control2: CGPoint(x: 14.2109 * sx, y: 11.1841 * sy)
        )
        path.closeSubpath()
        return path
    }
}

public struct FlameIconView: View {
    public var width: CGFloat
    public var height: CGFloat
    public var isPressed: Bool
    
    @State private var isAnimatingHeat: Bool = false
    @State private var heatWaveProgress: CGFloat = 0.0
    @State private var flameGlowOpacity: CGFloat = 0.0
    
    public init(width: CGFloat = 14, height: CGFloat = 20, isPressed: Bool = false) {
        self.width = width
        self.height = height
        self.isPressed = isPressed
    }
    
    public var body: some View {
        ZStack {
            // 1. Ambient Warm Ember Glow (visible during landing animation and on touch)
            FlameIconShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 192/255, green: 132/255, blue: 252/255),
                            Color(red: 116/255, green: 18/255, blue: 250/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: isPressed ? 4.0 : 2.5)
                .opacity(isPressed ? 0.80 : (isAnimatingHeat ? flameGlowOpacity : 0.0))
                .scaleEffect(isPressed ? 1.14 : (isAnimatingHeat ? 1.04 : 1.0))
            
            // 2. Base Vector Flame Body (Purple / Violet Gradient)
            FlameIconShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 168/255, green: 85/255, blue: 247/255), // Top: #A855F7
                            Color(red: 106/255, green: 13/255, blue: 173/255)  // Bottom: #6A0DAD / Electric Violet
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // 3. Ascending Heat Shimmer Wave (Heat tongues rising upward through the flame body)
            FlameIconShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color(red: 233/255, green: 213/255, blue: 255/255).opacity(isPressed ? 0.95 : 0.70), location: 0.40),
                            .init(color: Color(red: 192/255, green: 132/255, blue: 252/255).opacity(isPressed ? 0.85 : 0.50), location: 0.65),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .init(x: 0.5, y: 1.2 - heatWaveProgress * 1.8),
                        endPoint: .init(x: 0.5, y: 1.8 - heatWaveProgress * 1.8)
                    )
                )
                .opacity((isAnimatingHeat || isPressed) ? 1.0 : 0.0)
                .blendMode(.screen)
        }
        .frame(width: width, height: height)
        .scaleEffect(isPressed ? 1.12 : 1.0, anchor: .bottom)
        .animation(.spring(response: 0.28, dampingFraction: 0.60), value: isPressed)
        .onAppear {
            startAppearanceAnimation()
        }
    }
    
    private func startAppearanceAnimation() {
        isAnimatingHeat = true
        
        // Rising heat shimmer wave
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
            heatWaveProgress = 1.0
        }
        
        // Gentle glow pulse
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
            flameGlowOpacity = 0.50
        }
        
        // Stop animation after 4 seconds and return to static rest
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimatingHeat = false
                flameGlowOpacity = 0.0
            }
        }
    }
}

public struct PlotSearchCreditPillView: View {
    public var credits: Int
    public var isUnlimited: Bool
    public var isPressed: Bool
    public var isCoverPresented: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var displayedCredits: Int = 0
    @State private var pendingTargetCredits: Int? = nil
    @State private var dropletBounceScale: CGFloat = 1.0
    @State private var celebratoryScale: CGFloat = 1.0
    @State private var shineOffset: CGFloat = -2.0
    @State private var isReflecting: Bool = false
    @State private var pulseFlame: Bool = false
    @State private var countTask: _Concurrency.Task<Void, Never>? = nil
    @State private var hasInitialized: Bool = false
    
    public init(
        credits: Int,
        isUnlimited: Bool = false,
        isPressed: Bool = false,
        isCoverPresented: Bool = false
    ) {
        self.credits = credits
        self.isUnlimited = isUnlimited
        self.isPressed = isPressed
        self.isCoverPresented = isCoverPresented
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            FlameIconView(width: 15, height: 21.5, isPressed: isPressed || pulseFlame)
            
            Text(isUnlimited ? "∞" : "\(displayedCredits)")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? Color.white : Color(red: 20/255, green: 20/255, blue: 24/255))
                .contentTransition(.numericText(countsDown: false))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            ZStack {
                // Adaptive Container (Crisp White in Light Mode, Sleek Elevated Dark in Dark Mode)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? Color(red: 32/255, green: 34/255, blue: 42/255)
                            : Color.white
                    )
                
                // Specular Light / Glass Reflection Beam on Successful Credit Top-Up
                if isReflecting {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.85), location: 0.45),
                            .init(color: Color(red: 255/255, green: 220/255, blue: 110/255).opacity(0.65), location: 0.55),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .offset(x: shineOffset * 70)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .shadow(
                color: isReflecting
                    ? Color(red: 245/255, green: 150/255, blue: 30/255).opacity(0.38)
                    : (colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(isPressed ? 0.20 : 0.14)),
                radius: isReflecting ? 12 : (isPressed ? 5 : 8),
                x: 0,
                y: isPressed ? 1.5 : 3
            )
        )
        .scaleEffect(dropletBounceScale * celebratoryScale)
        .onAppear {
            if !hasInitialized {
                displayedCredits = credits
                hasInitialized = true
            } else if let pending = pendingTargetCredits, !isCoverPresented {
                pendingTargetCredits = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    animateCreditChange(from: displayedCredits, to: pending)
                }
            } else if credits > displayedCredits && !isCoverPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    animateCreditChange(from: displayedCredits, to: credits)
                }
            }
        }
        .onChange(of: credits) { newTarget in
            guard hasInitialized else {
                displayedCredits = newTarget
                return
            }
            if isCoverPresented {
                // Hold animation while payment modal is actively showing over map
                pendingTargetCredits = newTarget
            } else {
                animateCreditChange(from: displayedCredits, to: newTarget)
            }
        }
        .onChange(of: isCoverPresented) { isPresented in
            if !isPresented {
                // Payment modal just dismissed - trigger immediate top-up animation on map screen
                let target = pendingTargetCredits ?? credits
                pendingTargetCredits = nil
                if target > displayedCredits {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        animateCreditChange(from: displayedCredits, to: target)
                    }
                }
            }
        }
    }
    
    private func animateCreditChange(from start: Int, to target: Int) {
        countTask?.cancel()
        
        guard target != start else { return }
        
        // If credits decrease (e.g. 1 search used), quick simple transition
        if target < start {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) {
                displayedCredits = target
                dropletBounceScale = 0.96
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.60)) {
                    dropletBounceScale = 1.0
                }
            }
            return
        }
        
        // If credits increase (Purchase / addition e.g. 20 -> 30)
        let totalDelta = target - start
        
        countTask = _Concurrency.Task { @MainActor in
            for step in 1...totalDelta {
                if _Concurrency.Task.isCancelled { break }
                
                let currentNumber = start + step
                let progress = Double(step) / Double(totalDelta)
                
                // Non-linear S-Curve timing: starts gradual, streams fast in middle, eases out at finish
                let delaySeconds: Double
                if totalDelta <= 3 {
                    delaySeconds = 0.14
                } else {
                    if progress < 0.25 {
                        // Slow start: 21, 22
                        delaySeconds = 0.15 - (progress * 0.22)
                    } else if progress < 0.78 {
                        // Fast stream: 23, 24, 25, 26, 27
                        delaySeconds = 0.042
                    } else if progress < 0.96 {
                        // Slow down: 28, 29
                        delaySeconds = 0.10 + ((progress - 0.78) * 0.32)
                    } else {
                        // Final landing step: 30
                        delaySeconds = 0.17
                    }
                }
                
                try? await _Concurrency.Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                if _Concurrency.Task.isCancelled { break }
                
                displayedCredits = currentNumber
                
                // Subtle tactile water-drop bounce with each addition ("bum, bum, bum")
                Theme.haptic(.light)
                
                withAnimation(.spring(response: 0.10, dampingFraction: 0.40)) {
                    dropletBounceScale = 1.055
                    pulseFlame = true
                }
                
                try? await _Concurrency.Task.sleep(nanoseconds: 60_000_000)
                withAnimation(.spring(response: 0.14, dampingFraction: 0.65)) {
                    dropletBounceScale = 1.0
                    pulseFlame = false
                }
            }
            
            // Final celebration when reaching the target number (e.g. 30):
            if !_Concurrency.Task.isCancelled {
                triggerSuccessCelebration()
            }
        }
    }
    
    private func triggerSuccessCelebration() {
        Theme.haptic(.medium)
        
        // 1. Success Pill Pop
        withAnimation(.spring(response: 0.36, dampingFraction: 0.52)) {
            celebratoryScale = 1.14
        }
        
        // 2. Success Specular Reflection Beam sweep
        shineOffset = -2.0
        isReflecting = true
        
        withAnimation(.easeInOut(duration: 0.72)) {
            shineOffset = 2.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.65)) {
                celebratoryScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {
            isReflecting = false
            shineOffset = -2.0
        }
    }
}

public struct PlotSearchCreditButton: View {
    public var credits: Int
    public var isUnlimited: Bool
    public var isCoverPresented: Bool
    public var action: () -> Void
    
    public init(
        credits: Int,
        isUnlimited: Bool = false,
        isCoverPresented: Bool = false,
        action: @escaping () -> Void
    ) {
        self.credits = credits
        self.isUnlimited = isUnlimited
        self.isCoverPresented = isCoverPresented
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            EmptyView()
        }
        .buttonStyle(
            PlotSearchCreditButtonStyle(
                credits: credits,
                isUnlimited: isUnlimited,
                isCoverPresented: isCoverPresented
            )
        )
        .accessibilityLabel("Search Credits")
    }
}

public struct PlotSearchCreditButtonStyle: ButtonStyle {
    public var credits: Int
    public var isUnlimited: Bool
    public var isCoverPresented: Bool
    
    public init(credits: Int, isUnlimited: Bool = false, isCoverPresented: Bool = false) {
        self.credits = credits
        self.isUnlimited = isUnlimited
        self.isCoverPresented = isCoverPresented
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        PlotSearchCreditPillView(
            credits: credits,
            isUnlimited: isUnlimited,
            isPressed: configuration.isPressed,
            isCoverPresented: isCoverPresented
        )
        .scaleEffect(configuration.isPressed ? 0.955 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var credits = 20
        @State private var isSheetOpen = false
        
        var body: some View {
            VStack(spacing: 30) {
                PlotSearchCreditPillView(
                    credits: credits,
                    isCoverPresented: isSheetOpen
                )
                
                HStack(spacing: 12) {
                    Button("+10 Plots (20 -> 30)") {
                        credits += 10
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Simulate Purchase Modal") {
                        isSheetOpen = true
                        credits += 10
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isSheetOpen = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Reset (20)") {
                        credits = 20
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(40)
            .background(Color(red: 20/255, green: 40/255, blue: 50/255))
        }
    }
    return PreviewWrapper()
}

