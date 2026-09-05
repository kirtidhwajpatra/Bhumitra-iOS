//
//  OverviewCardIcons.swift
//  MyBhoomi
//
//  Exact Vector Shapes from Figma Nodes 845:89 (SkeletonView) and 798:2420 (OverviewCard)
//

import SwiftUI

// MARK: - Rotating Yellow Star Badge (Figma #772:1659)
public struct SkeletonLoadingStarView: View {
    public var size: CGFloat = 27.59
    @State private var isRotating: Bool = false
    
    public init(size: CGFloat = 27.59) {
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let scaleX = canvasSize.width / 27.0
            let scaleY = canvasSize.height / 27.0
            
            var path = Path()
            // SVG Path: 27x27 star contour
            path.move(to: CGPoint(x: 12.13 * scaleX, y: 1.34 * scaleY))
            path.addLine(to: CGPoint(x: 14.87 * scaleX, y: 1.34 * scaleY))
            path.addLine(to: CGPoint(x: 15.77 * scaleX, y: 1.87 * scaleY))
            path.addLine(to: CGPoint(x: 17.93 * scaleX, y: 2.51 * scaleY))
            path.addLine(to: CGPoint(x: 18.97 * scaleX, y: 2.55 * scaleY))
            path.addLine(to: CGPoint(x: 21.28 * scaleX, y: 4.03 * scaleY))
            path.addLine(to: CGPoint(x: 21.75 * scaleX, y: 4.96 * scaleY))
            path.addLine(to: CGPoint(x: 23.23 * scaleX, y: 6.67 * scaleY))
            path.addLine(to: CGPoint(x: 24.08 * scaleX, y: 7.26 * scaleY))
            path.addLine(to: CGPoint(x: 25.22 * scaleX, y: 9.76 * scaleY))
            path.addLine(to: CGPoint(x: 25.11 * scaleX, y: 10.79 * scaleY))
            path.addLine(to: CGPoint(x: 25.43 * scaleX, y: 13.03 * scaleY))
            path.addLine(to: CGPoint(x: 25.83 * scaleX, y: 13.99 * scaleY))
            path.addLine(to: CGPoint(x: 25.44 * scaleX, y: 16.70 * scaleY))
            path.addLine(to: CGPoint(x: 24.79 * scaleX, y: 17.51 * scaleY))
            path.addLine(to: CGPoint(x: 23.85 * scaleX, y: 19.57 * scaleY))
            path.addLine(to: CGPoint(x: 23.66 * scaleX, y: 20.59 * scaleY))
            path.addLine(to: CGPoint(x: 21.86 * scaleX, y: 22.66 * scaleY))
            path.addLine(to: CGPoint(x: 20.88 * scaleX, y: 23.00 * scaleY))
            path.addLine(to: CGPoint(x: 18.98 * scaleX, y: 24.22 * scaleY))
            path.addLine(to: CGPoint(x: 18.27 * scaleX, y: 24.97 * scaleY))
            path.addLine(to: CGPoint(x: 15.64 * scaleX, y: 25.75 * scaleY))
            path.addLine(to: CGPoint(x: 14.63 * scaleX, y: 25.50 * scaleY))
            path.addLine(to: CGPoint(x: 12.37 * scaleX, y: 25.50 * scaleY))
            path.addLine(to: CGPoint(x: 11.36 * scaleX, y: 25.75 * scaleY))
            path.addLine(to: CGPoint(x: 8.73 * scaleX, y: 24.97 * scaleY))
            path.addLine(to: CGPoint(x: 8.02 * scaleX, y: 24.22 * scaleY))
            path.addLine(to: CGPoint(x: 6.12 * scaleX, y: 23.00 * scaleY))
            path.addLine(to: CGPoint(x: 5.14 * scaleX, y: 22.66 * scaleY))
            path.addLine(to: CGPoint(x: 3.34 * scaleX, y: 20.59 * scaleY))
            path.addLine(to: CGPoint(x: 3.15 * scaleX, y: 19.57 * scaleY))
            path.addLine(to: CGPoint(x: 2.21 * scaleX, y: 17.51 * scaleY))
            path.addLine(to: CGPoint(x: 1.56 * scaleX, y: 16.70 * scaleY))
            path.addLine(to: CGPoint(x: 1.17 * scaleX, y: 13.99 * scaleY))
            path.addLine(to: CGPoint(x: 1.57 * scaleX, y: 13.03 * scaleY))
            path.addLine(to: CGPoint(x: 1.89 * scaleX, y: 10.79 * scaleY))
            path.addLine(to: CGPoint(x: 1.78 * scaleX, y: 9.76 * scaleY))
            path.addLine(to: CGPoint(x: 2.92 * scaleX, y: 7.26 * scaleY))
            path.addLine(to: CGPoint(x: 3.77 * scaleX, y: 6.67 * scaleY))
            path.addLine(to: CGPoint(x: 5.25 * scaleX, y: 4.96 * scaleY))
            path.addLine(to: CGPoint(x: 5.72 * scaleX, y: 4.03 * scaleY))
            path.addLine(to: CGPoint(x: 8.03 * scaleX, y: 2.55 * scaleY))
            path.addLine(to: CGPoint(x: 9.06 * scaleX, y: 2.51 * scaleY))
            path.addLine(to: CGPoint(x: 11.23 * scaleX, y: 1.87 * scaleY))
            path.closeSubpath()
            
            // White fill
            context.fill(path, with: .color(.white))
            
            // Yellow Linear Gradient Stroke (#F4F4F4 -> #FFE100)
            let strokeGradient = Gradient(colors: [Color(hex: "#F4F4F4"), Color(hex: "#FFE100")])
            let shading = GraphicsContext.Shading.linearGradient(
                strokeGradient,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
            )
            context.stroke(path, with: shading, style: StrokeStyle(lineWidth: 1.89, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(isRotating ? 360 : 0))
        .onAppear {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
    }
}

// MARK: - Verified Green Seal Badge (Figma #845:97)
public struct OverviewVerifiedCheckView: View {
    public var size: CGFloat = 18.76
    
    public init(size: CGFloat = 18.76) {
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let scaleX = canvasSize.width / 18.0
            let scaleY = canvasSize.height / 18.0
            
            var sealPath = Path()
            // SVG Path: 18x18 seal contour
            sealPath.move(to: CGPoint(x: 7.92 * scaleX, y: 0.62 * scaleY))
            sealPath.addLine(to: CGPoint(x: 10.08 * scaleX, y: 0.62 * scaleY))
            sealPath.addLine(to: CGPoint(x: 10.68 * scaleX, y: 0.97 * scaleY))
            sealPath.addLine(to: CGPoint(x: 11.97 * scaleX, y: 1.35 * scaleY))
            sealPath.addLine(to: CGPoint(x: 12.66 * scaleX, y: 1.38 * scaleY))
            sealPath.addLine(to: CGPoint(x: 14.48 * scaleX, y: 2.54 * scaleY))
            sealPath.addLine(to: CGPoint(x: 14.79 * scaleX, y: 3.16 * scaleY))
            sealPath.addLine(to: CGPoint(x: 15.67 * scaleX, y: 4.18 * scaleY))
            sealPath.addLine(to: CGPoint(x: 16.24 * scaleX, y: 4.58 * scaleY))
            sealPath.addLine(to: CGPoint(x: 17.14 * scaleX, y: 6.54 * scaleY))
            sealPath.addLine(to: CGPoint(x: 17.06 * scaleX, y: 7.23 * scaleY))
            sealPath.addLine(to: CGPoint(x: 17.26 * scaleX, y: 8.56 * scaleY))
            sealPath.addLine(to: CGPoint(x: 17.52 * scaleX, y: 9.20 * scaleY))
            sealPath.addLine(to: CGPoint(x: 17.21 * scaleX, y: 11.34 * scaleY))
            sealPath.addLine(to: CGPoint(x: 16.78 * scaleX, y: 11.88 * scaleY))
            sealPath.addLine(to: CGPoint(x: 16.22 * scaleX, y: 13.11 * scaleY))
            sealPath.addLine(to: CGPoint(x: 16.09 * scaleX, y: 13.79 * scaleY))
            sealPath.addLine(to: CGPoint(x: 14.68 * scaleX, y: 15.42 * scaleY))
            sealPath.addLine(to: CGPoint(x: 14.02 * scaleX, y: 15.64 * scaleY))
            sealPath.addLine(to: CGPoint(x: 12.89 * scaleX, y: 16.37 * scaleY))
            sealPath.addLine(to: CGPoint(x: 12.42 * scaleX, y: 16.87 * scaleY))
            sealPath.addLine(to: CGPoint(x: 10.35 * scaleX, y: 17.48 * scaleY))
            sealPath.addLine(to: CGPoint(x: 9.67 * scaleX, y: 17.31 * scaleY))
            sealPath.addLine(to: CGPoint(x: 8.33 * scaleX, y: 17.31 * scaleY))
            sealPath.addLine(to: CGPoint(x: 7.65 * scaleX, y: 17.48 * scaleY))
            sealPath.addLine(to: CGPoint(x: 5.58 * scaleX, y: 16.87 * scaleY))
            sealPath.addLine(to: CGPoint(x: 5.11 * scaleX, y: 16.37 * scaleY))
            sealPath.addLine(to: CGPoint(x: 3.98 * scaleX, y: 15.64 * scaleY))
            sealPath.addLine(to: CGPoint(x: 3.32 * scaleX, y: 15.42 * scaleY))
            sealPath.addLine(to: CGPoint(x: 1.91 * scaleX, y: 13.79 * scaleY))
            sealPath.addLine(to: CGPoint(x: 1.78 * scaleX, y: 13.11 * scaleY))
            sealPath.addLine(to: CGPoint(x: 1.22 * scaleX, y: 11.88 * scaleY))
            sealPath.addLine(to: CGPoint(x: 0.79 * scaleX, y: 11.34 * scaleY))
            sealPath.addLine(to: CGPoint(x: 0.48 * scaleX, y: 9.20 * scaleY))
            sealPath.addLine(to: CGPoint(x: 0.74 * scaleX, y: 8.56 * scaleY))
            sealPath.addLine(to: CGPoint(x: 0.94 * scaleX, y: 7.23 * scaleY))
            sealPath.addLine(to: CGPoint(x: 0.87 * scaleX, y: 6.54 * scaleY))
            sealPath.addLine(to: CGPoint(x: 1.76 * scaleX, y: 4.58 * scaleY))
            sealPath.addLine(to: CGPoint(x: 2.33 * scaleX, y: 4.18 * scaleY))
            sealPath.addLine(to: CGPoint(x: 3.21 * scaleX, y: 3.16 * scaleY))
            sealPath.addLine(to: CGPoint(x: 3.52 * scaleX, y: 2.54 * scaleY))
            sealPath.addLine(to: CGPoint(x: 5.34 * scaleX, y: 1.38 * scaleY))
            sealPath.addLine(to: CGPoint(x: 6.03 * scaleX, y: 1.35 * scaleY))
            sealPath.addLine(to: CGPoint(x: 7.33 * scaleX, y: 0.97 * scaleY))
            sealPath.closeSubpath()
            
            // Fill Green (#00CA48)
            context.fill(sealPath, with: .color(Color(hex: "#00CA48")))
            
            // Subtle Green Gradient Stroke
            let greenGradient = Gradient(colors: [Color(hex: "#F4F4F4"), Color(hex: "#94FF81")])
            let shading = GraphicsContext.Shading.linearGradient(
                greenGradient,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
            )
            context.stroke(sealPath, with: shading, style: StrokeStyle(lineWidth: 0.65, lineCap: .round, lineJoin: .round))
            
            // Inner Checkmark
            var checkPath = Path()
            checkPath.move(to: CGPoint(x: 5.31 * scaleX, y: 9.28 * scaleY))
            checkPath.addLine(to: CGPoint(x: 7.97 * scaleX, y: 12.61 * scaleY))
            checkPath.addLine(to: CGPoint(x: 12.69 * scaleX, y: 5.53 * scaleY))
            
            context.stroke(
                checkPath,
                with: .color(.black),
                style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Standalone Verified Green Check Badge (Figma #893:2192)
public struct VerifiedSealBadgeView: View {
    public var size: CGFloat = 26
    
    public init(size: CGFloat = 26) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#00C259"))
            
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Owner Avatar Circle Icon (Figma #893:2192)
public struct OwnerAvatarCircleView: View {
    public var size: CGFloat = 24
    
    public init(size: CGFloat = 24) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#EFEFEF"))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundColor(Color(hex: "#757575"))
        }
        .frame(width: size, height: size)
    }
}

