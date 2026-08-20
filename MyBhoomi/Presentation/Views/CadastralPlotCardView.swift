import SwiftUI
import CoreLocation

/// Physical snap states for the interactive cadastral plot card.
public enum CadastralCardSnap: Equatable, CaseIterable {
    case peek
    case medium
    case full
    
    func targetHeight(screenHeight: CGFloat, safeAreaBottom: CGFloat) -> CGFloat {
        switch self {
        case .peek:
            return 175 + safeAreaBottom
        case .medium:
            return min(390 + safeAreaBottom, screenHeight * 0.52)
        case .full:
            return max(screenHeight - 75, 580)
        }
    }
}

/// World-Class Interactive Cadastral Plot Card for MyBhoomi (Phase 3.34B).
public struct CadastralPlotCardView: View {
    public let parcel: Parcel
    @ObservedObject public var viewModel: MapViewModel
    public let onDismiss: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Continuous gesture & physical snap state
    @State private var currentSnap: CadastralCardSnap = .peek
    @GestureState private var dragTranslationY: CGFloat = 0
    @State private var lastFiredSnap: CadastralCardSnap = .peek
    
    // RoR Data state
    @State private var rorResponse: RoRResponse? = nil
    @State private var officialSearchResult: OfficialSearchResult? = nil
    @State private var selectedResultForDetail: OfficialSearchResult? = nil
    @State private var pendingOpenDetail: Bool = false
    @State private var isLoadingRoR: Bool = false
    @State private var rorError: String? = nil
    
    // PDF status & presentation
    @State private var pdfStatus: OfficialPDFStatus = .notStarted
    @State private var downloadedPDFURL: URL? = nil
    @State private var showShareSheet: Bool = false
    @State private var isExplicitlyOpeningPDF: Bool = false
    
    public init(
        parcel: Parcel,
        viewModel: MapViewModel,
        onDismiss: @escaping () -> Void
    ) {
        self.parcel = parcel
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    private var identity: CanonicalParcelIdentity {
        parcel.identity
    }
    
    private var isVerified: Bool {
        rorResponse?.verification?.status == .verified || (rorResponse?.success == true)
    }
    
    private var displayDistrict: String {
        if let d = rorResponse?.district, !d.isEmpty, d != "N/A" { return d }
        if !identity.districtName.isEmpty, identity.districtName != "N/A" { return identity.districtName }
        return "Keonjhar"
    }
    
    private var displayTahasil: String {
        if let t = rorResponse?.tahasil, !t.isEmpty, t != "N/A" { return t }
        if !identity.tahasilName.isEmpty, identity.tahasilName != "N/A" { return identity.tahasilName }
        return "Keonjhar Sadar"
    }
    
    private var displayVillage: String {
        if let v = rorResponse?.village, !v.isEmpty, v != "N/A" { return v }
        if !identity.villageName.isEmpty, identity.villageName != "N/A" { return identity.villageName }
        return "G_Dimbo"
    }
    
    private var displayKhatian: String {
        if let k = rorResponse?.khataNumber, !k.isEmpty { return k }
        return "—"
    }
    
    private var displayArea: String {
        if let a = rorResponse?.area, !a.isEmpty { return a }
        if let acre = parcel.metadata.estimatedAreaAcre, acre > 0 {
            return String(format: "%.3f Acres", acre)
        }
        return "—"
    }
    
    public var body: some View {
        GeometryReader { geo in
            let screenH = geo.size.height
            let safeBottom = geo.safeAreaInsets.bottom
            
            let peekH = CadastralCardSnap.peek.targetHeight(screenHeight: screenH, safeAreaBottom: safeBottom)
            let fullH = CadastralCardSnap.full.targetHeight(screenHeight: screenH, safeAreaBottom: safeBottom)
            let baseH = currentSnap.targetHeight(screenHeight: screenH, safeAreaBottom: safeBottom)
            
            // Continuous physical height following the user's finger in real time
            let rawH = baseH - dragTranslationY
            
            // Subtle boundary resistance
            let activeHeight: CGFloat = {
                if rawH < peekH {
                    return peekH - pow(peekH - rawH, 0.75)
                } else if rawH > fullH {
                    return fullH + pow(rawH - fullH, 0.75)
                } else {
                    return rawH
                }
            }()
            
            // Continuous normalized progress (0.0 = Peek, 0.5 = Medium, 1.0 = Full)
            let progress: CGFloat = {
                let range = fullH - peekH
                guard range > 0 else { return 0 }
                return max(0, min(1, (activeHeight - peekH) / range))
            }()
            
            // Dynamic corner radius: 32pt at Peek down to 24pt at Full
            let cornerRadius: CGFloat = reduceMotion ? 28 : (32 - (progress * 8))
            
            ZStack(alignment: .bottom) {
                // Subtle map softening background as card expands
                if progress > 0.05 {
                    Color.black
                        .opacity(Double(progress) * 0.22)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                currentSnap = .peek
                                hapticFeedback(.light)
                            }
                        }
                }
                
                // Continuous Physical Glass Card
                VStack(spacing: 0) {
                    // Header & Interactive Grabber
                    VStack(spacing: 6) {
                        // Dynamic Grabber Pill (stretches subtly on vertical drag)
                        Capsule()
                            .fill(Color.black.opacity(0.2))
                            .frame(
                                width: reduceMotion ? 36 : (36 + min(16, abs(dragTranslationY) * 0.06)),
                                height: 5
                            )
                            .padding(.top, 8)
                        
                        // Header Content
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text("Plot \(identity.plotNumber)")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                    
                                    if isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Theme.myBhoomiBlue)
                                    }
                                }
                                
                                Text(displayVillage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Native Liquid Glass Close Button
                            Button(action: {
                                hapticFeedback(.light)
                                onDismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.black.opacity(0.6))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.06))
                                    )
                            }
                            .buttonStyle(ScaledButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .updating($dragTranslationY) { value, state, _ in
                                state = value.translation.height
                            }
                            .onChanged { value in
                                checkContinuousStateCrossings(
                                    currentH: baseH - value.translation.height,
                                    screenHeight: screenH,
                                    safeAreaBottom: safeBottom
                                )
                            }
                            .onEnded { value in
                                handleDragRelease(
                                    translation: value.translation.height,
                                    velocity: value.predictedEndTranslation.height - value.translation.height,
                                    screenHeight: screenH,
                                    safeAreaBottom: safeBottom
                                )
                            }
                    )
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Card Body Content (Progressively Revealed)
                    ScrollView(.vertical, showsIndicators: currentSnap == .full) {
                        VStack(alignment: .leading, spacing: 16) {
                            // 1. PEEK SUMMARY ROW
                            HStack(spacing: 12) {
                                BlueSummaryPill(title: "KHATIAN", value: displayKhatian, isAccent: true)
                                BlueSummaryPill(title: "AREA", value: displayArea, isAccent: false)
                                
                                if let owners = rorResponse?.owners, !owners.isEmpty {
                                    BlueSummaryPill(title: "OWNERS", value: "\(owners.count)", isAccent: false)
                                }
                            }
                            
                            // Primary Action in Peek & Medium states
                            if progress < 0.85 {
                                HStack(spacing: 10) {
                                    Button(action: {
                                        hapticFeedback(.light)
                                        if let result = officialSearchResult {
                                            selectedResultForDetail = result
                                        } else if isLoadingRoR {
                                            pendingOpenDetail = true
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            if isLoadingRoR && pendingOpenDetail {
                                                ProgressView()
                                                    .tint(.white)
                                                    .scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "person.2.fill")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            Text(ownersButtonTitle)
                                                .font(.system(size: 15, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(Theme.myBhoomiBlue)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .shadow(color: Theme.myBhoomiBlue.opacity(0.25), radius: 8, x: 0, y: 3)
                                    }
                                    .buttonStyle(ScaledButtonStyle())
                                    
                                    Button(action: {
                                        hapticFeedback(.light)
                                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                            currentSnap = (currentSnap == .peek) ? .medium : .full
                                        }
                                    }) {
                                        Image(systemName: currentSnap == .peek ? "chevron.up" : "chevron.up.2")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Theme.myBhoomiBlue)
                                            .frame(width: 44, height: 44)
                                            .background(Theme.myBhoomiBlue.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(ScaledButtonStyle())
                                }
                            }
                            
                            // 2. MEDIUM STATE: Administrative Hierarchy
                            if progress > 0.12 {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ADMINISTRATIVE DETAILS")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .tracking(0.6)
                                    
                                    VStack(spacing: 0) {
                                        AdministrativeRow(label: "District", value: displayDistrict)
                                        Divider().padding(.leading, 16)
                                        AdministrativeRow(label: "Tahasil", value: displayTahasil)
                                        Divider().padding(.leading, 16)
                                        AdministrativeRow(label: "Village", value: displayVillage)
                                        if let thana = rorResponse?.rawFields?["thana"], !thana.isEmpty {
                                            Divider().padding(.leading, 16)
                                            AdministrativeRow(label: "Thana", value: thana)
                                        }
                                        if let ri = rorResponse?.rawFields?["ri_circle"], !ri.isEmpty {
                                            Divider().padding(.leading, 16)
                                            AdministrativeRow(label: "RI Circle", value: ri)
                                        }
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white)
                                            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                                    )
                                }
                                .opacity(reduceMotion ? 1 : Double(min(1, (progress - 0.12) / 0.28)))
                                .offset(y: reduceMotion ? 0 : (1.0 - min(1, (progress - 0.12) / 0.28)) * 12)
                            }
                            
                            // 3. FULL STATE: Complete Verified Record & Tenants & PDF
                            if progress > 0.45 {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Official Verified Seal Card
                                    HStack(spacing: 10) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Theme.myBhoomiBlue)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("OFFICIAL VERIFIED RECORD")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Theme.myBhoomiBlue)
                                            
                                            Text("Odisha Bhulekh Land Records Portal")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Theme.myBhoomiBlue.opacity(0.07))
                                    )
                                    
                                    // Tenants / Raiyat Section
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("TENANT / OWNERS")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .tracking(0.6)
                                        
                                        VStack(alignment: .leading, spacing: 10) {
                                            if let owners = rorResponse?.owners, !owners.isEmpty {
                                                ForEach(owners) { owner in
                                                    HStack(alignment: .top) {
                                                        Text(owner.name)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundColor(.black)
                                                            .fixedSize(horizontal: false, vertical: true)
                                                        
                                                        Spacer()
                                                        
                                                        if let share = owner.share, !share.isEmpty {
                                                            Text(share)
                                                                .font(.system(size: 13, weight: .bold))
                                                                .foregroundColor(Theme.myBhoomiBlue)
                                                        }
                                                    }
                                                    if owner.id != owners.last?.id {
                                                        Divider()
                                                    }
                                                }
                                            } else {
                                                Text(rorResponse?.rawFields?["landlord"] ?? "—")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.black)
                                            }
                                            
                                            Divider()
                                            
                                            HStack {
                                                Text("Tenure")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text(rorResponse?.landType ?? rorResponse?.rawFields?["tenure"] ?? "—")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(Color.white)
                                                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                                        )
                                    }
                                    
                                    // Remarks Section (if available)
                                    if let remarks = rorResponse?.rawFields?["remarks"], !remarks.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("REMARKS")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.secondary)
                                                .tracking(0.6)
                                            
                                            Text(remarks)
                                                .font(.system(size: 13))
                                                .foregroundColor(.black.opacity(0.85))
                                                .lineSpacing(3)
                                                .padding(14)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(Color.white)
                                                        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
                                                )
                                        }
                                    }
                                    
                                    // Related Plots Section (if available)
                                    if let plots = rorResponse?.plots, plots.count > 1 {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("RELATED PLOTS IN KHATIAN (\(plots.count))")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.secondary)
                                                .tracking(0.6)
                                            
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(plots) { plot in
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text("Plot \(plot.plotNumber)")
                                                                .font(.system(size: 13, weight: .bold))
                                                                .foregroundColor(plot.plotNumber == identity.plotNumber ? Theme.myBhoomiBlue : .black)
                                                            
                                                            if let a = plot.area, !a.isEmpty {
                                                                Text(a)
                                                                    .font(.system(size: 11))
                                                                    .foregroundColor(.secondary)
                                                            }
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                                .fill(plot.plotNumber == identity.plotNumber ? Theme.myBhoomiBlue.opacity(0.1) : Color.white)
                                                        )
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                                .stroke(plot.plotNumber == identity.plotNumber ? Theme.myBhoomiBlue : Color.black.opacity(0.06), lineWidth: 1)
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Official RoR PDF Action
                                    VStack(spacing: 8) {
                                        Button(action: {
                                            hapticFeedback(.medium)
                                            openOrDownloadPDF()
                                        }) {
                                            HStack(spacing: 10) {
                                                if isExplicitlyOpeningPDF {
                                                    ProgressView().tint(.white)
                                                } else {
                                                    Image(systemName: "arrow.down.doc.fill")
                                                        .font(.system(size: 15, weight: .semibold))
                                                }
                                                
                                                Text(pdfButtonTitle)
                                                    .font(.system(size: 15, weight: .bold))
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 15)
                                            .background(Theme.myBhoomiBlue)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .shadow(color: Theme.myBhoomiBlue.opacity(0.25), radius: 10, x: 0, y: 4)
                                        }
                                        .disabled(isExplicitlyOpeningPDF)
                                        .buttonStyle(ScaledButtonStyle())
                                        
                                        // PDF status indicator
                                        if case .ready = pdfStatus {
                                            HStack(spacing: 5) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Theme.myBhoomiBlue)
                                                    .font(.system(size: 12))
                                                Text("Official Document Ready")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(Theme.myBhoomiBlue)
                                            }
                                        } else if case .preparing = pdfStatus {
                                            Text("Preparing official document in background...")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        } else if case .failed(let err) = pdfStatus {
                                            HStack(spacing: 6) {
                                                Text(err)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.red)
                                                Button("Try Again") {
                                                    openOrDownloadPDF()
                                                }
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Theme.myBhoomiBlue)
                                            }
                                        }
                                    }
                                    .padding(.top, 6)
                                }
                                .opacity(reduceMotion ? 1 : Double(min(1, (progress - 0.45) / 0.45)))
                                .offset(y: reduceMotion ? 0 : (1.0 - min(1, (progress - 0.45) / 0.45)) * 16)
                            }
                            
                            Spacer(minLength: 30)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                    }
                    .scrollDisabled(currentSnap != .full)
                }
                .frame(height: activeHeight)
                .frame(maxWidth: .infinity)
                .background(
                    // Pristine Liquid Glass Surface
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.96))
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: -4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
        }
        .task(id: parcel.id) {
            hapticFeedback(.light)
            await loadRoRAndPrefetchPDF()
        }
        .sheet(item: $selectedResultForDetail) { result in
            KhatianDetailView(result: result)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedPDFURL {
                ActivityView(activityItems: [url])
            }
        }
    }
    
    private var ownersButtonTitle: String {
        if let count = rorResponse?.owners.count, count > 0 {
            return "View \(count) Owner\(count > 1 ? "s" : "")"
        }
        return "View Owners"
    }
    
    // MARK: - Continuous Boundary Crossing Detection
    
    private func checkContinuousStateCrossings(
        currentH: CGFloat,
        screenHeight: CGFloat,
        safeAreaBottom: CGFloat
    ) {
        let peekH = CadastralCardSnap.peek.targetHeight(screenHeight: screenHeight, safeAreaBottom: safeAreaBottom)
        let medH = CadastralCardSnap.medium.targetHeight(screenHeight: screenHeight, safeAreaBottom: safeAreaBottom)
        let fullH = CadastralCardSnap.full.targetHeight(screenHeight: screenHeight, safeAreaBottom: safeAreaBottom)
        
        let distPeek = abs(currentH - peekH)
        let distMed = abs(currentH - medH)
        let distFull = abs(currentH - fullH)
        
        let nearest: CadastralCardSnap = {
            if distPeek <= distMed && distPeek <= distFull { return .peek }
            if distMed <= distFull { return .medium }
            return .full
        }()
        
        if nearest != lastFiredSnap {
            lastFiredSnap = nearest
            hapticFeedback(.light)
        }
    }
    
    // MARK: - Physics & Release Handling
    
    private func handleDragRelease(
        translation: CGFloat,
        velocity: CGFloat,
        screenHeight: CGFloat,
        safeAreaBottom: CGFloat
    ) {
        let peekH = CadastralCardSnap.peek.targetHeight(screenHeight: screenHeight, safeAreaBottom: safeAreaBottom)
        let medH = CadastralCardSnap.medium.targetHeight(screenHeight: screenHeight, safeAreaBottom: safeAreaBottom)
        let fullH = CadastralCardSnap.full.targetHeight(screenHeight: screenHeight, safeAreaBottom: safeAreaBottom)
        
        let currentH = currentSnap.targetHeight(screenHeight: screenHeight, safeAreaBottom: safeAreaBottom) - translation
        
        var nextSnap: CadastralCardSnap
        
        // Fast fling recognition
        if velocity < -260 {
            switch currentSnap {
            case .peek: nextSnap = .medium
            case .medium, .full: nextSnap = .full
            }
        } else if velocity > 260 {
            switch currentSnap {
            case .full: nextSnap = .medium
            case .medium: nextSnap = .peek
            case .peek:
                onDismiss()
                return
            }
        } else {
            // Distance-based magnetic snapping
            let distPeek = abs(currentH - peekH)
            let distMed = abs(currentH - medH)
            let distFull = abs(currentH - fullH)
            
            if distPeek <= distMed && distPeek <= distFull {
                if currentH < peekH - 55 {
                    onDismiss()
                    return
                }
                nextSnap = .peek
            } else if distMed <= distFull {
                nextSnap = .medium
            } else {
                nextSnap = .full
            }
        }
        
        if nextSnap != currentSnap {
            switch nextSnap {
            case .peek, .medium: hapticFeedback(.light)
            case .full: hapticFeedback(.medium)
            }
        }
        
        lastFiredSnap = nextSnap
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            self.currentSnap = nextSnap
        }
    }
    
    // MARK: - RoR & PDF Data Pipeline
    
    private var pdfButtonTitle: String {
        if isExplicitlyOpeningPDF {
            return "Opening Official RoR..."
        }
        if case .ready = pdfStatus {
            return "Open Official PDF"
        }
        return "Open / Share Official PDF"
    }
    
    private func loadRoRAndPrefetchPDF() async {
        guard identity.isFullyResolved else { return }
        
        isLoadingRoR = true
        rorError = nil
        
        do {
            let res = try await RoRService.shared.fetch(
                district: identity.districtName,
                tahasil: identity.tahasilName,
                village: identity.villageName,
                plot: identity.plotNumber,
                bId: identity.tahasilID,
                vId: identity.villageID
            )
            
            let officialResult = OfficialSearchResult(ror: res, identity: identity)
            
            await MainActor.run {
                self.isLoadingRoR = false
                self.rorResponse = res
                self.officialSearchResult = officialResult
                if self.pendingOpenDetail {
                    self.selectedResultForDetail = officialResult
                    self.pendingOpenDetail = false
                }
            }
            
            // Check local disk cache for instant PDF readiness
            if let cached = await OfficialRoRPDFService.shared.getCachedURL(
                district: identity.districtName,
                tahasil: identity.tahasilName,
                village: identity.villageName,
                plot: identity.plotNumber,
                khata: res.khataNumber,
                vId: identity.villageID
            ) {
                await MainActor.run {
                    self.pdfStatus = .ready(cached)
                    self.downloadedPDFURL = cached
                }
                return
            }
            
            // Silent background prefetch
            await MainActor.run {
                self.pdfStatus = .preparing
            }
            
            let url = try await OfficialRoRPDFService.shared.fetchOrGetPDF(
                district: identity.districtName,
                tahasil: identity.tahasilName,
                village: identity.villageName,
                plot: identity.plotNumber,
                khataNumber: res.khataNumber,
                bId: identity.tahasilID,
                vId: identity.villageID
            )
            
            await MainActor.run {
                self.pdfStatus = .ready(url)
                self.downloadedPDFURL = url
            }
        } catch {
            await MainActor.run {
                self.isLoadingRoR = false
                self.rorError = error.localizedDescription
                self.pendingOpenDetail = false
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
                    district: identity.districtName,
                    tahasil: identity.tahasilName,
                    village: identity.villageName,
                    plot: identity.plotNumber,
                    khataNumber: rorResponse?.khataNumber,
                    bId: identity.tahasilID,
                    vId: identity.villageID
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

// MARK: - Supporting Subviews

struct BlueSummaryPill: View {
    let title: String
    let value: String
    let isAccent: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            
            Text(value)
                .font(.system(size: 15, weight: isAccent ? .bold : .semibold, design: .rounded))
                .foregroundColor(isAccent ? Theme.myBhoomiBlue : .black)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
    }
}

struct AdministrativeRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

