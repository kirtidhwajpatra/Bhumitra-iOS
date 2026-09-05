//
//  AppFeedbackManager.swift
//  MyBhoomi
//
//  Lightweight, production-ready App Store review prompt coordinator.
//  Strictly enforces Apple StoreKit guidelines and limits prompt opportunities to exactly 2.
//

import SwiftUI
import Combine
import StoreKit
import UIKit

public enum FeedbackOpportunity: Int, Codable {
    case first = 1
    case second = 2
    
    public var title: String {
        switch self {
        case .first:
            return "Enjoying MyBhoomi?"
        case .second:
            return "Could you help us out?"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .first:
            return "Help us make land searches better. A quick App Store rating really helps."
        case .second:
            return "Enjoying MyBhoomi? A quick App Store rating helps us keep improving the app."
        }
    }
    
    public var primaryButtonTitle: String {
        return "Rate MyBhoomi"
    }
    
    public var secondaryButtonTitle: String {
        switch self {
        case .first:
            return "Maybe later"
        case .second:
            return "Not now"
        }
    }
}

@MainActor
public final class AppFeedbackManager: ObservableObject {
    public static let shared = AppFeedbackManager()
    
    // Persistence Keys in UserDefaults
    private let kOpportunityCountKey = "mybhoomi_review_prompt_opportunity_count"
    private let kHasCompletedFeedbackKey = "mybhoomi_has_completed_feedback_flow"
    
    @Published public var isFeedbackPromptPresented: Bool = false
    @Published public var currentOpportunity: FeedbackOpportunity? = nil
    
    // In-memory debounce to prevent duplicate triggers for the same search result presentation
    private var lastPresentedResultId: String? = nil
    private var isEvaluating: Bool = false
    
    private let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// The number of feedback opportunities that have been presented (0, 1, or 2+).
    public var opportunityCount: Int {
        get {
            userDefaults.integer(forKey: kOpportunityCountKey)
        }
        set {
            userDefaults.set(newValue, forKey: kOpportunityCountKey)
        }
    }
    
    /// Whether the user has completed the feedback action (e.g. tapped "Rate MyBhoomi").
    public var hasCompletedFeedback: Bool {
        get {
            userDefaults.bool(forKey: kHasCompletedFeedbackKey)
        }
        set {
            userDefaults.set(newValue, forKey: kHasCompletedFeedbackKey)
        }
    }
    
    /// Whether a feedback prompt is eligible to be presented.
    public var canPresentFeedbackPrompt: Bool {
        guard !hasCompletedFeedback else { return false }
        guard opportunityCount < 2 else { return false }
        return true
    }
    
    /// Triggered ONLY when a search has succeeded, valid data is received, and the result is actually visible to the user.
    public func notifySuccessfulSearchResultPresented(resultId: String, animatedDelay: Double = 1.2) {
        // 1. Check eligibility
        guard canPresentFeedbackPrompt else { return }
        
        // 2. Prevent duplicate triggers for the same result presentation
        guard lastPresentedResultId != resultId else { return }
        guard !isFeedbackPromptPresented else { return }
        guard !isEvaluating else { return }
        
        lastPresentedResultId = resultId
        isEvaluating = true
        
        let nextOpportunityNumber = opportunityCount + 1
        guard let opportunity = FeedbackOpportunity(rawValue: nextOpportunityNumber) else {
            isEvaluating = false
            return
        }
        
        // 3. Mark the opportunity as presented in persistent storage
        opportunityCount = nextOpportunityNumber
        
        // 4. Smooth, natural delay so the user first absorbs the valid search result
        if animatedDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + animatedDelay) { [weak self] in
                guard let self = self else { return }
                self.isEvaluating = false
                guard self.hasCompletedFeedback == false else { return }
                
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    self.currentOpportunity = opportunity
                    self.isFeedbackPromptPresented = true
                }
            }
        } else {
            self.isEvaluating = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                self.currentOpportunity = opportunity
                self.isFeedbackPromptPresented = true
            }
        }
    }
    
    /// User tapped "Rate MyBhoomi"
    public func handleRate() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.isFeedbackPromptPresented = false
        }
        
        // Mark feedback as completed so we never prompt again
        self.hasCompletedFeedback = true
        self.opportunityCount = 2
        
        Theme.haptic(.medium)
        
        // Request Apple's official StoreKit review interface
        requestNativeAppStoreReview()
    }
    
    /// User tapped "Maybe later", "Not now", or closed the prompt
    public func handleDismiss() {
        Theme.haptic(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.isFeedbackPromptPresented = false
            self.currentOpportunity = nil
        }
    }
    
    /// Requests Apple's StoreKit review UI on the active window scene.
    public func requestNativeAppStoreReview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                if #available(iOS 18.0, *) {
                    AppStore.requestReview(in: windowScene)
                } else {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
        }
    }
    
    // For unit testing only
    public func resetForTesting() {
        userDefaults.removeObject(forKey: kOpportunityCountKey)
        userDefaults.removeObject(forKey: kHasCompletedFeedbackKey)
        lastPresentedResultId = nil
        isFeedbackPromptPresented = false
        currentOpportunity = nil
        isEvaluating = false
    }
}
