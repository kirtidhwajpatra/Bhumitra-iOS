//
//  LiquidGlassLocationSelector.swift
//  MyBhoomi
//
//  Created by Uday on 22/08/26.
//
import SwiftUI

// ============================================================
// MARK: - LIQUID GLASS LOCATION SELECTOR (DYNAMIC HIERARCHY ACCORDION)
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

    @State private var isExpanded = false
    @State private var openLevel: String?

    private let accent = Color.accentColor

    /// A selected parcel or map location owns the user's attention while its detail
    /// card is visible. Keep the map chrome out of the way until that interaction
    /// has been dismissed.
    private var isMapInteractionActive: Bool {
        mapViewModel.selectedParcel != nil || mapViewModel.selectedLocationInfo != nil
    }

    private var triggerWidth: CGFloat {
        if isMapInteractionActive { return 44 }
        return isExpanded ? 220 : 160
    }

    private var triggerCornerRadius: CGFloat {
        isMapInteractionActive ? 22 : (isExpanded ? 24 : 20)
    }

    private var triggerAnimation: Animation {
        .spring(response: 0.52, dampingFraction: 0.84, blendDuration: 0.16)
    }

    public init(
        mapViewModel: MapViewModel,
        style: Style = .compact
    ) {
        self.mapViewModel = mapViewModel
        self.style = style
    }

    // ========================================================
    // MARK: - BODY
    // ========================================================

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main trigger
            mainButton

            // Expanded content
            if isExpanded && !isMapInteractionActive {
                expandedContent
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(
                                with: .scale(scale: 0.96, anchor: .topLeading)
                            ),
                            removal: .opacity.combined(
                                with: .scale(scale: 0.98, anchor: .topLeading)
                            )
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(triggerAnimation, value: isMapInteractionActive)
        .animation(
            .spring(
                response: 0.38,
                dampingFraction: 0.82
            ),
            value: isExpanded
        )
        .animation(
            .spring(
                response: 0.32,
                dampingFraction: 0.82
            ),
            value: openLevel
        )
        .onAppear {
            locationVM.loadDistricts()
        }
        .onChange(of: isMapInteractionActive) { _, isActive in
            guard isActive else { return }
            withAnimation(triggerAnimation) {
                isExpanded = false
                openLevel = nil
            }
        }
    }

    // ========================================================
    // MARK: - MAIN BUTTON (Small Resting Pill -> Expands)
    // ========================================================

    @ViewBuilder
    private var mainButton: some View {
        Button {
            guard !isMapInteractionActive else { return }

            withAnimation(
                .spring(
                    response: 0.38,
                    dampingFraction: 0.82
                )
            ) {
                isExpanded.toggle()
                if isExpanded {
                    openLevel = nil
                    if locationVM.districts.isEmpty {
                        locationVM.loadDistricts(force: true)
                    }
                }
            }

            UIImpactFeedbackGenerator(
                style: .light
            ).impactOccurred()

        } label: {
            HStack {
                if isMapInteractionActive {
                    Image(systemName: "location.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 42, height: 42)
                } else {
                    Text(locationSummary)
                        .font(.googleSans(size: 15, weight: .bold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isMapInteractionActive ? 0 : 18)
            .frame(height: 42)
            .frame(width: isMapInteractionActive ? 42 : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isMapInteractionActive)
        .glassEffect(
            .regular
                .tint(.accent)
                .interactive(),
            in: Capsule()
        )
    }

    // ========================================================
    // MARK: - EXPANDED CONTENT (Accordioned Hierarchy)
    // ========================================================

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 6) {
            // TIER 1: District
            selectorRow(
                title: "District",
                value: locationVM.selectedDistrict?.name,
                options: locationVM.districts.map(\.name),
                isLoading: locationVM.isLoadingDistricts,
                isEnabled: true
            )

            // TIER 2: Tehsil (Visible when District is not open)
            if openLevel == nil || openLevel != "District" {
                selectorRow(
                    title: "Tehsil",
                    value: locationVM.selectedTahasil?.name,
                    options: locationVM.tahasils.map(\.name),
                    isLoading: locationVM.isLoadingTahasils,
                    isEnabled: locationVM.selectedDistrict != nil
                )
            }

            // TIER 3: Panchayat (Visible when neither District nor Tehsil is open)
            if openLevel == nil || (openLevel != "District" && openLevel != "Tehsil") {
                selectorRow(
                    title: "Panchayat",
                    value: locationVM.selectedPanchayat?.name,
                    options: locationVM.panchayats.map(\.name),
                    isLoading: locationVM.isLoadingPanchayats,
                    isEnabled: locationVM.selectedTahasil != nil
                )
            }

            // TIER 4: Village (Visible when no previous tier is open)
            if openLevel == nil || openLevel == "Village" {
                selectorRow(
                    title: "Village",
                    value: locationVM.selectedVillage?.name ?? mapViewModel.activeCadastralVillage?.name,
                    options: locationVM.villages.map(\.name),
                    isLoading: locationVM.isLoadingVillages,
                    isEnabled: locationVM.selectedPanchayat != nil || locationVM.selectedTahasil != nil
                )
            }
        }
        .padding(8)
        .frame(width: 220)
        .glassEffect(
            .regular
                .tint(accent.opacity(0.82))
                .interactive(),
            in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .padding(.top, 6)
    }

    // ========================================================
    // MARK: - SELECTOR ROW
    // ========================================================

    @ViewBuilder
    private func selectorRow(
        title: String,
        value: String?,
        options: [String],
        isLoading: Bool,
        isEnabled: Bool
    ) -> some View {
        let isOpen = openLevel == title

        VStack(spacing: 0) {
            Button {
                guard isEnabled else {
                    UIImpactFeedbackGenerator(
                        style: .rigid
                    ).impactOccurred()
                    return
                }

                withAnimation(
                    .spring(
                        response: 0.32,
                        dampingFraction: 0.82
                    )
                ) {
                    if openLevel == title {
                        openLevel = nil
                    } else {
                        openLevel = title
                    }
                }

                UIImpactFeedbackGenerator(
                    style: .light
                ).impactOccurred()

            } label: {
                HStack(spacing: 8) {
                    VStack(
                        alignment: .leading,
                        spacing: 1
                    ) {
                        Text(title)
                            .font(.googleSans(size: 11, weight: .semibold))
                            .opacity(
                                isEnabled ? 0.65 : 0.35
                            )

                        Text(
                            value ??
                            (isEnabled
                             ? "Select \(title.lowercased())"
                             : "Select previous first")
                        )
                        .font(.googleSans(size: 14, weight: .bold))
                        .lineLimit(1)
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(
                            systemName:
                                isOpen
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(.googleSans(size: 12, weight: .bold))
                    }
                }
                .foregroundStyle(
                    isEnabled
                    ? .white
                    : .white.opacity(0.35)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(
                        isOpen
                        ? Color.white.opacity(0.20)
                        : (isEnabled
                           ? Color.white.opacity(0.08)
                           : Color.white.opacity(0.03))
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .stroke(
                        isOpen
                        ? Color.white.opacity(0.35)
                        : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(ScaledButtonStyle())
            .disabled(!isEnabled)

            // ------------------------------------------------
            // SCROLLABLE LIST OF OPTIONS (Larger Font)
            // ------------------------------------------------
            if isOpen && isEnabled {
                VStack(spacing: 0) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.white)
                                .padding(.vertical, 16)
                            Spacer()
                        }
                    } else if options.isEmpty {
                        Text("No \(title.lowercased())s available")
                            .font(.googleSans(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.70))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(options, id: \.self) { option in
                                    Button {
                                        select(
                                            title: title,
                                            value: option
                                        )
                                    } label: {
                                        HStack {
                                            Text(option)
                                                .font(.googleSans(size: 17.5, weight: .medium))

                                            Spacer()

                                            if value == option {
                                                Image(
                                                    systemName: "checkmark"
                                                )
                                                .font(.googleSans(size: 14, weight: .bold))
                                            }
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 11)
                                        .background {
                                            if value == option {
                                                RoundedRectangle(
                                                    cornerRadius: 14,
                                                    style: .continuous
                                                )
                                                .fill(
                                                    .white.opacity(0.15)
                                                )
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 250)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.bottom, 8)
                .transition(
                    .opacity
                        .combined(
                            with: .move(
                                edge: .top
                            )
                        )
                )
            }
        }
    }

    // ========================================================
    // MARK: - SELECTION LOGIC
    // ========================================================

    private func select(
        title: String,
        value: String
    ) {
        UIImpactFeedbackGenerator(
            style: .light
        ).impactOccurred()

        withAnimation(
            .spring(
                response: 0.34,
                dampingFraction: 0.82
            )
        ) {
            switch title {
            case "District":
                if let found = locationVM.districts.first(where: { $0.name.caseInsensitiveCompare(value) == .orderedSame }) {
                    locationVM.selectDistrict(found)
                }
                openLevel = nil // Re-shows all fields with District selected

            case "Tehsil":
                if let found = locationVM.tahasils.first(where: { $0.name.caseInsensitiveCompare(value) == .orderedSame }) {
                    locationVM.selectTahasil(found)
                }
                openLevel = nil // Re-shows all fields with Tehsil selected

            case "Panchayat":
                if let found = locationVM.panchayats.first(where: { $0.name.caseInsensitiveCompare(value) == .orderedSame }) {
                    locationVM.selectPanchayat(found)
                }
                openLevel = nil // Re-shows all fields with Panchayat selected

            case "Village":
                if let found = locationVM.villages.first(where: { $0.name.caseInsensitiveCompare(value) == .orderedSame }) {
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
                    _Concurrency.Task { @MainActor in
                        await mapViewModel.loadCadastralVillage(village: enriched)
                    }
                }
                openLevel = nil
                isExpanded = false

            default:
                break
            }
        }
    }

    // ========================================================
    // MARK: - SUMMARY
    // ========================================================

    private var locationSummary: String {
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
        return "Select location"
    }

    // ========================================================
    // MARK: - STYLE VALUES
    // ========================================================

    private var cornerRadius: CGFloat {
        switch style {
        case .stacked:
            return 28
        case .compact:
            return 22
        case .floating:
            return 32
        case .large:
            return 32
        case .minimal:
            return 20
        }
    }
}

// ============================================================
// MARK: - PREVIEW
// ============================================================

#Preview {
    LiquidGlassLocationSelector(
        mapViewModel: MapViewModel(),
        style: .compact
    )
}
