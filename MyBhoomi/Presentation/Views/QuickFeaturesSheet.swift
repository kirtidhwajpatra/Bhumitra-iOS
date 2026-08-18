import SwiftUI

struct QuickFeatureCategory: Identifiable {
    let id = UUID()
    let name: String
    let features: [QuickFeature]
}

struct QuickFeature: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let type: LandServiceType
}

struct QuickFeaturesSheet: View {
    @ObservedObject var viewModel: MapViewModel
    let onDismiss: () -> Void
    
    @State private var selectedService: LandServiceType? = nil
    
    let categories: [QuickFeatureCategory] = [
        QuickFeatureCategory(
            name: "LAND RECORDS & CADASTRAL",
            features: [
                QuickFeature(
                    title: "Official RoR Search",
                    subtitle: "Direct official land ownership lookup by Plot, Khata, or Hierarchy",
                    icon: "doc.text.magnifyingglass",
                    color: .blue,
                    type: .viewRor
                ),
                QuickFeature(
                    title: "Odisha Cadastral Hierarchy",
                    subtitle: "Browse surveyed parcels across 30 Districts, Tahasils, GPs & Mouzas",
                    icon: "map.circle.fill",
                    color: .indigo,
                    type: .cadastralHierarchy
                ),
                QuickFeature(
                    title: "Downloaded Records",
                    subtitle: "Access your offline saved & verified RoR documents",
                    icon: "arrow.down.circle.fill",
                    color: .purple,
                    type: .downloadedRor
                )
            ]
        ),
        QuickFeatureCategory(
            name: "MAPS & SATELLITE LAYERS",
            features: [
                QuickFeature(
                    title: "Satellite & Map Layers",
                    subtitle: "Configure high-res satellite imagery and cadastral overlay styling",
                    icon: "square.3.layers.3d",
                    color: .teal,
                    type: .satelliteLayer
                ),
                QuickFeature(
                    title: "Offline Maps",
                    subtitle: "Access and cache cadastral parcels without internet connection",
                    icon: "map.fill",
                    color: .green,
                    type: .offlineMaps
                )
            ]
        ),
        QuickFeatureCategory(
            name: "PREMIUM & SUPPORT",
            features: [
                QuickFeature(
                    title: "Bhumitra Pro",
                    subtitle: "Unlimited RoR downloads, satellite terrain & parcel analytics",
                    icon: "crown.fill",
                    color: Color(red: 170/255, green: 70/255, blue: 250/255),
                    type: .proSubscription
                ),
                QuickFeature(
                    title: "Legal Disclaimer",
                    subtitle: "Official data source notices, accuracy policies & terms of use",
                    icon: "info.circle.fill",
                    color: .gray,
                    type: .legalDisclaimer
                ),
                QuickFeature(
                    title: "Help & Contact",
                    subtitle: "Support, user guides, FAQs & feedback",
                    icon: "envelope.badge.fill",
                    color: .orange,
                    type: .contactSupport
                )
            ]
        )
    ]
    
    var body: some View {
        ZStack {
            // Background Gradient for the sheet
            LinearGradient(colors: [Color.white, Color(white: 0.96)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Digital Services")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text("Instant access to all land records, maps & tools")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        ForEach(categories) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.name)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                    .padding(.leading, 4)
                                
                                VStack(spacing: 12) {
                                    ForEach(category.features) { feature in
                                        FeatureCard(feature: feature) {
                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                                selectedService = feature.type
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            
            if let service = selectedService {
                LandServiceDetailView(service: service, onDismiss: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        selectedService = nil
                    }
                }, viewModel: viewModel)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 40, x: 0, y: 20)
    }
}

struct FeatureCard: View {
    let feature: QuickFeature
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            hapticFeedback(.medium)
            action()
        }) {
            HStack(spacing: 16) {
                // Icon with Vivid Gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [feature.color.opacity(0.8), feature.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                        .shadow(color: feature.color.opacity(0.25), radius: 6, x: 0, y: 3)
                    
                    Image(systemName: feature.icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(feature.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Text(feature.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.2))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(feature.color.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScaledButtonStyle())
    }
}

