import SwiftUI
import UIKit

/// High-fidelity Official Plot Detail Sheet.
/// Presents authentic Record of Rights (RoR) data for a specific plot, directly connected to Bhulekh.
public struct OfficialPlotDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let plotNumber: String
    public let parentResult: OfficialSearchResult
    
    @State private var pdfStatus: OfficialPDFStatus = .notStarted
    @State private var isExplicitlyOpeningPDF = false
    @State private var downloadedPDFURL: URL? = nil
    @State private var showShareSheet = false
    
    public init(
        plotNumber: String,
        parentResult: OfficialSearchResult
    ) {
        self.plotNumber = plotNumber
        self.parentResult = parentResult
    }
    
    private var associatedPlot: AssociatedPlot? {
        parentResult.rawResponse.plots.first(where: { $0.plotNumber == plotNumber })
    }
    
    private var displayArea: String {
        if let a = associatedPlot?.area, !a.isEmpty { return a }
        if let a = parentResult.area, !a.isEmpty { return a }
        return "—"
    }
    
    private var displayLandType: String {
        if let lt = associatedPlot?.landType, !lt.isEmpty { return lt }
        if let lt = parentResult.rawResponse.landType, !lt.isEmpty { return lt }
        return parentResult.rawResponse.rawFields?["tenure"] ?? "—"
    }
    
    private var displayRemarks: String {
        if let r = associatedPlot?.remarks, !r.isEmpty { return r }
        if let r = parentResult.rawResponse.rawFields?["remarks"], !r.isEmpty { return r }
        return "—"
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Theme.Color.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Official Verified Record Pill
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.Color.success)
                            
                            Text("Official Verified Record")
                                .font(Theme.Typography.captionMedium)
                                .foregroundColor(Theme.Color.success)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Theme.Color.success.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.top, Theme.Spacing.xxs)
                        
                        // 1. Plot & Location Hierarchy Section
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Plot Details")
                                .font(Theme.Typography.subcaption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Color.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.leading, Theme.Spacing.xxs)
                            
                            VStack(spacing: 0) {
                                DetailInfoRow(label: "Plot Number", value: plotNumber, isHighlighted: true)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Khatian", value: parentResult.khatianNumber)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Area", value: displayArea)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Land Type", value: displayLandType)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Village", value: parentResult.rawResponse.village.isEmpty ? parentResult.villageName : parentResult.rawResponse.village)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Tahasil", value: parentResult.rawResponse.tahasil.isEmpty ? parentResult.tahasilName : parentResult.rawResponse.tahasil)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "District", value: parentResult.rawResponse.district.isEmpty ? parentResult.districtName : parentResult.rawResponse.district)
                                Divider().padding(.leading, Theme.Spacing.md)
                                DetailInfoRow(label: "Thana", value: parentResult.rawResponse.rawFields?["thana"] ?? "—")
                            }
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .fill(Theme.Color.surface)
                                    .shadow(color: Theme.Shadow.subtle, radius: 10, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .stroke(Theme.Color.border, lineWidth: 1)
                            )
                        }
                        
                        // 2. Tenant Section
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Tenant")
                                .font(Theme.Typography.subcaption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Color.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.leading, Theme.Spacing.xxs)
                            
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                if !parentResult.rawResponse.owners.isEmpty {
                                    ForEach(parentResult.rawResponse.owners) { owner in
                                        HStack(alignment: .top) {
                                            Text(owner.name)
                                                .font(Theme.Typography.secondaryBodyMedium)
                                                .foregroundColor(Theme.Color.primaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            Spacer()
                                            
                                            if let share = owner.share, !share.isEmpty {
                                                Text(share)
                                                    .font(Theme.Typography.captionMedium)
                                                    .foregroundColor(Theme.Color.secondaryText)
                                            }
                                        }
                                        if owner.id != parentResult.rawResponse.owners.last?.id {
                                            Divider()
                                        }
                                    }
                                } else {
                                    Text(parentResult.rawResponse.rawFields?["landlord"] ?? "—")
                                        .font(Theme.Typography.secondaryBodyMedium)
                                        .foregroundColor(Theme.Color.primaryText)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .fill(Theme.Color.surface)
                                    .shadow(color: Theme.Shadow.subtle, radius: 10, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .stroke(Theme.Color.border, lineWidth: 1)
                            )
                        }
                        
                        // 3. Remarks Section
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Remarks")
                                .font(Theme.Typography.subcaption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Color.secondaryText)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .padding(.leading, Theme.Spacing.xxs)
                            
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(displayRemarks)
                                    .font(Theme.Typography.secondaryBody)
                                    .foregroundColor(Theme.Color.primaryText.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .fill(Theme.Color.surface)
                                    .shadow(color: Theme.Shadow.subtle, radius: 10, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                                    .stroke(Theme.Color.border, lineWidth: 1)
                            )
                        }
                        
                        // 4. Print / Download Action Button
                        VStack(spacing: Theme.Spacing.xs) {
                            Button(action: {
                                openOrDownloadPDF()
                            }) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    if isExplicitlyOpeningPDF {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "printer.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    
                                    Text(actionButtonTitle)
                                        .font(Theme.Typography.primaryBodyBold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(Theme.Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                                .shadow(color: Theme.Shadow.primaryGlow, radius: 12, x: 0, y: 4)
                            }
                            .disabled(isExplicitlyOpeningPDF)
                            .buttonStyle(ScaledButtonStyle())
                            
                            // Status / Error Indicator
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
            .navigationTitle("Plot \(plotNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Close")
                            .font(Theme.Typography.primaryBody)
                            .foregroundColor(Theme.Color.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if downloadedPDFURL != nil {
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Theme.Color.primary)
                        }
                    }
                }
            }
            .task {
                await checkOrPrefetchPDF()
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
        
        let districtID = parentResult.districtID
        let tahasilID = parentResult.tahasilID
        let villageID = parentResult.villageID
        let khatian = parentResult.khatianNumber
        
        guard !districtID.isEmpty, !tahasilID.isEmpty, !villageID.isEmpty, !khatian.isEmpty else {
            return
        }
        
        pdfStatus = .preparing
        
        do {
            let (url, _, _) = try await RoRService.shared.downloadROR(
                district: districtID,
                tahasil: tahasilID,
                village: villageID,
                plot: plotNumber,
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
