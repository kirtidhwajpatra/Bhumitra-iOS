import SwiftUI

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
    
    let features: [QuickFeature] = [
        QuickFeature(title: "Offline Maps", subtitle: "Access maps without internet", icon: "map.fill", color: .green, type: .offlineMaps),
        QuickFeature(title: "View ROR", subtitle: "Official land ownership records", icon: "doc.text.fill", color: .blue, type: .viewRor),
        QuickFeature(title: "Downloaded ROR", subtitle: "Your recently saved records", icon: "arrow.down.circle.fill", color: .purple, type: .downloadedRor)
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
                        
                        Text("Instant access to your land data")
                            .font(.system(size: 15, weight: .medium))
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
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(features) { feature in
                            FeatureCard(feature: feature) {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    selectedService = feature.type
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
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
            HStack(spacing: 18) {
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
                        .frame(width: 52, height: 52)
                        .shadow(color: feature.color.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: feature.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Text(feature.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.black.opacity(0.05), Color.black.opacity(0.1))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(feature.color.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaledButtonStyle())
    }
}

