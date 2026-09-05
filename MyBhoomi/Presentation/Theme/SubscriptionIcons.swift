//
//  SubscriptionIcons.swift
//  MyBhoomi
//
//  Vector-precise icons matching Figma definitions for SubscriptionScreen.
//

import SwiftUI

/// Vector checkmark matching Figma node #772:617 / #772:619
public struct SubscriptionCheckmarkShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        // Reference viewBox: 0 0 13 12
        // d="M0.927707 6.30395L4.7427 11.0727L11.5056 0.928204"
        let scaleX = rect.width / 13.0
        let scaleY = rect.height / 12.0
        
        path.move(to: CGPoint(x: 0.9277 * scaleX, y: 6.3039 * scaleY))
        path.addLine(to: CGPoint(x: 4.7427 * scaleX, y: 11.0727 * scaleY))
        path.addLine(to: CGPoint(x: 11.5056 * scaleX, y: 0.9282 * scaleY))
        
        return path
    }
}

public struct SubscriptionCheckmarkIcon: View {
    public var strokeColor: Color = Color(hex: "#616161")
    public var lineWidth: CGFloat = 1.85
    public var size: CGSize = CGSize(width: 11.5, height: 11)
    
    public init(strokeColor: Color = Color(hex: "#616161"), lineWidth: CGFloat = 1.85, size: CGSize = CGSize(width: 11.5, height: 11)) {
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.size = size
    }
    
    public var body: some View {
        SubscriptionCheckmarkShape()
            .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size.width, height: size.height)
    }
}

/// Circular Yellow Corner Badge with Checkmark (Figma node #772:1617)
public struct SubscriptionSelectedBadge: View {
    public var size: CGFloat = 24
    
    public init(size: CGFloat = 24) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#FFEC64"))
                .frame(width: size, height: size)
            
            SubscriptionCheckmarkShape()
                .stroke(Color.black, style: StrokeStyle(lineWidth: 1.83, lineCap: .round, lineJoin: .round))
                .frame(width: 11.5, height: 11)
        }
    }
}

/// Close 'X' Button Vector (Figma node #772:626)
public struct SubscriptionCloseIcon: View {
    public var color: Color = Color(hex: "#747474")
    public var lineWidth: CGFloat = 2.42
    public var size: CGFloat = 18
    
    public init(color: Color = Color(hex: "#747474"), lineWidth: CGFloat = 2.42, size: CGFloat = 18) {
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            var p1 = Path()
            p1.move(to: CGPoint(x: 0, y: 0))
            p1.addLine(to: CGPoint(x: w, y: h))
            
            var p2 = Path()
            p2.move(to: CGPoint(x: 0, y: h))
            p2.addLine(to: CGPoint(x: w, y: 0))
            
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            context.stroke(p1, with: .color(color), style: style)
            context.stroke(p2, with: .color(color), style: style)
        }
        .frame(width: size, height: size)
    }
}
