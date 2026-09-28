import SwiftUI

/// Unified, verified RoR result view used across Map taps, Plot Search, Khata Search, and Plot Unique ID.
public struct UnifiedRoRResultView: View {
    public let ror: RoRResponse
    public let verification: ParcelVerificationResult
    public var onDownloadPDF: (() -> Void)? = nil
    public var isDownloadingPDF: Bool = false
    public var downloadedPDFURL: URL? = nil
    public var onSelectPlot: ((AssociatedPlot) -> Void)? = nil
    public var onSaveParcel: (() -> Void)? = nil
    public var isSaved: Bool = false
    
    public init(
        ror: RoRResponse,
        verification: ParcelVerificationResult,
        onDownloadPDF: (() -> Void)? = nil,
        isDownloadingPDF: Bool = false,
        downloadedPDFURL: URL? = nil,
        onSelectPlot: ((AssociatedPlot) -> Void)? = nil,
        onSaveParcel: (() -> Void)? = nil,
        isSaved: Bool = false
    ) {
        self.ror = ror
        self.verification = verification
        self.onDownloadPDF = onDownloadPDF
        self.isDownloadingPDF = isDownloadingPDF
        self.downloadedPDFURL = downloadedPDFURL
        self.onSelectPlot = onSelectPlot
        self.onSaveParcel = onSaveParcel
        self.isSaved = isSaved
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // ── 1. SOURCE & VERIFICATION STATUS BADGE ────────────────────────
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: verification.isVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(verification.isVerified ? Theme.Color.bhumitraSuccess : Theme.Color.bhumitraWarning)
                        .font(.system(size: 15))
                    Text(verification.isVerified ? "VERIFIED OFFICIAL RECORD" : "UNVERIFIED RECORD")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(verification.isVerified ? Theme.Color.bhumitraSuccess : Theme.Color.bhumitraWarning)
                        .tracking(0.6)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Source:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Odisha Bhulekh")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
            
            // ── 2. PARCEL / CADASTRAL IDENTITY CARD ────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(Theme.primary)
                        .font(.system(size: 13))
                    Text("PARCEL DETAILS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.8)
                    Spacer()
                    if let k = ror.khataNumber {
                        Text("Khata No: \(k)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.primary.opacity(0.08))
                            .cornerRadius(6)
                    }
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    UnifiedDataRow(label: "Plot Number", value: ror.plot, isEmphasized: true)
                    UnifiedDataRow(label: "Revenue Village (Mouza)", value: ror.village)
                    UnifiedDataRow(label: "Tahasil", value: ror.tahasil)
                    UnifiedDataRow(label: "District", value: ror.district)
                    if let landType = ror.landType {
                        UnifiedDataRow(label: "Kisam (Land Type)", value: landType)
                    }
                    if let area = ror.area {
                        UnifiedDataRow(label: "Recorded Area", value: area)
                    }
                }
            }
            .padding(16)
            .background(Theme.Color.surface)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 3)
            
            // ── 3. ASSOCIATED PLOTS (For multi-plot Khatas) ─────────────────
            if !ror.plots.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "square.split.2x2.fill")
                            .foregroundColor(Theme.primary)
                            .font(.system(size: 13))
                        Text("ALL PLOTS IN KHATA (\(ror.plots.count))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.8)
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(ror.plots) { p in
                            Button(action: {
                                onSelectPlot?(p)
                            }) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("Plot \(p.plotNumber)")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(Theme.Color.primaryText)
                                            if p.plotNumber == ror.plot {
                                                Text("SELECTED")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Theme.Color.bhumitraPrimary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        if let t = p.landType {
                                            Text(t)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if let a = p.area {
                                        Text(a)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Theme.primary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Theme.primary.opacity(0.08))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(12)
                                .background(p.plotNumber == ror.plot ? Theme.Color.bhumitraSelection : Theme.Color.bhumitraSurfaceSecondary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(p.plotNumber == ror.plot ? Theme.Color.bhumitraPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
                                 )
                            }
                        }
                    }
                }
                .padding(16)
                .background(Theme.Color.surface)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.03), radius: 8, y: 3)
            }
            
            // ── 4. OWNERS / TENANTS SECTION ─────────────────────────────────
            if verification.isVerified {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(Theme.primary)
                            .font(.system(size: 13))
                        Text("VERIFIED RECORD HOLDERS (\(ror.owners.count))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.8)
                        Spacer()
                    }
                    
                    Divider()
                    
                    VStack(spacing: 0) {
                        ForEach(ror.owners) { owner in
                            ModernOwnerRow(owner: owner)
                            if owner.id != ror.owners.last?.id {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Theme.Color.surface)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.03), radius: 8, y: 3)
            } else {
                // Fail-Closed Shield for Unverified Parcels
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.slash.fill")
                            .foregroundColor(Theme.Color.bhumitraWarning)
                        Text("Unable to verify this land record")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraWarning)
                    }
                    Text("Ownership details are withheld to prevent misidentification. The returned state record could not be authoritatively linked.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    ForEach(verification.reasons, id: \.self) { reason in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundColor(Theme.Color.bhumitraWarning)
                            Text(reason).font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Theme.Color.bhumitraWarningSurface)
                .cornerRadius(18)
            }
            
            // ── 5. ACTIONS: PDF DOWNLOAD & SHARE ───────────────────────────
            VStack(spacing: 12) {
                if isDownloadingPDF {
                    // Busy state rendered as the same CTA (brand fill, no taps).
                    Button {} label: {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Generating Official RoR (PDF)…")
                        }
                    }
                    .buttonStyle(.primaryCTA)
                    .allowsHitTesting(false)
                } else if let url = downloadedPDFURL {
                    HStack(spacing: 12) {
                        ShareLink(item: url, preview: SharePreview("RoR Plot \(ror.plot)", image: Image(systemName: "doc.text.fill"))) {
                            Label("Share Document", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.primaryCTA)
                        
                        if let onSave = onSaveParcel {
                            Button(action: onSave) {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            }
                            .buttonStyle(.ctaIcon)
                            .accessibilityLabel(isSaved ? "Saved" : "Save plot")
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Button(action: {
                            onDownloadPDF?()
                        }) {
                            Label("Download Official RoR (PDF)", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.primaryCTA)
                        
                        if let onSave = onSaveParcel {
                            Button(action: onSave) {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            }
                            .buttonStyle(.ctaIcon)
                            .accessibilityLabel(isSaved ? "Saved" : "Save plot")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Row Helper

struct UnifiedDataRow: View {
    let label: String
    let value: String
    var isEmphasized: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: isEmphasized ? .bold : .semibold))
                .foregroundColor(isEmphasized ? Theme.primary : Theme.Color.primaryText)
        }
    }
}
