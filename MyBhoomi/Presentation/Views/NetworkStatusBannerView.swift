import SwiftUI

/// Edge-to-edge connectivity strip pinned to the absolute top of the screen.
/// The colour fills the status-bar area and a slim label row sits just below
/// it: red while offline, amber while connecting or limited, green briefly
/// when the connection comes back. Place it as the FIRST item of a top-aligned
/// stack so the controls below slide down while it's visible.
public struct NetworkStatusBannerView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    public init() {}

    public var body: some View {
        Group {
            if let banner = networkMonitor.banner {
                strip(for: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.banner)
    }

    private func strip(for banner: NetworkBanner) -> some View {
        let style = Self.style(for: banner)
        return HStack(spacing: 6) {
            Image(systemName: style.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(style.text)
                .font(.system(size: 12.5, weight: .semibold))
        }
        .foregroundColor(style.foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .background(style.color.ignoresSafeArea(edges: .top))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private struct Style {
        let color: Color
        let foreground: Color
        let icon: String
        let text: String
    }

    private static func style(for banner: NetworkBanner) -> Style {
        switch banner {
        case .offline:
            return Style(color: Theme.Color.bhumitraError, foreground: .white,
                         icon: "wifi.slash", text: "No internet connection")
        case .connecting:
            return Style(color: Color(red: 245/255, green: 180/255, blue: 0/255), foreground: Color(red: 40/255, green: 30/255, blue: 0/255),
                         icon: "wifi.exclamationmark", text: "Connecting…")
        case .limited:
            return Style(color: Color(red: 245/255, green: 180/255, blue: 0/255), foreground: Color(red: 40/255, green: 30/255, blue: 0/255),
                         icon: "wifi.exclamationmark", text: "Limited connection · Low Data Mode")
        case .restored:
            return Style(color: Theme.Color.bhumitraSuccess, foreground: .white,
                         icon: "wifi", text: "Back online")
        }
    }
}
