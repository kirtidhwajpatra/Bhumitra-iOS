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
                // Top Grabber Handle
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(FigmaOverviewTokens.grabberColor.opacity(0.85))
                    .frame(width: 44, height: 4.5)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                if isLoadingRoR {
                    // High-Visibility Noticeable Skeleton Loading View
                    skeletonContentView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if let error = rorError, rorResponse == nil {
                    // Minimalist Error & Retry State
                    errorRetryView(message: error)
                        .transition(.opacity)
                } else {
                    // Loaded Overview Content View
                    loadedOverviewContentView
                        .transition(.opacity.combined(with: .scale(scale: 1.01)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .background(
                cardShape
                    .fill(
                        LinearGradient(
                            stops: colorScheme == .dark ? [
                                .init(color: Color(hex: "#1C2128").opacity(0.96), location: 0.0),
                                .init(color: Color(hex: "#161B22").opacity(0.92), location: 0.55),
                                .init(color: Color(hex: "#1E182A").opacity(0.94), location: 1.0)
                            ] : [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color.white.opacity(0.90), location: 0.55),
                                .init(color: Color(hex: "#F9F8FC").opacity(0.92), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(cardShape.fill(.ultraThinMaterial))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14), radius: 24, x: 0, y: 10)
                    .shadow(color: FigmaOverviewTokens.primaryPurple.opacity(colorScheme == .dark ? 0.16 : 0.08), radius: 10, x: 0, y: 2)
            )
            .overlay(
                cardShape
                    .stroke(
                        LinearGradient(
                            stops: colorScheme == .dark ? [
                                .init(color: Color.white.opacity(0.35), location: 0.0),
                                .init(color: Color.white.opacity(0.15), location: 0.35),
                                .init(color: Color.white.opacity(0.08), location: 0.70),
                                .init(color: FigmaOverviewTokens.primaryPurple.opacity(0.35), location: 1.0)
                            ] : [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color.white.opacity(0.60), location: 0.35),
                                .init(color: Color.white.opacity(0.25), location: 0.70),
                                .init(color: FigmaOverviewTokens.primaryPurple.opacity(0.20), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
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
                
                // Rotating Star Loading Badge with soft glow
                ZStack {
                    Circle()
                        .fill(FigmaOverviewTokens.primaryPurple.opacity(0.08))
                        .frame(width: 32, height: 32)
                    
                    SkeletonLoadingStarView(size: 24)
                }
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
            
            // Land Owners Section with Multiline Wrapping and Inline +N
            ownersSectionView
                .padding(.bottom, 14)
            
            // Interactive Outlined CTA Button (View Detailed Report or Unlock Full Plot Details)
            Button {
                openDetailedReport()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color.white.opacity(0.88)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.ultraThinMaterial))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            FigmaOverviewTokens.primaryPurple.opacity(0.65),
                                            FigmaOverviewTokens.primaryPurple.opacity(0.30),
                                            Color.white.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.0
                                )
                        )
                        .shadow(color: FigmaOverviewTokens.primaryPurple.opacity(0.14), radius: 8, x: 0, y: 3)
                        .frame(height: 48)
                    
                    if isPlotLocked {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.primaryPurple)
                            
                            Text("Unlock Full Plot Details")
                                .font(.stackSansHeadline(size: 17.5, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.primaryPurple)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text("View Detailed Report")
                                .font(.stackSansHeadline(size: 17.5, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.primaryPurple)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(FigmaOverviewTokens.primaryPurple)
                        }
                    }
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

