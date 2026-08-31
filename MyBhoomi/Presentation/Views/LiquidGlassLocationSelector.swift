//
//  LiquidGlassLocationSelector.swift
//  MyBhoomi
//
//  Created by Uday on 22/08/26.
//
import SwiftUI

// ============================================================
// MARK: - LIQUID GLASS LOCATION SELECTOR (MAP RESTING PILL)
// ============================================================

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
    @StateObject private var locationVM = OfficialLandRecordsViewModel()

    @State private var isModalPresented: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    public init(
        mapViewModel: MapViewModel,
        style: Style = .compact
    ) {
        self.mapViewModel = mapViewModel
        self.style = style
    }

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
        colorScheme == .dark ? Color.black.opacity(0.16) : Color.white.opacity(0.94)
    }

    public var body: some View {
        // Resting Pill Button on the Map Top-Bar
        Button {
            guard !isMapInteractionActive else { return }
            Theme.haptic(.medium)
            if locationVM.districts.isEmpty {
                locationVM.loadDistricts(force: true)
            }
            isModalPresented = true
        } label: {
            HStack(spacing: 8) {
                if isMapInteractionActive {
                    Image(systemName: "location.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? Color.white : Color(red: 20/255, green: 20/255, blue: 25/255))
                        .frame(width: 48, height: 48)
                } else {
                    Text(locationSummary)
                        .font(.system(size: 15.5, weight: .medium, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? Color.white : Color(red: 20/255, green: 20/255, blue: 25/255))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.70) : Color.black.opacity(0.60))
                }
            }
            .padding(.horizontal, isMapInteractionActive ? 0 : 16)
            .frame(height: 48)
            .frame(width: isMapInteractionActive ? 48 : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isMapInteractionActive)
        .glassEffect(
            .regular.tint(mapSurfaceTint).interactive(),
            in: Capsule()
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 8, x: 0, y: 3)
        .fullScreenCover(isPresented: $isModalPresented) {
            LocationPickerView(
                mapViewModel: mapViewModel,
                locationVM: locationVM,
                onDismiss: {
                    isModalPresented = false
                }
            )
        }
        .onAppear {
            locationVM.loadDistricts()
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
            return "Select Location"
        }()
        
        let sanitized = VillageNameSanitizer.sanitize(raw)
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 12 {
            let prefix = String(trimmed.prefix(12)).trimmingCharacters(in: .whitespaces)
            return "\(prefix)..."
        }
        return trimmed
    }
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
        case .district: return "gavel.fill"
        case .tahasil: return "building.2.fill"
        case .panchayat: return "house.and.flag.fill"
        case .village: return "house.fill"
        }
    }
}

// ============================================================
// MARK: - LOCATION FIELD STATE
// ============================================================

public enum LocationFieldState {
    case disabled
    case enabled
    case selected(String)
    case expanded(String?)
}

// ============================================================
// MARK: - REUSABLE LOCATION FIELD COMPONENT (LIQUID GLASS)
// ============================================================

public struct LocationField: View {
    public let type: LocationPickerType
    public let customTitle: String?
    public let state: LocationFieldState
    public let isLoading: Bool
    public let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(
        type: LocationPickerType,
        customTitle: String? = nil,
        state: LocationFieldState,
        isLoading: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.type = type
        self.customTitle = customTitle
        self.state = state
        self.isLoading = isLoading
        self.onTap = onTap
    }

    private var isExpanded: Bool {
        if case .expanded = state { return true }
        return false
    }

    private var isEnabled: Bool {
        if case .disabled = state { return false }
        return true
    }

    private var selectedValue: String? {
        switch state {
        case .selected(let val): return val
        case .expanded(let val): return val
        default: return nil
        }
    }

    private var accessibilityDescription: String {
        let displayTitle = customTitle ?? type.rawValue
        if let val = selectedValue, !val.isEmpty {
            return "\(displayTitle), \(val)"
        } else {
            return "\(displayTitle), \(isEnabled ? "not selected" : "disabled")"
        }
    }

    public var body: some View {
        Button {
            guard isEnabled else {
                Theme.haptic(.rigid)
                return
            }
            Theme.haptic(.light)
            onTap()
        } label: {
            HStack(spacing: 14) {
                // Left Icon: 24x24pt perfectly sized vector icon
                iconView
                    .frame(width: 24, height: 24)
                    .foregroundColor(iconColor)

                // Field Label (Single-line with tail truncation)
                Text(customTitle ?? type.rawValue)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(labelColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                // Right: Selected Value & Chevron / Loading
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                } else {
                    if let value = selectedValue, !value.isEmpty {
                        Text(value)
                            .font(.system(size: 16.5, weight: .medium, design: .rounded))
                            .foregroundColor(valueColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 135, alignment: .trailing)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(chevronColor)
                }
            }
            .padding(.horizontal, 24)
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? (isExpanded ? 0.18 : 0.06) : (isExpanded ? 0.03 : 0.01)),
                radius: isExpanded ? 6 : 3,
                x: 0,
                y: isExpanded ? 2 : 1
            )
            .opacity(isEnabled ? 1.0 : 0.78)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var iconView: some View {
        if UIImage(named: type.assetName) != nil {
            Image(type.assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: type.sfFallback)
                .resizable()
                .scaledToFit()
        }
    }

    private var iconColor: Color {
        if !isEnabled {
            return colorScheme == .dark ? Color.white.opacity(0.60) : Color(red: 130/255, green: 130/255, blue: 140/255)
        }
        return colorScheme == .dark ? Color.white.opacity(0.95) : Color(red: 25/255, green: 25/255, blue: 30/255)
    }

    private var labelColor: Color {
        if !isEnabled {
            return colorScheme == .dark ? Color.white.opacity(0.65) : Color(red: 130/255, green: 130/255, blue: 140/255)
        }
        return colorScheme == .dark ? Color.white : Color(red: 20/255, green: 20/255, blue: 25/255)
    }

    private var valueColor: Color {
        return colorScheme == .dark ? Color.white : Color(red: 20/255, green: 20/255, blue: 25/255)
    }

    private var chevronColor: Color {
        if !isEnabled {
            return colorScheme == .dark ? Color.white.opacity(0.40) : Color.black.opacity(0.30)
        }
        return colorScheme == .dark ? Color.white.opacity(0.70) : Color.black.opacity(0.55)
    }
}

// ============================================================
// MARK: - REUSABLE LOCATION OPTION LIST COMPONENT
// ============================================================

public struct LocationOptionList: View {
    public let items: [String]
    public let selectedItem: String?
    public let isLoading: Bool
    public let errorMessage: String?
    public let onRetry: (() -> Void)?
    public let onSelect: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(
        items: [String],
        selectedItem: String?,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        onRetry: (() -> Void)? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        self.items = items
        self.selectedItem = selectedItem
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.1)
                        .padding(.top, 28)
                    Text("Loading options...")
                        .font(.system(size: 15.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.orange)
                        .padding(.top, 24)

                    Text(error)
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 25/255, green: 25/255, blue: 30/255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)

                    if let onRetry = onRetry {
                        Button {
                            Theme.haptic(.medium)
                            onRetry()
                        } label: {
                            Text("Retry")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Color.accentColor))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 8) {
                    Text("No options available")
                        .font(.system(size: 15.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 28)
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items, id: \.self) { item in
                            let isSelected = (item.caseInsensitiveCompare(selectedItem ?? "") == .orderedSame)

                            Button {
                                Theme.haptic(.medium)
                                onSelect(item)
                            } label: {
                                HStack {
                                    Text(item)
                                        .font(.system(
                                            size: 18.5,
                                            weight: isSelected ? .bold : .regular,
                                            design: .default
                                        ))
                                        .foregroundColor(
                                            isSelected
                                                ? (colorScheme == .dark ? Color.white : Color(red: 15/255, green: 15/255, blue: 20/255))
                                                : (colorScheme == .dark ? Color.white.opacity(0.70) : Color(red: 70/255, green: 70/255, blue: 80/255))
                                        )
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())

                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color.accentColor)
                                    }
                                }
                                .padding(.horizontal, 26)
                                .frame(height: 54)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item)\(isSelected ? ", selected" : "")")
                        }
                    }
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 320)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color(uiColor: .secondarySystemBackground)
                        : Color.white
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.12)
                        : Color.black.opacity(0.04),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04),
            radius: 8,
            x: 0,
            y: 3
        )
    }
}

// ============================================================
// MARK: - REUSABLE LOCATION PICKER VIEW (FULL SCREEN)
// ============================================================

public struct LocationPickerView: View {
    @ObservedObject public var mapViewModel: MapViewModel
    @ObservedObject public var locationVM: OfficialLandRecordsViewModel
    public let onDismiss: () -> Void
    public var onSearchLocation: ((CadastralDistrict, CadastralBlock, CadastralGP, CadastralVillage) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var activePicker: LocationPickerType? = nil
    @State private var isSearching: Bool = false
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

    private var headerTitle: String {
        guard let active = activePicker else {
            return "Select the following"
        }
        switch active {
        case .district:
            return "Select a District"
        case .tahasil:
            return isBihar ? "Select a Circle / Anchal" : "Select a Tahsil"
        case .panchayat:
            return isBihar ? "Select a Halka" : "Select a Panchayat"
        case .village:
            return isBihar ? "Select a Mauza" : "Select a Village"
        }
    }

    private var isSearchReady: Bool {
        locationVM.selectedDistrict != nil &&
        locationVM.selectedTahasil != nil &&
        locationVM.selectedPanchayat != nil &&
        locationVM.selectedVillage != nil
    }

    public var body: some View {
        ZStack {
            // Full Screen Background
            (colorScheme == .dark
                ? Color(uiColor: .systemBackground)
                : Color(red: 242/255, green: 243/255, blue: 247/255)
            )
            .ignoresSafeArea()

            // Background touch dismiss for active dropdown
            if activePicker != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            activePicker = nil
                        }
                    }
            }

            VStack(spacing: 0) {
                // 1. Top Right Liquid Glass Close Button (x)
                HStack {
                    Spacer()
                    Button {
                        Theme.haptic(.light)
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(red: 35/255, green: 35/255, blue: 40/255))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04), radius: 6, x: 0, y: 2)
                    .accessibilityLabel("Close location selector")
                }
                .padding(.top, 16)
                .padding(.trailing, 28)

                // 2. Feature-Flagged State Switcher (Odisha / Bihar)
                if AppConfig.biharGisFeatureEnabled {
                    Picker("State", selection: $selectedStateCode) {
                        Text("Odisha").tag("OD")
                        Text("Bihar").tag("BR")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 48)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .onChange(of: selectedStateCode) { newCode in
                        activePicker = nil
                        locationVM.resetForState(newCode == "BR" ? "BIHAR" : "ODISHA")
                    }
                }

                // 3. Header Title: "Select the following" (Regular Font, Large)
                Text(headerTitle)
                    .font(.system(size: 26, weight: .regular, design: .default))
                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 20/255, green: 20/255, blue: 25/255))
                    .multilineTextAlignment(.center)
                    .padding(.top, AppConfig.biharGisFeatureEnabled ? 16 : 40)
                    .padding(.bottom, 32)
                    .animation(.easeInOut(duration: 0.2), value: headerTitle)

                // 4. Main Selection Content (Dynamic Morphing Widths with Smooth Spring)
                VStack(spacing: 11) {
                    if let active = activePicker {
                        // Single Active Row + Attached Dropdown List (Expands Outward Smoothly)
                        activePickerView(for: active)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 0.98))
                            ))
                    } else {
                        // All 4 Rows Visible with Individual State-Based Morphing Widths
                        allRowsView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity.combined(with: .scale(scale: 0.98))
                            ))
                    }
                }
                .animation(.spring(response: 0.44, dampingFraction: 0.78), value: activePicker)
                .animation(.spring(response: 0.44, dampingFraction: 0.78), value: locationVM.selectedDistrict?.id)
                .animation(.spring(response: 0.44, dampingFraction: 0.78), value: locationVM.selectedTahasil?.id)
                .animation(.spring(response: 0.44, dampingFraction: 0.78), value: locationVM.selectedPanchayat?.id)
                .animation(.spring(response: 0.44, dampingFraction: 0.78), value: locationVM.selectedVillage?.id)

                Spacer()

                // 5. Bottom Action: "Search now"
                if activePicker == nil {
                    searchNowButton
                        .padding(.horizontal, 48)
                        .padding(.bottom, 48)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            let targetState = (AppConfig.biharGisFeatureEnabled && selectedStateCode == "BR" ? "BIHAR" : "ODISHA")
            if locationVM.currentState != targetState || locationVM.districts.isEmpty {
                locationVM.resetForState(targetState)
            }
        }
    }

    // ========================================================
    // MARK: - DYNAMIC PADDING HELPER
    // ========================================================
    private func rowPadding(for type: LocationPickerType) -> CGFloat {
        if currentValue(for: type) != nil {
            return 28 // Extended width for completed / selected tier
        } else {
            return 46 // Inset padding for unselected tier
        }
    }

    // ========================================================
    // MARK: - ALL 4 ROWS VIEW
    // ========================================================
    private var allRowsView: some View {
        VStack(spacing: 11) {
            // 1. District
            LocationField(
                type: .district,
                customTitle: "District",
                state: state(for: .district),
                isLoading: locationVM.isLoadingDistricts,
                onTap: {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                        activePicker = .district
                    }
                }
            )
            .padding(.horizontal, rowPadding(for: .district))

            // 2. Tahsil / Circle
            LocationField(
                type: .tahasil,
                customTitle: isBihar ? "Circle / Anchal" : "Tahsil",
                state: state(for: .tahasil),
                isLoading: locationVM.isLoadingTahasils,
                onTap: {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                        activePicker = .tahasil
                    }
                }
            )
            .padding(.horizontal, rowPadding(for: .tahasil))

            // 3. Panchayat / Halka
            LocationField(
                type: .panchayat,
                customTitle: isBihar ? "Halka" : "Panchayat",
                state: state(for: .panchayat),
                isLoading: locationVM.isLoadingPanchayats,
                onTap: {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                        activePicker = .panchayat
                    }
                }
            )
            .padding(.horizontal, rowPadding(for: .panchayat))

            // 4. Village / Mauza
            LocationField(
                type: .village,
                customTitle: isBihar ? "Mauza" : "Village",
                state: state(for: .village),
                isLoading: locationVM.isLoadingVillages,
                onTap: {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                        activePicker = .village
                    }
                }
            )
            .padding(.horizontal, rowPadding(for: .village))
        }
    }

    // ========================================================
    // MARK: - ACTIVE PICKER VIEW (ROW + ATTACHED DROPDOWN LIST)
    // ========================================================
    private func activePickerView(for type: LocationPickerType) -> some View {
        let title: String = {
            switch type {
            case .district: return "District"
            case .tahasil: return isBihar ? "Circle / Anchal" : "Tahsil"
            case .panchayat: return isBihar ? "Halka" : "Panchayat"
            case .village: return isBihar ? "Mauza" : "Village"
            }
        }()

        return VStack(spacing: 10) {
            // 1. Pinned Active Row (Chevron Up)
            LocationField(
                type: type,
                customTitle: title,
                state: .expanded(currentValue(for: type)),
                isLoading: false,
                onTap: {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                        activePicker = nil // Re-shows all 4 rows
                    }
                }
            )

            // 2. Attached Liquid Glass Dropdown Options List
            LocationOptionList(
                items: optionsList(for: type),
                selectedItem: currentValue(for: type),
                isLoading: isLoading(for: type),
                errorMessage: errorMessage(for: type),
                onRetry: retryAction(for: type),
                onSelect: { name in
                    selectItem(name: name, for: type)
                }
            )
        }
        .padding(.horizontal, 24)
    }

    // ========================================================
    // MARK: - BOTTOM SEARCH NOW BUTTON (APPLE LIQUID GLASS CAPSULE)
    // ========================================================
    private var searchNowButton: some View {
        Button {
            guard isSearchReady, !isSearching,
                  let d = locationVM.selectedDistrict,
                  let t = locationVM.selectedTahasil,
                  let p = locationVM.selectedPanchayat,
                  let v = locationVM.selectedVillage else { return }
            Theme.haptic(.medium)

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isSearching = true
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
                    onDismiss()
                }
            }
        } label: {
            HStack(spacing: 10) {
                if isSearching {
                    ProgressView()
                        .tint(colorScheme == .dark ? Color.black : Color.white)
                        .scaleEffect(0.95)

                    Text("Loading map...")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                } else {
                    Text("Search now")
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(
                            isSearchReady
                                ? (colorScheme == .dark ? Color.black : Color.white)
                                : (colorScheme == .dark ? Color.black.opacity(0.40) : Color.white.opacity(0.40))
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Capsule()
                    .fill(
                        isSearchReady
                            ? (colorScheme == .dark ? Color.white.opacity(0.85) : Color(red: 20/255, green: 20/255, blue: 24/255).opacity(0.90))
                            : (colorScheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.25))
                    )
            )
            .contentShape(Capsule())
            .glassEffect(
                .regular.interactive(),
                in: Capsule()
            )
            .shadow(
                color: Color.black.opacity(isSearchReady ? (colorScheme == .dark ? 0.22 : 0.15) : 0.0),
                radius: 8,
                x: 0,
                y: 3
            )
            .opacity(isSearchReady ? 1.0 : 0.60)
        }
        .buttonStyle(.plain)
        .disabled(!isSearchReady || isSearching)
        .accessibilityLabel(isSearching ? "Loading map" : "Search location")
    }

    // ========================================================
    // MARK: - HELPER METHODS
    // ========================================================

    private func state(for type: LocationPickerType) -> LocationFieldState {
        switch type {
        case .district:
            if let d = locationVM.selectedDistrict?.name {
                return .selected(d)
            }
            return .enabled
        case .tahasil:
            guard locationVM.selectedDistrict != nil else { return .disabled }
            if let t = locationVM.selectedTahasil?.name {
                return .selected(t)
            }
            return .enabled
        case .panchayat:
            guard locationVM.selectedTahasil != nil else { return .disabled }
            if let p = locationVM.selectedPanchayat?.name {
                return .selected(p)
            }
            return .enabled
        case .village:
            guard locationVM.selectedPanchayat != nil || locationVM.selectedTahasil != nil else { return .disabled }
            if let v = locationVM.selectedVillage?.name {
                return .selected(v)
            }
            return .enabled
        }
    }

    private func currentValue(for type: LocationPickerType) -> String? {
        switch type {
        case .district:
            return locationVM.selectedDistrict?.name
        case .tahasil:
            return locationVM.selectedTahasil?.name
        case .panchayat:
            return locationVM.selectedPanchayat?.name
        case .village:
            return locationVM.selectedVillage?.name
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
        withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
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

            // Close the active picker so all remaining rows reappear smoothly!
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
