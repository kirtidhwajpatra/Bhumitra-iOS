//
//  AppFeedbackPromptCardView.swift
//  MyBhoomi
//
//  Lightweight, non-intrusive App Store review prompt card.
//  Matches MyBhoomi's #7600FF brand purple, StackSans/Google Sans typography,
//  and tactile liquid glass aesthetic.
//

import SwiftUI

public struct AppFeedbackPromptCardView: View {
    public let opportunity: FeedbackOpportunity
    @ObservedObject private var feedbackManager = AppFeedbackManager.shared
    
    public init(opportunity: FeedbackOpportunity) {
        self.opportunity = opportunity
    }
    
    public var body: some View {
        ZStack {
            // Subtle Backdrop (Tap to dismiss without interrupting search result)
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    feedbackManager.handleDismiss()
                }
            
            // Floating Card Container
            VStack(spacing: 0) {
                // Top Close Button Row
                HStack {
                    Spacer()
                    Button {
                        feedbackManager.handleDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7C7"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss feedback prompt")
                }
                .padding(.top, 14)
                .padding(.trailing, 14)
                
                // Icon / Star Badge Header
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#8B24FF"), Color(hex: "#7600FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: Color(hex: "#7600FF").opacity(0.35), radius: 10, x: 0, y: 4)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.top, -6)
                .padding(.bottom, 12)
                
                // Title
                Text(opportunity.title)
                    .font(.stackSansHeadline(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "#050505"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                
                // Subtitle
                Text(opportunity.subtitle)
                    .font(.system(size: 14.2, weight: .regular, design: .default))
                    .foregroundColor(Color(hex: "#606060"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2.5)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
                
                // Action Buttons
                VStack(spacing: 10) {
                    // Primary Rate Action
                    Button {
                        feedbackManager.handleRate()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 14, weight: .semibold))
                            
                            Text(opportunity.primaryButtonTitle)
                                .font(.stackSansHeadline(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#8A20FF"), Color(hex: "#7600FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "#7600FF").opacity(0.30), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    
                    // Secondary Skip / Later Action
                    Button {
                        feedbackManager.handleDismiss()
                    } label: {
                        Text(opportunity.secondaryButtonTitle)
                            .font(.stackSansHeadline(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "#5A5A5A"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#E0E0E0"), lineWidth: 1.2)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: 328)
            .background(Color.white)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
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
