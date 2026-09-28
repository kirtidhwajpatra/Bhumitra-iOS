//
//  LocationPermissionManager.swift
//  MyBhoomi
//
//  Production-ready Location Authorization State Manager.
//  Observes CoreLocation permissions, system services status, and foreground transitions.
//

import SwiftUI
import CoreLocation
import Combine

@MainActor
public final class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationPermissionManager()
    
    private let locationManager = CLLocationManager()
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus
    @Published public private(set) var accuracyAuthorization: CLAccuracyAuthorization
    @Published public private(set) var isLocationServicesEnabled: Bool
    /// Not published: it updates on every GPS fix and nothing renders it.
    public private(set) var currentLocation: CLLocation?
    
    public var isReducedAccuracy: Bool {
        return accuracyAuthorization == .reducedAccuracy
    }
    
    public enum LocationError: LocalizedError, Equatable {
        case servicesDisabled
        case permissionDenied
        case timeout
        case locationUnavailable(String)
        
        public var errorDescription: String? {
            switch self {
            case .servicesDisabled:
                return "Location services are disabled on your device."
            case .permissionDenied:
                return "Location permission is required to find plots near you."
            case .timeout:
                return "Location request timed out."
            case .locationUnavailable(let msg):
                return "Unable to determine current location: \(msg)"
            }
        }
    }
    
    // MARK: - Continuation tracking (single-flight, race-safe)
    
    /// Only one location request continuation can be active at a time.
    /// This prevents double-resume crashes from concurrent didUpdateLocations / timeout races.
    private var activeLocationContinuation: CheckedContinuation<CLLocation, Error>?
    private var pendingAuthContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []
    
    /// Tracks whether a location request is currently in-flight to prevent re-entrant requests.
    private var isLocationRequestActive: Bool = false
    
    private override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        self.accuracyAuthorization = locationManager.accuracyAuthorization
        // Don't call CLLocationManager.locationServicesEnabled() here: it blocks the
        // main thread (Xcode's "may cause UI unresponsiveness" warning). The
        // authorization callback below delivers the real value immediately.
        let status = locationManager.authorizationStatus
        self.isLocationServicesEnabled = !(status == .restricted)
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // No continuous GPS at launch: MapLibre tracks the blue dot itself, and
        // requestCurrentLocation() starts a one-off fix when the user asks.
    }
    
    /// Reads the system-wide Location Services switch off the main thread.
    private func refreshServicesEnabledInBackground() {
        _Concurrency.Task.detached(priority: .utility) {
            let enabled = CLLocationManager.locationServicesEnabled()
            await MainActor.run { [weak self] in
                guard let self, self.isLocationServicesEnabled != enabled else { return }
                self.isLocationServicesEnabled = enabled
            }
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if authorizationStatus != manager.authorizationStatus { self.authorizationStatus = manager.authorizationStatus }
        if accuracyAuthorization != manager.accuracyAuthorization { self.accuracyAuthorization = manager.accuracyAuthorization }
        refreshServicesEnabledInBackground()
        
        if !(manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) {
            locationManager.stopUpdatingLocation()
        }
        
        if manager.authorizationStatus != .notDetermined && !pendingAuthContinuations.isEmpty {
            let continuations = pendingAuthContinuations
            pendingAuthContinuations.removeAll()
            for continuation in continuations {
                continuation.resume(returning: manager.authorizationStatus)
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.currentLocation = location
        
        // Only resume if there's an active single-flight continuation
        if let continuation = activeLocationContinuation {
            activeLocationContinuation = nil
            isLocationRequestActive = false
            continuation.resume(returning: location)
            // One-off fix delivered: stop the GPS radio instead of running it forever.
            manager.stopUpdatingLocation()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("[LocationPermissionManager] didFailWithError: \(error.localizedDescription)")
        #endif
        
        // Only resume if there's an active single-flight continuation
        if let continuation = activeLocationContinuation {
            activeLocationContinuation = nil
            isLocationRequestActive = false
            continuation.resume(throwing: LocationError.locationUnavailable(error.localizedDescription))
        }
    }
    
    /// The best currently known location from CLLocationManager or cached state.
    public var bestAvailableLocation: CLLocation? {
        if let loc = locationManager.location,
           CLLocationCoordinate2DIsValid(loc.coordinate),
           (loc.coordinate.latitude != 0.0 || loc.coordinate.longitude != 0.0),
           loc.horizontalAccuracy >= 0 {
            return loc
        }
        if let loc = currentLocation,
           CLLocationCoordinate2DIsValid(loc.coordinate),
           (loc.coordinate.latitude != 0.0 || loc.coordinate.longitude != 0.0),
           loc.horizontalAccuracy >= 0 {
            return loc
        }
        return nil
    }
    
    /// Requests the user's current GPS location.
    /// Fast path: Returns immediately (<5ms) if CoreLocation already has a valid location fix.
    /// Async path: Bounded 2.5s wait for a fresh fix with fallback to last known location.
    public func requestCurrentLocation(timeoutSeconds: TimeInterval = 2.5) async throws -> CLLocation {
        refresh()
        // Explicit user action (GPS button): read the system switch now, off the main thread.
        let servicesEnabled = await _Concurrency.Task.detached(priority: .userInitiated) {
            CLLocationManager.locationServicesEnabled()
        }.value
        if isLocationServicesEnabled != servicesEnabled { isLocationServicesEnabled = servicesEnabled }
        
        guard isLocationServicesEnabled else {
            throw LocationError.servicesDisabled
        }
        
        var currentStatus = authorizationStatus
        if currentStatus == .notDetermined {
            currentStatus = await withCheckedContinuation { continuation in
                pendingAuthContinuations.append(continuation)
                locationManager.requestWhenInUseAuthorization()
            }
        }
        
        guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }
        
        // 1. FAST PATH (0ms): If CLLocationManager already has a valid fix within the last 120s with accuracy <= 200m
        if let loc = locationManager.location,
           CLLocationCoordinate2DIsValid(loc.coordinate),
           (loc.coordinate.latitude != 0.0 || loc.coordinate.longitude != 0.0),
           loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy <= 200,
           loc.timestamp.timeIntervalSinceNow > -120.0 {
            self.currentLocation = loc
            #if DEBUG
            print("[GPS_DEBUG] Instant GPS fix from locationManager.location: (\(loc.coordinate.latitude), \(loc.coordinate.longitude)), accuracy=\(loc.horizontalAccuracy)m")
            #endif
            return loc
        }
        
        // 2. WARM CACHE PATH: Stored currentLocation within 120s
        if let loc = currentLocation,
           CLLocationCoordinate2DIsValid(loc.coordinate),
           (loc.coordinate.latitude != 0.0 || loc.coordinate.longitude != 0.0),
           loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy <= 200,
           loc.timestamp.timeIntervalSinceNow > -120.0 {
            #if DEBUG
            print("[GPS_DEBUG] Instant GPS fix from cached currentLocation: (\(loc.coordinate.latitude), \(loc.coordinate.longitude))")
            #endif
            return loc
        }
        
        // 3. ASYNC PATH: Start updates and await fresh fix with a short 2.5s bounded timeout
        locationManager.startUpdatingLocation()
        
        // Cancel any previous continuation safely
        if let prev = activeLocationContinuation {
            activeLocationContinuation = nil
            if let best = bestAvailableLocation {
                prev.resume(returning: best)
            } else {
                prev.resume(throwing: LocationError.timeout)
            }
        }
        
        let timeoutTask = _Concurrency.Task { @MainActor [weak self] in
            try await _Concurrency.Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            guard let self = self else { return }
            if let continuation = self.activeLocationContinuation {
                self.activeLocationContinuation = nil
                if let best = self.bestAvailableLocation {
                    #if DEBUG
                    print("[GPS_DEBUG] Timeout reached, returning best available fallback location: (\(best.coordinate.latitude), \(best.coordinate.longitude))")
                    #endif
                    continuation.resume(returning: best)
                } else {
                    continuation.resume(throwing: LocationError.timeout)
                }
            }
        }
        
        do {
            let location = try await withCheckedThrowingContinuation { continuation in
                self.activeLocationContinuation = continuation
            }
            timeoutTask.cancel()
            return location
        } catch {
            timeoutTask.cancel()
            if let best = bestAvailableLocation {
                return best
            }
            throw error
        }
    }
    
    public func refresh() {
        if authorizationStatus != locationManager.authorizationStatus { self.authorizationStatus = locationManager.authorizationStatus }
        if accuracyAuthorization != locationManager.accuracyAuthorization { self.accuracyAuthorization = locationManager.accuracyAuthorization }
        refreshServicesEnabledInBackground()
    }
    
    public var statusDisplay: String {
        guard isLocationServicesEnabled else {
            return "Disabled"
        }
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Enabled"
        case .denied, .restricted:
            return "Permission required"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Disabled"
        }
    }
    
    public func handleTap() {
        refresh()
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}
