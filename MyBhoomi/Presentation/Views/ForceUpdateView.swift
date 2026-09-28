import SwiftUI
import UIKit

public struct ForceUpdateView: View {
    @ObservedObject var remoteConfig = RemoteConfigManager.shared
    
    private var appStoreURL: URL {
        URL(string: remoteConfig.appStoreURL) ?? URL(string: "https://apps.apple.com/in/app/bhumitra/id6760656162")!
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Dimmed semi-transparent backdrop
            Theme.Color.bhumitraOverlay
                .ignoresSafeArea()
            
            // Floating Modal Card
            VStack(spacing: 0) {
                // Top Graphic Illustration Asset with robust multi-layer fallback
                illustrationView
                
                // Title
                Text("Stay ahead!")
                    .font(.googleSans(size: 30, weight: .bold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                
                // Subtitle message from reference design
                Text("more features, more improvements that\noutdated people doesn’t have")
                    .font(.googleSans(size: 14.5, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                
                // Action Buttons
                VStack(spacing: 14) {
                    // "Update now" Primary Button (Matching Plot Bottom Sheet CTA style)
                    Button(action: openAppStore) {
                        Text("Update now")
                    }
                    .buttonStyle(.primaryCTA)
                    
                    // "Not now" Secondary Button (Only displayed if update is NOT mandatory)
                    if !remoteConfig.isMandatoryUpdate {
                        Button(action: {
                            remoteConfig.dismissForSession()
                        }) {
                            Text("Not now")
                                .font(.googleSans(size: 15, weight: .bold))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(Theme.Color.bhumitraSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 38, style: .continuous)
                            .stroke(Theme.Color.bhumitraBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.20), radius: 30, x: 0, y: 12)
            )
            .padding(.horizontal, 24)
        }
        .interactiveDismissDisabled(true)
    }
    
    @ViewBuilder
    private var illustrationView: some View {
        if let uiImage = loadIllustrationImage() {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 240, maxHeight: 190)
                .padding(.top, 32)
                .padding(.bottom, 16)
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 50, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimary)
                .frame(width: 240, height: 160)
                .padding(.top, 32)
                .padding(.bottom, 16)
        }
    }
    
    private func loadIllustrationImage() -> UIImage? {
        if let img = UIImage(named: "force_update_illustration") {
            return img
        }
        if let img = UIImage(named: "ForceUpdateIllustration") {
            return img
        }
        if let bundlePath = Bundle.main.path(forResource: "force_update_illustration", ofType: "png"),
           let img = UIImage(contentsOfFile: bundlePath) {
            return img
        }
        return nil
    }
    
    private func openAppStore() {
        // Direct App Store protocol for seamless opening
        if let itmsURL = URL(string: "itms-apps://apps.apple.com/app/id6760656162"), UIApplication.shared.canOpenURL(itmsURL) {
            UIApplication.shared.open(itmsURL, options: [:], completionHandler: nil)
        } else if let httpsURL = URL(string: "https://apps.apple.com/in/app/bhumitra/id6760656162") {
            UIApplication.shared.open(httpsURL, options: [:], completionHandler: nil)
        }
    }
}
