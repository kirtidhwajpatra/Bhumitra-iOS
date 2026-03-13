import MapKit
import Combine
import SwiftUI

public enum SearchResultType {
    case global(MKLocalSearchCompletion)
    case plot(String)
    case area(String, Coordinate)
}

public struct SearchResult: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let type: SearchResultType
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
    @MainActor @Published public var isSatellite: Bool = false
    @MainActor @Published public var showParcels: Bool = true
    @MainActor @Published public var shouldCenterOnUser: Bool = false
    @MainActor @Published public var mapCenter: Coordinate = Coordinate(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude)
    @MainActor @Published public var zoomLevel: Double = 13.0
    @MainActor @Published public var tapPoint: CGPoint? = nil
    
    // UI Feedback
    @MainActor @Published public var toastMessage: String?
    @MainActor @Published public var toastIcon: String = ""
    @MainActor @Published public var isNetworkWeak: Bool = false
    
    private let parcelRepository: ParcelRepositoryProtocol
    private let completer = MKLocalSearchCompleter()
    
    // Local Knowledge Base of Areas
    private let localAreas: [(name: String, coord: Coordinate)] = [
        ("Keonjhar Town", Coordinate(latitude: 21.6289, longitude: 85.5817)),
        ("Barbil", Coordinate(latitude: 22.1205, longitude: 85.3582)),
        ("Joda", Coordinate(latitude: 22.0125, longitude: 85.4219)),
        ("Anandapur", Coordinate(latitude: 21.2133, longitude: 86.1158)),
        ("Champua", Coordinate(latitude: 22.0733, longitude: 85.6667)),
        ("Ghatgaon", Coordinate(latitude: 21.3917, longitude: 85.9167))
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
            
        NetworkMonitor.shared.$isExpensive
            .receive(on: RunLoop.main)
            .sink { [weak self] isExpensive in
                if isExpensive {
                    self?.showToast("Weak or Expensive Internet", icon: "wifi.exclamationmark")
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    public func showToast(_ message: String, icon: String) {
        self.toastMessage = message
        self.toastIcon = icon
        hapticFeedback(.light)
        
        // Auto dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.toastMessage == message {
                withAnimation {
                    self.toastMessage = nil
                }
            }
        }
    }
    
    @MainActor
    public func toggleSatellite() {
        isSatellite.toggle()
        showToast(isSatellite ? "Satellite View Enabled" : "Map View Enabled", 
                  icon: isSatellite ? "globe.asia.australia.fill" : "map.fill")
    }
    
    @MainActor
    public func toggleParcels() {
        showParcels.toggle()
        showToast(showParcels ? "Parcel Boundaries Visible" : "Parcel Boundaries Hidden", 
                  icon: showParcels ? "square.grid.2x2.fill" : "square.grid.2x2")
    }
    
    @MainActor
    private func updateSuggestions() {
        if searchQuery.isEmpty {
            searchResults = []
            return
        }
        
        completer.queryFragment = searchQuery
        
        var suggestions: [SearchResult] = []
        
        // 1. Plot Number (numeric check)
        if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: searchQuery)) {
            suggestions.append(SearchResult(
                title: "Plot: \(searchQuery)",
                subtitle: "Find cadastral boundaries",
                type: .plot(searchQuery)
            ))
        }
        
        // 2. Local Villages/Areas
        for area in localAreas {
            if area.name.lowercased().contains(searchQuery.lowercased()) {
                suggestions.append(SearchResult(
                    title: area.name,
                    subtitle: "District Keonjhar, Odisha",
                    type: .area(area.name, area.coord)
                ))
            }
        }
        
        self.searchResults = suggestions
    }
    
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            let global = completer.results.map { 
                SearchResult(title: $0.title, subtitle: $0.subtitle, type: .global($0)) 
            }
            let currentLocal = self.searchResults.filter { 
                if case .global = $0.type { return false }
                return true
            }
            // Keep local stuff at top, then global
            self.searchResults = currentLocal + global.prefix(5)
        }
    }
    
    @MainActor
    public func selectLocation(_ result: SearchResult) {
        searchQuery = ""
        searchResults = []
        
        switch result.type {
        case .plot(let plotNo):
            Task {
                if let plot = try? await parcelRepository.searchParcel(plotNumber: plotNo) {
                    if let centroid = plot.boundary.first {
                        self.mapCenter = centroid
                        self.zoomLevel = 18.0
                        self.selectedParcel = plot
                    }
                } else {
                    // Even if not in local sample, try to find it via map layers if possible (simulated zoom)
                    self.zoomLevel = 18.0
                }
            }
            
        case .area(_, let coord):
            self.mapCenter = coord
            self.zoomLevel = 15.0
            
        case .global(let completion):
            let searchRequest = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: searchRequest)
            search.start { response, error in
                guard let coord = response?.mapItems.first?.placemark.coordinate else { return }
                DispatchQueue.main.async {
                    self.mapCenter = Coordinate(latitude: coord.latitude, longitude: coord.longitude)
                    self.zoomLevel = 15.0
                }
            }
        }
    }
    
    @MainActor
    public func jumpToKeonjhar() {
        print("DEBUG: Jumping to Keonjhar coordinates.")
        mapCenter = Coordinate(latitude: 21.6289, longitude: 85.5817)
        zoomLevel = 14.0 // Zoomed in even more for better plot visibility
    }
    
    @MainActor
    public func searchLocation() {
        print("DEBUG: Searching for: \(searchQuery)")
        if searchQuery.lowercased().contains("keonjhar") {
            jumpToKeonjhar()
        } else {
            print("DEBUG: Query '\(searchQuery)' did not match 'keonjhar'")
        }
    }
    
    @MainActor
    public func zoomIn() {
        zoomLevel = min(zoomLevel + 1.0, 22.0)
    }
    
    @MainActor
    public func zoomOut() {
        zoomLevel = max(zoomLevel - 1.0, 2.0)
    }
    
    @MainActor
    public func loadParcels(in bounds: GeoBounds? = nil) async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        do {
            if let bounds = bounds {
                self.parcels = try await parcelRepository.fetchParcels(in: bounds)
            } else {
                self.parcels = try await parcelRepository.fetchParcels()
            }
        } catch {
            print("ERROR: GIS Fetch Failed -> \(error.localizedDescription)")
            self.errorMessage = "Live GIS data currently unavailable"
            showToast("GIS Service Busy", icon: "exclamationmark.triangle.fill")
        }
        isLoading = false
    }
    
    // Throttled update for map movement
    private var lastUpdateWorkItem: DispatchWorkItem?
    
    @MainActor
    public func onMapRegionChanged(northEast: Coordinate, southWest: Coordinate) {
        lastUpdateWorkItem?.cancel()
        
        // Wait for map to settle slightly
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                let bounds = GeoBounds(northEast: northEast, southWest: southWest)
                await self?.loadParcels(in: bounds)
            }
        }
        
        lastUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }
    
    @MainActor
    public func downloadRoRPDF(for parcel: Parcel) async -> URL? {
        isDownloadingPDF = true
        showToast("Generating ROR PDF...", icon: "doc.text.fill")
        
        do {
            let url = try await RoRService.shared.downloadROR(for: parcel)
            isDownloadingPDF = false
            showToast("PDF Ready to Download", icon: "checkmark.circle.fill")
            return url
        } catch {
            isDownloadingPDF = false
            showToast("Failed to generate PDF", icon: "exclamationmark.triangle.fill")
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
}
