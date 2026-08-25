import SwiftUI

public struct ForceUpdateView: View {
    @ObservedObject var remoteConfig = RemoteConfigManager.shared
    
    private var appStoreURL: URL {
        URL(string: remoteConfig.appStoreURL) ?? URL(string: "https://apps.apple.com/app/bhumitra-odisha-land-records/id6742337788")!
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Dimmed semi-transparent blur backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            
            // Floating White Modal Card matching reference design
            VStack(spacing: 0) {
                // Top Graphic Illustration
                phoneGraphic
                    .padding(.top, 36)
                    .padding(.bottom, 24)
                
                // Title
                Text("Stay ahead!")
                    .font(.googleSans(size: 30, weight: .bold))
                    .foregroundColor(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)
                
                // Subtitle message from reference
                Text("more features, more improvements that\noutdated people doesn’t have")
                    .font(.googleSans(size: 14.5, weight: .regular))
                    .foregroundColor(Color(red: 0.28, green: 0.32, blue: 0.38))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                
                // Action Buttons
                VStack(spacing: 16) {
                    // "Update now" Primary Purple Capsule CTA Button
                    Button(action: openAppStore) {
                        Text("Update now")
                            .font(.googleSans(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                Capsule()
                                    .fill(Color(red: 102/255, green: 16/255, blue: 252/255))
                            )
                            .shadow(color: Color(red: 102/255, green: 16/255, blue: 252/255).opacity(0.35), radius: 14, x: 0, y: 6)
                    }
                    .buttonStyle(ScaledButtonStyle())
                    
                    // "Not now" Secondary Text Button
                    Button(action: {
                        Theme.haptic(.light)
                        Task {
                            await remoteConfig.fetchRemoteConfig(force: true)
                        }
                    }) {
                        Text("Not now")
                            .font(.googleSans(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.14))
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.20), radius: 30, x: 0, y: 12)
            )
            .padding(.horizontal, 24)
        }
        .interactiveDismissDisabled(true)
    }
    
    // MARK: - Phone Illustration Graphic
    private var phoneGraphic: some View {
        ZStack {
            // Left Blue Speech Bubble with Music Note
            ZStack {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(red: 32/255, green: 100/255, blue: 220/255))
                
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: -1, y: -2)
            }
            .offset(x: -78, y: -52)
            .shadow(color: Color(red: 32/255, green: 100/255, blue: 220/255).opacity(0.3), radius: 8, y: 3)
            
            // Right Green Flower / Plant Asset
            Image(systemName: "camera.macro")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(Color(red: 38/255, green: 168/255, blue: 78/255))
                .offset(x: 78, y: -54)
            
            // Phone Outline Frame
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(red: 0.90, green: 0.92, blue: 0.95), lineWidth: 3.5)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(red: 0.98, green: 0.985, blue: 0.995))
                )
                .frame(width: 175, height: 165)
                .overlay(alignment: .top) {
                    // Dynamic Island pill
                    Capsule()
                        .fill(Color(red: 0.84, green: 0.86, blue: 0.90))
                        .frame(width: 50, height: 11)
                        .padding(.top, 10)
                }
                .overlay {
                    // Floating Notification Banner matching reference
                    HStack(spacing: 8) {
                        // Avatar / Logo
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
                                .frame(width: 26, height: 26)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            HStack {
                                Text("Bhumitra")
                                    .font(.googleSans(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.16))
                                Spacer()
                                Text("1m ago")
                                    .font(.googleSans(size: 8, weight: .regular))
                                    .foregroundColor(Color.gray.opacity(0.8))
                            }
                            
                            Text("Gentle structure for your land")
                                .font(.googleSans(size: 8.5, weight: .medium))
                                .foregroundColor(Color(red: 0.40, green: 0.44, blue: 0.50))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                    )
                    .padding(.horizontal, 10)
                    .offset(y: 8)
                }
        }
        .frame(height: 165)
    }
    
    private func openAppStore() {
        Theme.haptic(.medium)
        if UIApplication.shared.canOpenURL(appStoreURL) {
            UIApplication.shared.open(appStoreURL)
        }
    }
}
