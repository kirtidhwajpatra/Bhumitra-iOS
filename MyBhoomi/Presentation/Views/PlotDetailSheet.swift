//
//  PlotDetailSheet.swift
//  MyBhoomi
//
//  ONE native multi-detent bottom sheet that unifies the plot-tap flow.
//  Tapping a plot presents this sheet at a small detent showing a COMPACT
//  plot overview; dragging UP expands to `.large` and reveals the FULL land
//  report inline as ONE continuous scroll — no separate button, no separate
//  screen.
//
//  Data source: a single `LandRecordReportViewModel(parcel:)`. The compact
//  overview binds to that view model's published `report` fields, and the full
//  report below is `LandRecordReportView(..., embedded: true)` sharing the same
//  loading lifecycle. All displayed values are real state; no fabricated data.
//
//  Design language mirrors PlotCreditBalanceSheet: Theme.Color.bhumitra* tokens,
//  .stackSansHeadline typography, clean centered layout, Theme.haptic, capsule CTA.
//

import SwiftUI
import StoreKit

struct PlotDetailSheet: View {
    let parcel: Parcel
    @ObservedObject var viewModel: MapViewModel
    let onDismiss: () -> Void

    // Single source of truth for both the compact overview and the embedded
    // full report. Bound to the parcel so both surfaces read identical state.
    @StateObject private var reportViewModel: LandRecordReportViewModel

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSubscriptionModal: Bool = false
    @State private var isUnlocking: Bool = false
    /// Drives the detent so the "Full record" hint can expand the sheet.
    @State private var isExpanded: Bool = false

    init(parcel: Parcel, viewModel: MapViewModel, onDismiss: @escaping () -> Void) {
        self.parcel = parcel
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _reportViewModel = StateObject(wrappedValue: LandRecordReportViewModel(parcel: parcel))
    }

    // MARK: - Derived Real-State Display Values (bound to the report view model)

    private var report: LandDetailsReport { reportViewModel.report }

    private var plotNumber: String {
        let p = report.property.plotNumber.value
        return p.isEmpty ? reportViewModel.identity.plotNumber : p
    }

    /// "Village · Tahasil" style subtitle, matching CadastralPlotCardView.
    private var locationSubtitle: String {
        let v = report.location.village.value
        let t = report.location.tahasil.value
        let d = report.location.district.value
        if !v.isEmpty && v != "Village" && !t.isEmpty {
            return "\(v) · \(t)"
        } else if !v.isEmpty && v != "Village" && !d.isEmpty {
            return "\(v) · \(d)"
        } else if !t.isEmpty && !d.isEmpty {
            return "\(t) · \(d)"
        } else if !v.isEmpty && v != "Village" {
            return v
        } else if !t.isEmpty {
            return t
        } else if !d.isEmpty && d != "Odisha" {
            return d
        }
        return "Land Parcel"
    }

    private var displayKhatian: String {
        if let k = report.property.khataNumber.value, !k.isEmpty { return k }
        return "—"
    }

    private var displayArea: String {
        let raw = report.area.recordedArea.value
        // "1 Acre 0000 Decimal" -> "1 acre"; keep the raw text only if unparseable.
        if let short = LandAreaFormat.primary(raw) { return short }
        if let a = raw, !a.isEmpty, a != "-" { return a }
        return "—"
    }

    private var displayLandType: String {
        if let lt = report.landParticulars.landTypeKisam.value, !lt.isEmpty, lt != "-" { return lt }
        return "—"
    }

    private var ownerCount: Int { report.ownership.totalOwnersCount }

    private var ownersSummary: String {
        let owners = report.ownership.owners
        if owners.contains(where: { $0.isGovernment }) {
            return "Government of Odisha"
        }
        if let first = owners.first?.name, !first.isEmpty {
            if ownerCount > 1 {
                return "\(first) +\(ownerCount - 1) more"
            }
            return first
        }
        switch report.rorLoadingState {
        case .loading, .idle:
            return "Checking official record…"
        default:
            return "No recorded owner particulars"
        }
    }

    private var isVerified: Bool {
        if case .loaded = report.rorLoadingState { return !report.ownership.owners.isEmpty }
        return false
    }

    /// Locked = the record on screen is (or will be) the server's masked
    /// zero-credit preview. Once a FULL record has loaded (already paid for,
    /// or a credit was spent) it is shown regardless of the current balance.
    private var isPlotLocked: Bool {
        if subscriptionManager.isUnlimited || subscriptionManager.isPremium {
            return false
        }
        if case .loaded = report.rorLoadingState {
            return reportViewModel.isPreviewRecord
        }
        // Still loading: with no credits the server will return a preview.
        return subscriptionManager.remainingPlotCredits <= 0
    }

    private var hasCredits: Bool { subscriptionManager.remainingPlotCredits > 0 }

    /// Satellite-polygon estimate — free GIS data, safe to show when locked.
    private var mapAreaEstimate: String {
        guard let acre = parcel.metadata.estimatedAreaAcre, acre > 0 else { return "—" }
        return String(format: "≈ %.2f acre", acre)
    }

    private var startingPrice: String? {
        subscriptionManager.tenPlotsProduct?.displayPrice
    }

    private func unlock() {
        guard !isUnlocking else { return }
        isUnlocking = true
        _Concurrency.Task { @MainActor in
            await reportViewModel.unlockFullRecord()
            await subscriptionManager.fetchServerCreditBalance()
            isUnlocking = false
        }
    }

    // MARK: - Body

    /// Compact detent: just enough for the overview (title, metrics, owner).
    /// Locked plots need extra room for the unlock CTA.
    private var compactHeight: CGFloat { isPlotLocked ? 284 : (showsLandValueRow ? 300 : 250) }

    private var isRecordLoading: Bool {
        switch report.rorLoadingState {
        case .loading, .idle: return true
        default: return false
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                compactOverview
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 18)

                // Same hairline the report uses between its sections, so the
                // overview reads as the first section of one document.
                Rectangle()
                    .fill(Theme.Color.bhumitraBorder)
                    .frame(height: 1)

                if isPlotLocked {
                    // Teaser: record structure + unlock. Never renders the
                    // (masked) preview values.
                    LockedRecordPreview(
                        plotNumber: plotNumber,
                        ownerCount: reportViewModel.recordOwnerCount,
                        hasCredits: hasCredits,
                        creditsLeft: subscriptionManager.remainingPlotCredits,
                        startingPrice: startingPrice,
                        isUnlocking: isUnlocking,
                        onUnlock: unlock,
                        onSeePlans: { showSubscriptionModal = true }
                    )
                } else {
                    // Full report inline, sharing THIS sheet's view model (loaded
                    // once) and THIS sheet's single background and scroll.
                    LandRecordReportView(viewModel: reportViewModel, embedded: true)
                }
            }
        }
        .background(Theme.Color.bhumitraSurface)
        .task { await reportViewModel.loadData() }
        .presentationDetents([.height(compactHeight), .large], selection: detentSelection)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Color.bhumitraSurface)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(compactHeight)))
        .presentationContentInteraction(.scrolls)
        .sheet(isPresented: $showSubscriptionModal) {
            SubscriptionView()
        }
    }

    private var detentSelection: Binding<PresentationDetent> {
        Binding(
            get: { isExpanded ? .large : .height(compactHeight) },
            set: { isExpanded = ($0 == .large) }
        )
    }

    /// A quiet hint at the bottom of the compact card: names what's inside
    /// the full record so the user knows it's worth dragging up.
    @ViewBuilder
    private var fullRecordPeek: some View {
        if !isExpanded {
            Button {
                Theme.haptic(.light)
                withAnimation(.snappy) { isExpanded = true }
            } label: {
                HStack(spacing: 6) {
                    Text("Owners, land details, location & sales")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        .lineLimit(1)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show full land record")
            .transition(.opacity)
        }
    }

    // MARK: - Land Value (compact)

    /// The value is shown on the overview itself so a user never has to open
    /// or expand anything to learn it. Hidden only when no rate exists.
    private var showsLandValueRow: Bool {
        switch report.valuationLoadingState {
        case .loading, .idle: return true
        case .loaded: return (report.valuation.benchmarkValue.value ?? 0) > 0
        default: return false
        }
    }

    private var landValueRow: some View {
        let value = report.valuation.benchmarkValue.value ?? 0
        let isLoading: Bool = {
            if case .loaded = report.valuationLoadingState { return false }
            return true
        }()
        return HStack(spacing: 10) {
            Image(systemName: "indianrupeesign.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Theme.Color.bhumitraPrimary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Govt. land value")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                Text(isLoading ? "₹00.0 lakh" : LandValueFormat.compact(value))
                    .font(.stackSansHeadline(size: 17, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .redacted(reason: isLoading ? .placeholder : [])
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Color.bhumitraPrimary.opacity(0.07))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLoading ? "Loading land value" : "Government land value \(LandValueFormat.compact(value))")
    }

    // MARK: - Compact Overview

    private var compactOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            metricsRow
            ownersSummaryRow
            if isPlotLocked {
                lockedCTA
            } else {
                if showsLandValueRow {
                    landValueRow
                }
                fullRecordPeek
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Plot \(plotNumber)")
                        .font(.stackSansHeadline(size: 24, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    if isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraSuccess)
                            .accessibilityLabel("Verified")
                    }
                }
                Text(locationSubtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !isPlotLocked {
                SheetIconButton("square.and.arrow.up", accessibilityLabel: "Share land record") {
                    reportViewModel.shareReport()
                }
            }
        }
    }

    /// Three facts in one strip, separated by hairlines — no boxed cards, so
    /// the overview sits on the same single sheet background as the report.
    private var metricsRow: some View {
        HStack(spacing: 0) {
            if isPlotLocked {
                lockedMetric(title: "Khatian")
                metricDivider
                metric(title: "Map area", value: mapAreaEstimate)
                metricDivider
                lockedMetric(title: "Land type")
            } else {
                metric(title: "Area", value: displayArea)
                metricDivider
                metric(title: "Land type", value: displayLandType)
                metricDivider
                metric(title: "Khatian", value: displayKhatian)
            }
        }
    }

    /// A value the user hasn't unlocked: fixed placeholder + lock, no data.
    private func lockedMetric(title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(SheetChrome.controlFill)
                    .frame(width: 44, height: 14)
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
            }
            .frame(height: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), locked")
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Theme.Color.bhumitraBorder)
            .frame(width: 1, height: 32)
            .padding(.horizontal, 12)
    }

    private func metric(title: String, value: String) -> some View {
        let isPending = value == "—" && isRecordLoading
        return VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
            Text(isPending ? "000000" : value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .redacted(reason: isPending ? .placeholder : [])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var lockedOwnersText: String {
        guard let n = reportViewModel.recordOwnerCount, n > 0 else { return "Owner details are in the record" }
        return n == 1 ? "1 owner on record" : "\(n) owners on record"
    }

    private var ownersSummaryRow: some View {
        HStack(spacing: 8) {
            if isPlotLocked {
                Image(systemName: "person.2")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                Text(isRecordLoading ? "Checking the official record…" : lockedOwnersText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .lineLimit(1)
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
            } else if isRecordLoading && report.ownership.owners.isEmpty {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: report.ownership.owners.contains(where: { $0.isGovernment }) ? "building.columns" : "person.2")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
            }

            Text(ownersSummary)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var lockedCTA: some View {
        if hasCredits {
            Button {
                Theme.haptic(.light)
                unlock()
            } label: {
                HStack(spacing: 8) {
                    if isUnlocking { ProgressView() } else { Image(systemName: "lock.open") }
                    Text(isUnlocking ? "Unlocking…" : "Unlock full record · 1 search")
                }
            }
            .buttonStyle(.primaryCTA)
            .allowsHitTesting(!isUnlocking)
        } else {
            VStack(spacing: 6) {
                Button {
                    Theme.haptic(.light)
                    showSubscriptionModal = true
                } label: {
                    Label("Unlock full record", systemImage: "lock.open")
                }
                .buttonStyle(.primaryCTA)
                Text(startingPrice.map { "Plans from \($0) · swipe up to see what's inside" }
                     ?? "Swipe up to see what's inside")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
