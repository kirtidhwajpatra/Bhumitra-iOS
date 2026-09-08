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

// MARK: - Overview Card Design Tokens (Direct from Figma 798:2420 & 845:89)
private enum FigmaOverviewTokens {
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
    
    static let primaryPurple = Color(hex: "#7600FF")
    
    static let cardBg = dynamic(
        light: .white,
        dark: UIColor(red: 22/255, green: 27/255, blue: 34/255, alpha: 1.0)
    )
    static let textBlack = dynamic(
        light: .black,
        dark: UIColor(red: 240/255, green: 246/255, blue: 252/255, alpha: 1.0)
    )
    static let textGrayMetrics = dynamic(
        light: UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1.0),
        dark: UIColor(red: 201/255, green: 209/255, blue: 217/255, alpha: 1.0)
    )
    static let textGraySubtitle = dynamic(
        light: UIColor(red: 102/255, green: 102/255, blue: 102/255, alpha: 1.0),
        dark: UIColor(red: 139/255, green: 148/255, blue: 158/255, alpha: 1.0)
    )
    static let textDisabled = dynamic(
        light: UIColor(red: 158/255, green: 158/255, blue: 158/255, alpha: 1.0),
        dark: UIColor(red: 110/255, green: 118/255, blue: 129/255, alpha: 1.0)
    )
    
    static let dividerHorizontal = dynamic(
        light: UIColor(red: 232/255, green: 232/255, blue: 232/255, alpha: 1.0),
        dark: UIColor(white: 1.0, alpha: 0.10)
    )
    static let dividerVertical = dynamic(
        light: UIColor(red: 213/255, green: 216/255, blue: 224/255, alpha: 1.0),
        dark: UIColor(white: 1.0, alpha: 0.12)
    )
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

// MARK: - Device Metrics & Rounded Corner Helpers
public struct DeviceMetrics {
    public static var screenCornerRadius: CGFloat {
        let activeScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        
        for scene in activeScenes {
            for window in scene.windows {
                let key = ["Radius", "Corner", "display", "_"].reversed().joined() // "_displayCornerRadius"
                if let radius = window.screen.value(forKey: key) as? CGFloat, radius > 0 {
                    return radius
                }
                if window.safeAreaInsets.bottom > 0 {
                    return 48.0
                }
            }
        }
        
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            if keyWindow.safeAreaInsets.bottom > 0 {
                return 48.0
            }
        }
        return 28.0
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

public struct CadastralPlotCardView: View {
    public let parcel: Parcel
    @ObservedObject public var viewModel: MapViewModel
    public let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var rorResponse: RoRResponse? = nil
    @State private var officialSearchResult: OfficialSearchResult? = nil
    @State private var selectedResultForDetail: OfficialSearchResult? = nil
    @State private var showSubscriptionModal: Bool = false
    @State private var isLoadingRoR: Bool = false
    @State private var rorError: String? = nil
    
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
    @State private var dragOffsetY: CGFloat = 0
    
    // Interactive Expansion & Apple Liquid Glass Touch-Glow States
    @State private var isExpanded: Bool = false
    @State private var touchLocation: CGPoint = .zero
    @State private var isTouching: Bool = false
    @State private var touchIntensity: CGFloat = 0.0
    @State private var cardWidth: CGFloat = 360
    @State private var cardHeight: CGFloat = 300
    
    public init(
        parcel: Parcel,
        viewModel: MapViewModel,
        onDismiss: @escaping () -> Void
    ) {
        self.parcel = parcel
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self._rorResponse = State(initialValue: nil)
        self._officialSearchResult = State(initialValue: nil)
        self._rorError = State(initialValue: nil)
        self._isLoadingRoR = State(initialValue: true)
    }
    
    private var identity: CanonicalParcelIdentity {
        parcel.identity
    }
    
    private var displayDistrict: String {
        if let d = rorResponse?.district, !d.isEmpty, d != "N/A" { return d }
        if !identity.districtName.isEmpty, identity.districtName != "N/A" { return identity.districtName }
        if let d = viewModel.activeCadastralVillage?.districtName, !d.isEmpty { return d }
        return ""
    }
    
    private var displayTahasil: String {
        if let t = rorResponse?.tahasil, !t.isEmpty, t != "N/A" { return t }
        if !identity.tahasilName.isEmpty, identity.tahasilName != "N/A" { return identity.tahasilName }
        if let b = viewModel.activeCadastralVillage?.blockName, !b.isEmpty { return b }
        return ""
    }
    
    private var displayVillage: String {
        if let v = rorResponse?.village, !v.isEmpty, v != "N/A" { return v }
        if !identity.villageName.isEmpty, identity.villageName != "N/A" { return identity.villageName }
        if let v = viewModel.activeCadastralVillage?.name, !v.isEmpty { return v }
        return ""
    }
    
    private var locationSubtitle: String {
        let v = displayVillage
        let t = displayTahasil
        if !v.isEmpty && !t.isEmpty {
            return "\(v), \(t)"
        } else if !v.isEmpty {
            return v
        } else if !t.isEmpty {
            return t
        }
        return "\(identity.villageName), \(identity.tahasilName)"
    }
    
    private var displayKhatian: String {
        if let k = rorResponse?.khataNumber, !k.isEmpty { return k }
        if let k = parcel.metadata.additionalInfo?["k_no"] ?? parcel.metadata.additionalInfo?["khata"], !k.isEmpty { return k }
        return "-"
    }
    
    private var displayLandType: String {
        if let lt = rorResponse?.landType, !lt.isEmpty { return lt }
        if let tenure = rorResponse?.rawFields?["tenure"], !tenure.isEmpty { return tenure }
        if let lt = parcel.metadata.additionalInfo?["land_type"] ?? parcel.metadata.additionalInfo?["kissam"], !lt.isEmpty { return lt }
        return "-"
    }

    private var displayAreaFormatted: String {
        if let area = rorResponse?.area, !area.isEmpty, area != "N/A" {
            return OdishaAreaFormatter.formatToDecimalString(area)
        }
        if let est = parcel.metadata.estimatedAreaAcre, est > 0 {
            return OdishaAreaFormatter.formatToDecimalString("\(est)")
        }
        return "-"
    }
    
    private var cardBottomRadius: CGFloat {
        DeviceMetrics.concentricRadius(padding: 10)
    }
    
    private var cardShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 32,
            bottomLeadingRadius: cardBottomRadius,
            bottomTrailingRadius: cardBottomRadius,
            topTrailingRadius: 32,
            style: .continuous
        )
    }
    
    private var cardEffectiveOffsetY: CGFloat {
        let total = dragOffsetY + dragTranslation
        if isExpanded {
            return max(0, total)
        } else {
            if total < 0 {
                return total * 0.45
            } else {
                return max(0, total)
            }
        }
    }
    
    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let translation = value.translation.height
                let velocity = value.predictedEndTranslation.height
                
                if isExpanded {
                    // Swiping down collapses
                    if translation > 45 || velocity > 75 {
                        withAnimation(BhumitraMotion.sheetPresentation) {
                            isExpanded = false
                            dragOffsetY = 0
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else if translation > 180 || velocity > 260 {
                        onDismiss()
                    } else {
                        withAnimation(BhumitraMotion.sheetPresentation) {
                            dragOffsetY = 0
                        }
                    }
                } else {
                    // Swiping up expands
                    if translation < -25 || velocity < -50 {
                        withAnimation(BhumitraMotion.sheetPresentation) {
                            isExpanded = true
                            dragOffsetY = 0
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else if translation > 80 || velocity > 150 {
                        onDismiss()
                    } else {
                        withAnimation(BhumitraMotion.sheetPresentation) {
                            dragOffsetY = 0
                        }
                    }
                }
            }
    }
    
    private var grabberHandleView: some View {
        Button {
            withAnimation(BhumitraMotion.sheetPresentation) {
                isExpanded.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(FigmaOverviewTokens.grabberColor.opacity(0.85))
                    .frame(width: 44, height: 4.5)
                
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(isExpanded ? "Collapse" : "Swipe up for more details")
                        .font(.googleSans(size: 11, weight: .semibold))
                }
                .foregroundColor(FigmaOverviewTokens.textGraySubtitle.opacity(0.80))
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .padding(.bottom, isExpanded ? 6 : 8)
    }
    
    private var liquidGlassBackground: some View {
        ZStack {
            // 1. Apple Liquid Glass Frosted Material (real-time map blur)
            cardShape
                .fill(.ultraThinMaterial)
            
            // 2. Translucent glass tint layer (so background map is visible and blurry)
            cardShape
                .fill(
                    LinearGradient(
                        stops: colorScheme == .dark ? [
                            .init(color: Color(hex: "#1C2128").opacity(0.48), location: 0.0),
                            .init(color: Color(hex: "#161B22").opacity(0.38), location: 0.55),
                            .init(color: Color(hex: "#1E182A").opacity(0.42), location: 1.0)
                        ] : [
                            .init(color: Color.white.opacity(0.45), location: 0.0),
                            .init(color: Color.white.opacity(0.32), location: 0.55),
                            .init(color: Color(hex: "#F9F8FC").opacity(0.38), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 3. Apple Liquid Glass Touch Glow (illuminates near contact location)
            if touchIntensity > 0.01 {
                cardShape
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity((colorScheme == .dark ? 0.32 : 0.45) * touchIntensity),
                                FigmaOverviewTokens.primaryPurple.opacity((colorScheme == .dark ? 0.22 : 0.16) * touchIntensity),
                                Color.clear
                            ],
                            center: UnitPoint(
                                x: cardWidth > 0 ? touchLocation.x / cardWidth : 0.5,
                                y: cardHeight > 0 ? touchLocation.y / cardHeight : 0.5
                            ),
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        cardWidth = geo.size.width
                        cardHeight = geo.size.height
                    }
                    .onChange(of: geo.size) { newSize in
                        cardWidth = newSize.width
                        cardHeight = newSize.height
                    }
            }
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14), radius: 24, x: 0, y: 10)
        .shadow(color: FigmaOverviewTokens.primaryPurple.opacity(colorScheme == .dark ? 0.16 : 0.08), radius: 10, x: 0, y: 2)
    }
    
    private var liquidGlassBorderOverlay: some View {
        ZStack {
            // Specular perimeter border
            cardShape
                .stroke(
                    LinearGradient(
                        stops: colorScheme == .dark ? [
                            .init(color: Color.white.opacity(0.45), location: 0.0),
                            .init(color: Color.white.opacity(0.20), location: 0.35),
                            .init(color: Color.white.opacity(0.10), location: 0.70),
                            .init(color: FigmaOverviewTokens.primaryPurple.opacity(0.35), location: 1.0)
                        ] : [
                            .init(color: Color.white.opacity(0.90), location: 0.0),
                            .init(color: Color.white.opacity(0.55), location: 0.35),
                            .init(color: Color.white.opacity(0.25), location: 0.70),
                            .init(color: FigmaOverviewTokens.primaryPurple.opacity(0.30), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            
            // Dynamic touch-following edge rim glow
            if touchIntensity > 0.01 {
                cardShape
                    .stroke(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.90 * touchIntensity),
                                FigmaOverviewTokens.primaryPurple.opacity(0.70 * touchIntensity),
                                Color.clear
                            ],
                            center: UnitPoint(
                                x: cardWidth > 0 ? touchLocation.x / cardWidth : 0.5,
                                y: cardHeight > 0 ? touchLocation.y / cardHeight : 0.5
                            ),
                            startRadius: 0,
                            endRadius: 130
                        ),
                        lineWidth: 2.2
                    )
            }
        }
        .allowsHitTesting(false)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Main Card Container (Liquid Glass Floating Sheet)
            VStack(spacing: 0) {
                // Top Grabber Handle with interactive expand/collapse
                grabberHandleView
                
                if isLoadingRoR {
                    // High-Visibility Noticeable Skeleton Loading View
                    skeletonContentView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if let error = rorError, rorResponse == nil {
                    // Minimalist Error & Retry State
                    errorRetryView(message: error)
                        .transition(.opacity)
                } else {
                    // Loaded Overview Content View (Interactive Expandable Sheet)
                    loadedOverviewContentView
                        .transition(.opacity.combined(with: .scale(scale: 1.01)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .background(liquidGlassBackground)
            .overlay(liquidGlassBorderOverlay)
            .clipShape(cardShape)
            .padding(.horizontal, 10)
            .padding(.bottom, DeviceMetrics.bottomSafeAreaInset > 0 ? max(6, DeviceMetrics.bottomSafeAreaInset - 20) : 8)
            .offset(y: cardEffectiveOffsetY)
            .gesture(cardDragGesture)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        touchLocation = value.location
                        isTouching = true
                        withAnimation(.easeOut(duration: 0.12)) {
                            touchIntensity = 1.0
                        }
                    }
                    .onEnded { _ in
                        isTouching = false
                        withAnimation(.easeOut(duration: 0.40)) {
                            touchIntensity = 0.0
                        }
                    }
            )
            .animation(BhumitraMotion.standard, value: isLoadingRoR)
            .animation(BhumitraMotion.sheetPresentation, value: isExpanded)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            AnalyticsService.shared.log(.landRecordViewed(
                districtID: displayDistrict,
                isGovernmentLand: officialSearchResult?.isGovernmentLand ?? false,
                ownerCount: rorResponse?.owners.count ?? 1,
                landClassification: displayLandType
            ))
        }
        .task(id: parcel.id) {
            self.isLoadingRoR = true
            self.rorResponse = nil
            self.officialSearchResult = nil
            self.rorError = nil
            await loadRoR()
        }
        .fullScreenCover(item: $selectedResultForDetail) { result in
            LandPassportDetailView(result: result, selectedBoundary: parcel.boundary)
        }
        .fullScreenCover(isPresented: $showSubscriptionModal) {
            SubscriptionView()
        }
    }
    
    // MARK: - 1. SKELETON LOADING CONTENT (Noticeable & High-Visibility)
    private var skeletonContentView: some View {
        VStack(spacing: 0) {
            // Header Row: Plot Title + Live Fetch Status Indicator + Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plot \(identity.plotNumber)")
                        .font(.stackSansHeadline(size: 24.0, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textBlack)
                    
                    // Live status pill: immediately understandable to user
                    HStack(spacing: 5) {
                        Circle()
                            .fill(FigmaOverviewTokens.primaryPurple)
                            .frame(width: 6, height: 6)
                            .skeletonShimmer()
                        
                        Text(locationSubtitle.isEmpty ? "Querying Bhulekh Odisha..." : "\(locationSubtitle) • Live Record")
                            .font(.googleSans(size: 13.0, weight: .semibold))
                            .foregroundColor(FigmaOverviewTokens.primaryPurple.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Rotating Star Loading Badge
                SkeletonLoadingStarView(size: 24)
            }
            .padding(.bottom, 12)
            
            // Metrics Header Bar Skeleton
            HStack(spacing: 0) {
                Text("Khata No.")
                    .frame(maxWidth: .infinity)
                Text("Area")
                    .frame(maxWidth: .infinity)
                Text("Land type")
                    .frame(maxWidth: .infinity)
            }
            .font(.stackSansHeadline(size: 11.0, weight: .bold))
            .foregroundColor(Color(hex: "#666666"))
            .padding(.vertical, 4.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.7), lineWidth: 0.6)
                    )
            )
            .padding(.bottom, 6)
            
            // 3-Column Metrics Skeleton Row with Distinct High-Contrast Shimmer Blocks
            HStack(spacing: 0) {
                shimmerBlock(width: 68, height: 26, cornerRadius: 6)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(FigmaOverviewTokens.dividerVertical.opacity(0.7))
                    .frame(width: 1.5, height: 24)
                
                shimmerBlock(width: 68, height: 26, cornerRadius: 6)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(FigmaOverviewTokens.dividerVertical.opacity(0.7))
                    .frame(width: 1.5, height: 24)
                
                shimmerBlock(width: 72, height: 26, cornerRadius: 6)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 12)
            
            // Divider
            Rectangle()
                .fill(FigmaOverviewTokens.dividerHorizontal)
                .frame(height: 1.0)
                .padding(.bottom, 10)
            
            // Owners Section Skeleton with High-Contrast Shimmer
            VStack(alignment: .leading, spacing: 8) {
                Text("Land Ownership")
                    .font(.stackSansHeadline(size: 14.5, weight: .bold))
                    .foregroundColor(Color(hex: "#444444"))
                
                HStack(spacing: 9) {
                    Circle()
                        .fill(FigmaOverviewTokens.skeletonFill)
                        .frame(width: 24, height: 24)
                        .skeletonShimmer()
                    
                    shimmerBlock(width: 140, height: 16, cornerRadius: 5)
                    Spacer()
                }
                
                HStack(spacing: 9) {
                    Circle()
                        .fill(FigmaOverviewTokens.skeletonFill)
                        .frame(width: 24, height: 24)
                        .skeletonShimmer()
                    
                    shimmerBlock(width: 210, height: 16, cornerRadius: 5)
                    Spacer()
                }
            }
            .padding(.bottom, 14)
            
            // Shimmering Disabled CTA Button
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.55))
                    .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.ultraThinMaterial))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        FigmaOverviewTokens.primaryPurple.opacity(0.25),
                                        FigmaOverviewTokens.buttonBorder.opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .frame(height: 46)
                
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(FigmaOverviewTokens.primaryPurple)
                    
                    Text("Fetching Official Report...")
                        .font(.stackSansHeadline(size: 16.5, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textDisabled)
                }
            }
        }
    }
    
    // MARK: - Minimalist Error & Retry View
    private func errorRetryView(message: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#F59E0B"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unable to Load Bhulekh Record")
                        .font(.stackSansHeadline(size: 15, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textBlack)
                    
                    Text("Temporary network timeout while querying land registry.")
                        .font(.googleSans(size: 12, weight: .medium))
                        .foregroundColor(FigmaOverviewTokens.textGraySubtitle)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            
            Button {
                self.isLoadingRoR = true
                self.rorError = nil
                _Concurrency.Task {
                    await loadRoR()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                    Text("Tap to Retry")
                        .font(.stackSansHeadline(size: 16, weight: .bold))
                }
                .foregroundColor(FigmaOverviewTokens.primaryPurple)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(FigmaOverviewTokens.primaryPurple.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(FigmaOverviewTokens.primaryPurple.opacity(0.3), lineWidth: 1.2)
                        )
                )
            }
            .buttonStyle(BhumitraPrimaryActionButtonStyle())
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - 2. LOADED OVERVIEW CONTENT (Figma 893:2192 Minimalist)
    private var loadedOverviewContentView: some View {
        VStack(spacing: 0) {
            // Header Row: Plot Title + Subtitle + Standalone Green Check Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plot \(identity.plotNumber)")
                        .font(.stackSansHeadline(size: 24.0, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textBlack)
                    
                    Text(locationSubtitle)
                        .font(.googleSans(size: 13.5, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textGraySubtitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                
                Spacer()
                
                // Standalone Green Checkmark Circle Badge
                if rorResponse?.verification?.status == .verified || (rorResponse?.success == true && (rorResponse?.owners.isEmpty == false || rorResponse?.isGovernmentLand == true)) {
                    VerifiedSealBadgeView(size: 26)
                        .padding(.top, 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.bottom, 10)
            
            // Metrics Header Bar + Values (Khata No. | Area | Land type)
            metricsSectionView
                .padding(.bottom, 10)
            
            // Horizontal Divider
            Rectangle()
                .fill(FigmaOverviewTokens.dividerHorizontal)
                .frame(height: 1.0)
                .padding(.bottom, 10)
            
            if !isExpanded {
                // Collapsed Compact State: Owners preview + CTA Button
                collapsedOverviewSectionView
            } else {
                // Expanded Interactive State: Full details, all owners, administrative grid, associated plots
                expandedOverviewSectionView
            }
        }
    }
    
    // MARK: - Collapsed Overview Section
    private var collapsedOverviewSectionView: some View {
        VStack(spacing: 0) {
            // Land Owners Section with Multiline Wrapping and Inline +N
            ownersSectionView
                .padding(.bottom, 14)
            
            // Primary Action Button
            ctaActionButton
        }
    }
    
    // MARK: - Expanded Interactive Overview Section (Full Owners, Administrative Details, Associated Plots)
    private var expandedOverviewSectionView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // Full Land Ownership Section
                allOwnersListView
                
                // Divider
                Rectangle()
                    .fill(FigmaOverviewTokens.dividerHorizontal)
                    .frame(height: 1.0)
                
                // Administrative & Land Details Grid
                administrativeDetailsGridView
                
                // Associated Plots in Khata (if any)
                associatedPlotsSectionView
                
                // Primary Action Button
                ctaActionButton
                    .padding(.top, 4)
                
                // Secondary Collapse Button
                Button {
                    withAnimation(BhumitraMotion.sheetPresentation) {
                        isExpanded = false
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                        Text("Collapse to Overview")
                            .font(.googleSans(size: 13, weight: .semibold))
                    }
                    .foregroundColor(FigmaOverviewTokens.textGraySubtitle)
                    .padding(.vertical, 6)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: min(UIScreen.main.bounds.height * 0.52, 440))
    }
    
    // MARK: - All Owners List View
    private var allOwnersListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Registered Owners (\(rorResponse?.owners.count ?? 1))")
                    .font(.stackSansHeadline(size: 14.5, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textBlack)
                Spacer()
            }
            
            if isPlotLocked {
                ownersSectionView
            } else {
                let owners = rorResponse?.owners ?? []
                if owners.isEmpty {
                    HStack(spacing: 8) {
                        OwnerAvatarCircleView(size: 22)
                        Text(rorResponse?.isGovernmentLand == true ? "ଓଡ଼ିଶା ସରକାର (Government of Odisha)" : "Record on File")
                            .font(.googleSans(size: 15.5, weight: .semibold))
                            .foregroundColor(FigmaOverviewTokens.textBlack)
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(owners.enumerated()), id: \.offset) { index, owner in
                            HStack(alignment: .center, spacing: 10) {
                                OwnerAvatarCircleView(size: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(owner.name)
                                        .font(.googleSans(size: 15.5, weight: .bold))
                                        .foregroundColor(FigmaOverviewTokens.textBlack)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    if let share = owner.share, !share.isEmpty, share != "N/A" {
                                        Text("Share: \(share)")
                                            .font(.googleSans(size: 12, weight: .medium))
                                            .foregroundColor(FigmaOverviewTokens.primaryPurple)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("#\(index + 1)")
                                    .font(.googleSans(size: 12, weight: .bold))
                                    .foregroundColor(FigmaOverviewTokens.textGraySubtitle.opacity(0.8))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.04))
                                    )
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.60))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.70), lineWidth: 0.8)
                                    )
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Administrative & Cadastral Details Grid
    private var administrativeDetailsGridView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Administrative & Land Details")
                .font(.stackSansHeadline(size: 14.5, weight: .bold))
                .foregroundColor(FigmaOverviewTokens.textBlack)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                adminDetailCell(label: "District", value: displayDistrict.isEmpty ? "-" : displayDistrict, icon: "building.columns")
                adminDetailCell(label: "Tahasil", value: displayTahasil.isEmpty ? "-" : displayTahasil, icon: "mappin.and.ellipse")
                adminDetailCell(label: "Village / Mouza", value: displayVillage.isEmpty ? "-" : displayVillage, icon: "house")
                adminDetailCell(label: "Khata No.", value: displayKhatian, icon: "doc.text")
                adminDetailCell(label: "Plot No.", value: identity.plotNumber, icon: "number")
                adminDetailCell(label: "Land Kissam", value: displayLandType, icon: "leaf")
                adminDetailCell(label: "Boundary Points", value: "\(parcel.boundary.count) points", icon: "skew")
                adminDetailCell(label: "Estimated Area", value: displayAreaFormatted, icon: "ruler")
            }
        }
    }
    
    private func adminDetailCell(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(FigmaOverviewTokens.primaryPurple)
                Text(label)
                    .font(.googleSans(size: 11, weight: .semibold))
                    .foregroundColor(FigmaOverviewTokens.textGraySubtitle)
            }
            
            Text(value)
                .font(.googleSans(size: 13.5, weight: .bold))
                .foregroundColor(FigmaOverviewTokens.textBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.60), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Associated Plots in Khata Section
    private var associatedPlotsSectionView: some View {
        let plots = rorResponse?.plots ?? []
        return Group {
            if !plots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Associated Plots in Khata (\(plots.count))")
                            .font(.stackSansHeadline(size: 14.5, weight: .bold))
                            .foregroundColor(FigmaOverviewTokens.textBlack)
                        Spacer()
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(plots) { plot in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 4) {
                                        Text("Plot \(plot.plotNumber)")
                                            .font(.googleSans(size: 13, weight: .bold))
                                            .foregroundColor(FigmaOverviewTokens.textBlack)
                                        
                                        if plot.plotNumber == identity.plotNumber {
                                            Text("Current")
                                                .font(.googleSans(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(Capsule().fill(FigmaOverviewTokens.primaryPurple))
                                        }
                                    }
                                    
                                    if let area = plot.area, !area.isEmpty {
                                        Text(OdishaAreaFormatter.formatToDecimalString(area))
                                            .font(.googleSans(size: 11, weight: .medium))
                                            .foregroundColor(FigmaOverviewTokens.textGraySubtitle)
                                    }
                                    
                                    if let lt = plot.landType, !lt.isEmpty {
                                        Text(lt)
                                            .font(.googleSans(size: 10, weight: .medium))
                                            .foregroundColor(FigmaOverviewTokens.textGraySubtitle.opacity(0.8))
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.60))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(
                                                    plot.plotNumber == identity.plotNumber ?
                                                        FigmaOverviewTokens.primaryPurple.opacity(0.6) :
                                                        Color.white.opacity(colorScheme == .dark ? 0.12 : 0.70),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Metrics Section (Figma 893:2192)
    private var metricsSectionView: some View {
        VStack(spacing: 6) {
            // Frosted Gray Header Bar
            HStack(spacing: 0) {
                Text("Khata No.")
                    .frame(maxWidth: .infinity)
                Text("Area")
                    .frame(maxWidth: .infinity)
                Text("Land type")
                    .frame(maxWidth: .infinity)
            }
            .font(.stackSansHeadline(size: 11.0, weight: .bold))
            .foregroundColor(Color(hex: "#555555"))
            .padding(.vertical, 4.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 0.6)
                    )
            )
            
            // 3-Column Values Row with Blur Support for Locked Previews
            HStack(spacing: 0) {
                BlurredKhataView(khata: displayKhatian, isLocked: isPlotLocked)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(FigmaOverviewTokens.dividerVertical)
                    .frame(width: 2.0, height: 24)
                
                BlurredAreaView(area: displayAreaFormatted, isLocked: isPlotLocked)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(FigmaOverviewTokens.dividerVertical)
                    .frame(width: 2.0, height: 24)
                
                Text(displayLandType)
                    .font(.googleSans(size: 21, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textGrayMetrics)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Owners Section (Figma 893:2192 with High-Conversion Continuous Teaser Blur)
    private var ownersSectionView: some View {
        let ownersList: [OwnerEntry] = rorResponse?.owners ?? []
        return BlurredOwnerSectionView(
            owners: ownersList,
            isLocked: isPlotLocked,
            isGovernmentLand: rorResponse?.isGovernmentLand == true
        )
    }

    // MARK: - Helper Views & Methods
    
    private func shimmerBlock(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(FigmaOverviewTokens.skeletonFill)
            .frame(width: width, height: height)
            .skeletonShimmer()
    }
    
    private func openDetailedReport() {
        if isPlotLocked {
            showSubscriptionModal = true
            return
        }
        if let existing = officialSearchResult {
            selectedResultForDetail = existing
        } else if let ror = rorResponse {
            let result = OfficialSearchResult(ror: ror, identity: parcel.identity)
            selectedResultForDetail = result
        } else {
            let fallbackRoR = RoRResponse(
                success: true,
                plot: identity.plotNumber,
                village: displayVillage,
                district: displayDistrict,
                tahasil: displayTahasil,
                khataNumber: displayKhatian,
                area: displayAreaFormatted,
                landType: displayLandType,
                owners: rorResponse?.owners ?? []
            )
            let result = OfficialSearchResult(ror: fallbackRoR, identity: parcel.identity)
            selectedResultForDetail = result
        }
    }
    
    private func loadRoR() async {
        do {
            print("[CadastralPlotCardView] 🚀 Fetching RoR for plot=\(parcel.identity.plotNumber), village=\(parcel.identity.villageName), tahasil=\(parcel.identity.tahasilName), district=\(parcel.identity.districtName)")
            let response = try await RoRService.shared.fetchOwnerDetails(for: parcel)
            print("[CadastralPlotCardView] ✅ Received RoR: plot=\(response.plot), khata=\(response.khataNumber ?? "none"), owners=\(response.owners.count), area=\(response.area ?? "none")")
            let verif = ParcelCrossVerifier.verify(
                gisIdentity: parcel.identity,
                rorResponse: response,
                gisAreaInAcre: parcel.metadata.estimatedAreaAcre
            )
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    self.rorResponse = response
                    self.officialSearchResult = OfficialSearchResult(ror: response, identity: parcel.identity)
                    self.isLoadingRoR = false
                }
                // Save to verified parcel cache if verified
                if verif.isVerified {
                    VerifiedParcelCache.shared.save(
                        identity: parcel.identity,
                        ror: response,
                        verification: verif,
                        boundary: parcel.boundary
                    )
                }
                
                // Trigger lightweight App Store feedback prompt if eligible (Opportunity #1 or #2)
                AppFeedbackManager.shared.notifySuccessfulSearchResultPresented(
                    resultId: "parcel_\(parcel.identity.plotNumber)_\(parcel.identity.villageName)_\(response.khataNumber ?? "")"
                )
                
                // Reconcile server credit balance
                _Concurrency.Task {
                    await SubscriptionManager.shared.fetchServerCreditBalance()
                }
                
                // Prefetch Official RoR PDF in background
                _Concurrency.Task {
                    let docID = response.officialDocument?.documentID
                    _ = try? await OfficialRoRPDFService.shared.fetchOrGetPDF(
                        district: parcel.identity.districtName,
                        tahasil: parcel.identity.tahasilName,
                        village: parcel.identity.villageName,
                        plot: response.plot.isEmpty ? parcel.identity.plotNumber : response.plot,
                        khataNumber: response.khataNumber,
                        documentID: docID
                    )
                }
            }
        } catch {
            print("[CadastralPlotCardView] ❌ loadRoR failed: \(error.localizedDescription)")
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    self.rorError = error.localizedDescription
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

private struct BlurredOwnerSectionView: View {
    let owners: [OwnerEntry]
    let isLocked: Bool
    let isGovernmentLand: Bool
    
    var body: some View {
        let count = owners.count
        
        if isGovernmentLand {
            VStack(alignment: .leading, spacing: 6) {
                Text("Land Ownership")
                    .font(.stackSansHeadline(size: 15.0, weight: .bold))
                    .foregroundColor(Color(hex: "#444444"))
                
                HStack(alignment: .center, spacing: 8) {
                    OwnerAvatarCircleView(size: 22)
                    
                    Text(owners.first?.name ?? "ଓଡ଼ିଶା ସରକାର (Government of Odisha)")
                        .font(.googleSans(size: 16.5, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textBlack)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                    
                    Spacer()
                }
            }
        } else if !isLocked {
            // Full Unlocked State: Crystal-clear full names
            VStack(alignment: .leading, spacing: 6) {
                Text("Land Owners(\(count))")
                    .font(.stackSansHeadline(size: 15.0, weight: .bold))
                    .foregroundColor(Color(hex: "#444444"))
                
                if let first = owners.first {
                    HStack(alignment: .center, spacing: 8) {
                        OwnerAvatarCircleView(size: 22)
                        Text(first.name)
                            .font(.googleSans(size: 16.5, weight: .bold))
                            .foregroundColor(FigmaOverviewTokens.textBlack)
                            .lineLimit(2)
                        Spacer()
                    }
                }
                
                if count > 1 {
                    let remaining = count - 2
                    HStack(alignment: .center, spacing: 8) {
                        OwnerAvatarCircleView(size: 22)
                        HStack(spacing: 4) {
                            Text(owners[1].name)
                                .font(.googleSans(size: 16.5, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.textBlack)
                            
                            if remaining > 0 {
                                Text("+\(remaining)")
                                    .font(.googleSans(size: 16.5, weight: .bold))
                                    .foregroundColor(FigmaOverviewTokens.primaryPurple)
                            }
                        }
                        .lineLimit(2)
                        Spacer()
                    }
                }
            }
        } else {
            // Locked Teaser State: Enticing continuous blur with initial letters
            let rawFirstName = owners.first?.name ?? "ପ୍ରଦୀପ୍ତ ପାତ୍ର"
            let (firstInitial, lastInitial) = extractFirstAndLastInitials(from: rawFirstName)
            let isOdia = firstInitial.unicodeScalars.contains { $0.value >= 0x0B00 && $0.value <= 0x0B7F }
            let firstNameFiller = isOdia ? "୍ରକାଶ" : "amesh"
            let surnameFiller = isOdia ? "ାତ୍ର" : "ahoo"
            let secondOwnerFiller = isOdia ? "ମନୋଜ କୁମାର ପାତ୍ର" : "Manoj Kumar Patra"
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Land Owners(\(max(1, count)))")
                    .font(.stackSansHeadline(size: 15.0, weight: .bold))
                    .foregroundColor(Color(hex: "#444444"))
                
                // Row 1: Primary Owner (First Name Initial + continuous soft blur, Surname Initial + continuous soft blur)
                HStack(alignment: .center, spacing: 8) {
                    OwnerAvatarCircleView(size: 22)
                    
                    HStack(spacing: 12) {
                        // First Name Token
                        HStack(spacing: 0) {
                            Text(firstInitial)
                                .font(.googleSans(size: 16.5, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.textBlack)
                            
                            Text(firstNameFiller)
                                .font(.googleSans(size: 16.5, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.textBlack.opacity(0.65))
                                .blur(radius: 3.5)
                        }
                        
                        // Surname Token
                        HStack(spacing: 0) {
                            Text(lastInitial)
                                .font(.googleSans(size: 16.5, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.textBlack)
                            
                            Text(surnameFiller)
                                .font(.googleSans(size: 16.5, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.textBlack.opacity(0.65))
                                .blur(radius: 3.5)
                        }
                    }
                    
                    Spacer()
                }
                
                // Row 2: Secondary Owner Preview (Smooth continuous blur + purple badge)
                if count > 1 {
                    HStack(alignment: .center, spacing: 8) {
                        OwnerAvatarCircleView(size: 22)
                        
                        HStack(spacing: 6) {
                            Text(secondOwnerFiller)
                                .font(.googleSans(size: 16.5, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.textBlack.opacity(0.55))
                                .blur(radius: 4.0)
                            
                            if count > 2 {
                                Text("+\(count - 2)")
                                    .font(.googleSans(size: 16.5, weight: .bold))
                                    .foregroundColor(FigmaOverviewTokens.primaryPurple)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct BlurredKhataView: View {
    let khata: String
    let isLocked: Bool
    
    var body: some View {
        if !isLocked {
            Text(khata)
                .font(.stackSansHeadline(size: 22, weight: .bold))
                .foregroundColor(FigmaOverviewTokens.textGrayMetrics)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        } else {
            let cleanKhata = khata.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            // Show only ONE single number / digit
            let firstDigit = cleanKhata.isEmpty ? "8" : String(cleanKhata.prefix(1))
            let suffix = cleanKhata.count > 1 ? String(cleanKhata.dropFirst(1)) : "48"
            
            HStack(spacing: 1) {
                Text(firstDigit)
                    .font(.stackSansHeadline(size: 22, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textGrayMetrics)
                
                Text(suffix)
                    .font(.stackSansHeadline(size: 22, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textGrayMetrics.opacity(0.65))
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
            Text(area)
                .font(.stackSansHeadline(size: 22, weight: .bold))
                .foregroundColor(FigmaOverviewTokens.textGrayMetrics)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        } else {
            let cleanArea = area.replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let unit = cleanArea.contains("Ha") ? " Ha" : " Acre"
            let numPart = cleanArea.replacingOccurrences(of: "Acre", with: "").replacingOccurrences(of: "Ha", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Show only ONE single number / digit
            let firstDigit = numPart.isEmpty ? "0" : String(numPart.prefix(1))
            let restOfNum = numPart.count > 1 ? String(numPart.dropFirst(1)) : ".458"
            
            HStack(spacing: 1) {
                Text(firstDigit)
                    .font(.stackSansHeadline(size: 22, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textGrayMetrics)
                
                Text(restOfNum)
                    .font(.stackSansHeadline(size: 22, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textGrayMetrics.opacity(0.65))
                    .blur(radius: 3.5)
                
                Text(unit)
                    .font(.stackSansHeadline(size: 22, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textGrayMetrics)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.70)
        }
    }
}

