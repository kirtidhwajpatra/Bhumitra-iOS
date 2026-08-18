import Foundation
import MapKit
import Combine
import SwiftUI

public struct SearchResult: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let type: SearchResultType
}

public enum SearchResultType: Equatable {
    case plot(String)
    case area(String, Coordinate)
    case village(String, Coordinate)
    case global(MKLocalSearchCompletion)
}

public final class MapViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @MainActor @Published public var parcels: [Parcel] = []
    @MainActor @Published public var selectedParcel: Parcel?
    @MainActor @Published public var isLoading: Bool = false
    @MainActor @Published public var isDownloadingPDF: Bool = false
    @MainActor @Published public var errorMessage: String?
    @MainActor @Published public var searchQuery: String = "" {
        didSet {
            updateSuggestions()
        }
    }
    @MainActor @Published public var searchResults: [SearchResult] = []
    @MainActor @Published public var isSatellite: Bool = true
    @MainActor @Published public var showParcels: Bool = true
    @MainActor @Published public var shouldCenterOnUser: Bool = false
    @MainActor @Published public var mapCenter: Coordinate = Coordinate(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude)
    @MainActor @Published public var zoomLevel: Double = 15.5
    @MainActor @Published public var tapPoint: CGPoint? = nil
    @MainActor @Published public var selectedLocationInfo: LocalAdminClient.LocationInfo? = nil
    @MainActor @Published public var downloadedRORs: [DownloadedROR] = []
    
    public struct DownloadedROR: Identifiable, Codable {
        public let id = UUID()
        public let filename: String
        public let date: String
        public let details: String
    }
    
    private let parcelRepository: ParcelRepositoryProtocol
    private let completer = MKLocalSearchCompleter()
    
    // Local Knowledge Base of Areas (Odisha)
    private let localAreas: [(name: String, coord: Coordinate)] = [
        ("Keonjhar Town", Coordinate(latitude: 21.6289, longitude: 85.5817)),
        ("Barbil", Coordinate(latitude: 22.1205, longitude: 85.3582)),
        ("Joda", Coordinate(latitude: 22.0125, longitude: 85.4219)),
        ("Anandapur", Coordinate(latitude: 21.2133, longitude: 86.1158)),
        ("Champua", Coordinate(latitude: 22.0733, longitude: 85.6667)),
        ("Ghatgaon", Coordinate(latitude: 21.3917, longitude: 85.9167)),
        ("Telkoi", Coordinate(latitude: 21.3533, longitude: 85.4056)),
        ("Banspal", Coordinate(latitude: 21.5667, longitude: 85.4167))
    ]
    
    public init(parcelRepository: ParcelRepositoryProtocol = ParcelRepository()) {
        self.parcelRepository = parcelRepository
        super.init()
        completer.delegate = self
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.6289, longitude: 85.5817),
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
        )
        setupConnectivityMonitoring()
        
        // Listen to state changes
        NotificationCenter.default.publisher(for: NSNotification.Name("BhumitraStateChanged"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleStateChanged()
            }
            .store(in: &cancellables)
            
        // Initial setup
        handleStateChanged()
    }
    
    @MainActor
    private func handleStateChanged() {
        guard let code = AuthManager.shared.selectedStateCode else { return }
        if let state = StateDetails.allStates.first(where: { $0.id == code }) {
            let center = CLLocationCoordinate2D(latitude: state.latitude, longitude: state.longitude)
            let span = MKCoordinateSpan(latitudeDelta: state.latDelta, longitudeDelta: state.lonDelta)
            self.completer.region = MKCoordinateRegion(center: center, span: span)
            
            // Recenter the map view on the selected state
            self.mapCenter = Coordinate(latitude: state.latitude, longitude: state.longitude)
            self.zoomLevel = code == "OD" ? 14.5 : 10.0 // Center closer if Odisha (default PMTiles zone)
            
            // Reset selection context
            self.selectedParcel = nil
            self.selectedLocationInfo = nil
            self.tapPoint = nil
            
            // Clear current parcels and reload
            self.parcels = []
            Task {
                await loadParcels()
            }
            
            showToast("Centered on \(state.name)", icon: "scope")
        }
    }
    
    private var selectedStateName: String {
        AuthManager.shared.selectedState ?? "Odisha"
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupConnectivityMonitoring() {
        NetworkMonitor.shared.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.showToast("Internet connection lost", icon: "wifi.slash")
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    public func showToast(_ message: String, icon: String) {
        self.toastMessage = message
        self.toastIcon = icon
        hapticFeedback(.light)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.toastMessage == message {
                withAnimation { self.toastMessage = nil }
            }
        }
    }
    
    @MainActor @Published public var toastMessage: String?
    @MainActor @Published public var toastIcon: String = ""
    
    @MainActor
    public func toggleSatellite() {
        isSatellite.toggle()
        showToast(isSatellite ? "Satellite Mode" : "Map Mode", icon: "globe")
    }
    
    @MainActor
    public func toggleParcels() {
        showParcels.toggle()
        showToast(showParcels ? "Parcels Visible" : "Parcels Hidden", icon: showParcels ? "eye.fill" : "eye.slash.fill")
    }
    
    @MainActor
    private func updateSuggestions() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        completer.queryFragment = searchQuery
        
        var suggestions: [SearchResult] = []
        let stateCode = AuthManager.shared.selectedStateCode ?? "OD"
        
        // 1. Plot Check
        if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: searchQuery)) {
            let plotSubtitle = stateCode == "OD" ? "Locate plot in Keonjhar" : "Locate plot in \(selectedStateName)"
            suggestions.append(SearchResult(title: "Plot: \(searchQuery)", subtitle: plotSubtitle, type: .plot(searchQuery)))
        }
        
        // 2. Local Areas Check (Only relevant for Odisha context since we have static area catalog)
        if stateCode == "OD" {
            for area in localAreas {
                if area.name.lowercased().contains(searchQuery.lowercased()) {
                    let type: SearchResultType = area.name.contains("Town") ? .area(area.name, area.coord) : .village(area.name, area.coord)
                    suggestions.append(SearchResult(title: area.name, subtitle: "Keonjhar, Odisha", type: type))
                }
            }
        }
        
        self.searchResults = suggestions
    }
    
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            let global = completer.results.map { SearchResult(title: $0.title, subtitle: $0.subtitle, type: .global($0)) }
            let locals = self.searchResults.filter { if case .global = $0.type { return false }; return true }
            self.searchResults = locals + global.prefix(5)
        }
    }
    
    @MainActor
    public func selectLocation(_ result: SearchResult) {
        print("DEBUG: 🎯 Selecting result: \(result.title)")
        searchQuery = ""
        searchResults = []
        shouldCenterOnUser = false
        
        switch result.type {
        case .plot(let plotNo):
            // Plot numbers repeat across villages, so a bare number can't be
            // located globally. Zoom in so the cadastral layer (and its plot
            // labels) become visible and let the user tap the exact plot.
            self.zoomLevel = 18.0
            showToast("Zoom to your village and tap plot \(plotNo)", icon: "scope")
        case .area(_, let coord), .village(_, let coord):
            self.mapCenter = coord
            self.zoomLevel = 15.0
        case .global(let completion):
            let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
            search.start { response, _ in
                guard let coord = response?.mapItems.first?.placemark.coordinate else { return }
                DispatchQueue.main.async {
                    self.mapCenter = Coordinate(latitude: coord.latitude, longitude: coord.longitude)
                    self.zoomLevel = 15.0
                }
            }
        }
    }
    
    @MainActor
    public func searchLocation() {
        let currentStateName = selectedStateName.lowercased()
        if searchQuery.lowercased().contains(currentStateName) {
            jumpToSelectedState()
        } else if searchQuery.lowercased().contains("keonjhar") {
            jumpToKeonjhar()
        } else if let first = searchResults.first {
            selectLocation(first)
        }
    }
    
    @MainActor
    public func jumpToKeonjhar() {
        mapCenter = Coordinate(latitude: 21.6289, longitude: 85.5817)
        zoomLevel = 14.5
        shouldCenterOnUser = false
    }
    
    @MainActor
    public func jumpToSelectedState() {
        guard let code = AuthManager.shared.selectedStateCode,
              let state = StateDetails.allStates.first(where: { $0.id == code }) else {
            jumpToKeonjhar()
            return
        }
        mapCenter = Coordinate(latitude: state.latitude, longitude: state.longitude)
        zoomLevel = 10.0
        shouldCenterOnUser = false
    }
    
    @MainActor 
    public func onMapRegionChanged(northEast: Coordinate, southWest: Coordinate) {
        // In static mode, we don't need to trigger fetches on move as the whole set is local OR in PMTiles
        // But we update the internal state for consistency
    }
    
    @MainActor
    public func loadParcels() async {
        guard parcels.isEmpty else { return }
        isLoading = true
        do {
            self.parcels = try await parcelRepository.fetchParcels()
        } catch {
            print("ERROR: Failed to load static parcels: \(error)")
        }
        isLoading = false
    }
    
    @MainActor
    public func fetchLocationInfo(at coordinate: Coordinate) async {
        // Re-enable admin lookup if backend is running
        if let info = try? await LocalAdminClient.shared.fetchLocationInfo(latitude: coordinate.latitude, longitude: coordinate.longitude) {
            self.selectedLocationInfo = info
        }
    }
    
    @MainActor public func zoomIn() { zoomLevel = min(zoomLevel + 1.0, 22.0) }
    @MainActor public func zoomOut() { zoomLevel = max(zoomLevel - 1.0, 2.0) }
    
    @MainActor
    public func downloadRoRPDF(for parcel: Parcel) async -> URL? {
        isDownloadingPDF = true
        showToast("Fetching RoR PDF...", icon: "tray.and.arrow.down.fill")
        defer { isDownloadingPDF = false }
        return try? await RoRService.shared.downloadROR(for: parcel)
    }
}
