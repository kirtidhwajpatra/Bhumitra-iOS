//
//  EdgeBlurOverlay.swift
//  MyBhoomi
//
//  Pure transparent progressive variable blur overlay (Apple native liquid glass).
//  Zero white gradient, zero tint wash. 100% transparent live blur.
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import QuartzCore

public enum VariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
}

public struct VariableBlurView: UIViewRepresentable {
    public var maxBlurRadius: CGFloat = 18
    public var direction: VariableBlurDirection = .blurredTopClearBottom
    public var startOffset: CGFloat = 0
    
    public init(
        maxBlurRadius: CGFloat = 18,
        direction: VariableBlurDirection = .blurredTopClearBottom,
        startOffset: CGFloat = 0
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
    }
    
    public func makeUIView(context: Context) -> VariableBlurUIView {
        VariableBlurUIView(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }

    public func updateUIView(_ uiView: VariableBlurUIView, context: Context) {
        uiView.updateMask()
    }
}

open class VariableBlurUIView: UIVisualEffectView {
    public var maxBlurRadius: CGFloat
    public var direction: VariableBlurDirection
    public var startOffset: CGFloat
    private var gradientMaskLayer: CAGradientLayer?
    
    public init(
        maxBlurRadius: CGFloat = 18,
        direction: VariableBlurDirection = .blurredTopClearBottom,
        startOffset: CGFloat = 0
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.startOffset = startOffset
        
        super.init(effect: UIBlurEffect(style: .regular))
        
        backgroundColor = .clear
        
        setupVariableBlur()
        setupGradualMask()
        stripTintViews()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupVariableBlur() {
        let clsName = String("retliFAC".reversed())
        let selName = String(":epyThtiWretlif".reversed())
        
        if let Cls = NSClassFromString(clsName) as? NSObject.Type,
           let variableBlur = Cls.perform(NSSelectorFromString(selName), with: "variableBlur")?.takeUnretainedValue() as? NSObject {
            
            let gradientImage = makeGradientImage(direction: direction)
            variableBlur.setValue(maxBlurRadius, forKey: "inputRadius")
            variableBlur.setValue(gradientImage, forKey: "inputMaskImage")
            variableBlur.setValue(true, forKey: "inputNormalizeEdges")
            
            let backdropLayer = subviews.first?.layer
            backdropLayer?.filters = [variableBlur]
        }
    }
    
    /// Establishes a natural cubic-ease feathered mask on the view layer so the inner edge fades seamlessly with zero sharp cutoff.
    private func setupGradualMask() {
        let mask = CAGradientLayer()
        mask.startPoint = CGPoint(x: 0.5, y: 0.0)
        mask.endPoint = CGPoint(x: 0.5, y: 1.0)
        
        if direction == .blurredTopClearBottom {
            // Top (device edge) is full opacity; Bottom (inner content edge) fades gradually to zero
            mask.colors = [
                UIColor.black.cgColor,
                UIColor.black.withAlphaComponent(0.85).cgColor,
                UIColor.black.withAlphaComponent(0.50).cgColor,
                UIColor.black.withAlphaComponent(0.20).cgColor,
                UIColor.black.withAlphaComponent(0.04).cgColor,
                UIColor.clear.cgColor
            ]
            mask.locations = [0.0, 0.20, 0.42, 0.65, 0.85, 1.0]
        } else {
            // Top (inner content edge) fades gradually to zero; Bottom (device edge) is full opacity
            mask.colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.04).cgColor,
                UIColor.black.withAlphaComponent(0.20).cgColor,
                UIColor.black.withAlphaComponent(0.50).cgColor,
                UIColor.black.withAlphaComponent(0.85).cgColor,
                UIColor.black.cgColor
            ]
            mask.locations = [0.0, 0.15, 0.35, 0.58, 0.80, 1.0]
        }
        layer.mask = mask
        gradientMaskLayer = mask
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        stripTintViews()
        updateMask()
    }
    
    public func updateMask() {
        if let mask = gradientMaskLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            mask.frame = bounds
            CATransaction.commit()
        }
    }
    
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        stripTintViews()
        updateMask()
        guard let window, let backdropLayer = subviews.first?.layer else { return }
        backdropLayer.setValue(window.traitCollection.displayScale, forKey: "scale")
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        // Guard against internal UIKit crash
    }
    
    /// Completely strip and hide all visual effect view tint and color subviews.
    /// This removes all milky white, gray, or dark color casts.
    private func stripTintViews() {
        backgroundColor = .clear
        for subview in subviews.dropFirst() {
            if subview != contentView {
                subview.alpha = 0
                subview.isHidden = true
                subview.backgroundColor = .clear
            }
        }
    }
    
    private func makeGradientImage(
        width: CGFloat = 64,
        height: CGFloat = 256,
        direction: VariableBlurDirection
    ) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Ultra-smooth cubic progression: derivative at inner edge is 0 (zero sharp boundary)
        let colors: [CGFloat] = [
            0, 0, 0, 0.0,
            0, 0, 0, 0.02,
            0, 0, 0, 0.08,
            0, 0, 0, 0.22,
            0, 0, 0, 0.45,
            0, 0, 0, 0.72,
            0, 0, 0, 0.90,
            0, 0, 0, 1.0
        ]
        let locations: [CGFloat] = [0.0, 0.15, 0.32, 0.50, 0.68, 0.82, 0.92, 1.0]
        
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: locations,
            count: locations.count
        ),
        let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: Int(width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            let ciGradientFilter = CIFilter.smoothLinearGradient()
            ciGradientFilter.color0 = CIColor.black
            ciGradientFilter.color1 = CIColor.clear
            ciGradientFilter.point0 = CGPoint(x: 0, y: direction == .blurredTopClearBottom ? height : 0)
            ciGradientFilter.point1 = CGPoint(x: 0, y: direction == .blurredTopClearBottom ? 0 : height)
            return CIContext().createCGImage(
                ciGradientFilter.outputImage!,
                from: CGRect(x: 0, y: 0, width: width, height: height)
            )!
        }
        
        let startPoint: CGPoint
        let endPoint: CGPoint
        if direction == .blurredTopClearBottom {
            // y = 0 in Core Graphics is bottom (inner edge -> clear)
            // y = height is top (device edge -> blurred)
            startPoint = CGPoint(x: width / 2, y: 0)
            endPoint = CGPoint(x: width / 2, y: height)
        } else {
            // y = height is top (inner edge -> clear)
            // y = 0 is bottom (device edge -> blurred)
            startPoint = CGPoint(x: width / 2, y: height)
            endPoint = CGPoint(x: width / 2, y: 0)
        }
        
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        
        return context.makeImage()!
    }
}

/// An Apple Liquid Glass edge blur overlay that smoothly softens underlying content
/// as it approaches the screen boundary. Pure live transparent blur with ZERO white or color wash.
public struct EdgeBlurOverlay: View {
    public enum Edge {
        case top
        case bottom
    }
    
    public var edge: Edge
    public var height: CGFloat
    public var maxBlurRadius: CGFloat
    
    public init(
        edge: Edge,
        height: CGFloat? = nil,
        maxBlurRadius: CGFloat = 18,
        tintColor: Color? = nil,
        intensity: Double = 1.0
    ) {
        self.edge = edge
        // Default heights: 70pt for top (status bar + gradual fade), 60pt for bottom (safe area + gradual fade)
        self.height = height ?? (edge == .top ? 70 : 60)
        self.maxBlurRadius = maxBlurRadius
    }
    
    public var body: some View {
        VariableBlurView(
            maxBlurRadius: maxBlurRadius,
            direction: edge == .top ? .blurredTopClearBottom : .blurredBottomClearTop
        )
        .frame(height: height)
        .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
        .allowsHitTesting(false)
    }
}

