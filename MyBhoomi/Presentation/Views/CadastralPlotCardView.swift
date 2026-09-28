//
//  CadastralPlotCardView.swift
//  MyBhoomi
//
//  Figma Pixel-Perfect Implementation of:
//  - SkeletonView (Node ID: 845:89) with animated shimmer reflection
//  - OverviewCard (Node ID: 798:2420) with verified seal & completion haptics
//

import SwiftUI
import CoreLocation
import UIKit
import os.log

// MARK: - Overview Card Design Tokens (Direct from Figma 798:2420 & 845:89)
private enum FigmaOverviewTokens {
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
    
    static let grabberColor = dynamic(
        light: UIColor(red: 203/255, green: 208/255, blue: 220/255, alpha: 1.0),
        dark: UIColor(red: 72/255, green: 79/255, blue: 88/255, alpha: 0.85)
    )
    static let buttonBorder = dynamic(
        light: UIColor(red: 208/255, green: 214/255, blue: 226/255, alpha: 1.0),
        dark: UIColor(white: 1.0, alpha: 0.16)
    )
    static let skeletonFill = dynamic(
        light: UIColor(red: 223/255, green: 228/255, blue: 238/255, alpha: 1.0),
        dark: UIColor(red: 45/255, green: 51/255, blue: 59/255, alpha: 1.0)
    )
}

// MARK: - Authoritative Odia Locality Mapping
public enum AuthoritativeOdiaLocality {
    private static let authoritativeNames: [String: String] = [
        // Districts (30 Official Districts of Odisha)
        "anugul": "ଅନୁଗୋଳ", "angul": "ଅନୁଗୋଳ",
        "baleswar": "ବାଲେଶ୍ୱର", "balasore": "ବାଲେଶ୍ୱର",
        "baragarh": "ବରଗଡ଼", "bargarh": "ବରଗଡ଼",
        "bhadrak": "ଭଦ୍ରକ",
        "bolangir": "ବଲାଙ୍ଗୀର", "balangir": "ବଲାଙ୍ଗୀର",
        "boudh": "ବୌଦ୍ଧ", "baudh": "ବୌଦ୍ଧ",
        "cuttack": "କଟକ",
        "deogarh": "ଦେବଗଡ଼", "debagarh": "ଦେବଗଡ଼",
        "dhenkanal": "ଢେଙ୍କାନାଳ",
        "ganjam": "ଗଞ୍ଜାମ",
        "gajapati": "ଗଜପତି",
        "jagatsinghpur": "ଜଗତସିଂହପୁର",
        "jajpur": "ଯାଜପୁର",
        "jharsuguda": "ଝାରସୁଗୁଡ଼ା",
        "kalahandi": "କଳାହାଣ୍ଡି",
        "kandhamal": "କନ୍ଧମାଳ",
        "kendrapada": "କେନ୍ଦ୍ରାପଡ଼ା", "kendrapara": "କେନ୍ଦ୍ରାପଡ଼ା",
        "kendujhar": "କେନ୍ଦୁଝର", "keonjhar": "କେନ୍ଦୁଝର",
        "khurda": "ଖୋର୍ଦ୍ଧା", "khordha": "ଖୋର୍ଦ୍ଧା",
        "koraput": "କୋରାପୁଟ",
        "malkangiri": "ମାଲକାନଗିରି",
        "mayurbhanj": "ମୟୂରଭଞ୍ଜ",
        "nabarangpur": "ନବରଙ୍ଗପୁର",
        "nayagarh": "ନୟାଗଡ଼",
        "nuapada": "ନୂଆପଡ଼ା",
        "puri": "ପୁରୀ",
        "rayagada": "ରାୟଗଡ଼ା",
        "sambalpur": "ସମ୍ବଲପୁର",
        "sonepur": "ସୋନପୁର", "subarnapur": "ସୋନପୁର",
        "sundargarh": "ସୁନ୍ଦରଗଡ଼",
        
        // Tahasils
        "barkot": "ବାରକୋଟ", "barkote": "ବାରକୋଟ",
        "reamal": "ରିଆମାଳ",
        "tileibani": "ତିଳେଇବଣି",
        "bhubaneswar": "ଭୁବନେଶ୍ୱର",
        "jatni": "ଜଟଣୀ",
        "balianta": "ବାଳିଅନ୍ତା",
        "balipatna": "ବାଳିପାଟଣା",
        "keonjhar sadar": "କେନ୍ଦୁଝର ସଦର", "kendujhar sadar": "କେନ୍ଦୁଝର ସଦର",
        "telkoi": "ତେଲକୋଇ",
        "ghatagaon": "ଘଟଗାଁ",
        "anandapur": "ଆନନ୍ଦପୁର",
        "champua": "ଚମ୍ପୁଆ",
        "barbil": "ବଡ଼ବିଲ",
        "cuttack sadar": "କଟକ ସଦର",
        "puri sadar": "ପୁରୀ ସଦର",
        "sambalpur sadar": "ସମ୍ବଲପୁର ସଦର",
        "balasore sadar": "ବାଲେଶ୍ୱର ସଦର", "baleswar sadar": "ବାଲେଶ୍ୱର ସଦର",
        
        // Villages / Mouzas (Stored catalog data)
        "bahadapasi": "ବାହାଡା ପସି",
        "bahadapasi 03": "ବାହାଡା ପସି",
        "bahadapasi_03": "ବାହାଡା ପସି",
        "chakuli": "ଚକୁଳି",
        "chakuli 277": "ଚକୁଳି",
        "chakuli_277": "ଚକୁଳି",
        "g keri": "ଜି କେରି",
        "g keri 271": "ଜି କେରି",
        "g_keri": "ଜି କେରି",
        "patia": "ପଟିଆ",
        "chandrasekharpur": "ଚନ୍ଦ୍ରଶେଖରପୁର",
        "infocity": "ଇନଫୋସିଟି",
        "kiit": "କିଟ୍",
        "kalarahanga": "କଳାରାହାଙ୍ଗ",
        "raghunathpur": "ରଘୁନାଥପୁର",
        "baramunda": "ବାରମୁଣ୍ଡା",
        "khandagiri": "ଖଣ୍ଡଗିରି",
        "saheed nagar": "ସହିଦ ନଗର",
        "nayapalli": "ନୟାପଲ୍ଲୀ",
        "jayadev vihar": "ଜୟଦେବ ବିହାର",
        "old town": "ପୁରୁଣା ସହର"
    ]
    
    public static func name(for rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "N/A" { return "" }
        
        // Return directly if already in Odia script
        if trimmed.unicodeScalars.contains(where: { $0.value >= 0x0B00 && $0.value <= 0x0B7F }) {
            return trimmed
        }
        
        let normalized = trimmed.lowercased().replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = authoritativeNames[normalized] {
            return match
        }
        
        // Match prefix before numbers (e.g. "Bahadapasi 03" -> "bahadapasi")
        let basePart = normalized.components(separatedBy: CharacterSet.decimalDigits).first?.trimmingCharacters(in: .whitespaces) ?? ""
        if !basePart.isEmpty, let match = authoritativeNames[basePart] {
            return match
        }
        
        return trimmed
    }
}


// MARK: - Device Metrics & Rounded Corner Helpers
public struct DeviceMetrics {
    /// Approximate display corner radius derived purely from public API signals:
    /// devices with a bottom safe-area inset (notched / Dynamic Island displays)
    /// use ~48pt, while rectangular legacy displays use ~28pt.
    public static var screenCornerRadius: CGFloat {
        let hasBottomSafeArea = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .contains { scene in scene.windows.contains { $0.safeAreaInsets.bottom > 0 } }
        
        return hasBottomSafeArea ? 48.0 : 28.0
    }
    
    public static var bottomSafeAreaInset: CGFloat {
        let activeScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        
        for scene in activeScenes {
            if let inset = scene.windows.first?.safeAreaInsets.bottom, inset > 0 {
                return inset
            }
        }
        return 0
    }
    
    /// Returns concentric corner radius matching the hardware display curvature minus margins
    public static func concentricRadius(padding: CGFloat = 10) -> CGFloat {
        let r = screenCornerRadius
        return max(r - padding, 26.0)
    }
}

private let cardLog = Logger(subsystem: "com.bhumitra.app", category: "CadastralPlotCardView")

/// Shared fallback height used before the card's real height is measured.
private let defaultCardHeight: CGFloat = 270

public struct CadastralPlotCardView: View {
    public let parcel: Parcel
    @ObservedObject public var viewModel: MapViewModel
    public let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var rorResponse: RoRResponse? = nil
    @State private var officialSearchResult: OfficialSearchResult? = nil
    @State private var selectedResultForDetail: OfficialSearchResult? = nil
    @State private var showNewLandRecordReport: Bool = false
    @State private var showSubscriptionModal: Bool = false
    @State private var isLoadingRoR: Bool = false
    @State private var rorError: String? = nil
    @State private var rorErrorState: RoRErrorState? = nil
    @State private var resolvedIdentity: CanonicalParcelIdentity? = nil
    @State private var loadRoRTask: _Concurrency.Task<Void, Never>? = nil
    @State private var loadingTimerTask: _Concurrency.Task<Void, Never>? = nil
    
    private var isPlotLocked: Bool {
        if SubscriptionManager.shared.isUnlimited || SubscriptionManager.shared.isPremium {
            return false
        }
        if let ror = rorResponse {
            return ror.isLocked
        }
        return SubscriptionManager.shared.remainingPlotCredits <= 0
    }
    
    // Live interactive drag gesture state
    @GestureState private var dragTranslation: CGFloat = 0
    
    // Plot Owners card expansion state (only owners expand on arrow click)
    @State private var isOwnersExpanded: Bool = false
    
    // Live measured card height for screen center tracking
    @State private var cardMeasuredHeight: CGFloat = defaultCardHeight
    
    public init(
        parcel: Parcel,
        viewModel: MapViewModel,
        onDismiss: @escaping () -> Void
    ) {
        self.parcel = parcel
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        if let cached = VerifiedParcelCache.shared.findVerified(identity: parcel.identity) {
            self._rorResponse = State(initialValue: cached.rawRoRResponse)
            self._officialSearchResult = State(initialValue: cached.toOfficialSearchResult())
            self._rorError = State(initialValue: nil)
            self._rorErrorState = State(initialValue: nil)
            self._isLoadingRoR = State(initialValue: false)
            self._resolvedIdentity = State(initialValue: cached.canonicalIdentity)
        } else {
            self._rorResponse = State(initialValue: nil)
            self._officialSearchResult = State(initialValue: nil)
            self._rorError = State(initialValue: nil)
            self._rorErrorState = State(initialValue: nil)
            self._isLoadingRoR = State(initialValue: true)
            self._resolvedIdentity = State(initialValue: nil)
        }
    }
    
    private var identity: CanonicalParcelIdentity {
        resolvedIdentity ?? parcel.identity
    }
    
    private var displayDistrict: String {
        if let d = rorResponse?.district, !d.isEmpty, d != "N/A" { return AuthoritativeOdiaLocality.name(for: d) }
        if !identity.districtName.isEmpty, identity.districtName != "N/A" { return AuthoritativeOdiaLocality.name(for: identity.districtName) }
        if let d = viewModel.activeCadastralVillage?.districtName, !d.isEmpty { return AuthoritativeOdiaLocality.name(for: d) }
        return ""
    }
    
    private var displayTahasil: String {
        if let t = rorResponse?.tahasil, !t.isEmpty, t != "N/A" { return AuthoritativeOdiaLocality.name(for: t) }
        if !identity.tahasilName.isEmpty, identity.tahasilName != "N/A" { return AuthoritativeOdiaLocality.name(for: identity.tahasilName) }
        if let b = viewModel.activeCadastralVillage?.blockName, !b.isEmpty { return AuthoritativeOdiaLocality.name(for: b) }
        return ""
    }
    
    private var displayVillage: String {
        if let v = rorResponse?.village, !v.isEmpty, v != "N/A" { return AuthoritativeOdiaLocality.name(for: v) }
        if !identity.villageName.isEmpty, identity.villageName != "N/A" { return AuthoritativeOdiaLocality.name(for: identity.villageName) }
        if let v = viewModel.activeCadastralVillage?.name, !v.isEmpty { return AuthoritativeOdiaLocality.name(for: v) }
        return ""
    }
    
    private var locationSubtitle: String {
        let v = displayVillage
        let t = displayTahasil
        let d = displayDistrict
        if !v.isEmpty && v != "Village" && !t.isEmpty {
            return "\(v) · \(t)"
        } else if !v.isEmpty && v != "Village" && !d.isEmpty {
            return "\(v) · \(d)"
        } else if !t.isEmpty && !d.isEmpty {
            return "\(t) · \(d)"
        } else if !v.isEmpty && v != "Village" {
            return v
        } else if !t.isEmpty {
            return t
        } else if !d.isEmpty && d != "Odisha" {
            return d
        }
        return !identity.districtName.isEmpty && identity.districtName != "Odisha" ? displayDistrict : "Land Parcel"
    }
    
    private var displayKhatian: String {
        if let k = rorResponse?.khataNumber, !k.isEmpty { return k }
        if let k = parcel.metadata.additionalInfo?["k_no"] ?? parcel.metadata.additionalInfo?["khata"], !k.isEmpty { return k }
        return "—"
    }
    
    private var displayLandType: String {
        if let lt = rorResponse?.landType, !lt.isEmpty { return lt }
        if let tenure = rorResponse?.rawFields?["tenure"], !tenure.isEmpty { return tenure }
        if let lt = parcel.metadata.additionalInfo?["land_type"] ?? parcel.metadata.additionalInfo?["kissam"], !lt.isEmpty { return lt }
        return "—"
    }

    private var displayAreaFormatted: String {
        if let area = rorResponse?.area, !area.isEmpty, area != "N/A" {
            return OdishaAreaFormatter.formatToDecimalString(area)
        }
        if let estAcre = parcel.metadata.estimatedAreaAcre, estAcre > 0 {
            let decimals = estAcre * 100.0
            return String(format: "%.2f", decimals)
        }
        return "—"
    }
    
    // Apple Official Liquid Glass Card Shape - Concurrently matching hardware display roundness
    private var outerHorizontalPadding: CGFloat { 6.0 }
    
    private var cardCornerRadius: CGFloat {
        DeviceMetrics.concentricRadius(padding: outerHorizontalPadding)
    }
    
    // Content expansion capability
    private var hasExpandableContent: Bool {
        guard let ror = rorResponse else { return false }
        return ror.owners.count > 1 && !isPlotLocked
    }
    
    @GestureState private var isDragging: Bool = false
    
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    }
    
    // MARK: - Height-Only Drag Model
    // Drags never translate the card. The bottom edge stays anchored at all
    // times; dragging purely resizes the card:
    //   · Upward scrub continuously reveals more content (owners list), up to
    //     the full natural content height.
    //   · Downward scrub first collapses the owners section 1:1, then squeezes
    //     the whole card as a dismiss preview (content clips from the top).

    /// Floor for the downward squeeze preview so the card never vanishes.
    private let minSqueezedCardHeight: CGFloat = 170

    /// Owners row shows expanded content while resting-expanded or while the
    /// user is actively scrubbing upward.
    private var ownersDisplayExpanded: Bool {
        isOwnersExpanded || (isDragging && hasExpandableContent && dragTranslation < 0)
    }

    /// Extra whole-card squeeze after the owners section is fully collapsed.
    private var downSqueeze: CGFloat {
        guard isDragging, dragTranslation > 0 else { return 0 }
        let ownersAbsorb: CGFloat = isOwnersExpanded ? calculatedOwnersExpandedHeight : 0
        return max(0, dragTranslation - ownersAbsorb)
    }

    /// Target height for the squeeze frame; nil means natural sizing.
    private var squeezeFrameHeight: CGFloat? {
        guard downSqueeze > 0, cardMeasuredHeight > minSqueezedCardHeight else { return nil }
        return max(minSqueezedCardHeight, cardMeasuredHeight - downSqueeze)
    }

    private var squeezeProgress: CGFloat {
        let range = max(cardMeasuredHeight - minSqueezedCardHeight, 1)
        return min(downSqueeze / range, 1)
    }

    // Tactile feedback during the downward squeeze (bottom-anchored, so scale
    // and fade stay subtle and never move the bottom edge).
    private var dragScale: CGFloat {
        1.0 - (squeezeProgress * 0.035)
    }

    private var dragOpacity: Double {
        1.0 - (squeezeProgress * 0.22)
    }
    
    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let dy = value.translation.height
                let predictedDY = value.predictedEndTranslation.height
                
                // Downward fling dismisses from any state.
                if dy > 85 || predictedDY > 180 {
                    triggerHapticFeedback(.medium)
                    onDismiss()
                    return
                }
                
                // Upward fling expands when content allows it.
                if dy < -25 || predictedDY < -60 {
                    if hasExpandableContent {
                        triggerHapticFeedback(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isOwnersExpanded = true
                        }
                    }
                    return
                }
                
                // Otherwise settle the owners section at the nearest rest detent.
                if hasExpandableContent {
                    let natural = calculatedOwnersExpandedHeight
                    var revealed: CGFloat = isOwnersExpanded ? natural : 0
                    if dy < 0 {
                        revealed = min(natural, -dy)
                    } else if dy > 0 && isOwnersExpanded {
                        revealed = max(0, natural - dy)
                    }
                    let settleExpanded = natural > 0 && (revealed / natural) >= 0.5
                    if settleExpanded != isOwnersExpanded {
                        triggerHapticFeedback(.light)
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        isOwnersExpanded = settleExpanded
                    }
                }
            }
    }
    
    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    // Minimalist Apple Native Top Grabber Handle with interactive width feedback
    private var grabberHandleView: some View {
        Capsule()
            .fill(isDragging ? FigmaOverviewTokens.grabberColor.opacity(0.85) : FigmaOverviewTokens.grabberColor)
            .frame(width: isDragging ? 44 : 36, height: 4.5)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isDragging)
    }
    
private struct CadastralCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = defaultCardHeight
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Applies the interactive squeeze height while dragging down; passes through
/// untouched (natural sizing) at rest so measurement stays accurate.
private struct SqueezeFrameModifier: ViewModifier {
    let height: CGFloat?
    
    func body(content: Content) -> some View {
        if let height {
            content.frame(height: height, alignment: .bottom)
                .clipped()
        } else {
            content
        }
    }
}

    public var body: some View {
        GeometryReader { screenGeo in
            let screenHeight = screenGeo.size.height
            let restingCardTop = max(0, screenHeight - cardMeasuredHeight)
            let liveCardTop = restingCardTop
            let isBeyondCenter = liveCardTop < (screenHeight * 0.50)
            
            VStack(spacing: 0) {
                Spacer()
                
                // 2-Button Map Controls Pill (Parcels Eye & GPS Location) closely attached above the card
                HStack {
                    Spacer()
                    LiquidGlassMapControlsCapsule(viewModel: viewModel)
                        .padding(.trailing, 16)
                }
                .padding(.bottom, 10)
                .scaleEffect(isBeyondCenter ? 0.85 : 1.0, anchor: .bottomTrailing)
                .opacity(isBeyondCenter ? 0.0 : 1.0)
                .allowsHitTesting(!isBeyondCenter)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isBeyondCenter)
                
                // Main Apple Official Liquid Glass Floating Sheet
                // Height-only drag: during a downward squeeze the frame is pinned
                // to the shrinking height with bottom alignment, so the bottom edge
                // never moves and content clips from the top instead.
                VStack(spacing: 10) {
                    grabberHandleView
                    
                    if isLoadingRoR {
                        skeletonContentView
                    } else {
                        loadedOverviewContentView
                    }
                }
                .padding(.bottom, 12)
                .contentShape(Rectangle())
                .accessibilityAction(named: Text("Close card")) {
                    closeCard()
                }
                .background(
                    GeometryReader { cardProxy in
                        Color.clear.preference(
                            key: CadastralCardHeightKey.self,
                            value: cardProxy.size.height
                        )
                    }
                )
                .modifier(SqueezeFrameModifier(height: squeezeFrameHeight))
                .bhumitraLiquidGlass(in: cardShape, shadowRadius: 16, shadowY: 6)
                .padding(.horizontal, outerHorizontalPadding)
                .padding(.bottom, outerHorizontalPadding)
                .scaleEffect(dragScale, anchor: .bottom)
                .opacity(dragOpacity)
                // Card container uniformly owns the vertical drag gesture across all states.
                // Height-only model: up scrub reveals content, down scrub squeezes, bottom anchored.
                .gesture(cardDragGesture)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isOwnersExpanded)
                .animation(BhumitraMotion.standard, value: isLoadingRoR)
            }
            .onPreferenceChange(CadastralCardHeightKey.self) { height in
                if height > 0 {
                    self.cardMeasuredHeight = height
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .task(id: parcel.id) {
            loadRoRTask?.cancel()
            loadingTimerTask?.cancel()
            self.isOwnersExpanded = false
            
            // Check persistent verified parcel cache first for instant 0ms restoration
            if let cached = VerifiedParcelCache.shared.findVerified(identity: parcel.identity) {
                cardLog.debug("Instant cache hit for plot \(parcel.identity.plotNumber)")
                self.rorResponse = cached.rawRoRResponse
                self.officialSearchResult = cached.toOfficialSearchResult()
                self.resolvedIdentity = cached.canonicalIdentity
                self.rorError = nil
                self.rorErrorState = nil
                self.isLoadingRoR = false
                logLandRecordViewed()
                prefetchSupportingServices()
                return
            }
            
            self.rorResponse = nil
            self.officialSearchResult = nil
            self.resolvedIdentity = nil
            self.rorError = nil
            self.rorErrorState = .loading(isSlow: false)
            self.isLoadingRoR = true
            prefetchSupportingServices()
            await startLoadRoR()
        }
        .sheet(item: $selectedResultForDetail) { result in
            LandPassportDetailView(result: result, selectedBoundary: parcel.boundary)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showNewLandRecordReport) {
            if let ror = rorResponse {
                LandRecordReportView(identity: parcel.identity, ror: ror, parcel: parcel)
            } else {
                LandRecordReportView(parcel: parcel)
            }
        }
        .fullScreenCover(isPresented: $showSubscriptionModal) {
            SubscriptionView()
        }
    }
    
    /// VoiceOver description for the owners row, including expanded state.
    private func accessibilityLabel(for count: Int, isGov: Bool) -> String {
        let subject = isGov ? "Government of Odisha land record" : "Plot owners"
        if count <= 1 { return subject }
        return isOwnersExpanded ? "\(subject), \(count) owners, expanded" : "\(subject), \(count) owners, collapsed"
    }
    
    /// Close affordance for VoiceOver and discoverability; mirrors the swipe-down dismiss.
    private func closeCard() {
        triggerHapticFeedback(.light)
        onDismiss()
    }
    
    // MARK: - Supporting Tasks
    
    /// Both services are actors with internal per-parcel memoization, so repeats
    /// are cheap; this just warms them once per card presentation.
    private func prefetchSupportingServices() {
        _Concurrency.Task {
            _ = try? await BenchmarkValuationService.shared.fetchValuation(for: parcel)
        }
        _Concurrency.Task {
            _ = try? await RegistrationCostService.shared.fetchEstimate(for: parcel)
        }
    }
    
    /// Analytics with real record data. Fires only after the RoR actually resolves
    /// (from cache or network) so owner/government/classification values are accurate.
    private func logLandRecordViewed() {
        guard let ror = rorResponse else { return }
        AnalyticsService.shared.log(.landRecordViewed(
            districtID: displayDistrict,
            isGovernmentLand: ror.isGovernmentLand,
            ownerCount: ror.owners.count,
            landClassification: displayLandType
        ))
    }
    
    // MARK: - 1. SKELETON LOADING CONTENT (Matching Pixel-Perfect Geometry)
    private var skeletonContentView: some View {
        VStack(spacing: 8) {
            // High-Confidence GPS Auto-Selection Explanatory Banner (Non-ownership)
            if let gpsContext = viewModel.gpsAutoSelectionContext, gpsContext.plotNumber == identity.plotNumber {
                gpsSpatialRelationshipBanner(accuracy: gpsContext.accuracy, plotNumber: identity.plotNumber)
                    .padding(.horizontal, 12)
            }
            
            // Header Row Skeleton
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plot \(identity.plotNumber)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Theme.Color.bhumitraPrimary)
                            .frame(width: 6, height: 6)
                            .skeletonShimmer()
                        Text(locationSubtitle.isEmpty ? "Querying land records..." : "\(locationSubtitle) • Live Record")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                SkeletonLoadingStarView(size: 24)
            }
            .padding(.horizontal, 12)
            
            // 3-Tile Metrics Skeleton
            HStack(spacing: 8) {
                ForEach(["KHATIAN", "AREA", "LAND TYPE"], id: \.self) { title in
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 10.5, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(Theme.Color.bhumitraTertiaryText)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.Color.bhumitraSurfaceSecondary)
                            .frame(width: 50, height: 18)
                            .skeletonShimmer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.Color.bhumitraSurfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                            )
                    )
                }
            }
            .padding(.horizontal, 12)
            
            // Owners Skeleton
            HStack(spacing: 9) {
                Circle()
                    .fill(Theme.Color.bhumitraSurfaceSecondary)
                    .frame(width: 20, height: 20)
                    .skeletonShimmer()
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.Color.bhumitraSurfaceSecondary)
                    .frame(width: 150, height: 16)
                    .skeletonShimmer()
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Color.bhumitraSurfaceSecondary)
            )
            .padding(.horizontal, 12)
            
            // CTA Button Skeleton
            Capsule()
                .fill(Theme.Color.bhumitraPrimary.opacity(0.80))
                .frame(height: 48)
                .overlay(
                    HStack(spacing: 6) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.80)
                        Text(rorErrorState == .loading(isSlow: true) ? "Still Checking Official RoR…" : "Checking Official RoR…")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundColor(.white)
                    }
                )
                .padding(.horizontal, 12)
                .padding(.top, 1)
        }
    }
    
    // MARK: - Minimalist Error & Retry View
    private func errorRetryView(message: String) -> some View {
        let isNotFound = rorErrorState == .notFound
        let isBusy = rorErrorState == .temporaryBusy
        
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: isNotFound ? "doc.text.magnifyingglass" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isNotFound ? Theme.Color.bhumitraSecondaryText : Theme.Color.bhumitraWarning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isNotFound ? "Official Land Record Unavailable" : "Couldn't Load Land Details")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    
                    Text(isNotFound ? "No official government record is currently on file for this plot." :
                         isBusy ? "Government service is temporarily busy. Tap to retry." :
                         "Official land records are temporarily unavailable. Tap to retry.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            
            if !isNotFound {
                Button {
                    retryLoadRoR()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                        Text("Tap to Retry")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Capsule()
                            .fill(Theme.Color.bhumitraPrimary)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Inline Non-Blocking Status Notice
    private func inlineStatusNoticeBar(for state: RoRErrorState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if case .loading = state {
                    ProgressView()
                        .controlSize(.small)
                        .tint(statusNoticeIconColor(for: state))
                } else {
                    Image(systemName: state.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(statusNoticeIconColor(for: state))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    if let subtitle = state.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                Spacer()
                
                if case .quotaExceeded = state {
                    Button {
                        Theme.selectionHaptic()
                        showSubscriptionModal = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text("Get Searches")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Theme.Color.bhumitraPrimary)
                        )
                    }
                    .buttonStyle(.plain)
                } else if state.isRetryable {
                    Button {
                        retryLoadRoR()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("Retry")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Theme.Color.bhumitraTint)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Subtle indeterminate activity track communicating live background query without fake percentages
            if case .loading = state {
                IndeterminateActivityBar()
                    .padding(.top, 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(statusNoticeIconColor(for: state).opacity(0.35), lineWidth: 0.8)
                )
        )
    }

    private func statusNoticeIconColor(for state: RoRErrorState) -> Color {
        switch state {
        case .notFound, .identityUnresolved:
            return Theme.Color.bhumitraSecondaryText
        case .loading(let isSlow):
            return isSlow ? Theme.Color.bhumitraWarning : Theme.Color.bhumitraPrimary
        case .quotaExceeded:
            return Theme.Color.bhumitraPrimary
        case .slow, .unavailable, .temporaryBusy, .identityMismatch, .networkProblem, .malformedResponse:
            return Theme.Color.bhumitraWarning
        }
    }
    
    // MARK: - Subtle Indeterminate Activity Bar
    private struct IndeterminateActivityBar: View {
        @State private var isAnimating = false
        
        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Color.bhumitraPrimary.opacity(0.12))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.Color.bhumitraPrimary.opacity(0.0),
                                    Theme.Color.bhumitraPrimary.opacity(0.85),
                                    Theme.Color.bhumitraPrimary.opacity(0.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * 0.35, 40))
                        .offset(x: isAnimating ? (geo.size.width - max(geo.size.width * 0.35, 40)) : 0)
                }
            }
            .frame(height: 2.5)
            .clipShape(Capsule())
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
    
    // MARK: - 2. LOADED OVERVIEW CONTENT (Pixel-Perfect Reference Match)
    private var loadedOverviewContentView: some View {
        VStack(spacing: 8) {
            // High-Confidence GPS Auto-Selection Explanatory Banner (Non-ownership)
            if let gpsContext = viewModel.gpsAutoSelectionContext, gpsContext.plotNumber == identity.plotNumber {
                gpsSpatialRelationshipBanner(accuracy: gpsContext.accuracy, plotNumber: identity.plotNumber)
                    .padding(.horizontal, 12)
            }
            
            // 1. Header Row: Plot Title + Location Subtitle + Verified Pill Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plot \(identity.plotNumber)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    
                    Text(locationSubtitle)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Verification Badge (Subtle and compact)
                if rorResponse != nil && rorErrorState == nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraSuccess)
                        Text("Verified")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraSuccess)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Theme.Color.bhumitraSuccessSurface)
                    )
                }
            }
            .padding(.horizontal, 12)
            
            // Optional Non-Intrusive Status / Error Notice
            if rorResponse == nil, let state = rorErrorState {
                inlineStatusNoticeBar(for: state)
                    .padding(.horizontal, 12)
            }
            
            // 2. Metrics 3-Card Row (KHATIAN | AREA | LAND TYPE)
            metricsThreeCardsRow
            
            // 3. Plot Owners Card (Tappable Arrow Expands All Owners)
            plotOwnersCardView
            
            // 4. Primary Action Button: Filled Vibrant Purple
            ctaActionButton
                .padding(.top, 3)
                .padding(.bottom, rorResponse != nil ? 2 : 6)
            
            // 5. Controlled Entry Point: View Full Land Record Report (New Screen)
            Button {
                showNewLandRecordReport = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                    Text("View Full Land Record Report")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Theme.Color.bhumitraPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(Theme.Color.bhumitraPrimary.opacity(0.08))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }
    
    // MARK: - GPS Spatial Relationship Banner (P0 Fix 4)
    private func gpsSpatialRelationshipBanner(accuracy: Double, plotNumber: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "location.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.myBhoomiBlue)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Your location appears to be inside Plot \(plotNumber)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                
                Text("Location accuracy ±\(Int(accuracy))m")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                
                Text("Plot boundaries are based on available cadastral map data.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.myBhoomiBlue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.myBhoomiBlue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 3-Card Metrics Row
    private var metricsThreeCardsRow: some View {
        HStack(spacing: 8) {
            // Card 1: KHATIAN
            VStack(spacing: 4) {
                Text("KHATIAN")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
                
                if isPlotLocked {
                    BlurredKhataView(khata: displayKhatian, isLocked: true)
                } else {
                    Text(displayKhatian)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 0.8)
                    )
            )
            
            // Card 2: AREA (Vibrant Purple "Decimal" Value)
            VStack(spacing: 4) {
                Text("AREA")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
                
                if isPlotLocked {
                    BlurredAreaView(area: displayAreaFormatted, isLocked: true)
                } else {
                    Text("\(displayAreaFormatted) Decimal")
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 0.8)
                    )
            )
            
            // Card 3: LAND TYPE
            VStack(spacing: 4) {
                Text("LAND TYPE")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
                
                Text(displayLandType)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 0.8)
                    )
            )
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - Owner Expansion Dynamic Height Calculation
    
    /// Calculated natural height of the expanded owners section for bottom-anchored collapse
    private var calculatedOwnersExpandedHeight: CGFloat {
        guard !isPlotLocked else { return 0 }
        let ownersList = rorResponse?.owners ?? []
        let displayCount = min(ownersList.count, 5)
        guard displayCount > 0 else { return 0 }
        // Each owner row is 28pt high, with 8pt spacing between rows
        let rowsHeight = CGFloat(displayCount) * 28.0 + CGFloat(max(0, displayCount - 1)) * 8.0
        let moreRowHeight: CGFloat = ownersList.count > 5 ? 22.0 : 0.0
        // 1pt divider + 6pt divider bottom padding + 10pt container bottom padding = 17pt
        return rowsHeight + moreRowHeight + 17.0
    }
    
    /// Live owners-section height driven by drag scrubs and the resting state.
    private var currentOwnersSectionHeight: CGFloat {
        let natural = calculatedOwnersExpandedHeight
        guard natural > 0 else { return 0 }
        if isDragging {
            if dragTranslation < 0 && hasExpandableContent {
                // Scrubbing up: reveal owners 1:1 with the finger, up to full content.
                return min(natural, -dragTranslation)
            }
            if dragTranslation > 0 && isOwnersExpanded {
                // Scrubbing down: collapse owners first, bottom stays anchored.
                return max(0, natural - dragTranslation)
            }
        }
        return isOwnersExpanded ? natural : 0
    }
    
    // MARK: - Plot Owners Card (Expandable on arrow click)
    private var plotOwnersCardView: some View {
        let ownersList = rorResponse?.owners ?? []
        let isGov = rorResponse?.isGovernmentLand == true
        let count = ownersList.count
        let primaryName: String = {
            if isGov {
                return "ଓଡ଼ିଶା ସରକାର (Government of Odisha)"
            }
            if let first = ownersList.first?.name, !first.isEmpty {
                return first
            }
            if isLoadingRoR {
                if case .loading(let isSlow) = rorErrorState, isSlow {
                    return "Still checking official government record…"
                }
                return "Checking official government record…"
            }
            if let state = rorErrorState {
                switch state {
                case .notFound:
                    return "No official record on file"
                case .slow, .loading:
                    return "Official record taking longer than expected"
                case .unavailable, .temporaryBusy:
                    return "Official service temporarily unavailable"
                case .networkProblem:
                    return "Network connection issue"
                case .identityUnresolved, .identityMismatch, .malformedResponse:
                    return "Record unverified"
                case .quotaExceeded:
                    return "Search limit reached"
                }
            }
            return "Tap below to view official land records"
        }()
        
        return VStack(spacing: 0) {
            Button {
                if count > 1 {
                    triggerHapticFeedback(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        isOwnersExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isGov ? "building.columns.fill" : "person.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                    
                    if isPlotLocked && count > 0 {
                        blurredOwnerTeaser(name: primaryName)
                    } else {
                        Text(primaryName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            .lineLimit(1)
                    }
                    
                    if count > 1 {
                        Text("+\(count - 1) more")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    }
                    
                    Spacer()
                    
                    if count > 1 {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            .rotationEffect(.degrees(ownersDisplayExpanded ? 180 : 0))
                            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: ownersDisplayExpanded)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(count <= 1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: count, isGov: isGov))
            .accessibilityHint(count > 1 ? "Double-taps to show all owners" : "")
            .accessibilityAddTraits(count > 1 ? [.isButton] : [])
            
            // Expanded Owners List inside the same card (bottom-anchored height collapse)
            if ownersDisplayExpanded && !isPlotLocked {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Theme.Color.bhumitraDivider)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                    
                    VStack(spacing: 8) {
                        ForEach(Array(ownersList.prefix(5).enumerated()), id: \.offset) { index, owner in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.Color.bhumitraTint)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Theme.Color.bhumitraPrimary)
                                    )
                                
                                Text(owner.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if let share = owner.share, !share.isEmpty, share != "N/A" {
                                    Text("Share: \(share)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                }
                            }
                            .frame(height: 28)
                            .accessibilityElement(children: .combine)
                        }
                        
                        if ownersList.count > 5 {
                            Text("+ \(ownersList.count - 5) more in official details")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                .frame(height: 22)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .accessibilityLabel("All owners")
                .frame(height: currentOwnersSectionHeight, alignment: .top)
                .clipped()
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 0.8)
                )
        )
        .padding(.horizontal, 12)
    }
    
    // MARK: - Primary Action Button (Official Apple Liquid Glass Button)
    private var ctaActionButton: some View {
        Button {
            if rorResponse != nil {
                if isPlotLocked {
                    openDetailedReport()
                } else {
                    showNewLandRecordReport = true
                }
            } else if let state = rorErrorState, state.isRetryable {
                retryLoadRoR()
            } else {
                showNewLandRecordReport = true
            }
        } label: {
            HStack(spacing: 8) {
                if rorResponse != nil {
                    Text(isPlotLocked ? "Unlock Official RoR Details" : "View Official RoR Details")
                    Image(systemName: "arrow.right")
                } else if let state = rorErrorState, state.isRetryable {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry Official Lookup")
                } else {
                    Text("View Land Details")
                    Image(systemName: "arrow.right")
                }
            }
        }
        .buttonStyle(.primaryCTA)
        .padding(.horizontal, 12)
    }
    
    private func blurredOwnerTeaser(name: String) -> some View {
        let (firstInitial, lastInitial) = extractFirstAndLastInitials(from: name)
        let isOdia = firstInitial.unicodeScalars.contains { $0.value >= 0x0B00 && $0.value <= 0x0B7F }
        let firstNameFiller = isOdia ? "୍ରକାଶ" : "amesh"
        let surnameFiller = isOdia ? "ାତ୍ର" : "ahoo"
        
        return HStack(spacing: 8) {
            HStack(spacing: 0) {
                Text(firstInitial)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                Text(firstNameFiller)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .blur(radius: 3.5)
            }
            HStack(spacing: 0) {
                Text(lastInitial)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                Text(surnameFiller)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .blur(radius: 3.5)
            }
        }
        .lineLimit(1)
    }
    
    private func openDetailedReport() {
        if isPlotLocked {
            if SubscriptionManager.shared.canPerformPlotSearch {
                let consumed = SubscriptionManager.shared.consumePlotSearchCredit(
                    plot: parcel.identity.plotNumber,
                    village: displayVillage,
                    district: displayDistrict
                )
                if consumed {
                    self.rorResponse = nil
                    self.officialSearchResult = nil
                    retryLoadRoR()
                    return
                }
            }
            showSubscriptionModal = true
            return
        }
        if let existing = officialSearchResult {
            selectedResultForDetail = existing
        } else if let ror = rorResponse, ror.verification?.status == .verified {
            let result = OfficialSearchResult(ror: ror, identity: parcel.identity)
            selectedResultForDetail = result
        }
    }
    
    private func retryLoadRoR() {
        loadRoRTask?.cancel()
        loadingTimerTask?.cancel()
        self.isLoadingRoR = true
        self.rorError = nil
        self.rorErrorState = .loading(isSlow: false)
        loadRoRTask = _Concurrency.Task {
            await startLoadRoR()
        }
    }
    
    private func startLoadRoR() async {
        loadingTimerTask?.cancel()
        self.rorErrorState = .loading(isSlow: false)
        loadingTimerTask = _Concurrency.Task {
            try? await Task.sleep(nanoseconds: 8_500_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    if self.isLoadingRoR {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.rorErrorState = .loading(isSlow: true)
                        }
                    }
                }
            }
        }
        
        await loadRoR()
        loadingTimerTask?.cancel()
    }
    
    private func loadRoR() async {
        let targetParcelID = parcel.id
        do {
            var currentIdentity = self.identity
            
            // If district is missing, "Odisha", or generic, resolve via LocalAdminClient using parcel coordinates
            let isDistrictUnresolved = currentIdentity.districtName.isEmpty ||
                                      currentIdentity.districtName == "Odisha" ||
                                      currentIdentity.districtName == "N/A"
            let isTahasilUnresolved = currentIdentity.tahasilName.isEmpty ||
                                     currentIdentity.tahasilName == "N/A"
            let isVillageUnresolved = currentIdentity.villageName.isEmpty ||
                                     currentIdentity.villageName == "Village" ||
                                     currentIdentity.villageName == "N/A"
            
            if isDistrictUnresolved || isTahasilUnresolved || isVillageUnresolved {
                if let center = parcel.boundary.first {
                    if let locationInfo = try? await LocalAdminClient.shared.fetchLocationInfo(latitude: center.latitude, longitude: center.longitude) {
                        try Task.checkCancellation()
                        let resolvedDist = isDistrictUnresolved && !locationInfo.district.isEmpty && locationInfo.district != "Unknown District" ? locationInfo.district : currentIdentity.districtName
                        let resolvedTah = isTahasilUnresolved && !locationInfo.tehsil.isEmpty && locationInfo.tehsil != "Unknown Tehsil" ? locationInfo.tehsil : currentIdentity.tahasilName
                        let resolvedVill = isVillageUnresolved && !locationInfo.village.isEmpty && locationInfo.village != "Unknown Village" ? locationInfo.village : currentIdentity.villageName
                        
                        let updated = CanonicalParcelIdentity(
                            parcelID: currentIdentity.parcelID,
                            plotNumber: currentIdentity.plotNumber,
                            districtName: resolvedDist,
                            districtID: currentIdentity.districtID,
                            tahasilName: resolvedTah,
                            tahasilID: currentIdentity.tahasilID,
                            villageName: resolvedVill,
                            villageID: currentIdentity.villageID,
                            panchayatName: currentIdentity.panchayatName ?? locationInfo.panchayat
                        )
                        await MainActor.run {
                            guard self.parcel.id == targetParcelID else { return }
                            self.resolvedIdentity = updated
                        }
                        currentIdentity = updated
                    }
                }
            }
            
            try Task.checkCancellation()
            
            // If identity was updated/resolved, re-check local verified cache
            if let cached = VerifiedParcelCache.shared.findVerified(identity: currentIdentity) {
                cardLog.debug("Post-resolution cache hit for plot \(currentIdentity.plotNumber)")
                await MainActor.run {
                    guard self.parcel.id == targetParcelID else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        self.rorResponse = cached.rawRoRResponse
                        self.officialSearchResult = cached.toOfficialSearchResult()
                        self.rorError = nil
                        self.rorErrorState = nil
                        self.isLoadingRoR = false
                    }
                    self.logLandRecordViewed()
                }
                return
            }
            
            let queryParcel = Parcel(
                id: parcel.id,
                boundary: parcel.boundary,
                metadata: ParcelMetadata(
                    identity: currentIdentity,
                    estimatedAreaAcre: parcel.metadata.estimatedAreaAcre,
                    additionalInfo: parcel.metadata.additionalInfo
                )
            )
            
            try Task.checkCancellation()
            
            cardLog.debug("Fetching RoR for plot=\(currentIdentity.plotNumber), village=\(currentIdentity.villageName), tahasil=\(currentIdentity.tahasilName), district=\(currentIdentity.districtName)")
            let response = try await RoRService.shared.fetchOwnerDetails(for: queryParcel)
            
            try Task.checkCancellation()
            
            cardLog.debug("Received RoR: plot=\(response.plot), khata=\(response.khataNumber ?? "none"), owners=\(response.owners.count), area=\(response.area ?? "none")")
            let verif = ParcelCrossVerifier.verify(
                gisIdentity: currentIdentity,
                rorResponse: response,
                gisAreaInAcre: parcel.metadata.estimatedAreaAcre
            )
            await MainActor.run {
                guard self.parcel.id == targetParcelID else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    if verif.isVerified {
                        self.rorResponse = response
                        self.officialSearchResult = OfficialSearchResult(ror: response, identity: currentIdentity)
                        self.rorError = nil
                        self.rorErrorState = nil
                    } else {
                        self.rorResponse = nil
                        self.officialSearchResult = nil
                        self.rorError = verif.reasons.first ?? "Official record could not be verified for this exact parcel."
                        self.rorErrorState = .identityMismatch
                    }
                    self.isLoadingRoR = false
                }
                self.logLandRecordViewed()
                
                // Save to verified parcel cache if verified
                if verif.isVerified {
                    VerifiedParcelCache.shared.save(
                        identity: currentIdentity,
                        ror: response,
                        verification: verif,
                        boundary: parcel.boundary
                    )
                }
                
                // Trigger lightweight App Store feedback prompt if eligible (Opportunity #1 or #2)
                AppFeedbackManager.shared.notifySuccessfulSearchResultPresented(
                    resultId: "parcel_\(currentIdentity.plotNumber)_\(currentIdentity.villageName)_\(response.khataNumber ?? "")"
                )
                
                // Reconcile server credit balance
                _Concurrency.Task {
                    await SubscriptionManager.shared.fetchServerCreditBalance()
                }
                
                // Prefetch Official RoR PDF in background
                _Concurrency.Task {
                    let docID = response.officialDocument?.documentID
                    _ = try? await OfficialRoRPDFService.shared.fetchOrGetPDF(
                        district: currentIdentity.districtName,
                        tahasil: currentIdentity.tahasilName,
                        village: currentIdentity.villageName,
                        plot: response.plot.isEmpty ? currentIdentity.plotNumber : response.plot,
                        khataNumber: response.khataNumber,
                        documentID: docID
                    )
                }
            }
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            cardLog.error("loadRoR failed: \(error.localizedDescription)")
            await MainActor.run {
                guard self.parcel.id == targetParcelID else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    self.rorError = error.localizedDescription
                    self.rorErrorState = RoRErrorState.from(error: error)
                    self.isLoadingRoR = false
                }
            }
        }
    }
}

// MARK: - Word-Level Blurred Masked Views for Locked Previews

private func extractFirstAndLastInitials(from name: String) -> (first: String, last: String) {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let words = clean.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty && $0 != "•" }
    
    guard !words.isEmpty else { return ("ପ", "ପ") }
    
    let firstWord = words.first!
    let firstInitial = String(firstWord.prefix(1))
    
    let lastInitial: String
    if words.count > 1 {
        let lastWord = words.last!
        lastInitial = String(lastWord.prefix(1))
    } else {
        lastInitial = "ପ"
    }
    return (firstInitial, lastInitial)
}

private struct BlurredKhataView: View {
    let khata: String
    let isLocked: Bool
    
    var body: some View {
        if !isLocked {
            Text(khata)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        } else {
            let cleanKhata = khata.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let firstDigit = cleanKhata.isEmpty ? "8" : String(cleanKhata.prefix(1))
            let suffix = cleanKhata.count > 1 ? String(cleanKhata.dropFirst(1)) : "48"
            
            HStack(spacing: 1) {
                Text(firstDigit)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                
                Text(suffix)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .blur(radius: 3.5)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.70)
        }
    }
}

private struct BlurredAreaView: View {
    let area: String
    let isLocked: Bool
    
    var body: some View {
        if !isLocked {
            Text("\(area) Decimal")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.Color.bhumitraPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        } else {
            let cleanArea = area.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let numPart = cleanArea.replacingOccurrences(of: "Acre", with: "")
                .replacingOccurrences(of: "Ha", with: "")
                .replacingOccurrences(of: "dec", with: "")
                .replacingOccurrences(of: "Decimal", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let firstDigit = numPart.isEmpty ? "0" : String(numPart.prefix(1))
            let restOfNum = numPart.count > 1 ? String(numPart.dropFirst(1)) : ".45"
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(firstDigit)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimary)
                
                Text(restOfNum)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimary.opacity(0.65))
                    .blur(radius: 3.5)
                
                Text("Decimal")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.70)
        }
    }
}

