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
            HStack {
                Spacer()
                Button(action: {
                    hapticFeedback(.medium)
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.black.opacity(0.2))
                }
                .padding(16)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(alignment: .center, spacing: 16) {
                        VStack(spacing: 0) {
                            Text("RECORDS OF RIGHT")
                            Text("(ROR)")
                        }
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Text("PLOT")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black.opacity(0.6))
                                Text("\(parcel.metadata.plotNumber)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(primaryPurple)
                            }
                            
                            Text(getFriendlyValue(for: "v_name")?.uppercased() ?? "UNKNOWN")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black.opacity(0.6))
                            
                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                                .frame(height: 1)
                                .frame(width: 140)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 10)
                    
                    // Main Action Button (Fetch Owner)
                    OwnerDetailsSection(state: ownerState, parcel: parcel) {
                        fetchOwnerDetails()
                    }
                    
                    // Static Details List
                    VStack(spacing: 0) {
                        ModernRow(label: "Village", value: getFriendlyValue(for: "v_name") ?? "N/A")
                        Divider().background(Color.black.opacity(0.05)).padding(.horizontal, 16)
                        ModernRow(label: "Dist", value: getFriendlyValue(for: "d_name") ?? "N/A")
                        Divider().background(Color.black.opacity(0.05)).padding(.horizontal, 16)
                        ModernRow(label: "Tahsil", value: getFriendlyValue(for: "b_name") ?? "N/A")
                        Divider().background(Color.black.opacity(0.05)).padding(.horizontal, 16)
                        ModernRow(label: "Panchayat", value: getFriendlyValue(for: "p_name") ?? "N/A")
                        Divider().background(Color.black.opacity(0.05)).padding(.horizontal, 16)
                        ModernRow(label: "Revenue Plot", value: parcel.metadata.plotNumber)
                        Divider().background(Color.black.opacity(0.05)).padding(.horizontal, 16)
                        ModernRow(label: "Area", value: "\(parcel.metadata.area) \(parcel.metadata.areaUnit)")
                    }
                    .background(Color.white)
                    
                    // PDF Download Section
                    VStack(spacing: 16) {
                        if viewModel.isDownloadingPDF {
                            HStack {
                                ProgressView()
                                    .tint(primaryPurple)
                                Text("Preparing Official PDF...")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(primaryPurple)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(primaryPurple.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else if let url = pdfURL {
                            ShareLink(item: url, preview: SharePreview("Record of Right - Plot \(parcel.metadata.plotNumber)", image: Image(systemName: "doc.text.fill"))) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up.fill")
                                    Text("Share / Save ROR PDF")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        } else {
                            Button(action: {
                                Task {
                                    if let url = await viewModel.downloadRoRPDF(for: parcel) {
                                        withAnimation {
                                            self.pdfURL = url
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "doc.append.fill")
                                    Text("Download Official ROR")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(primaryPurple)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(ScaledButtonStyle())
                        }
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.15), radius: 40, x: 0, y: 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateContent = true
            }
        }
    }
    
    private func getFriendlyValue(for key: String) -> String? {
        return parcel.metadata.additionalInfo?[key]
    }
    
    private func fetchOwnerDetails() {
        ownerState = .loading
        hapticFeedback(.light)
        
        Task {
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
                    .padding(.leading, 20)
                    .padding(.trailing, 8)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaledButtonStyle())
                
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(primaryPurple)
                    Text("Fetching data...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.04))
                .clipShape(Capsule())
                
            case .success(let ror):
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("OWNERSHIP RECORDS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(primaryPurple)
                            .tracking(1)
                        Spacer()
                        Text("\(ror.owners.count) HOLDERS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                    
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
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
    }
}

