import Foundation
import Network
import Combine
import UIKit
import SwiftUI

public enum NetworkStatus: Equatable {
    case noInternet
    case connected
    
    public var title: String {
        switch self {
        case .noInternet:
            return "Connection Lost"
        case .connected:
            return "Connected"
        }
    }
}

public class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "bhumitra.network.monitor", qos: .utility)
    
    @Published public var isConnected: Bool = true
    @Published public var currentStatus: NetworkStatus = .connected
    
    // MARK: - Visual State Machine
    @Published public var showDropBanner: Bool = false
    @Published public var dropBannerText: String = ""
    @Published public var dropBannerColor: Color = Color(red: 220/255, green: 38/255, blue: 38/255)
    @Published public var statusBarColor: Color? = nil
    
    private var previousStatus: NetworkStatus = .connected
    private var dismissDropTask: Task<Void, Never>? = nil
    private var dismissStatusTask: Task<Void, Never>? = nil
    private var isInitialCheck: Bool = true
    
    private init() {
        startMonitoring()
    }
    
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.evaluatePath(path)
        }
        monitor.start(queue: queue)
    }
    
    private func evaluatePath(_ path: NWPath) {
        let connected = path.status == .satisfied
        
        DispatchQueue.main.async {
            self.isConnected = connected
            if connected {
                self.updateStatus(.connected)
            } else {
                self.updateStatus(.noInternet)
            }
        }
    }
    
    @MainActor
    public func updateStatus(_ newStatus: NetworkStatus) {
        let oldStatus = self.currentStatus
        self.currentStatus = newStatus
        
        let redColor = Color(red: 220/255, green: 38/255, blue: 38/255)
        let greenColor = Color(red: 22/255, green: 163/255, blue: 74/255)
        
        if isInitialCheck {
            isInitialCheck = false
            self.previousStatus = newStatus
            if newStatus == .noInternet {
                // Initial launch while offline: keep status bar red
                self.statusBarColor = redColor
            }
            return
        }
        
        guard oldStatus != newStatus else { return }
        
        dismissDropTask?.cancel()
        dismissStatusTask?.cancel()
        
        switch newStatus {
        case .noInternet:
            // 1. Status bar turns Red immediately and stays Red for the entire offline duration
            self.statusBarColor = redColor
            self.dropBannerColor = redColor
            self.dropBannerText = "Connection Lost"
            
            // 2. Extend down the "Connection Lost" banner
            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                self.showDropBanner = true
            }
            
            // 3. Keep text banner visible for 3.5s, then retract text banner back into the Red status bar
            dismissDropTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                if !Task.isCancelled && self.currentStatus == .noInternet {
                    withAnimation(.easeInOut(duration: 0.32)) {
                        self.showDropBanner = false
                    }
                }
            }
            
        case .connected:
            if oldStatus == .noInternet {
                // Subtle haptic tap
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
                
                // 1. Status bar instantly switches from Red to Green
                self.statusBarColor = greenColor
                self.dropBannerColor = greenColor
                self.dropBannerText = "Connected"
                
                // 2. Extend down the "Connected" banner
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    self.showDropBanner = true
                }
                
                // 3. Keep text banner visible for 3.5s, then retract text banner into the Green status bar
                dismissDropTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    if !Task.isCancelled && self.currentStatus == .connected {
                        withAnimation(.easeInOut(duration: 0.32)) {
                            self.showDropBanner = false
                        }
                    }
                }
                
                // 4. Green status bar stays visible for an extra 3.0s after text disappears (total 6.5s), then smoothly fades away
                dismissStatusTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 6_500_000_000)
                    if !Task.isCancelled && self.currentStatus == .connected {
                        withAnimation(.easeInOut(duration: 0.40)) {
                            self.statusBarColor = nil
                        }
                    }
                }
            } else {
                self.showDropBanner = false
                self.statusBarColor = nil
            }
        }
        
        self.previousStatus = newStatus
    }
}
