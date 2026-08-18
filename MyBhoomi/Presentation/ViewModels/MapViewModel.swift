import Foundation
import MapKit
import Combine
import SwiftUI
import MapLibre

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
    case cadastralVillage(CadastralVillage)
    case global(MKLocalSearchCompletion)
}

public final class MapViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @MainActor @Published public var parcels: [Parcel] = []
    @MainActor @Published public var selectedParcel: Parcel?
    
    // MARK: - Official 4K GEO Cadastral Pipeline State
    @MainActor @Published public var cadastralShape: MLNShape? = nil
    @MainActor @Published public var cadastralParcels: [CadastralParcel] = []
    @MainActor @Published public var selectedCadastralParcel: CadastralParcel? = nil
    @MainActor @Published public var activeCadastralVillage: CadastralVillage? = nil
    
    // MARK: - Debug Diagnostic State (#if DEBUG)
    @MainActor @Published public var gisApiStatus: String = "Connected"
    @MainActor @Published public var debugVillageName: String = "Not Selected"
    @MainActor @Published public var debugVillageID: String = "--"
    @MainActor @Published public var debugParcelCount: Int = 0
    @MainActor @Published public var debugRequestDurationMs: Double = 0.0
    @MainActor @Published public var debugCacheStatus: String = "--"
    @MainActor @Published public var debugErrorMessage: String? = nil
    @MainActor @Published public var debugSelectedPlot: String? = nil
    @MainActor @Published public var debugSelectedSourceID: String? = nil
    @MainActor @Published public var debugGeometryType: String? = nil
    
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
    private let cadastralRepository: CadastralRepository
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
    
    public init(
        parcelRepository: ParcelRepositoryProtocol = ParcelRepository(),
        cadastralRepository: CadastralRepository = .shared
    ) {
        self.parcelRepository = parcelRepository
        self.cadastralRepository = cadastralRepository
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
            
        // Listen to dynamic toasts
        NotificationCenter.default.publisher(for: NSNotification.Name("BhumitraShowToast"))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let msg = notification.userInfo?["message"] as? String {
                    let icon = (notification.userInfo?["icon"] as? String) ?? "info.circle.fill"
                    self?.showToast(msg, icon: icon)
                }
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
            self.zoomLevel = code == "OD" ? 14.5 : 10.0
            
            // Reset selection context
            self.selectedParcel = nil
            self.selectedCadastralParcel = nil
            self.selectedLocationInfo = nil
            self.tapPoint = nil
            
            showToast("Centered on \(state.name)", icon: "scope")
        }
    }
    
    // MARK: - Official 4K GEO Cadastral Loading Pipeline
    
    @MainActor
    public func loadCadastralVillage(village: CadastralVillage) async {
        isLoading = true
        activeCadastralVillage = village
        debugVillageName = village.name
        debugVillageID = village.id
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // 1. Move camera to official village bounding extent
            if let extent = try? await cadastralRepository.getVillageExtent(village: village) {
                self.mapCenter = Coordinate(latitude: extent.centerLat, longitude: extent.centerLng)
                self.zoomLevel = 16.0
            }
            
            // 2. Fetch official WGS84 GeoJSON parcels collection
            let (parsedData, isCacheHit) = try await cadastralRepository.loadVillageParcels(village: village)
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            
            self.cadastralShape = parsedData.shape
            self.cadastralParcels = parsedData.parcels
            self.debugParcelCount = parsedData.totalCount
            self.debugRequestDurationMs = round(duration)
            self.debugCacheStatus = isCacheHit ? "Hit (0ms)" : "Miss (\(Int(duration))ms)"
            self.gisApiStatus = "Connected"
            self.debugErrorMessage = nil
            self.isLoading = false
            
            if parsedData.totalCount > 0 {
                showToast("Loaded \(parsedData.totalCount) parcels for \(village.name)", icon: "map.fill")
            } else {
                showToast("No cadastral parcels found for this village.", icon: "exclamationmark.triangle")
            }
        } catch {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            self.debugRequestDurationMs = round(duration)
            self.debugCacheStatus = "Error"
            self.debugErrorMessage = error.localizedDescription
            self.gisApiStatus = "Failed"
            self.isLoading = false
            showToast("Cadastral map unavailable", icon: "wifi.slash")
        }
    }
    
    @MainActor
    public func onCadastralParcelSelected(_ parcel: CadastralParcel) {
        self.selectedCadastralParcel = parcel
        self.debugSelectedPlot = parcel.plotNumber
        self.debugSelectedSourceID = parcel.sourceFeatureID
        self.debugGeometryType = parcel.geometryType
        
        // Sync with legacy Parcel wrapper for presentation sheet
        let identity = CanonicalParcelIdentity(
            parcelID: parcel.sourceFeatureID,
            plotNumber: parcel.plotNumber,
            districtName: parcel.districtName ?? "KEONJHAR",
            districtID: parcel.districtID,
            tahasilName: parcel.blockName ?? "KEONJHAR SADAR",
            tahasilID: parcel.blockID,
            villageName: parcel.villageName ?? "G_Dimbo",
            villageID: parcel.villageID
        )
        let legacyParcel = Parcel(
            id: parcel.id,
            boundary: parcel.boundary,
            metadata: ParcelMetadata(identity: identity, estimatedAreaAcre: nil)
        )
        self.selectedParcel = legacyParcel
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
    public func zoomIn() {
        if zoomLevel < 21.0 {
            zoomLevel += 1.0
        }
    }
    
    @MainActor
    public func zoomOut() {
        if zoomLevel > 5.0 {
            zoomLevel -= 1.0
        }
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
        
        // 2. Local Areas Check
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
            let filteredResults = completer.results.filter { result in
                let combined = (result.title + " " + result.subtitle).lowercased()
                let target = self.selectedStateName.lowercased()
                return combined.contains(target) || combined.contains("odisha") || combined.contains("india")
            }
            
            let globalSuggestions = filteredResults.map {
                SearchResult(title: $0.title, subtitle: $0.subtitle, type: .global($0))
            }
            
            if !self.searchQuery.isEmpty {
                var current = self.searchResults.filter {
                    if case .global = $0.type { return false }
                    return true
                }
                current.append(contentsOf: globalSuggestions)
                self.searchResults = current
            }
        }
    }
    
    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Ignored gracefully
    }
    
    @MainActor
    public func searchLocation() {
        if let first = searchResults.first {
            _Concurrency.Task {
                try? await selectLocation(first)
            }
        }
    }
    
    @MainActor
    public func selectLocation(_ result: SearchResult) async throws {
        switch result.type {
        case .cadastralVillage(let village):
            await loadCadastralVillage(village: village)
            
        case .plot(let plotNum):
            if let activeV = activeCadastralVillage,
               let parcel = cadastralRepository.getParcelByPlot(village: activeV, plotNumber: plotNum) {
                onCadastralParcelSelected(parcel)
                let c = parcel.centroidCoordinate
                self.mapCenter = Coordinate(latitude: c.latitude, longitude: c.longitude)
                self.zoomLevel = 18.0
            } else {
                showToast("Plot \(plotNum) search requires village selection", icon: "magnifyingglass")
            }
            
        case .area(_, let coord), .village(_, let coord):
            self.mapCenter = coord
            self.zoomLevel = 16.0
            showToast("Centered on \(result.title)", icon: "scope")
            
        case .global(let completion):
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            if let item = response.mapItems.first {
                let coord = Coordinate(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                self.mapCenter = coord
                self.zoomLevel = 16.0
                showToast("Centered on \(result.title)", icon: "scope")
            }
        }
    }
    
    @MainActor
    public func downloadRoRPDF(for parcel: Parcel) async -> URL? {
        isDownloadingPDF = true
        defer { isDownloadingPDF = false }
        do {
            let url = try await RoRService.shared.downloadROR(for: parcel)
            let filename = "RoR_\(parcel.metadata.plotNumber)_\(Int(Date().timeIntervalSince1970)).pdf"
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
            let details = "Plot \(parcel.metadata.plotNumber), \(parcel.identity.villageName), \(parcel.identity.districtName)"
            downloadedRORs.insert(DownloadedROR(filename: filename, date: dateStr, details: details), at: 0)
            showToast("Downloaded official land record", icon: "arrow.down.doc.fill")
            return url
        } catch {
            showToast("Unable to generate PDF", icon: "exclamationmark.triangle.fill")
            return nil
        }
    }
}
