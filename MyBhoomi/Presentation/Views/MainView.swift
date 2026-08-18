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
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSubscriptionPaywall = false
    @State private var showProfile = false
    
    var body: some View {
        ZStack {
            MapLibreView(
                selectedParcel: $viewModel.selectedParcel,
                center: $viewModel.mapCenter,
                zoom: $viewModel.zoomLevel,
                isSatellite: $viewModel.isSatellite,
                showParcels: $viewModel.showParcels,
                shouldCenterOnUser: $viewModel.shouldCenterOnUser,
                tapPoint: $viewModel.tapPoint,
                parcels: $viewModel.parcels,
                selectedLocationInfo: $viewModel.selectedLocationInfo,
                onRegionChanged: { ne, sw in
                    viewModel.onMapRegionChanged(northEast: ne, southWest: sw)
                },
                onMapTap: { coord, point in
                _Concurrency.Task {
                        await viewModel.fetchLocationInfo(at: coord)
                    }
                }
            )
            .ignoresSafeArea()
            .blur(radius: splashState == .finished ? 0 : mapBlur)
            
            if splashState == .finished {
                VStack(spacing: 0) {
                    // Search Section
                    SearchSectionView(
                        viewModel: viewModel,
                        showSubscriptionPaywall: $showSubscriptionPaywall,
                        showProfile: $showProfile
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                    
                    // Map Controls
                    if viewModel.selectedParcel == nil && viewModel.selectedLocationInfo == nil {
                        MapControlsView(viewModel: viewModel, showDisclaimer: $showDisclaimer)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .zIndex(1)
            }
            
            if splashState != .finished {
                ZStack {
                    Color.white.opacity(logoOpacity).ignoresSafeArea()
                    
                    if let image = getAppIcon() {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    } else {
                        Image(systemName: "map.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(primaryPurple)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    }
                }
                .ignoresSafeArea()
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
        .task { await viewModel.loadParcels() }
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
        .sheet(isPresented: $showSubscriptionPaywall) {
            SubscriptionView()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
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

// MARK: - Sub-Views

struct SearchSectionView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var showSubscriptionPaywall: Bool
    @Binding var showProfile: Bool
    
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: Search Bar (Top) & Profile Button (Rightmost)
            HStack(spacing: 12) {
                SearchBarView(viewModel: viewModel, text: $viewModel.searchQuery) {
                    viewModel.searchLocation()
                }
                
                // Profile Button
                Button(action: {
                    hapticFeedback(.light)
                    showProfile = true
                }) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Theme.primary)
                        .frame(width: 48, height: 48)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
                }
                .buttonStyle(ScaledButtonStyle())
            }
            
            // Row 2: Subscription / Upgrade Badge (Below Search)
            HStack(spacing: 10) {
                Spacer()
                
                // Subscription Status Indicator / CTA
                Button(action: {
                    hapticFeedback(.light)
                    showSubscriptionPaywall = true
                }) {
                    HStack(spacing: 6) {
                        if subscriptionManager.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.neonPurple)
                            Text("Premium")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.neonPurple)
                        } else {
                            Image(systemName: "crown")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("Upgrade")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(subscriptionManager.isPremium ? Theme.neonPurple.opacity(0.1) : Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(subscriptionManager.isPremium ? Theme.neonPurple.opacity(0.3) : Color.black.opacity(0.04), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                }
                .buttonStyle(ScaledButtonStyle())
            }
            .padding(.top, 10)
            
            if !viewModel.searchResults.isEmpty {
                SearchSuggestionsList(viewModel: viewModel)
            }
        }
        .padding(.horizontal, 20)
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
                        viewModel.selectLocation(result)
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
        case .global(_): return "mappin.and.ellipse"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(primaryPurple.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: resultIcon(for: result.type))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(primaryPurple)
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

struct MapControlsView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var showDisclaimer: Bool
    
    var body: some View {
        HStack(alignment: .bottom) {
            if viewModel.isLoading {
                LoadingIndicator()
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: { showDisclaimer = true }) {
                    MapControlButton(icon: "info.circle.fill")
                }
                .buttonStyle(ScaledButtonStyle())
                
                Button(action: { viewModel.toggleSatellite() }) {
                    MapControlButton(icon: viewModel.isSatellite ? "map" : "square.3.layers.3d")
                }
                .buttonStyle(ScaledButtonStyle())
                
                if viewModel.zoomLevel >= 14.5 {
                    Button(action: { viewModel.toggleParcels() }) {
                        MapControlButton(icon: viewModel.showParcels ? "eye.fill" : "eye.slash.fill")
                    }
                    .buttonStyle(ScaledButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }
                
                Button(action: { 
                    hapticFeedback(.medium)
                    viewModel.shouldCenterOnUser = true 
                }) {
                    MapControlButton(icon: "location.fill")
                }
                .buttonStyle(ScaledButtonStyle())
                
                ZoomControls(viewModel: viewModel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedParcel == nil)
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

struct ZoomControls: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { 
                hapticFeedback(.light)
                viewModel.zoomIn() 
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primaryPurple)
                    .frame(width: 44, height: 44)
            }
            Divider().background(Color.black.opacity(0.05)).frame(width: 24)
            Button(action: { 
                hapticFeedback(.light)
                viewModel.zoomOut() 
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primaryPurple)
                    .frame(width: 44, height: 44)
            }
        }
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
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
            if viewModel.selectedParcel != nil || viewModel.selectedLocationInfo != nil {
                ZStack {
                    // Backdrop: Simple dim instead of blur
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .ignoresSafeArea()
                        .onTapGesture {
                            print("DEBUG: Backdrop tapped. Setting selectedParcel to nil.")
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.selectedParcel = nil
                                viewModel.selectedLocationInfo = nil
                                viewModel.tapPoint = nil
                            }
                        }
                    
                    if let parcel = viewModel.selectedParcel {
                        ParcelDetailSheet(parcel: parcel, viewModel: viewModel, onDismiss: {
                            print("DEBUG: ParcelDetailSheet dismissed via onDismiss button.")
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.selectedParcel = nil
                                viewModel.tapPoint = nil
                                hapticFeedback(.light)
                            }
                        })
                        .id(parcel.id)
                        .padding(.horizontal, 26)
                        .padding(.top, 80)
                        .padding(.bottom, 100)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.05, anchor: anchorPoint(for: geo.size)).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .center).combined(with: .opacity)
                        ))
                    } else if let locationInfo = viewModel.selectedLocationInfo {
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
                }
                .ignoresSafeArea()
                .zIndex(100)
            }
            
        }
        .ignoresSafeArea()
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

// MARK: - Profile View

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // User details card
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.primary)
                    }
                    
                    VStack(spacing: 4) {
                        Text(authManager.currentUser?.name ?? "Guest User")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("+91 \(authManager.currentUser?.mobile ?? "")")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 16)
                
                // Subscription Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MEMBERSHIP STATUS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1)
                            Text(subscriptionManager.isPremium ? "Premium Account" : "Free Tier")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(subscriptionManager.isPremium ? Theme.neonPurple : .black)
                        }
                        Spacer()
                        if subscriptionManager.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.neonPurple)
                        } else {
                            Button(action: {
                                showPaywall = true
                            }) {
                                Text("Upgrade")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Theme.brandGradient)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(ScaledButtonStyle())
                        }
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.03))
                    .cornerRadius(16)
                    
                    if !subscriptionManager.isPremium {
                        let remaining = max(0, 5 - subscriptionManager.getOwnershipPreviewCount())
                        Text("\(remaining) ownership record views remaining this month.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Logout Button
                Button(action: {
                    hapticFeedback(.medium)
                    dismiss()
                    authManager.logout()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(16)
                }
                .buttonStyle(ScaledButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionView()
            }
        }
    }
}
