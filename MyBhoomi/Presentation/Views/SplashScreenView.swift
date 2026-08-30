import SwiftUI

public struct SplashScreenView: View {
    @Binding var isFinished: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var logoOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.78
    @State private var logoBlur: CGFloat = 18.0
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
            
            // 2. Centered "prettyplot" Wordmark Logo with Cinematic Blur-to-Sharp Reveal
            VStack {
                Spacer()
                
                Image("PreetyplotLogo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 230)
                    .scaleEffect(logoScale)
                    .blur(radius: logoBlur)
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
        // Step 1: Cinematic De-blur Scale-up Logo Appearance (From small & blurry to full size & sharp)
        withAnimation(.spring(response: 0.90, dampingFraction: 0.78)) {
            logoOpacity = 1.0
            logoScale = 1.0
            logoBlur = 0.0
        }
        
        // Step 2: Show loading capsule indicator after 4.0 seconds of logo appearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.35)) {
                showIndicator = true
            }
            
            // Step 3: Animate the loading progress smoothly and gracefully across the track (~2.8s duration)
            withAnimation(.easeInOut(duration: 2.8)) {
                indicatorProgress = 1.0
            }
        }
        
        // Step 4: Complete loading and smoothly cross-fade to home screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.2) {
            withAnimation(.easeInOut(duration: 0.55)) {
                isFinished = true
            }
        }
    }
}

#Preview {
    SplashScreenView(isFinished: .constant(false))
}
