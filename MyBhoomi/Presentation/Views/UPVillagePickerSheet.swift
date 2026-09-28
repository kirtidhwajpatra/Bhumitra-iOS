//
//  UPVillagePickerSheet.swift
//  MyBhoomi
//
//  Uttar Pradesh map prototype: District -> Tehsil -> Village picker.
//  UP BhuNaksha lists names in Hindi only, so the filter matches Hindi text
//  and codes. English village search comes later if the prototype holds up.
//

import SwiftUI

struct UPVillagePickerSheet: View {
    @ObservedObject var viewModel: MapViewModel
    let onDismiss: () -> Void

    private enum Step: Int { case district = 1, tehsil = 2, village = 3 }

    @State private var step: Step = .district
    @State private var district: UPLevelItem?
    @State private var tehsil: UPLevelItem?
    @State private var items: [UPLevelItem] = []
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var openingVillage: String?
    @State private var openingTask: _Concurrency.Task<Void, Never>?

    var body: some View {
        ZStack {
            SheetChrome.background.ignoresSafeArea()
            VStack(spacing: 0) {
                SettingsHeader("Uttar Pradesh", subtitle: subtitle, onClose: onDismiss)
                breadcrumb
                searchField
                content
            }
        }
        .task(id: step) { await load() }
        .onDisappear { openingTask?.cancel() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var subtitle: String {
        switch step {
        case .district: return "Map view (beta) · choose a district"
        case .tehsil: return "Choose a tehsil"
        case .village: return "Choose a village"
        }
    }

    // MARK: - Breadcrumb

    @ViewBuilder
    private var breadcrumb: some View {
        if district != nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    crumb("UP") { go(to: .district) }
                    if let district {
                        chevron
                        crumb(district.name, isCurrent: step == .tehsil) { go(to: .tehsil) }
                    }
                    if let tehsil, step == .village {
                        chevron
                        crumb(tehsil.name, isCurrent: true) {}
                    }
                }
                .padding(.horizontal, SettingsMetrics.horizontalPadding)
            }
            .padding(.bottom, 8)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Theme.Color.bhumitraTertiaryText)
            .accessibilityHidden(true)
    }

    private func crumb(_ title: String, isCurrent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.googleSans(size: 13, weight: isCurrent ? .semibold : .regular))
                .foregroundColor(isCurrent ? Theme.Color.bhumitraPrimaryText : Theme.Color.bhumitraPrimary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(SheetChrome.controlFill))
        }
        .buttonStyle(MapChromePressStyle())
        .disabled(isCurrent)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                .accessibilityHidden(true)
            TextField(searchPlaceholder, text: $query)
                .font(.googleSans(size: 15, weight: .regular))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                }
                .accessibilityLabel("Clear filter")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SheetChrome.controlFill))
        .padding(.horizontal, SettingsMetrics.horizontalPadding)
        .padding(.bottom, 10)
    }

    private var searchPlaceholder: String {
        switch step {
        case .district: return "Filter \(items.count) districts (Hindi)"
        case .tehsil: return "Filter tehsils (Hindi)"
        case .village: return "Filter \(items.count) villages (Hindi)"
        }
    }

    private var filtered: [UPLevelItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.code.hasPrefix(q) }
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        if isLoading && items.isEmpty {
            Spacer()
            ProgressView().controlSize(.large)
            Spacer()
        } else if let errorMessage {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                Text(errorMessage)
                    .font(.googleSans(size: 15, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .multilineTextAlignment(.center)
                Button("Try again") { _Concurrency.Task { await load() } }
                    .font(.googleSans(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 32)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { item in
                        row(item)
                        if item.id != filtered.last?.id { SettingsDivider(inset: 16) }
                    }
                }
                .background(SheetChrome.controlFill)
                .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.cardRadius, style: .continuous))
                .padding(.horizontal, SettingsMetrics.horizontalPadding)
                .padding(.bottom, 40)

                if filtered.isEmpty && !items.isEmpty {
                    Text("No matches for “\(query)”")
                        .font(.googleSans(size: 14, weight: .regular))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        .padding(.top, 20)
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func row(_ item: UPLevelItem) -> some View {
        Button {
            Theme.selectionHaptic()
            select(item)
        } label: {
            HStack(spacing: 12) {
                Text(item.name)
                    .font(.googleSans(size: 16, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                Spacer(minLength: 8)
                if openingVillage == item.code {
                    ProgressView()
                } else {
                    Image(systemName: step == .village ? "map" : "chevron.right")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: SettingsMetrics.rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
        .disabled(openingVillage != nil)
    }

    // MARK: - Actions

    private func go(to target: Step) {
        guard target != step else { return }
        if target == .district { district = nil; tehsil = nil }
        if target == .tehsil { tehsil = nil }
        query = ""
        items = []
        step = target
    }

    private func select(_ item: UPLevelItem) {
        switch step {
        case .district:
            district = item
            go(to: .tehsil)
        case .tehsil:
            tehsil = item
            go(to: .village)
        case .village:
            open(item)
        }
    }

    private func load() async {
        let requestedStep = step
        let parents: [String]
        switch requestedStep {
        case .district: parents = []
        case .tehsil: parents = [district?.code].compactMap { $0 }
        case .village: parents = [district?.code, tehsil?.code].compactMap { $0 }
        }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await UPMapService.shared.levels(level: requestedStep.rawValue, parentCodes: parents)
            guard !Task.isCancelled, step == requestedStep else { return }
            items = result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch is CancellationError {
            return
        } catch {
            guard step == requestedStep else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load the list."
        }
        if step == requestedStep { isLoading = false }
    }

    private func open(_ village: UPLevelItem) {
        guard let district, let tehsil else { return }
        openingTask?.cancel()
        openingVillage = village.code
        openingTask = _Concurrency.Task { @MainActor in
            defer { openingVillage = nil }
            do {
                let extent = try await UPMapService.shared.villageExtent(
                    district: district.code, tehsil: tehsil.code, village: village.code)
                guard !_Concurrency.Task.isCancelled,
                      self.district?.code == district.code,
                      self.tehsil?.code == tehsil.code else { return }
                let session = UPVillageSession(
                    extent: extent, districtName: district.name,
                    tehsilName: tehsil.name, villageName: village.name)
                viewModel.enterUP(session)
                onDismiss()
            } catch is CancellationError {
                return
            } catch {
                guard !_Concurrency.Task.isCancelled else { return }
                viewModel.showToast(
                    MapViewModel.upMessage(for: error, notFound: "This village has no digital map yet"),
                    icon: "map")
            }
        }
    }
}
