//
//  UPPlotCard.swift
//  MyBhoomi
//
//  Uttar Pradesh map prototype: plot details (plot no, khata, area) with a
//  link out to UP Bhulekh for the official record. Owner names are never
//  shown; the backend strips them.
//

import SwiftUI

/// Floating "UP beta" mode indicator shown on the map while viewing a UP village.
struct UPModePill: View {
    let session: UPVillageSession
    let isBusy: Bool
    let onChangeVillage: () -> Void
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onChangeVillage) {
                HStack(spacing: 8) {
                    if isBusy {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "map")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraPrimary)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(session.villageName)
                            .font(.googleSans(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            .lineLimit(1)
                        Text("UP map · beta · tap a plot")
                            .font(.googleSans(size: 11.5, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(MapChromePressStyle())
            .accessibilityLabel("Uttar Pradesh map, \(session.villageName). Change village")

            Divider().frame(height: 24)

            Button(action: onExit) {
                Text("Exit")
                    .font(.googleSans(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimary)
                    .frame(minWidth: 44, minHeight: 36)
            }
            .buttonStyle(MapChromePressStyle())
            .accessibilityLabel("Exit Uttar Pradesh map")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

struct UPPlotCard: View {
    let plot: UPPlotResult
    @ObservedObject var viewModel: MapViewModel
    let onDismiss: () -> Void

    @State private var plotQuery = ""
    @State private var isSearching = false
    @State private var searchTask: _Concurrency.Task<Void, Never>?
    @Environment(\.openURL) private var openURL

    private var session: UPVillageSession? { viewModel.upSession }

    private var totalArea: (value: Double, unit: String)? {
        let areas = plot.records.compactMap { r -> (Double, String)? in
            guard let a = r.area else { return nil }
            return (a, r.areaUnit ?? "")
        }
        guard !areas.isEmpty, Set(areas.map { $0.1 }).count == 1 else { return nil }
        return (areas.reduce(0) { $0 + $1.0 }, areas[0].1)
    }

    var body: some View {
        ZStack {
            SheetChrome.background.ignoresSafeArea()
            VStack(spacing: 0) {
                SettingsHeader("Plot \(plot.plotNo)", subtitle: locationLine, onClose: onDismiss)
                ScrollView {
                    VStack(spacing: 16) {
                        findPlotField
                        summaryCard
                        if !plot.records.isEmpty { recordsSection }
                        officialLink
                        Text(plot.note ?? "Map view (beta). Not an official record.")
                            .font(.googleSans(size: 12, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                        Text("Source: UP BhuNaksha, Govt. of Uttar Pradesh")
                            .font(.googleSans(size: 11.5, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraTertiaryText)
                    }
                    .padding(.horizontal, SettingsMetrics.horizontalPadding)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .presentationDetents([.fraction(0.42), .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.42)))
        .presentationDragIndicator(.visible)
        .onDisappear { searchTask?.cancel() }
    }

    private var locationLine: String? {
        guard let s = session else { return nil }
        return [s.villageName, s.tehsilName, s.districtName].joined(separator: " · ")
    }

    private var findPlotField: some View {
        HStack(spacing: 8) {
            Image(systemName: "number")
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                .accessibilityHidden(true)
            TextField("Find another plot number", text: $plotQuery)
                .font(.googleSans(size: 15, weight: .regular))
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.search)
                .onSubmit(search)
            if isSearching {
                ProgressView()
            } else if !plotQuery.isEmpty {
                Button("Find", action: search)
                    .font(.googleSans(size: 14, weight: .semibold))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SheetChrome.controlFill))
    }

    private func search() {
        let q = plotQuery
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty, !isSearching else { return }
        searchTask?.cancel()
        isSearching = true
        searchTask = _Concurrency.Task { @MainActor in
            let found = await viewModel.findUPPlot(number: q)
            guard !_Concurrency.Task.isCancelled else { return }
            isSearching = false
            if found { plotQuery = "" }
        }
    }

    private var summaryCard: some View {
        SettingsCard {
            SettingsRow(icon: "square.dashed", title: "Plot number", value: plot.plotNo, accessory: .none)
            SettingsDivider()
            SettingsRow(icon: "doc.text", title: "Khata entries",
                        value: plot.records.isEmpty ? "Not available" : "\(plot.records.count)", accessory: .none)
            if let total = totalArea {
                SettingsDivider()
                SettingsRow(icon: "ruler", title: "Recorded area",
                            value: "\(format(total.value)) \(total.unit)", accessory: .none)
            }
        }
    }

    private var recordsSection: some View {
        SettingsSection("Khata & sub-plots") {
            ForEach(Array(plot.records.enumerated()), id: \.offset) { idx, r in
                SettingsRow(title: "Khata \(r.khataNo)",
                            subtitle: "Plot \(r.plotNo)",
                            value: r.area.map { "\(format($0)) \(r.areaUnit ?? "")" },
                            accessory: .none)
                if idx < plot.records.count - 1 { SettingsDivider(inset: 16) }
            }
        }
    }

    private var officialLink: some View {
        Button {
            let url = plot.officialRecordUrl.flatMap(URL.init(string:)) ?? UPFeature.officialRecordURL
            openURL(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right.square")
                Text("View official record on UP Bhulekh")
            }
            .font(.googleSans(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.Color.bhumitraPrimary))
        }
        .buttonStyle(MapChromePressStyle())
        .accessibilityHint("Opens upbhulekh.gov.in in your browser")
    }

    private func format(_ v: Double) -> String {
        String(format: v < 1 ? "%.4f" : "%.3f", v)
    }
}
