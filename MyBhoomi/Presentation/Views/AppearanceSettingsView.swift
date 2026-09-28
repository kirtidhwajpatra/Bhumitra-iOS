//
//  AppearanceSettingsView.swift
//  MyBhoomi
//
//  Appearance: app theme, map style, parcel rendering, visual preset,
//  land unit, outline contrast and haptics. Uses SettingsKit for a
//  consistent grouped layout with the rest of Settings.
//

import SwiftUI

public struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var viewModel: MapViewModel
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    public init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }

    private let units: [LandAreaUnit] = [.acres, .decimal, .hectares, .squareFeet, .squareMeters]

    public var body: some View {
        ZStack {
            SheetChrome.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader("Appearance", subtitle: "Changes apply immediately") { dismiss() }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        themeSection
                        mapSection
                        unitsSection
                        accessibilitySection
                    }
                    .padding(.horizontal, SettingsMetrics.horizontalPadding)
                    .padding(.top, 6)
                    .padding(.bottom, 48)
                }
            }
        }
    }

    // MARK: - Theme

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionCaption("App theme")
            HStack(spacing: 10) {
                ForEach(AppThemeMode.allCases) { mode in
                    themeOption(mode)
                }
            }
        }
    }

    private func themeOption(_ mode: AppThemeMode) -> some View {
        let isSelected = appearanceManager.themeMode == mode
        return Button {
            appearanceManager.triggerSelectionHaptic()
            withAnimation(Theme.Animation.spring) { appearanceManager.themeMode = mode }
        } label: {
            VStack(spacing: 10) {
                themePreview(mode)
                    .frame(height: 64)
                HStack(spacing: 5) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraTertiaryText)
                    Text(mode.title)
                        .font(.googleSans(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Theme.Color.bhumitraSurface)
            .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SettingsMetrics.cardRadius, style: .continuous)
                    .stroke(isSelected ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraBorder,
                            lineWidth: isSelected ? 1.5 : 0.75)
            )
        }
        .buttonStyle(ScaledButtonStyle())
        .accessibilityLabel("\(mode.title) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Miniature light/dark mock so the choice is visible, not just named.
    @ViewBuilder
    private func themePreview(_ mode: AppThemeMode) -> some View {
        switch mode {
        case .light:
            miniScreen(background: .white, bar: Color(hex: "#E5E7EB"), accent: Theme.Color.bhumitraPrimary)
        case .dark:
            miniScreen(background: Color(hex: "#15171C"), bar: Color(hex: "#2D323E"), accent: Theme.Color.bhumitraPrimary)
        case .system:
            HStack(spacing: 0) {
                miniScreen(background: .white, bar: Color(hex: "#E5E7EB"), accent: Theme.Color.bhumitraPrimary, rounded: false)
                miniScreen(background: Color(hex: "#15171C"), bar: Color(hex: "#2D323E"), accent: Theme.Color.bhumitraPrimary, rounded: false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.Color.bhumitraBorder, lineWidth: 0.75))
        }
    }

    private func miniScreen(background: Color, bar: Color, accent: Color, rounded: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: rounded ? 8 : 0, style: .continuous)
        return VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 22, height: 5)
            RoundedRectangle(cornerRadius: 3).fill(bar).frame(height: 14)
            RoundedRectangle(cornerRadius: 2).fill(bar).frame(width: 30, height: 4)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background)
        .clipShape(shape)
        .overlay(shape.stroke(rounded ? Theme.Color.bhumitraBorder : .clear, lineWidth: 0.75))
        .accessibilityHidden(true)
    }

    // MARK: - Map

    private var mapSection: some View {
        SettingsSection("Map", footer: "Boundary outline keeps the imagery visible. Shaded plots make parcels easier to tell apart.") {
            VStack(alignment: .leading, spacing: 10) {
                optionLabel("Base map", icon: "map")
                segmented(
                    options: [("Satellite", true), ("Standard", false)],
                    selection: viewModel.isSatellite
                ) { value in
                    appearanceManager.triggerHaptic(.light)
                    viewModel.isSatellite = value
                }
            }
            .padding(16)

            SettingsDivider(inset: 16)

            VStack(alignment: .leading, spacing: 10) {
                optionLabel("Plot display", icon: "square.dashed")
                segmented(
                    options: [("Outline", ParcelDisplayStyle.boundaryOnly), ("Shaded", ParcelDisplayStyle.shadedFill)],
                    selection: viewModel.parcelDisplayStyle
                ) { style in
                    appearanceManager.triggerHaptic(.light)
                    viewModel.setParcelDisplayStyle(style)
                }
            }
            .padding(16)

            SettingsDivider(inset: 16)

            VStack(alignment: .leading, spacing: 10) {
                optionLabel("Colour preset", icon: "paintpalette")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MapVisualFilter.allCases) { filter in
                            filterChip(filter)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func optionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                .accessibilityHidden(true)
            Text(title)
                .font(.googleSans(size: 15, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
        }
    }

    /// Two-option control styled like a native segmented picker, but bound to
    /// actions (the view model uses setter methods with side effects).
    private func segmented<T: Equatable>(options: [(String, T)], selection: T, onSelect: @escaping (T) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = option.1 == selection
                Button {
                    guard !isSelected else { return }
                    withAnimation(Theme.Animation.micro) { onSelect(option.1) }
                } label: {
                    Text(option.0)
                        .font(.googleSans(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? Theme.Color.bhumitraPrimaryText : Theme.Color.bhumitraSecondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isSelected ? Theme.Color.bhumitraSurface : Color.clear)
                                .shadow(color: isSelected ? Theme.Shadow.card : .clear, radius: 3, y: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.Color.bhumitraBorder)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func filterChip(_ filter: MapVisualFilter) -> some View {
        let isSelected = viewModel.visualFilter == filter
        return Button {
            appearanceManager.triggerHaptic(.light)
            viewModel.setMapFilter(filter)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(filter.displayName)
                    .font(.googleSans(size: 13.5, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraPrimaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.Color.bhumitraTint : Theme.Color.bhumitraSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Theme.Color.bhumitraPrimary : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Units

    private var unitsSection: some View {
        SettingsSection("Measurements", footer: "Used for plot areas and the land area calculator.") {
            HStack(spacing: 12) {
                SettingsIconTile("ruler", tone: .info)
                Text("Land area unit")
                    .font(.googleSans(size: 15.5, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                Spacer()
                Picker("Land area unit", selection: $appearanceManager.preferredUnit) {
                    ForEach(units, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.Color.bhumitraPrimary)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: SettingsMetrics.rowMinHeight)
        }
    }

    // MARK: - Accessibility

    private var accessibilitySection: some View {
        SettingsSection("Accessibility") {
            toggleRow(icon: "circle.lefthalf.striped.horizontal", title: "High-contrast outlines",
                      subtitle: "Thicker plot borders for bright sunlight",
                      isOn: $appearanceManager.highContrastBoundaries)
            SettingsDivider()
            toggleRow(icon: "iphone.radiowaves.left.and.right", title: "Haptic feedback",
                      subtitle: "Vibration when selecting plots and options",
                      isOn: $appearanceManager.isHapticsEnabled)
        }
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                SettingsIconTile(icon, tone: .info)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.googleSans(size: 15.5, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    Text(subtitle)
                        .font(.googleSans(size: 12.5, weight: .regular))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.Color.bhumitraPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: SettingsMetrics.rowMinHeight)
    }

    private func sectionCaption(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.googleSans(size: 12, weight: .semibold))
            .tracking(0.6)
            .foregroundColor(Theme.Color.bhumitraSecondaryText)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    AppearanceSettingsView(viewModel: MapViewModel())
}
