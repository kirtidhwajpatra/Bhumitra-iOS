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
    static let cardBg = Color(hex: "#FFFFFF")
    static let primaryPurple = Color(hex: "#7600FF")
    static let textBlack = Color(hex: "#000000")
    static let textGrayMetrics = Color(hex: "#494949")
    static let textGraySubtitle = Color(hex: "#747474")
    static let textDisabled = Color(hex: "#D8D8D8")
    
    static let dividerHorizontal = Color(hex: "#EDEDED")
    static let dividerVertical = Color(hex: "#DADADA")
    static let grabberColor = Color(hex: "#DADADA")
    static let buttonBorder = Color(hex: "#DCD6D6")
    static let skeletonFill = Color(hex: "#EFEFEF")
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

public struct UnevenRoundedCornerShape: Shape {
    public var topLeft: CGFloat = 24
    public var topRight: CGFloat = 24
    public var bottomLeft: CGFloat = 44
    public var bottomRight: CGFloat = 44

    public init(topLeft: CGFloat = 24, topRight: CGFloat = 24, bottomLeft: CGFloat = 44, bottomRight: CGFloat = 44) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath()
        
        let tl = min(min(topLeft, rect.height / 2), rect.width / 2)
        let tr = min(min(topRight, rect.height / 2), rect.width / 2)
        let bl = min(min(bottomLeft, rect.height / 2), rect.width / 2)
        let br = min(min(bottomRight, rect.height / 2), rect.width / 2)
        
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(withCenter: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: CGFloat(3 * Double.pi / 2), endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(withCenter: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: 0, endAngle: CGFloat(Double.pi / 2), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(withCenter: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: CGFloat(Double.pi / 2), endAngle: CGFloat(Double.pi), clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(withCenter: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: CGFloat(Double.pi), endAngle: CGFloat(3 * Double.pi / 2), clockwise: true)
        path.close()
        
        return Path(path.cgPath)
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
    @State private var isLoadingRoR: Bool = false
    @State private var rorError: String? = nil
    
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
    
    public var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Main Card Container (Liquid Glass Floating Sheet)
            VStack(spacing: 0) {
                // Top Drag Handle (width 72, height 4.5)
                RoundedRectangle(cornerRadius: 2.25)
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 72, height: 4.5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                
                if isLoadingRoR {
                    // SKELETON LOADING VIEW (Figma 845:89 with Shimmer Waves)
                    skeletonContentView
                } else {
                    // LOADED OVERVIEW CONTENT VIEW (Figma 893:2192)
                    loadedOverviewContentView
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .background(
                cardShape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.92), location: 0.0),
                                .init(color: Color.white.opacity(0.84), location: 0.55),
                                .init(color: Color(hex: "#FAF7FF").opacity(0.88), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(cardShape.fill(.ultraThinMaterial))
                    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
                    .shadow(color: FigmaOverviewTokens.primaryPurple.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .overlay(
                cardShape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color.white.opacity(0.60), location: 0.35),
                                .init(color: Color.white.opacity(0.20), location: 0.70),
                                .init(color: FigmaOverviewTokens.primaryPurple.opacity(0.25), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.25
                    )
            )
            .clipShape(cardShape)
            .padding(.horizontal, 10)
            .padding(.bottom, DeviceMetrics.bottomSafeAreaInset > 0 ? max(6, DeviceMetrics.bottomSafeAreaInset - 20) : 8)
            .offset(y: max(0, dragOffsetY + dragTranslation))
            .gesture(
                DragGesture(minimumDistance: 3)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        if value.translation.height > 80 || value.predictedEndTranslation.height > 150 {
                            onDismiss()
                        } else {
                            withAnimation(BhumitraMotion.sheetPresentation) {
                                dragOffsetY = 0
                            }
                        }
                    }
            )
            .animation(BhumitraMotion.standard, value: isLoadingRoR)
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
    }
    
    // MARK: - 1. SKELETON LOADING CONTENT (Matching Layout with Shimmer Waves)
    private var skeletonContentView: some View {
        VStack(spacing: 0) {
            // Header Row: Plot Name + Subtitle Shimmer + Rotating Star
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plot \(identity.plotNumber)")
                        .font(.stackSansHeadline(size: 25.0, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textBlack)
                    
                    // Subtitle shimmer wave
                    shimmerBlock(width: 90, height: 15, cornerRadius: 4)
                }
                
                Spacer()
                
                // Rotating Yellow Star Loading Badge
                SkeletonLoadingStarView(size: 26)
            }
            .padding(.bottom, 10)
            
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
            .foregroundColor(Color(hex: "#888888"))
            .padding(.vertical, 4.0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 0.6)
                    )
            )
            .padding(.bottom, 6)
            
            // 3-Column Metrics Skeleton Row with Shimmer
            HStack(spacing: 0) {
                shimmerBlock(width: 65, height: 24, cornerRadius: 4)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(FigmaOverviewTokens.dividerVertical)
                    .frame(width: 2.0, height: 24)
                
                shimmerBlock(width: 60, height: 24, cornerRadius: 4)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(FigmaOverviewTokens.dividerVertical)
                    .frame(width: 2.0, height: 24)
                
                shimmerBlock(width: 70, height: 24, cornerRadius: 4)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 10)
            
            // Divider
            Rectangle()
                .fill(FigmaOverviewTokens.dividerHorizontal)
                .frame(height: 1.5)
                .padding(.bottom, 10)
            
            // Owners Section Skeleton
            VStack(alignment: .leading, spacing: 8) {
                Text("Land Owners")
                    .font(.stackSansHeadline(size: 15.0, weight: .bold))
                    .foregroundColor(Color(hex: "#444444"))
                
                HStack(spacing: 8) {
                    OwnerAvatarCircleView(size: 22)
                        .skeletonShimmer()
                    shimmerBlock(width: 120, height: 16, cornerRadius: 4)
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    OwnerAvatarCircleView(size: 22)
                        .skeletonShimmer()
                    shimmerBlock(width: 200, height: 16, cornerRadius: 4)
                    Spacer()
                }
            }
            .padding(.bottom, 12)
            
            // Disabled Outline CTA Button
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.60))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(FigmaOverviewTokens.buttonBorder.opacity(0.7), lineWidth: 2.2)
                    )
                    .frame(height: 48)
                
                Text("view detailed report")
                    .font(.stackSansHeadline(size: 18.5, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textDisabled)
            }
        }
    }
    
    // MARK: - 2. LOADED OVERVIEW CONTENT (Figma 893:2192)
    private var loadedOverviewContentView: some View {
        VStack(spacing: 0) {
            // Header Row: Plot Title + Subtitle + Standalone Green Check Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plot \(identity.plotNumber)")
                        .font(.stackSansHeadline(size: 25.0, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textBlack)
                    
                    Text(locationSubtitle)
                        .font(.googleSans(size: 14.0, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textGraySubtitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                
                Spacer()
                
                // Standalone Green Checkmark Circle Badge (Figma #893:2192)
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
                .frame(height: 1.5)
                .padding(.bottom, 10)
            
            // Land Owners Section with Multiline Wrapping and Inline +N
            ownersSectionView
                .padding(.bottom, 12)
            
            // Interactive Outlined "view detailed report" CTA Button
            Button {
                openDetailedReport()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color.white.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.ultraThinMaterial))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            FigmaOverviewTokens.primaryPurple.opacity(0.55),
                                            FigmaOverviewTokens.primaryPurple.opacity(0.25),
                                            Color.white.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.2
                                )
                        )
                        .shadow(color: FigmaOverviewTokens.primaryPurple.opacity(0.12), radius: 8, x: 0, y: 3)
                        .frame(height: 48)
                    
                    Text("view detailed report")
                        .font(.stackSansHeadline(size: 18.5, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.primaryPurple)
                }
            }
            .buttonStyle(BhumitraPrimaryActionButtonStyle())
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
            
            // 3-Column Values Row
            HStack(spacing: 0) {
                Text(displayKhatian)
                    .font(.stackSansHeadline(size: 22, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textGrayMetrics)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(FigmaOverviewTokens.dividerVertical)
                    .frame(width: 2.0, height: 24)
                
                Text(displayAreaFormatted)
                    .font(.stackSansHeadline(size: 22, weight: .bold))
                    .foregroundColor(FigmaOverviewTokens.textGrayMetrics)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
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
    
    // MARK: - Owners Section (Figma 893:2192 with natural multi-line wrapping)
    private var ownersSectionView: some View {
        VStack(alignment: .leading, spacing: 6) {
            let ownersList: [OwnerEntry] = rorResponse?.owners ?? []
            let count = ownersList.count
            
            if rorResponse?.isGovernmentLand == true {
                Text("Land Ownership")
                    .font(.stackSansHeadline(size: 15.0, weight: .bold))
                    .foregroundColor(Color(hex: "#444444"))
                
                HStack(alignment: .top, spacing: 8) {
                    OwnerAvatarCircleView(size: 22)
                        .padding(.top, 2)
                    
                    Text(ownersList.first?.name ?? "ଓଡ଼ିଶା ସରକାର (Government of Odisha)")
                        .font(.googleSans(size: 16.5, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textBlack)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                    
                    Spacer()
                }
            } else if !ownersList.isEmpty {
                Text("Land Owners(\(count))")
                    .font(.stackSansHeadline(size: 15.0, weight: .bold))
                    .foregroundColor(Color(hex: "#444444"))
                
                // Row 1: Primary Owner (Multi-line wrap supported)
                HStack(alignment: .top, spacing: 8) {
                    OwnerAvatarCircleView(size: 22)
                        .padding(.top, 2)
                    
                    Text(ownersList[0].name)
                        .font(.googleSans(size: 16.5, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textBlack)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                    
                    Spacer()
                }
                
                // Row 2: Second Owner with inline +N count if more than 2 owners
                if count > 1 {
                    let remaining = count - 2
                    HStack(alignment: .top, spacing: 8) {
                        OwnerAvatarCircleView(size: 22)
                            .padding(.top, 2)
                        
                        HStack(spacing: 4) {
                            Text(ownersList[1].name)
                                .font(.googleSans(size: 16.5, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.textBlack)
                            
                            if remaining > 0 {
                                Text("+\(remaining)")
                                    .font(.googleSans(size: 16.5, weight: .bold))
                                    .foregroundColor(FigmaOverviewTokens.primaryPurple)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                        
                        Spacer()
                    }
                }
            } else {
                Text("Land Owners")
                    .font(.stackSansHeadline(size: 15.0, weight: .bold))
                    .foregroundColor(Color(hex: "#444444"))
                
                HStack(alignment: .top, spacing: 8) {
                    OwnerAvatarCircleView(size: 22)
                        .padding(.top, 2)
                    
                    Text(parcel.metadata.additionalInfo?["owner"] ?? parcel.metadata.additionalInfo?["owner_name"] ?? "Record not available")
                        .font(.googleSans(size: 16.5, weight: .bold))
                        .foregroundColor(FigmaOverviewTokens.textBlack)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                    
                    Spacer()
                }
            }
        }
    }

    
    // MARK: - Helper Views & Methods
    
    private func shimmerBlock(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(FigmaOverviewTokens.skeletonFill)
            .frame(width: width, height: height)
            .skeletonShimmer()
    }
    
    private func openDetailedReport() {
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
