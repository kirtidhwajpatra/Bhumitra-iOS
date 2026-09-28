import SwiftUI

/// Clean, map-first floating controls overlay for MyBhoomi home screen.
public struct MapHomeOverlay: View {
    @ObservedObject public var viewModel: MapViewModel
    @Binding public var showVillagePicker: Bool
    @Binding public var showQuickFeatures: Bool
    @Binding public var showOfficialLandRecords: Bool
    @Binding public var showLandAreaConverter: Bool
    @Binding public var showSubscription: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var explorerVM = GISExplorerViewModel.shared
    @ObservedObject private var locationSearchService = LocationSearchService.shared
    @ObservedObject private var recentStore = RecentLocationSearchStore.shared
    
    @State private var isSearchSheetPresented: Bool = false
    @State private var quickFeaturesBounce = false
    @State private var premiumBounce = false
    @State private var showCreditBalanceSheet: Bool = false
    @State private var creditSheetWantsSubscription: Bool = false
    
    private var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    public init(
        viewModel: MapViewModel,
        showVillagePicker: Binding<Bool>,
        showQuickFeatures: Binding<Bool>,
        showOfficialLandRecords: Binding<Bool>,
        showLandAreaConverter: Binding<Bool> = .constant(false),
        showSubscription: Binding<Bool> = .constant(false)
    ) {
        self.viewModel = viewModel
        self._showVillagePicker = showVillagePicker
        self._showQuickFeatures = showQuickFeatures
        self._showOfficialLandRecords = showOfficialLandRecords
        self._showLandAreaConverter = showLandAreaConverter
        self._showSubscription = showSubscription
    }
    
    private var topBarIconColor: Color {
        Theme.Color.bhumitraPrimaryText
    }

    /// Live satellite imagery must not determine the light-mode control surface.
    private var mapControlGlassTint: Color {
        Theme.Color.bhumitraMapSurface
    }
    
    private var bottomControlsPadding: CGFloat {
        if explorerVM.isExplorerActive {
            return explorerVM.hasBottomCard ? 360 : 28
        } else {
            return 28
        }
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Dismiss keyboard and search dropdown when tapping outside
            if viewModel.isSearchFocused {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.isSearchFocused = false
                        viewModel.dismissSearchOnMapInteraction()
                    }
            }
            
            VStack(spacing: 0) {
                // 0. Edge-to-edge connectivity strip at the absolute top
                //    (fills the status-bar area; controls slide down under it).
                NetworkStatusBannerView()

                // 1. TOP: control row, then ONE status stack (credits,
                //    location/plot progress) — all shared notice style.
                VStack(alignment: .leading, spacing: MapChrome.spacing) {
                    if !explorerVM.isExplorerActive {
                        HStack(spacing: MapChrome.spacing) {
                            // Tapping the location pill opens village search; the
                            // District → Tahasil → Village picker stays reachable
                            // from search via "Browse by district".
                            LiquidGlassLocationSelector(mapViewModel: viewModel, style: .compact) {
                                isSearchSheetPresented = true
                            }
                            
                            Spacer(minLength: MapChrome.spacing)
                            
                            // Credits + account grouped in a single capsule
                            MapAccountCapsule(
                                credits: subscriptionManager.remainingPlotCredits,
                                isUnlimited: subscriptionManager.isUnlimited,
                                isCoverPresented: showSubscription,
                                onCreditsTap: { showCreditBalanceSheet = true },
                                onProfileTap: { showQuickFeatures = true }
                            )
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
                    }
                        
                    if !explorerVM.isExplorerActive,
                       viewModel.selectedParcel == nil && viewModel.selectedLocationInfo == nil {
                        CreditNotificationBannerView {
                            showSubscription = true
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        
                        SpatialResolutionStatusPill(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: explorerVM.isExplorerActive)
                
                Spacer()
                
                // 2. BOTTOM FLOATING CONTROLS (Eye Parcels & GPS Location Pill)
                // When a parcel is selected, the 2-button pill is smoothly handled directly by CadastralPlotCardView above the sheet.
                if viewModel.selectedParcel == nil {
                    HStack {
                        Spacer()
                        LiquidGlassMapControlsCapsule(viewModel: viewModel)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, bottomControlsPadding)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .animation(Theme.Animation.spring, value: viewModel.selectedParcel == nil)
        }
        .onChange(of: viewModel.isSearchFocused) { _, focused in
            if focused {
                if viewModel.searchQuery.isEmpty && !recentStore.recents.isEmpty {
                    recentStore.loadRecents()
                }
            }
        }
        .sheet(isPresented: $isSearchSheetPresented) {
            LocationSearchNativeSheet(
                viewModel: viewModel,
                locationSearchService: locationSearchService,
                recentStore: recentStore,
                isDarkMode: isDarkMode,
                onSelect: { result, isRecent in
                    handleSuggestionSelected(result, isRecent: isRecent)
                },
                onOpenManualSelector: {
                    // Let the search sheet finish dismissing before the picker
                    // sheet presents, or SwiftUI drops the second presentation.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        viewModel.openManualLocationSelector()
                    }
                },
                onOpenProfile: {
                    showQuickFeatures = true
                }
            )
        }
        .sheet(isPresented: $showCreditBalanceSheet, onDismiss: {
            if creditSheetWantsSubscription {
                creditSheetWantsSubscription = false
                showSubscription = true
            }
        }) {
            PlotCreditBalanceSheet {
                Theme.haptic(.light)
                creditSheetWantsSubscription = true
                showCreditBalanceSheet = false
            }
            .onAppear {
                AnalyticsService.shared.log(.paywallViewed(
                    trigger: .manualOpen,
                    remainingCreditBucket: AnalyticsCreditBucket.bucket(
                        for: subscriptionManager.remainingPlotCredits,
                        isUnlimited: subscriptionManager.isUnlimited
                    )
                ))
            }
        }
    }
    
    // MARK: - Search Bar & Native Search Presentation
    
    private var mapSearchBarView: some View {
        BhumitraLiquidGlassSearchBar(
            viewModel: viewModel,
            text: $viewModel.searchQuery,
            isFocusedBinding: $viewModel.isSearchFocused,
            onOpenProfile: {
                showQuickFeatures = true
            },
            onCommit: {
                handleMapSearchCommit()
            }
        )
    }
    
    @ViewBuilder
    private var mapSearchDropdownView: some View {
        Group {
            if locationSearchService.isSearching && locationSearchService.searchResults.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.Color.bhumitraPrimary)
                    Text("Searching Odisha locations...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraTextMuted)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            } else if !locationSearchService.searchResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(locationSearchService.searchResults) { result in
                            Button {
                                handleSuggestionSelected(result, isRecent: false)
                            } label: {
                                LocationSuggestionRow(result: result)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .padding(.leading, result.id != locationSearchService.searchResults.last?.id ? 62 : 0)
                        }
                        BrowseByDistrictRow {
                            viewModel.isSearchFocused = false
                            viewModel.openManualLocationSelector()
                        }
                    }
                }
                .frame(maxHeight: min(CGFloat(locationSearchService.searchResults.count) * 56 + 56, 360))
            } else if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !locationSearchService.isSearching {
                SearchEmptyStateCard(query: viewModel.searchQuery) {
                    viewModel.isSearchFocused = false
                    viewModel.openManualLocationSelector()
                }
            } else if viewModel.isSearchFocused && viewModel.searchQuery.isEmpty && !recentStore.recents.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Recent Searches")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Color.secondaryText)
                        Spacer()
                        Button("Clear") {
                            recentStore.clearAll()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(recentStore.recents) { recent in
                                Button {
                                    handleSuggestionSelected(recent, isRecent: true)
                                } label: {
                                    LocationSuggestionRow(result: recent, isRecent: true)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                
                                if recent.id != recentStore.recents.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: min(CGFloat(recentStore.recents.count) * 54 + 10, 280))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Color.bhumitraCardFillElevated)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.Color.bhumitraCardStroke, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(isDarkMode ? 0.32 : 0.10), radius: 12, x: 0, y: 5)
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
    }
    
    private func handleSuggestionSelected(_ result: LocationSearchResult, isRecent: Bool = false) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isSearchSheetPresented = false
        if viewModel.isSearchFocused { viewModel.isSearchFocused = false }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        viewModel.currentFlow = isRecent ? "RECENT" : "LIVE"
        locationSearchService.clearSearch()
        if !viewModel.searchQuery.isEmpty { viewModel.searchQuery = "" }
        
        // Start the map work after the sheet's dismiss animation has begun, so the
        // camera move and plot download don't compete with it for the same frames.
        _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(nanoseconds: 120_000_000)
            // Direct villages position the camera from their real extent once loaded;
            // their lat/lon is only an approximate tahasil centre, so don't pre-zoom there.
            if result.directCadastralVillage == nil, let lat = result.latitude, let lon = result.longitude {
                viewModel.moveCamera(to: Coordinate(latitude: lat, longitude: lon), zoom: result.type.recommendedZoomLevel)
            }
            try? await viewModel.selectLocation(result, isRecent: isRecent)
        }
    }
    
    private func handleMapSearchCommit() {
        if let first = locationSearchService.searchResults.first {
            handleSuggestionSelected(first)
        } else {
            viewModel.searchLocation()
        }
    }
}

// MARK: - Plot Search Credit Pill View & SVG Flame Icon

public struct FlameIconShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 15.5684
        let sy = rect.height / 22.4258
        
        var path = Path()
        path.move(to: CGPoint(x: 13.7891 * sx, y: 10.5838 * sy))
        path.addCurve(
            to: CGPoint(x: 11.7754 * sx, y: 8.06724 * sy),
            control1: CGPoint(x: 13.1699 * sx, y: 9.70298 * sy),
            control2: CGPoint(x: 12.459 * sx, y: 8.86893 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.3379 * sx, y: 6.31646 * sy),
            control1: CGPoint(x: 11.2656 * sx, y: 7.47047 * sy),
            control2: CGPoint(x: 10.7695 * sx, y: 6.88807 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.07812 * sx, y: 4.10193 * sy),
            control1: CGPoint(x: 9.76758 * sx, y: 5.5651 * sy),
            control2: CGPoint(x: 9.31055 * sx, y: 4.83172 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.07812 * sx, y: 0.0 * sy),
            control1: CGPoint(x: 8.56641 * sx, y: 2.50933 * sy),
            control2: CGPoint(x: 8.91992 * sx, y: 0.722601 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.84375 * sx, y: 3.74961 * sy),
            control1: CGPoint(x: 7.99805 * sx, y: 0.744171 * sy),
            control2: CGPoint(x: 7.26172 * sx, y: 2.22532 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.45312 * sx, y: 7.27634 * sy),
            control1: CGPoint(x: 6.49414 * sx, y: 5.02944 * sy),
            control2: CGPoint(x: 6.36914 * sx, y: 6.34163 * sy)
        )
        path.addLine(to: CGPoint(x: 6.52344 * sx, y: 8.04208 * sy))
        path.addCurve(
            to: CGPoint(x: 6.59766 * sx, y: 10.7024 * sy),
            control1: CGPoint(x: 6.60547 * sx, y: 8.95162 * sy),
            control2: CGPoint(x: 6.67969 * sx, y: 9.92228 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.56836 * sx, y: 12.259 * sy),
            control1: CGPoint(x: 6.50781 * sx, y: 11.5616 * sy),
            control2: CGPoint(x: 6.22852 * sx, y: 12.1907 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.47266 * sx, y: 12.0757 * sy),
            control1: CGPoint(x: 5.14648 * sx, y: 12.3022 * sy),
            control2: CGPoint(x: 4.78711 * sx, y: 12.2303 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.29688 * sx, y: 10.9217 * sy),
            control1: CGPoint(x: 3.99023 * sx, y: 11.842 * sy),
            control2: CGPoint(x: 3.61719 * sx, y: 11.4142 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 2.64258 * sx, y: 9.75331 * sy),
            control1: CGPoint(x: 3.05664 * sx, y: 10.5514 * sy),
            control2: CGPoint(x: 2.8457 * sx, y: 10.1452 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 0.00195312 * sx, y: 15.02 * sy),
            control1: CGPoint(x: 1.06445 * sx, y: 11.0475 * sy),
            control2: CGPoint(x: 0.0527344 * sx, y: 12.9241 * sy)
        )
        path.addLine(to: CGPoint(x: 0.0 * sx, y: 15.2573 * sy))
        path.addCurve(
            to: CGPoint(x: 7.78516 * sx, y: 22.4258 * sy),
            control1: CGPoint(x: 0.0390625 * sx, y: 19.2226 * sy),
            control2: CGPoint(x: 3.50977 * sx, y: 22.4258 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 15.5684 * sx, y: 15.2825 * sy),
            control1: CGPoint(x: 12.0508 * sx, y: 22.4258 * sy),
            control2: CGPoint(x: 15.5137 * sx, y: 19.237 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.9238 * sx, y: 12.5251 * sy),
            control1: CGPoint(x: 15.5586 * sx, y: 14.3082 * sy),
            control2: CGPoint(x: 15.3145 * sx, y: 13.3915 * sy)
        )
        path.addLine(to: CGPoint(x: 14.8965 * sx, y: 12.4676 * sy))
        path.addCurve(
            to: CGPoint(x: 13.7891 * sx, y: 10.5838 * sy),
            control1: CGPoint(x: 14.5977 * sx, y: 11.8205 * sy),
            control2: CGPoint(x: 14.2109 * sx, y: 11.1841 * sy)
        )
        path.closeSubpath()
        return path
    }
}

public struct FlameIconView: View {
    public var width: CGFloat
    public var height: CGFloat
    public var isPressed: Bool
    
    @State private var isAnimatingHeat: Bool = false
    @State private var heatWaveProgress: CGFloat = 0.0
    @State private var flameGlowOpacity: CGFloat = 0.0
    
    public init(width: CGFloat = 14, height: CGFloat = 20, isPressed: Bool = false) {
        self.width = width
        self.height = height
        self.isPressed = isPressed
    }
    
    public var body: some View {
        ZStack {
            // 1. Ambient Warm Ember Glow (visible during landing animation and on touch)
            FlameIconShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 192/255, green: 132/255, blue: 252/255),
                            Color(red: 116/255, green: 18/255, blue: 250/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: isPressed ? 4.0 : 2.5)
                .opacity(isPressed ? 0.80 : (isAnimatingHeat ? flameGlowOpacity : 0.0))
                .scaleEffect(isPressed ? 1.14 : (isAnimatingHeat ? 1.04 : 1.0))
            
            // 2. Base Vector Flame Body (Purple / Violet Gradient)
            FlameIconShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 168/255, green: 85/255, blue: 247/255), // Top: #A855F7
                            Color(red: 106/255, green: 13/255, blue: 173/255)  // Bottom: #6A0DAD / Electric Violet
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // 3. Ascending Heat Shimmer Wave (Heat tongues rising upward through the flame body)
            FlameIconShape()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color(red: 233/255, green: 213/255, blue: 255/255).opacity(isPressed ? 0.95 : 0.70), location: 0.40),
                            .init(color: Color(red: 192/255, green: 132/255, blue: 252/255).opacity(isPressed ? 0.85 : 0.50), location: 0.65),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .init(x: 0.5, y: 1.2 - heatWaveProgress * 1.8),
                        endPoint: .init(x: 0.5, y: 1.8 - heatWaveProgress * 1.8)
                    )
                )
                .opacity((isAnimatingHeat || isPressed) ? 1.0 : 0.0)
                .blendMode(.screen)
        }
        .frame(width: width, height: height)
        .scaleEffect(isPressed ? 1.12 : 1.0, anchor: .bottom)
        .animation(.spring(response: 0.28, dampingFraction: 0.60), value: isPressed)
        .onAppear {
            startAppearanceAnimation()
        }
    }
    
    private func startAppearanceAnimation() {
        isAnimatingHeat = true
        
        // Rising heat shimmer wave
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
            heatWaveProgress = 1.0
        }
        
        // Gentle glow pulse
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
            flameGlowOpacity = 0.50
        }
        
        // Stop animation after 4 seconds and return to static rest
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimatingHeat = false
                flameGlowOpacity = 0.0
            }
        }
    }
}

public struct PlotSearchCreditPillView: View {
    public var credits: Int
    public var isUnlimited: Bool
    public var isPressed: Bool
    public var isCoverPresented: Bool
    /// When true the pill draws no glass/shadow of its own, so a parent
    /// capsule (e.g. `MapAccountCapsule`) can own the surface.
    public var embedded: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var displayedCredits: Int = 0
    @State private var pendingTargetCredits: Int? = nil
    @State private var dropletBounceScale: CGFloat = 1.0
    @State private var celebratoryScale: CGFloat = 1.0
    @State private var shineOffset: CGFloat = -2.0
    @State private var isReflecting: Bool = false
    @State private var pulseFlame: Bool = false
    @State private var countTask: _Concurrency.Task<Void, Never>? = nil
    @State private var hasInitialized: Bool = false
    
    public init(
        credits: Int,
        isUnlimited: Bool = false,
        isPressed: Bool = false,
        isCoverPresented: Bool = false,
        embedded: Bool = false
    ) {
        self.credits = credits
        self.isUnlimited = isUnlimited
        self.isPressed = isPressed
        self.isCoverPresented = isCoverPresented
        self.embedded = embedded
    }
    
    private var pillContent: some View {
        HStack(spacing: embedded ? 5 : 4) {
            FlameIconView(
                width: embedded ? 12 : 14,
                height: embedded ? 16 : 19,
                isPressed: isPressed || pulseFlame
            )
            
            if isUnlimited {
                Text("Plus")
                    .font(.stackSansHeadline(size: embedded ? 14 : 14.5, weight: embedded ? .semibold : .bold))
                    .foregroundColor(embedded ? Theme.Color.bhumitraPrimaryText : Theme.Color.bhumitraPrimary)
            } else {
                Text("\(displayedCredits)")
                    .font(.stackSansHeadline(size: embedded ? 15 : 16.5, weight: embedded ? .semibold : .bold))
                    .monospacedDigit()
                    // Persistent, quiet low-balance signal: the count itself
                    // turns amber at 2 or fewer (no banner needed).
                    .foregroundColor(displayedCredits <= 2 ? Theme.Color.bhumitraWarning : Theme.Color.bhumitraPrimaryText)
                    .contentTransition(.numericText(countsDown: false))
            }
        }
        .padding(.horizontal, embedded ? 12 : (isUnlimited ? 9 : 10))
        .frame(height: embedded ? MapChrome.controlHeight : 38)
        .contentShape(Capsule())
    }
    
    public var body: some View {
        Group {
            if embedded {
                pillContent
            } else {
                pillContent.glassEffect(
                    .regular.tint(Theme.Color.bhumitraMapSurface).interactive(),
                    in: .capsule
                )
            }
        }
        .overlay(
            Group {
                // Specular Light / Glass Reflection Beam on Successful Credit Top-Up
                if isReflecting {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.85), location: 0.45),
                            .init(color: Color(red: 255/255, green: 220/255, blue: 110/255).opacity(0.65), location: 0.55),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .offset(x: shineOffset * 50)
                }
            }
        )
        .shadow(
            color: isReflecting
                ? Color(red: 168/255, green: 85/255, blue: 247/255).opacity(0.50)
                : (embedded ? .clear : Color.black.opacity(colorScheme == .dark ? 0.30 : 0.10)),
            radius: isReflecting ? 10 : (isPressed ? 3 : 6),
            x: 0,
            y: isPressed ? 1 : 2
        )
        .scaleEffect(dropletBounceScale * celebratoryScale)
        .onAppear {
            if !hasInitialized {
                displayedCredits = credits
                hasInitialized = true
            } else if let pending = pendingTargetCredits, !isCoverPresented {
                pendingTargetCredits = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    animateCreditChange(from: displayedCredits, to: pending)
                }
            } else if credits > displayedCredits && !isCoverPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    animateCreditChange(from: displayedCredits, to: credits)
                }
            }
        }
        .onChange(of: credits) { newTarget in
            guard hasInitialized else {
                displayedCredits = newTarget
                return
            }
            if isCoverPresented {
                // Hold animation while payment modal is actively showing over map
                pendingTargetCredits = newTarget
            } else {
                animateCreditChange(from: displayedCredits, to: newTarget)
            }
        }
        .onChange(of: isCoverPresented) { isPresented in
            if !isPresented {
                // Payment modal just dismissed - trigger immediate top-up animation on map screen
                let target = pendingTargetCredits ?? credits
                pendingTargetCredits = nil
                if target > displayedCredits {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        animateCreditChange(from: displayedCredits, to: target)
                    }
                }
            }
        }
    }
    
    private func animateCreditChange(from start: Int, to target: Int) {
        countTask?.cancel()
        
        guard target != start else { return }
        
        // If credits decrease (e.g. 1 search used), quick simple transition
        if target < start {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) {
                displayedCredits = target
                dropletBounceScale = 0.96
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.60)) {
                    dropletBounceScale = 1.0
                }
            }
            return
        }
        
        // If credits increase (Purchase / addition e.g. 20 -> 30)
        let totalDelta = target - start
        
        countTask = _Concurrency.Task { @MainActor in
            for step in 1...totalDelta {
                if _Concurrency.Task.isCancelled { break }
                
                let currentNumber = start + step
                let progress = Double(step) / Double(totalDelta)
                
                // Non-linear S-Curve timing: starts gradual, streams fast in middle, eases out at finish
                let delaySeconds: Double
                if totalDelta <= 3 {
                    delaySeconds = 0.14
                } else {
                    if progress < 0.25 {
                        // Slow start: 21, 22
                        delaySeconds = 0.15 - (progress * 0.22)
                    } else if progress < 0.78 {
                        // Fast stream: 23, 24, 25, 26, 27
                        delaySeconds = 0.042
                    } else if progress < 0.96 {
                        // Slow down: 28, 29
                        delaySeconds = 0.10 + ((progress - 0.78) * 0.32)
                    } else {
                        // Final landing step: 30
                        delaySeconds = 0.17
                    }
                }
                
                try? await _Concurrency.Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                if _Concurrency.Task.isCancelled { break }
                
                displayedCredits = currentNumber
                
                withAnimation(.spring(response: 0.10, dampingFraction: 0.40)) {
                    dropletBounceScale = 1.055
                    pulseFlame = true
                }
                
                try? await _Concurrency.Task.sleep(nanoseconds: 60_000_000)
                withAnimation(.spring(response: 0.14, dampingFraction: 0.65)) {
                    dropletBounceScale = 1.0
                    pulseFlame = false
                }
            }
            
            // Final celebration when reaching the target number (e.g. 30):
            if !_Concurrency.Task.isCancelled {
                triggerSuccessCelebration()
            }
        }
    }
    
    private func triggerSuccessCelebration() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // 1. Success Pill Pop
        withAnimation(.spring(response: 0.36, dampingFraction: 0.52)) {
            celebratoryScale = 1.14
        }
        
        // 2. Success Specular Reflection Beam sweep
        shineOffset = -2.0
        isReflecting = true
        
        withAnimation(.easeInOut(duration: 0.72)) {
            shineOffset = 2.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.65)) {
                celebratoryScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {
            isReflecting = false
            shineOffset = -2.0
        }
    }
}

public struct PlotSearchCreditButton: View {
    public var credits: Int
    public var isUnlimited: Bool
    public var isCoverPresented: Bool
    public var embedded: Bool
    public var action: () -> Void
    
    public init(
        credits: Int,
        isUnlimited: Bool = false,
        isCoverPresented: Bool = false,
        embedded: Bool = false,
        action: @escaping () -> Void
    ) {
        self.credits = credits
        self.isUnlimited = isUnlimited
        self.isCoverPresented = isCoverPresented
        self.embedded = embedded
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            EmptyView()
        }
        .buttonStyle(
            PlotSearchCreditButtonStyle(
                credits: credits,
                isUnlimited: isUnlimited,
                isCoverPresented: isCoverPresented,
                embedded: embedded
            )
        )
        .accessibilityLabel("Search credits")
        .accessibilityValue(isUnlimited ? "Unlimited" : "\(credits) remaining")
    }
}

public struct PlotSearchCreditButtonStyle: ButtonStyle {
    public var credits: Int
    public var isUnlimited: Bool
    public var isCoverPresented: Bool
    public var embedded: Bool
    
    public init(credits: Int, isUnlimited: Bool = false, isCoverPresented: Bool = false, embedded: Bool = false) {
        self.credits = credits
        self.isUnlimited = isUnlimited
        self.isCoverPresented = isCoverPresented
        self.embedded = embedded
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        PlotSearchCreditPillView(
            credits: credits,
            isUnlimited: isUnlimited,
            isPressed: configuration.isPressed,
            isCoverPresented: isCoverPresented,
            embedded: embedded
        )
        .opacity(embedded && configuration.isPressed ? 0.6 : 1.0)
        .scaleEffect(configuration.isPressed ? (embedded ? 0.97 : 0.955) : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var credits = 20
        @State private var isSheetOpen = false
        
        var body: some View {
            VStack(spacing: 30) {
                PlotSearchCreditPillView(
                    credits: credits,
                    isCoverPresented: isSheetOpen
                )
                
                HStack(spacing: 12) {
                    Button("+10 Plots (20 -> 30)") {
                        credits += 10
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Simulate Purchase Modal") {
                        isSheetOpen = true
                        credits += 10
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isSheetOpen = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Reset (20)") {
                        credits = 20
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(40)
            .background(Color(red: 20/255, green: 40/255, blue: 50/255))
        }
    }
    return PreviewWrapper()
}
