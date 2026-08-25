import SwiftUI

public struct ForceUpdateView: View {
    @ObservedObject var remoteConfig = RemoteConfigManager.shared
    
    private var appStoreURL: URL {
        URL(string: remoteConfig.appStoreURL) ?? URL(string: "https://apps.apple.com/app/bhumitra-odisha-land-records/id6742337788")!
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Clean Canvas Background
            LinearGradient(
                colors: [Theme.Color.canvasTop, Theme.Color.canvasBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // App Update Icon Badge
                ZStack {
                    Circle()
                        .fill(Theme.Color.primary.opacity(0.08))
                        .frame(width: 110, height: 110)
                    
                    Circle()
                        .fill(Theme.Color.primary.opacity(0.14))
                        .frame(width: 86, height: 86)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(Theme.Color.primary)
                }
                .padding(.bottom, Theme.Spacing.xxl)
                
                // Heading
                Text("New Update Available")
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Color.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Theme.Spacing.sm)
                
                // Concise single-line message
                Text("The app got even better functionality and features.\nWant to try? Update it now.")
                    .font(Theme.Typography.secondaryBodyMedium)
                    .foregroundColor(Theme.Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.lg)
                
                // Version Badge (Current -> Target)
                HStack(spacing: 8) {
                    Text("v\(remoteConfig.currentAppVersion)")
                        .font(Theme.Typography.captionMedium)
                        .foregroundColor(Theme.Color.tertiaryText)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.Color.tertiaryText)
                    
                    Text("v\(remoteConfig.latestVersion)")
                        .font(Theme.Typography.captionMedium)
                        .foregroundColor(Theme.Color.primary)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Color.primaryLight)
                .clipShape(Capsule())
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: Theme.Spacing.md) {
                    Button(action: openAppStore) {
                        HStack(spacing: 8) {
                            Text("Update Now")
                                .font(Theme.Typography.buttonBold)
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                        .shadow(color: Theme.Shadow.primaryGlow, radius: 14, x: 0, y: 6)
                    }
                    .buttonStyle(ScaledButtonStyle())
                    
                    Button(action: {
                        Task {
                            await remoteConfig.fetchRemoteConfig(force: true)
                        }
                    }) {
                        HStack(spacing: 6) {
                            if remoteConfig.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text("Check Again")
                                .font(Theme.Typography.captionMedium)
                        }
                        .foregroundColor(Theme.Color.tertiaryText)
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .interactiveDismissDisabled(true)
    }
    
    private func openAppStore() {
        Theme.haptic(.medium)
        if UIApplication.shared.canOpenURL(appStoreURL) {
            UIApplication.shared.open(appStoreURL)
        }
    }
}
