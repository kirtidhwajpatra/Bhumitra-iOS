//
//  AppFeedbackPromptCardView.swift
//  MyBhoomi
//
//  Pixel-perfect implementation of App Store review request modal.
//  Matching Figma node 925:2236:
//  - 3D crystal purple star inside circular lavender badge
//  - "Enjoying Bhumitra?" headline typography
//  - "Rate Bhumitra ❤️" outlined purple capsule button
//  - "Maybe later" secondary action
//

import SwiftUI

public struct AppFeedbackPromptCardView: View {
    public let opportunity: FeedbackOpportunity
    @ObservedObject private var feedbackManager = AppFeedbackManager.shared
    
    // Purple accent matching Figma (#7412FA)
    private let electricPurple = Color(red: 116 / 255, green: 18 / 255, blue: 250 / 255)
    // Off-white to pure white gradient for circle backdrop
    private var starCircleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Theme.Color.dynamic(light: Color(hex: "#F4F4F6"), dark: Color(hex: "#2C2D36")),
                Theme.Color.dynamic(light: Color.white, dark: Color(hex: "#1E1F26"))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    // Outline button border
    private var outlineBorder: Color {
        Theme.Color.dynamic(
            light: Color(red: 221 / 255, green: 214 / 255, blue: 229 / 255),
            dark: Color.white.opacity(0.18)
        )
    }
    
    public init(opportunity: FeedbackOpportunity) {
        self.opportunity = opportunity
    }
    
    public var body: some View {
        ZStack {
            // Subtle Backdrop Overlay (Tap to dismiss)
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    feedbackManager.handleDismiss()
                }
            
            // Floating Modal Card (Figma 925:2236)
            VStack(spacing: 0) {
                // Top Close Button (Top-Right Xmark)
                HStack {
                    Spacer()
                    Button {
                        feedbackManager.handleDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Color.secondaryText)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss review request")
                }
                .padding(.top, 14)
                .padding(.trailing, 14)
                
                // 3D Purple Crystal Star Illustration in Absolute Center of Plain Gradient Circle
                ZStack(alignment: .center) {
                    Circle()
                        .fill(starCircleGradient)
                        .frame(width: 92, height: 92)
                    
                    Image("ReviewPromptStar")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 58, height: 58)
                }
                .frame(width: 92, height: 92)
                .padding(.top, 2)
                .padding(.bottom, 18)
                
                // Title
                Text(opportunity.title)
                    .font(.stackSansHeadline(size: 27, weight: .bold))
                    .foregroundColor(Theme.Color.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                
                // Subtitle
                Text(opportunity.subtitle)
                    .font(.system(size: 15.5, weight: .regular))
                    .foregroundColor(Theme.Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3.5)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Primary Action: "Rate Bhumitra ❤️" (Outline Capsule Button)
                    Button {
                        feedbackManager.handleRate()
                    } label: {
                        Text(opportunity.primaryButtonTitle)
                            .font(.stackSansHeadline(size: 18, weight: .bold))
                            .foregroundColor(electricPurple)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Theme.Color.surface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(outlineBorder, lineWidth: 1.8)
                            )
                    }
                    .buttonStyle(TactileGlassButtonStyle())
                    
                    // Secondary Action: "Maybe later" / "Not now" (Plain Text Button)
                    Button {
                        feedbackManager.handleDismiss()
                    } label: {
                        Text(opportunity.secondaryButtonTitle)
                            .font(.stackSansHeadline(size: 17, weight: .medium))
                            .foregroundColor(Theme.Color.primaryText.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: 336)
            .background(Theme.Color.surface)
            .cornerRadius(28)
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 8)
            .padding(.horizontal, 24)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .scale(scale: 0.94).combined(with: .opacity)
                )
            )
        }
        .zIndex(999)
    }
}
