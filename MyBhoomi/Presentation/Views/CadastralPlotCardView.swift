import SwiftUI
import CoreLocation
import AVFoundation

/// Premium Apple-grade Native Liquid Glass Cadastral Plot Card for MyBhoomi.
/// Dynamically matches device screen corner radius, adapts 100% to Dark/Light appearances,
/// and presents authentic official RoR land records with fluid liquid glass physics.
public struct CadastralPlotCardView: View {
    public let parcel: Parcel
    @ObservedObject public var viewModel: MapViewModel
    public let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var rorResponse: RoRResponse? = nil
    @State private var officialSearchResult: OfficialSearchResult? = nil
    @State private var selectedResultForDetail: OfficialSearchResult? = nil
    @State private var isLoadingRoR: Bool = false
    @State private var rorError: String? = nil
    
    // PDF status & presentation
    @State private var pdfStatus: OfficialPDFStatus = .notStarted
    @State private var downloadedPDFURL: URL? = nil
    @State private var showShareSheet: Bool = false
    @State private var isExplicitlyOpeningPDF: Bool = false
    @State private var showAreaCalculator: Bool = false
    
    // Half-screen expansion state
    @State private var isExpandedHalfScreen: Bool = false
    
    // Live interactive drag gesture state
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var dragOffsetY: CGFloat = 0
    
    public init(
        parcel: Parcel,
        viewModel: MapViewModel,
        onDismiss: @escaping () -> Void
    ) {
        self.parcel = parcel
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        if let cached = VerifiedParcelCache.shared.get(identity: parcel.identity) {
            self._rorResponse = State(initialValue: cached.rawRoRResponse)
            self._officialSearchResult = State(initialValue: cached.toOfficialSearchResult())
            self._isLoadingRoR = State(initialValue: false)
        } else {
            self._isLoadingRoR = State(initialValue: true)
        }
    }
    
    private var identity: CanonicalParcelIdentity {
        parcel.identity
    }
    
    private var isVerified: Bool {
        rorResponse?.verification?.status == .verified
    }
    
    private var displayDistrict: String {
        if let d = rorResponse?.district, !d.isEmpty, d != "N/A" { return d }
        if !identity.districtName.isEmpty, identity.districtName != "N/A", identity.districtName != "Odisha" { return identity.districtName }
        if let d = viewModel.activeCadastralVillage?.districtName, !d.isEmpty { return d }
        return "Odisha"
    }
    
    private var displayTahasil: String {
        if let t = rorResponse?.tahasil, !t.isEmpty, t != "N/A" { return t }
        if !identity.tahasilName.isEmpty, identity.tahasilName != "N/A", identity.tahasilName != "Tahsil" { return identity.tahasilName }
        if let b = viewModel.activeCadastralVillage?.blockName, !b.isEmpty { return b }
        return "Tahsil"
    }
    
    private var displayVillage: String {
        if let v = rorResponse?.village, !v.isEmpty, v != "N/A" { return v }
        if !identity.villageName.isEmpty, identity.villageName != "N/A", identity.villageName != "Village" { return identity.villageName }
        if let v = viewModel.activeCadastralVillage?.name, !v.isEmpty { return v }
        return "Village"
    }
    
    private var displayKhatian: String {
        if let k = rorResponse?.khataNumber, !k.isEmpty { return k }
        return "—"
    }
    
    private var displayLandType: String {
        if let lt = rorResponse?.landType, !lt.isEmpty { return lt }
        if let tenure = rorResponse?.rawFields?["tenure"], !tenure.isEmpty { return tenure }
        if isLoadingRoR { return "Loading..." }
        return "Unverified"
    }
    
    private var displayArea: String {
        let raw = rorResponse?.area ?? rorResponse?.rawFields?["area"] ?? rorResponse?.rawFields?["total_area"] ?? rorResponse?.rawFields?["plot_area"]
        return formatAreaToDecimal(raw: raw, estimatedAcre: parcel.metadata.estimatedAreaAcre)
    }
    
    private func formatAreaToDecimal(raw: String?, estimatedAcre: Double?) -> String {
        if let raw = raw, !raw.isEmpty, raw != "N/A", raw != "—" {
            let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Case 1: Check if already formatted as Decimal (e.g. "80 Decimal" or "80 Dec")
            if clean.lowercased().contains("dec") {
                let digitsAndDot = clean.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
                if let val = Double(digitsAndDot), val > 0 {
                    let formatted = val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.2f", val)
                    return "\(formatted) Decimal"
                }
            }
            
            // Case 2: Formatted as A-D-C (e.g. "0-80-0" or "1-20-0" or "0-8-0")
            if clean.contains("-") {
                let parts = clean.components(separatedBy: "-")
                if parts.count >= 2, let acre = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let dec = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    let totalDec = (acre * 100.0) + dec
                    let formatted = totalDec.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", totalDec) : String(format: "%.2f", totalDec)
                    return "\(formatted) Decimal"
                }
            }
            
            // Case 3: Acre string like "Ac. 0.8000" or "0.080 Ac" or "0.80"
            let digitsAndDot = clean.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
            if let val = Double(digitsAndDot), val > 0 {
                // If value is expressed in Acres (< 100 acres), multiply by 100 to get Decimals
                let totalDec: Double = (val < 100.0) ? (val * 100.0) : val
                let formatted = totalDec.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", totalDec) : String(format: "%.2f", totalDec)
                return "\(formatted) Decimal"
            }
        }
        
        // Fallback to estimated GIS acre converted to Decimals
        if let acre = estimatedAcre, acre > 0 {
            let totalDec = acre * 100.0
            let formatted = totalDec.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", totalDec) : String(format: "%.2f", totalDec)
            return "\(formatted) Decimal"
        }
        
        return "—"
    }
    
    private var displayThana: String {
        if let t = rorResponse?.rawFields?["thana"], !t.isEmpty { return t }
        return displayTahasil
    }
    
    private var displayRICircle: String? {
        if let ri = rorResponse?.rawFields?["ri_circle"], !ri.isEmpty { return ri }
        if let ri = rorResponse?.rawFields?["ricircle"], !ri.isEmpty { return ri }
        if let ri = rorResponse?.rawFields?["ri"], !ri.isEmpty { return ri }
        if let ri = rorResponse?.rawFields?["revenue_circle"], !ri.isEmpty { return ri }
        if let ri = rorResponse?.rawFields?["circle"], !ri.isEmpty { return ri }
        return nil
    }
    
    /// Hardware screen corner radius tailored to the active iPhone model
    private var deviceCornerRadius: CGFloat {
        if let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
           let radius = keyWindow.screen.value(forKey: "_displayCornerRadius") as? CGFloat,
           radius > 0 {
            return radius
        }
        return 44
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            loadedPlotContentView
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 14)
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(
                        cornerRadius: deviceCornerRadius,
                        style: .continuous
                    )
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
                .offset(y: max(0, dragOffsetY + dragTranslation)) // ONLY translate downward when dragging down to dismiss!
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .updating($dragTranslation) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            handleDragEnd(translation: value.translation.height, predicted: value.predictedEndTranslation.height)
                        }
                )
        }
        .task(id: parcel.id) {
            Theme.haptic(.light)
            await loadRoR()
        }
        .fullScreenCover(item: $selectedResultForDetail) { result in
            // Preserve the exact geometry of the map feature the user tapped so
            // the passport's location preview highlights this same plot.
            LandPassportDetailView(result: result, selectedBoundary: parcel.boundary)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedPDFURL {
                ShareSheet(activityItems: [url])
            }
        }
        .fullScreenCover(isPresented: $showAreaCalculator) {
            LandAreaConverterView(
                officialArea: rorResponse?.area ?? displayArea,
                parcelContext: "Plot \(identity.plotNumber) • \(displayVillage)"
            )
        }
    }
    
    // MARK: - Loaded Content View
    private var loadedPlotContentView: some View {
        VStack(spacing: 12) {
            // 1. Sleek Centered Top Grabber Indicator (Clean Apple Maps Padding & Direct Tap)
            Capsule()
                .fill(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.22))
                .frame(width: 36, height: 5)
                .padding(.top, 7)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        isExpandedHalfScreen.toggle()
                    }
                }
            
            // 2. Hero Plot Title & Verified Badge
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plot \(identity.plotNumber)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if isLoadingRoR && (displayVillage == "Village" || displayVillage.isEmpty) {
                        SkeletonBlock(width: 130, height: 13, cornerRadius: 3)
                            .padding(.top, 2)
                    } else {
                        Text("\(displayVillage) • \(displayTahasil)")
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Verified / Government / Unverified Badge Pill
                if isVerified {
                    if officialSearchResult?.isGovernmentLand == true {
                        HStack(spacing: 4) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Govt Land")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Theme.Color.warning)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Theme.Color.warning.opacity(0.14))
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Verified")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Theme.Color.success)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Theme.Color.success.opacity(0.14))
                        .clipShape(Capsule())
                    }
                } else if isLoadingRoR {
                    HStack(spacing: 5) {
                        ProgressView()
                            .scaleEffect(0.60)
                        Text("Verifying...")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                    .skeletonShimmer()
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Unverified")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            // 3. Key Attributes Grid Card (High-Contrast Khatian, Area, Land Type with Skeleton Shimmer)
            HStack(spacing: 8) {
                AttributePill(
                    label: "KHATIAN",
                    value: displayKhatian,
                    isHighlighted: false,
                    isLoading: isLoadingRoR
                )
                
                AttributePill(
                    label: "AREA",
                    value: displayArea,
                    isHighlighted: true,
                    isLoading: isLoadingRoR && displayArea == "—",
                    showCalculatorAction: false,
                    onCalculatorTap: nil
                )
                
                AttributePill(
                    label: "LAND TYPE",
                    value: displayLandType,
                    isHighlighted: false,
                    isLoading: isLoadingRoR
                )
            }
            
            // 4. Content Section: Compact Preview OR Expanded Half-Screen Details
            if isExpandedHalfScreen {
                // EXPANDED HALF-SCREEN SCROLLABLE DETAILS
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // A. Full Recorded Owners List (No Truncation)
                        if let owners = rorResponse?.owners, !owners.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.accentColor)
                                    Text("RECORDED TENANTS / OWNERS (\(owners.count))")
                                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .tracking(0.6)
                                    Spacer()
                                }
                                
                                ForEach(Array(owners.enumerated()), id: \.element.id) { idx, owner in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(idx + 1).")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .frame(width: 18, alignment: .leading)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(owner.name)
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            if let share = owner.share, !share.isEmpty {
                                                Text("Share: \(share)")
                                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            )
                        } else if isLoadingRoR {
                            VStack(alignment: .leading, spacing: 10) {
                                SkeletonBlock(width: 160, height: 12, cornerRadius: 3)
                                SkeletonBlock(height: 16, cornerRadius: 4)
                                SkeletonBlock(width: 180, height: 14, cornerRadius: 4)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            )
                        }
                        
                        // B. Revenue Administration Quick Details (Thana, RI Circle / Tahasil, Total Plots)
                        HStack(spacing: 8) {
                            AttributePill(
                                label: "THANA",
                                value: displayThana,
                                isHighlighted: false,
                                isLoading: isLoadingRoR
                            )
                            
                            if let ri = displayRICircle, !ri.isEmpty {
                                AttributePill(
                                    label: "RI CIRCLE",
                                    value: ri,
                                    isHighlighted: false,
                                    isLoading: isLoadingRoR
                                )
                            } else {
                                AttributePill(
                                    label: "TAHASIL",
                                    value: displayTahasil,
                                    isHighlighted: false,
                                    isLoading: isLoadingRoR
                                )
                            }
                            
                            AttributePill(
                                label: "TOTAL PLOTS",
                                value: "\(rorResponse?.plots.count ?? 1)",
                                isHighlighted: false,
                                isLoading: isLoadingRoR
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.28)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                
            } else {
                // COMPACT PEEKING ROW
                if let errorMsg = rorError, !errorMsg.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text(errorMsg)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button("Retry") {
                            _Concurrency.Task {
                                await loadRoR()
                            }
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.accentColor)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9.5)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
                } else if isLoadingRoR {
                    // Shimmering Skeleton Owner Row while verifying
                    HStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(Color.accentColor.opacity(0.35))
                        
                        SkeletonBlock(width: 140, height: 13, cornerRadius: 4)
                        
                        Spacer()
                        
                        SkeletonBlock(width: 40, height: 13, cornerRadius: 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9.5)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
                } else if let owners = rorResponse?.owners, !owners.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isExpandedHalfScreen = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(Color.accentColor)
                            
                            Text(owners.first?.name ?? "Land Owner")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            if owners.count > 1 {
                                Text("+\(owners.count - 1) more")
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9.5)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 5. Full-Width Primary CTA: View Official RoR Details (if verified) or Verify Full RoR (if unverified)
            Button {
                if isVerified {
                    openCompleteRoRDetails()
                } else {
                    _Concurrency.Task {
                        await loadRoR()
                        if isVerified {
                            openCompleteRoRDetails()
                        } else {
                            openCompleteRoRDetails()
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(isVerified ? "View Official RoR Details" : "Verify Full RoR")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Image(systemName: isVerified ? "arrow.right" : "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(.glassProminent)
            .tint(isVerified ? Color.accentColor : Color.secondary)
            .disabled(isLoadingRoR)
            .opacity(isLoadingRoR ? 0.65 : 1.0)
            .accessibilityLabel(isVerified ? "View official RoR details" : "Verify full RoR")
            .padding(.top, 1)
        }
    }
    
    // MARK: - Gesture Handling
    private func handleDragEnd(translation: CGFloat, predicted: CGFloat) {
        if isExpandedHalfScreen {
            // Dragging down from expanded -> collapse to compact (Step 1)
            if translation > 20 || predicted > 35 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isExpandedHalfScreen = false
                    dragOffsetY = 0
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    dragOffsetY = 0
                }
            }
        } else {
            // Dragging UP from compact -> expand to half screen (Step 2)
            if translation < -15 || predicted < -30 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isExpandedHalfScreen = true
                    dragOffsetY = 0
                }
            } else if translation > 40 || predicted > 70 {
                // Dragging DOWN from compact -> dismiss card (Step 3: Back to map)
                onDismiss()
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    dragOffsetY = 0
                }
            }
        }
    }
    
    // MARK: - RoR Data Loading
    private func loadRoR() async {
        let expectedParcelID = parcel.id
        let expectedPlot = identity.plotNumber
        
        await MainActor.run {
            self.isLoadingRoR = true
            self.rorError = nil
        }
        
        // 1. Instant Verified Parcel Cache Lookup
        if let cached = await MainActor.run(body: { VerifiedParcelCache.shared.get(identity: self.identity) }) {
            await MainActor.run {
                guard self.parcel.id == expectedParcelID else { return }
                self.rorResponse = cached.rawRoRResponse
                self.officialSearchResult = cached.toOfficialSearchResult()
                self.isLoadingRoR = false
            }
            return
        }
        
        // 2. Search Quota Verification
        if !SubscriptionManager.shared.canPerformPlotSearch {
            await MainActor.run {
                guard self.parcel.id == expectedParcelID else { return }
                self.isLoadingRoR = false
                self.rorError = "Plot search limit reached (0 left)"
                self.viewModel.showToast("0 plot searches left. Tap to top up.", icon: "bolt.slash.fill")
            }
            return
        }
        
        let effectiveBId: String? = {
            if let b = identity.tahasilID, !b.isEmpty, b != "N/A" { return b }
            if let b = viewModel.activeCadastralVillage?.blockID, !b.isEmpty { return b }
            return nil
        }()
        
        let effectiveVId: String? = {
            if let v = identity.villageID, !v.isEmpty, v != "N/A" { return v }
            if let v = viewModel.activeCadastralVillage?.id, !v.isEmpty { return v }
            return nil
        }()
        
        #if DEBUG
        print("[PlotVerify] selected plot: \(identity.plotNumber)")
        print("[PlotVerify] district: \(displayDistrict)")
        print("[PlotVerify] district_id: \(identity.districtID ?? "nil")")
        print("[PlotVerify] tahasil: \(displayTahasil)")
        print("[PlotVerify] tahasil_id: \(effectiveBId ?? "nil")")
        print("[PlotVerify] village: \(displayVillage)")
        print("[PlotVerify] village_id: \(effectiveVId ?? "nil")")
        print("[PlotVerify] b_id: \(effectiveBId ?? "nil")")
        print("[PlotVerify] v_id: \(effectiveVId ?? "nil")")
        print("[PlotVerify] plot: \(identity.plotNumber)")
        #endif
        
        do {
            let res = try await RoRService.shared.fetch(
                district: displayDistrict,
                tahasil: displayTahasil,
                village: displayVillage,
                plot: identity.plotNumber,
                bId: effectiveBId,
                vId: effectiveVId
            )
            
            await MainActor.run {
                guard self.parcel.id == expectedParcelID,
                      self.identity.plotNumber == expectedPlot else {
                    self.isLoadingRoR = false
                    return
                }
                
                self.rorResponse = res
                self.officialSearchResult = OfficialSearchResult(ror: res, identity: identity)
                self.isLoadingRoR = false
                
                // Deduct 1 credit for new successful plot inspection
                SubscriptionManager.shared.consumePlotSearchCredit()
                
                // Cache exclusively if successfully verified
                let verif = ParcelCrossVerifier.verify(gisIdentity: self.identity, rorResponse: res, gisAreaInAcre: nil)
                if verif.isVerified {
                    VerifiedParcelCache.shared.save(
                        identity: self.identity,
                        ror: res,
                        verification: verif,
                        boundary: self.parcel.boundary
                    )
                }
            }
            
            // Prefetch PDF in background (uses cached official document if available)
            if let khata = res.khataNumber, !khata.isEmpty {
                _Concurrency.Task.detached(priority: .utility) {
                    do {
                        let (url, _, _) = try await RoRService.shared.downloadROR(
                            district: displayDistrict,
                            tahasil: displayTahasil,
                            village: displayVillage,
                            plot: identity.plotNumber,
                            khataNumber: khata,
                            bId: effectiveBId,
                            vId: effectiveVId,
                            documentID: res.officialDocument?.documentID
                        )
                        await MainActor.run {
                            guard self.parcel.id == expectedParcelID else { return }
                            self.downloadedPDFURL = url
                            self.pdfStatus = .ready(url)
                        }
                    } catch {}
                }
            }
        } catch is CancellationError {
            print("[PlotVerify] ⏹️ Task cancelled for plot \(expectedPlot)")
            return
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("[PlotVerify] ⏹️ Network request cancelled for plot \(expectedPlot)")
                return
            }
            
            print("[PlotVerify] ❌ Error loading RoR for plot \(expectedPlot): \(error)")
            
            await MainActor.run {
                guard self.parcel.id == expectedParcelID else { return }
                self.isLoadingRoR = false
                if case .notFound = (error as? RoRError) {
                    self.rorError = nil
                } else if case .usageLimitExceeded(let msg) = (error as? RoRError) {
                    self.rorError = msg
                } else {
                    self.rorError = "Couldn’t verify this plot right now"
                }
            }
        }
    }
    
    private func openCompleteRoRDetails() {
        if let result = officialSearchResult {
            selectedResultForDetail = result
        } else {
            // Build fallback OfficialSearchResult
            let fallbackResult = OfficialSearchResult(
                districtID: identity.districtID ?? "",
                districtName: displayDistrict,
                tahasilID: identity.tahasilID ?? "",
                tahasilName: displayTahasil,
                villageID: identity.villageID ?? "",
                villageName: displayVillage,
                plotNumber: identity.plotNumber,
                khatianNumber: displayKhatian,
                area: displayArea,
                ownersCount: rorResponse?.owners.count ?? 1,
                associatedPlots: rorResponse?.plots.map { $0.plotNumber } ?? [identity.plotNumber],
                rawResponse: rorResponse ?? RoRResponse(success: true, plot: identity.plotNumber, village: displayVillage, district: displayDistrict, tahasil: displayTahasil, khataNumber: displayKhatian, area: displayArea, landType: displayLandType, owners: [], plots: [], rawFields: nil, verification: nil, source: "CADASTRAL_MAP")
            )
            selectedResultForDetail = fallbackResult
        }
    }
    
    private func openOrDownloadPDF() {
        if let _ = downloadedPDFURL {
            showShareSheet = true
            return
        }
        
        guard let khata = rorResponse?.khataNumber, !khata.isEmpty, khata != "—", isVerified else {
            showShareSheet = false
            return
        }
        
        isExplicitlyOpeningPDF = true
        _Concurrency.Task {
            do {
                let (url, _, _) = try await RoRService.shared.downloadROR(
                    district: identity.districtID ?? "",
                    tahasil: identity.tahasilID ?? "",
                    village: identity.villageID ?? "",
                    plot: identity.plotNumber,
                    khataNumber: khata
                )
                await MainActor.run {
                    self.downloadedPDFURL = url
                    self.pdfStatus = .ready(url)
                    self.isExplicitlyOpeningPDF = false
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isExplicitlyOpeningPDF = false
                }
            }
        }
    }
}

// MARK: - High-Contrast Appearance-Aware Attribute Pill

struct AttributePill: View {
    let label: String
    let value: String
    let isHighlighted: Bool
    var isLoading: Bool = false
    var showCalculatorAction: Bool = false
    var onCalculatorTap: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var pillBody: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Text(label)
                    .font(Theme.Typography.pillLabelCondensed)
                    .foregroundColor(.secondary)
                    .tracking(0.6)
                
                if showCalculatorAction && !isLoading {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.accentColor)
                }
            }
            
            if isLoading {
                SkeletonBlock(width: 44, height: 15, cornerRadius: 4)
                    .padding(.vertical, 1)
            } else {
                Text(value)
                    .font(Theme.Typography.pillValueCondensed)
                    .foregroundColor(
                        isHighlighted
                            ? (colorScheme == .dark ? Color(red: 175/255, green: 110/255, blue: 255/255) : Color(red: 116/255, green: 18/255, blue: 250/255))
                            : .primary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
        )
    }
    
    var body: some View {
        if showCalculatorAction && !isLoading {
            Button {
                if let tap = onCalculatorTap {
                    Theme.haptic(.light)
                    tap()
                }
            } label: {
                pillBody
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Convert land area, currently \(value)")
            .accessibilityHint("Double tap to open land area converter")
        } else {
            pillBody
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(label): \(value)")
        }
    }
}
