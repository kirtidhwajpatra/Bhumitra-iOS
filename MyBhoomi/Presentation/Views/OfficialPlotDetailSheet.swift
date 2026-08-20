import SwiftUI

/// Screen displaying the official verified Record of Rights (RoR) for an individual plot.
public struct OfficialPlotDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let plotNumber: String
    public let parentResult: OfficialSearchResult
    
    @State private var pdfStatus: OfficialPDFStatus = .notStarted
    @State private var isExplicitlyOpeningPDF = false
    @State private var downloadedPDFURL: URL? = nil
    @State private var showShareSheet = false
    
    public init(plotNumber: String, parentResult: OfficialSearchResult) {
        self.plotNumber = plotNumber
        self.parentResult = parentResult
    }
    
    private var associatedPlot: AssociatedPlot? {
        parentResult.rawResponse.plots.first(where: { $0.plotNumber == plotNumber })
    }
    
    private var displayArea: String {
        if let a = associatedPlot?.area, !a.isEmpty { return a }
        if plotNumber == parentResult.plotNumber, let a = parentResult.area, !a.isEmpty { return a }
        return "—"
    }
    
    private var displayLandType: String {
        if let lt = associatedPlot?.landType, !lt.isEmpty { return lt }
        if let lt = parentResult.rawResponse.landType, !lt.isEmpty { return lt }
        return "—"
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Apple-style light background
                Color(white: 0.98).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Official Verified Record Pill
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
                        
                        // 1. Plot & Location Hierarchy Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Plot Details")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                DetailInfoRow(label: "Plot Number", value: plotNumber, isHighlighted: true)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "Khatian", value: parentResult.khatianNumber)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "Area", value: displayArea)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "Land Type", value: displayLandType)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "Village", value: parentResult.rawResponse.village.isEmpty ? parentResult.villageName : parentResult.rawResponse.village)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "Tahasil", value: parentResult.rawResponse.tahasil.isEmpty ? parentResult.tahasilName : parentResult.rawResponse.tahasil)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "District", value: parentResult.rawResponse.district.isEmpty ? parentResult.districtName : parentResult.rawResponse.district)
                                Divider().padding(.leading, 16)
                                DetailInfoRow(label: "Thana", value: parentResult.rawResponse.rawFields?["thana"] ?? "—")
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
                                if !parentResult.rawResponse.owners.isEmpty {
                                    ForEach(parentResult.rawResponse.owners) { owner in
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
                                        if owner.id != parentResult.rawResponse.owners.last?.id {
                                            Divider()
                                        }
                                    }
                                } else if let rawTenant = parentResult.rawResponse.rawFields?["tenant"], !rawTenant.isEmpty {
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
                                    Text(parentResult.rawResponse.landType ?? parentResult.rawResponse.rawFields?["tenure"] ?? "—")
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
                                Text(associatedPlot?.remarks ?? parentResult.rawResponse.rawFields?["remarks"] ?? "—")
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
                        
                        // 4. Open / Share Official PDF Button with Instant Open
                        VStack(spacing: 8) {
                            Button(action: {
                                hapticFeedback(.medium)
                                openOrDownloadPDF()
                            }) {
                                HStack(spacing: 10) {
                                    if isExplicitlyOpeningPDF {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.down.doc.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    
                                    Text(actionButtonTitle)
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.emeraldGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Theme.emeraldGreen.opacity(0.25), radius: 12, x: 0, y: 4)
                            }
                            .disabled(isExplicitlyOpeningPDF)
                            .buttonStyle(ScaledButtonStyle())
                            
                            // Status / Error Indicator
                            switch pdfStatus {
                            case .preparing:
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Preparing official document in background...")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 2)
                            case .ready:
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.emeraldGreen)
                                        .font(.system(size: 12))
                                    Text("Official Document Ready")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.emeraldGreen)
                                }
                                .padding(.top, 2)
                            case .failed(let err):
                                VStack(spacing: 4) {
                                    Text(err)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("Try Again") {
                                        hapticFeedback(.light)
                                        openOrDownloadPDF()
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.emeraldGreen)
                                }
                                .padding(.top, 2)
                            case .notStarted:
                                EmptyView()
                            }
                        }
                        .padding(.top, 10)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Plot \(plotNumber)")
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
                        openOrDownloadPDF()
                    }) {
                        Image(systemName: "printer")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.emeraldGreen)
                    }
                }
            }
            .task {
                await checkOrPrefetchPDF()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = downloadedPDFURL {
                    ActivityView(activityItems: [url])
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
        return "Open / Share Official PDF"
    }
    
    private func checkOrPrefetchPDF() async {
        if let cachedURL = await OfficialRoRPDFService.shared.getCachedURL(
            district: parentResult.districtName,
            tahasil: parentResult.tahasilName,
            village: parentResult.villageName,
            plot: plotNumber,
            khata: parentResult.khatianNumber,
            vId: parentResult.villageID
        ) {
            await MainActor.run {
                self.pdfStatus = .ready(cachedURL)
                self.downloadedPDFURL = cachedURL
            }
            return
        }
        
        await MainActor.run {
            self.pdfStatus = .preparing
        }
        
        do {
            let url = try await OfficialRoRPDFService.shared.fetchOrGetPDF(
                district: parentResult.districtName,
                tahasil: parentResult.tahasilName,
                village: parentResult.villageName,
                plot: plotNumber,
                khataNumber: parentResult.khatianNumber,
                bId: parentResult.tahasilID,
                vId: parentResult.villageID
            )
            await MainActor.run {
                self.pdfStatus = .ready(url)
                self.downloadedPDFURL = url
            }
        } catch {
            await MainActor.run {
                self.pdfStatus = .failed("Official document is temporarily unavailable.")
            }
        }
    }
    
    private func openOrDownloadPDF() {
        if case .ready(let url) = pdfStatus {
            self.downloadedPDFURL = url
            self.showShareSheet = true
            return
        }
        
        isExplicitlyOpeningPDF = true
        _Concurrency.Task {
            do {
                let url = try await OfficialRoRPDFService.shared.fetchOrGetPDF(
                    district: parentResult.districtName,
                    tahasil: parentResult.tahasilName,
                    village: parentResult.villageName,
                    plot: plotNumber,
                    khataNumber: parentResult.khatianNumber,
                    bId: parentResult.tahasilID,
                    vId: parentResult.villageID
                )
                await MainActor.run {
                    self.isExplicitlyOpeningPDF = false
                    self.pdfStatus = .ready(url)
                    self.downloadedPDFURL = url
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isExplicitlyOpeningPDF = false
                    self.pdfStatus = .failed("Official document is temporarily unavailable.")
                }
            }
        }
    }
}
