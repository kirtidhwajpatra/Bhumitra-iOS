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
    @MainActor @Published public var debugPipelineStage: String = "IDLE"
    @MainActor @Published public var debugExtentStatus: String = "Not Loaded"
    @MainActor @Published public var debugDistrictName: String = "Odisha"
    @MainActor @Published public var debugTahasilName: String = ""
    @MainActor @Published public var debugGPName: String = ""
    @MainActor @Published public var debugVillageName: String = "Not Selected"
    @MainActor @Published public var debugVillageID: String = "--"
    @MainActor @Published public var debugParcelCount: Int = 0
    @MainActor @Published public var debugDecodedParcelCount: Int = 0
    @MainActor @Published public var debugMapSourceCount: Int = 0
    @MainActor @Published public var debugFirstPlots: [String] = []
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
    @MainActor @Published public var parcelDisplayStyle: ParcelDisplayStyle = .boundaryOnly {
        didSet {
            UserDefaults.standard.set(parcelDisplayStyle.rawValue, forKey: "bhumitra_parcel_display_style")
        }
    }
    @MainActor @Published public var shouldCenterOnUser: Bool = false
    @MainActor @Published public var isTrackingUser: Bool = false
    @MainActor @Published public var visualFilter: MapVisualFilter = .natural
    @MainActor @Published public var mapCenter: Coordinate = Coordinate(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude)
    @MainActor @Published public var zoomLevel: Double = 15.5
    @MainActor @Published public var tapPoint: CGPoint? = nil
    @MainActor @Published public var selectedLocationInfo: LocalAdminClient.LocationInfo? = nil
    @MainActor @Published public var downloadedRORs: [DownloadedROR] = []
    @MainActor @Published public var isDrawingBoundaryLoading: Bool = false
    
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
        ("Bhubaneswar", Coordinate(latitude: 20.2961, longitude: 85.8245)),
        ("Cuttack", Coordinate(latitude: 20.4625, longitude: 85.8828)),
        ("Puri", Coordinate(latitude: 19.8135, longitude: 85.8312)),
        ("Rourkela", Coordinate(latitude: 22.2604, longitude: 84.8536)),
        ("Sambalpur", Coordinate(latitude: 21.4669, longitude: 83.9812)),
        ("Berhampur", Coordinate(latitude: 19.3150, longitude: 84.7941)),
        ("Balasore", Coordinate(latitude: 21.4934, longitude: 86.9135)),
        ("Baripada", Coordinate(latitude: 21.9346, longitude: 86.7368)),
        ("Jeypore", Coordinate(latitude: 18.8550, longitude: 82.5683)),
        ("Jharsuguda", Coordinate(latitude: 21.8554, longitude: 84.0062)),
        ("Angul", Coordinate(latitude: 20.8394, longitude: 85.1014)),
        ("Dhenkanal", Coordinate(latitude: 20.6582, longitude: 85.5969)),
        ("Bhadrak", Coordinate(latitude: 21.0543, longitude: 86.4969)),
        ("Kendrapada", Coordinate(latitude: 20.4984, longitude: 86.4230)),
        ("Jagatsinghpur", Coordinate(latitude: 20.2587, longitude: 86.1687)),
        ("Jajpur", Coordinate(latitude: 20.8504, longitude: 86.3344)),
        ("Bargarh", Coordinate(latitude: 21.3340, longitude: 83.6214)),
        ("Bolangir", Coordinate(latitude: 20.7107, longitude: 83.4842)),
        ("Kalahandi (Bhawanipatna)", Coordinate(latitude: 19.9075, longitude: 83.1659)),
        ("Koraput", Coordinate(latitude: 18.8135, longitude: 82.7123)),
        ("Rayagada", Coordinate(latitude: 19.1717, longitude: 83.4163)),
        ("Nabarangpur", Coordinate(latitude: 19.2314, longitude: 82.5511)),
        ("Malkangiri", Coordinate(latitude: 18.3436, longitude: 81.8845)),
        ("Nuapada", Coordinate(latitude: 20.8354, longitude: 82.5292)),
        ("Kandhamal (Phulbani)", Coordinate(latitude: 20.4764, longitude: 84.2343)),
        ("Boudh", Coordinate(latitude: 20.8378, longitude: 84.3267)),
        ("Subarnapur (Sonepur)", Coordinate(latitude: 20.8407, longitude: 83.9168)),
        ("Deogarh", Coordinate(latitude: 21.5367, longitude: 84.7339)),
        ("Gajapati (Paralakhemundi)", Coordinate(latitude: 18.7758, longitude: 84.0934)),
        ("Nayagarh", Coordinate(latitude: 20.1259, longitude: 85.1065)),
    ]
    
    public init(
        parcelRepository: ParcelRepositoryProtocol = ParcelRepository(),
        cadastralRepository: CadastralRepository = .shared
    ) {
        self.parcelRepository = parcelRepository
        self.cadastralRepository = cadastralRepository
        super.init()
        UserDefaults.standard.removeObject(forKey: "bhumitra_parcel_display_style")
        self.parcelDisplayStyle = .boundaryOnly
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
    
    @MainActor private var currentLoadingVillageID: String? = nil
    
    @MainActor
    public func loadCadastralVillage(village: CadastralVillage) async {
        isLoading = true
        isDrawingBoundaryLoading = false
        currentLoadingVillageID = village.id
        activeCadastralVillage = village
        
        // Immediately reset previous shapes, plots, and selection context
        self.cadastralShape = nil
        self.cadastralParcels = []
        self.selectedCadastralParcel = nil
        self.selectedParcel = nil
        self.selectedLocationInfo = nil
        self.tapPoint = nil
        self.debugParcelCount = 0
        self.debugDecodedParcelCount = 0
        self.debugFirstPlots = []
        
        debugDistrictName = village.districtName ?? "Odisha"
        debugTahasilName = village.blockName ?? ""
        debugGPName = village.gpID ?? ""
        debugVillageName = village.name
        debugVillageID = village.id
        debugPipelineStage = "LOADING_EXTENT"
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // 1. Move camera to official village bounding extent
            do {
                let extent = try await cadastralRepository.getVillageExtent(village: village)
                guard self.currentLoadingVillageID == village.id else { return }
                self.mapCenter = Coordinate(latitude: extent.centerLat, longitude: extent.centerLng)
                self.zoomLevel = 16.5
                self.debugExtentStatus = String(format: "Lat: %.4f, Lng: %.4f", extent.centerLat, extent.centerLng)
                self.debugPipelineStage = "EXTENT_LOADED"
                print("DEBUG: 🗺️ Extent loaded for \(village.name): Center lat=\(extent.centerLat), lng=\(extent.centerLng)")
            } catch {
                print("DEBUG: ⚠️ Extent fetch failed for \(village.name): \(error). Proceeding to parcels...")
                self.debugExtentStatus = "Extent Failed"
            }
            
            // 2. Once the camera has navigated to the search area, activate the plot numbers animation
            guard self.currentLoadingVillageID == village.id else { return }
            try? await _Concurrency.Task.sleep(nanoseconds: 300_000_000) // 300ms for camera glide
            guard self.currentLoadingVillageID == village.id else { return }
            withAnimation(.easeInOut(duration: 0.50)) {
                self.isDrawingBoundaryLoading = true
            }
            
            // 3. Fetch official WGS84 GeoJSON parcels collection
            self.debugPipelineStage = "FETCHING_PARCELS"
            let (parsedData, isCacheHit) = try await cadastralRepository.loadVillageParcels(village: village)
            guard self.currentLoadingVillageID == village.id else { return }
            
            // Ensure calm, smooth visual rhythm (minimum 1.2s display so it doesn't flash)
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            if elapsed < 1.2 {
                let remainingNanos = UInt64((1.2 - elapsed) * 1_000_000_000)
                try? await _Concurrency.Task.sleep(nanoseconds: remainingNanos)
            }
            guard self.currentLoadingVillageID == village.id else { return }
            
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            
            self.cadastralShape = parsedData.shape
            self.cadastralParcels = parsedData.parcels
            self.debugParcelCount = parsedData.totalCount
            self.debugDecodedParcelCount = parsedData.parcels.count
            self.debugMapSourceCount = parsedData.shape != nil ? parsedData.totalCount : 0
            self.debugFirstPlots = Array(parsedData.parcels.prefix(5).map { $0.plotNumber })
            self.debugRequestDurationMs = round(duration)
            self.debugCacheStatus = isCacheHit ? "Hit (0ms)" : "Miss (\(Int(duration))ms)"
            self.debugPipelineStage = parsedData.totalCount > 0 ? "PARCELS_LOADED (\(parsedData.totalCount))" : "ZERO_PARCELS"
            self.gisApiStatus = "Connected"
            self.debugErrorMessage = nil
            
            // Smoothly dissolve floating plot numbers into the real vector parcels
            withAnimation(.easeInOut(duration: 0.60)) {
                self.isDrawingBoundaryLoading = false
                self.isLoading = false
            }
            
            print("DEBUG: 🗺️ Loaded \(parsedData.totalCount) parcels for village \(village.name) (ID: \(village.id)). First plots: \(debugFirstPlots)")
            
            if parsedData.totalCount == 0 {
                showToast("Cadastral parcel data is not available for this village.", icon: "exclamationmark.triangle")
            }
        } catch {
            guard self.currentLoadingVillageID == village.id else { return }
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            self.debugRequestDurationMs = round(duration)
            self.debugCacheStatus = "Error"
            self.debugPipelineStage = "PARCEL_FETCH_FAILED"
            self.debugErrorMessage = error.localizedDescription
            self.gisApiStatus = "Failed"
            withAnimation(.easeInOut(duration: 0.35)) {
                self.isDrawingBoundaryLoading = false
                self.isLoading = false
            }
            print("DEBUG: ❌ Failed to load village parcels for \(village.name): \(error)")
            showToast("Cadastral map unavailable", icon: "wifi.slash")
        }
    }
    
    // MARK: - DEBUG Helpers (#if DEBUG)
    
    #if DEBUG
    @MainActor
    public func loadTestVillage() {
        let testVillage = CadastralVillage(
            id: "0704317",
            name: "G_Dimbo",
            gpID: "07040001",
            blockID: "0704",
            districtID: "224"
        )
        _Concurrency.Task {
            await loadCadastralVillage(village: testVillage)
        }
    }
    
    @MainActor
    public func zoomToTestPlot12_1() {
        _Concurrency.Task {
            let testVillage = activeCadastralVillage ?? CadastralVillage(
                id: "0704317",
                name: "G_Dimbo",
                gpID: "07040001",
                blockID: "0704",
                districtID: "224"
            )
            
            // Ensure village is loaded first if not already
            if activeCadastralVillage?.id != testVillage.id {
                await loadCadastralVillage(village: testVillage)
            }
            
            // Try 12/1, then 12, then 782
            let targetPlots = ["12/1", "12", "782"]
            var foundParcel: CadastralParcel? = nil
            
            for pNum in targetPlots {
                if let p = cadastralRepository.getParcelByPlot(village: testVillage, plotNumber: pNum) {
                    foundParcel = p
                    break
                }
            }
            
            if let parcel = foundParcel {
                onCadastralParcelSelected(parcel)
                let c = parcel.centroidCoordinate
                self.mapCenter = Coordinate(latitude: c.latitude, longitude: c.longitude)
                self.zoomLevel = 18.0
                self.debugPipelineStage = "PLOT_\(parcel.plotNumber)_SELECTED"
                showToast("Centered on Plot \(parcel.plotNumber)", icon: "scope")
            } else {
                // Try fetching directly from API
                do {
                    let parcel = try await CadastralAPIClient.shared.fetchParcelByPlot(
                        villageID: testVillage.id,
                        plotNumber: "12",
                        districtName: "Keonjhar",
                        blockName: "Keonjhar Sadar",
                        villageName: "G_Dimbo"
                    )
                    onCadastralParcelSelected(parcel)
                    let c = parcel.centroidCoordinate
                    self.mapCenter = Coordinate(latitude: c.latitude, longitude: c.longitude)
                    self.zoomLevel = 18.0
                    self.debugPipelineStage = "PLOT_12_SELECTED"
                    showToast("Centered on Plot 12", icon: "scope")
                } catch {
                    self.debugErrorMessage = "Plot error: \(error.localizedDescription)"
                    showToast("Plot not found", icon: "exclamationmark.triangle")
                }
            }
        }
    }
    #endif
    
    @MainActor
    public func onCadastralParcelSelected(_ parcel: CadastralParcel) {
        self.selectedCadastralParcel = parcel
        self.debugSelectedPlot = parcel.plotNumber
        self.debugSelectedSourceID = parcel.sourceFeatureID
        self.debugGeometryType = parcel.geometryType
        
        let blockID: String = {
            if !parcel.blockID.isEmpty && parcel.blockID != "N/A" { return parcel.blockID }
            if let b = activeCadastralVillage?.blockID, !b.isEmpty { return b }
            return ""
        }()
        
        let distName: String = {
            if let d = parcel.districtName, !d.isEmpty, d != "N/A", d != "Odisha" { return d }
            if let d = activeCadastralVillage?.districtName, !d.isEmpty, d != "Odisha" { return d }
            if blockID.count >= 2 {
                let prefix = String(blockID.prefix(2))
                if let mapped = MapViewModel.districtNameForGISPrefix(prefix) {
                    return mapped
                }
            }
            return "Odisha"
        }()
        
        let distID: String = {
            if !parcel.districtID.isEmpty && parcel.districtID != "N/A" { return parcel.districtID }
            if let d = activeCadastralVillage?.districtID, !d.isEmpty { return d }
            if blockID.count >= 2 {
                let prefix = String(blockID.prefix(2))
                if let intCode = Int(prefix) {
                    return String(intCode)
                }
            }
            return ""
        }()
        
        let blockName: String = {
            if let b = parcel.blockName, !b.isEmpty, b != "N/A" { return b }
            if let b = activeCadastralVillage?.blockName, !b.isEmpty { return b }
            return ""
        }()
        
        let villName: String = {
            if let v = parcel.villageName, !v.isEmpty, v != "N/A" { return v }
            if let v = activeCadastralVillage?.name, !v.isEmpty { return v }
            return "Village"
        }()
        
        let villID: String = {
            if !parcel.villageID.isEmpty && parcel.villageID != "N/A" { return parcel.villageID }
            if let v = activeCadastralVillage?.id, !v.isEmpty { return v }
            return ""
        }()
        
        let identity = CanonicalParcelIdentity(
            parcelID: parcel.sourceFeatureID,
            plotNumber: parcel.plotNumber,
            districtName: distName,
            districtID: distID,
            tahasilName: blockName,
            tahasilID: blockID,
            villageName: villName,
            villageID: villID
        )
        let legacyParcel = Parcel(
            id: parcel.id,
            boundary: parcel.boundary,
            metadata: ParcelMetadata(identity: identity, estimatedAreaAcre: nil)
        )
        self.selectedParcel = legacyParcel
    }
    
    public static func districtNameForGISPrefix(_ prefix: String) -> String? {
        let codeMap: [String: String] = [
            "01": "Baleswar", "02": "Bolangir", "03": "Cuttack", "04": "Dhenkanal",
            "05": "Ganjam", "06": "Kalahandi", "07": "Keonjhar", "08": "Koraput",
            "09": "Mayurbhanj", "10": "Kandhamal", "11": "Puri", "12": "Sambalpur",
            "13": "Sundargarh", "14": "Angul", "15": "Bargarh", "16": "Bhadrak",
            "17": "Jagatsinghpur", "18": "Jajpur", "19": "Kendrapara", "20": "Khordha",
            "21": "Nuapada", "22": "Nayagarh", "23": "Subarnapur", "24": "Gajapati",
            "25": "Malkangiri", "26": "Nabarangpur", "27": "Rayagada", "28": "Boudh",
            "29": "Deogarh", "30": "Jharsuguda"
        ]
        return codeMap[prefix]
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
    public func toggleParcelDisplayStyle() {
        parcelDisplayStyle = (parcelDisplayStyle == .shadedFill) ? .boundaryOnly : .shadedFill
        showToast(parcelDisplayStyle.title, icon: parcelDisplayStyle.iconName)
    }
    
    @MainActor
    public func setParcelDisplayStyle(_ style: ParcelDisplayStyle) {
        parcelDisplayStyle = style
        showToast(style.title, icon: style.iconName)
    }
    
    @MainActor
    public func toggleUserTracking() {
        if isTrackingUser {
            isTrackingUser = false
            showToast("Free Exploration Mode", icon: "location")
        } else {
            shouldCenterOnUser = true
            isTrackingUser = true
            showToast("Centered on GPS Location", icon: "location.fill")
        }
    }
    
    @MainActor
    public func cycleMapFilter() {
        let allFilters = MapVisualFilter.allCases
        if let currentIndex = allFilters.firstIndex(of: visualFilter) {
            let nextIndex = (currentIndex + 1) % allFilters.count
            visualFilter = allFilters[nextIndex]
            showToast("Filter: \(visualFilter.displayName)", icon: visualFilter.icon)
        }
    }
    
    @MainActor
    public func setMapFilter(_ filter: MapVisualFilter) {
        visualFilter = filter
        showToast("Filter: \(filter.displayName)", icon: filter.icon)
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
            let plotSubtitle = "Locate plot in \(selectedStateName)"
            suggestions.append(SearchResult(title: "Plot: \(searchQuery)", subtitle: plotSubtitle, type: .plot(searchQuery)))
        }
        
        // 2. Local Areas Check
        if stateCode == "OD" {
            for area in localAreas {
                if area.name.lowercased().contains(searchQuery.lowercased()) {
                    let type: SearchResultType = area.name.contains("Town") ? .area(area.name, area.coord) : .village(area.name, area.coord)
                    suggestions.append(SearchResult(title: area.name, subtitle: "\(selectedStateName), India", type: type))
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
            let (url, _, _) = try await RoRService.shared.downloadROR(for: parcel)
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

// MARK: - Map Visual Preset Filters
public enum MapVisualFilter: String, CaseIterable, Identifiable {
    case natural = "Natural"
    case highContrast = "High Contrast"
    case emerald = "Emerald"
    case golden = "Golden"
    
    public var id: String { rawValue }
    
    public var displayName: String { rawValue }
    
    public var icon: String {
        switch self {
        case .natural: return "globe.asia.australia.fill"
        case .highContrast: return "circle.lefthalf.filled"
        case .emerald: return "leaf.fill"
        case .golden: return "sun.max.fill"
        }
    }
    
    public var rasterContrast: Double {
        switch self {
        case .natural: return 0.05
        case .highContrast: return 0.35
        case .emerald: return 0.18
        case .golden: return 0.22
        }
    }
    
    public var rasterSaturation: Double {
        switch self {
        case .natural: return 0.10
        case .highContrast: return 0.40
        case .emerald: return 0.55
        case .golden: return 0.25
        }
    }
}

// MARK: - Parcel Display Style (Shaded Fills vs Boundary Wireframe)
public enum ParcelDisplayStyle: String, CaseIterable, Identifiable, Codable {
    case shadedFill = "shadedFill"
    case boundaryOnly = "boundaryOnly"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .shadedFill: return "Shaded Plots"
        case .boundaryOnly: return "Boundary Only"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .shadedFill: return "Shaded"
        case .boundaryOnly: return "Outline"
        }
    }
    
    public var iconName: String {
        switch self {
        case .shadedFill: return "square.filled.on.square"
        case .boundaryOnly: return "square.dashed"
        }
    }
    
    public var description: String {
        switch self {
        case .shadedFill: return "Semi-transparent colored parcel fills with plot numbers"
        case .boundaryOnly: return "High-contrast boundary line outlines only"
        }
    }
}
