import SwiftUI

/// Screen presented when user searches official land records directly from Odisha Bhulekh.
public struct OfficialLandRecordsView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.98).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Theme.emeraldGreen.opacity(0.12))
                            .frame(width: 92, height: 92)
                        
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundColor(Theme.emeraldGreen)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Official Land Records")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text("Search and view verified Record of Rights (RoR) directly from Odisha Bhulekh.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Land Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        hapticFeedback(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(Color.black.opacity(0.3))
                    }
                }
            }
        }
    }
}

#Preview {
    OfficialLandRecordsView()
}
