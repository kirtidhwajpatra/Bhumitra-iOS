import SwiftUI
import UIKit

/// Official Khatian and Record of Rights (RoR) Detail Screen.
public struct KhatianDetailView: View {
    @Environment(\.dismiss) private var dismiss
    public let result: OfficialSearchResult
    public var onPlotSelected: ((String) -> Void)? = nil
    
    @State private var isDownloadingPDF = false
    @State private var pdfErrorMessage: String? = nil
    @State private var downloadedPDFURL: URL? = nil
    @State private var showShareSheet = false
    
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
    
    private func displayArea(for plot: AssociatedPlot) -> String {
        if let a = plot.area, !a.isEmpty { return a }
        if let a = result.area, !a.isEmpty { return a }
        return "—"
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Apple-style very light grey surface
                Color(white: 0.98).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Official Verification Status Pill
                        if isVerified {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.emeraldGreen)
                                
                                Text("Official Verified Record")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.emeraldGreen)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.emeraldGreen.opacity(0.1))
                            .clipShape(Capsule())
                            .padding(.top, 4)
                        }
                        
                        // 1. Location Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                DetailInfoRow(label: "Khatian", value: result.khatianNumber, isHighlighted: true)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "Village", value: result.rawResponse.village.isEmpty ? result.villageName : result.rawResponse.village)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "Tahasil", value: result.rawResponse.tahasil.isEmpty ? result.tahasilName : result.rawResponse.tahasil)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "District", value: result.rawResponse.district.isEmpty ? result.districtName : result.rawResponse.district)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "Thana", value: result.rawResponse.rawFields?["thana"] ?? result.rawResponse.rawFields?["ps_name"] ?? "—")
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "RI Circle", value: result.rawResponse.rawFields?["ri_circle"] ?? result.rawResponse.rawFields?["circle"] ?? "—")
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                        }
                        
                        // 2. Tenant Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tenant")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.leading, 4)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                if !result.rawResponse.owners.isEmpty {
                                    ForEach(result.rawResponse.owners) { owner in
                                        HStack(alignment: .top) {
                                            Text(owner.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.black)
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            Spacer()
                                            
                                            if let share = owner.share, !share.isEmpty {
                                                Text(share)
                                                    .font(.system(size: 13, weight: .regular))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        if owner.id != result.rawResponse.owners.last?.id {
                                            Divider()
                                        }
                                    }
                                } else if let rawTenant = result.rawResponse.rawFields?["tenant"], !rawTenant.isEmpty {
                                    Text(rawTenant)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.black)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text("—")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("Tenure")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(result.rawResponse.landType ?? result.rawResponse.rawFields?["tenure"] ?? "—")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                        }
                        
                        // 3. Remarks Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Remarks")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.leading, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(result.rawResponse.rawFields?["remarks"] ?? "—")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.black.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                        }
                        
                        // 4. Plots Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Plots (\(plotsList.count))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 10) {
                                ForEach(plotsList) { plot in
                                    Button(action: {
                                        hapticFeedback(.light)
                                        onPlotSelected?(plot.plotNumber)
                                    }) {
                                        HStack(alignment: .center) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("Plot \(plot.plotNumber)")
                                                    .font(.system(size: 17, weight: .bold))
                                                    .foregroundColor(Theme.emeraldGreen)
                                                
                                                Text(displayArea(for: plot))
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 14) {
                                                Image(systemName: "map")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(Theme.emeraldGreen)
                                                
                                                Image(systemName: "bookmark")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(Color.black.opacity(0.3))
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white)
                                                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(ScaledButtonStyle())
                                }
                            }
                        }
                        
                        // 5. Print Action Button
                        VStack(spacing: 8) {
                            Button(action: {
                                hapticFeedback(.medium)
                                downloadAndPrintPDF()
                            }) {
                                HStack(spacing: 10) {
                                    if isDownloadingPDF {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "printer.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    
                                    Text(isDownloadingPDF ? "Preparing Official RoR..." : "Print original khatian")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.emeraldGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Theme.emeraldGreen.opacity(0.25), radius: 12, x: 0, y: 4)
                            }
                            .disabled(isDownloadingPDF)
                            .buttonStyle(ScaledButtonStyle())
                            
                            if let err = pdfErrorMessage {
                                Text(err)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 10)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Khatian \(result.khatianNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        hapticFeedback(.light)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.emeraldGreen)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        hapticFeedback(.medium)
                        downloadAndPrintPDF()
                    }) {
                        Image(systemName: "printer")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.emeraldGreen)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = downloadedPDFURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
    }
    
    private func downloadAndPrintPDF() {
        guard !isDownloadingPDF else { return }
        isDownloadingPDF = true
        pdfErrorMessage = nil
        
        _Concurrency.Task {
            do {
                let (url, _, _) = try await RoRService.shared.downloadROR(
                    district: result.districtName,
                    tahasil: result.tahasilName,
                    village: result.villageName,
                    plot: result.plotNumber,
                    khataNumber: result.khatianNumber,
                    bId: result.tahasilID,
                    vId: result.villageID
                )
                
                await MainActor.run {
                    self.isDownloadingPDF = false
                    self.downloadedPDFURL = url
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isDownloadingPDF = false
                    self.pdfErrorMessage = "Official RoR PDF could not be generated at this time."
                }
            }
        }
    }
}

/// Native UIActivityViewController wrapper for PDF sharing and printing.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}
}

/// Helper row for key-value pairs in the Location section.
struct DetailInfoRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: isHighlighted ? .bold : .semibold))
                .foregroundColor(isHighlighted ? Theme.emeraldGreen : .black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
