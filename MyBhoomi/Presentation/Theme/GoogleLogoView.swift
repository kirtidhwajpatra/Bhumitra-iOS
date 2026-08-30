import SwiftUI

// ============================================================
// MARK: - OFFICIAL GOOGLE 4-COLOR LOGO VECTOR (PIXEL-PERFECT)
// ============================================================

/// Pixel-accurate vector Google 'G' icon using official Google brand colors and standard 24x24 viewBox.
public struct GoogleLogoView: View {
    public var size: CGFloat = 20
    
    public init(size: CGFloat = 20) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            GoogleRedShape()
                .fill(Color(red: 234/255, green: 67/255, blue: 53/255))
            GoogleYellowShape()
                .fill(Color(red: 251/255, green: 188/255, blue: 5/255))
            GoogleGreenShape()
                .fill(Color(red: 52/255, green: 168/255, blue: 83/255))
            GoogleBlueShape()
                .fill(Color(red: 66/255, green: 133/255, blue: 244/255))
        }
        .frame(width: size, height: size)
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Shapes

struct GoogleBlueShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        
        path.move(to: CGPoint(x: 23.49 * sx, y: 12.28 * sy))
        path.addCurve(
            to: CGPoint(x: 23.30 * sx, y: 10.00 * sy),
            control1: CGPoint(x: 23.49 * sx, y: 11.50 * sy),
            control2: CGPoint(x: 23.41 * sx, y: 10.74 * sy)
        )
        path.addLine(to: CGPoint(x: 12.00 * sx, y: 10.00 * sy))
        path.addLine(to: CGPoint(x: 12.00 * sx, y: 14.58 * sy))
        path.addLine(to: CGPoint(x: 18.47 * sx, y: 14.58 * sy))
        path.addCurve(
            to: CGPoint(x: 16.13 * sx, y: 18.06 * sy),
            control1: CGPoint(x: 18.18 * sx, y: 15.99 * sy),
            control2: CGPoint(x: 17.34 * sx, y: 17.24 * sy)
        )
        path.addLine(to: CGPoint(x: 19.98 * sx, y: 21.05 * sy))
        path.addCurve(
            to: CGPoint(x: 23.49 * sx, y: 12.28 * sy),
            control1: CGPoint(x: 22.21 * sx, y: 18.99 * sy),
            control2: CGPoint(x: 23.49 * sx, y: 15.93 * sy)
        )
        path.closeSubpath()
        return path
    }
}

struct GoogleGreenShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        
        path.move(to: CGPoint(x: 12.00 * sx, y: 24.00 * sy))
        path.addCurve(
            to: CGPoint(x: 19.98 * sx, y: 21.05 * sy),
            control1: CGPoint(x: 15.24 * sx, y: 24.00 * sy),
            control2: CGPoint(x: 17.97 * sx, y: 22.92 * sy)
        )
        path.addLine(to: CGPoint(x: 16.13 * sx, y: 18.06 * sy))
        path.addCurve(
            to: CGPoint(x: 12.00 * sx, y: 19.25 * sy),
            control1: CGPoint(x: 15.05 * sx, y: 18.78 * sy),
            control2: CGPoint(x: 13.66 * sx, y: 19.25 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.38 * sx, y: 14.44 * sy),
            control1: CGPoint(x: 8.93 * sx, y: 19.25 * sy),
            control2: CGPoint(x: 6.31 * sx, y: 17.22 * sy)
        )
        path.addLine(to: CGPoint(x: 1.45 * sx, y: 17.49 * sy))
        path.addCurve(
            to: CGPoint(x: 12.00 * sx, y: 24.00 * sy),
            control1: CGPoint(x: 3.40 * sx, y: 21.35 * sy),
            control2: CGPoint(x: 7.37 * sx, y: 24.00 * sy)
        )
        path.closeSubpath()
        return path
    }
}

struct GoogleYellowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        
        path.move(to: CGPoint(x: 5.38 * sx, y: 14.44 * sy))
        path.addCurve(
            to: CGPoint(x: 5.00 * sx, y: 12.00 * sy),
            control1: CGPoint(x: 5.14 * sx, y: 13.72 * sy),
            control2: CGPoint(x: 5.00 * sx, y: 12.96 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.38 * sx, y: 9.56 * sy),
            control1: CGPoint(x: 5.00 * sx, y: 11.04 * sy),
            control2: CGPoint(x: 5.14 * sx, y: 10.28 * sy)
        )
        path.addLine(to: CGPoint(x: 1.45 * sx, y: 6.51 * sy))
        path.addCurve(
            to: CGPoint(x: 0.00 * sx, y: 12.00 * sy),
            control1: CGPoint(x: 0.53 * sx, y: 8.35 * sy),
            control2: CGPoint(x: 0.00 * sx, y: 10.42 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 1.45 * sx, y: 17.49 * sy),
            control1: CGPoint(x: 0.00 * sx, y: 13.58 * sy),
            control2: CGPoint(x: 0.53 * sx, y: 15.65 * sy)
        )
        path.addLine(to: CGPoint(x: 5.38 * sx, y: 14.44 * sy))
        path.closeSubpath()
        return path
    }
}

struct GoogleRedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 24.0
        let sy = rect.height / 24.0
        
        path.move(to: CGPoint(x: 12.00 * sx, y: 4.75 * sy))
        path.addCurve(
            to: CGPoint(x: 16.58 * sx, y: 6.54 * sy),
            control1: CGPoint(x: 13.72 * sx, y: 4.75 * sy),
            control2: CGPoint(x: 15.26 * sx, y: 5.34 * sy)
        )
        path.addLine(to: CGPoint(x: 20.00 * sx, y: 3.12 * sy))
        path.addCurve(
            to: CGPoint(x: 12.00 * sx, y: 0.00 * sy),
            control1: CGPoint(x: 17.89 * sx, y: 1.15 * sy),
            control2: CGPoint(x: 15.11 * sx, y: 0.00 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 1.45 * sx, y: 6.51 * sy),
            control1: CGPoint(x: 7.37 * sx, y: 0.00 * sy),
            control2: CGPoint(x: 3.40 * sx, y: 2.65 * sy)
        )
        path.addLine(to: CGPoint(x: 5.38 * sx, y: 9.56 * sy))
        path.addCurve(
            to: CGPoint(x: 12.00 * sx, y: 4.75 * sy),
            control1: CGPoint(x: 6.31 * sx, y: 6.78 * sy),
            control2: CGPoint(x: 8.93 * sx, y: 4.75 * sy)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    GoogleLogoView(size: 32)
        .padding()
}
