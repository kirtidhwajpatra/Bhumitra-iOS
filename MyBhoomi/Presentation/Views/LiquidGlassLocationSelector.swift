//
//  LiquidGlassLocationSelector.swift
//  MyBhoomi
//
//  Created by Uday on 22/08/26.
//
import SwiftUI
import os.log

// ============================================================
// MARK: - LIQUID GLASS LOCATION SELECTOR (MAP RESTING PILL)
// ============================================================

private let locationLog = Logger(subsystem: "com.bhumitra.app", category: "LiquidGlassLocationSelector")

// MARK: - Shared Picker Helpers
//
// Visual tokens for every picker surface now live in SheetChrome.swift.

fileprivate func withNavigation(_ body: @escaping () -> Void) -> () -> Void {
    return {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82), body)
    }
}

public struct LiquidGlassLocationSelector: View {
    public enum Style {
        case stacked
        case compact
        case floating
        case large
        case minimal
    }

    public let style: Style
    @ObservedObject public var mapViewModel: MapViewModel
    /// When set, tapping the pill opens village search instead of the 4-step
    /// picker. The picker still opens via `shouldOpenLocationPicker`
    /// ("Browse by district").
    public var onSearchTap: (() -> Void)? = nil
    @StateObject private var locationVM = OfficialLandRecordsViewModel()

    @State private var isModalPresented: Bool = false
    @State private var isExtending: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    public init(
        mapViewModel: MapViewModel,
        style: Style = .compact,
        onSearchTap: (() -> Void)? = nil
    ) {
        self.mapViewModel = mapViewModel
        self.style = style
        self.onSearchTap = onSearchTap
    }

    private var isSearchFirst: Bool { onSearchTap != nil }

    // A selected parcel or map location owns the user's attention while its detail
    // card is visible. Keep the map chrome out of the way until that interaction
    // has been dismissed.
    private var isMapInteractionActive: Bool {
        mapViewModel.selectedParcel != nil || mapViewModel.selectedLocationInfo != nil
    }

    private var isLocationSelected: Bool {
        locationVM.selectedVillage != nil ||
        mapViewModel.activeCadastralVillage != nil ||
        locationVM.selectedDistrict != nil
    }

    /// Keep light-mode map chrome readable over both pale and dark map tiles.
    private var mapSurfaceTint: Color {
        Theme.Color.bhumitraMapSurface
    }

    public var body: some View {
        // Resting Pill Button on the Map Top-Bar
        Button {
            guard !isMapInteractionActive else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if let onSearchTap {
                onSearchTap()
                return
            }
            isExtending = true
            if locationVM.districts.isEmpty {
                locationVM.loadDistricts()
            }
            locationLog.debug("Location picker opened with \(locationVM.districts.count) districts ready")
            isModalPresented = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSearchFirst ? "magnifyingglass" : "mappin.and.ellipse")
                    .font(.system(size: MapChrome.iconSize, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 0) {
                    Text(locationContext)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        .lineLimit(1)

                    Text(locationSummary)
                        .font(.stackSansHeadline(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: 170, alignment: .leading)

                if !isSearchFirst {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                        .rotationEffect(.degrees(isModalPresented ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isModalPresented)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .frame(height: MapChrome.controlHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(MapChromePressStyle())
        .mapChromeSurface(in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Location: \(locationSummary), \(locationContext)")
        .accessibilityHint(isSearchFirst ? "Search for a village" : "Choose district, tahasil and village")
        .allowsHitTesting(!isMapInteractionActive)
        .sheet(isPresented: $isModalPresented, onDismiss: {
            isExtending = false
        }) {
            LocationPickerView(
                mapViewModel: mapViewModel,
                locationVM: locationVM,
                onDismiss: {
                    isExtending = false
                    isModalPresented = false
                }
            )
        }
        .onAppear {
            locationVM.loadDistricts()
            if mapViewModel.shouldOpenLocationPicker {
                mapViewModel.shouldOpenLocationPicker = false
                if let pendingName = mapViewModel.pendingDistrictSelectionName {
                    applyPendingDistrict(pendingName)
                }
                isModalPresented = true
            }
        }
        .onChange(of: mapViewModel.shouldOpenLocationPicker) { shouldOpen in
            if shouldOpen {
                mapViewModel.shouldOpenLocationPicker = false
                if let pendingName = mapViewModel.pendingDistrictSelectionName {
                    applyPendingDistrict(pendingName)
                }
                isModalPresented = true
            }
        }
        .onChange(of: locationVM.districts) { districts in
            if let pendingName = mapViewModel.pendingDistrictSelectionName, !districts.isEmpty {
                applyPendingDistrict(pendingName)
            }
        }
    }

    private func applyPendingDistrict(_ name: String) {
        if locationVM.districts.isEmpty {
            locationVM.loadDistricts(force: true)
            return
        }
        if let found = locationVM.districts.first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame ||
            $0.name.lowercased().contains(name.lowercased()) ||
            name.lowercased().contains($0.name.lowercased())
        }) {
            locationVM.selectDistrict(found)
        }
    }

    private var locationSummary: String {
        let raw: String = {
            if let v = locationVM.selectedVillage?.name ?? mapViewModel.activeCadastralVillage?.name {
                return v
            }
            if let p = locationVM.selectedPanchayat?.name {
                return p
            }
            if let t = locationVM.selectedTahasil?.name {
                return t
            }
            if let d = locationVM.selectedDistrict?.name {
                return d
            }
            return isSearchFirst ? "Search village" : "Select village"
        }()
        
        return VillageNameSanitizer.sanitize(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Small caption above the title: the parent jurisdiction of whatever is
    /// shown, so the user always knows *where* the named place sits.
    private var locationContext: String {
        let hasVillage = locationVM.selectedVillage != nil || mapViewModel.activeCadastralVillage != nil
        let district = locationVM.selectedDistrict?.name
        let tahasil = locationVM.selectedTahasil?.name

        if hasVillage || locationVM.selectedPanchayat != nil {
            return [tahasil, district].compactMap { $0 }.joined(separator: ", ").nonEmpty ?? "Odisha"
        }
        if tahasil != nil {
            return district ?? "Odisha"
        }
        return "Odisha"
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}


// ============================================================
// MARK: - LOCATION PICKER TYPE EXTENSIONS
// ============================================================

extension LocationPickerType {
    public var assetName: String {
        switch self {
        case .district: return "icon_location_district"
        case .tahasil: return "icon_location_tahsil"
        case .panchayat: return "icon_location_panchayat"
        case .village: return "icon_location_village"
        }
    }

    public var sfFallback: String {
        switch self {
        case .district: return "building.columns.fill"
        case .tahasil: return "building.2.fill"
        case .panchayat: return "house.and.flag.fill"
        case .village: return "house.fill"
        }
    }
}

// Level row → LocationSelectionCard.swift; focused list → LocationOptionPickerView.swift

// ============================================================
// MARK: - REUSABLE LOCATION PICKER VIEW (CARD-BASED REDESIGN)
// ============================================================

public struct LocationPickerView: View {
    @ObservedObject public var mapViewModel: MapViewModel
    @ObservedObject public var locationVM: OfficialLandRecordsViewModel
    public let onDismiss: () -> Void
    public var onSearchLocation: ((CadastralDistrict, CadastralBlock, CadastralGP, CadastralVillage) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var activePicker: LocationPickerType? = nil
    @State private var isSearching: Bool = false
    @State private var isSearchTransitioning: Bool = false
    @State private var selectedStateCode: String = AuthManager.shared.selectedStateCode ?? "OD"

    private var isBihar: Bool {
        AppConfig.biharGisFeatureEnabled && selectedStateCode == "BR"
    }

    public init(
        mapViewModel: MapViewModel,
        locationVM: OfficialLandRecordsViewModel,
        onDismiss: @escaping () -> Void,
        onSearchLocation: ((CadastralDistrict, CadastralBlock, CadastralGP, CadastralVillage) -> Void)? = nil
    ) {
        self.mapViewModel = mapViewModel
        self.locationVM = locationVM
        self.onDismiss = onDismiss
        self.onSearchLocation = onSearchLocation
    }

    /// Mode-aware helper copy: names all four levels using state-appropriate terms.
    private var locationSubtitleText: String {
        if isBihar {
            return "Choose your District, Circle / Anchal, Halka and Mauza."
        }
        return "Choose your District, Tahsil, Panchayat and Village."
    }

    private var isSearchReady: Bool {
        locationVM.selectedDistrict != nil &&
        locationVM.selectedTahasil != nil &&
        locationVM.selectedPanchayat != nil &&
        locationVM.selectedVillage != nil
    }

    /// Any pick (or an active map village) exists → the reset affordance appears.
    private var hasAnySelection: Bool {
        locationVM.selectedDistrict != nil || mapViewModel.activeCadastralVillage != nil
    }

    /// Clears the whole location chain and unloads the active village from the map,
    /// so the user can start a fresh selection.
    private func handleResetLocation() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            locationVM.resetAll()
            mapViewModel.clearCadastralVillage()
        }
    }

    public var body: some View {
        ZStack {
            SheetChrome.background
                .ignoresSafeArea()

            if let active = activePicker {
                // Focused Selection Experience for the Active Level
                LocationOptionPickerView(
                    type: active,
                    title: pickerTitle(for: active),
                    placeholder: searchPlaceholder(for: active),
                    items: optionsList(for: active),
                    selectedItem: currentValue(for: active),
                    isLoading: isLoading(for: active),
                    errorMessage: errorMessage(for: active),
                    onBack: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            activePicker = nil
                        }
                    },
                    onClose: onDismiss,
                    onRetry: retryAction(for: active),
                    onSelect: { name in
                        selectItem(name: name, for: active)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                // Main Screen: 4-step hierarchy on one background
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        SheetIconButton("xmark", accessibilityLabel: "Close", action: onDismiss)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, SheetChrome.inset)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Select location")
                                    .font(.stackSansHeadline(size: 26, weight: .bold))
                                    .foregroundColor(Theme.Color.bhumitraPrimaryText)

                                Text(locationSubtitleText)
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                    .lineSpacing(2)
                            }
                            .padding(.horizontal, SheetChrome.inset)
                            .padding(.top, 4)
                            .padding(.bottom, 20)

                            // State Switcher (Odisha / Bihar) if feature flag enabled
                            if AppConfig.biharGisFeatureEnabled {
                                Picker("State", selection: $selectedStateCode) {
                                    Text("Odisha").tag("OD")
                                    Text("Bihar").tag("BR")
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                                .onChange(of: selectedStateCode) { newCode in
                                    activePicker = nil
                                    locationVM.resetForState(newCode == "BR" ? "BIHAR" : "ODISHA")
                                }
                            }

                            // 4 hierarchy rows, hairline-separated (inset past the step marker)
                            VStack(spacing: 0) {
                                // 1. District Card
                                LocationSelectionCard(
                                    levelTitle: "District",
                                    selectedValue: locationVM.selectedDistrict?.name,
                                    placeholder: "Select District",
                                    iconSystemName: "building.columns.fill",
                                    stepNumber: 1,
                                    isSelected: locationVM.selectedDistrict != nil,
                                    isActive: activePicker == .district,
                                    isEnabled: true,
                                    showSkeleton: locationVM.isLoadingDistricts && locationVM.districts.isEmpty,
                                    onTap: withNavigation {
                                        activePicker = .district
                                    },
                                    onClear: locationVM.selectedDistrict != nil ? withNavigation { locationVM.clearSelection(level: .district) } : nil
                                )

                                SheetHairline().padding(.leading, 42)

                                // 2. Tahsil Card
                                LocationSelectionCard(
                                    levelTitle: isBihar ? "Circle / Anchal" : "Tahsil",
                                    selectedValue: locationVM.selectedTahasil?.name,
                                    placeholder: locationVM.selectedDistrict != nil
                                        ? (isBihar ? "Select Circle / Anchal" : "Select Tahsil")
                                        : "Select District first",
                                    iconSystemName: "building.2.fill",
                                    stepNumber: 2,
                                    isSelected: locationVM.selectedTahasil != nil,
                                    isActive: activePicker == .tahasil,
                                    isEnabled: locationVM.selectedDistrict != nil,
                                    showSkeleton: locationVM.isLoadingTahasils && locationVM.tahasils.isEmpty,
                                    onTap: withNavigation {
                                        activePicker = .tahasil
                                    },
                                    onClear: locationVM.selectedTahasil != nil ? withNavigation { locationVM.clearSelection(level: .tahasil) } : nil
                                )

                                SheetHairline().padding(.leading, 42)

                                // 3. Panchayat Card
                                LocationSelectionCard(
                                    levelTitle: isBihar ? "Halka" : "Panchayat",
                                    selectedValue: locationVM.selectedPanchayat?.name,
                                    placeholder: locationVM.selectedTahasil != nil
                                        ? (isBihar ? "Select Halka" : "Select Panchayat")
                                        : (isBihar ? "Select Circle first" : "Select Tahsil first"),
                                    iconSystemName: "person.3.fill",
                                    stepNumber: 3,
                                    isSelected: locationVM.selectedPanchayat != nil,
                                    isActive: activePicker == .panchayat,
                                    isEnabled: locationVM.selectedTahasil != nil,
                                    showSkeleton: locationVM.isLoadingPanchayats && locationVM.panchayats.isEmpty,
                                    onTap: withNavigation {
                                        activePicker = .panchayat
                                    },
                                    onClear: locationVM.selectedPanchayat != nil ? withNavigation { locationVM.clearSelection(level: .panchayat) } : nil
                                )

                                SheetHairline().padding(.leading, 42)

                                // 4. Village Card
                                LocationSelectionCard(
                                    levelTitle: isBihar ? "Mauza" : "Village",
                                    selectedValue: locationVM.selectedVillage?.name,
                                    placeholder: locationVM.selectedPanchayat != nil
                                        ? (isBihar ? "Select Mauza" : "Select Village")
                                        : (locationVM.selectedTahasil != nil
                                            ? (isBihar ? "Select Halka first" : "Select Panchayat first")
                                            : (isBihar ? "Select Circle first" : "Select Tahsil first")),
                                    iconSystemName: "house.fill",
                                    stepNumber: 4,
                                    isSelected: locationVM.selectedVillage != nil,
                                    isActive: activePicker == .village,
                                    isEnabled: locationVM.selectedPanchayat != nil,
                                    showSkeleton: locationVM.isLoadingVillages && locationVM.villages.isEmpty,
                                    onTap: withNavigation {
                                        activePicker = .village
                                    },
                                    onClear: locationVM.selectedVillage != nil ? withNavigation { locationVM.clearSelection(level: .village) } : nil
                                )
                            }
                            .padding(.horizontal, 20)

                            Spacer(minLength: 28)
                        }
                    }

                    // Bottom bar: Reset + "Search now", divided from the list by one hairline
                    SheetHairline()
                    HStack(spacing: 12) {
                        // Reset: starts a fresh location selection (clears picks + map village)
                        if hasAnySelection {
                            Button {
                                handleResetLocation()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .buttonStyle(.ctaIcon)
                            .accessibilityLabel("Reset location selection")
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }

                        PrimaryCTAButton(
                            "Search now",
                            systemImage: "arrow.right",
                            isLoading: isSearching || isSearchTransitioning,
                            loadingTitle: "Searching…",
                            isEnabled: isSearchReady,
                            showsGlowWhenDisabled: false,
                            action: handleSearchTriggered
                        )
                    }
                    .animation(.spring(response: 0.32, dampingFraction: 0.8), value: hasAnySelection)
                    .padding(.horizontal, SheetChrome.inset)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .onAppear {
            let targetState = (AppConfig.biharGisFeatureEnabled && selectedStateCode == "BR" ? "BIHAR" : "ODISHA")
            if locationVM.currentState != targetState || locationVM.districts.isEmpty {
                locationVM.resetForState(targetState)
            }
            checkAndApplyPendingDistrict()
        }
        .onChange(of: locationVM.districts) { _ in
            checkAndApplyPendingDistrict()
        }
    }

    private func checkAndApplyPendingDistrict() {
        if let pending = mapViewModel.pendingDistrictSelectionName {
            if let found = locationVM.districts.first(where: {
                $0.name.caseInsensitiveCompare(pending) == .orderedSame ||
                $0.name.lowercased().contains(pending.lowercased()) ||
                pending.lowercased().contains($0.name.lowercased())
            }) {
                locationVM.selectDistrict(found)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    activePicker = .tahasil
                }
                mapViewModel.pendingDistrictSelectionName = nil
            }
        }
    }

    // ========================================================
    // MARK: - BOTTOM SEARCH NOW BUTTON
    // ========================================================
    private func handleSearchTriggered() {
        guard isSearchReady, !isSearching, !isSearchTransitioning,
              let _ = locationVM.selectedDistrict,
              let _ = locationVM.selectedTahasil,
              let _ = locationVM.selectedPanchayat,
              let _ = locationVM.selectedVillage else { return }
        executeSearchTransition()
    }

    private func executeSearchTransition() {
        guard isSearchReady,
              let d = locationVM.selectedDistrict,
              let t = locationVM.selectedTahasil,
              let p = locationVM.selectedPanchayat,
              let v = locationVM.selectedVillage else {
            isSearchTransitioning = false
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSearching = true
            isSearchTransitioning = true
        }

        _Concurrency.Task { @MainActor in
            let stateParam = (isBihar ? "BIHAR" : "ODISHA")
            if let onSearchLocation = onSearchLocation {
                onSearchLocation(d, t, p, v)
            } else {
                await mapViewModel.loadCadastralVillage(village: v, state: stateParam)
            }

            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                isSearching = false
                isSearchTransitioning = false
                onDismiss()
            }
        }
    }

    // ========================================================
    // MARK: - TITLES & PLACEHOLDERS
    // ========================================================

    private func pickerTitle(for type: LocationPickerType) -> String {
        switch type {
        case .district: return "Select a District"
        case .tahasil: return isBihar ? "Select a Circle / Anchal" : "Select a Tahsil"
        case .panchayat: return isBihar ? "Select a Halka" : "Select a Panchayat"
        case .village: return isBihar ? "Select a Mauza" : "Select a Village"
        }
    }

    private func searchPlaceholder(for type: LocationPickerType) -> String {
        switch type {
        case .district: return "Search District..."
        case .tahasil: return isBihar ? "Search Circle / Anchal..." : "Search Tahsil..."
        case .panchayat: return isBihar ? "Search Halka..." : "Search Panchayat..."
        case .village: return isBihar ? "Search Mauza..." : "Search Village..."
        }
    }

    private func currentValue(for type: LocationPickerType) -> String? {
        switch type {
        case .district: return locationVM.selectedDistrict?.name
        case .tahasil: return locationVM.selectedTahasil?.name
        case .panchayat: return locationVM.selectedPanchayat?.name
        case .village: return locationVM.selectedVillage?.name
        }
    }

    private func isLoading(for type: LocationPickerType) -> Bool {
        switch type {
        case .district: return locationVM.isLoadingDistricts
        case .tahasil: return locationVM.isLoadingTahasils
        case .panchayat: return locationVM.isLoadingPanchayats
        case .village: return locationVM.isLoadingVillages
        }
    }

    private func errorMessage(for type: LocationPickerType) -> String? {
        switch type {
        case .district: return locationVM.districtError
        case .tahasil: return locationVM.tahasilError
        case .panchayat: return locationVM.panchayatError
        case .village: return locationVM.villageError
        }
    }

    private func retryAction(for type: LocationPickerType) -> (() -> Void)? {
        switch type {
        case .district:
            return { locationVM.loadDistricts(force: true) }
        case .tahasil:
            guard let d = locationVM.selectedDistrict else { return nil }
            return { locationVM.loadTahasils(for: d.id) }
        case .panchayat:
            guard let t = locationVM.selectedTahasil else { return nil }
            return { locationVM.loadPanchayats(blockID: t.id) }
        case .village:
            guard let t = locationVM.selectedTahasil else { return nil }
            return { locationVM.loadVillages(blockID: t.id, gpID: locationVM.selectedPanchayat?.id) }
        }
    }

    private func optionsList(for type: LocationPickerType) -> [String] {
        switch type {
        case .district:
            return locationVM.districts.map { $0.name }
        case .tahasil:
            return locationVM.tahasils.map { $0.name }
        case .panchayat:
            return locationVM.panchayats.map { $0.name }
        case .village:
            return locationVM.villages.map { $0.name }
        }
    }

    private func selectItem(name: String, for type: LocationPickerType) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            switch type {
            case .district:
                if let found = locationVM.districts.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    locationVM.selectDistrict(found)
                }
            case .tahasil:
                if let found = locationVM.tahasils.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    locationVM.selectTahasil(found)
                }
            case .panchayat:
                if let found = locationVM.panchayats.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    locationVM.selectPanchayat(found)
                }
            case .village:
                if let found = locationVM.villages.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    let enriched = CadastralVillage(
                        id: found.id,
                        name: found.name,
                        gpID: found.gpID,
                        blockID: found.blockID,
                        districtID: locationVM.selectedDistrict?.id ?? found.districtID,
                        blockName: locationVM.selectedTahasil?.name ?? found.blockName,
                        districtName: locationVM.selectedDistrict?.name ?? found.districtName
                    )
                    locationVM.selectVillage(enriched)
                }
            }
            activePicker = nil
        }
    }
}

// Backward compatibility aliases
public typealias LocationSelectionModalView = LocationPickerView
public typealias LocationPicker = LocationPickerView

// ============================================================
// MARK: - PREVIEW
// ============================================================

#Preview {
    LiquidGlassLocationSelector(
        mapViewModel: MapViewModel(),
        style: .compact
    )
}
