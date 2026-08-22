import SwiftUI

struct ParcelDetailSheet: View {
    let parcel: Parcel
    let onDismiss: () -> Void
    
    @State private var ownerState: OwnerFetchState = .idle
    @State private var showTechnicalDetails = false
    @State private var pdfURL: URL?
    @State private var pdfState: PDFDownloadState = .idle
    @State private var showManualSearch = false
    @State private var manualSearchMode: ManualSearchMode = .plot
    @ObservedObject var viewModel: MapViewModel
    
    // Explicit initializer to avoid memberwise init confusion
    init(parcel: Parcel, viewModel: MapViewModel, onDismiss: @escaping () -> Void) {
        self.parcel = parcel
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    enum OwnerFetchState: Equatable {
        case idle
        case loading
        case success(RoRResponse, ParcelVerificationResult)
        case unverified(ParcelVerificationResult)
        case notFound(String)
        case temporarilyUnavailable(String)
        case error(String)
        
        static func == (lhs: OwnerFetchState, rhs: OwnerFetchState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading): return true
            case (.success(let a, let va), .success(let b, let vb)): return a.owners.count == b.owners.count && va == vb
            case (.unverified(let a), .unverified(let b)): return a == b
            case (.notFound(let a), .notFound(let b)): return a == b
            case (.temporarilyUnavailable(let a), .temporarilyUnavailable(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }
    
    @State private var animateContent = false
    @State private var statusPulse = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Premium Drag Handle & Close
            HStack {
                Spacer()
                Button(action: {
                    hapticFeedback(.medium)
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(Color.black.opacity(0.15))
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header Section: Refined Premium Style
                    VStack(alignment: .center, spacing: 12) {
                        VStack(spacing: 4) {
                            Text("RECORD OF RIGHTS")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.primary)
                                .tracking(1.5)
                            
                            Text("Legal Ownership Detail")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color.black)
                        }
                        
                        HStack(spacing: 16) {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color.black.opacity(0.05))
                            
                            HStack(spacing: 6) {
                                Text("PLOT")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .fixedSize()
                                Text("\(parcel.metadata.plotNumber)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Theme.primary)
                                    .fixedSize()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.primary.opacity(0.05))
                            .clipShape(Capsule())
                            .layoutPriority(1)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color.black.opacity(0.05))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.top, 10)
                    
                    // Main Action Section
                    OwnerDetailsSection(
                        state: ownerState,
                        parcel: parcel,
                        onFetch: {
                            fetchOwnerDetails()
                        },
                        onFallbackSearch: { mode in
                            manualSearchMode = mode
                            showManualSearch = true
                        }
                    )
                    .background(Theme.surface)
                    .cornerRadius(16)
                    
                    // Information Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GEOGRAPHICAL DETAILS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.5))
                            .tracking(1.0)
                            .padding(.leading, 8)
                        
                        VStack(spacing: 0) {
                            ModernRow(label: adminLabels.village, value: parcel.identity.villageName)
                            Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                            ModernRow(label: "District", value: parcel.identity.districtName)
                            Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                            ModernRow(label: "Tahasil", value: parcel.identity.tahasilName)
                            if let panchayat = parcel.identity.panchayatName, !panchayat.isEmpty {
                                Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                                ModernRow(label: adminLabels.localBody, value: panchayat)
                            }
                            Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                            ModernRow(label: "Revenue Plot", value: "\(parcel.identity.plotNumber)")
                            if let area = parcel.metadata.estimatedAreaAcre, area > 0 {
                                Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                                ModernRow(label: "Estimated Map Area", value: String(format: "%.2f Acre", area))
                            }
                            if parcel.boundary.count >= 3 {
                                Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                                ModernRow(label: "GPS (Lat, Long)", value: String(format: "%.6f, %.6f", parcel.center.latitude, parcel.center.longitude))
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    
                    // PDF / Document Actions
                    VStack(spacing: 16) {
                        switch pdfState {
                        case .idle:
                            Button(action: {
                                downloadRoRPDF()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 18))
                                    Text("Download Official RoR (PDF)")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(color: Theme.primary.opacity(0.25), radius: 12, y: 6)
                            }
                            
                        case .downloading:
                            HStack(spacing: 12) {
                                ProgressView().tint(.white)
                                Text("Downloading Official Document...")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            
                        case .validating:
                            HStack(spacing: 12) {
                                ProgressView().tint(.white)
                                Text("Validating & Verifying Checksum...")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            
                        case .ready(let url, let isOfflineSaved, let metadata):
                            VStack(spacing: 12) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 14))
                                        Text(isOfflineSaved ? "SAVED ON THIS DEVICE" : "OFFICIAL PDF READY")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.green)
                                    }
                                    Spacer()
                                    Text("\(metadata.fileSize / 1024) KB")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 4)
                                
                                if isOfflineSaved {
                                    Text("Retrieved: \(metadata.formattedDate)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                }
                                
                                ShareLink(
                                    item: url,
                                    preview: SharePreview("Official RoR - Plot \(parcel.metadata.plotNumber)", image: Image(systemName: "doc.text.fill"))
                                ) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "square.and.arrow.up.fill")
                                            .font(.system(size: 16))
                                        Text("Open / Share Official PDF")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.green)
                                    .cornerRadius(14)
                                    .shadow(color: Color.green.opacity(0.25), radius: 10, y: 4)
                                }
                            }
                            .padding(16)
                            .background(Color.green.opacity(0.08))
                            .cornerRadius(18)
                            
                        case .failed(let message):
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("PDF Download Issue")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Button("TRY AGAIN") {
                                        downloadRoRPDF()
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.primary)
                                }
                                Text(message.isEmpty ? "Ownership record verified, but PDF document could not be generated." : message)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color.orange.opacity(0.08))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.top, 8)
                    
                    // Footer Verification Badge
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.primary.opacity(0.6))
                        Text("Official Land Records • Odisha Bhulekh Portal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.12), radius: 30, y: -10)
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $showManualSearch) {
            NavigationView {
                ManualRoRSearchView(
                    initialDistrict: parcel.identity.districtName,
                    initialTahasil: parcel.identity.tahasilName,
                    initialVillage: parcel.identity.villageName,
                    suggestedPlot: parcel.metadata.plotNumber,
                    initialMode: manualSearchMode
                )
                .navigationTitle("Manual RoR Search")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showManualSearch = false }
                    }
                }
            }
        }
        .onAppear {
            checkLocalCachedDocument()
        }
    }
    
    // Dynamic localization-friendly labels
    private var adminLabels: (village: String, localBody: String) {
        let isOdisha = parcel.identity.districtName.uppercased().contains("ODISHA") ||
                       !parcel.identity.districtName.isEmpty
        return isOdisha
            ? (village: "Revenue Village (Mouza)", localBody: "Gram Panchayat")
            : (village: "Village", localBody: "Local Body")
    }
    
    private func checkLocalCachedDocument() {
        let id = parcel.identity
        _Concurrency.Task {
            if let cached = await PDFDocumentManager.shared.getCachedDocument(
                district: id.districtName,
                tahasil: id.tahasilName,
                village: id.villageName,
                plot: id.plotNumber,
                vId: id.villageID
            ) {
                await MainActor.run {
                    self.pdfState = .ready(url: cached.url, isOfflineSaved: true, metadata: cached.metadata)
                }
            }
        }
    }
    
    private func downloadRoRPDF() {
        pdfState = .downloading
        _Concurrency.Task {
            do {
                let (url, metadata, isOfflineSaved) = try await RoRService.shared.downloadROR(for: parcel)
                await MainActor.run {
                    self.pdfState = .ready(url: url, isOfflineSaved: isOfflineSaved, metadata: metadata)
                    hapticFeedback(.light)
                }
            } catch let err as RoRError {
                await MainActor.run {
                    self.pdfState = .failed(message: err.localizedDescription)
                    hapticFeedback(.medium)
                }
            } catch {
                await MainActor.run {
                    self.pdfState = .failed(message: error.localizedDescription)
                    hapticFeedback(.medium)
                }
            }
        }
    }
    
    private func fetchOwnerDetails() {
        ownerState = .loading
        _Concurrency.Task {
            do {
                let ror = try await RoRService.shared.fetchOwnerDetails(for: parcel)
                let verif = ParcelCrossVerifier.verify(
                    gisIdentity: parcel.identity,
                    rorResponse: ror,
                    gisAreaInAcre: parcel.metadata.estimatedAreaAcre
                )
                await MainActor.run {
                    if verif.isVerified {
                        self.ownerState = .success(ror, verif)
                        hapticFeedback(.light)
                    } else {
                        self.ownerState = .unverified(verif)
                        hapticFeedback(.medium)
                    }
                }
            } catch let rorError as RoRError {
                await MainActor.run {
                    switch rorError {
                    case .notFound(let msg):
                        self.ownerState = .notFound(msg)
                    case .temporarilyUnavailable(let msg), .timeout(let msg):
                        self.ownerState = .temporarilyUnavailable(msg)
                    case .identityMismatch:
                        let verif = ParcelCrossVerifier.verify(
                            gisIdentity: parcel.identity,
                            rorResponse: nil,
                            gisAreaInAcre: parcel.metadata.estimatedAreaAcre,
                            error: rorError
                        )
                        self.ownerState = .unverified(verif)
                    default:
                        self.ownerState = .error(rorError.localizedDescription)
                    }
                    hapticFeedback(.medium)
                }
            } catch {
                await MainActor.run {
                    self.ownerState = .error(error.localizedDescription)
                    hapticFeedback(.medium)
                }
            }
        }
    }
}

// MARK: - Owner Details Section

struct OwnerDetailsSection: View {
    let state: ParcelDetailSheet.OwnerFetchState
    let parcel: Parcel
    let onFetch: () -> Void
    var onFallbackSearch: ((ManualSearchMode) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            switch state {
            case .idle:
                Button {
                    hapticFeedback(.medium)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onFetch()
                    }
                } label: {
                    HStack {
                        Text("View Ownership Record")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.accentColor)
                
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(primaryPurple)
                    Text("Cross-verifying land records...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.03))
                .cornerRadius(12)
                
            case .success(let ror, let verif):
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("VERIFIED RECORD OF RIGHTS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                                .tracking(0.5)
                        }
                        Spacer()
                        Text("\(ror.owners.count) HOLDERS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    
                    if let notes = verif.areaComparisonNotes {
                        Text(notes)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                    }
                    
                    VStack(spacing: 0) {
                        if ror.owners.isEmpty {
                            Text("No private records found (Government Land).")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(24)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(ror.owners) { owner in
                                ModernOwnerRow(owner: owner)
                                if owner.id != ror.owners.last?.id {
                                    Divider().background(Color.black.opacity(0.05)).padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .background(Color.black.opacity(0.03))
                    .cornerRadius(16)
                }
                
            case .unverified(let verif):
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.slash.fill")
                                .foregroundColor(.orange)
                            Text("Record Found — Verification Needed")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        
                        Text("We received a response from Odisha Bhulekh, but we could not safely verify that it belongs to this parcel.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(verif.reasons, id: \.self) { reason in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .foregroundColor(.orange)
                                    Text(reason)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(16)
                    
                    MapFallbackSearchCard(
                        district: parcel.identity.districtName,
                        tahasil: parcel.identity.tahasilName,
                        village: parcel.identity.villageName,
                        suggestedPlot: parcel.metadata.plotNumber,
                        onSelectSearchMode: { mode in
                            onFallbackSearch?(mode)
                        }
                    )
                }
                
            case .notFound(let message):
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.orange)
                            Text("Official Land Record Not Found")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                        }
                        
                        Text(message.isEmpty ? "No official RoR record was found for this plot in Bhulekh land records." : message)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(16)
                    
                    MapFallbackSearchCard(
                        district: parcel.identity.districtName,
                        tahasil: parcel.identity.tahasilName,
                        village: parcel.identity.villageName,
                        suggestedPlot: parcel.metadata.plotNumber,
                        onSelectSearchMode: { mode in
                            onFallbackSearch?(mode)
                        }
                    )
                }

            case .temporarilyUnavailable(let message):
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(Theme.primary)
                            Text("Official Records Temporarily Unavailable")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                        }
                        
                        Text(message.isEmpty ? "Odisha land records service is temporarily unreachable. Please try again." : message)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Theme.primary.opacity(0.08))
                    .cornerRadius(16)
                    
                    Button {
                        onFetch()
                    } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glass)
                }

            case .error(let message):
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Lookup Failed")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Button {
                                onFetch()
                            } label: {
                                Text("Retry")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.glass)
                        }
                        
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    
                    MapFallbackSearchCard(
                        district: parcel.identity.districtName,
                        tahasil: parcel.identity.tahasilName,
                        village: parcel.identity.villageName,
                        suggestedPlot: parcel.metadata.plotNumber,
                        onSelectSearchMode: { mode in
                            onFallbackSearch?(mode)
                        }
                    )
                }
            }
        }
    }
}

struct ModernOwnerRow: View {
    let owner: OwnerEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(primaryPurple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(owner.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                
                if let share = owner.share, !share.isEmpty {
                    Text("Share: \(share)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let khata = owner.khataNumber, !khata.isEmpty {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("KHATA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(khata)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ModernRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
