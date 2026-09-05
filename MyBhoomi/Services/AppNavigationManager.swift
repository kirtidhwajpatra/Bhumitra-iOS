//
//  AppNavigationManager.swift
//  MyBhoomi
//
//  Centralized Navigation Coordinator for Unified Bottom Dock & Global Navigation
//

import SwiftUI
import Combine

@MainActor
public final class AppNavigationManager: ObservableObject {
    public static let shared = AppNavigationManager()
    
    @Published public var selectedTab: AppTab = .home
    
    private init() {}
    
    public func navigate(to tab: AppTab) {
        withAnimation(BhumitraMotion.tabSwitch) {
            self.selectedTab = tab
        }
    }
}
