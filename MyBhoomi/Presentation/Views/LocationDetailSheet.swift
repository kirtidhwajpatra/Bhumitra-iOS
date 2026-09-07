import SwiftUI

struct LocationDetailSheet: View {
    let locationInfo: LocalAdminClient.LocationInfo
    let onDismiss: () -> Void
    @ObservedObject var viewModel: MapViewModel
    
    init(locationInfo: LocalAdminClient.LocationInfo, viewModel: MapViewModel, onDismiss: @escaping () -> Void) {
        self.locationInfo = locationInfo
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.Color.secondaryText.opacity(0.4))
                }
                .padding(16)
            }
            
            VStack(spacing: 24) {
                // Header Section
                VStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 40))
                            .foregroundColor(primaryPurple)
                            .padding(.bottom, 8)
                            
                        Text("LOCATION INFO")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(primaryPurple)
                            .tracking(2)
                        
                        Text(locationInfo.village.uppercased())
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Theme.Color.primaryText)
                            .multilineTextAlignment(.center)
                        
                        Rectangle()
                            .fill(Theme.Color.separator)
                            .frame(height: 1)
                            .frame(width: 140)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 10)
                
                // Details List
                VStack(spacing: 0) {
                    ModernRow(label: "District", value: locationInfo.district)
                    Divider().background(Theme.Color.separator).padding(.horizontal, 16)
                    ModernRow(label: "Tehsil", value: locationInfo.tehsil)
                    Divider().background(Theme.Color.separator).padding(.horizontal, 16)
                    ModernRow(label: "Panchayat", value: locationInfo.panchayat)
                    Divider().background(Theme.Color.separator).padding(.horizontal, 16)
                    ModernRow(label: "Village Code", value: locationInfo.village_code)
                }
                .background(Theme.Color.surface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.Color.border, lineWidth: 1)
                )
                
                // Informational Note
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(primaryPurple)
                    Text("Select a specific plot boundary on the map to view ownership records (RoR) and download official documents.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding(16)
                .background(primaryPurple.opacity(0.05))
                .cornerRadius(16)
                
                Button(action: {
                    onDismiss()
                }) {
                    Text("Got it")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(primaryPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.15), radius: 40, x: 0, y: 20)
    }
}
