import SwiftUI

public struct SplashScreenView: View {
    @Binding var isFinished: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.94
    @State private var showIndicator: Bool = false
    @State private var indicatorProgress: CGFloat = 0.0
    
    private let primaryBrandPurple = Color(red: 124/255, green: 58/255, blue: 237/255) // #7C3AED / Electric Violet
    private let trackLavender = Color(red: 237/255, green: 233/255, blue: 254/255)    // #EDE9FE / Soft Lavender
    
    public init(isFinished: Binding<Bool>) {
        self._isFinished = isFinished
    }
    
    public var body: some View {
        ZStack {
            // 1. Clean Canvas Background (Crisp pure white in light mode, sleek dark in dark mode)
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            // 2. Centered "preetyplot" Wordmark Logo
            VStack {
                Spacer()
                
                Image("PreetyplotLogo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 230)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Spacer()
            }
            
            // 3. Bottom Minimal Capsule Loading Indicator
            VStack {
                Spacer()
                
                ZStack(alignment: .leading) {
                    // Capsule Track
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.14) : trackLavender)
                        .frame(width: 56, height: 9.0)
                    
                    // Active Gliding Progress Pill
                    Capsule()
                        .fill(primaryBrandPurple)
                        .frame(width: max(9.0, 56 * indicatorProgress), height: 9.0)
                }
                .opacity(showIndicator ? 1.0 : 0.0)
                .padding(.bottom, 68)
            }
        }
        .onAppear {
            startSplashSequence()
        }
    }
    
    private func startSplashSequence() {
        // Step 1: Smooth Logo Appearance
        withAnimation(.easeOut(duration: 0.50)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Step 2: Show loading capsule indicator after 4.0 seconds of logo appearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.30)) {
                showIndicator = true
            }
            
            // Step 3: Animate the loading progress smoothly across the track
            withAnimation(.easeInOut(duration: 1.25)) {
                indicatorProgress = 1.0
            }
        }
        
        // Step 4: Complete loading and smoothly transition to home screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation(.easeInOut(duration: 0.50)) {
                isFinished = true
            }
        }
    }
}

#Preview {
    SplashScreenView(isFinished: .constant(false))
}
