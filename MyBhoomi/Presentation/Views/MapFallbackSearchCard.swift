import SwiftUI

/// Fallback banner presented when cadastral tap, feature resolution, or RoR verification fails.
public struct MapFallbackSearchCard: View {
    public let district: String?
    public let tahasil: String?
    public let village: String?
    public let suggestedPlot: String?
    public let onSelectSearchMode: (ManualSearchMode) -> Void
    
    public init(
        district: String? = nil,
        tahasil: String? = nil,
        village: String? = nil,
        suggestedPlot: String? = nil,
        onSelectSearchMode: @escaping (ManualSearchMode) -> Void
    ) {
        self.district = district
        self.tahasil = tahasil
        self.village = village
        self.suggestedPlot = suggestedPlot
        self.onSelectSearchMode = onSelectSearchMode
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.primary)
                Text("Can't find this plot?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
            }
            
            Text("If the cadastral map could not identify the exact boundary, search the official Odisha land records directly.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(2)
            
            // Suggested Plot Pill (if available from vector feature)
            if let p = suggestedPlot, !p.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plot number found on map:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(p)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Theme.primary)
                    }
                    Spacer()
                    Button(action: {
                        onSelectSearchMode(.plot)
                    }) {
                        Text("Use \(p)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.primary)
                            .cornerRadius(10)
                    }
                }
                .padding(12)
                .background(Theme.primary.opacity(0.06))
                .cornerRadius(12)
            }
            
            // Search Actions Grid
            VStack(spacing: 8) {
                FallbackActionButton(
                    icon: "magnifyingglass",
                    title: "Search RoR Manually",
                    subtitle: "Select District → Tahasil → Village",
                    action: { onSelectSearchMode(.plot) }
                )
                
                FallbackActionButton(
                    icon: "doc.text.fill",
                    title: "Search by Khata Number",
                    subtitle: "Find all plots in a Khatiyan",
                    action: { onSelectSearchMode(.khata) }
                )
                
                FallbackActionButton(
                    icon: "qrcode",
                    title: "Search by Plot Unique ID",
                    subtitle: "Look up via official State unique code",
                    action: { onSelectSearchMode(.uniqueID) }
                )
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

struct FallbackActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.primary)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemGray6).opacity(0.6))
            .cornerRadius(12)
        }
    }
}
