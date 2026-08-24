import SwiftUI

// ============================================================
// MARK: - IN-MAP DENSE CADASTRAL PLOT NUMBERS DISCOVERY OVERLAY
// ============================================================

/// In-Map Cadastral Plot Numbers Discovery Loading Overlay.
/// Completely transparent canvas (zero dark backgrounds or borders).
/// Displays a rich, dense constellation of pure text revenue plot numbers
/// matching the exact font size, font style, and dark halo of map vector labels,
/// smoothly fading in and out across the entire screen in staggered calm waves.
public struct CadastralBoundaryDrawingOverlayView: View {
    @ObservedObject public var viewModel: MapViewModel
    
    // Rich, dense constellation of ~65 scattered plot numbers across the whole map
    private let plotItems: [ScatteredPlotItem] = [
        // Upper Viewport
        ScatteredPlotItem(number: "12", relX: 0.15, relY: 0.12, delay: 0.4, duration: 2.6),
        ScatteredPlotItem(number: "304", relX: 0.32, relY: 0.14, delay: 1.1, duration: 2.8),
        ScatteredPlotItem(number: "32", relX: 0.48, relY: 0.13, delay: 0.2, duration: 2.7),
        ScatteredPlotItem(number: "712", relX: 0.65, relY: 0.15, delay: 1.5, duration: 3.0),
        ScatteredPlotItem(number: "980", relX: 0.82, relY: 0.12, delay: 0.7, duration: 2.5),
        ScatteredPlotItem(number: "840", relX: 0.92, relY: 0.16, delay: 1.8, duration: 2.9),
        
        // Upper-Center Band
        ScatteredPlotItem(number: "45", relX: 0.08, relY: 0.22, delay: 1.3, duration: 2.8),
        ScatteredPlotItem(number: "218", relX: 0.22, relY: 0.24, delay: 0.5, duration: 2.7),
        ScatteredPlotItem(number: "138", relX: 0.38, relY: 0.21, delay: 1.7, duration: 3.1),
        ScatteredPlotItem(number: "53", relX: 0.54, relY: 0.23, delay: 0.1, duration: 2.6),
        ScatteredPlotItem(number: "330", relX: 0.70, relY: 0.22, delay: 1.4, duration: 2.9),
        ScatteredPlotItem(number: "50", relX: 0.86, relY: 0.25, delay: 0.9, duration: 2.8),
        
        // Mid-Upper Band
        ScatteredPlotItem(number: "20", relX: 0.14, relY: 0.32, delay: 0.3, duration: 2.7),
        ScatteredPlotItem(number: "156", relX: 0.28, relY: 0.31, delay: 1.6, duration: 3.0),
        ScatteredPlotItem(number: "581", relX: 0.44, relY: 0.33, delay: 0.8, duration: 2.8),
        ScatteredPlotItem(number: "410", relX: 0.60, relY: 0.30, delay: 1.9, duration: 3.2),
        ScatteredPlotItem(number: "75", relX: 0.76, relY: 0.34, delay: 0.4, duration: 2.6),
        ScatteredPlotItem(number: "67", relX: 0.90, relY: 0.32, delay: 1.2, duration: 2.9),
        
        // Center Band
        ScatteredPlotItem(number: "27", relX: 0.06, relY: 0.42, delay: 1.0, duration: 2.8),
        ScatteredPlotItem(number: "90", relX: 0.20, relY: 0.41, delay: 0.2, duration: 2.6),
        ScatteredPlotItem(number: "233", relX: 0.34, relY: 0.43, delay: 1.5, duration: 3.1),
        ScatteredPlotItem(number: "104", relX: 0.50, relY: 0.40, delay: 0.0, duration: 2.5),
        ScatteredPlotItem(number: "468", relX: 0.66, relY: 0.42, delay: 1.3, duration: 2.9),
        ScatteredPlotItem(number: "175", relX: 0.82, relY: 0.41, delay: 0.7, duration: 2.8),
        ScatteredPlotItem(number: "548", relX: 0.94, relY: 0.44, delay: 2.0, duration: 3.2),
        
        // Mid-Lower Band
        ScatteredPlotItem(number: "630", relX: 0.12, relY: 0.52, delay: 0.6, duration: 2.9),
        ScatteredPlotItem(number: "89", relX: 0.26, relY: 0.51, delay: 1.8, duration: 3.0),
        ScatteredPlotItem(number: "360", relX: 0.40, relY: 0.53, delay: 0.4, duration: 2.7),
        ScatteredPlotItem(number: "420", relX: 0.56, relY: 0.50, delay: 1.1, duration: 2.8),
        ScatteredPlotItem(number: "660", relX: 0.72, relY: 0.52, delay: 0.3, duration: 2.6),
        ScatteredPlotItem(number: "260", relX: 0.88, relY: 0.54, delay: 1.6, duration: 3.1),
        
        // Lower-Center Band
        ScatteredPlotItem(number: "116", relX: 0.08, relY: 0.63, delay: 1.4, duration: 2.9),
        ScatteredPlotItem(number: "248", relX: 0.22, relY: 0.62, delay: 0.7, duration: 2.7),
        ScatteredPlotItem(number: "378", relX: 0.36, relY: 0.64, delay: 2.1, duration: 3.3),
        ScatteredPlotItem(number: "515", relX: 0.52, relY: 0.61, delay: 0.5, duration: 2.8),
        ScatteredPlotItem(number: "97", relX: 0.68, relY: 0.63, delay: 1.2, duration: 2.9),
        ScatteredPlotItem(number: "83", relX: 0.84, relY: 0.62, delay: 0.1, duration: 2.5),
        ScatteredPlotItem(number: "695", relX: 0.93, relY: 0.65, delay: 1.7, duration: 3.0),
        
        // Lower Band
        ScatteredPlotItem(number: "142", relX: 0.16, relY: 0.73, delay: 0.8, duration: 2.8),
        ScatteredPlotItem(number: "290", relX: 0.30, relY: 0.75, delay: 1.9, duration: 3.2),
        ScatteredPlotItem(number: "1060", relX: 0.46, relY: 0.72, delay: 0.3, duration: 2.6),
        ScatteredPlotItem(number: "595", relX: 0.62, relY: 0.74, delay: 1.5, duration: 3.0),
        ScatteredPlotItem(number: "748", relX: 0.78, relY: 0.73, delay: 0.9, duration: 2.8),
        ScatteredPlotItem(number: "875", relX: 0.90, relY: 0.76, delay: 0.2, duration: 2.7),
        
        // Bottom Edge
        ScatteredPlotItem(number: "190", relX: 0.10, relY: 0.84, delay: 1.6, duration: 3.1),
        ScatteredPlotItem(number: "345", relX: 0.26, relY: 0.86, delay: 0.4, duration: 2.7),
        ScatteredPlotItem(number: "450", relX: 0.42, relY: 0.83, delay: 1.3, duration: 2.9),
        ScatteredPlotItem(number: "610", relX: 0.58, relY: 0.85, delay: 0.6, duration: 2.8),
        ScatteredPlotItem(number: "765", relX: 0.74, relY: 0.84, delay: 1.8, duration: 3.1),
        ScatteredPlotItem(number: "1025", relX: 0.88, relY: 0.87, delay: 1.0, duration: 2.9)
    ]
    
    public init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            if viewModel.isDrawingBoundaryLoading {
                GeometryReader { geo in
                    let size = geo.size
                    
                    ZStack {
                        ForEach(plotItems) { item in
                            PurePlotNumberLabelView(
                                item: item,
                                position: CGPoint(
                                    x: size.width * item.relX,
                                    y: size.height * item.relY
                                )
                            )
                        }
                    }
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.60)))
                .allowsHitTesting(false)
            }
        }
    }
}

// ============================================================
// MARK: - SCATTERED PLOT ITEM MODEL
// ============================================================

private struct ScatteredPlotItem: Identifiable {
    let id = UUID()
    let number: String
    let relX: CGFloat
    let relY: CGFloat
    let delay: Double
    let duration: Double
}

// ============================================================
// MARK: - PURE PLOT NUMBER LABEL VIEW (EXACT MAP LABEL STYLING)
// ============================================================

/// Renders pure text numbers matching MapLibre's parcel-labels layer:
/// 12pt bold font, crisp white text, and dark halo with synchronized 1:1 opacity fade.
private struct PurePlotNumberLabelView: View {
    let item: ScatteredPlotItem
    let position: CGPoint
    
    @State private var opacity: Double = 0.0
    
    var body: some View {
        Text(item.number)
            .font(.system(size: 12, weight: .bold, design: .default))
            .foregroundColor(Color.white.opacity(opacity))
            // Dark halo shadow perfectly synchronized 1:1 with text opacity
            .shadow(color: Color.black.opacity(0.95 * opacity), radius: 0.8, x: 1, y: 1)
            .shadow(color: Color.black.opacity(0.95 * opacity), radius: 0.8, x: -1, y: -1)
            .shadow(color: Color.black.opacity(0.95 * opacity), radius: 0.8, x: 1, y: -1)
            .shadow(color: Color.black.opacity(0.95 * opacity), radius: 0.8, x: -1, y: 1)
            .compositingGroup()
            .opacity(opacity)
            .position(position)
            .onAppear {
                startSlowBreathingAnimation()
            }
    }
    
    private func startSlowBreathingAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + item.delay) {
            withAnimation(.easeInOut(duration: item.duration / 2.0).repeatForever(autoreverses: true)) {
                opacity = 0.95
            }
        }
    }
}
