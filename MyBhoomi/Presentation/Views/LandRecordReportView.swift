//
//  LandRecordReportView.swift
//  MyBhoomi
//
//  Full-screen Official Land Record Report for Bhumitra ("Land Details").
//  High-performance, information-dense, native government document feel.
//  Prioritizes DATA CORRECTNESS, SOURCE TRACEABILITY, READABILITY, AND COMPLETENESS.
//  Zero fabricated data, zero fake zeroes, zero invented statuses.
//

import SwiftUI
import CoreLocation
import UIKit

// MARK: - Activity View Controller Representable for Sharing

public struct ActivityViewSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Design & Typography Tokens (Native SF Pro)

private enum ReportTokens {
    static let pageTitle = Font.system(size: 17, weight: .semibold)
    static let pageSubtitle = Font.system(size: 13, weight: .regular)
    static let sectionTitle = Font.system(size: 17, weight: .semibold)
    static let sectionSubtitle = Font.system(size: 13, weight: .regular)
    static let ownerName = Font.system(size: 17, weight: .semibold)
    static let rowLabel = Font.system(size: 14, weight: .regular)
    static let rowValue = Font.system(size: 15, weight: .medium)
    static let rowValueBold = Font.system(size: 15, weight: .semibold)
    static let rowValueLarge = Font.system(size: 17, weight: .semibold)
    static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoBold = Font.system(size: 13, weight: .semibold, design: .monospaced)
    static let caption = Font.system(size: 13, weight: .regular)
    static let captionMedium = Font.system(size: 13, weight: .medium)
    
    // Background, ink and divider tokens — ADAPTIVE (light + dark).
    // The full-screen report still pins `.preferredColorScheme(.dark)`, so it
    // renders exactly as before; the embedded sheet follows the system theme.
    /// Primary text / glyph colour, and the base for all tinted fills.
    static let ink = Theme.Color.dynamic(
        light: UIColor(red: 17/255, green: 20/255, blue: 24/255, alpha: 1),
        dark: UIColor.white
    )
    static let darkBackground = Theme.Color.dynamic(
        light: UIColor.white,
        dark: UIColor(red: 13/255, green: 14/255, blue: 18/255, alpha: 1) // #0D0E12
    )
    static let cardFill = ink.opacity(0.04)
    static let hairline = ink.opacity(0.08)
    /// Same hairline token the host sheet uses, so section breaks match exactly.
    static let prominentDivider = Theme.Color.bhumitraBorder
    static let secondaryText = Theme.Color.dynamic(
        light: UIColor(red: 90/255, green: 96/255, blue: 106/255, alpha: 1),
        dark: UIColor(red: 156/255, green: 163/255, blue: 175/255, alpha: 1) // #9CA3AF
    )
    static let accentLine = Color(red: 99/255, green: 102/255, blue: 241/255) // Indigo/Purple accent
    
    static let dangerRed = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let successGreen = Color(red: 34/255, green: 197/255, blue: 94/255)
    static let brandGold = Theme.Color.dynamic(
        light: UIColor(red: 161/255, green: 98/255, blue: 7/255, alpha: 1),  // #A16207, readable on white
        dark: UIColor(red: 234/255, green: 179/255, blue: 8/255, alpha: 1)   // #EAB308
    )
}

// MARK: - Static Precomputed Formatters (Performance Optimization)

private enum ReportFormatters {
    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₹"
        f.locale = Locale(identifier: "en_IN")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()
    
    static func formatMoney(_ value: Double) -> String {
        let hasFraction = abs(value.truncatingRemainder(dividingBy: 1)) > 0.001
        currencyFormatter.maximumFractionDigits = hasFraction ? 2 : 0
        return currencyFormatter.string(from: NSNumber(value: value)) ?? "₹\(String(format: "%.2f", value))"
    }
}

// MARK: - Odia Script Awareness

private enum OdiaScriptSupport {
    static func containsOdiaScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { ($0.value >= 0x0B00 && $0.value <= 0x0B7F) }
    }
    
    static func font(size: CGFloat, weight: Font.Weight = .regular, value: String) -> Font {
        // System font handles both Latin and Odia Unicode glyphs flawlessly without fallback penalty
        return .system(size: size, weight: weight)
    }
}

// MARK: - Section Identifiers for Local Expand / Collapse

private enum ReportSectionId: String, CaseIterable, Hashable {
    case owners
    case location
    case salesHistory
    case benchmarkValue
    case land
    case remarks
}

// MARK: - Main Land Record Report View

public struct LandRecordReportView: View {
    @StateObject private var viewModel: LandRecordReportViewModel
    @Environment(\.dismiss) private var dismiss

    /// When true, the view renders ONLY its inner scrollable content (no
    /// NavigationView, back button, principal title, navigation style, or dark
    /// color-scheme override) so it can be nested inline inside a parent sheet
    /// (see PlotDetailSheet). Full-screen callers leave this false and get the
    /// unchanged self-contained chrome.
    private let embedded: Bool

    // Local, lightweight section expansion state
    // Default collapsed on landing: user clicks to view any section
    @State private var expandedSections: Set<ReportSectionId> = []
    @State private var showAssociatedPlotSheet: Bool = false
    @State private var showValuationInputSheet: Bool = false
    @State private var showMoreRates: Bool = false
    
    private var areAllSectionsExpanded: Bool {
        var required: [ReportSectionId] = [.benchmarkValue, .owners, .location, .land, .salesHistory]
        if viewModel.report.remarks.hasContent {
            required.append(.remarks)
        }
        return required.allSatisfy { expandedSections.contains($0) }
    }
    
    public init(parcel: Parcel, embedded: Bool = false) {
        self.embedded = embedded
        _viewModel = StateObject(wrappedValue: LandRecordReportViewModel(parcel: parcel))
    }
    
    public init(result: OfficialSearchResult, parcel: Parcel? = nil, embedded: Bool = false) {
        self.embedded = embedded
        _viewModel = StateObject(wrappedValue: LandRecordReportViewModel(result: result, parcel: parcel))
    }
    
    public init(identity: CanonicalParcelIdentity, ror: RoRResponse?, valuation: BenchmarkValuation? = nil, parcel: Parcel? = nil, embedded: Bool = false) {
        self.embedded = embedded
        _viewModel = StateObject(wrappedValue: LandRecordReportViewModel(identity: identity, ror: ror, valuation: valuation, parcel: parcel))
    }

    /// Hosts an EXISTING view model so a parent (PlotDetailSheet) and this
    /// report read one shared, once-loaded state instead of two copies.
    public init(viewModel: LandRecordReportViewModel, embedded: Bool = true) {
        self.embedded = embedded
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    private func toggleSection(_ section: ReportSectionId) {
        withAnimation(.easeInOut(duration: 0.20)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }
    
    // Human-readable parcel identifier — single source of truth from the builder.
    // The view MUST NOT synthesize its own; a divergent "Parcel ID" on screen vs.
    // share text / saved records is a data-trust bug.
    private var canonicalParcelID: String {
        viewModel.report.property.displayParcelID.value ?? "Not available"
    }
    
    public var body: some View {
        if embedded {
            // Inline mode: render ONLY the section column so it nests inside a
            // parent sheet's own scroll/detent stack. No NavigationView, no
            // toolbar, no background, no colour-scheme override — the parent
            // owns those (and hosts Share in its own header). Data loading is
            // also owned by the parent, which shares this view model.
            embeddedReportContent
                .sheet(isPresented: $viewModel.showShareSheet) {
                    ActivityViewSheet(activityItems: viewModel.shareItems)
                }
                .sheet(isPresented: $showAssociatedPlotSheet) {
                    associatedPlotsSheet
                }
                .sheet(isPresented: $showValuationInputSheet) {
                    LandValuationInputSheet(viewModel: viewModel)
                }
        } else {
            NavigationView {
                reportScrollContent
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 16, weight: .regular))
                                }
                                .foregroundColor(ReportTokens.ink)
                            }
                        }
                        
                        ToolbarItem(placement: .principal) {
                            Text("Land Details")
                                .font(ReportTokens.pageTitle)
                                .foregroundColor(ReportTokens.ink)
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { viewModel.shareReport() }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(ReportTokens.ink)
                            }
                        }
                    }
                    .task {
                        await viewModel.loadData()
                    }
                    .sheet(isPresented: $viewModel.showShareSheet) {
                        ActivityViewSheet(activityItems: viewModel.shareItems)
                    }
                    .sheet(isPresented: $showAssociatedPlotSheet) {
                        associatedPlotsSheet
                    }
                    .sheet(isPresented: $showValuationInputSheet) {
                        LandValuationInputSheet(viewModel: viewModel)
                    }
            }
            .navigationViewStyle(.stack)
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - Inner Scrollable Report Content (chrome-free, reused embedded & full-screen)
    
    private var reportScrollContent: some View {
        ZStack {
            // True full-screen background edge-to-edge
            ReportTokens.darkBackground
                .ignoresSafeArea()
            
            // Single primary vertical ScrollView for 60/120 FPS native scrolling
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: true) {
                    reportSections(scrollProxy: scrollProxy)
                }
                .refreshable {
                    viewModel.retry()
                }
            }
        }
    }

    /// Embedded variant: NO inner ScrollView and NO ScrollViewReader. The
    /// parent sheet (PlotDetailSheet) owns the one and only scroll, so the
    /// report sections render as a plain column that flows into that scroll.
    /// This is what avoids a broken scroll-inside-scroll on the unified sheet.
    private var embeddedReportContent: some View {
        reportSections(scrollProxy: nil)
    }

    /// The report's ordered sections as a plain column. `scrollProxy` is only
    /// used by the full-screen "back to top" affordance; in embedded mode it is
    /// nil and that affordance is omitted (the parent scroll handles return).
    @ViewBuilder
    private func reportSections(scrollProxy: ScrollViewProxy?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id("topOfReport")

            if let error = viewModel.errorMessage {
                errorBanner(message: error)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }

            // Full-screen only: the sheet's compact overview already shows the
            // plot's identity and address, so the embedded report skips them.
            if !embedded {
                addressBlock
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                sectionDivider
                propertyIdentifierBlock
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                sectionDivider
            }

            // Ordered by what people ask first: what is it worth, who owns it,
            // what kind of land it is, where exactly, has it been sold.
            // Every section is collapsed but shows a one-line answer, so the
            // page reads as a short list of facts instead of a wall of rows.
            reportSection { benchmarkValueSection }
            sectionDivider
            reportSection { ownershipSection }
            sectionDivider
            reportSection { landSection }
            sectionDivider
            reportSection { locationSection }
            sectionDivider
            reportSection { salesHistorySection }

            // 8. REMARKS (only when official remarks are present)
            if viewModel.report.remarks.hasContent {
                sectionDivider

                remarksSection
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
            }

            // Back to top button — full-screen mode only (needs a ScrollViewProxy).
            if let scrollProxy, areAllSectionsExpanded {
                backToTopButton(proxy: scrollProxy)
                    .id("bottomOfReport")
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Layout Building Blocks

    /// Uniform padding for every report section.
    private func reportSection<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
    }

    /// A list of label → value rows. Kept as a plain column (not a grid) so
    /// labels form one clean left edge and values one clean right edge.
    private func factGrid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
    }

    /// Label on the left, value on the right. The label column has a fixed
    /// width and never wraps; the value hugs the right edge and wraps only
    /// when it must, staying right-aligned. An optional caption sits under the
    /// value (small, right-aligned) or, with `captionBelow`, full-width below.
    @ViewBuilder
    private func factTile(
        _ label: String,
        _ value: String?,
        caption: String? = nil,
        captionBelow: Bool = false,
        valueColor: Color? = nil,
        isMono: Bool = false
    ) -> some View {
        if let value, !value.isEmpty, value != "-", value != "—" {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(label)
                        .font(.system(size: 14.5))
                        .foregroundColor(ReportTokens.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: 128, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(value)
                            .font(isMono ? ReportTokens.mono : OdiaScriptSupport.font(size: 15.5, weight: .semibold, value: value))
                            .foregroundColor(valueColor ?? ReportTokens.ink)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        if let caption, !caption.isEmpty, !captionBelow {
                            Text(caption)
                                .font(.system(size: 12.5))
                                .foregroundColor(ReportTokens.secondaryText)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if let caption, !caption.isEmpty, captionBelow {
                    Text(caption)
                        .font(.system(size: 12.5))
                        .foregroundColor(ReportTokens.secondaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 11)
            .overlay(alignment: .bottom) {
                Rectangle().fill(ReportTokens.hairline).frame(height: 0.5)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Section Divider (Edge-to-Edge Prominent)
    
    private var sectionDivider: some View {
        Rectangle()
            .fill(ReportTokens.prominentDivider)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(message: String) -> some View {
        // Shared notice card, same as the map's status notices.
        MapNoticeCard(
            icon: "exclamationmark.triangle",
            tone: .warning,
            title: "Some details couldn't load",
            message: message,
            primary: NoticeAction("Try again", icon: "arrow.clockwise") {
                viewModel.errorMessage = nil
                viewModel.retry()
            },
            onDismiss: { viewModel.errorMessage = nil }
        )
    }
    
    // MARK: - 3. PLOT IDENTIFIERS BLOCK
    
    private var propertyIdentifierBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Property")
                .font(ReportTokens.sectionTitle)
                .foregroundColor(ReportTokens.ink)
            
            HStack(alignment: .top, spacing: 16) {
                propertyColumn(
                    label: "Plot No.",
                    value: viewModel.identity.plotNumber
                )
                
                propertyColumn(
                    label: "Khata No.",
                    value: viewModel.report.property.khataNumber.value ?? "Not available"
                )
                
                propertyColumn(
                    label: "Parcel ID",
                    value: canonicalParcelID
                )
            }
        }
    }
    
    private func propertyColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(ReportTokens.rowLabel)
                .foregroundColor(ReportTokens.secondaryText)
            
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(ReportTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 2. ADDRESS
    
    private var addressBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Address")
                .font(ReportTokens.sectionTitle)
                .foregroundColor(ReportTokens.ink)
            
            let addressText: String = {
                var text: String
                if let direct = viewModel.report.location.addressString.value, !direct.isEmpty {
                    text = direct
                } else {
                    text = "\(viewModel.identity.villageName), \(viewModel.identity.tahasilName), \(viewModel.identity.districtName), Odisha"
                }
                if let pin = viewModel.report.location.pinCode.value, !pin.isEmpty, !text.contains(pin) {
                    text += " - \(pin)"
                }
                return text
            }()
            
            Text(addressText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ReportTokens.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - 3. OWNERSHIP SECTION
    
    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let ownerCount = viewModel.report.ownership.totalOwnersCount
            let countLabel = ownerCount > 0 ? " (\(ownerCount))" : ""
            
            collapsibleHeader(
                title: "Owners\(countLabel)",
                sectionId: .owners,
                trailingBadge: viewModel.report.ownership.owners.contains(where: { $0.isGovernment }) ? "GOVT" : nil,
                summary: ownersSummary
            )
            
            if expandedSections.contains(.owners) {
                switch viewModel.report.rorLoadingState {
                case .loading, .idle:
                    ownerSkeleton
                        .padding(.top, 4)
                    
                case .failed(let message):
                    sectionFailureRow(message: message, retryTitle: "Retry owner lookup")
                        .padding(.top, 4)
                    
                case .loaded, .unavailable:
                    if viewModel.report.ownership.owners.isEmpty {
                        emptyValueRow("No recorded owner particulars are available for this parcel.")
                            .padding(.top, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.report.ownership.owners) { owner in
                                ownerRow(owner)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    private var ownersSummary: String? {
        let owners = viewModel.report.ownership.owners
        guard let first = owners.first?.name, !first.isEmpty else { return nil }
        return owners.count > 1 ? "\(first) and \(owners.count - 1) more" : first
    }

    private var ownerSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 3).fill(ReportTokens.ink.opacity(0.10)).frame(width: 18, height: 16)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4).fill(ReportTokens.ink.opacity(0.10)).frame(width: 150, height: 16)
                        RoundedRectangle(cornerRadius: 3).fill(ReportTokens.ink.opacity(0.06)).frame(width: 200, height: 12)
                    }
                }
            }
        }
    }
    
    private func ownerRow(_ owner: ReportOwner) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Serial number
            Text("\(owner.index).")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ReportTokens.secondaryText)
                .frame(width: 22, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 3) {
                // Owner name in a good font size
                HStack(spacing: 8) {
                    Text(owner.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ReportTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if owner.isGovernment {
                        Text("GOVT")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.20))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                }
                
                // Father / Husband / Caste / Residence (tight cohesive grouping)
                VStack(alignment: .leading, spacing: 2) {
                    if let relName = owner.relationName, !relName.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(owner.relationType ?? "Father"):")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(ReportTokens.secondaryText)
                            Text(relName)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(ReportTokens.ink)
                        }
                    }
                    if let caste = owner.caste, !caste.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Caste:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(ReportTokens.secondaryText)
                            Text(caste)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(ReportTokens.ink)
                        }
                    }
                    if let residence = owner.residence, !residence.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Residence:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(ReportTokens.secondaryText)
                            Text(residence)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(ReportTokens.ink)
                        }
                    }
                    if let share = owner.share, !share.isEmpty, share != "-" {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Share:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(ReportTokens.secondaryText)
                            Text(share)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(ReportTokens.ink)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 4. LOCATION SECTION
    
    private var fullAddressText: String {
        var text = viewModel.report.location.addressString.value
            ?? "\(viewModel.identity.villageName), \(viewModel.identity.tahasilName), \(viewModel.identity.districtName), Odisha"
        if let pin = viewModel.report.location.pinCode.value, !pin.isEmpty, !text.contains(pin) {
            text += " – \(pin)"
        }
        return text
    }

    private var locationSummary: String {
        let loc = viewModel.report.location
        var parts = [loc.district.value].filter { !$0.isEmpty }
        if let pin = loc.pinCode.value, !pin.isEmpty { parts.append("PIN \(pin)") }
        return parts.joined(separator: " · ")
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            collapsibleHeader(title: "Location", sectionId: .location, summary: locationSummary)
            
            if expandedSections.contains(.location) {
                let loc = viewModel.report.location
                VStack(alignment: .leading, spacing: 18) {
                    Text(fullAddressText)
                        .font(OdiaScriptSupport.font(size: 15, value: fullAddressText))
                        .foregroundColor(ReportTokens.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    factGrid {
                        factTile("Village", loc.village.value)
                        factTile("Tahasil", loc.tahasil.value)
                        factTile("District", loc.district.value)
                        factTile("PIN code", loc.pinCode.value)
                        factTile("Police station", loc.policeStationThana.value)
                        factTile("Panchayat", viewModel.identity.panchayatName)
                        factTile("Parcel ID", canonicalParcelID == "Not available" ? nil : canonicalParcelID)
                        if let lat = loc.latitude, let lon = loc.longitude {
                            factTile("Coordinates", String(format: "%.5f, %.5f", lat, lon), isMono: true)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
    
    // MARK: - 5. SALES HISTORY (EC) SECTION
    
    private var salesHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            collapsibleHeader(
                title: "Sales history",
                sectionId: .salesHistory,
                summary: salesSummary
            )
            
            if expandedSections.contains(.salesHistory) {
                let transactions = viewModel.report.transactions.transactions
                
                if transactions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No sale deeds for this plot are published online. An Encumbrance Certificate (EC) from the registration office lists every past sale.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(ReportTokens.secondaryText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button {
                            openIGRPortal()
                        } label: {
                            Text("Apply for an EC")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ReportTokens.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(ReportTokens.accentLine.opacity(0.35)))
                        }
                    }
                    .padding(.top, 4)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                            transactionCard(tx)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    private var salesSummary: String {
        let n = viewModel.report.transactions.transactions.count
        switch n {
        case 0: return "No registered sales found online"
        case 1: return "1 registered sale"
        default: return "\(n) registered sales"
        }
    }

    private func transactionCard(_ tx: ReportTransaction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let price = tx.transferPrice {
                collisionSafeRow("Transfer Price", value: ReportFormatters.formatMoney(price), isBold: true)
            }
            if let date = tx.saleDate {
                collisionSafeRow("Sale Date", value: date)
            }
            if let docNumber = tx.documentNumber {
                collisionSafeRow("Sale Doc Number", value: docNumber, isMono: true)
            }
            if let docType = tx.documentType {
                collisionSafeRow("Document Type", value: docType)
            }
            if let buyer = tx.buyerName {
                collisionSafeRow("Buyer Name", value: buyer)
            }
            if let seller = tx.sellerName {
                collisionSafeRow("Seller Name", value: seller)
            }
            if let office = tx.registrationOffice {
                collisionSafeRow("Registration Office", value: office)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(ReportTokens.cardFill))
    }
    
    // MARK: - 6. LAND VALUE (always visible, not collapsible)
    //
    // The value is the answer most users open a plot for, so it is never
    // hidden behind a chevron or a jurisdiction picker. The view model resolves
    // the registration office automatically; the user only ever sees either a
    // value, a single fallback action, or a clear "not published" message.

    private var benchmarkValueSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            collapsibleHeader(title: "Value & registration cost", sectionId: .benchmarkValue, summary: valueSummary)

            if expandedSections.contains(.benchmarkValue) {
                Group {
                    switch viewModel.report.valuationLoadingState {
                    case .loading, .idle:
                        valueLoadingState
                    case .failed(let message):
                        sectionFailureRow(message: message, retryTitle: "Try again")
                    case .loaded, .unavailable:
                        if hasBenchmarkValue {
                            valueLoadedState
                        } else {
                            valueUnavailableState
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    /// Collapsed answer. The value itself is already on the overview card, so
    /// this line leads with the next question: what does registering cost?
    private var valueSummary: String {
        let v = viewModel.report.valuation
        switch viewModel.report.valuationLoadingState {
        case .loading, .idle:
            return "Finding the official rate…"
        case .failed:
            return "Couldn't load — tap to retry"
        case .loaded, .unavailable:
            guard hasBenchmarkValue else {
                return viewModel.valuationCandidates.isEmpty ? "No official rate published" : "Choose an office to see the value"
            }
            if let duty = v.stampDutyEstimate.value, let fee = v.registrationFeeEstimate.value {
                return "\(LandValueFormat.compact(duty + fee)) to register · value \(LandValueFormat.compact(v.benchmarkValue.value ?? 0))"
            }
            return "Govt. value \(LandValueFormat.compact(v.benchmarkValue.value ?? 0))"
        }
    }

    private var hasBenchmarkValue: Bool {
        (viewModel.report.valuation.benchmarkValue.value ?? 0) > 0
    }

    private var valueSourceBadge: some View {
        let isEstimate = viewModel.isUserAssistedValuation
        return Text(isEstimate ? "Your estimate" : "Official rate")
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundColor(isEstimate ? ReportTokens.brandGold : ReportTokens.successGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill((isEstimate ? ReportTokens.brandGold : ReportTokens.successGreen).opacity(0.12))
            )
    }

    private var valueLoadingState: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(ReportTokens.ink.opacity(0.08))
                .frame(width: 170, height: 30)
            RoundedRectangle(cornerRadius: 4)
                .fill(ReportTokens.ink.opacity(0.06))
                .frame(width: 220, height: 13)
            Text("Finding the official government rate for this plot…")
                .font(ReportTokens.caption)
                .foregroundColor(ReportTokens.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading land value")
    }

    // MARK: Loaded

    private var valueLoadedState: some View {
        let v = viewModel.report.valuation
        let total = v.benchmarkValue.value ?? 0
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                valueSourceBadge
                Spacer()
            }

            factGrid {
                factTile("Government value", ReportFormatters.formatMoney(total), caption: valueCoverage)
                if let rate = v.ratePerDecimal.value, rate > 0 {
                    factTile("Rate", "\(ReportFormatters.formatMoney(rate)) / decimal")
                }
            }

            Text(viewModel.isUserAssistedValuation
                 ? "Worked out from the details you entered. The official figure is confirmed at the registration office."
                 : "The lowest price the government accepts for this land. Stamp duty and fees are charged on it.")
                .font(ReportTokens.caption)
                .foregroundColor(ReportTokens.secondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            registrationCostCard(v)

            valueFooter(v)
        }
    }

    private var valueCoverage: String? {
        guard let area = recordedAreaPrimary, !area.isEmpty else { return nil }
        return "For \(area)"
    }

    private var stampDutyRateLabel: String? {
        guard viewModel.customDeedIdInput == 1 else { return nil }
        let rate = viewModel.customBuyerCategoryInput == .womanBuyer
            ? OdishaStatutoryRates.stampDutyWomanBuyer
            : OdishaStatutoryRates.stampDutyStandard
        return OdishaStatutoryRates.percentString(rate)
    }

    /// "If you buy this plot" — the costs a buyer pays to register it.
    @ViewBuilder
    private func registrationCostCard(_ v: ValuationSectionData) -> some View {
        let duty = v.stampDutyEstimate.value
        let fee = v.registrationFeeEstimate.value
        if duty != nil || fee != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cost to register if you buy")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ReportTokens.ink)

                if let duty {
                    costRow(
                        "Stamp duty" + (stampDutyRateLabel.map { " (\($0))" } ?? ""),
                        ReportFormatters.formatMoney(duty)
                    )
                }
                if let fee {
                    costRow(
                        "Registration fee" + (viewModel.customDeedIdInput == 1 ? " (\(OdishaStatutoryRates.percentString(OdishaStatutoryRates.registrationFee)))" : ""),
                        ReportFormatters.formatMoney(fee)
                    )
                }
                if let duty, let fee {
                    innerDivider
                    HStack {
                        Text("Total")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ReportTokens.ink)
                        Spacer()
                        Text(ReportFormatters.formatMoney(duty + fee))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ReportTokens.ink)
                    }
                }

                Text("Paid by the buyer at the registration office, on top of the price.")
                    .font(.system(size: 12))
                    .foregroundColor(ReportTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showValuationInputSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("Estimate for my deal")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundColor(Theme.Color.bhumitraPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.Color.bhumitraPrimary.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ReportTokens.cardFill))
        }
    }

    private func costRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(ReportTokens.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ReportTokens.ink)
        }
    }

    /// Where the rate came from (with a quiet "Change"), and extra unit rates.
    private func valueFooter(_ v: ValuationSectionData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let office = viewModel.selectedCandidate?.registrationOfficeName ?? v.registrationOffice.value {
                HStack(spacing: 6) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 11.5))
                        .foregroundColor(ReportTokens.secondaryText)
                    Text("Rate from \(office)")
                        .font(.system(size: 12.5))
                        .foregroundColor(ReportTokens.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if viewModel.valuationCandidates.count > 1 {
                        officeMenu(label: Text("Change")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraPrimary))
                    }
                }
            }

            let extraRates: [(String, Double)] = [
                ("Per acre", v.ratePerAcre.value),
                ("Per sq ft", v.ratePerSqFt.value),
                ("Per sq metre", v.ratePerSqMeter.value)
            ].compactMap { label, value in
                guard let value, value > 0 else { return nil }
                return (label, value)
            }

            if !extraRates.isEmpty || v.kisamUsed.value != nil {
                DisclosureGroup(isExpanded: $showMoreRates) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(extraRates, id: \.0) { label, value in
                            costRow(label, ReportFormatters.formatMoney(value))
                        }
                        if let kisam = v.kisamUsed.value, !kisam.isEmpty {
                            costRow("Land type used", kisam)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Rates in other units")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ReportTokens.secondaryText)
                }
                .tint(ReportTokens.secondaryText)
            }
        }
    }

    private func officeMenu<Label: View>(label: Label) -> some View {
        Menu {
            ForEach(viewModel.rankedCandidates) { cand in
                Button {
                    _Concurrency.Task { await viewModel.applyJurisdictionCandidate(cand) }
                } label: {
                    if cand.id == viewModel.selectedCandidate?.id {
                        SwiftUI.Label("\(cand.registrationOfficeName) – \(cand.villageName)", systemImage: "checkmark")
                    } else {
                        Text("\(cand.registrationOfficeName) – \(cand.villageName)")
                    }
                }
            }
        } label: {
            label
        }
    }

    // MARK: Unavailable

    /// Reached only when automatic office matching found no rate. One clear
    /// message and one primary action — never a stack of controls.
    private var valueUnavailableState: some View {
        let hasOffices = !viewModel.valuationCandidates.isEmpty
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ReportTokens.secondaryText)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasOffices ? "We couldn't match the rate automatically" : "No official rate published")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(ReportTokens.ink)
                    Text(hasOffices
                         ? "This village is served by more than one registration office. Pick the one that handles this plot to see its value."
                         : "The government hasn't listed a rate for this plot yet. You can still estimate registration costs from a price.")
                        .font(ReportTokens.caption)
                        .foregroundColor(ReportTokens.secondaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if hasOffices {
                officeMenu(label: primaryValueActionLabel(icon: "building.columns", title: "Choose registration office"))
            }

            Button {
                showValuationInputSheet = true
            } label: {
                if hasOffices {
                    Text("Or estimate from a price")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                        .frame(maxWidth: .infinity)
                } else {
                    primaryValueActionLabel(icon: "indianrupeesign", title: "Estimate from a price")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ReportTokens.cardFill))
    }

    private func primaryValueActionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(Color.white) // on solid brand fill — white in both themes
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(Capsule().fill(Theme.Color.bhumitraPrimary))
    }
    
    private func benchmarkRow(_ label: String, value: String, isBold: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(ReportTokens.secondaryText)
                .frame(minWidth: 120, maxWidth: 155, alignment: .leading)
            
            Spacer(minLength: 8)
            
            Text(value)
                .font(.system(size: 15, weight: isBold ? .semibold : .medium))
                .foregroundColor(ReportTokens.ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 5)
    }
    
    private var innerDivider: some View {
        Rectangle()
            .fill(ReportTokens.hairline)
            .frame(height: 0.5)
    }
    
    // MARK: - 7. LAND SECTION

    @State private var showAllAreaUnits: Bool = false

    private var recordedAreaPrimary: String? {
        let raw = viewModel.report.area.recordedArea.value
        return LandAreaFormat.primary(raw) ?? raw
    }

    private var landSummary: String {
        [recordedAreaPrimary, viewModel.report.landParticulars.landTypeKisam.value]
            .compactMap { $0 }
            .filter { !$0.isEmpty && $0 != "-" }
            .joined(separator: " · ")
    }

    /// One plain-English line for the kisam, when we know what it means.
    private var landUseMeaning: String? {
        guard let kisam = viewModel.report.landParticulars.landTypeKisam.value, !kisam.isEmpty else { return nil }
        let meaning = LandClassificationHelper.meaning(for: kisam)
        return (meaning.isEmpty || meaning == kisam) ? nil : meaning
    }

    private var hasRevenueStatus: Bool {
        if let s = viewModel.report.revenue.paymentStatus.value, !s.isEmpty { return true }
        return false
    }
    
    private var landSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            collapsibleHeader(title: "Land details", sectionId: .land, summary: landSummary)
            
            if expandedSections.contains(.land) {
                let particulars = viewModel.report.landParticulars
                let area = viewModel.report.area
                
                VStack(alignment: .leading, spacing: 14) {
                    factGrid {
                        factTile("Area", recordedAreaPrimary, caption: LandAreaFormat.secondary(area.recordedArea.value))
                        factTile("Land use", particulars.landTypeKisam.value, caption: landUseMeaning, captionBelow: true)
                        if let gis = area.gisPolygonAreaAcre.value, gis > 0 {
                            factTile("Map area", String(format: "≈ %.2f acre", gis))
                        }
                        factTile("Ownership type", particulars.propertyClass.value ?? particulars.tenureSettlement.value)
                        if hasRevenueStatus {
                            factTile("Land tax", revenuePaymentDisplay, valueColor: revenuePaymentColor)
                        }
                    }

                    if !area.conversions.isEmpty {
                        DisclosureGroup(isExpanded: $showAllAreaUnits) {
                            VStack(spacing: 8) {
                                ForEach(area.conversions) { conv in
                                    HStack {
                                        Text(conv.unitName)
                                            .font(.system(size: 14))
                                            .foregroundColor(ReportTokens.secondaryText)
                                        Spacer()
                                        Text(conv.formattedValue)
                                            .font(.system(size: 14.5, weight: .medium))
                                            .foregroundColor(ReportTokens.ink)
                                    }
                                }
                            }
                            .padding(.top, 10)
                        } label: {
                            Text("Area in other units")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(ReportTokens.secondaryText)
                        }
                        .tint(ReportTokens.secondaryText)
                    }

                    if viewModel.report.associatedPlots.totalCount > 0 {
                        Button {
                            showAssociatedPlotSheet = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.on.square")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ReportTokens.secondaryText)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Other plots in this khata")
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundColor(ReportTokens.ink)
                                    Text(viewModel.report.associatedPlots.plots.map { $0.plotNumber }.joined(separator: ", "))
                                        .font(.system(size: 13))
                                        .foregroundColor(ReportTokens.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(ReportTokens.secondaryText)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ReportTokens.cardFill))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
    
    private var revenuePaymentDisplay: String? {
        if let status = viewModel.report.revenue.paymentStatus.value, !status.isEmpty {
            return status
        }
        return "Not available online"
    }
    
    private var revenuePaymentColor: Color? {
        guard let status = viewModel.report.revenue.paymentStatus.value?.lowercased() else { return nil }
        if status.contains("paid") || status.contains("clear") { return ReportTokens.successGreen }
        if status.contains("pending") || status.contains("due") { return ReportTokens.dangerRed }
        return nil
    }
    
    // MARK: - 8. REMARKS SECTION
    
    private var remarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            collapsibleHeader(title: "Remarks", sectionId: .remarks)
            
            if expandedSections.contains(.remarks) {
                if let remarks = viewModel.report.remarks.officialRemarks {
                    Text(remarks)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(ReportTokens.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Collapsible Header Component (Rounded Square Button per Design)
    
    private func collapsibleHeader(
        title: String,
        sectionId: ReportSectionId,
        trailingBadge: String? = nil,
        summary: String? = nil
    ) -> some View {
        let isExpanded = expandedSections.contains(sectionId)
        
        return Button(action: { toggleSection(sectionId) }) {
            HStack(alignment: .center, spacing: 10) {
                // Title + a one-line answer, so a collapsed section still tells
                // the user what's inside without opening it.
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(ReportTokens.sectionTitle)
                        .foregroundColor(ReportTokens.ink)
                    if let summary, !summary.isEmpty, !isExpanded {
                        Text(summary)
                            .font(OdiaScriptSupport.font(size: 13.5, value: summary))
                            .foregroundColor(ReportTokens.secondaryText)
                            .lineLimit(1)
                            .transition(.opacity)
                    }
                }
                
                if let badge = trailingBadge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.20))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
                
                Spacer(minLength: 8)
                
                // Quiet disclosure glyph — one weight lighter than the title so
                // section headers read as a list, not a stack of buttons.
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ReportTokens.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(ReportTokens.ink.opacity(0.06)))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
    
    // MARK: - Back To Top Button
    
    private func backToTopButton(proxy: ScrollViewProxy) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo("topOfReport", anchor: .top)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                Text("Back to top")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(ReportTokens.darkBackground)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(ReportTokens.ink.opacity(0.88))
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 24)
        .padding(.bottom, 48)
    }
    
    // MARK: - Collision-Safe Label/Value Row
    
    private func collisionSafeRow(
        _ label: String,
        value: String?,
        isMono: Bool = false,
        isBold: Bool = false,
        valueColor: Color? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(ReportTokens.secondaryText)
                .frame(minWidth: 110, maxWidth: 135, alignment: .leading)
            
            Spacer(minLength: 8)
            
            if let value, !value.isEmpty, value != "-" {
                Text(value)
                    .font(isMono ? ReportTokens.mono : .system(size: 15, weight: isBold ? .semibold : .medium))
                    .foregroundColor(valueColor ?? ReportTokens.ink)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not available")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(ReportTokens.secondaryText.opacity(0.60))
            }
        }
        .padding(.vertical, 5)
    }
    
    // MARK: - Empty & Failure Row Helpers
    
    private func emptyValueRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(ReportTokens.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func sectionFailureRow(message: String, retryTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(ReportTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Button {
                viewModel.retry()
            } label: {
                Text(retryTitle)
                    .font(ReportTokens.captionMedium)
                    .foregroundColor(ReportTokens.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(ReportTokens.ink.opacity(0.12)))
            }
        }
    }
    
    // MARK: - Associated Plots Sheet
    
    private var associatedPlotsSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let plots = viewModel.report.associatedPlots.plots
                    
                    if plots.isEmpty {
                        emptyValueRow("No associated plots are recorded for this Khata.")
                            .padding(.vertical, 24)
                    } else {
                        ForEach(Array(plots.enumerated()), id: \.element.id) { index, plot in
                            associatedPlotRow(plot)
                            if index < plots.count - 1 {
                                innerDivider
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(ReportTokens.darkBackground.ignoresSafeArea())
            .navigationTitle("Associated Plots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showAssociatedPlotSheet = false }
                        .foregroundColor(ReportTokens.ink)
                }
            }
        }
        // Embedded (sheet) mode follows the system theme like its host sheet.
        .preferredColorScheme(embedded ? nil : .dark)
    }
    
    private func associatedPlotRow(_ plot: ReportAssociatedPlot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Plot \(plot.plotNumber)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(plot.isCurrentPlot ? ReportTokens.accentLine : ReportTokens.ink)
                
                if plot.isCurrentPlot {
                    Text("CURRENT")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ReportTokens.accentLine.opacity(0.20))
                        .foregroundColor(ReportTokens.accentLine)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            
            let details = [plot.area, plot.landType].compactMap { $0 }.filter { !$0.isEmpty && $0 != "-" }
            if !details.isEmpty {
                Text(details.joined(separator: " • "))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(ReportTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - External Link Helper
    
    private func openIGRPortal() {
        guard let url = URL(string: "https://igrodisha.gov.in") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - "Estimate my deal" Sheet
//
// Everything is prefilled from the land record, so a user can tap one button.
// Only the two things that actually change the cost are up front (who is
// buying, and the price); rarely-needed inputs sit under "More options".

public struct LandValuationInputSheet: View {
    @ObservedObject var viewModel: LandRecordReportViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var areaText: String
    @State private var selectedUnit: String
    @State private var selectedBuyer: BuyerCategoryOption
    @State private var landValueText: String
    @State private var selectedCandidate: IGRValuationCandidate?
    @State private var selectedDeedId: Int
    @State private var isCalculating: Bool = false
    @State private var inputError: String? = nil
    @State private var showMoreOptions: Bool = false
    
    let units = ["Decimal", "Acre", "Sq Feet", "Guntha"]
    let deedTypes: [(id: Int, name: String)] = [
        (1, "Sale"),
        (3, "Gift"),
        (4, "Partition"),
        (5, "Settlement")
    ]
    
    public init(viewModel: LandRecordReportViewModel) {
        self.viewModel = viewModel
        let initialArea = viewModel.customAreaInput ?? viewModel.defaultAreaDecimal
        _areaText = State(initialValue: String(format: "%.2f", initialArea).replacingOccurrences(of: ".00", with: ""))
        _selectedUnit = State(initialValue: viewModel.customUnitInput)
        _selectedBuyer = State(initialValue: viewModel.customBuyerCategoryInput)
        _selectedDeedId = State(initialValue: viewModel.customDeedIdInput)
        _selectedCandidate = State(initialValue: viewModel.selectedCandidate ?? viewModel.rankedCandidates.first)
        if let val = viewModel.customConsiderationInput, val > 0 {
            _landValueText = State(initialValue: String(Int(val)))
        } else {
            _landValueText = State(initialValue: "")
        }
    }

    /// Official value, when known — the default price if the user leaves it blank.
    private var officialValue: Double? {
        guard !viewModel.isUserAssistedValuation,
              let bv = viewModel.report.valuation.benchmarkValue.value, bv > 0 else { return nil }
        return bv
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerView
                    buyerSection
                    priceSection
                    areaSection
                    moreOptionsSection
                    
                    if let err = inputError {
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.Color.bhumitraError)
                    }
                    
                    actionButton
                }
                .padding(20)
            }
            .background(Theme.Color.bhumitraBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Estimate my deal")
                        .font(.stackSansHeadline(size: 17, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(nil)
    }
    
    // MARK: Sections

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Plot \(viewModel.identity.plotNumber) · \(viewModel.identity.villageName)")
                .font(.appText(viewModel.identity.villageName, size: 15, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
            Text("See what you'd pay in stamp duty and fees to register this plot. Details from the land record are already filled in.")
                .font(.system(size: 13.5))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buyerSection: some View {
        fieldGroup(
            title: "Who is buying?",
            hint: "Women buyers pay \(OdishaStatutoryRates.percentString(OdishaStatutoryRates.stampDutyWomanBuyer)) stamp duty instead of \(OdishaStatutoryRates.percentString(OdishaStatutoryRates.stampDutyStandard))."
        ) {
            Picker("Buyer", selection: $selectedBuyer) {
                Text("Standard").tag(BuyerCategoryOption.standard)
                Text("Woman buyer").tag(BuyerCategoryOption.womanBuyer)
            }
            .pickerStyle(.segmented)
        }
    }

    private var priceSection: some View {
        fieldGroup(
            title: officialValue == nil ? "Deal price" : "Deal price (optional)",
            hint: officialValue == nil
                ? "No official rate is published for this plot, so costs are based on your price."
                : "Leave blank to use the government value."
        ) {
            HStack(spacing: 8) {
                Text("₹")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                TextField(officialValue.map { ReportFormatters.formatMoney($0).replacingOccurrences(of: "₹", with: "") } ?? "e.g. 15,00,000", text: $landValueText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .keyboardType(.numberPad)
            }
            .padding(14)
            .background(fieldBackground)
        }
    }

    private var areaSection: some View {
        fieldGroup(title: "Area", hint: "From the land record. Change it if you're buying only part of the plot.") {
            HStack(spacing: 10) {
                TextField("Area", text: $areaText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .keyboardType(.decimalPad)
                    .padding(14)
                    .background(fieldBackground)
                Menu {
                    ForEach(units, id: \.self) { u in
                        Button(u) { selectedUnit = u }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedUnit)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraTertiaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 15)
                    .background(fieldBackground)
                }
            }
        }
    }

    private var moreOptionsSection: some View {
        DisclosureGroup(isExpanded: $showMoreOptions) {
            VStack(alignment: .leading, spacing: 16) {
                fieldGroup(title: "Type of transfer", hint: nil) {
                    Picker("Type of transfer", selection: $selectedDeedId) {
                        ForEach(deedTypes, id: \.id) { dt in
                            Text(dt.name).tag(dt.id)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if viewModel.valuationCandidates.count > 1 {
                    fieldGroup(title: "Registration office", hint: "Picked automatically for this plot.") {
                        Menu {
                            ForEach(viewModel.rankedCandidates) { cand in
                                Button("\(cand.registrationOfficeName) – \(cand.villageName)") {
                                    selectedCandidate = cand
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedCandidate.map { "\($0.registrationOfficeName) – \($0.villageName)" } ?? "Choose office")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            }
                            .padding(14)
                            .background(fieldBackground)
                        }
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            Text("More options")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
        }
        .tint(Theme.Color.bhumitraSecondaryText)
    }

    private var actionButton: some View {
        Button {
            performCalculation()
        } label: {
            HStack(spacing: 8) {
                if isCalculating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Show my costs")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(Color.white) // on solid brand fill — white in both themes
            .frame(maxWidth: .infinity)
            .frame(height: Theme.ButtonHeight.cta)
            .background(Capsule().fill(Theme.Color.bhumitraPrimary))
        }
        .disabled(isCalculating)
        .padding(.top, 4)
        .padding(.bottom, 24)
    }

    // MARK: Building blocks

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.Color.bhumitraSurface)
    }

    private func fieldGroup<Content: View>(title: String, hint: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
            content()
            if let hint {
                Text(hint)
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func performCalculation() {
        guard let areaDouble = Double(areaText.replacingOccurrences(of: ",", with: "")), areaDouble > 0 else {
            inputError = "Enter the area of land you're buying."
            return
        }
        let typed = Double(landValueText.replacingOccurrences(of: ",", with: ""))
        let fallback = viewModel.report.valuation.benchmarkValue.value.flatMap { $0 > 0 ? $0 : nil }
        let consideration = (typed ?? 0) > 0 ? typed : fallback
        guard consideration != nil else {
            inputError = "Enter the deal price to estimate costs."
            return
        }
        inputError = nil
        isCalculating = true
        
        _Concurrency.Task { @MainActor in
            await viewModel.calculateWithCustomInputs(
                area: areaDouble,
                unit: selectedUnit,
                buyerCategory: selectedBuyer,
                deedId: selectedDeedId,
                manualConsiderationValue: consideration,
                candidate: selectedCandidate
            )
            isCalculating = false
            dismiss()
        }
    }
}
