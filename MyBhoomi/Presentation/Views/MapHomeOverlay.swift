import SwiftUI

/// Clean, map-first floating controls overlay for MyBhoomi home screen (Phase 3.35).
public struct MapHomeOverlay: View {
    @ObservedObject public var viewModel: MapViewModel
    @Binding public var showVillagePicker: Bool
    @Binding public var showQuickFeatures: Bool
    @Binding public var showOfficialLandRecords: Bool
    
    public init(
        viewModel: MapViewModel,
        showVillagePicker: Binding<Bool>,
        showQuickFeatures: Binding<Bool>,
        showOfficialLandRecords: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self._showVillagePicker = showVillagePicker
        self._showQuickFeatures = showQuickFeatures
        self._showOfficialLandRecords = showOfficialLandRecords
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. TOP FLOATING CONTROL ROW
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    // Left: Village Selector Pill
                    Button(action: {
                        hapticFeedback(.light)
                        showVillagePicker = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.myBhoomiBlue)
                            
                            Text(viewModel.activeCadastralVillage?.name ?? "Odisha")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.black.opacity(0.85))
                                .lineLimit(1)
                                .frame(maxWidth: 110, alignment: .leading)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.94))
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaledButtonStyle())
                    .accessibilityLabel("Select village")
                    
                    // Center: Compact Village Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.myBhoomiBlue)
                        
                        TextField("Search village...", text: $viewModel.searchQuery)
                            .font(.system(size: 14, weight: .regular))
                            .submitLabel(.search)
                            .onSubmit {
                                viewModel.searchLocation()
                            }
                        
                        if !viewModel.searchQuery.isEmpty {
                            Button(action: {
                                hapticFeedback(.light)
                                viewModel.searchQuery = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.94))
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .accessibilityLabel("Search village")
                    
                    // Right: Map Info Button
                    Button(action: {
                        hapticFeedback(.light)
                        showQuickFeatures = true
                    }) {
                        Image(systemName: "info")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.myBhoomiBlue)
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.94))
                                    .background(
                                        Circle().fill(.ultraThinMaterial)
                                    )
                                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaledButtonStyle())
                    .accessibilityLabel("Map information")
                }
                
                // Search suggestions dropdown if typing
                if !viewModel.searchResults.isEmpty {
                    SearchSuggestionsList(viewModel: viewModel)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Spacer()
            
            // 2. BOTTOM FLOATING CONTROLS & MANUAL ROR ACTION
            if viewModel.selectedParcel == nil && viewModel.selectedLocationInfo == nil {
                VStack(spacing: 14) {
                    // Trailing Floating Map Controls
                    HStack {
                        if viewModel.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(Theme.myBhoomiBlue)
                                Text("Updating...")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.92))
                                    .background(Capsule().fill(.ultraThinMaterial))
                                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                            )
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 10) {
                            // Toggle Cadastral Parcels Layer
                            Button(action: {
                                hapticFeedback(.light)
                                viewModel.toggleParcels()
                            }) {
                                Image(systemName: viewModel.showParcels ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Theme.myBhoomiBlue)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.94))
                                            .background(Circle().fill(.ultraThinMaterial))
                                            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                                    )
                                    .overlay(
                                        Circle().stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaledButtonStyle())
                            .accessibilityLabel("Toggle parcel visibility")
                            
                            // Center on User GPS
                            Button(action: {
                                hapticFeedback(.light)
                                viewModel.shouldCenterOnUser = true
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Theme.myBhoomiBlue)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.94))
                                            .background(Circle().fill(.ultraThinMaterial))
                                            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                                    )
                                    .overlay(
                                        Circle().stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaledButtonStyle())
                            .accessibilityLabel("Show my location")
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Bottom Center: Floating Manual RoR Search Pill
                    Button(action: {
                        hapticFeedback(.light)
                        showOfficialLandRecords = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.myBhoomiBlue)
                            
                            Text("Manual RoR Search")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.black.opacity(0.85))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.95))
                                .background(Capsule().fill(.ultraThinMaterial))
                                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
                        )
                        .overlay(
                            Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaledButtonStyle())
                    .accessibilityLabel("Manual RoR search")
                    .padding(.bottom, 22)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.selectedParcel == nil)
    }
}
