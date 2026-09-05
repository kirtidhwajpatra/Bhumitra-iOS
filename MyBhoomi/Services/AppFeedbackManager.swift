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
            return "Enjoying Bhumitra?"
        case .second:
            return "Could you help us out?"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .first:
            return "Help us make land searches better.\nA quick App Store rating really helps."
        case .second:
            return "Enjoying Bhumitra? A quick App Store rating helps us keep improving the app."
        }
    }
    
    public var primaryButtonTitle: String {
        return "Rate Bhumitra ❤️"
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.isFeedbackPromptPresented = false
            self.currentOpportunity = nil
        }
    }
    
    /// Safely finds the currently active foreground UIWindowScene.
    /// Returns nil if no active foreground scene exists, without crashing or passing an arbitrary background scene.
    public func findActiveForegroundWindowScene() -> UIWindowScene? {
        let activeScene = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first
        
        #if DEBUG
        if activeScene == nil {
            print("[AppFeedbackManager] DEBUG: No active foreground UIWindowScene available for StoreKit review request.")
        }
        #endif
        
        return activeScene
    }
    
    /// Requests Apple's StoreKit review UI on the active window scene after card dismissal completes.
    public func requestNativeAppStoreReview() {
        // Delay slightly (0.45s) so the custom prompt card dismissal animation completes cleanly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self = self else { return }
            guard let windowScene = self.findActiveForegroundWindowScene() else {
                return
            }
            
            #if DEBUG
            print("[AppFeedbackManager] DEBUG: Requesting native StoreKit review on active foreground UIWindowScene: \(windowScene)")
            #endif
            
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: windowScene)
            } else {
                SKStoreReviewController.requestReview(in: windowScene)
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
