import SwiftUI

struct ParcelDetailSheet: View {
    let parcel: Parcel
    let onDismiss: () -> Void
    
    @State private var ownerState: OwnerFetchState = .idle
    @State private var showTechnicalDetails = false
    @State private var pdfURL: URL?
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
        case success(RoRResponse)
        case error(String)
        
        static func == (lhs: OwnerFetchState, rhs: OwnerFetchState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading): return true
            case (.success(let a), .success(let b)): return a.owners.count == b.owners.count
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
                    OwnerDetailsSection(state: ownerState, parcel: parcel) {
                        fetchOwnerDetails()
                    }
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
                            ModernRow(label: adminLabels.village, value: getFriendlyValue(for: "v_name") ?? "N/A")
                            Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                            ModernRow(label: "District", value: getFriendlyValue(for: "d_name") ?? "N/A")
                            Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                            ModernRow(label: "Tahsil", value: getFriendlyValue(for: "b_name") ?? "N/A")
                            Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                            ModernRow(label: adminLabels.localBody, value: getFriendlyValue(for: "p_name") ?? "N/A")
                            Divider().background(Color.black.opacity(0.04)).padding(.horizontal, 16)
                            ModernRow(label: "Revenue Plot", value: "\(parcel.metadata.plotNumber)")
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
                        if viewModel.isDownloadingPDF {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
                                Text("Generating Official Report...")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        } else if let url = pdfURL {
                            ShareLink(item: url, preview: SharePreview("Land Record - Plot \(parcel.metadata.plotNumber)", image: Image(systemName: "doc.text.fill"))) {
                                Label("Share Document", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                        } else {
                            Button(action: {
                                AdManager.shared.showAd {
                                    _Concurrency.Task {
                                        if let url = await viewModel.downloadRoRPDF(for: parcel) {
                                            withAnimation { self.pdfURL = url }
                                        }
                                    }
                                }
                            }) {
                                Label("Download Official ROR", systemImage: "arrow.down.doc.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Theme.brandGradient)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(ScaledButtonStyle())
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.white)
        .cornerRadius(32)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateContent = true
            }
        }
    }
    
    private var adminLabels: (village: String, localBody: String) {
        let villageName = getFriendlyValue(for: "v_name")?.uppercased() ?? ""
        let tahsilName = getFriendlyValue(for: "b_name")?.uppercased() ?? ""
        
        let isUrban = villageName.contains("TOWN") || 
                      villageName.contains("MUNICIPAL") || 
                      villageName.contains("NAC") ||
                      villageName.contains("NIJIGARH") ||
                      tahsilName.contains("MUNICIPAL")
        
        return (
            village: isUrban ? "Ward / Locality" : "Village / Town Area",
            localBody: isUrban ? "Municipality / NAC" : "Panchayat / Local Body"
        )
    }
    
    private func getFriendlyValue(for key: String) -> String? {
        return parcel.metadata.additionalInfo?[key]
    }
    
    private func fetchOwnerDetails() {
        AdManager.shared.showAd {
            ownerState = .loading
            hapticFeedback(.light)
            
            _Concurrency.Task {
                do {
                    let result = try await RoRService.shared.fetchOwnerDetails(for: parcel)
                    await MainActor.run {
                        ownerState = .success(result)
                        hapticFeedback(.light)
                    }
                } catch {
                    await MainActor.run {
                        ownerState = .error(error.localizedDescription)
                        hapticFeedback(.medium)
                    }
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
    
    var body: some View {
        VStack(spacing: 0) {
            switch state {
            case .idle:
                Button(action: {
                    hapticFeedback(.medium)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onFetch()
                    }
                }) {
                    HStack {
                        Text("View Ownership record")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(primaryPurple)
                                .frame(width: 38, height: 38)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.04))
                    .cornerRadius(12)
                }
                .buttonStyle(ScaledButtonStyle())
                
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(primaryPurple)
                    Text("Fetching data...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.03))
                .cornerRadius(12)
                
            case .success(let ror):
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("OWNERSHIP RECORDS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(primaryPurple)
                            .tracking(1)
                        Spacer()
                        Text("\(ror.owners.count) HOLDERS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    
                    VStack(spacing: 0) {
                        if ror.owners.isEmpty {
                            Text("No records found.")
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
                
            case .error(let message):
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Connection Error")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Button("RETRY") { onFetch() }
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(primaryPurple)
                    }
                    
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(16)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(16)
            }
        }
    }
}

struct ModernOwnerRow: View {
    let owner: OwnerEntry
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(owner.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                
                if let share = owner.share, !share.isEmpty {
                    Text("Share: \(share)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
    }
}

struct ModernRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.black.opacity(0.6))
            
            Spacer(minLength: 12)
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
}

