import Foundation
import Network
import Combine
import UIKit
import SwiftUI

public enum NetworkStatus: Equatable {
    case noInternet
    /// Path exists but isn't usable yet (e.g. joining Wi-Fi, captive portal).
    case connecting
    /// Connected, but the system reports a constrained path (Low Data Mode).
    case limited
    case connected

    public var title: String {
        switch self {
        case .noInternet: return "Connection Lost"
        case .connecting: return "Connecting"
        case .limited: return "Limited Connection"
        case .connected: return "Connected"
        }
    }
}

/// What the edge-to-edge connectivity strip is showing right now.
public enum NetworkBanner: Equatable {
    /// Red, stays for as long as the device is offline.
    case offline
    /// Amber, stays while the path is still coming up.
    case connecting
    /// Amber, shown briefly when Low Data Mode limits the connection.
    case limited
    /// Green, shown briefly after recovering from offline/connecting.
    case restored
}

public class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "bhumitra.network.monitor", qos: .utility)

    @Published public var isConnected: Bool = true
    @Published public var currentStatus: NetworkStatus = .connected
    /// Nil = nothing to show.
    @Published public var banner: NetworkBanner? = nil

    private var dismissTask: Task<Void, Never>? = nil
    private var isInitialCheck: Bool = true

    /// How long transient states (restored / limited) stay on screen.
    private let transientSeconds: UInt64 = 3

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
        let status: NetworkStatus
        switch path.status {
        case .satisfied:
            status = path.isConstrained ? .limited : .connected
        case .requiresConnection:
            status = .connecting
        default:
            status = .noInternet
        }

        DispatchQueue.main.async {
            self.isConnected = path.status == .satisfied
            self.updateStatus(status)
        }
    }

    @MainActor
    public func updateStatus(_ newStatus: NetworkStatus) {
        let oldStatus = currentStatus
        currentStatus = newStatus

        if isInitialCheck {
            isInitialCheck = false
            // On launch only surface real problems — never a "Connected" flash.
            switch newStatus {
            case .noInternet: setBanner(.offline)
            case .connecting: setBanner(.connecting)
            case .limited, .connected: break
            }
            return
        }

        guard oldStatus != newStatus else { return }
        dismissTask?.cancel()

        switch newStatus {
        case .noInternet:
            setBanner(.offline)
        case .connecting:
            setBanner(.connecting)
        case .limited:
            setBanner(.limited)
            autoHide(ifStill: .limited)
        case .connected:
            if oldStatus == .noInternet || oldStatus == .connecting {
                setBanner(.restored)
                autoHide(ifStill: .connected)
            } else {
                setBanner(nil)
            }
        }
    }

    @MainActor
    private func setBanner(_ value: NetworkBanner?) {
        withAnimation(.easeInOut(duration: 0.3)) {
            banner = value
        }
    }

    @MainActor
    private func autoHide(ifStill status: NetworkStatus) {
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: transientSeconds * 1_000_000_000)
            if !Task.isCancelled && self.currentStatus == status {
                self.setBanner(nil)
            }
        }
    }
}
