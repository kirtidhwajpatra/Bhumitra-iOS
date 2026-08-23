//
//  KhatianDetailView.swift
//  MyBhoomi
//
//  Authoritative Land Passport View for Odisha Bhulekh Record of Rights (RoR).
//  Built strictly with Apple's native SF Pro typography and Liquid Glass controls.
//

import SwiftUI
import CoreLocation

public struct KhatianDetailView: View {
    public let result: OfficialSearchResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Share Sheet and PDF download states
    @State private var showShareSheet: Bool = false
    @State private var isExplicitlyOpeningPDF: Bool = false
    @State private var downloadedPDFURL: URL? = nil
    
    public init(result: OfficialSearchResult) {
        self.result = result
    }
    
    // MARK: - Document Colors (Clean Black & Grey with App Accent)
    
    private var docBackground: Color {
        colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.08) : Color.white
    }
    
    private var docPrimary: Color {
        colorScheme == .dark ? Color.white : Color(red: 0.08, green: 0.08, blue: 0.10)
    }
    
    private var docSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.60) : Color.black.opacity(0.55)
    }
    
    private var thinRuleColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
    
    private var specimenBg: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.025)
    }
    
    private var appAccent: Color {
        Color.accentColor
    }
    
    // MARK: - Computed Properties
    
    private var isVerified: Bool {
        result.rawResponse.verification?.status == .verified || result.rawResponse.success
    }
    
    private var isGovernmentLand: Bool {
        result.isGovernmentLand
    }
    
    private var displayTenure: String {
        if let t = result.rawResponse.rawFields?["tenure"], !t.isEmpty {
            return t
        }
        if result.resolutionStatus == .verified {
            return isGovernmentLand ? "Government Estate" : "Rayati (Stitiban)"
        }
        return "Not Available"
    }
    
    private var displayLandlord: String {
        if let ll = result.rawResponse.rawFields?["landlord"], !ll.isEmpty {
            return ll
        }
        return "Not Available"
    }
    
    // Robust parsing of Acre and Decimal
    private var parsedExtent: (acres: String, decimals: String) {
        let raw = (result.area ?? result.rawResponse.area ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return ("0", "0") }
        
        // 1. Matches formats like "0 Acre 0600 Decimal" or "1 Acre 40 Decimal" or "0 Acre 60 Decimal"
        let acreDecRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:Acre|Ac|A)?\s+(\d+)\s*(?:Decimal|Dec|D)?"#, options: .caseInsensitive)
        if let match = acreDecRegex?.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let r1 = Range(match.range(at: 1), in: raw),
               let r2 = Range(match.range(at: 2), in: raw) {
                return (String(raw[r1]), String(raw[r2]))
            }
        }
        
        // 2. Matches "0.06 Ac" or "1.40 Ac" or "0.09"
        let decPointRegex = try? NSRegularExpression(pattern: #"(\d+)\.(\d+)"#, options: [])
        if let match = decPointRegex?.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            if let r1 = Range(match.range(at: 1), in: raw),
               let r2 = Range(match.range(at: 2), in: raw) {
                let ac = String(raw[r1])
                let dec = String(raw[r2])
                return (ac, dec)
            }
        }
        
        // 3. Fallback: digits only
        let digitsOnly = raw.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if !digitsOnly.isEmpty {
            return ("0", digitsOnly)
        }
        
        return ("0", "0")
    }
    
    private var plotRemarksText: String {
        if let rem = result.rawResponse.rawFields?["remarks"], !rem.isEmpty, rem != "—" {
            return rem
        }
        if let plotRem = result.rawResponse.plots.compactMap({ $0.remarks }).first, !plotRem.isEmpty, plotRem != "—" {
            return plotRem
        }
        return "No encumbrance or dispute noted in register"
    }
    
    private var rentCessText: String? {
        if let rent = result.rawResponse.rawFields?["rent_cess"], !rent.isEmpty, rent != "—" {
            return rent
        }
        if let plotRent = result.rawResponse.plots.compactMap({ $0.rentCess }).first, !plotRent.isEmpty, plotRent != "—" {
            return plotRent
        }
        return nil
    }

    public var body: some View {
        ZStack {
            // Background
            docBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Action Controls (Compact Glass Icon Buttons)
                topControlBar
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // ── 1. HEADER: Centered "LAND PASSPORT" Title ─────────
                        headerCenteredTitle
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        
                        // Thin Divider Rule
                        thinDivider
                        
                        // ── 2. METADATA ROW (Clean 3-Column Strip) ───────────
                        metadataIdentityRow
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                        
                        // Thin Divider Rule
                        thinDivider
                        
                        // ── 3. SPECIMEN MEDIA BOX (Cadastral Parcel) ─────────
                        specimenImageBox
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                        
                        // Thin Divider Rule
                        thinDivider
                        
                        // ── 4. ORIGIN / LOCATION SECTION ─────────────────────
                        originSection
                            .padding(.horizontal, 24)
                            .padding(.vertical, 22)
                        
                        // Thin Divider Rule
                        thinDivider
                        
                        // ── 5. TENANCY / OWNERS SECTION ──────────────────────
                        tenancySection
                            .padding(.horizontal, 24)
                            .padding(.vertical, 22)
                        
                        // Thin Divider Rule
                        thinDivider
                        
                        // ── 6. EXTENT / AREA TABLE VIEW ──────────────────────
                        extentTableSection
                            .padding(.horizontal, 24)
                            .padding(.vertical, 22)
                        
                        // Thin Divider Rule
                        thinDivider
                        
                        // ── 7. REMARKS & REVENUE DETAILS ─────────────────────
                        remarksSection
                            .padding(.horizontal, 24)
                            .padding(.vertical, 22)
                        
                        // Thin Divider Rule
                        thinDivider
                        
                        // ── 8. AUDIT & SOURCE INTEGRITY ──────────────────────
                        auditSection
                            .padding(.horizontal, 24)
                            .padding(.vertical, 22)
                        
                        // Thin Divider Rule
                        thinDivider
                        
                        // ── 9. PRIMARY LIQUID GLASS CTA BUTTON ───────────────
                        ctaButtonBlock
                            .padding(.horizontal, 24)
                            .padding(.top, 64)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedPDFURL {
                ShareSheet(activityItems: [url])
            } else {
                ShareSheet(activityItems: [generateShareSummary()])
            }
        }
    }
    
    // MARK: - Thin Divider Rule
    
    private var thinDivider: some View {
        Rectangle()
            .frame(height: 0.8)
            .foregroundColor(thinRuleColor)
            .padding(.horizontal, 20)
    }
    
    // MARK: - Top Modal Control Bar
    
    private var topControlBar: some View {
        HStack {
            // Cancel Button: Compact Icon Button
            Button {
                Theme.haptic(.light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16.5, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Close Land Passport")
            
            Spacer()
            
            // Share Button: Compact Icon Button
            Button {
                Theme.haptic(.light)
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16.5, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Share Land Passport")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - 1. Centered Header: Title & Subtitle
    
    private var headerCenteredTitle: some View {
        VStack(spacing: 5) {
            Text("LAND PASSPORT")
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundColor(docPrimary)
                .lineLimit(1)
            
            Text("OFFICIAL RECORD OF RIGHTS · ODISHA BHULEKH")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundColor(appAccent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - 2. Metadata Identity Row (3 Clean Columns)
    
    private var metadataIdentityRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Column 1: DISTRICT ID
            VStack(alignment: .leading, spacing: 2) {
                Text("DISTRICT ID")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundColor(docSecondary)
                    .lineLimit(1)
                
                Text(!result.districtID.isEmpty ? "OD-\(result.districtID)" : "OD-\(result.districtName.prefix(3).uppercased())")
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundColor(docPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Column 2: SURVEY PLOT
            VStack(alignment: .leading, spacing: 2) {
                Text("PLOT NO")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundColor(docSecondary)
                    .lineLimit(1)
                
                Text(result.plotNumber)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundColor(appAccent)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Column 3: KHATA NO
            VStack(alignment: .leading, spacing: 2) {
                Text("KHATA NO")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundColor(docSecondary)
                    .lineLimit(1)
                
                Text(result.khatianNumber)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundColor(docPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 3. Specimen Media Box (Cadastral Parcel)
    
    private var specimenImageBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(specimenBg)
            
            VStack(spacing: 8) {
                ZStack {
                    CadastralParcelSpecimenShape()
                        .stroke(appAccent, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                        .background(
                            CadastralParcelSpecimenShape()
                                .fill(appAccent.opacity(0.10))
                        )
                        .frame(width: 150, height: 110)
                    
                    VStack(spacing: 2) {
                        Text("PLOT")
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .foregroundColor(appAccent)
                        Text(result.plotNumber)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(appAccent)
                    }
                }
                
                Text("CADASTRAL REVENUE SURVEY · 1:3960")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(docSecondary)
            }
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 195)
    }
    
    // MARK: - 4. ORIGIN / Location Section (Clean Spacing)
    
    private var originSection: some View {
        HStack(alignment: .top, spacing: 24) {
            // Left Margin Tag in Cool Grey
            Text("ORIGIN")
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(docSecondary)
                .frame(width: 80, alignment: .leading)
            
            // Right Content List
            VStack(alignment: .leading, spacing: 14) {
                // Item
                VStack(alignment: .leading, spacing: 2) {
                    Text("REVENUE PARCEL")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(docSecondary)
                    
                    Text("Plot \(result.plotNumber) – \(result.rawResponse.village.isEmpty ? result.villageName : result.rawResponse.village)")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundColor(docPrimary)
                }
                
                // Location Site
                VStack(alignment: .leading, spacing: 2) {
                    Text("ADMINISTRATIVE SITE")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(docSecondary)
                    
                    Text("\(result.rawResponse.tahasil.isEmpty ? result.tahasilName : result.rawResponse.tahasil) Tahasil, \(result.rawResponse.district.isEmpty ? result.districtName : result.rawResponse.district), Odisha")
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(docPrimary)
                }
                
                // Classification
                VStack(alignment: .leading, spacing: 2) {
                    Text("LAND CLASSIFICATION / KISSAM")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(docSecondary)
                    
                    Text("\(result.rawResponse.landType ?? "—") · \(displayTenure)")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundColor(appAccent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 5. TENANCY / Owners Section (Bigger Tenant Names & Clean Spacing)
    
    private var tenancySection: some View {
        HStack(alignment: .top, spacing: 24) {
            // Left Margin Tag in Cool Grey
            Text("TENANCY")
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(docSecondary)
                .frame(width: 80, alignment: .leading)
            
            // Right Content List
            VStack(alignment: .leading, spacing: 14) {
                // Recorded Tenants
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECORDED TENANTS")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(docSecondary)
                    
                    if isGovernmentLand {
                        Text("GOVERNMENT LAND / STATE PROPERTY")
                            .font(.system(size: 17, weight: .bold, design: .default))
                            .foregroundColor(appAccent)
                    } else if result.rawResponse.owners.isEmpty {
                        Text("RECORD UNRESOLVED / NO TENANT FOUND")
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .foregroundColor(docSecondary)
                    } else {
                        ForEach(Array(result.rawResponse.owners.enumerated()), id: \.element.id) { index, owner in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(owner.name)
                                    .font(.system(size: 18, weight: .bold, design: .default))
                                    .foregroundColor(docPrimary)
                                
                                if let s = owner.share, !s.isEmpty {
                                    Text("Share: \(s)")
                                        .font(.system(size: 12.5, weight: .semibold, design: .default))
                                        .foregroundColor(appAccent)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                // Landlord / State
                VStack(alignment: .leading, spacing: 2) {
                    Text("LANDLORD / KHEWATA")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(docSecondary)
                    Text(displayLandlord)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(docPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 6. EXTENT / Area Section (Table View Strip)
    
    private var extentTableSection: some View {
        HStack(alignment: .top, spacing: 24) {
            // Left Margin Tag in Cool Grey
            Text("EXTENT")
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(docSecondary)
                .frame(width: 80, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 10) {
                // Table View Box
                HStack(spacing: 0) {
                    // ACRE Column
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACRE")
                            .font(.system(size: 11.5, weight: .bold, design: .default))
                            .foregroundColor(docSecondary)
                        
                        Text(parsedExtent.acres)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(docPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Vertical Table Divider
                    Rectangle()
                        .frame(width: 1, height: 38)
                        .foregroundColor(thinRuleColor)
                        .padding(.horizontal, 16)
                    
                    // DECIMAL Column
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DECIMAL")
                            .font(.system(size: 11.5, weight: .bold, design: .default))
                            .foregroundColor(docSecondary)
                        
                        Text(parsedExtent.decimals)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(appAccent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(specimenBg)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(thinRuleColor, lineWidth: 1)
                )
                
                // Total Recorded Extent String
                Text("TOTAL RECORDED EXTENT: \(result.area ?? "—")")
                    .font(.system(size: 11.5, weight: .semibold, design: .default))
                    .foregroundColor(docSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 7. REMARKS & Revenue Section (Clean Spacing)
    
    private var remarksSection: some View {
        HStack(alignment: .top, spacing: 24) {
            // Left Margin Tag in Cool Grey
            Text("REMARKS")
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(docSecondary)
                .frame(width: 80, alignment: .leading)
            
            // Right Content List
            VStack(alignment: .leading, spacing: 12) {
                // Remarks / Notes
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLOT REMARKS / ମନ୍ତବ୍ୟ")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(docSecondary)
                    Text(plotRemarksText)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(docPrimary)
                }
                
                // Revenue / Rent & Cess
                if let rent = rentCessText, !rent.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ANNUAL RENT & CESS / ଖଜଣା")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .foregroundColor(docSecondary)
                        Text(rent)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(appAccent)
                    }
                }
                
                // Associated Plots in Khata
                if !result.associatedPlots.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ASSOCIATED PLOTS IN KHATA")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .foregroundColor(docSecondary)
                        Text(result.associatedPlots.joined(separator: ", "))
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(docPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 8. AUDIT & Source Section (Clean Spacing)
    
    private var auditSection: some View {
        HStack(alignment: .top, spacing: 24) {
            // Left Margin Tag in Cool Grey
            Text("AUDIT")
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(docSecondary)
                .frame(width: 80, alignment: .leading)
            
            // Right Content List
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AUTHORITATIVE SOURCE")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(docSecondary)
                    Text("ODISHA BHULEKH PORTAL (NIC)")
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundColor(docPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("RECORD INTEGRITY")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(docSecondary)
                    Text(isVerified ? "✓ EXACT RECORD VERIFIED" : "UNVERIFIED RECORD")
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundColor(isVerified ? appAccent : .orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 9. Primary CTA Button (Clean Spacing & No Subtitle)
    
    private var ctaButtonBlock: some View {
        Button {
            Theme.haptic(.medium)
            openOrDownloadPDF()
        } label: {
            HStack(spacing: 8) {
                if isExplicitlyOpeningPDF {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isExplicitlyOpeningPDF ? "Generating Official RoR..." : "Download Official RoR (PDF)")
                    .font(Theme.Typography.button)
                    .lineLimit(1)
                
                if !isExplicitlyOpeningPDF {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
        }
        .buttonStyle(.glassProminent)
        .tint(.accentColor)
        .disabled(isExplicitlyOpeningPDF)
        .opacity(isExplicitlyOpeningPDF ? 0.65 : 1.0)
        .accessibilityLabel("Download Official RoR PDF")
    }
    
    // MARK: - PDF Download Logic
    
    private func openOrDownloadPDF() {
        if let _ = downloadedPDFURL {
            showShareSheet = true
            return
        }
        
        let khata = result.khatianNumber
        guard !khata.isEmpty, khata != "—", isVerified else {
            showShareSheet = true
            return
        }
        
        isExplicitlyOpeningPDF = true
        _Concurrency.Task {
            do {
                let (url, _, _) = try await RoRService.shared.downloadROR(
                    district: result.districtID,
                    tahasil: result.tahasilID,
                    village: result.villageID,
                    plot: result.plotNumber,
                    khataNumber: khata
                )
                await MainActor.run {
                    self.downloadedPDFURL = url
                    self.isExplicitlyOpeningPDF = false
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isExplicitlyOpeningPDF = false
                    self.showShareSheet = true
                }
            }
        }
    }
    
    private func generateShareSummary() -> String {
        let ownersList = result.rawResponse.owners.map { $0.name }.joined(separator: ", ")
        return """
        BHUMITRA — OFFICIAL LAND PASSPORT
        Plot: \(result.plotNumber)
        Khata: \(result.khatianNumber)
        Village: \(result.villageName)
        Tahasil: \(result.tahasilName)
        District: \(result.districtName), Odisha
        Land Type: \(result.rawResponse.landType ?? "—")
        Area: \(result.area ?? "—")
        Owners: \(ownersList.isEmpty ? (isGovernmentLand ? "Government Land" : "—") : ownersList)
        Verification: OFFICIAL RECORD VERIFIED
        Source: Odisha Bhulekh
        """
    }
}

// MARK: - Cadastral Specimen Shape

private struct CadastralParcelSpecimenShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.08))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.82, y: rect.minY + h * 0.15))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.94, y: rect.minY + h * 0.85))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.45, y: rect.minY + h * 0.95))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.06, y: rect.minY + h * 0.65))
        path.closeSubpath()
        return path
    }
}

// MARK: - Supporting Compatibility Components

public struct DetailInfoRow: View {
    public let label: String
    public let value: String
    public var isHighlighted: Bool = false
    
    public init(label: String, value: String, isHighlighted: Bool = false) {
        self.label = label
        self.value = value
        self.isHighlighted = isHighlighted
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: isHighlighted ? .bold : .semibold))
                .foregroundColor(isHighlighted ? Color.accentColor : .primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    
    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
