import SwiftUI

enum AppSplashState {
    case showingLogo
    case animatingMap
    case finished
}

struct MainView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var splashState: AppSplashState = .showingLogo
    @State private var logoScale: CGFloat = 1.0
    @State private var logoOpacity: Double = 1.0
    @State private var mapBlur: CGFloat = 15.0
    @State private var showDisclaimer = false
    @State private var showVillagePicker = false
    @State private var showQuickFeatures = false
    @State private var showManualSearch = false
    @State private var showOfficialLandRecords = false
    @State private var showSubscription = false
    @State private var showLogin = false
    @State private var showLandAreaConverter = false
    @ObservedObject private var navManager = AppNavigationManager.shared
    @State private var showShareSheet: Bool = false
    @ObservedObject private var feedbackManager = AppFeedbackManager.shared
    @ObservedObject private var explorerVM = GISExplorerViewModel.shared
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared
    
    var body: some View {
        ZStack {
            if splashState == .finished {
                ZStack {
                    MapLibreView(
                        selectedParcel: $viewModel.selectedParcel,
                        selectedCadastralParcel: $viewModel.selectedCadastralParcel,
                        cadastralShape: $viewModel.cadastralShape,
                        center: $viewModel.mapCenter,
                        zoom: $viewModel.zoomLevel,
                        pendingCameraTarget: $viewModel.pendingCameraTarget,
                        isSatellite: $viewModel.isSatellite,
                        showParcels: $viewModel.showParcels,
                        parcelDisplayStyle: $viewModel.parcelDisplayStyle,
                        shouldCenterOnUser: $viewModel.shouldCenterOnUser,
                        isTrackingUser: $viewModel.isTrackingUser,
                        userLocationCoordinate: $viewModel.lastKnownMapLibreUserLocation,
                        shouldResetBearing: $viewModel.shouldResetBearing,
                        tapPoint: $viewModel.tapPoint,
                        selectedLocationInfo: $viewModel.selectedLocationInfo,
                        activeCadastralVillage: viewModel.activeCadastralVillage,
                        visualFilter: viewModel.visualFilter,
                        selectionToken: viewModel.activeSelectionToken,
                        parcelCount: viewModel.cadastralParcels.count,
                        currentFlow: viewModel.currentFlow,
                        upGISCode: UPFeature.isAvailable ? viewModel.upSession?.gisCode : nil,
                        upSelectionTileURLTemplate: viewModel.selectedUPPlot.flatMap {
                            UPMapService.shared.selectionTileURLTemplate(for: $0)
                        },
                        upSelectionBBox: viewModel.selectedUPPlot?.bbox,
                        onUPTap: { coord in
                            viewModel.identifyUPPlot(at: coord)
                        },
                        onRegionChanged: { _, _ in
                            viewModel.dismissSearchOnMapInteraction()
                        },
                        onMapTap: { _, _ in
                            viewModel.dismissSearchOnMapInteraction()
                        },
                        onParcelTapped: { cadastral in
                            viewModel.onCadastralParcelSelected(cadastral)
                        },
                        onParcelRenderingVerified: { isRendered, villageId, token, reason in
                            if isRendered {
                                viewModel.onParcelLayerRenderSuccess(villageId: villageId, token: token)
                            } else {
                                viewModel.onParcelLayerRenderFailure(villageId: villageId, token: token, reason: reason)
                            }
                        }
                    )
                    .ignoresSafeArea()
                    
                    // In-Map Procedural Cadastral Boundary Drawing
                    CadastralBoundaryDrawingOverlayView(viewModel: viewModel)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    
                    // Absolute Top Map Edge Blur Overlay
                    VStack(spacing: 0) {
                        EdgeBlurOverlay(edge: .top, height: 70)
                        Spacer()
                    }
                    .ignoresSafeArea()
                    
                    // Isolated GIS Explorer View (Apple Maps-style exploration overlay)
                    if AppConfig.gisNavigationEnabled && explorerVM.isExplorerActive {
                        GISExplorerView(viewModel: explorerVM, mapViewModel: viewModel)
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                    }
                    
                    // Detail Sheets (Plot Card / Location Sheet) - Strictly Map View only
                    DetailSheetsOverlay(viewModel: viewModel)
                        .ignoresSafeArea(edges: .bottom)
                    
                    // Uttar Pradesh map prototype: mode pill with exit
                    if let upSession = viewModel.upSession {
                        UPModePill(session: upSession,
                                   isBusy: viewModel.isUPIdentifying,
                                   onChangeVillage: { viewModel.showUPPicker = true },
                                   onExit: { viewModel.exitUP() })
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 112)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(106)
                    }

                    MapHomeOverlay(
                        viewModel: viewModel,
                        showVillagePicker: $showVillagePicker,
                        showQuickFeatures: $showQuickFeatures,
                        showOfficialLandRecords: $showOfficialLandRecords,
                        showLandAreaConverter: $showLandAreaConverter,
                        showSubscription: $showSubscription
                    )
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .zIndex(105)
                }
                .transition(.bhumitraTabTransition)
            } else {
                AppLaunchExperience(scale: logoScale, opacity: logoOpacity)
                    .zIndex(2)
            }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            if navManager.selectedTab == .share { navManager.selectedTab = .map }
        }) {
            ShareSheet(activityItems: ["Check out MyBhoomi - Land Records & Cadastral Mapping: https://mybhoomi.app"])
        }
        .sheet(isPresented: Binding<Bool>(
            get: {
                if case .ambiguous = viewModel.spatialResolutionState { return true }
                return false
            },
            set: { if !$0 { viewModel.spatialResolutionState = .idle } }
        )) {
            if case .ambiguous(let candidates) = viewModel.spatialResolutionState {
                ResolutionAmbiguitySheet(
                    candidates: candidates,
                    onSelect: { candidate in
                        _Concurrency.Task {
                            await viewModel.selectResolutionCandidate(candidate)
                        }
                    },
                    onDismiss: {
                        viewModel.spatialResolutionState = .idle
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if splashState == .finished {
                ToastOverlay(message: viewModel.toastMessage, icon: viewModel.toastIcon)
            }
        }
        .onChange(of: remoteConfig.isUPMapEnabled) { _ in
            if !UPFeature.isAvailable, viewModel.upSession != nil {
                viewModel.exitUP(restorePrevious: true)
            }
        }
        .onChange(of: navManager.selectedTab) { newTab in
            if newTab != .map {
                viewModel.selectedParcel = nil
                viewModel.selectedCadastralParcel = nil
                viewModel.tapPoint = nil
                viewModel.selectedLocationInfo = nil
                viewModel.selectedUPPlot = nil
            }
        }
        .onAppear {
            guard splashState == .showingLogo else { return }
            
            // Fast animated entrance & dismissal: map becomes interactive immediately (< 200ms)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.20)) {
                    logoOpacity = 0.0
                    logoScale = 1.04
                    mapBlur = 0.0
                    splashState = .finished
                }
                
                #if DEBUG
                if CommandLine.arguments.contains("-openMap") {
                    navManager.navigate(to: .map)
                } else if CommandLine.arguments.contains("-openGISExplorer") ||
                   CommandLine.arguments.contains("-selectDistrict") ||
                   CommandLine.arguments.contains("-selectTahasil") ||
                   CommandLine.arguments.contains("-selectVillage") ||
                   CommandLine.arguments.contains("-selectParcel") {
                    navManager.navigate(to: .map)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        GISExplorerViewModel.shared.enterExplorer()
                    }
                }
                #endif
                if !AuthManager.shared.isAuthenticated {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showLogin = true
                    }
                }
            }
        }
        .sheet(isPresented: $showDisclaimer) {
            DisclaimerView()
        }
        .sheet(isPresented: $showVillagePicker) {
            CadastralVillagePickerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showUPPicker) {
            UPVillagePickerSheet(viewModel: viewModel, onDismiss: {
                viewModel.showUPPicker = false
            })
        }
        .sheet(item: $viewModel.selectedUPPlot) { plot in
            UPPlotCard(plot: plot, viewModel: viewModel, onDismiss: {
                viewModel.selectedUPPlot = nil
            })
        }
        .sheet(isPresented: $showQuickFeatures) {
            QuickFeaturesSheet(viewModel: viewModel, onDismiss: {
                showQuickFeatures = false
            })
        }
        .sheet(isPresented: $showManualSearch) {
            NavigationView {
                ManualRoRSearchView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showManualSearch = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView(onDismiss: {
                showLogin = false
            })
        }
        .fullScreenCover(isPresented: $showLandAreaConverter) {
            LandAreaConverterView()
        }
        .overlay {
            if showOfficialLandRecords {
                OfficialLandRecordsView(
                    onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showOfficialLandRecords = false
                        }
                    },
                    onShowPlotsOnMap: { village in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showOfficialLandRecords = false
                        }
                        _Concurrency.Task {
                            await viewModel.loadCadastralVillage(village: village)
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(100)
            }
        }
        .overlay {
            if feedbackManager.isFeedbackPromptPresented, let opportunity = feedbackManager.currentOpportunity {
                AppFeedbackPromptCardView(opportunity: opportunity)
                    .transition(.opacity)
            }
        }
        .liquidToastOverlay()
    }
    
    private func getAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return UIImage(named: "MyBhoomi_AppIcon") ?? UIImage(named: "AppIcon")
    }
}

private struct AppLaunchExperience: View {
    let scale: CGFloat
    let opacity: Double

    @Environment(\.colorScheme) private var colorScheme
    @State private var textScale: CGFloat = 0.92
    @State private var textOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Adaptive ambient background
            (colorScheme == .dark ? Color(red: 0.06, green: 0.07, blue: 0.09) : Color(red: 0.97, green: 0.98, blue: 1.0))
                .ignoresSafeArea()

            // Big Bold Bhumitra Typography
            Text("Bhumitra")
                .font(.googleSans(size: 46, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: colorScheme == .dark
                        ? [Color.white, Color.white.opacity(0.85)]
                        : [Color(red: 0.07, green: 0.10, blue: 0.16), Color(red: 0.15, green: 0.20, blue: 0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(textScale * scale)
                .opacity(textOpacity)
        }
        .opacity(opacity)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                textScale = 1.0
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - Resolution Ambiguity Disambiguation Sheet
struct ResolutionAmbiguitySheet: View {
    let candidates: [LocationResolutionCandidate]
    let onSelect: (LocationResolutionCandidate) -> Void
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDarkMode: Bool { colorScheme == .dark }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Select Revenue Village")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : Color(hex: "#111111"))
                    Text("Multiple official revenue boundaries cover this coordinate. Please select the correct village:")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Theme.Color.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(candidates) { candidate in
                            Button {
                                onSelect(candidate)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.myBhoomiBlue.opacity(0.12))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "map.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Theme.myBhoomiBlue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(candidate.villageName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Theme.Color.primaryText)
                                            .lineLimit(1)
                                        
                                        let subtitleParts = [
                                            candidate.tahasilName,
                                            candidate.districtName
                                        ].compactMap { $0 }.filter { !$0.isEmpty }
                                        
                                        Text(subtitleParts.joined(separator: ", "))
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(Theme.Color.secondaryText)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Theme.Color.tertiaryText)
                                }
                                .padding(16)
                                .background(isDarkMode ? Color(hex: "#1A1A24") : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(isDarkMode ? Color.white.opacity(0.10) : Color(hex: "#E5E7EB"), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaledButtonStyle())
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(candidate.villageName), \(candidate.tahasilName ?? ""), \(candidate.districtName ?? "")")
                            .accessibilityHint("Selects this revenue village")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background((isDarkMode ? Color(hex: "#0F0F14") : Color(hex: "#F8F9FA")).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(Theme.myBhoomiBlue)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}



struct ToastOverlay: View {
    let message: String?
    let icon: String
    
    /// Messages that end in an ellipsis describe work in progress
    /// ("Loading nearby land plots…") and get a spinner instead of an icon.
    private func isProgress(_ text: String) -> Bool {
        text.hasSuffix("...") || text.hasSuffix("…")
    }

    var body: some View {
        if let message = message {
            MapStatusPill(
                icon: icon.isEmpty ? nil : icon,
                tone: isProgress(message) ? .progress : .neutral,
                title: message.replacingOccurrences(of: "...", with: "…")
            )
            // Clear of the right-hand map controls and the scale bar.
            .padding(.horizontal, 76)
            .padding(.bottom, 36)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(message)
            .zIndex(100)
        }
    }
}

struct DetailSheetsOverlay: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        GeometryReader { geo in
            // The plot-tap flow is now ONE native multi-detent bottom sheet
            // (PlotDetailSheet): compact overview at the small detent, dragging
            // up reveals the full land report inline in the same scroll. The
            // location-tap flow is unchanged.
            if let locationInfo = viewModel.selectedLocationInfo {
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.selectedLocationInfo = nil
                                viewModel.tapPoint = nil
                            }
                        }
                    
                    LocationDetailSheet(locationInfo: locationInfo, viewModel: viewModel, onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.selectedLocationInfo = nil
                            viewModel.tapPoint = nil
                        }
                    })
                    .padding(.horizontal, 26)
                    .padding(.top, 80)
                    .padding(.bottom, 100)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.05, anchor: anchorPoint(for: geo.size)).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .center).combined(with: .opacity)
                    ))
                }
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .zIndex(100)
        // Native multi-detent bottom sheet for the tapped plot. Parcel is
        // Identifiable, so .sheet(item:) rebuilds cleanly when the selection
        // changes. onDismiss mirrors the previous card teardown.
        .sheet(item: $viewModel.selectedParcel, onDismiss: {
            viewModel.selectedCadastralParcel = nil
            viewModel.tapPoint = nil
        }) { parcel in
            PlotDetailSheet(parcel: parcel, viewModel: viewModel, onDismiss: {
                viewModel.selectedParcel = nil
                viewModel.selectedCadastralParcel = nil
                viewModel.tapPoint = nil
            })
        }
    }
    
    private func anchorPoint(for size: CGSize) -> UnitPoint {
        if let tap = viewModel.tapPoint {
            let x = max(0, min(1, tap.x / size.width))
            let y = max(0, min(1, tap.y / size.height))
            return UnitPoint(x: x, y: y)
        }
        return .center
    }
}

// MARK: - Interaction Helpers



extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        self // All corners are sharp per instruction
    }
}

// MARK: - Disclaimer View
struct DisclaimerView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("Important Disclaimer")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Bhumitra is an independent application developed for public convenience and informational purposes.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("Not Affiliated With Government")
                                .fontWeight(.semibold)
                        }
                        
                        Text("This application is NOT affiliated with, endorsed by, sponsored by, or representative of the Government of Odisha or any other government entity.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.leading, 32)
                        
                        HStack(alignment: .top) {
                            Image(systemName: "server.rack")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Data Source")
                                .fontWeight(.semibold)
                        }
                        
                        Text("The land records, cadastral maps, and ownership information displayed in this app are sourced from open government data portals, primarily the official Odisha Bhulekh portal (https://bhulekh.ori.nic.in).")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.leading, 32)
                            
                        HStack(alignment: .top) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("No Legal Validity")
                                .fontWeight(.semibold)
                        }
                        
                        Text("Data provided here is strictly for general guidance and informational reference. It should NOT be used for legal purposes, dispute resolutions, or official documentation. We do not guarantee absolute accuracy. For certified and legally valid copies of land records, please consult your respective Revenue Office or Tahasil directly.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.leading, 32)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 40)
                    
                    Button(action: { dismiss() }) {
                        Text("I Understand")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
            }
        }
    }
}

#Preview{
    MainView()
}
