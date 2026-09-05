//
//  DetailedReportIcons.swift
//  MyBhoomi
//
//  Vector icons precisely matching Figma node 773:1902 definitions.
//

import SwiftUI

public struct DetailedReportBackArrow: View {
    public var size: CGFloat = 24
    public var color: Color = Color(hex: "#000000")
    
    public init(size: CGFloat = 24, color: Color = Color(hex: "#000000")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            var path = Path()
            // Standard back arrow
            path.move(to: CGPoint(x: w * 0.65, y: h * 0.2))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.5))
            path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.8))
            
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}

public struct DetailedReportUsersIcon: View {
    public var size: CGFloat = 16
    public var color: Color = Color(hex: "#4F4F4F")
    
    public init(size: CGFloat = 16, color: Color = Color(hex: "#4F4F4F")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "person.3.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

public struct DetailedReportLandTypeIcon: View {
    public var size: CGFloat = 18
    public var color: Color = Color(hex: "#4F4F4F")
    
    public init(size: CGFloat = 18, color: Color = Color(hex: "#4F4F4F")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "house.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

public struct DetailedReportCirclesIcon: View {
    public var size: CGFloat = 18
    public var color: Color = Color(hex: "#4F4F4F")
    
    public init(size: CGFloat = 18, color: Color = Color(hex: "#4F4F4F")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "circle.grid.3x3.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

public struct DetailedReportFlagIcon: View {
    public var size: CGFloat = 16
    public var color: Color = Color(hex: "#222222")
    
    public init(size: CGFloat = 16, color: Color = Color(hex: "#222222")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "flag")
            .resizable()
            .scaledToFit()
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

public struct DetailedReportPDFDocBadge: View {
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "doc")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#444444"))
            
            Text("PDF")
                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                .foregroundColor(Color(hex: "#FF3B30"))
                .offset(x: 3, y: 2)
        }
        .frame(width: 20, height: 18)
    }
}

public struct DetailedReportCalendarIcon: View {
    public var size: CGFloat = 16
    public var color: Color = Color(hex: "#585858")
    
    public init(size: CGFloat = 16, color: Color = Color(hex: "#585858")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "calendar")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

public struct DetailedReportClockIcon: View {
    public var size: CGFloat = 16
    public var color: Color = Color(hex: "#585858")
    
    public init(size: CGFloat = 16, color: Color = Color(hex: "#585858")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "clock")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

public struct DetailedReportVerifiedCheck: View {
    public var size: CGFloat = 18
    
    public init(size: CGFloat = 18) {
        self.size = size
    }
    
    public var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(Color(hex: "#16A34A"))
            .frame(width: size, height: size)
    }
}

public struct DetailedReportLandAreaIcon: View {
    public var size: CGFloat = 16
    public var color: Color = Color(hex: "#4F4F4F")
    
    public init(size: CGFloat = 16, color: Color = Color(hex: "#4F4F4F")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "ruler.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

public struct DetailedReportShieldCheckIcon: View {
    public var size: CGFloat = 16
    public var color: Color = Color(hex: "#4F4F4F")
    
    public init(size: CGFloat = 16, color: Color = Color(hex: "#4F4F4F")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "shield.checkmark.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

public struct DetailedReportDocIcon: View {
    public var size: CGFloat = 16
    public var color: Color = Color(hex: "#4F4F4F")
    
    public init(size: CGFloat = 16, color: Color = Color(hex: "#4F4F4F")) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: "doc.text.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}
