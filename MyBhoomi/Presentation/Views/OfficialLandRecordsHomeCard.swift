import SwiftUI

/// Home screen card allowing users to search official land records directly from Odisha Bhulekh.
public struct OfficialLandRecordsHomeCard: View {
    public let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Leading Icon Container with Apple Liquid Glass styling
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.emeraldGreen.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.emeraldGreen)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 3) {
                    Text("Search Official Land Records")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("Find land records directly from Odisha Bhulekh")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Trailing Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.2))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(ScaledButtonStyle())
    }
}

#Preview {
    ZStack {
        Color(white: 0.9).ignoresSafeArea()
        OfficialLandRecordsHomeCard(action: {})
            .padding()
    }
}
