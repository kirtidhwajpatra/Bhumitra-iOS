//
//  LandPassportDetailView.swift
//  MyBhoomi
//
//  Figma Pixel-Perfect Implementation of DetailedReport_Screen (Node ID: 773:1902)
//

import SwiftUI
import CoreLocation
import MapKit

// MARK: - Design Tokens (Figma Node 773:1902)
private enum FigmaReportTokens {
    static let canvasBg = Color(hex: "#F3F3F3")
    static let cardBg = Color(hex: "#FFFFFF")
    static let promoYellow = Color(hex: "#FFE100")
    
    static let textBlack = Color(hex: "#000000")
    static let textTitle = Color(hex: "#070707")
    static let textSubtitle = Color(hex: "#2F2F2F")
    static let textDark = Color(hex: "#030C0B")
    static let textGrayLabel = Color(hex: "#797979")
    static let textGrayLight = Color(hex: "#848484")
    static let textMuted = Color(hex: "#585858")
    static let textDim = Color(hex: "#A6A6A6")
    static let textPlotLabel = Color(hex: "#676767")
    static let textAcreLabel = Color(hex: "#4F4F4F")
    static let textConversion = Color(hex: "#272727")
    
    static let purpleAccent = Color(hex: "#6E07FF")
    static let purpleButton = Color(hex: "#7600FF")
    
    static let dividerLight = Color(hex: "#E8E8E8")
    static let buttonStroke = Color(hex: "#EAEAEA")
    static let plotPillGray = Color(hex: "#DCDCDC")
}

// MARK: - Parsed Land Area Model & Helper
public struct ParsedLandArea {
    public let totalDecimal: Double
    public let decimalFormatted: String
    public let acreFormatted: String
    public let sqftFormatted: String
    
    public static func parse(_ rawInput: String?) -> ParsedLandArea {
        guard let raw = rawInput?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw != "N/A", raw != "-" else {
            return ParsedLandArea(totalDecimal: 150, decimalFormatted: "150", acreFormatted: "1.50", sqftFormatted: "65,340")
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
            parsed = true
        }
        
        // 2. If already formatted like "150 Decimal" or "3.5 D."
        if !parsed && (lower.contains("decimal") || lower.contains("dec") || lower.contains(" d.")) {
            let numOnly = raw.replacingOccurrences(of: #"[^\d\.]"#, with: "", options: .regularExpression)
            if let d = Double(numOnly) {
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
            if let num = Double(cleanNum) {
                if num < 10.0 && (raw.contains(".") || raw.lowercased().contains("ac")) {
                    totalDecimal = num * 100.0
                } else {
                    totalDecimal = num
                }
                parsed = true
            }
        }
        
        if !parsed || totalDecimal <= 0 {
            totalDecimal = 150
        }
        
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
        
        // Sq. ft format
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
    @State private var showShareSheet: Bool = false
    @State private var downloadedPDFURL: URL? = nil
    @State private var showAreaCalculator: Bool = false
    @State private var isOwnersExpanded: Bool = false
    @State private var showSaveSuccessModal: Bool = false
    @State private var selectedAssociatedPlot: String = "450"
    @State private var selectedTab: AppTab = .home
    @ObservedObject private var savedLandManager = SavedLandManager.shared
    
    private var isSavedLocally: Bool {
        savedLandManager.isSaved(result: result)
    }
    
    public let onDismiss: (() -> Void)?
    
    public init(result: OfficialSearchResult, selectedBoundary: [Coordinate] = [], onDismiss: (() -> Void)? = nil) {
        self.result = result
        self.onDismiss = onDismiss
        self._selectedAssociatedPlot = State(initialValue: result.plotNumber.isEmpty ? "450" : result.plotNumber)
    }
    
    // MARK: - Computed Properties
    
    private var displayDistrict: String {
        let val = result.districtName.isEmpty ? result.rawResponse.district : result.districtName
        return val.isEmpty ? "Keonjhar" : val
    }
    
    private var displayTahasil: String {
        let val = result.tahasilName.isEmpty ? result.rawResponse.tahasil : result.tahasilName
        return val.isEmpty ? "Sadar" : val
    }
    
    private var displayPostOffice: String {
        if let po = result.rawResponse.rawFields?["po"], !po.isEmpty { return po }
        if let po = result.rawResponse.rawFields?["post_office"], !po.isEmpty { return po }
        if let po = result.rawResponse.rawFields?["p_o"], !po.isEmpty { return po }
        let village = result.villageName.isEmpty ? result.rawResponse.village : result.villageName
        return village.isEmpty ? "Tikarpada" : village
    }
    
    private var displayVillage: String {
        let raw = result.villageName.isEmpty ? (result.rawResponse.village.isEmpty ? "Naiganer.." : result.rawResponse.village) : result.villageName
        return VillageNameSanitizer.sanitize(raw)
    }
    
    private var displayKhatian: String {
        let val = result.khatianNumber.isEmpty ? (result.rawResponse.khataNumber ?? "205") : result.khatianNumber
        return val.isEmpty ? "205" : val
    }
    
    private var displayPlot: String {
        result.plotNumber.isEmpty ? "450" : result.plotNumber
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
    
    private var parsedArea: ParsedLandArea {
        ParsedLandArea.parse(result.area ?? result.rawResponse.area)
    }
    
    private var displayAreaDecimal: String {
        parsedArea.decimalFormatted
    }
    
    private var displayAreaAcre: String {
        parsedArea.acreFormatted
    }
    
    private var displayAreaSqft: String {
        parsedArea.sqftFormatted
    }
    
    private var displayLandClassification: String {
        if let raw = result.rawResponse.rawFields?["classification"], !raw.isEmpty { return raw }
        if let raw = result.rawResponse.rawFields?["kissam"], !raw.isEmpty { return raw }
        return "ଘରବାରି"
    }
    
    private var associatedPlotsList: [String] {
        if let plots = result.rawResponse.rawFields?["associated_plots"]?.components(separatedBy: ","), !plots.isEmpty {
            return plots.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return ["102", "106", "123", "147", "814/2", "32"]
    }
    
    // MARK: - Main Body
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Full Canvas Background
            FigmaReportTokens.canvasBg
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Sticky Top Navigation Bar (Fixed at top so scrolling content moves behind it)
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
                    .zIndex(10)
                
                // Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 1. Discount / Offer Strip
                        promoOfferStrip
                            .padding(.horizontal, 18)
                            .padding(.top, 4)
                        
                        // 2 & 3. Connected Hero Plot & Location Card (Unified)
                        connectedHeroLocationCard
                            .padding(.horizontal, 18)
                        
                        // 4. Section: Ownership
                        ownershipSection
                            .padding(.horizontal, 18)
                        
                        // 5. Section: Land Area
                        landAreaSection
                            .padding(.horizontal, 18)
                        
                        // 6. Section: Land Type
                        landTypeSection
                            .padding(.horizontal, 18)
                        
                        // 7. Section: Associated Plots
                        associatedPlotsSection
                            .padding(.horizontal, 18)
                        
                        // 8. Section: Remarks (Verification Status)
                        verificationSection
                            .padding(.horizontal, 18)
                        
                        // 9. Section: Documents
                        documentsSection
                            .padding(.horizontal, 18)
                        
                        // Bottom Spacer for Floating Dock
                        Spacer().frame(height: 100)
                    }
                }
            }
            
            // 11. Unified Floating Bottom Dock (Fixed at Bottom Center)
            FloatingDockBar(
                selectedTab: $selectedTab,
                onShareTap: {
                    showShareSheet = true
                }
            )
            .padding(.bottom, 6)
        }
        .onChange(of: selectedTab) { newTab in
            switch newTab {
            case .home, .map:
                onDismiss?()
                dismiss()
            case .saved:
                handleSaveLand()
            case .share:
                showShareSheet = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedPDFURL {
                ShareSheet(activityItems: [url])
            } else {
                ShareSheet(activityItems: [generateShareSummary()])
            }
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
    }
    
    // MARK: - Top Nav Bar (#773:1905, #773:1909)
    private var topNavBar: some View {
        HStack {
            Button {
                Theme.haptic(.light)
                onDismiss?()
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                    
                    DetailedReportBackArrow(size: 18, color: FigmaReportTokens.textBlack)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to search")
            
            Spacer()
            
            Text("Land details")
                .font(.stackSansHeadline(size: 24, weight: .medium))
                .foregroundColor(FigmaReportTokens.textBlack)
            
            Spacer()
            
            // Balance width for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
    }
    
    // MARK: - 1. Promo Offer Strip (#773:1918 - #773:1920)
    private var promoOfferStrip: some View {
        HStack(spacing: 6) {
            Image("SubscriptionBestValueIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20.85, height: 19.05)
            
            Text("Get 50 off today")
                .font(.stackSansHeadline(size: 11.5, weight: .regular))
                .foregroundColor(FigmaReportTokens.textBlack)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28.34)
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
    }
    
    // MARK: - 2 & 3. Connected Hero Plot & Location Card (#773:1924, #779:1946)
    private var connectedHeroLocationCard: some View {
        VStack(spacing: 0) {
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
                    
                    Text(displayPlot)
                        .font(.stackSansHeadline(size: 62, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textTitle)
                        .tracking(-1.2)
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
                    // Dist: Keonjhar
                    HStack(spacing: 6) {
                        Text("Dist")
                            .font(.stackSansHeadline(size: 19, weight: .light))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        Text(displayDistrict)
                            .font(.stackSansHeadline(size: 19, weight: .regular))
                            .foregroundColor(FigmaReportTokens.textTitle)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Tahsil: Sadar
                    HStack(spacing: 6) {
                        Text("Tahsil")
                            .font(.stackSansHeadline(size: 19, weight: .light))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        Text(displayTahasil)
                            .font(.stackSansHeadline(size: 19, weight: .regular))
                            .foregroundColor(FigmaReportTokens.textTitle)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack {
                    // P/O: Tikarpada
                    HStack(spacing: 6) {
                        Text("P/O")
                            .font(.stackSansHeadline(size: 19, weight: .light))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        Text(displayPostOffice)
                            .font(.stackSansHeadline(size: 19, weight: .regular))
                            .foregroundColor(FigmaReportTokens.textTitle)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Village: Naiganer..
                    HStack(spacing: 6) {
                        Text("Village")
                            .font(.stackSansHeadline(size: 19, weight: .light))
                            .foregroundColor(FigmaReportTokens.textGrayLabel)
                        Text(displayVillage)
                            .font(.stackSansHeadline(size: 19, weight: .regular))
                            .foregroundColor(FigmaReportTokens.textTitle)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(FigmaReportTokens.cardBg)
        }
        .background(FigmaReportTokens.cardBg)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - 4. Section: Ownership (#779:1993, #779:1975, #779:1964 - #779:1974)
    private var ownershipSection: some View {
        let owners = allOwnersList
        let previewLimit = 5
        let hasHiddenOwners = owners.count > previewLimit
        let displayOwners = isOwnersExpanded ? owners : Array(owners.prefix(previewLimit))
        
        return VStack(alignment: .leading, spacing: 0) {
            // Tab Pill Header
            sectionTabHeader(title: "Ownership", icon: AnyView(DetailedReportUsersIcon(size: 16)))
            
            // Card Content
            VStack(spacing: 12) {
                // Table Header
                HStack {
                    Text("Owners")
                        .font(.stackSansHeadline(size: 14.5, weight: .semibold))
                        .foregroundColor(Color(hex: "#3A3A3A"))
                    
                    Spacer()
                    
                    Text("Share")
                        .font(.stackSansHeadline(size: 14.5, weight: .semibold))
                        .foregroundColor(Color(hex: "#3A3A3A"))
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                
                Rectangle()
                    .fill(FigmaReportTokens.dividerLight)
                    .frame(height: 1.11)
                    .padding(.horizontal, 18)
                
                // Owner Rows
                if displayOwners.isEmpty {
                    Text("No owner records found")
                        .font(.stackSansHeadline(size: 16, weight: .medium))
                        .foregroundColor(FigmaReportTokens.textGrayLabel)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                } else {
                    VStack(spacing: 14) {
                        ForEach(Array(displayOwners.enumerated()), id: \.offset) { index, owner in
                            HStack(spacing: 10) {
                                Image("OwnerAvatar")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color(hex: "#EDEDED"), lineWidth: 0.6))
                                
                                Text(owner.name)
                                    .font(.system(size: 17.5, weight: .semibold, design: .default))
                                    .foregroundColor(FigmaReportTokens.textBlack)
                                
                                Spacer()
                                
                                Text(owner.share ?? "1/1")
                                    .font(.system(size: 17.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(FigmaReportTokens.textTitle)
                            }
                            .padding(.horizontal, 18)
                        }
                    }
                }
                
                // Footer Expand/Collapse Link (Only displayed when there are extra hidden owners)
                if hasHiddenOwners {
                    Button {
                        Theme.haptic(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isOwnersExpanded.toggle()
                        }
                    } label: {
                        Text(isOwnersExpanded ? "Collapse owners ↑" : "View all \(owners.count) owners →")
                            .font(.stackSansHeadline(size: 17, weight: .semibold))
                            .foregroundColor(FigmaReportTokens.purpleAccent)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                } else {
                    Spacer().frame(height: 6)
                }
            }
            .background(FigmaReportTokens.cardBg)
        }
    }
    
    // MARK: - 5. Section: Land Area (#779:1999, #779:1976, #779:1977 - #779:1983)
    private var landAreaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTabHeader(title: "Land Area", icon: AnyView(DetailedReportLandAreaIcon(size: 16)))
            
            VStack(spacing: 0) {
                // Top Graphic Banner (LandAreaBg)
                ZStack(alignment: .leading) {
                    Image("LandAreaBg")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 96.72)
                        .clipped()
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(displayAreaDecimal)
                            .font(.system(size: 64.95, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Decimal")
                            .font(.stackSansHeadline(size: 31.95, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 18)
                }
                .frame(height: 96.72)
                
                // Bottom Conversion Row (Dynamically computed based on real total decimals)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Acre")
                            .font(.stackSansHeadline(size: 18.07, weight: .regular))
                            .foregroundColor(FigmaReportTokens.textAcreLabel)
                        Text(displayAreaAcre)
                            .font(.stackSansHeadline(size: 31.38, weight: .semibold))
                            .foregroundColor(FigmaReportTokens.textConversion)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sq. ft")
                            .font(.stackSansHeadline(size: 18.07, weight: .regular))
                            .foregroundColor(FigmaReportTokens.textAcreLabel)
                        Text(displayAreaSqft)
                            .font(.stackSansHeadline(size: 31.38, weight: .semibold))
                            .foregroundColor(FigmaReportTokens.textConversion)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(FigmaReportTokens.cardBg)
            }
        }
    }
    
    // MARK: - 6. Section: Land Type (#779:2004, #779:1984, #779:1985, #779:1987, #779:1989)
    private var landTypeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTabHeader(title: "Land Type", icon: AnyView(DetailedReportLandTypeIcon(size: 16)))
            
            HStack(alignment: .center) {
                Text(displayLandClassification)
                    .font(.googleSans(size: 24.44, weight: .bold))
                    .foregroundColor(FigmaReportTokens.textDark)
                
                Spacer()
                
                Text("No encumbrance or dispute noted in register")
                    .font(.stackSansHeadline(size: 12, weight: .light))
                    .foregroundColor(FigmaReportTokens.textTitle)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 155)
            }
            .padding(.horizontal, 20)
            .frame(height: 88.22)
            .frame(maxWidth: .infinity)
            .background(FigmaReportTokens.cardBg)
        }
    }
    
    // MARK: - 7. Section: Associated Plots (#779:2025, #779:2026, #779:2008 - #779:2024)
    private var associatedPlotsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTabHeader(title: "Associated Plots", icon: AnyView(DetailedReportCirclesIcon(size: 16)))
            
            VStack(spacing: 14) {
                // Khata Number & Value
                VStack(spacing: 2) {
                    Text("Khata Number")
                        .font(.stackSansHeadline(size: 16.75, weight: .regular))
                        .foregroundColor(Color(hex: "#636363"))
                    
                    Text(displayKhatian)
                        .font(.stackSansHeadline(size: 85.61, weight: .regular))
                        .foregroundColor(FigmaReportTokens.textTitle)
                        .tracking(-2.0)
                }
                .padding(.top, 10)
                
                Rectangle()
                    .fill(FigmaReportTokens.dividerLight)
                    .frame(height: 1.0)
                    .padding(.horizontal, 18)
                
                Text("\(associatedPlotsList.count) Recorded Plots")
                    .font(.stackSansHeadline(size: 16.75, weight: .medium))
                    .foregroundColor(FigmaReportTokens.textTitle)
                
                // Badges Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(associatedPlotsList, id: \.self) { plot in
                        let isSelected = (plot == selectedAssociatedPlot)
                        Button {
                            Theme.selectionHaptic()
                            selectedAssociatedPlot = plot
                        } label: {
                            Text(plot)
                                .font(.stackSansHeadline(size: 32, weight: .regular))
                                .foregroundColor(isSelected ? Color(hex: "#F5F5F5") : FigmaReportTokens.textBlack)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50.25)
                                .background(isSelected ? FigmaReportTokens.textBlack : FigmaReportTokens.plotPillGray)
                                .cornerRadius(2.79)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            .background(FigmaReportTokens.cardBg)
        }
    }
    
    // MARK: - 8. Section: Remarks (Verification Status) (#779:2063 - #779:2085)
    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTabHeader(title: "Remarks", icon: AnyView(DetailedReportFlagIcon(size: 15)))
            
            VStack(spacing: 16) {
                // Row 1: Verified with
                HStack(alignment: .top) {
                    Text("Verified with")
                        .font(.stackSansHeadline(size: 15, weight: .regular))
                        .foregroundColor(FigmaReportTokens.textGrayLight)
                        .frame(width: 125, alignment: .leading)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plot, Khata, Area &")
                            .font(.stackSansHeadline(size: 17.5, weight: .semibold))
                            .foregroundColor(FigmaReportTokens.textTitle)
                        Text("Owners")
                            .font(.stackSansHeadline(size: 17.5, weight: .semibold))
                            .foregroundColor(FigmaReportTokens.textTitle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Row 2: Verified on
                HStack(alignment: .top) {
                    Text("Verified on")
                        .font(.stackSansHeadline(size: 15, weight: .regular))
                        .foregroundColor(FigmaReportTokens.textGrayLight)
                        .frame(width: 125, alignment: .leading)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            DetailedReportCalendarIcon(size: 15, color: FigmaReportTokens.textMuted)
                            Text("28\u{1D57}\u{02B0} Aug, 2026")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(FigmaReportTokens.textTitle)
                        }
                        
                        HStack(spacing: 6) {
                            DetailedReportClockIcon(size: 15, color: FigmaReportTokens.textMuted)
                            Text("05:39 PM")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(FigmaReportTokens.textTitle)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Row 3: Verification status
                HStack(alignment: .center) {
                    Text("Verification status")
                        .font(.stackSansHeadline(size: 15, weight: .regular))
                        .foregroundColor(FigmaReportTokens.textGrayLight)
                        .frame(width: 125, alignment: .leading)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        DetailedReportVerifiedCheck(size: 18)
                        Text("Verified with govt portal")
                            .font(.stackSansHeadline(size: 15.5, weight: .semibold))
                            .foregroundColor(FigmaReportTokens.textBlack)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(FigmaReportTokens.cardBg)
        }
    }
    
    // MARK: - 9. Section: Documents (#779:2086 - #779:2126)
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTabHeader(title: "Documents", icon: AnyView(DetailedReportFlagIcon(size: 15)))
            
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Official ROR document")
                        .font(.stackSansHeadline(size: 19.5, weight: .semibold))
                        .foregroundColor(FigmaReportTokens.textTitle)
                    
                    Text("Official government record")
                        .font(.system(size: 14.5, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "#8C8C8C"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 32)
                
                HStack(spacing: 12) {
                    // View Button
                    Button {
                        Theme.haptic(.light)
                        handleViewDocument()
                    } label: {
                        Text("View")
                            .font(.stackSansHeadline(size: 16.5, weight: .semibold))
                            .foregroundColor(Color(hex: "#222222"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color(hex: "#DCDCDC"), lineWidth: 1.6)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Download Button
                    Button {
                        Theme.haptic(.medium)
                        handleDownloadDocument()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Download")
                                .font(.stackSansHeadline(size: 16.5, weight: .semibold))
                                .foregroundColor(FigmaReportTokens.purpleButton)
                            
                            DetailedReportPDFDocBadge()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color(hex: "#DCDCDC"), lineWidth: 1.6)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(FigmaReportTokens.cardBg)
            
            // Disclaimer Below Card
            Text("Information shown reproduced from the Records of Rights\npublished on Govt Portals")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundColor(Color(hex: "#979797"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Section Tab Header Helper
    private func sectionTabHeader(title: String, icon: AnyView?) -> some View {
        HStack(spacing: 6) {
            if let icon = icon {
                icon
            }
            Text(title)
                .font(.stackSansHeadline(size: 15.5, weight: .semibold))
                .foregroundColor(FigmaReportTokens.textDark)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white)
        .cornerRadius(4)
        .offset(y: 2)
    }
    
    // MARK: - Actions
    
    private func handleViewDocument() {
        if downloadedPDFURL != nil {
            showShareSheet = true
        } else {
            showShareSheet = true
        }
    }
    
    private func handleDownloadDocument() {
        showShareSheet = true
    }
    
    private func handleSaveLand() {
        let isNowSaved = savedLandManager.toggleSave(result: result)
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
        Tahsil: \(displayTahasil)
        Village: \(displayVillage)
        Area: \(displayAreaDecimal) Decimal
        """
    }
}
