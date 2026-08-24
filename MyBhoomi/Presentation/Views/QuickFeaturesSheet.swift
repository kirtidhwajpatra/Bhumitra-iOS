import SwiftUI

// ============================================================
// MARK: - BHUMITRA DIGITAL SERVICES & SETTINGS (LIQUID GLASS REDESIGN)
// ============================================================

/// Clean, modern Liquid Glass preferences & services sheet.
/// Includes Bhumitra Pro hero banner, in-place map & layer settings,
/// land record utilities, and support & legal notices.
public struct QuickFeaturesSheet: View {
    @ObservedObject public var viewModel: MapViewModel
    public let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedService: LandServiceType? = nil
    @State private var showSubscriptionCover: Bool = false
    @State private var proCardBounce: Bool = false
    
    public init(viewModel: MapViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.85)
    }
    
    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }
    
    public var body: some View {
        ZStack {
            AppAtmosphereBackground()
            
            VStack(spacing: 0) {
                // 1. TOP HEADER: Title, Subtitle, and Liquid Glass Close Button
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Digital Services & Settings")
                            .font(Theme.Typography.titleCondensed)
                            .foregroundStyle(Theme.Color.primaryText)
                        
                        Text("Layers, pro features, and land records")
                            .font(Theme.Typography.captionMedium)
                            .foregroundStyle(Theme.Color.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button {
                        Theme.haptic(.light)
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14.5, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // 2. BHUMITRA PRO HERO BANNER (Liquid Glass with Ambient Glow)
                        proHeroBanner
                        
                        // 3. MAP & SATELLITE LAYERS (In-Place Interactive Settings)
                        mapLayersCard
                        
                        // 4. LAND RECORDS & GIS UTILITIES (Grouped Tile Rows)
                        landRecordsGroup
                        
                        // 5. COMPLIANCE & SUPPORT
                        supportAndLegalGroup
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
            
            // Nested Detail Sheet for Secondary Views (RoR Search, Disclaimer, Support)
            if let service = selectedService {
                LandServiceDetailView(service: service, onDismiss: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        selectedService = nil
                    }
                }, viewModel: viewModel)
            }
        }
        .fullScreenCover(isPresented: $showSubscriptionCover) {
            SubscriptionView()
        }
    }
    
    // ============================================================
    // MARK: - 1. BHUMITRA PRO HERO CARD
    // ============================================================
    
    private var proHeroBanner: some View {
        Button {
            Theme.haptic(.medium)
            proCardBounce.toggle()
            showSubscriptionCover = true
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 16) {
                    // Glowing Crown Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.neonPurple.opacity(0.35), Color.accentColor.opacity(0.20)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.neonPurple)
                            .shadow(color: Theme.neonPurple.opacity(0.6), radius: 8)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Bhumitra Pro")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Theme.Color.primaryText)
                            
                            Text("UNLIMITED")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(0.5)
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.neonPurple, Color(red: 130/255, green: 50/255, blue: 240/255)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                        
                        Text("Unlimited RoRs, 4K vector map & PDF exports")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundColor(Theme.Color.secondaryText)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.Color.secondaryText)
                }
                .padding(16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.neonPurple.opacity(0.10),
                                        Color.accentColor.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Theme.neonPurple.opacity(0.50),
                                    Color.accentColor.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.25
                        )
                )
                .shadow(color: Theme.neonPurple.opacity(0.12), radius: 12, y: 4)
            }
        }
        .buttonStyle(ScaledButtonStyle())
    }
    
    // ============================================================
    // MARK: - 2. MAP & SATELLITE LAYERS (IN-PLACE SETTINGS)
    // ============================================================
    
    private var mapLayersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MAP & SATELLITE LAYERS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.8)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                // Row 1: Satellite Mode Toggle
                HStack(spacing: 14) {
                    layerIcon(icon: "square.3.layers.3d.fill", color: .teal)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Satellite High-Res Imagery")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Color.primaryText)
                        Text(viewModel.isSatellite ? "High-res satellite terrain" : "Standard vector base map")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { viewModel.isSatellite },
                        set: { _ in viewModel.toggleSatellite() }
                    ))
                    .labelsHidden()
                }
                .padding(14)
                
                Divider()
                    .padding(.leading, 56)
                
                // Row 2: Cadastral Boundaries Toggle
                HStack(spacing: 14) {
                    layerIcon(icon: "map.fill", color: Theme.Color.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cadastral Parcel Boundaries")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Color.primaryText)
                        Text(viewModel.showParcels ? "Survey boundaries & plot numbers" : "Parcels hidden")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.showParcels)
                        .labelsHidden()
                }
                .padding(14)
                
                Divider()
                    .padding(.leading, 56)
                
                // Row 3: Plot Shading Mode (Shaded Fill vs Outline Only)
                HStack(spacing: 14) {
                    layerIcon(icon: viewModel.parcelDisplayStyle == .shadedFill ? "square.filled.on.square" : "square.dashed", color: .purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plot Shading Mode")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Color.primaryText)
                        Text(viewModel.parcelDisplayStyle == .shadedFill ? "Vibrant shaded plot fills" : "Fine boundary outline only")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        Theme.haptic(.light)
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            viewModel.toggleParcelDisplayStyle()
                        }
                    } label: {
                        Text(viewModel.parcelDisplayStyle == .shadedFill ? "Shaded" : "Outline")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
        }
    }
    
    // ============================================================
    // MARK: - 3. LAND RECORDS & GIS UTILITIES
    // ============================================================
    
    private var landRecordsGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LAND RECORDS & UTILITIES")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.8)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                serviceRow(
                    icon: "doc.text.magnifyingglass",
                    iconColor: .blue,
                    title: "Official RoR Search",
                    subtitle: "Direct ownership lookup by Plot or Khata",
                    service: .viewRor
                )
                
                Divider()
                    .padding(.leading, 56)
                
                serviceRow(
                    icon: "map.circle.fill",
                    iconColor: .indigo,
                    title: "Odisha Cadastral Hierarchy",
                    subtitle: "Browse surveyed parcels across 30 Districts",
                    service: .cadastralHierarchy
                )
                
                Divider()
                    .padding(.leading, 56)
                
                serviceRow(
                    icon: "arrow.down.circle.fill",
                    iconColor: .purple,
                    title: "Downloaded Records",
                    subtitle: "Access offline saved & verified RoR documents",
                    service: .downloadedRor
                )
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
        }
    }
    
    // ============================================================
    // MARK: - 4. COMPLIANCE & SUPPORT GROUP
    // ============================================================
    
    private var supportAndLegalGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUPPORT & COMPLIANCE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.8)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                serviceRow(
                    icon: "info.circle.fill",
                    iconColor: .gray,
                    title: "Legal Disclaimer",
                    subtitle: "Official data notices & terms of use",
                    service: .legalDisclaimer
                )
                
                Divider()
                    .padding(.leading, 56)
                
                serviceRow(
                    icon: "envelope.badge.fill",
                    iconColor: .orange,
                    title: "Help & Contact",
                    subtitle: "Support, user guides & feedback",
                    service: .contactSupport
                )
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
        }
    }
    
    // ============================================================
    // MARK: - HELPER ROW BUILDERS
    // ============================================================
    
    private func serviceRow(icon: String, iconColor: Color, title: String, subtitle: String, service: LandServiceType) -> some View {
        Button {
            Theme.haptic(.light)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                selectedService = service
            }
        } label: {
            HStack(spacing: 14) {
                layerIcon(icon: icon, color: iconColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Color.primaryText)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
    
    private func layerIcon(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: 36, height: 36)
            
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
    }
}
