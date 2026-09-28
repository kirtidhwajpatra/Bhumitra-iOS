//
//  LandPassportDetailView.swift
//  MyBhoomi
//
//  Figma Pixel-Perfect Implementation of DetailedReport_Screen (Node ID: 773:1902)
//

import SwiftUI
import CoreLocation
import MapKit

// MARK: - Design Tokens (Figma Node 773:1902 - Pure White Light Mode)
private enum FigmaReportTokens {
    static let canvasBg = Color.white
    static let cardBg = Color.white
    static let promoYellow = Color(hex: "#FFE100")
    
    static let textBlack = Color(hex: "#111111")
    static let textTitle = Color(hex: "#111111")
    static let textSubtitle = Color(hex: "#666666")
    static let textDark = Color(hex: "#111111")
    static let textGrayLabel = Color(hex: "#777777")
    static let textGrayLight = Color(hex: "#999999")
    static let textMuted = Color(hex: "#666666")
    static let textDim = Color(hex: "#888888")
    static let textPlotLabel = Color(hex: "#666666")
    static let textAcreLabel = Color(hex: "#666666")
    static let textConversion = Color(hex: "#111111")
    
    static let purpleAccent = Theme.Color.bhumitraPrimary
    static let purpleButton = Theme.Color.bhumitraPrimary
    
    static let dividerLight = Color(hex: "#EEEEEE")
    static let buttonStroke = Color(hex: "#E0E0E0")
    static let plotPillGray = Color(hex: "#F5F5F7")
}

// MARK: - Parsed Land Area Model & Helper
public struct ParsedLandArea {
    public let totalDecimal: Double
    public let decimalFormatted: String
    public let acreFormatted: String
    public let sqftFormatted: String
    
    /// Parses an official revenue area string (e.g. "0 Acre 9900 Decimal", "0.0300",
    /// "150") into Decimal/Acre/SqFt conversions. Returns nil when the input is empty
    /// or unparseable so callers can surface an honest empty state instead of
    /// fabricating a value.
    public static func parse(_ rawInput: String?) -> ParsedLandArea? {
        guard let raw = rawInput?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "N/A", raw != "-", raw != "—" else {
            return nil
        }
        
        var totalDecimal: Double = 0
        var parsed = false
        
        let lower = raw.lowercased()
        
        // 1. Regex pattern for "X Acre Y Decimal" / "X Ac Y Dec" / "X Acre Y"
        let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(?:acre|ac)?\s*(\d+(?:\.\d+)?)\s*(?:decimal|dec|d\.?)?"#, options: .caseInsensitive)
        if let match = regex?.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
           let rAcre = Range(match.range(at: 1), in: raw),
           let rDec = Range(match.range(at: 2), in: raw) {
            let acreVal = Double(raw[rAcre]) ?? 0
            var decVal = Double(raw[rDec]) ?? 0
            
            // If revenue fixed point (e.g. 0300 = 3, 3000 = 30, 0050 = 0.5, 3400 = 34)
            if decVal >= 100 && decVal.truncatingRemainder(dividingBy: 10) == 0 {
                decVal = decVal / 100.0
            }
            
            totalDecimal = (acreVal * 100.0) + decVal
            parsed = totalDecimal > 0
        }
        
        // 2. If already formatted like "150 Decimal" or "3.5 D."
        if !parsed && (lower.contains("decimal") || lower.contains("dec") || lower.contains(" d.")) {
            let numOnly = raw.replacingOccurrences(of: #"[^\d\.]"#, with: "", options: .regularExpression)
            if let d = Double(numOnly), d > 0 {
                totalDecimal = d
                parsed = true
            }
        }
        
        // 3. Plain numeric float or string (e.g. "0.0300", "1.34", "150")
        if !parsed {
            let cleanNum = raw.replacingOccurrences(of: "Ac", with: "")
                              .replacingOccurrences(of: "ac", with: "")
                              .replacingOccurrences(of: "Acre", with: "")
                              .replacingOccurrences(of: "acre", with: "")
                              .trimmingCharacters(in: .whitespacesAndNewlines)
            if let num = Double(cleanNum), num > 0 {
                if num < 10.0 && (raw.contains(".") || raw.lowercased().contains("ac")) {
                    totalDecimal = num * 100.0
                } else {
                    totalDecimal = num
                }
                parsed = totalDecimal > 0
            }
        }
        
        guard parsed, totalDecimal > 0 else { return nil }
        
        // Format decimal string cleanly (e.g. "3", "30", "134")
        let decimalStr: String
        if totalDecimal.truncatingRemainder(dividingBy: 1) == 0 {
            decimalStr = "\(Int(totalDecimal))"
        } else {
            let formatted = String(format: "%.2f", totalDecimal)
            decimalStr = formatted.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
        }
        
        // Acre format
        let acreVal = totalDecimal / 100.0
        let acreStr: String
        if acreVal.truncatingRemainder(dividingBy: 1) == 0 {
            acreStr = "\(Int(acreVal))"
        } else {
            let formatted = String(format: "%.3f", acreVal)
            acreStr = formatted.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
        }
        
        // Sq. ft format (1 Decimal = 435.6 sq ft in Odisha revenue records)
        let sqftVal = Int(round(totalDecimal * 435.6))
        let numFormatter = NumberFormatter()
        numFormatter.numberStyle = .decimal
        let sqftStr = numFormatter.string(from: NSNumber(value: sqftVal)) ?? "\(sqftVal)"
        
        return ParsedLandArea(
            totalDecimal: totalDecimal,
            decimalFormatted: decimalStr,
            acreFormatted: acreStr,
            sqftFormatted: sqftStr
        )
    }
}

public struct LandPassportDetailView: View {
    public let result: OfficialSearchResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // State
    @State private var isLoadingDocument: Bool = false
    @State private var isDownloadingForView: Bool = false
    @State private var isDownloadingForShare: Bool = false
    @State private var showInAppPDFViewer: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var downloadedPDFURL: URL? = nil
    @State private var showAreaCalculator: Bool = false
    @State private var isOwnersExpanded: Bool = false
    @State private var showSaveSuccessModal: Bool = false
    @State private var selectedAssociatedPlot: String = "450"
    @State private var benchmarkValuation: BenchmarkValuation? = nil
    @State private var isLoadingBenchmark: Bool = false
    @State private var benchmarkError: String? = nil
    @State private var showBenchmarkDetailSheet: Bool = false
    @State private var showJurisdictionPickerSheet: Bool = false
    @State private var selectedCandidate: IGRValuationCandidate? = nil

    // Registration & Stamp Duty State
    @State private var registrationEstimate: RegistrationCostEstimate? = nil
    @State private var isLoadingRegistration: Bool = false
    @State private var registrationError: String? = nil
    @State private var showAdjustEstimateSheet: Bool = false
    @State private var customArea: Decimal? = nil
    @State private var customUnit: String = "Decimal"
    @State private var customDeedId: Int = 1
    @State private var customBuyerCategory: BuyerCategoryOption = .standard
    @State private var showSubscriptionCover: Bool = false
    @State private var showNewLandRecordReport: Bool = false

    @ObservedObject private var navManager = AppNavigationManager.shared
    @ObservedObject private var savedLandManager = SavedLandManager.shared
    
    private var isSavedLocally: Bool {
        savedLandManager.isSaved(result: result)
    }
    
    public let onDismiss: (() -> Void)?
    private let selectedBoundary: [Coordinate]
    
    public init(result: OfficialSearchResult, selectedBoundary: [Coordinate] = [], onDismiss: (() -> Void)? = nil) {
        self.result = result
        self.selectedBoundary = selectedBoundary
        self.onDismiss = onDismiss
        self._selectedAssociatedPlot = State(initialValue: result.plotNumber)
    }
    
    // MARK: - Computed Properties
    
    private var displayDistrict: String {
        let val = result.districtName.isEmpty ? result.rawResponse.district : result.districtName
        return val
    }
    
    private var displayTahasil: String {
        let val = result.tahasilName.isEmpty ? result.rawResponse.tahasil : result.tahasilName
        return val
    }
    
    private var displayPostOffice: String {
        if let po = result.rawResponse.rawFields?["po"], !po.isEmpty { return po }
        if let po = result.rawResponse.rawFields?["post_office"], !po.isEmpty { return po }
        if let po = result.rawResponse.rawFields?["p_o"], !po.isEmpty { return po }
        // P/O is a distinct field in the RoR; never substitute the village name — show "—".
        return ""
    }
    
    private var displayVillage: String {
        let raw = result.villageName.isEmpty ? result.rawResponse.village : result.villageName
        return VillageNameSanitizer.sanitize(raw)
    }
    
    private var displayKhatian: String {
        let val = result.khatianNumber.isEmpty ? (result.rawResponse.khataNumber ?? "") : result.khatianNumber
        return val == "N/A" ? "" : val
    }
    
    private var displayPlot: String {
        result.plotNumber
    }
    
    private var allOwnersList: [OwnerEntry] {
        if !result.rawResponse.owners.isEmpty {
            return result.rawResponse.owners
        }
        if let rawOwner = result.rawResponse.rawFields?["owner_name"], !rawOwner.isEmpty {
            let names = rawOwner.components(separatedBy: CharacterSet(charactersIn: ",;\n")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !names.isEmpty {
                return names.map { OwnerEntry(name: $0, share: nil, khataNumber: displayKhatian) }
            }
        }
        if let rawOwner = result.rawResponse.rawFields?["owners"], !rawOwner.isEmpty {
            let names = rawOwner.components(separatedBy: CharacterSet(charactersIn: ",;\n")).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !names.isEmpty {
                return names.map { OwnerEntry(name: $0, share: nil, khataNumber: displayKhatian) }
            }
        }
        return []
    }
    
    private var currentSelectedPlotMetadata: AssociatedPlot? {
        result.rawResponse.plots.first(where: { $0.plotNumber == selectedAssociatedPlot })
    }
    
    /// Nil when the record carries no parseable official area — callers must show
    /// an honest "not recorded" state instead of a fabricated figure.
    private var parsedArea: ParsedLandArea? {
        if let plotMeta = currentSelectedPlotMetadata, let a = plotMeta.area, !a.isEmpty {
            return ParsedLandArea.parse(a)
        }
        return ParsedLandArea.parse(result.area ?? result.rawResponse.area)
    }
    
    private var displayAreaDecimal: String {
        parsedArea?.decimalFormatted ?? "—"
    }
    
    private var displayAreaAcre: String {
        parsedArea?.acreFormatted ?? "—"
    }
    
    private var displayAreaSqft: String {
        parsedArea?.sqftFormatted ?? "—"
    }
    
    /// Area sentence used by PDF/share flows; honest when not recorded.
    private var displayAreaText: String {
        guard let area = parsedArea else { return "Not recorded" }
        return "\(area.decimalFormatted) Decimal"
    }
    
    private var displayLandClassification: String {
        if let plotMeta = currentSelectedPlotMetadata, let lt = plotMeta.landType, !lt.isEmpty {
            return LandClassificationHelper.cleanName(for: lt)
        }
        if let lt = result.rawResponse.landType, !lt.isEmpty {
            return LandClassificationHelper.cleanName(for: lt)
        }
        if let raw = result.rawResponse.rawFields?["kissam"], !raw.isEmpty {
            return LandClassificationHelper.cleanName(for: raw)
        }
        if let raw = result.rawResponse.rawFields?["classification"], !raw.isEmpty {
            return LandClassificationHelper.cleanName(for: raw)
        }
        if let raw = result.rawResponse.rawFields?["land_type"], !raw.isEmpty {
            return LandClassificationHelper.cleanName(for: raw)
        }
        if let raw = result.rawResponse.rawFields?["land_classification"], !raw.isEmpty {
            return LandClassificationHelper.cleanName(for: raw)
        }
        if let tenure = result.rawResponse.rawFields?["tenure"], !tenure.isEmpty {
            return LandClassificationHelper.cleanName(for: tenure)
        }
        // No fabricated default: the UI shows an explicit "not recorded" state.
        return ""
    }
    
    private var displayLandTypeMeaning: String {
        LandClassificationHelper.meaning(for: displayLandClassification)
    }
    
    /// Live register remarks; honest fallback when the record has none.
    private var displayRemarks: String {
        if let rem = result.rawResponse.rawFields?["remarks"], !rem.isEmpty, rem != "—" {
            return rem
        }
        if let plotRem = result.rawResponse.plots.compactMap({ $0.remarks }).first, !plotRem.isEmpty, plotRem != "—" {
            return plotRem
        }
        return "No encumbrance or dispute noted in register"
    }
    
    private var associatedPlotsList: [String] {
        if !result.associatedPlots.isEmpty {
            return result.associatedPlots
        }
        if !result.rawResponse.plots.isEmpty {
            return result.rawResponse.plots.map { $0.plotNumber }
        }
        if let plots = result.rawResponse.rawFields?["associated_plots"]?.components(separatedBy: ","), !plots.isEmpty {
            let cleaned = plots.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !cleaned.isEmpty { return cleaned }
        }
        if !result.plotNumber.isEmpty {
            return [result.plotNumber]
        }
        return []
    }
    
    // MARK: - Main Body
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Controlled Comparative Entry Point: View New Land Record Report
                Button {
                    showNewLandRecordReport = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraPrimary)
                        Text("View Full Land Record Report (New)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraPrimary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.Color.bhumitraPrimary.opacity(0.08))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                
                // 1, 2 & 3. Connected Hero Plot & Location Card (With attached Promo Offer Banner at Top)
                connectedHeroLocationCard
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                
                // 4. Section: Ownership
                ownershipSection
                    .padding(.horizontal, 18)
                
                // 5. Section: Land Area
                landAreaSection
                    .padding(.horizontal, 18)
                
                // Section: Government Benchmark (Odisha IGR)
                governmentBenchmarkSection
                    .padding(.horizontal, 18)
                
                // Section: Registration & Stamp Duty (Odisha IGR)
                registrationAndStampDutySection
                    .padding(.horizontal, 18)
                
                // 6. Section: Land Type
                landTypeSection
                    .padding(.horizontal, 18)
                
                // 7. Section: Associated Plots
                associatedPlotsSection
                    .padding(.horizontal, 18)
                
                // 8. Section: Remarks (Live Register Remarks)
                remarksSection
                    .padding(.horizontal, 18)
                
                // 9. Section: Verification (Live Status & Timestamp)
                verificationSection
                    .padding(.horizontal, 18)
                
                // 10. Section: Documents
                documentsSection
                    .padding(.horizontal, 18)
                
                // Bottom Spacer
                Spacer().frame(height: 32)
            }
        }
        .background(FigmaReportTokens.canvasBg.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            topNavBar
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(
                    FigmaReportTokens.canvasBg
                        .opacity(0.98)
                        .background(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                )
        }
        .onChange(of: navManager.selectedTab) { _ in
            onDismiss?()
            dismiss()
        }
        .onChange(of: selectedAssociatedPlot) { _ in
            selectedCandidate = nil
            benchmarkValuation = nil
            registrationEstimate = nil
            customArea = nil
            _Concurrency.Task {
                await loadBenchmarkValuation()
            }
            _Concurrency.Task {
                await loadRegistrationEstimate()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedPDFURL {
                ShareSheet(activityItems: [url])
            } else {
                ShareSheet(activityItems: [generateShareSummary()])
            }
        }
        .fullScreenCover(isPresented: $showNewLandRecordReport) {
            LandRecordReportView(result: result)
        }
        .sheet(isPresented: $showInAppPDFViewer) {
            if let url = downloadedPDFURL {
                InAppPDFViewerModalView(
                    pdfURL: url,
                    title: "Official RoR Document",
                    subtitle: "Plot \(displayPlot) • \(displayVillage)"
                )
            }
        }
        .sheet(isPresented: $showBenchmarkDetailSheet) {
            if let valuation = benchmarkValuation {
                BenchmarkValuationDetailSheet(
                    valuation: valuation,
                    actualAreaText: displayAreaText
                )
            }
        }
        .sheet(isPresented: $showJurisdictionPickerSheet) {
            let candidates = benchmarkValuation?.candidates ?? registrationEstimate?.candidates ?? []
            if !candidates.isEmpty {
                JurisdictionPickerSheet(
                    candidates: candidates,
                    plotNumber: displayPlot,
                    onSelect: { selected in
                        self.selectedCandidate = selected
                        _Concurrency.Task {
                            await loadBenchmarkValuation(candidate: selected)
                        }
                        _Concurrency.Task {
                            await loadRegistrationEstimate(candidate: selected)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showAdjustEstimateSheet) {
            AdjustEstimateSheet(
                initialArea: customArea ?? (parsedArea.map { Decimal($0.totalDecimal) } ?? 1.0),
                initialUnit: customUnit,
                initialDeedId: customDeedId,
                initialBuyerCategory: customBuyerCategory,
                onCalculate: { newArea, newUnit, newDeed, newBuyer in
                    self.customArea = newArea
                    self.customUnit = newUnit
                    self.customDeedId = newDeed.id
                    self.customBuyerCategory = newBuyer
                    _Concurrency.Task {
                        await loadRegistrationEstimate(
                            forceRefresh: true,
                            customAreaValue: newArea,
                            customUnitValue: newUnit,
                            customDeedValue: newDeed,
                            customBuyerValue: newBuyer
                        )
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showSubscriptionCover) {
            SubscriptionView()
        }
        .fullScreenCover(isPresented: $showAreaCalculator) {
            LandAreaConverterView(
                officialArea: result.area ?? result.rawResponse.area,
                parcelContext: "Plot \(result.plotNumber) • \(displayVillage)"
            )
        }
        .fullScreenCover(isPresented: $showSaveSuccessModal) {
            SaveLandSuccessModalView(
                plotNumber: result.plotNumber,
                villageName: displayVillage,
                onDismiss: {
                    showSaveSuccessModal = false
                }
            )
        }
        .task {
            _Concurrency.Task {
                await loadBenchmarkValuation()
            }
            _Concurrency.Task {
                await loadRegistrationEstimate()
            }
            if downloadedPDFURL == nil {
                if let url = await fetchOrPrepareRoRPDF() {
                    await MainActor.run {
                        self.downloadedPDFURL = url
                    }
                }
            }
        }
        .onAppear {
            AnalyticsService.shared.log(.landPassportViewed(
                districtID: result.districtName,
                isGovernmentLand: result.isGovernmentLand,
                ownerCount: result.ownersCount
            ))
            AnalyticsService.shared.log(.bhumitraReportViewed(districtID: result.districtName))
            
            AppFeedbackManager.shared.notifySuccessfulSearchResultPresented(
                resultId: "passport_\(result.plotNumber)_\(result.villageName)_\(result.khatianNumber)"
            )
        }
        .overlay {
            if AppFeedbackManager.shared.isFeedbackPromptPresented, let opportunity = AppFeedbackManager.shared.currentOpportunity {
                AppFeedbackPromptCardView(opportunity: opportunity)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Top Nav Bar (#773:1905, #773:1909)
    private var topNavBar: some View {
        HStack {
            LiquidGlassBackButton(
                diameter: 42,
                iconSize: 16,
                accessibilityLabel: "Back to search"
            ) {
                onDismiss?()
                dismiss()
            }
            
            Spacer()
            
            Text("Land details")
                .font(.stackSansHeadline(size: 24, weight: .medium))
                .foregroundColor(FigmaReportTokens.textBlack)
            
            Spacer()
            
            // Dedicated Bookmark / Save Record Button
            LiquidGlassCircleButton(
                diameter: 42,
                accessibilityLabel: isSavedLocally ? "Remove from saved lands" : "Save Land Record"
            ) {
                handleSaveLand()
            } content: {
                Image(systemName: isSavedLocally ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(isSavedLocally ? Theme.Color.bhumitraPrimary : FigmaReportTokens.textBlack)
            }
        }
    }
    
    // MARK: - 1. Promo Offer Strip (#773:1918 - #773:1920)
    @ViewBuilder
    private var promoOfferStrip: some View {
        // Hidden entirely for subscribers; tappable deep-link to paywall otherwise.
        if SubscriptionManager.shared.isUnlimited || SubscriptionManager.shared.isPremium {
            EmptyView()
        } else {
            Button {
                showSubscriptionCover = true
            } label: {
                HStack(spacing: 8) {
                    Image("SubscriptionBestValueIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    
                    Text("Get unlimited search today")
                        .font(.stackSansHeadline(size: 15.5, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textBlack)
                    
                    Spacer(minLength: 4)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FigmaReportTokens.textBlack.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white, location: 0.0),
                            .init(color: FigmaReportTokens.promoYellow, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Get unlimited search today. Opens subscription.")
        }
    }
    
    // MARK: - 2 & 3. Connected Hero Plot & Location Card (#773:1924, #779:1946)
    private var connectedHeroLocationCard: some View {
        VStack(spacing: 0) {
            // Attached Promo Offer Banner at Top of Card
            promoOfferStrip
            
            // Subtle Connecting Divider
            Rectangle()
                .fill(FigmaReportTokens.dividerLight)
                .frame(height: 1)
            
            // Top Hero Texture with Plot Typography
            ZStack(alignment: .center) {
                // Background Plot Texture / Map Image
                Image("PlotHeroBg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 184)
                    .clipped()
                
                // Plot & Plot Number Typography (Semibold with tight vertical spacing)
                VStack(spacing: -6) {
                    Text("Plot")
                        .font(.stackSansHeadline(size: 30, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textPlotLabel)
                        .tracking(-0.8)
                    
                    Text(displayPlot.isEmpty ? "—" : displayPlot)
                        .font(.stackSansHeadline(size: displayPlot.count > 7 ? 44 : 62, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textTitle)
                        .tracking(-1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 184)
            .clipped()
            
            // Subtle Connecting Divider
            Rectangle()
                .fill(FigmaReportTokens.dividerLight)
                .frame(height: 1)
            
            // Connected Location Summary Details (Dist, Tahsil, P/O, Village)
            VStack(spacing: 12) {
                HStack {
                    heroLocationRow(label: "Dist", value: displayDistrict)
                    heroLocationRow(label: "Tahsil", value: displayTahasil)
                }
                
                HStack {
                    heroLocationRow(label: "P/O", value: displayPostOffice)
                    heroLocationRow(label: "Village", value: displayVillage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(FigmaReportTokens.cardBg)
        }
        .background(FigmaReportTokens.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
        )
    }
    
    /// Hero location row: honest "—" when the register doesn't carry the field,
    /// and auto-shrinking text so long names never truncate mid-glyph.
    private func heroLocationRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.stackSansHeadline(size: 19, weight: .light))
                .foregroundColor(FigmaReportTokens.textGrayLabel)
            Text(value.isEmpty ? "—" : value)
                .font(.stackSansHeadline(size: 19, weight: .regular))
                .foregroundColor(FigmaReportTokens.textTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 4. Section: Ownership (#779:1993, #779:1975, #779:1964 - #779:1974)
    private var ownershipSection: some View {
        let owners = allOwnersList
        let previewLimit = 5
        let hasHiddenOwners = owners.count > previewLimit
        let displayOwners = isOwnersExpanded ? owners : Array(owners.prefix(previewLimit))
        
        return VStack(alignment: .leading, spacing: 0) {
            sectionCardHeader(title: "Ownership")
            
            VStack(spacing: 12) {
                // Table Subheader
                HStack {
                    Text("Owners")
                        .font(.stackSansHeadline(size: 14.5, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textSubtitle)
                    
                    Spacer()
                    
                    Text("Share")
                        .font(.stackSansHeadline(size: 14.5, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textSubtitle)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Rectangle()
                    .fill(FigmaReportTokens.dividerLight)
                    .frame(height: 1.0)
                    .padding(.horizontal, 16)
                
                // Owner Rows
                if displayOwners.isEmpty {
                    Text("No owner records found")
                        .font(.stackSansHeadline(size: 16, weight: .medium))
                        .foregroundColor(FigmaReportTokens.textGrayLabel)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(displayOwners.enumerated()), id: \.offset) { index, owner in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image("OwnerAvatar")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Theme.Color.bhumitraBorder, lineWidth: 0.6))
                                
                                Text(owner.name)
                                    .font(.system(size: 17.5, weight: .semibold, design: .default))
                                    .foregroundColor(FigmaReportTokens.textBlack)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                                
                                // Only show the official share; never fabricate "1/1".
                                Text(owner.share ?? "—")
                                    .font(.system(size: 17.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(FigmaReportTokens.textTitle)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                // Footer Expand/Collapse Link
                if hasHiddenOwners {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isOwnersExpanded.toggle()
                        }
                    } label: {
                        Text(isOwnersExpanded ? "Collapse owners ↑" : "View all \(owners.count) owners →")
                            .font(.stackSansHeadline(size: 16.5, weight: .semibold))
                            .foregroundColor(FigmaReportTokens.purpleAccent)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                } else {
                    Spacer().frame(height: 4)
                }
            }
        }
        .background(FigmaReportTokens.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
        )
    }
    
    // MARK: - 5. Section: Land Area (#779:1999, #779:1976, #779:1977 - #779:1983)
    private var landAreaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionCardHeader(title: "Land Area")
            
            if let area = parsedArea {
                VStack(spacing: 0) {
                    // Top Graphic Banner (LandAreaBg)
                    ZStack(alignment: .leading) {
                        Image("LandAreaBg")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 96.72)
                            .clipped()
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(area.decimalFormatted)
                                .font(.system(size: 64.95, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Decimal")
                                .font(.stackSansHeadline(size: 31.95, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 16)
                    }
                    .frame(height: 96.72)
                    
                    // Bottom Conversion Row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Acre")
                                .font(.stackSansHeadline(size: 18.07, weight: .regular))
                                .foregroundColor(FigmaReportTokens.textAcreLabel)
                            Text(area.acreFormatted)
                                .font(.stackSansHeadline(size: 31.38, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textConversion)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sq. ft")
                                .font(.stackSansHeadline(size: 18.07, weight: .regular))
                                .foregroundColor(FigmaReportTokens.textAcreLabel)
                            Text(area.sqftFormatted)
                                .font(.stackSansHeadline(size: 31.38, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textConversion)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            } else {
                // Honest empty state: official record carries no parseable area
                VStack(alignment: .leading, spacing: 6) {
                    Text("Area not recorded")
                        .font(.stackSansHeadline(size: 19, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textTitle)
                    Text("The official register does not list a parseable area for this plot.")
                        .font(.stackSansHeadline(size: 13, weight: .regular))
                        .foregroundColor(FigmaReportTokens.textGrayLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 22)
            }
        }
        .background(FigmaReportTokens.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
        )
    }
    
    // MARK: - Section: Government Benchmark (Odisha IGR)
    private var governmentBenchmarkSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Government Benchmark")
                    .font(.stackSansHeadline(size: 14.5, weight: .semibold))
                    .foregroundColor(FigmaReportTokens.textTitle)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.55, blue: 0.33))
                        .frame(width: 6, height: 6)
                    Text("Odisha IGR")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.Color.bhumitraPrimary.opacity(0.08))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.Color.bhumitraSurfaceSecondary)
            .overlay(
                Rectangle()
                    .fill(Theme.Color.bhumitraDivider)
                    .frame(height: 1.0),
                alignment: .bottom
            )
            
            VStack(alignment: .leading, spacing: 14) {
                if isLoadingBenchmark {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(Theme.Color.bhumitraPrimary)
                            .scaleEffect(0.9)
                        Text("Loading benchmark value...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                } else if let valuation = benchmarkValuation, valuation.isAvailable {
                    VStack(alignment: .leading, spacing: 12) {
                        // Rate per Decimal (Prominent Hero)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(valuation.formattedRatePerDecimal)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(FigmaReportTokens.textTitle)
                            Text("per Decimal")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textSubtitle)
                            
                            Spacer()
                        }
                        
                        Text("Government benchmark rate")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        
                        // Indicative Benchmark Amount (if calculation available)
                        if valuation.calculation.calculationAvailable, let amountStr = valuation.calculation.formattedAmount {
                            Rectangle()
                                .fill(FigmaReportTokens.dividerLight)
                                .frame(height: 1.0)
                            
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Indicative benchmark amount")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundColor(FigmaReportTokens.textSubtitle)
                                    Text(amountStr)
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
                                    Text("Based on \(displayAreaText) at government rate")
                                        .font(.system(size: 11))
                                        .foregroundColor(FigmaReportTokens.textGrayLabel)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Secondary rates preview (Acre & Hectare)
                        if let rates = valuation.unitRates {
                            HStack(spacing: 8) {
                                Text("\(rates.formattedPerAcre) / Acre")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(FigmaReportTokens.textSubtitle)
                                Text("•")
                                    .foregroundColor(FigmaReportTokens.textGrayLabel)
                                Text("\(rates.formattedPerHectare) / Hectare")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(FigmaReportTokens.textSubtitle)
                                Spacer()
                            }
                        }
                        
                        Rectangle()
                            .fill(FigmaReportTokens.dividerLight)
                            .frame(height: 1.0)

                        // Transparency Tag (Automatic vs User-Selected)
                        HStack(spacing: 6) {
                            if valuation.isUserAssisted {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                                Text("Jurisdiction selected by you")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
                                Text("Automatically matched")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
                            }
                            
                            Spacer()
                            
                            if let cands = valuation.candidates, !cands.isEmpty {
                                Button {
                                    showJurisdictionPickerSheet = true
                                } label: {
                                    Text("Change jurisdiction")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Theme.Color.bhumitraPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(valuation.isUserAssisted ? Theme.Color.bhumitraPrimary.opacity(0.08) : Color(red: 0.11, green: 0.55, blue: 0.33).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        // Action Button to open native Apple-style Detail Sheet
                        Button {
                            showBenchmarkDetailSheet = true
                        } label: {
                            HStack {
                                Text("View benchmark details")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                } else if let valuation = benchmarkValuation, valuation.isMappingRequiresUserSelection {
                    // Safe User-Assisted Fallback State
                    let candidates = valuation.candidates ?? []
                    if valuation.reason == "PLOT_NOT_FOUND_IN_JURISDICTION" {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)
                                Text("Plot not found in jurisdiction")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(FigmaReportTokens.textTitle)
                                Spacer()
                            }
                            
                            Text(valuation.message ?? "The selected Sub-Registrar jurisdiction does not contain Plot \(displayPlot). Please choose another jurisdiction.")
                                .font(.system(size: 12))
                                .foregroundColor(FigmaReportTokens.textGrayLabel)
                            
                            Button {
                                showJurisdictionPickerSheet = true
                            } label: {
                                HStack {
                                    Text("Choose another jurisdiction")
                                        .font(.system(size: 13, weight: .semibold))
                                    Image(systemName: "arrow.triangle.swap")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.Color.bhumitraPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(16)
                    } else if candidates.count == 1, let singleCand = candidates.first {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                                Text("Valuation jurisdiction found")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(FigmaReportTokens.textTitle)
                                Spacer()
                            }
                            
                            Text("Found official Sub-Registrar \(singleCand.registrationOfficeName) for \(singleCand.villageName). Confirm to view government benchmark rates.")
                                .font(.system(size: 12))
                                .foregroundColor(FigmaReportTokens.textGrayLabel)
                            
                            Button {
                                _Concurrency.Task {
                                    await loadBenchmarkValuation(candidate: singleCand)
                                }
                            } label: {
                                HStack {
                                    Text("Use this jurisdiction")
                                        .font(.system(size: 13, weight: .semibold))
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.Color.bhumitraPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(16)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "building.columns.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                                Text("Select valuation jurisdiction")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(FigmaReportTokens.textTitle)
                                Spacer()
                            }
                            
                            Text("Official benchmark rates depend on the Sub-Registrar registration office. Select the matching jurisdiction to view official rates.")
                                .font(.system(size: 12))
                                .foregroundColor(FigmaReportTokens.textGrayLabel)
                            
                            if let topCand = candidates.first {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(topCand.villageName)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(FigmaReportTokens.textTitle)
                                        Text("Sub-Registrar: \(topCand.registrationOfficeName)")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                    }
                                    Spacer()
                                    Text("Top match")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.11, green: 0.55, blue: 0.33).opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .padding(10)
                                .background(FigmaReportTokens.dividerLight.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            
                            Button {
                                showJurisdictionPickerSheet = true
                            } label: {
                                HStack {
                                    Text("Select jurisdiction")
                                        .font(.system(size: 13, weight: .semibold))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.Color.bhumitraPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(16)
                    }
                } else if let valuation = benchmarkValuation, valuation.isNotFound {
                    // Distinct NOT_FOUND state (Plot without official benchmark rate defined in IGR)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            Text("No benchmark valuation recorded")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textTitle)
                            Spacer()
                        }
                        Text(valuation.message ?? "No official government benchmark rate is defined for this plot in official records. Record of Rights remains unaffected.")
                            .font(.system(size: 12))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        
                        if let cands = valuation.candidates, !cands.isEmpty {
                            Button {
                                showJurisdictionPickerSheet = true
                            } label: {
                                Text("Try another jurisdiction")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                } else if let valuation = benchmarkValuation, valuation.isAmbiguous {
                    // Distinct AMBIGUOUS state (Multiple matching jurisdictions)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            Text("Benchmark jurisdiction ambiguous")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textTitle)
                            Spacer()
                        }
                        Text(valuation.message ?? "Multiple registration offices or revenue villages match this location. Benchmark valuation withheld to prevent false rate association.")
                            .font(.system(size: 12))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        
                        if let cands = valuation.candidates, !cands.isEmpty {
                            Button {
                                showJurisdictionPickerSheet = true
                            } label: {
                                Text("Select jurisdiction")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                } else if let valuation = benchmarkValuation, valuation.isMappingUnresolved {
                    // Distinct MAPPING_UNRESOLVED state (Sub-Registrar or Village not mapped)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            Text("Government location mapping unavailable")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textTitle)
                            Spacer()
                        }
                        Text(valuation.message ?? "Official Sub-Registrar jurisdiction or village-thana could not be safely mapped for this location. Record of Rights remains unaffected.")
                            .font(.system(size: 12))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        
                        if let cands = valuation.candidates, !cands.isEmpty {
                            Button {
                                showJurisdictionPickerSheet = true
                            } label: {
                                Text("Select jurisdiction")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                } else {
                    // Unavailable / Error State with Retry
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            Text("Benchmark temporarily unavailable")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textTitle)
                            Spacer()
                            Button {
                                _Concurrency.Task {
                                    await loadBenchmarkValuation(forceRefresh: true)
                                }
                            } label: {
                                Text("Retry")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Theme.Color.bhumitraPrimary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(benchmarkValuation?.message ?? "Unable to retrieve official government valuation at this time. Record of Rights remains unaffected.")
                            .font(.system(size: 12))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                    }
                    .padding(16)
                }
            }
            .background(FigmaReportTokens.cardBg)
        }
        .background(FigmaReportTokens.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
        )
    }
    
    // MARK: - Section: Registration & Stamp Duty (Odisha IGR)
    private var registrationAndStampDutySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Registration & Stamp Duty")
                    .font(.stackSansHeadline(size: 14.5, weight: .semibold))
                    .foregroundColor(FigmaReportTokens.textTitle)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.55, blue: 0.33))
                        .frame(width: 6, height: 6)
                    Text("Odisha IGR")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.Color.bhumitraPrimary.opacity(0.08))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.Color.bhumitraSurfaceSecondary)
            .overlay(
                Rectangle()
                    .fill(Theme.Color.bhumitraDivider)
                    .frame(height: 1.0),
                alignment: .bottom
            )
            
            VStack(alignment: .leading, spacing: 14) {
                if isLoadingRegistration {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(Theme.Color.bhumitraPrimary)
                            .scaleEffect(0.9)
                        Text("Calculating government charges…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                } else if let estimate = registrationEstimate, estimate.isAvailable {
                    VStack(alignment: .leading, spacing: 12) {
                        // Subheader
                        Text("Estimated government charges")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        
                        // Breakdown Rows
                        VStack(spacing: 8) {
                            HStack {
                                Text("Benchmark value")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                Spacer()
                                Text(estimate.formattedBenchmarkValue)
                                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            }
                            
                            HStack {
                                Text("Stamp Duty")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                Spacer()
                                Text(estimate.formattedStampDuty)
                                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            }
                            
                            HStack {
                                Text("Registration Fee")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                Spacer()
                                Text(estimate.formattedRegistrationFee)
                                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            }
                            
                            if estimate.womenBuyerConcessionApplicable, let concessionStr = estimate.formattedConcessionAmount, estimate.buyerCategory == "WOMEN_BUYER" {
                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Women buyer concession")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
                                    }
                                    Spacer()
                                    Text("-\(concessionStr)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Rectangle()
                            .fill(FigmaReportTokens.dividerLight)
                            .frame(height: 1.0)
                        
                        // Total Row
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(estimate.buyerCategory == "WOMEN_BUYER" && estimate.womenBuyerConcessionApplicable ? "Total after concession" : "Estimated Total")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                Text("For \(NSDecimalNumber(decimal: estimate.selectedArea).stringValue) \(estimate.selectedUnit) (\(estimate.deedType))")
                                    .font(.system(size: 11))
                                    .foregroundColor(FigmaReportTokens.textGrayLabel)
                            }
                            
                            Spacer()
                            
                            Text(estimate.formattedTotalAfterConcession)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Color.bhumitraPrimary)
                        }
                        
                        Rectangle()
                            .fill(FigmaReportTokens.dividerLight)
                            .frame(height: 1.0)
                        
                        // Action Button to open Adjust Estimate Sheet
                        Button {
                            showAdjustEstimateSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Adjust estimate")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(Theme.Color.bhumitraPrimary)
                            .padding(.vertical, 4)
                        }
                        
                        Text("Based on official Odisha IGR inputs. Statutory rates vary by deed type and buyer concession.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Color.bhumitraTertiaryText)
                    }
                    .padding(16)
                } else if let estimate = registrationEstimate, estimate.isMappingRequiresUserSelection || estimate.isMappingUnresolved {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            Text("Registration estimate unavailable")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textTitle)
                            Spacer()
                        }
                        Text("Official IGR jurisdiction could not be resolved automatically.")
                            .font(.system(size: 12))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        
                        Button {
                            showJurisdictionPickerSheet = true
                        } label: {
                            Text("Select jurisdiction")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(Theme.Color.bhumitraPrimary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                } else if let estimate = registrationEstimate, estimate.isNotFound {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            Text("No registration charges recorded")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textTitle)
                            Spacer()
                        }
                        Text(estimate.message ?? "No official government benchmark valuation is defined for this plot. Record of Rights remains unaffected.")
                            .font(.system(size: 12))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                    }
                    .padding(16)
                } else {
                    // Unavailable / Error State with Retry
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            Text("Registration estimate temporarily unavailable")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textTitle)
                            Spacer()
                            Button {
                                _Concurrency.Task {
                                    await loadRegistrationEstimate(forceRefresh: true)
                                }
                            } label: {
                                Text("Retry")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Theme.Color.bhumitraPrimary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(registrationEstimate?.message ?? "Unable to retrieve official government registration charges at this time. Record of Rights remains unaffected.")
                            .font(.system(size: 12))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                    }
                    .padding(16)
                }
            }
            .background(FigmaReportTokens.cardBg)
        }
        .background(FigmaReportTokens.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
        )
    }
    
    // MARK: - 6. Section: Land Type (#779:2004, #779:1984, #779:1985, #779:1987, #779:1989)
    private var landTypeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionCardHeader(title: "Land Type")
            
            if displayLandClassification.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Classification not recorded")
                        .font(.stackSansHeadline(size: 17, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textTitle)
                    Text("The official register does not list a land classification (Kissam) for this plot.")
                        .font(.stackSansHeadline(size: 13, weight: .regular))
                        .foregroundColor(FigmaReportTokens.textGrayLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    Text(displayLandClassification)
                        .font(.googleSans(size: 24.44, weight: .bold))
                        .foregroundColor(FigmaReportTokens.textDark)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    Text(displayLandTypeMeaning)
                        .font(.stackSansHeadline(size: 12, weight: .light))
                        .foregroundColor(FigmaReportTokens.textTitle)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 165, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(minHeight: 80)
                .frame(maxWidth: .infinity)
            }
        }
        .background(FigmaReportTokens.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
        )
    }
    
    // MARK: - 7. Section: Associated Plots (#779:2025, #779:2026, #779:2008 - #779:2024)
    private var associatedPlotsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionCardHeader(title: "Associated Plots")
            
            VStack(alignment: .leading, spacing: 12) {
                // Khata Number & Value (Strictly Left Aligned)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Khata Number")
                        .font(.stackSansHeadline(size: 15, weight: .medium))
                        .foregroundColor(FigmaReportTokens.textSubtitle)
                    
                    Text(displayKhatian)
                        .font(.stackSansHeadline(size: 68, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textTitle)
                        .tracking(-2.0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Rectangle()
                    .fill(FigmaReportTokens.dividerLight)
                    .frame(height: 1.0)
                    .padding(.horizontal, 16)
                
                // Recorded Plots Count (Strictly Left Aligned)
                Text(associatedPlotsList.count == 1 ? "1 Recorded Plot" : "\(associatedPlotsList.count) Recorded Plots")
                    .font(.stackSansHeadline(size: 16, weight: .semibold))
                    .foregroundColor(FigmaReportTokens.textTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                
                // Badges Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(associatedPlotsList, id: \.self) { plot in
                        let isSelected = (plot == selectedAssociatedPlot)
                        Button {
                            selectedAssociatedPlot = plot
                        } label: {
                            Text(plot)
                                .font(.stackSansHeadline(size: plot.count > 5 ? 22 : 32, weight: .regular))
                                .foregroundColor(isSelected ? .white : FigmaReportTokens.textBlack)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50.25)
                                .background(isSelected ? Theme.Color.bhumitraPrimary : FigmaReportTokens.plotPillGray)
                                .cornerRadius(2.79)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(FigmaReportTokens.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
        )
    }
    
    // MARK: - 8. Section: Remarks (Live Plot Remarks)
    private var remarksSection: some View {
        let remarksText = displayRemarks
        
        return VStack(alignment: .leading, spacing: 0) {
            sectionCardHeader(title: "Remarks")
            
            Text(remarksText)
                .font(.stackSansHeadline(size: 15, weight: .regular))
                .foregroundColor(FigmaReportTokens.textTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
        }
        .background(FigmaReportTokens.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
        )
    }
    
    // MARK: - 9. Section: Verification (#779:2063 - #779:2085)
    private var verificationSection: some View {
        let verification = result.rawResponse.verification
        let isVerified = verification?.status == .verified
        let verifiedAt = verificationTimestamp
        
        return VStack(alignment: .leading, spacing: 0) {
            sectionCardHeader(title: "Verification")
            
            VStack(spacing: 14) {
                // Row 1: Verified with
                HStack(alignment: .top) {
                    Text("Verified with")
                        .font(.stackSansHeadline(size: 15, weight: .regular))
                        .foregroundColor(FigmaReportTokens.textGrayLight)
                        .frame(width: 120, alignment: .leading)
                    
                    Spacer()
                    
                    Text("Plot, Khata, Area & Owners")
                        .font(.stackSansHeadline(size: 17, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textTitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Row 2: Verified on (live retrieval timestamp)
                HStack(alignment: .top) {
                    Text("Verified on")
                        .font(.stackSansHeadline(size: 15, weight: .regular))
                        .foregroundColor(FigmaReportTokens.textGrayLight)
                        .frame(width: 120, alignment: .leading)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            DetailedReportCalendarIcon(size: 15, color: FigmaReportTokens.textMuted)
                            Text(verifiedAt.dateText)
                                .font(.system(size: 15.5, weight: .medium, design: .rounded))
                                .foregroundColor(FigmaReportTokens.textTitle)
                        }
                        
                        HStack(spacing: 6) {
                            DetailedReportClockIcon(size: 15, color: FigmaReportTokens.textMuted)
                            Text(verifiedAt.timeText)
                                .font(.system(size: 15.5, weight: .medium, design: .rounded))
                                .foregroundColor(FigmaReportTokens.textTitle)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Row 3: Verification status (from official response, not hardcoded)
                HStack(alignment: .center) {
                    Text("Verification status")
                        .font(.stackSansHeadline(size: 15, weight: .regular))
                        .foregroundColor(FigmaReportTokens.textGrayLight)
                        .frame(width: 120, alignment: .leading)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        if isVerified {
                            DetailedReportVerifiedCheck(size: 18)
                            Text("Verified with govt portal")
                                .font(.stackSansHeadline(size: 15.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textBlack)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.orange)
                            Text("Verification incomplete")
                                .font(.stackSansHeadline(size: 15.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.textBlack)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .background(FigmaReportTokens.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
        )
    }
    
    /// Real retrieval timestamp from the verified-parcel cache; "now" only when the
    /// record was fetched fresh in this session (never a hardcoded date).
    private var verificationTimestamp: (dateText: String, timeText: String) {
        let date: Date = {
            // Match VerifiedParcelCache canonical key construction.
            let distId = result.districtID.isEmpty ? result.rawResponse.district : result.districtID
            let tahId = result.tahasilID.isEmpty ? result.rawResponse.tahasil : result.tahasilID
            let villId = result.villageID.isEmpty ? result.rawResponse.village : result.villageID
            let key = "\(distId):\(tahId):\(villId):\(displayPlot)"
            if let cachedAt = VerifiedParcelCache.shared.get(canonicalKey: key)?.verifiedAt {
                return cachedAt
            }
            return Date()
        }()
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        
        let day = Calendar.current.component(.day, from: date)
        let daySuffix: String
        switch day {
        case 1, 21, 31: daySuffix = "st"
        case 2, 22: daySuffix = "nd"
        case 3, 23: daySuffix = "rd"
        default: daySuffix = "th"
        }
        formatter.dateFormat = "d"
        let dayNum = formatter.string(from: date)
        formatter.dateFormat = "MMM, yyyy"
        let dateText = "\(dayNum)\(daySuffix) \(formatter.string(from: date))"
        
        formatter.dateFormat = "hh:mm a"
        let timeText = formatter.string(from: date).uppercased()
        
        return (dateText, timeText)
    }
    
    // MARK: - 9. Section: Documents (#779:2086 - #779:2126)
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                sectionCardHeader(title: "Documents")
                
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Official ROR document")
                            .font(.stackSansHeadline(size: 19, weight: .semibold))
                            .foregroundColor(FigmaReportTokens.textTitle)
                        
                        Text("Official government record")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(FigmaReportTokens.textSubtitle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                    
                    HStack(spacing: 12) {
                        // View Button (In-App Document Viewer)
                        Button {
                            handleViewDocument()
                        } label: {
                            HStack(spacing: 6) {
                                if isDownloadingForView {
                                    ProgressView()
                                         .scaleEffect(0.85)
                                }
                                Text(isDownloadingForView ? "Opening..." : "View")
                                    .font(.stackSansHeadline(size: 16.5, weight: .semibold))
                                    .foregroundColor(FigmaReportTokens.textBlack)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(FigmaReportTokens.cardBg)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(FigmaReportTokens.dividerLight, lineWidth: 1.6)
                            )
                        }
                        .buttonStyle(BhumitraPrimaryActionButtonStyle())
                        .disabled(isDownloadingForView || isDownloadingForShare)
                        
                        // Download Button (Native PDF Export)
                        Button {
                            handleDownloadDocument()
                        } label: {
                            HStack(spacing: 6) {
                                if isDownloadingForShare {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(FigmaReportTokens.purpleButton)
                                }
                                
                                Text(isDownloadingForShare ? "Preparing..." : "Download")
                                    .font(.stackSansHeadline(size: 16.5, weight: .semibold))
                                    .foregroundColor(FigmaReportTokens.purpleButton)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(FigmaReportTokens.cardBg)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(FigmaReportTokens.dividerLight, lineWidth: 1.6)
                            )
                        }
                        .buttonStyle(BhumitraPrimaryActionButtonStyle())
                        .disabled(isDownloadingForView || isDownloadingForShare)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
            .background(FigmaReportTokens.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.Color.bhumitraBorder, lineWidth: 1.0)
            )
            
            // Disclaimer Below Card
            Text("Information shown reproduced from the Records of Rights\npublished on Govt Portals")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundColor(FigmaReportTokens.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Modern Differentiated Section Header Strip (No Icons, Sleek Padding)
    private func sectionCardHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.stackSansHeadline(size: 14.5, weight: .semibold))
                .foregroundColor(FigmaReportTokens.textTitle)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.Color.bhumitraSurfaceSecondary)
        .overlay(
            Rectangle()
                .fill(Theme.Color.bhumitraDivider)
                .frame(height: 1.0),
            alignment: .bottom
        )
    }
    
    // MARK: - Actions
    
    private func fetchOrPrepareRoRPDF() async -> URL? {
        if let existing = downloadedPDFURL, FileManager.default.fileExists(atPath: existing.path) {
            return existing
        }
        
        let district = result.districtID.isEmpty ? result.districtName : result.districtID
        let tahasil = result.tahasilID.isEmpty ? result.tahasilName : result.tahasilID
        let village = result.villageID.isEmpty ? result.villageName : result.villageID
        let plot = displayPlot
        let khata = displayKhatian
        let bId = result.rawResponse.rawFields?["block_id"] ?? (result.tahasilID.isEmpty ? nil : result.tahasilID)
        let vId = result.villageID.isEmpty ? result.rawResponse.rawFields?["village_id"] : result.villageID
        let docID = result.rawResponse.officialDocument?.documentID
        
        // 0. Instant Cache Check
        if let cached = await OfficialRoRPDFService.shared.getCachedURL(
            district: district,
            tahasil: tahasil,
            village: village,
            plot: plot,
            khata: khata,
            vId: vId
        ), FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }
        
        // 1. Fetch remote official PDF with a 3.5s timeout budget to prevent UI freezes
        let remoteTask = _Concurrency.Task<URL?, Never> {
            if let docID = docID, !docID.isEmpty {
                if let (url, _, _) = try? await RoRService.shared.downloadOfficialDocument(documentID: docID),
                   FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
            if let url = try? await OfficialRoRPDFService.shared.fetchOrGetPDF(
                district: district,
                tahasil: tahasil,
                village: village,
                plot: plot,
                khataNumber: khata,
                bId: bId,
                vId: vId,
                documentID: docID
            ), FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            return nil
        }
        
        let timeoutTask = _Concurrency.Task<URL?, Never> {
            try? await _Concurrency.Task.sleep(nanoseconds: 3_500_000_000)
            return nil
        }
        
        let remoteResult = await withTaskGroup(of: URL?.self) { group -> URL? in
            group.addTask { await remoteTask.value }
            group.addTask { await timeoutTask.value }
            
            for await res in group {
                if let valid = res {
                    group.cancelAll()
                    return valid
                }
            }
            return nil
        }
        
        if let remoteURL = remoteResult {
            return remoteURL
        }
        
        // 2. Fallback to instant local PDF generator in background
        let targetDistrict = displayDistrict
        let targetTahasil = displayTahasil
        let targetVillage = displayVillage
        let targetPlot = displayPlot
        let targetKhata = displayKhatian
        let targetArea = displayAreaText
        let targetLandType = displayLandClassification
        let targetOwners = allOwnersList
        let targetPlots = associatedPlotsList
        
        return await _Concurrency.Task.detached(priority: .userInitiated) {
            return LocalRoRPDFGenerator.generateRoRPDF(
                district: targetDistrict,
                tahasil: targetTahasil,
                village: targetVillage,
                plotNumber: targetPlot,
                khataNumber: targetKhata,
                area: targetArea,
                landType: targetLandType,
                owners: targetOwners,
                associatedPlots: targetPlots
            )
        }.value
    }
    
    private func handleViewDocument() {
        if let url = downloadedPDFURL, FileManager.default.fileExists(atPath: url.path) {
            showInAppPDFViewer = true
            return
        }
        
        isDownloadingForView = true
        _Concurrency.Task {
            let url = await fetchOrPrepareRoRPDF()
            await MainActor.run {
                self.isDownloadingForView = false
                if let validURL = url {
                    self.downloadedPDFURL = validURL
                    self.showInAppPDFViewer = true
                }
            }
        }
    }
    
    private func handleDownloadDocument() {
        if let url = downloadedPDFURL, FileManager.default.fileExists(atPath: url.path) {
            showShareSheet = true
            return
        }
        
        isDownloadingForShare = true
        _Concurrency.Task {
            let url = await fetchOrPrepareRoRPDF()
            await MainActor.run {
                self.isDownloadingForShare = false
                if let validURL = url {
                    self.downloadedPDFURL = validURL
                    self.showShareSheet = true
                }
            }
        }
    }
    
    private func handleSaveLand() {
        let isNowSaved = savedLandManager.toggleSave(
            result: result,
            boundary: selectedBoundary.isEmpty ? nil : selectedBoundary
        )
        if isNowSaved {
            showSaveSuccessModal = true
        }
    }
    
    private func generateShareSummary() -> String {
        return """
        📄 Land Details Report (Bhumitra)
        Plot No: \(displayPlot)
        Khata No: \(displayKhatian)
        District: \(displayDistrict)
        Tahasil: \(displayTahasil)
        Village: \(displayVillage)
        Area: \(displayAreaText)
        """
    }
    
    private func loadBenchmarkValuation(forceRefresh: Bool = false, candidate: IGRValuationCandidate? = nil) async {
        let district = displayDistrict
        let tahasil: String = {
            if !result.tahasilName.isEmpty && result.tahasilName.caseInsensitiveCompare("Sadar") != .orderedSame {
                return result.tahasilName
            }
            if !result.rawResponse.tahasil.isEmpty && result.rawResponse.tahasil.caseInsensitiveCompare("Sadar") != .orderedSame {
                return result.rawResponse.tahasil
            }
            if displayTahasil.caseInsensitiveCompare("Sadar") == .orderedSame {
                return "\(district) Sadar"
            }
            return displayTahasil
        }()
        let village = result.villageName.isEmpty ? result.rawResponse.village : result.villageName
        let plot = displayPlot
        
        let areaDecimal = parsedArea?.totalDecimal
        
        if !forceRefresh {
            if let cached = await BenchmarkValuationService.shared.getCachedValuation(
                district: district,
                tahasil: tahasil,
                village: village,
                plot: plot,
                selectedRegoffID: candidate?.registrationOfficeId,
                selectedVillageID: candidate?.villageId
            ) {
                await MainActor.run {
                    self.benchmarkValuation = cached
                    self.isLoadingBenchmark = false
                }
                return
            }
        }
        
        await MainActor.run {
            self.isLoadingBenchmark = true
            self.benchmarkError = nil
        }
        
        do {
            let valuation = try await BenchmarkValuationService.shared.fetchValuation(
                district: district,
                tahasil: tahasil,
                village: village,
                plot: plot,
                actualArea: areaDecimal,
                actualAreaUnit: areaDecimal != nil ? "Decimal" : nil,
                bId: result.tahasilID.isEmpty ? nil : result.tahasilID,
                vId: result.villageID.isEmpty ? nil : result.villageID,
                selectedRegoffID: candidate?.registrationOfficeId,
                selectedVillageID: candidate?.villageId,
                candidateToken: candidate?.candidateToken,
                forceRefresh: forceRefresh
            )
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.benchmarkValuation = valuation
                    self.isLoadingBenchmark = false
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.isLoadingBenchmark = false
                    self.benchmarkError = error.localizedDescription
                }
            }
        }
    }

    private func loadRegistrationEstimate(
        forceRefresh: Bool = false,
        candidate: IGRValuationCandidate? = nil,
        customAreaValue: Decimal? = nil,
        customUnitValue: String? = nil,
        customDeedValue: IGRDeedOption? = nil,
        customBuyerValue: BuyerCategoryOption? = nil
    ) async {
        let district = displayDistrict
        let tahasil: String = {
            if !result.tahasilName.isEmpty && result.tahasilName.caseInsensitiveCompare("Sadar") != .orderedSame {
                return result.tahasilName
            }
            if !result.rawResponse.tahasil.isEmpty && result.rawResponse.tahasil.caseInsensitiveCompare("Sadar") != .orderedSame {
                return result.rawResponse.tahasil
            }
            if displayTahasil.caseInsensitiveCompare("Sadar") == .orderedSame {
                return "\(district) Sadar"
            }
            return displayTahasil
        }()
        let village = result.villageName.isEmpty ? result.rawResponse.village : result.villageName
        let plot = displayPlot

        let areaDecimal: Decimal = customAreaValue ?? customArea ?? (parsedArea.map { Decimal($0.totalDecimal) } ?? 1.0)
        let unitToUse = customUnitValue ?? customUnit
        let deedToUse = customDeedValue?.name ?? (IGRDeedOption.standardDeeds.first(where: { $0.id == customDeedId })?.name ?? "SALE IMMOVABLE")
        let deedIdToUse = customDeedValue?.id ?? customDeedId
        let buyerToUse = customBuyerValue ?? customBuyerCategory

        if !forceRefresh {
            if let cached = await RegistrationCostService.shared.getCachedEstimate(
                district: district,
                tahasil: tahasil,
                village: village,
                plot: plot,
                area: areaDecimal,
                unit: unitToUse,
                deedId: deedIdToUse,
                buyerCategory: buyerToUse,
                selectedRegoffID: candidate?.registrationOfficeId ?? selectedCandidate?.registrationOfficeId,
                selectedVillageID: candidate?.villageId ?? selectedCandidate?.villageId
            ) {
                await MainActor.run {
                    self.registrationEstimate = cached
                    self.isLoadingRegistration = false
                }
                return
            }
        }

        await MainActor.run {
            self.isLoadingRegistration = true
            self.registrationError = nil
        }

        do {
            let estimate = try await RegistrationCostService.shared.fetchEstimate(
                district: district,
                tahasil: tahasil,
                village: village,
                plot: plot,
                area: areaDecimal,
                unit: unitToUse,
                deedType: deedToUse,
                deedId: deedIdToUse,
                buyerCategory: buyerToUse,
                bId: result.tahasilID.isEmpty ? nil : result.tahasilID,
                vId: result.villageID.isEmpty ? nil : result.villageID,
                selectedRegoffID: candidate?.registrationOfficeId ?? selectedCandidate?.registrationOfficeId,
                selectedVillageID: candidate?.villageId ?? selectedCandidate?.villageId,
                candidateToken: candidate?.candidateToken ?? selectedCandidate?.candidateToken,
                forceRefresh: forceRefresh
            )
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.registrationEstimate = estimate
                    self.isLoadingRegistration = false
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.isLoadingRegistration = false
                    self.registrationError = error.localizedDescription
                }
            }
        }
    }
}

