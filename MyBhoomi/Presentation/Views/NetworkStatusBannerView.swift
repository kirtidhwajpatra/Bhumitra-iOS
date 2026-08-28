import SwiftUI

/// Top status bar tint and auto-retracting notification banner
public struct NetworkStatusBannerView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Drop notification banner (extends down below status bar for 3.5s then retracts)
            if networkMonitor.showDropBanner {
                Text(networkMonitor.dropBannerText)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 2)
                    .padding(.bottom, 4.5)
                    .frame(maxWidth: .infinity)
                    .background(networkMonitor.dropBannerColor)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .background {
            if let color = networkMonitor.statusBarColor {
                color
                    .ignoresSafeArea(edges: .top)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: networkMonitor.showDropBanner)
        .animation(.easeInOut(duration: 0.35), value: networkMonitor.statusBarColor)
    }
}
