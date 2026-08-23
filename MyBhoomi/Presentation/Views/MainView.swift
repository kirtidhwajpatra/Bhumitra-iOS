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
    
    var body: some View {
        ZStack {
            MapLibreView(
                selectedParcel: $viewModel.selectedParcel,
                selectedCadastralParcel: $viewModel.selectedCadastralParcel,
                cadastralShape: $viewModel.cadastralShape,
                center: $viewModel.mapCenter,
                zoom: $viewModel.zoomLevel,
                isSatellite: $viewModel.isSatellite,
                showParcels: $viewModel.showParcels,
                parcelDisplayStyle: $viewModel.parcelDisplayStyle,
                shouldCenterOnUser: $viewModel.shouldCenterOnUser,
                tapPoint: $viewModel.tapPoint,
                selectedLocationInfo: $viewModel.selectedLocationInfo,
                visualFilter: viewModel.visualFilter,
                onRegionChanged: nil,
                onMapTap: nil,
                onParcelTapped: { cadastral in
                    viewModel.onCadastralParcelSelected(cadastral)
                }
            )
            .ignoresSafeArea()
            .blur(radius: splashState == .finished ? 0 : mapBlur)
            
            // Subtle, light ambient dark overlay to enhance button contrast while maintaining natural map luminosity
            LinearGradient(
                colors: [
                    Color.black.opacity(0.12), // Soft top shading for header & status bar clarity
                    Color.black.opacity(0.04), // Clear middle for vibrant satellite clarity
                    Color.black.opacity(0.10)  // Soft bottom shading for card and control clarity
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            if splashState == .finished {
                MapHomeOverlay(
                    viewModel: viewModel,
                    showVillagePicker: $showVillagePicker,
                    showQuickFeatures: $showQuickFeatures,
                    showOfficialLandRecords: $showOfficialLandRecords
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .zIndex(1)
            }
            
            if splashState != .finished {
                AppLaunchExperience(icon: getAppIcon(), scale: logoScale, opacity: logoOpacity)
                .zIndex(2)
            }
        }
        .overlay(alignment: .bottom) {
            if splashState == .finished {
                ToastOverlay(message: viewModel.toastMessage, icon: viewModel.toastIcon)
            }
        }
        .overlay {
            if splashState == .finished {
                DetailSheetsOverlay(viewModel: viewModel)
            }
        }
        .onAppear {
            guard splashState == .showingLogo else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    logoOpacity = 0.0
                    logoScale = 0.95
                    mapBlur = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        splashState = .finished
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
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showLogin) {
            LoginView(onDismiss: {
                showLogin = false
            })
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
    let icon: UIImage?
    let scale: CGFloat
    let opacity: Double

    @State private var orbiting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppAtmosphereBackground()
                .opacity(opacity)

            VStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(Theme.Color.primary.opacity(0.14), lineWidth: 1)
                        .frame(width: 172, height: 172)
                    Circle()
                        .trim(from: 0.08, to: 0.32)
                        .stroke(Theme.Color.primary.opacity(0.66), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 172, height: 172)
                        .rotationEffect(.degrees(orbiting ? 360 : 0))

                    Group {
                        if let icon {
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "map.fill")
                                .resizable()
                                .scaledToFit()
                                .padding(28)
                                .foregroundStyle(Theme.brandGradient)
                        }
                    }
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.86), lineWidth: 1.25))
                    .shadow(color: Theme.Color.primary.opacity(0.24), radius: 28, x: 0, y: 14)
                }
                .scaleEffect(scale)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("Bhumitra")
                        .font(Theme.Typography.largeTitle)
                        .foregroundStyle(Theme.Color.primaryText)
                    Text("Land intelligence, made beautifully simple")
                        .font(Theme.Typography.secondaryBody)
                        .foregroundStyle(Theme.Color.secondaryText)
                }

                HStack(spacing: Theme.Spacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.Color.primary)
                    Text("Preparing your map")
                        .font(Theme.Typography.captionMedium)
                        .foregroundStyle(Theme.Color.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .liquidGlassCard(tint: Theme.Color.primary, radius: Theme.Radius.pill)
            }
            .opacity(opacity)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 3.4).repeatForever(autoreverses: false)) {
                orbiting = true
            }
        }
    }
}

// MARK: - Subviews

struct MapControlsView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        HStack(alignment: .bottom) {
            if viewModel.isLoading {
                LoadingIndicator()
            }
            
            Spacer()
            
            LiquidGlassMapControlsCapsule(viewModel: viewModel)
        }
        .padding(.leading, 16)
        .padding(.trailing, 24)
        .padding(.bottom, 16)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedParcel == nil)
    }
}

// MARK: - Sub-Views

struct SearchSectionView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var showQuickFeatures: Bool
    @Binding var showManualSearch: Bool
    @Binding var showSubscription: Bool
    @Binding var showLogin: Bool
    @Binding var showVillagePicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Village / Hierarchy Indicator Pill
                Button(action: {
                    hapticFeedback(.light)
                    showVillagePicker = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.neonPurple)
                        
                        Text(viewModel.activeCadastralVillage?.name ?? "Odisha")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.black.opacity(0.4))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 6)
                }
                .buttonStyle(ScaledButtonStyle())
                
                // Search Input Field
                SearchBarView(viewModel: viewModel, text: $viewModel.searchQuery) {
                    viewModel.searchLocation()
                }
                
                // Digital Services Quick Access
                Button(action: {
                    hapticFeedback(.medium)
                    showQuickFeatures = true
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 48, height: 48)
                            .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 6)
                        
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.brandGradient)
                    }
                }
                .buttonStyle(ScaledButtonStyle())
            }
            
            if !viewModel.searchResults.isEmpty {
                SearchSuggestionsList(viewModel: viewModel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedParcel == nil)
    }
}

struct SearchSuggestionsList: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.searchResults) { result in
                    Button(action: {
                        hapticFeedback(.medium)
                        _Concurrency.Task {
                            try? await viewModel.selectLocation(result)
                        }
                    }) {
                        SearchSuggestionRow(result: result)
                    }
                    
                    if result.id != viewModel.searchResults.last?.id {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
        .frame(maxHeight: 320)
        .padding(.top, 10)
    }
}

struct SearchSuggestionRow: View {
    let result: SearchResult
    
    private func resultIcon(for type: SearchResultType) -> String {
        switch type {
        case .plot(_): return "tag.fill"
        case .area(_, _): return "building.2.fill"
        case .village(_, _): return "map.fill"
        case .cadastralVillage(_): return "map.circle.fill"
        case .global(_): return "mappin.and.ellipse"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.myBhoomiBlue.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: resultIcon(for: result.type))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.myBhoomiBlue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black.opacity(0.8))
                    .lineLimit(1)
                Text(result.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black.opacity(0.15))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
    }
}



struct LoadingIndicator: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(primaryPurple)
            Text("Updating parcels")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(primaryPurple)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct ToastOverlay: View {
    let message: String?
    let icon: String
    
    var body: some View {
        if let message = message {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
                Text(message)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
            )
            .padding(.bottom, 40)
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
            if let parcel = viewModel.selectedParcel {
                CadastralPlotCardView(parcel: parcel, viewModel: viewModel, onDismiss: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.88, blendDuration: 0.15)) {
                        viewModel.selectedParcel = nil
                        viewModel.selectedCadastralParcel = nil
                        viewModel.tapPoint = nil
                        hapticFeedback(.light)
                    }
                })
                .id(parcel.id)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .move(edge: .bottom)
                            .combined(with: .opacity)
                    )
                )
            } else if let locationInfo = viewModel.selectedLocationInfo {
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
                            hapticFeedback(.light)
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


struct MapControlButton: View {
    let icon: String
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
            
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(primaryPurple)
        }
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView(effect: UIBlurEffect(style: blurStyle)) }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

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
