import SwiftUI
import UIKit

/// World-Class Official Khatian & RoR Detail View for MyBhoomi.
/// Displays comprehensive authentic Bhulekh land records: Thana, RI Circle, Landlord, Tenants,
/// Tenure, Revenue/Cess, Legal Remarks, and All Related Plots in Khata with 1-tap Official PDF export.
public struct KhatianDetailView: View {
    @Environment(\.dismiss) private var dismiss
    public let result: OfficialSearchResult
    public var onPlotSelected: ((String) -> Void)? = nil
    
    @State private var pdfStatus: OfficialPDFStatus = .notStarted
    @State private var isExplicitlyOpeningPDF = false
    @State private var downloadedPDFURL: URL? = nil
    @State private var showShareSheet = false
    @State private var selectedPlotForDetail: String? = nil
    
    public init(
        result: OfficialSearchResult,
        onPlotSelected: ((String) -> Void)? = nil
    ) {
        self.result = result
        self.onPlotSelected = onPlotSelected
    }
    
    private var isVerified: Bool {
        result.rawResponse.verification?.status == .verified || result.rawResponse.success
    }
    
    private var plotsList: [AssociatedPlot] {
        if !result.rawResponse.plots.isEmpty {
            return result.rawResponse.plots
        }
        return [
            AssociatedPlot(
                plotNumber: result.plotNumber,
                area: result.area,
                landType: result.rawResponse.landType
            )
        ]
    }
    
    private var displayRemarks: String? {
        if let r = result.rawResponse.rawFields?["remarks"], !r.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return r
        }
        // Check plots remarks
        let plotRemarks = result.rawResponse.plots.compactMap { $0.remarks }.filter { !$0.isEmpty }
        if let first = plotRemarks.first {
            return first
        }
        return nil
    }
    
    private var displayThana: String {
        result.rawResponse.rawFields?["thana"] ??
        result.rawResponse.rawFields?["thana_name"] ??
        result.rawResponse.rawFields?["ps_name"] ??
        result.rawResponse.rawFields?["police_station"] ?? "—"
    }
    
    private var displayRICircle: String {
        result.rawResponse.rawFields?["ri_circle"] ??
        result.rawResponse.rawFields?["circle"] ??
        result.rawResponse.rawFields?["circle_name"] ?? "—"
    }
    
    private var displayTenure: String {
        if let t = result.rawResponse.rawFields?["tenure"], !t.isEmpty { return t }
        if let lt = result.rawResponse.landType, !lt.isEmpty { return lt }
        return "Rayati (ରୟତି)"
    }
    
    private var displayLandlord: String {
        result.rawResponse.rawFields?["landlord"] ?? "ଓଡିଶା ସରକାର (State of Odisha)"
    }
    
    private var displayRent: String {
        result.rawResponse.rawFields?["rent"] ?? "—"
    }
    
    private var displayCess: String {
        result.rawResponse.rawFields?["cess"] ?? "—"
    }
    
    private var displayNabaCess: String {
        result.rawResponse.rawFields?["naba_cess"] ?? "—"
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Theme.Color.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // ── 1. VERIFICATION BADGE & SOURCE ───────────────────
                        HStack(alignment: .center) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: isVerified ? "checkmark.seal.fill" : "seal.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(isVerified ? Theme.Color.success : Theme.Color.primary)
                                
                                Text(isVerified ? "VERIFIED OFFICIAL RECORD" : "OFFICIAL RECORD")
                                    .font(Theme.Typography.captionMedium.weight(.bold))
                                    .foregroundColor(isVerified ? Theme.Color.success : Theme.Color.primary)
                                    .tracking(0.5)
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xxs)
                            .background(
                                (isVerified ? Theme.Color.success : Theme.Color.primary).opacity(0.12)
                            )
                            .clipShape(Capsule())
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("Source:")
                                    .font(Theme.Typography.subcaption)
                                    .foregroundColor(Theme.Color.secondaryText)
                                Text("Odisha Bhulekh")
                                    .font(Theme.Typography.subcaption.weight(.bold))
                                    .foregroundColor(Theme.Color.primaryText)
                            }
                        }
                        .padding(.top, Theme.Spacing.xxs)
                        
                        // ── 2. ADMINISTRATIVE & LOCATION CARD ────────────────
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Location Details")
                                .font(Theme.Typography.subcaption.weight(.bold).width(.condensed))
                                .foregroundColor(Theme.Color.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.leading, Theme.Spacing.xxs)
                            
                            VStack(spacing: 0) {
                                DetailInfoRow(label: "Khatian (Khata No)", value: result.khatianNumber, isHighlighted: true)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Revenue Village (Mouza)", value: result.rawResponse.village.isEmpty ? result.villageName : result.rawResponse.village)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Tahasil", value: result.rawResponse.tahasil.isEmpty ? result.tahasilName : result.rawResponse.tahasil)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "District", value: result.rawResponse.district.isEmpty ? result.districtName : result.rawResponse.district)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Thana (Police Station)", value: displayThana)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "RI Circle", value: displayRICircle)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .fill(Theme.Color.surface)
                                    .shadow(color: Theme.Shadow.card, radius: 10, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .stroke(Theme.Color.border, lineWidth: 1)
                            )
                        }
                        
                        // ── 3. TENANTS & OWNERSHIP CARD ──────────────────────
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Record Holders / Tenants (\(result.rawResponse.owners.count))")
                                .font(Theme.Typography.subcaption.weight(.bold).width(.condensed))
                                .foregroundColor(Theme.Color.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.leading, Theme.Spacing.xxs)
                            
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                // Landlord Info Row
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Landlord / Khewata")
                                            .font(Theme.Typography.subcaption)
                                            .foregroundColor(Theme.Color.secondaryText)
                                        Text(displayLandlord)
                                            .font(Theme.Typography.secondaryBodyMedium)
                                            .foregroundColor(Theme.Color.primaryText)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, result.rawResponse.owners.isEmpty ? 0 : Theme.Spacing.xs)
                                
                                if !result.rawResponse.owners.isEmpty {
                                    Divider()
                                    
                                    ForEach(result.rawResponse.owners) { owner in
                                        HStack(alignment: .top) {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(Theme.Color.primary.opacity(0.85))
                                                .padding(.top, 2)
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(owner.name)
                                                    .font(Theme.Typography.primaryBodyBold)
                                                    .foregroundColor(Theme.Color.primaryText)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .lineSpacing(2)
                                                
                                                if let share = owner.share, !share.isEmpty {
                                                    Text("Share: \(share)")
                                                        .font(Theme.Typography.captionMedium)
                                                        .foregroundColor(Theme.Color.primary)
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 2)
                                        
                                        if owner.id != result.rawResponse.owners.last?.id {
                                            Divider().padding(.leading, 28)
                                        }
                                    }
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .fill(Theme.Color.surface)
                                    .shadow(color: Theme.Shadow.card, radius: 10, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .stroke(Theme.Color.border, lineWidth: 1)
                            )
                        }
                        
                        // ── 4. TENURE & REVENUE CARD ─────────────────────────
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Tenure & Revenue")
                                .font(Theme.Typography.subcaption.weight(.bold).width(.condensed))
                                .foregroundColor(Theme.Color.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.leading, Theme.Spacing.xxs)
                            
                            VStack(spacing: 0) {
                                DetailInfoRow(label: "Tenure (ସ୍ୱତ୍ୱ)", value: displayTenure)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Rent (ଖଜଣା)", value: displayRent)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Cess (ସେସ)", value: displayCess)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Naba Cess (ନବ ସେସ)", value: displayNabaCess)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .fill(Theme.Color.surface)
                                    .shadow(color: Theme.Shadow.card, radius: 10, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .stroke(Theme.Color.border, lineWidth: 1)
                            )
                        }
                        
                        // ── 5. LEGAL REMARKS SECTION ─────────────────────────
                        if let remarks = displayRemarks {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Theme.Color.warning)
                                    
                                    Text("Official Remarks (ମନ୍ତବ୍ୟ)")
                                        .font(Theme.Typography.subcaption.weight(.bold).width(.condensed))
                                        .foregroundColor(Theme.Color.secondaryText)
                                        .textCase(.uppercase)
                                        .tracking(0.6)
                                }
                                .padding(.leading, Theme.Spacing.xxs)
                                
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    Text(remarks)
                                        .font(Theme.Typography.secondaryBody)
                                        .foregroundColor(Theme.Color.primaryText.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(4)
                                }
                                .padding(Theme.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                        .fill(Theme.Color.warning.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                        .stroke(Theme.Color.warning.opacity(0.25), lineWidth: 1)
                                )
                            }
                        }
                        
                        // ── 6. ALL PLOTS IN KHATIAN ──────────────────────────
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Plots in Khatian (\(plotsList.count))")
                                .font(Theme.Typography.subcaption.weight(.bold).width(.condensed))
                                .foregroundColor(Theme.Color.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.leading, Theme.Spacing.xxs)
                            
                            VStack(spacing: Theme.Spacing.xs) {
                                ForEach(plotsList) { plot in
                                    Button(action: {
                                        Theme.haptic(.light)
                                        selectedPlotForDetail = plot.plotNumber
                                        onPlotSelected?(plot.plotNumber)
                                    }) {
                                        HStack(alignment: .center) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: Theme.Spacing.xs) {
                                                    Text("Plot \(plot.plotNumber)")
                                                        .font(Theme.Typography.primaryBodyBold.width(.condensed))
                                                        .foregroundColor(plot.plotNumber == result.plotNumber ? Theme.Color.primary : Theme.Color.primaryText)
                                                    
                                                    if plot.plotNumber == result.plotNumber {
                                                        Text("CURRENT")
                                                            .font(Theme.Typography.subcaption.weight(.bold).width(.condensed))
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Theme.Color.primary)
                                                            .clipShape(Capsule())
                                                    }
                                                }
                                                
                                                HStack(spacing: Theme.Spacing.sm) {
                                                    if let lt = plot.landType, !lt.isEmpty {
                                                        Text(lt)
                                                            .font(Theme.Typography.captionMedium)
                                                            .foregroundColor(Theme.Color.secondaryText)
                                                    }
                                                    
                                                    if let a = plot.area, !a.isEmpty {
                                                        Text("•  \(a)")
                                                            .font(Theme.Typography.captionMedium)
                                                            .foregroundColor(Theme.Color.secondaryText)
                                                    }
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Theme.Color.tertiaryText)
                                        }
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, Theme.Spacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                                .fill(plot.plotNumber == result.plotNumber ? Theme.Color.primaryLight : Theme.Color.surface)
                                                .shadow(color: Theme.Shadow.card, radius: 6, x: 0, y: 2)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                                .stroke(plot.plotNumber == result.plotNumber ? Theme.Color.primary.opacity(0.35) : Theme.Color.border, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(ScaledButtonStyle())
                                }
                            }
                        }
                        
                        // ── 7. DOWNLOAD / SHARE OFFICIAL ROR PDF (Exact LiquidGlassButtonsDemo Style) ─────────────
                        VStack(spacing: Theme.Spacing.xs) {
                            Button {
                                openOrDownloadPDF()
                            } label: {
                                HStack(spacing: 8) {
                                    if isExplicitlyOpeningPDF {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "printer.fill")
                                            .font(.headline)
                                    }
                                    
                                    Text(actionButtonTitle)
                                        .font(.headline)
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.accentColor)
                            .disabled(isExplicitlyOpeningPDF)
                            .opacity(isExplicitlyOpeningPDF ? 0.65 : 1.0)
                            
                            // Live Status Indicator
                            switch pdfStatus {
                            case .preparing:
                                HStack(spacing: Theme.Spacing.xs) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Preparing official document in background...")
                                        .font(Theme.Typography.captionMedium)
                                        .foregroundColor(Theme.Color.secondaryText)
                                }
                                .padding(.top, Theme.Spacing.xxs)
                            case .ready(_):
                                HStack(spacing: Theme.Spacing.xxs) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.Color.success)
                                        .font(.system(size: 12))
                                    Text("Official Document Ready")
                                        .font(Theme.Typography.captionMedium)
                                        .foregroundColor(Theme.Color.success)
                                }
                                .padding(.top, Theme.Spacing.xxs)
                            case .failed(let err):
                                HStack(spacing: Theme.Spacing.xxs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Theme.Color.error)
                                        .font(.system(size: 12))
                                    Text(err)
                                        .font(Theme.Typography.captionMedium)
                                        .foregroundColor(Theme.Color.error)
                                }
                                .padding(.top, Theme.Spacing.xxs)
                            case .notStarted:
                                EmptyView()
                            }
                        }
                        .padding(.top, Theme.Spacing.xs)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .navigationTitle("Khatian \(result.khatianNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if downloadedPDFURL != nil {
                        Button {
                            showShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .task {
                await checkOrPrefetchPDF()
            }
            .sheet(item: $selectedPlotForDetail) { plotNum in
                OfficialPlotDetailSheet(
                    plotNumber: plotNum,
                    parentResult: result
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = downloadedPDFURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private var actionButtonTitle: String {
        if isExplicitlyOpeningPDF {
            return "Opening Official RoR..."
        }
        if case .ready = pdfStatus {
            return "Open Official PDF"
        }
        if case .preparing = pdfStatus {
            return "Preparing PDF..."
        }
        return "View Official RoR PDF"
    }
    
    private func checkOrPrefetchPDF() async {
        guard pdfStatus == .notStarted else { return }
        let districtID = result.districtID
        let tahasilID = result.tahasilID
        let villageID = result.villageID
        let khatian = result.khatianNumber
        
        guard !districtID.isEmpty, !tahasilID.isEmpty, !villageID.isEmpty, !khatian.isEmpty else {
            return
        }
        
        pdfStatus = .preparing
        
        do {
            let (url, _, _) = try await RoRService.shared.downloadROR(
                district: districtID,
                tahasil: tahasilID,
                village: villageID,
                plot: result.plotNumber,
                khataNumber: khatian
            )
            await MainActor.run {
                self.downloadedPDFURL = url
                self.pdfStatus = .ready(url)
                if self.isExplicitlyOpeningPDF {
                    self.isExplicitlyOpeningPDF = false
                    self.showShareSheet = true
                }
            }
        } catch {
            await MainActor.run {
                self.pdfStatus = .failed(error.localizedDescription)
                self.isExplicitlyOpeningPDF = false
            }
        }
    }
    
    private func openOrDownloadPDF() {
        if let _ = downloadedPDFURL {
            showShareSheet = true
            return
        }
        
        isExplicitlyOpeningPDF = true
        _Concurrency.Task {
            await checkOrPrefetchPDF()
        }
    }
}

// Extension to allow String to be Identifiable for .sheet(item: ...)
extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct DetailInfoRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(Theme.Typography.captionMedium)
                .foregroundColor(Theme.Color.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(isHighlighted ? Theme.Typography.primaryBodyBold : Theme.Typography.secondaryBodyMedium)
                .foregroundColor(isHighlighted ? Theme.Color.primary : Theme.Color.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
