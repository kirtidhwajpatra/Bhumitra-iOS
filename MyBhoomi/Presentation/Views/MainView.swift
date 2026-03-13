import SwiftUI

let primaryPurple = Color(red: 107/255, green: 70/255, blue: 193/255)
let accentLavender = Color(red: 240/255, green: 231/255, blue: 255/255)
let deepPurple = Color(red: 76/255, green: 59/255, blue: 145/255)

struct MainView: View {
    @StateObject private var viewModel = MapViewModel()
    
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
                onRegionChanged: { ne, sw in
                    viewModel.onMapRegionChanged(northEast: ne, southWest: sw)
                }
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TOP SECTION: Full Width Search
                if viewModel.selectedParcel == nil {
                    VStack(alignment: .leading, spacing: 0) {
                        SearchBarView(text: $viewModel.searchQuery) {
                            viewModel.searchLocation()
                        }
                        
                        // Search Suggestions List
                        if !viewModel.searchResults.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(viewModel.searchResults) { result in
                                        Button(action: {
                                            hapticFeedback(.medium)
                                            viewModel.selectLocation(result)
                                        }) {
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
                    .padding(.horizontal)
                    .padding(.top, 8) 
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedParcel == nil)
                }
                
                Spacer()
                
                // BOTTOM SECTION: Map Controls & Loading
                if viewModel.selectedParcel == nil {
                    HStack(alignment: .bottom) {
                        if viewModel.isLoading {
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
                        
                        Spacer()
                        
                        VStack(spacing: 12) {
                            Button(action: { viewModel.toggleSatellite() }) {
                                MapControlButton(icon: viewModel.isSatellite ? "map" : "square.3.layers.3d")
                            }
                            .buttonStyle(ScaledButtonStyle())
                            
                            Button(action: { viewModel.toggleParcels() }) {
                                MapControlButton(icon: viewModel.showParcels ? "eye.fill" : "eye.slash.fill")
                            }
                            .buttonStyle(ScaledButtonStyle())
                            
                            Button(action: { 
                                hapticFeedback(.medium)
                                viewModel.shouldCenterOnUser = true 
                            }) {
                                MapControlButton(icon: "location.fill")
                            }
                            .buttonStyle(ScaledButtonStyle())
                            
                            // Zoom Controls
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
                                Divider().background(Color.black.opacity(0.1)).frame(width: 24)
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedParcel == nil)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .overlay(alignment: .bottom) {
            if let message = viewModel.toastMessage {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.toastIcon)
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
        .task { await viewModel.loadParcels() }
        .overlay {
            GeometryReader { geo in
                if let parcel = viewModel.selectedParcel {
                    ZStack {
                        // Premium Glassmorphic Backdrop
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(Color.black.opacity(0.15))
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.selectedParcel = nil
                                    viewModel.tapPoint = nil
                                }
                            }
                        
                        ParcelDetailSheet(parcel: parcel, viewModel: viewModel, onDismiss: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.selectedParcel = nil
                                viewModel.tapPoint = nil
                                hapticFeedback(.light)
                            }
                        })
                        .id(parcel.id)
                        .padding(.horizontal, 26)
                        .padding(.top, 60)
                        .padding(.bottom, 80)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.05, anchor: {
                                if let tap = viewModel.tapPoint {
                                    let x = max(0, min(1, tap.x / geo.size.width))
                                    let y = max(0, min(1, tap.y / geo.size.height))
                                    return UnitPoint(x: x, y: y)
                                }
                                return .center
                            }()).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .center).combined(with: .opacity)
                        ))
                    }
                    .ignoresSafeArea()
                    .zIndex(100)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    private func resultIcon(for type: SearchResultType) -> String {
        switch type {
        case .plot: return "tag.fill"
        case .area: return "building.2.fill"
        case .global: return "mappin.and.ellipse"
        }
    }
}

// MARK: - Interaction Helpers

struct ScaledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}

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
