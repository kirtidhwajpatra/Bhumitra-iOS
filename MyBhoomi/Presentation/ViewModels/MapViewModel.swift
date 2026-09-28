import Foundation
import MapKit
import Combine
import SwiftUI
import MapLibre

public enum SpatialResolutionUIState: Equatable {
    case idle
    case resolving(title: String)
    case loadingParcels(villageName: String)
    case ready(message: String)
    case plotsNearYou(accuracy: Double)
    case approximateLocation(accuracy: Double)
    case preciseLocationRecommended(accuracy: Double)
    case exact(LocationResolutionResponse)
    case ambiguous([LocationResolutionCandidate])
    case noCoverage(reason: String)
    case outsideOdisha
    case locationPermissionDenied
    case locationServicesDisabled
    case locationTimeout
    case locationUnavailable
    case noInternet
    case backendTemporarilyUnavailable(reason: String)
    case parcelLoadFailed(villageName: String, reason: String)
    case unresolved(reason: String)
    case temporarilyUnavailable(reason: String)
}

public struct GPSAutoSelectionContext: Equatable {
    public let plotNumber: String
    public let accuracy: Double
    
    public init(plotNumber: String, accuracy: Double) {
        self.plotNumber = plotNumber
        self.accuracy = accuracy
    }
}

public final class MapViewModel: NSObject, ObservableObject {
    @MainActor @Published public var parcels: [Parcel] = []
    @MainActor @Published public var selectedParcel: Parcel?
    
    // MARK: - Official 4K GEO Cadastral Pipeline State
    @MainActor @Published public var cadastralShape: MLNShape? = nil
    @MainActor @Published public var cadastralParcels: [CadastralParcel] = []
    @MainActor @Published public var selectedCadastralParcel: CadastralParcel? = nil
    @MainActor @Published public var activeCadastralVillage: CadastralVillage? = nil
    @MainActor @Published public var parcelRenderingConfirmed: Bool = false
    private var activeParcelLoadTask: Task<Void, Never>? = nil
    
    // MARK: - Diagnostic State
    // Plain (non-@Published) on purpose: these change many times per village
    // load, and publishing each one re-rendered the whole map screen. No visible
    // view reads them; logic reads them directly.
    @MainActor public var gisApiStatus: String = "Connected"
    @MainActor public var debugPipelineStage: String = "IDLE"
    @MainActor public var debugExtentStatus: String = "Not Loaded"
    @MainActor public var debugDistrictName: String = "Odisha"
    @MainActor public var debugTahasilName: String = ""
    @MainActor public var debugGPName: String = ""
    @MainActor public var debugVillageName: String = "Not Selected"
    @MainActor public var debugVillageID: String = "--"
    @MainActor public var debugParcelCount: Int = 0
    @MainActor public var debugDecodedParcelCount: Int = 0
    @MainActor public var debugMapSourceCount: Int = 0
    @MainActor public var debugFirstPlots: [String] = []
    @MainActor public var debugRequestDurationMs: Double = 0.0
    @MainActor public var debugCacheStatus: String = "--"
    @MainActor public var debugErrorMessage: String? = nil
    @MainActor public var debugSelectedPlot: String? = nil
    @MainActor public var debugSelectedSourceID: String? = nil
    @MainActor public var debugGeometryType: String? = nil
    
    @MainActor @Published public var isLoading: Bool = false
    @MainActor @Published public var isDownloadingPDF: Bool = false
    @MainActor @Published public var spatialResolutionState: SpatialResolutionUIState = .idle
    @MainActor @Published public var lastFailedSearchResult: LocationSearchResult? = nil
    @MainActor @Published public var activeSelectionToken: UUID = UUID()
    @MainActor @Published public var isResolvingGPSLocation: Bool = false
    @MainActor @Published public var gpsAutoSelectionContext: GPSAutoSelectionContext? = nil
    private var activeGPSTask: _Concurrency.Task<Void, Never>? = nil
    
    @MainActor @Published public var isSearchFocused: Bool = false {
        didSet {
            if isSearchFocused {
                cancelActiveGPSAndClearPlotSelection()
            }
        }
    }
    @MainActor @Published public var searchQuery: String = "" {
        didSet {
            if !searchQuery.isEmpty {
                cancelActiveGPSAndClearPlotSelection()
            }
            updateSuggestions()
        }
    }
    @MainActor @Published public var searchResults: [LocationSearchResult] = []
    @MainActor @Published public var isSatellite: Bool = true
    @MainActor @Published public var showParcels: Bool = true
    @MainActor @Published public var parcelDisplayStyle: ParcelDisplayStyle = .boundaryOnly {
        didSet {
            UserDefaults.standard.set(parcelDisplayStyle.rawValue, forKey: "bhumitra_parcel_display_style")
        }
    }
    @MainActor @Published public var shouldCenterOnUser: Bool = false
    @MainActor @Published public var isTrackingUser: Bool = false
    /// Not published: written by the map on user movement, read only by logic.
    /// Publishing it re-rendered the entire map screen on every GPS update.
    @MainActor public var lastKnownMapLibreUserLocation: Coordinate? = nil
    @MainActor @Published public var shouldResetBearing: Bool = false
    @MainActor @Published public var visualFilter: MapVisualFilter = .natural
    /// Last known camera, kept in sync by the map after each pan/zoom. Not
    /// published: the camera is *driven* by `pendingCameraTarget`, so publishing
    /// these re-rendered everything after every pan for no visible change.
    @MainActor public var mapCenter: Coordinate = Coordinate(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude)
    @MainActor public var zoomLevel: Double = 15.5
    
    // MARK: - Programmatic Camera Command (Single Intent)
    public struct CameraTarget: Equatable {
        public let center: CLLocationCoordinate2D
        public let zoom: Double
        public let animated: Bool
        
        public init(center: CLLocationCoordinate2D, zoom: Double, animated: Bool = true) {
            self.center = center
            self.zoom = zoom
            self.animated = animated
        }
        
        public init(latitude: Double, longitude: Double, zoom: Double, animated: Bool = true) {
            self.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            self.zoom = zoom
            self.animated = animated
        }
        
        // Explicit: CLLocationCoordinate2D isn't Equatable in CoreLocation (the
        // conformance used to leak in from the unused MapLibreSwiftUI package).
        public static func == (lhs: CameraTarget, rhs: CameraTarget) -> Bool {
            lhs.center.latitude == rhs.center.latitude &&
            lhs.center.longitude == rhs.center.longitude &&
            lhs.zoom == rhs.zoom &&
            lhs.animated == rhs.animated
        }
    }
    
    @MainActor @Published public var pendingCameraTarget: CameraTarget? = nil
    
    // MARK: - Uttar Pradesh map prototype (isolated; see MapViewModel+UP.swift)
    @MainActor @Published public var upSession: UPVillageSession? = nil
    @MainActor @Published public var selectedUPPlot: UPPlotResult? = nil
    @MainActor @Published public var showUPPicker: Bool = false
    @MainActor @Published public var isUPIdentifying: Bool = false
    @MainActor public var upIdentifyTask: _Concurrency.Task<Void, Never>? = nil
    /// Latest UP tap/search request; older responses are ignored when it changes.
    @MainActor public var upRequestGeneration: UUID = UUID()
    @MainActor public var upReturnVillage: CadastralVillage? = nil
    @MainActor public var upReturnCenter: Coordinate? = nil
    @MainActor public var upReturnZoom: Double = 15.5
    @MainActor public var upReturnIsSatellite: Bool = true
    @MainActor public var upReturnShowParcels: Bool = true

    @MainActor
    public func moveCamera(to coordinate: Coordinate, zoom: Double? = nil, animated: Bool = true) {
        let targetZoom = zoom ?? self.zoomLevel
        self.mapCenter = coordinate
        self.zoomLevel = targetZoom
        self.pendingCameraTarget = CameraTarget(latitude: coordinate.latitude, longitude: coordinate.longitude, zoom: targetZoom, animated: animated)
    }
    
    @MainActor @Published public var tapPoint: CGPoint? = nil
    @MainActor @Published public var selectedLocationInfo: LocalAdminClient.LocationInfo? = nil
    @MainActor @Published public var downloadedRORs: [DownloadedROR] = []
    @MainActor @Published public var isDrawingBoundaryLoading: Bool = false
    @MainActor public var currentFlow: String = "LIVE"
    
    // MARK: - Location Selector Coordination
    @MainActor @Published public var pendingDistrictSelectionName: String? = nil
    @MainActor @Published public var shouldOpenLocationPicker: Bool = false
    
    public struct DownloadedROR: Identifiable, Codable {
        public let id = UUID()
        public let filename: String
        public let date: String
        public let details: String
    }
    
    private let parcelRepository: ParcelRepositoryProtocol
    private let cadastralRepository: CadastralRepository
    
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
        setupConnectivityMonitoring()
        
        // Rank same-named villages near the user first: GPS if known, otherwise the
        // area the user is looking at (only once zoomed in past district level).
        LocationSearchService.shared.proximityProvider = { [weak self] in
            guard let self else { return nil }
            if let user = self.lastKnownMapLibreUserLocation,
               user.latitude != 0 || user.longitude != 0 { return user }
            if let village = self.activeCadastralVillage, !village.id.isEmpty { return self.mapCenter }
            return self.zoomLevel >= 11 ? self.mapCenter : nil
        }
        
        // Search results are NOT mirrored into this view model any more: every
        // result batch republished MapViewModel and re-rendered the whole map
        // while typing. Search UI observes LocationSearchService directly.
        
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
    public func clearCadastralVillage() {
        activeParcelLoadTask?.cancel()
        activeParcelLoadTask = nil
        currentLoadingVillageID = nil
        if isLoading { isLoading = false }
        if isDrawingBoundaryLoading { isDrawingBoundaryLoading = false }
        activeCadastralVillage = nil
        cadastralShape = nil
        cadastralParcels = []
        selectedCadastralParcel = nil
        selectedParcel = nil
        selectedLocationInfo = nil
        tapPoint = nil
        debugParcelCount = 0
        debugDecodedParcelCount = 0
        debugFirstPlots = []
    }
    
    @MainActor
    public func loadCadastralVillage(village: CadastralVillage, state: String = "ODISHA", sheetNo: String? = nil, preserveCenter: Bool = false) async {
        guard !Task.isCancelled else { return }
        if upSession != nil { exitUP(restorePrevious: false) }
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
        
        let stateDisplayName = (state.uppercased() == "BIHAR") ? "Bihar" : (village.districtName ?? "Odisha")
        debugDistrictName = village.districtName ?? stateDisplayName
        debugTahasilName = village.blockName ?? ""
        debugGPName = village.gpID ?? ""
        debugVillageName = village.name
        debugVillageID = village.id
        debugPipelineStage = "FETCHING_PARCELS"
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Overlapped Extent & Parcel Fetching: Overlap extent and parcel collection safely
            debugLog("[\(currentFlow)-5] parcel request started for \(village.name) (ID: \(village.id))")
            
            async let extentFetch: CadastralExtent? = {
                do {
                    return try await self.cadastralRepository.getVillageExtent(village: village, state: state)
                } catch {
                    debugLog("DEBUG: ⚠️ [loadCadastralVillage] Extent fetch failed for \(village.name): \(error). Proceeding to parcels...")
                    return nil
                }
            }()
            
            async let parcelsFetch = self.cadastralRepository.loadVillageParcels(village: village, sheetNo: sheetNo, state: state)
            
            // Adjust camera to extent if available while parcel response is streaming in parallel
            if let extent = await extentFetch {
                guard self.currentLoadingVillageID == village.id && !Task.isCancelled else { return }
                let currentLat = self.mapCenter.latitude
                let currentLng = self.mapCenter.longitude
                let isInsideExtent = (extent.minLng <= currentLng && currentLng <= extent.maxLng &&
                                      extent.minLat <= currentLat && currentLat <= extent.maxLat)
                if !preserveCenter || !isInsideExtent {
                    moveCamera(to: Coordinate(latitude: extent.centerLat, longitude: extent.centerLng), zoom: 16.5)
                    debugLog("DEBUG: 🗺️ [loadCadastralVillage] Extent loaded for \(village.name): Moved camera to center lat=\(extent.centerLat), lng=\(extent.centerLng)")
                } else {
                    debugLog("DEBUG: 🗺️ [loadCadastralVillage] Extent loaded for \(village.name): preserveCenter is TRUE (inside extent). Preserving mapCenter at (\(self.mapCenter.latitude), \(self.mapCenter.longitude)), zoom=\(self.zoomLevel)")
                }
                self.debugExtentStatus = String(format: "Lat: %.4f, Lng: %.4f", extent.centerLat, extent.centerLng)
                self.debugPipelineStage = "EXTENT_LOADED"
            } else {
                self.debugExtentStatus = "Extent Failed"
            }
            
            let (parsedData, isCacheHit) = try await parcelsFetch
            guard self.currentLoadingVillageID == village.id && !Task.isCancelled else { return }
            
            debugLog("[\(currentFlow)-6] parcel response = \(parsedData.totalCount) features, decoded = \(parsedData.parcels.count)")
            
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            
            let finalShape: MLNShape? = parsedData.shape ?? {
                if let d = parsedData.shapeData {
                    return try? MLNShape(data: d, encoding: String.Encoding.utf8.rawValue)
                }
                return nil
            }()
            
            self.cadastralShape = finalShape
            self.cadastralParcels = parsedData.parcels
            debugLog("[\(currentFlow)-7] SwiftUI parcel state updated (cadastralShape=\(parsedData.shape != nil), parcels=\(parsedData.parcels.count))")
            self.debugParcelCount = parsedData.totalCount
            self.debugDecodedParcelCount = parsedData.parcels.count
            self.debugMapSourceCount = parsedData.shape != nil ? parsedData.totalCount : 0
            self.debugFirstPlots = Array(parsedData.parcels.prefix(5).map { $0.plotNumber })
            self.debugRequestDurationMs = round(duration)
            self.debugCacheStatus = isCacheHit ? "Hit (0ms)" : "Miss (\(Int(duration))ms)"
            self.debugPipelineStage = parsedData.totalCount > 0 ? "PARCELS_LOADED (\(parsedData.totalCount))" : "ZERO_PARCELS"
            self.gisApiStatus = "Connected"
            self.debugErrorMessage = nil
            
            debugLog("""
            [CADASTRAL] API DATA LOADED:
            villageID=\(village.id)
            villageName=\(village.name)
            parcelAPIFeatures=\(parsedData.totalCount)
            decodedSwiftFeatures=\(parsedData.parcels.count)
            firstPlots=\(self.debugFirstPlots)
            """)
            
            // Automatic Parcel Centroid Realignment: Ensure camera is centered directly over the loaded parcels
            if let cLat = parsedData.centroidLat, let cLng = parsedData.centroidLng {
                let curLat = self.mapCenter.latitude
                let curLng = self.mapCenter.longitude
                let isInsideParcels = (abs(curLat - cLat) <= 0.015 && abs(curLng - cLng) <= 0.015)
                if !preserveCenter || !isInsideParcels {
                    debugLog("DEBUG: 🗺️ [loadCadastralVillage] Centering camera on true parcel centroid (\(cLat), \(cLng)), zoom=16.5")
                    moveCamera(to: Coordinate(latitude: cLat, longitude: cLng), zoom: max(self.zoomLevel, 16.5))
                }
            } else if !parsedData.parcels.isEmpty {
                var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0
                for p in parsedData.parcels {
                    let c = p.centroidCoordinate
                    if c.latitude < minLat { minLat = c.latitude }
                    if c.latitude > maxLat { maxLat = c.latitude }
                    if c.longitude < minLng { minLng = c.longitude }
                    if c.longitude > maxLng { maxLng = c.longitude }
                }
                let pCenterLat = (minLat + maxLat) / 2.0
                let pCenterLng = (minLng + maxLng) / 2.0
                let curLat = self.mapCenter.latitude
                let curLng = self.mapCenter.longitude
                let isInsideParcels = (minLat - 0.005 <= curLat && curLat <= maxLat + 0.005 &&
                                      minLng - 0.005 <= curLng && curLng <= maxLng + 0.005)
                if !preserveCenter || !isInsideParcels {
                    debugLog("DEBUG: 🗺️ [loadCadastralVillage] Centering camera on true parcel centroid (\(pCenterLat), \(pCenterLng)), zoom=16.5")
                    moveCamera(to: Coordinate(latitude: pCenterLat, longitude: pCenterLng), zoom: max(self.zoomLevel, 16.5))
                }
            }
            
            // Smoothly finish loading state immediately
            self.isDrawingBoundaryLoading = false
            self.isLoading = false
            
            debugLog("DEBUG: 🗺️ Loaded \(parsedData.totalCount) parcels for village \(village.name) (ID: \(village.id)). First plots: \(debugFirstPlots)")
            
            if parsedData.totalCount > 0 {
                self.onParcelLayerRenderSuccess(villageId: village.id, token: self.activeSelectionToken)
            } else {
                self.spatialResolutionState = .noCoverage(reason: "Cadastral parcel data is not available for this village")
                showToast("Cadastral parcel data is not available for this village.", icon: "exclamationmark.triangle")
            }
        } catch {
            guard self.currentLoadingVillageID == village.id && !Task.isCancelled else { return }
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            self.debugRequestDurationMs = round(duration)
            self.debugCacheStatus = "Error"
            self.debugPipelineStage = "PARCEL_FETCH_FAILED"
            self.debugErrorMessage = error.localizedDescription
            self.gisApiStatus = "Failed"
            self.isDrawingBoundaryLoading = false
            self.isLoading = false
            debugLog("DEBUG: ❌ Failed to load village parcels for \(village.name): \(error)")
            
            if self.isNetworkConnectionError(error) {
                self.spatialResolutionState = .noInternet
                showToast("No Internet Connection", icon: "wifi.slash")
            } else {
                self.spatialResolutionState = .parcelLoadFailed(villageName: village.name, reason: error.localizedDescription)
            }
            
            if let apiErr = error as? CadastralAPIError {
                switch apiErr {
                case .biharGisDisabled:
                    showToast("Bihar cadastral GIS is currently disabled", icon: "shield.slash")
                case .serverUnavailable(let msg):
                    debugLog("DEBUG: parcel server unavailable: \(msg)")
                    showToast("Plot map is busy right now", icon: "exclamationmark.triangle")
                case .notFound(let msg):
                    showToast("Not found: \(msg)", icon: "questionmark.circle")
                case .decodingError:
                    showToast("Failed to decode parcel data", icon: "exclamationmark.triangle")
                case .invalidURL:
                    showToast("Invalid API URL", icon: "link.badge.plus")
                case .mapTooLarge(let msg):
                    showToast(msg, icon: "map.fill")
                }
            } else {
                showToast("Failed to load cadastral map: \(error.localizedDescription)", icon: "exclamationmark.triangle")
            }
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
                moveCamera(to: Coordinate(latitude: c.latitude, longitude: c.longitude), zoom: 18.0)
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
                    moveCamera(to: Coordinate(latitude: c.latitude, longitude: c.longitude), zoom: 18.0)
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
        if self.gpsAutoSelectionContext?.plotNumber != parcel.plotNumber {
            self.gpsAutoSelectionContext = nil
        }
        self.selectedCadastralParcel = parcel
        self.debugSelectedPlot = parcel.plotNumber
        self.debugSelectedSourceID = parcel.sourceFeatureID
        self.debugGeometryType = parcel.geometryType
        
        let villID: String = {
            if !parcel.villageID.isEmpty && parcel.villageID != "N/A" { return parcel.villageID }
            if let v = activeCadastralVillage?.id, !v.isEmpty { return v }
            return ""
        }()
        
        let blockID: String = {
            if !parcel.blockID.isEmpty && parcel.blockID != "N/A" { return parcel.blockID }
            if let b = activeCadastralVillage?.blockID, !b.isEmpty { return b }
            if villID.count >= 4 {
                let code = String(villID.dropFirst(2).prefix(2))
                if let intCode = Int(code) {
                    return String(intCode)
                }
                return code
            }
            return ""
        }()
        
        let distName: String = {
            if let d = parcel.districtName, !d.isEmpty, d != "N/A", d != "Odisha" { return d }
            if let d = activeCadastralVillage?.districtName, !d.isEmpty, d != "Odisha" { return d }
            if let p = pendingDistrictSelectionName, !p.isEmpty, p != "Odisha" { return p }
            if let d = selectedLocationInfo?.district, !d.isEmpty, d != "Odisha" { return d }
            if villID.count >= 2 {
                let prefix = String(villID.prefix(2))
                if let mapped = MapViewModel.districtNameForGISPrefix(prefix) {
                    return mapped
                }
            }
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
            if let d = selectedLocationInfo?.districtID, !d.isEmpty { return d }
            if villID.count >= 2 {
                let prefix = String(villID.prefix(2))
                if let intCode = Int(prefix) {
                    return String(intCode)
                }
            }
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
            if let t = selectedLocationInfo?.tehsil, !t.isEmpty, t != "Unknown Tehsil" { return t }
            if villID.count >= 4 {
                let distP = String(villID.prefix(2))
                let tahP = String(villID.dropFirst(2).prefix(2))
                if let mapped = MapViewModel.tahasilNameForGISCodes(districtCode: distP, tahasilCode: tahP) {
                    return mapped
                }
            }
            if distName != "Odisha" && !distName.isEmpty {
                return "\(distName) Sadar"
            }
            return ""
        }()
        
        let villName: String = {
            if let v = parcel.villageName, !v.isEmpty, v != "N/A", v != "Village" { return v }
            if let v = activeCadastralVillage?.name, !v.isEmpty, v != "Village" { return v }
            return "Village"
        }()
        
        let compoundKey = "\(distID):\(blockID):\(villID):\(parcel.plotNumber)"
        let identity = CanonicalParcelIdentity(
            parcelID: compoundKey,
            plotNumber: parcel.plotNumber,
            districtName: distName,
            districtID: distID,
            tahasilName: blockName,
            tahasilID: blockID,
            villageName: villName,
            villageID: villID
        )
        let computedArea = parcel.boundary.count >= 3 ? OdishaAreaFormatter.calculateAcre(from: parcel.boundary) : nil
        let legacyParcel = Parcel(
            id: compoundKey,
            boundary: parcel.boundary,
            metadata: ParcelMetadata(identity: identity, estimatedAreaAcre: computedArea)
        )
        self.selectedParcel = legacyParcel
        
        // Asynchronously resolve true district, tahasil, and village if GIS tile attributes are generic or incomplete
        if distName == "Odisha" || blockName.isEmpty || villName == "Village" {
            let coord: Coordinate? = {
                if let first = parcel.boundary.first { return first }
                if parcel.centroid.count >= 2 { return Coordinate(latitude: parcel.centroid[1], longitude: parcel.centroid[0]) }
                return nil
            }()
            
            if let targetCoord = coord {
                _Concurrency.Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if let loc = try? await LocalAdminClient.shared.fetchLocationInfo(latitude: targetCoord.latitude, longitude: targetCoord.longitude) {
                        if self.selectedCadastralParcel?.plotNumber == parcel.plotNumber {
                            self.selectedLocationInfo = loc
                            let enriched = CadastralParcel(
                                source: parcel.source,
                                sourceFeatureID: parcel.sourceFeatureID,
                                districtID: parcel.districtID,
                                districtName: (parcel.districtName == nil || parcel.districtName == "Odisha") && !loc.district.isEmpty && loc.district != "Unknown District" ? loc.district : parcel.districtName,
                                blockID: parcel.blockID,
                                blockName: (parcel.blockName == nil || parcel.blockName?.isEmpty == true) && !loc.tehsil.isEmpty && loc.tehsil != "Unknown Tehsil" ? loc.tehsil : parcel.blockName,
                                gpID: parcel.gpID ?? loc.panchayat,
                                villageID: parcel.villageID,
                                villageName: (parcel.villageName == nil || parcel.villageName == "Village") && !loc.village.isEmpty && loc.village != "Unknown Village" ? loc.village : parcel.villageName,
                                plotNumber: parcel.plotNumber,
                                centroid: parcel.centroid,
                                geometryType: parcel.geometryType,
                                boundary: parcel.boundary,
                                retrievedAt: parcel.retrievedAt
                            )
                            self.onCadastralParcelSelected(enriched)
                        }
                    }
                }
            }
        }
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
        if let match = codeMap[prefix] { return match }
        if prefix.count == 1 {
            return codeMap["0\(prefix)"]
        }
        return nil
    }
    
    public static func tahasilNameForGISCodes(districtCode: String, tahasilCode: String) -> String? {
        let distP = districtCode.count == 1 ? "0\(districtCode)" : districtCode
        let tahP = tahasilCode.count == 1 ? "0\(tahasilCode)" : tahasilCode
        let key = "\(distP)_\(tahP)"
        let tahasilMap: [String: String] = [
            // Keonjhar (07)
            "07_01": "Anandapur",
            "07_02": "Champua",
            "07_03": "Barbil",
            "07_04": "Keonjhar Sadar",
            "07_05": "Telkoi",
            "07_06": "Ghatagaon",
            "07_07": "Hatadihi",
            "07_08": "Jhumpura",
            "07_09": "Patna",
            "07_10": "Saharpada",
            
            // Cuttack (03)
            "03_01": "Athagarh",
            "03_02": "Banki",
            "03_03": "Badamba",
            "03_04": "Cuttack Sadar",
            "03_05": "Narasinghpur",
            "03_06": "Niali",
            "03_07": "Salipur",
            "03_08": "Mahanga",
            "03_09": "Tangi Choudwar",
            "03_10": "Kishorenagar",
            "03_11": "Nischintakoili",
            "03_12": "Baranga",
            "03_13": "Kantapada",
            "03_14": "Damapara",
            
            // Khordha (20)
            "20_01": "Banapur",
            "20_02": "Bhubaneswar",
            "20_03": "Bolagarh",
            "20_04": "Begunia",
            "20_05": "Chilika",
            "20_06": "Jatni",
            "20_07": "Khordha",
            "20_08": "Balianta",
            "20_09": "Balipatna",
            "20_10": "Tangi",
            
            // Balasore (01)
            "01_01": "Baleswar Sadar",
            "01_02": "Basta",
            "01_03": "Jaleswar",
            "01_04": "Nilgiri",
            "01_05": "Soro",
            "01_10": "Oupada",
            
            // Bolangir (02)
            "02_01": "Bolangir",
            "02_08": "Agalpur",
            
            // Dhenkanal (04)
            "04_01": "Dhenkanal Sadar",
            "04_02": "Kamakhyanagar",
            "04_03": "Bhuban",
            "04_04": "Hindol",
            
            // Ganjam (05)
            "05_01": "Chhatrapur",
            "05_02": "Bhanjanagar",
            "05_03": "Berhampur",
            
            // Kalahandi (06)
            "06_01": "Bhawanipatna",
            "06_02": "Dharmagarh",
            
            // Puri (11)
            "11_01": "Puri Sadar",
            "11_02": "Pipili",
            "11_03": "Nimapara",
            "11_04": "Kakatpur",
            "11_05": "Brahmagiri",
            "11_06": "Gop",
            "11_07": "Satyabadi",
            "11_08": "Krushnaprasad",
            "11_09": "Delanga",
            "11_10": "Kanas",
            "11_11": "Astaranga",
            
            // Sambalpur (12)
            "12_01": "Sambalpur Sadar",
            "12_02": "Kuchinda",
            "12_03": "Rairakhol",
            "12_04": "Rengali",
            
            // Sundargarh (13)
            "13_01": "Sundargarh Sadar",
            "13_02": "Panposh",
            "13_03": "Bonai",
            "13_04": "Rajgangpur",
            
            // Mayurbhanj (09)
            "09_01": "Baripada",
            "09_02": "Rairangpur",
            "09_03": "Karanjia",
            "09_04": "Udala"
        ]
        return tahasilMap[key]
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
    public func toggleMapType() {
        isSatellite.toggle()
        showToast(isSatellite ? "Satellite Layer" : "Standard Map Layer", icon: isSatellite ? "square.3.layers.3d" : "map")
    }
    
    @MainActor
    public func resetBearingToNorth() {
        shouldResetBearing = true
        showToast("Map Oriented to North", icon: "location.north.line.fill")
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
        locateAndShowNearbyPlots()
    }
    
    // MARK: - Search Conflict Cancellation (P0 Fix 3)
    
    @MainActor
    public func cancelActiveGPSAndClearPlotSelection() {
        // Only invalidate the selection when a GPS flow is actually running.
        // Rotating the token unconditionally (on every keystroke) forced the map
        // to re-upload the whole village's plots each time.
        let hadGPSFlow = activeGPSTask != nil || isResolvingGPSLocation || gpsAutoSelectionContext != nil
        activeGPSTask?.cancel()
        activeGPSTask = nil
        if isResolvingGPSLocation { isResolvingGPSLocation = false }
        if hadGPSFlow { activeSelectionToken = UUID() }
        if gpsAutoSelectionContext != nil {
            gpsAutoSelectionContext = nil
            selectedParcel = nil
            selectedCadastralParcel = nil
        }
        switch spatialResolutionState {
        case .resolving, .loadingParcels, .plotsNearYou, .approximateLocation, .preciseLocationRecommended:
            spatialResolutionState = .idle
        default:
            break
        }
    }
    
    public func isNetworkConnectionError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .timedOut, .dnsLookupFailed:
                return true
            default:
                break
            }
        }
        let msg = error.localizedDescription.lowercased()
        return msg.contains("offline") || msg.contains("internet") || msg.contains("network connection") || msg.contains("connection lost")
    }
    
    // MARK: - GPS -> Nearby Cadastral Plots Flow
    
    /// Triggered by the map GPS button. Obtains current GPS coordinates,
    /// centers the camera, resolves the administrative hierarchy & revenue village via backend,
    /// loads cadastral parcels, and highlights containing plot if identified.
    @MainActor
    public func locateAndShowNearbyPlots() {
        #if DEBUG
        debugLog("[GPS_DEBUG][1] BUTTON_TAPPED GPS location button pressed.")
        #endif
        
        // P0 Fix 3: User taps GPS button -> dismiss search keyboard & suggestions, invalidate search
        self.isSearchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        self.searchQuery = ""
        self.searchResults = []
        LocationSearchService.shared.clearSearch()
        self.activeParcelLoadTask?.cancel()
        self.activeParcelLoadTask = nil
        self.gpsAutoSelectionContext = nil
        
        // Fast visual response: immediately trigger user tracking
        isTrackingUser = true
        
        // Cancel any previous GPS task
        activeGPSTask?.cancel()
        activeGPSTask = nil
        
        isResolvingGPSLocation = true
        
        // Immediate UI feedback right after lock acquisition
        self.spatialResolutionState = .resolving(title: "Finding your location…")
        #if DEBUG
        debugLog("[GPS_DEBUG][6] RESOLUTION_STATE Set to 'Finding your location…'")
        #endif
        
        let selectionToken = UUID()
        self.activeSelectionToken = selectionToken
        self.parcelRenderingConfirmed = false
        
        self.activeGPSTask = _Concurrency.Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                self.isResolvingGPSLocation = false
                #if DEBUG
                debugLog("[GPS_DEBUG][16] GPS_FLOW_COMPLETE isResolvingGPSLocation released.")
                #endif
            }
            
            #if DEBUG
            debugLog("[GPS_DEBUG][2] LOCATION_REQUEST_START Initiating bounded GPS acquisition.")
            #endif
            
            var acquiredLocation: CLLocation? = nil
            
            do {
                let location = try await LocationPermissionManager.shared.requestCurrentLocation()
                acquiredLocation = location
                #if DEBUG
                debugLog("[GPS_DEBUG][3] LOCATION_RECEIVED Obtained CoreLocation fix: accuracy=\(location.horizontalAccuracy)m, age=\(-location.timestamp.timeIntervalSinceNow)s")
                #endif
            } catch let error as LocationPermissionManager.LocationError {
                guard !Task.isCancelled, self.activeSelectionToken == selectionToken else { return }
                #if DEBUG
                debugLog("[GPS_DEBUG][3] CoreLocation error: \(error.localizedDescription). Checking MapLibre user location fallback...")
                #endif
                
                switch error {
                case .permissionDenied:
                    self.spatialResolutionState = .locationPermissionDenied
                    self.showToast("Location permission required", icon: "location.slash")
                    return
                case .servicesDisabled:
                    self.spatialResolutionState = .locationServicesDisabled
                    self.showToast("Please enable Location Services", icon: "location.slash")
                    return
                case .timeout:
                    // Check Tier 2 Fallback: MapLibre user dot
                    if let mapLibreCoord = self.lastKnownMapLibreUserLocation,
                       CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: mapLibreCoord.latitude, longitude: mapLibreCoord.longitude)),
                       (mapLibreCoord.latitude != 0.0 || mapLibreCoord.longitude != 0.0) {
                        acquiredLocation = CLLocation(
                            coordinate: CLLocationCoordinate2D(latitude: mapLibreCoord.latitude, longitude: mapLibreCoord.longitude),
                            altitude: 0,
                            horizontalAccuracy: 50.0,
                            verticalAccuracy: -1,
                            timestamp: Date()
                        )
                        #if DEBUG
                        debugLog("[GPS_DEBUG][3] LOCATION_RECEIVED Using MapLibre user location fallback: \(mapLibreCoord.latitude), \(mapLibreCoord.longitude)")
                        #endif
                    } else {
                        self.spatialResolutionState = .locationTimeout
                        self.showToast("Unable to acquire GPS signal", icon: "location.slash")
                        return
                    }
                case .locationUnavailable(_):
                    // Check Tier 2 Fallback: MapLibre user dot
                    if let mapLibreCoord = self.lastKnownMapLibreUserLocation,
                       CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: mapLibreCoord.latitude, longitude: mapLibreCoord.longitude)),
                       (mapLibreCoord.latitude != 0.0 || mapLibreCoord.longitude != 0.0) {
                        acquiredLocation = CLLocation(
                            coordinate: CLLocationCoordinate2D(latitude: mapLibreCoord.latitude, longitude: mapLibreCoord.longitude),
                            altitude: 0,
                            horizontalAccuracy: 50.0,
                            verticalAccuracy: -1,
                            timestamp: Date()
                        )
                        #if DEBUG
                        debugLog("[GPS_DEBUG][3] LOCATION_RECEIVED Using MapLibre user location fallback: \(mapLibreCoord.latitude), \(mapLibreCoord.longitude)")
                        #endif
                    } else {
                        self.spatialResolutionState = .locationUnavailable
                        self.showToast("Location temporarily unavailable", icon: "location.slash")
                        return
                    }
                }
            } catch {
                guard !Task.isCancelled, self.activeSelectionToken == selectionToken else { return }
                #if DEBUG
                debugLog("[GPS_DEBUG][3] Location error: \(error.localizedDescription). Checking MapLibre user location fallback...")
                #endif
                
                if let mapLibreCoord = self.lastKnownMapLibreUserLocation,
                   CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: mapLibreCoord.latitude, longitude: mapLibreCoord.longitude)),
                   (mapLibreCoord.latitude != 0.0 || mapLibreCoord.longitude != 0.0) {
                    acquiredLocation = CLLocation(
                        coordinate: CLLocationCoordinate2D(latitude: mapLibreCoord.latitude, longitude: mapLibreCoord.longitude),
                        altitude: 0,
                        horizontalAccuracy: 50.0,
                        verticalAccuracy: -1,
                        timestamp: Date()
                    )
                    #if DEBUG
                    debugLog("[GPS_DEBUG][3] LOCATION_RECEIVED Using MapLibre user location fallback: \(mapLibreCoord.latitude), \(mapLibreCoord.longitude)")
                    #endif
                } else {
                    self.spatialResolutionState = .locationUnavailable
                    self.showToast("Location temporarily unavailable", icon: "location.slash")
                    return
                }
            }
            
            guard !Task.isCancelled, self.activeSelectionToken == selectionToken else { return }
            guard let location = acquiredLocation else {
                self.spatialResolutionState = .locationUnavailable
                self.showToast("Unable to get your location", icon: "location.slash")
                return
            }
            
            let coord = location.coordinate
            let lat = coord.latitude
            let lon = coord.longitude
            let accuracy = location.horizontalAccuracy
            let isReducedAccuracy = LocationPermissionManager.shared.isReducedAccuracy
            
            #if DEBUG
            debugLog("[GPS_DEBUG][4] COORDINATE lat=\(lat), lon=\(lon), accuracy=\(accuracy)m, isReduced=\(isReducedAccuracy)")
            #endif
            
            // 2. Center map camera on user coordinate at zoom 16.5
            self.moveCamera(to: Coordinate(latitude: lat, longitude: lon), zoom: 16.5)
            
            // 3. Odisha Bounding Box Gate (17.70 <= lat <= 22.65, 81.30 <= lon <= 87.60)
            let isInsideOdisha = (17.70 <= lat && lat <= 22.65) && (81.30 <= lon && lon <= 87.60)
            #if DEBUG
            debugLog("[GPS_DEBUG][5] ODISHA_GATE isInsideOdisha=\(isInsideOdisha) for (\(lat), \(lon))")
            #endif
            
            guard isInsideOdisha else {
                self.lastFailedSearchResult = nil
                self.spatialResolutionState = .outsideOdisha
                Theme.notificationHaptic(.warning)
                self.showToast("Location is outside Odisha cadastral coverage", icon: "slash.circle")
                return
            }
            
            // P0 Fix 2 Confidence Gating Check:
            // Tier D: Very Low Confidence (> 100m or iOS Reduced Accuracy)
            if isReducedAccuracy || accuracy > 100.0 {
                #if DEBUG
                debugLog("[GPS_DEBUG][5.1] VERY_LOW_CONFIDENCE accuracy=\(accuracy)m, isReduced=\(isReducedAccuracy)")
                #endif
                self.spatialResolutionState = .preciseLocationRecommended(accuracy: accuracy)
                Theme.notificationHaptic(.warning)
                return
            }
            
            // 4. Transition UI feedback to finding plots near you
            self.spatialResolutionState = .resolving(title: "plots near you")
            self.showToast("Finding plots near you...", icon: "scope")
            #if DEBUG
            debugLog("[GPS_DEBUG][6] RESOLUTION_STATE Set to 'plots near you'")
            #endif
            
            #if DEBUG
            debugLog("[GPS_DEBUG][7] RESOLVE_API_START Calling POST /api/v1/location/resolve for (\(lat), \(lon))")
            #endif
            
            // 5. Call backend spatial resolver with one automatic retry for transient failures
            do {
                let resolution: LocationResolutionResponse
                do {
                    resolution = try await LocationSearchService.shared.resolveCoordinate(
                        latitude: lat,
                        longitude: lon,
                        candidateVillageIds: nil
                    )
                } catch {
                    // First attempt failed — retry once after 1 second backoff
                    guard !Task.isCancelled, self.activeSelectionToken == selectionToken else { return }
                    #if DEBUG
                    debugLog("[GPS_DEBUG][7] RESOLVE_API_RETRY First attempt failed: \(error.localizedDescription). Retrying after 1s...")
                    #endif
                    self.spatialResolutionState = .resolving(title: "Retrying…")
                    try await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled, self.activeSelectionToken == selectionToken else { return }
                    resolution = try await LocationSearchService.shared.resolveCoordinate(
                        latitude: lat,
                        longitude: lon,
                        candidateVillageIds: nil
                    )
                }
                
                guard !Task.isCancelled, self.activeSelectionToken == selectionToken else {
                    #if DEBUG
                    debugLog("[GPS_DEBUG][8] RESOLVE_API_RESPONSE Stale resolution token ignored.")
                    #endif
                    return
                }
                
                #if DEBUG
                debugLog("[GPS_DEBUG][8] RESOLVE_API_RESPONSE Received response from server.")
                debugLog("[GPS_DEBUG][9] RESOLVE_RESULT status=\(resolution.status.rawValue), villageId=\(resolution.revenueVillageId ?? "nil"), villageName=\(resolution.revenueVillage ?? "nil"), plotNumber=\(resolution.plotNumber ?? "nil")")
                #endif
                
                switch resolution.status {
                case .exact:
                    guard let vId = resolution.revenueVillageId, let vName = resolution.revenueVillage else {
                        self.spatialResolutionState = .unresolved(reason: "Missing village identity")
                        self.showToast("Could not determine official village", icon: "questionmark.circle")
                        return
                    }
                    
                    let targetVillage = CadastralVillage(
                        id: vId,
                        name: vName,
                        gpID: nil,
                        blockID: resolution.tahasilId ?? "",
                        districtID: resolution.districtId,
                        blockName: resolution.tahasil,
                        districtName: resolution.district
                    )
                    
                    self.spatialResolutionState = .loadingParcels(villageName: vName)
                    self.showToast("Loading nearby land plots...", icon: "map.fill")
                    
                    #if DEBUG
                    debugLog("[GPS_DEBUG][10] VILLAGE_LOAD_START Loading village: \(vName) (ID: \(vId))")
                    debugLog("[GPS_DEBUG][11] PARCEL_API_START Calling /api/v1/gis/village/\(vId)/parcels")
                    #endif
                    
                    // Crucial: preserveCenter = true keeps camera focused on user's GPS position
                    await self.loadCadastralVillage(village: targetVillage, preserveCenter: true)
                    
                    guard !Task.isCancelled, self.activeSelectionToken == selectionToken else { return }
                    
                    #if DEBUG
                    debugLog("[GPS_DEBUG][12] PARCEL_API_RESPONSE Parcels received.")
                    debugLog("[GPS_DEBUG][13] PARCEL_COUNT Total parcels loaded: \(self.cadastralParcels.count)")
                    debugLog("[GPS_DEBUG][14] MAP_RENDER_START Supplying parcel features to MapLibre.")
                    #endif
                    
                    // P0 Fix 2 Confidence Policy Application:
                    if accuracy >= 0 && accuracy <= 15.0 {
                        // Tier A: High Confidence (<= 15m)
                        // Safe to auto-select containing plot if resolver returned a plot number
                        if let plotNum = resolution.plotNumber, !plotNum.isEmpty {
                            if let parcel = self.cadastralRepository.getParcelByPlot(village: targetVillage, plotNumber: plotNum) {
                                self.gpsAutoSelectionContext = GPSAutoSelectionContext(plotNumber: plotNum, accuracy: accuracy)
                                self.onCadastralParcelSelected(parcel)
                                #if DEBUG
                                debugLog("[GPS_DEBUG][15] HIGH_CONFIDENCE (<=15m) Auto-selected containing plot: \(plotNum)")
                                #endif
                                self.showToast("Plot \(plotNum) located", icon: "scope")
                            } else {
                                #if DEBUG
                                debugLog("[GPS_DEBUG][15] HIGH_CONFIDENCE Plot \(plotNum) reported by resolver but not found in village parcels.")
                                #endif
                            }
                        }
                        self.spatialResolutionState = .ready(message: "Plots near you")
                    } else if accuracy > 15.0 && accuracy <= 35.0 {
                        // Tier B: Moderate Confidence (> 15m and <= 35m)
                        // Do NOT auto-select a specific plot. Do NOT open plot card automatically.
                        #if DEBUG
                        debugLog("[GPS_DEBUG][15] MODERATE_CONFIDENCE (>15m, <=35m) Suppressed auto-selection for plot: \(resolution.plotNumber ?? "nil")")
                        #endif
                        self.selectedParcel = nil
                        self.selectedCadastralParcel = nil
                        self.gpsAutoSelectionContext = nil
                        self.spatialResolutionState = .plotsNearYou(accuracy: accuracy)
                    } else if accuracy > 35.0 && accuracy <= 100.0 {
                        // Tier C: Low Confidence (> 35m and <= 100m)
                        // Do NOT auto-select a specific plot.
                        #if DEBUG
                        debugLog("[GPS_DEBUG][15] LOW_CONFIDENCE (>35m, <=100m) Suppressed auto-selection for plot: \(resolution.plotNumber ?? "nil")")
                        #endif
                        self.selectedParcel = nil
                        self.selectedCadastralParcel = nil
                        self.gpsAutoSelectionContext = nil
                        self.spatialResolutionState = .approximateLocation(accuracy: accuracy)
                    }
                    self.lastFailedSearchResult = nil
                    
                case .ambiguous:
                    let candidates = resolution.candidates ?? []
                    #if DEBUG
                    debugLog("[GPS_DEBUG][9] RESOLVE_RESULT Ambiguous resolution with \(candidates.count) candidates.")
                    #endif
                    self.lastFailedSearchResult = nil
                    self.spatialResolutionState = .ambiguous(candidates)
                    self.showToast("Multiple village boundaries found. Please choose.", icon: "person.2.fill")
                    
                case .noCadastralCoverage:
                    let reason = resolution.resolutionReason ?? "No cadastral parcel coverage at this location"
                    #if DEBUG
                    debugLog("[GPS_DEBUG][9] RESOLVE_RESULT No cadastral coverage: \(reason)")
                    #endif
                    self.lastFailedSearchResult = nil
                    self.spatialResolutionState = .noCoverage(reason: reason)
                    Theme.notificationHaptic(.warning)
                    self.showToast("No cadastral map available for this area", icon: "exclamationmark.triangle")
                    
                case .outsideOdisha:
                    #if DEBUG
                    debugLog("[GPS_DEBUG][9] RESOLVE_RESULT Backend reported location outside Odisha.")
                    #endif
                    self.lastFailedSearchResult = nil
                    self.spatialResolutionState = .outsideOdisha
                    Theme.notificationHaptic(.warning)
                    self.showToast("Location is outside Odisha cadastral coverage", icon: "slash.circle")
                    
                case .parcelSourceTemporarilyUnavailable:
                    // 1. If resolution still returned a revenue village ID, load the village directly!
                    if let vId = resolution.revenueVillageId, let vName = resolution.revenueVillage {
                        #if DEBUG
                        debugLog("[GPS_DEBUG][9] Parcel source flagged busy, but village provided (\(vName)). Loading village directly...")
                        #endif
                        let targetVillage = CadastralVillage(
                            id: vId,
                            name: vName,
                            gpID: nil,
                            blockID: resolution.tahasilId ?? "",
                            districtID: resolution.districtId,
                            blockName: resolution.tahasil,
                            districtName: resolution.district
                        )
                        self.spatialResolutionState = .loadingParcels(villageName: vName)
                        self.showToast("Loading land plots for \(vName)...", icon: "map.fill")
                        await self.loadCadastralVillage(village: targetVillage, preserveCenter: true)
                        return
                    }
                    
                    // 2. If candidates are available, prompt disambiguation
                    if let candidates = resolution.candidates, !candidates.isEmpty {
                        self.spatialResolutionState = .ambiguous(candidates)
                        self.showToast("Select your revenue village to view plots", icon: "person.2.fill")
                        return
                    }
                    
                    // 3. Fallback: Reverse-geocode coordinate to find nearest revenue village
                    if let fallbackVillage = await self.attemptReverseGeocodeFallback(latitude: lat, longitude: lon) {
                        self.spatialResolutionState = .loadingParcels(villageName: fallbackVillage.name)
                        self.showToast("Found \(fallbackVillage.name), loading plots...", icon: "map.fill")
                        await self.loadCadastralVillage(village: fallbackVillage, preserveCenter: true)
                        return
                    }
                    
                    // 4. Could not resolve a village to load. Surface an ACTIONABLE recovery card
                    //    (Try Again / Choose Location Manually) instead of silently idling on a
                    //    blank map — the resolver reached the tahasil but the parcel source was
                    //    unreachable, so the user needs a clear path forward, not an empty screen.
                    let reason = resolution.resolutionReason ?? "Official cadastral records could not be loaded for this location right now. Please try again or select your village manually."
                    self.lastFailedSearchResult = nil
                    self.spatialResolutionState = .backendTemporarilyUnavailable(reason: reason)
                    Theme.notificationHaptic(.warning)
                    self.showToast("Couldn't load plots for this location", icon: "server.rack")
                    
                case .unresolved:
                    // Check if reverse geocoding can match a village
                    if let fallbackVillage = await self.attemptReverseGeocodeFallback(latitude: lat, longitude: lon) {
                        self.spatialResolutionState = .loadingParcels(villageName: fallbackVillage.name)
                        self.showToast("Found \(fallbackVillage.name), loading plots...", icon: "map.fill")
                        await self.loadCadastralVillage(village: fallbackVillage, preserveCenter: true)
                        return
                    }
                    
                    if let candidates = resolution.candidates, !candidates.isEmpty {
                        self.spatialResolutionState = .ambiguous(candidates)
                        return
                    }
                    
                    self.spatialResolutionState = .idle
                    self.showToast("Centered on your location", icon: "scope")
                }
            } catch {
                guard !Task.isCancelled, self.activeSelectionToken == selectionToken else { return }
                #if DEBUG
                debugLog("[GPS_DEBUG][8] RESOLVE_API_RESPONSE Resolution failed: \(error.localizedDescription)")
                #endif
                
                // On error, attempt reverse geocoding fallback before failing
                if let fallbackVillage = await self.attemptReverseGeocodeFallback(latitude: lat, longitude: lon) {
                    self.spatialResolutionState = .loadingParcels(villageName: fallbackVillage.name)
                    self.showToast("Found \(fallbackVillage.name), loading plots...", icon: "map.fill")
                    await self.loadCadastralVillage(village: fallbackVillage, preserveCenter: true)
                    return
                }
                
                self.spatialResolutionState = .idle
                self.showToast("Centered on your location", icon: "scope")
            }
        }
    }
    
    // MARK: - Native Reverse Geocode Fallback
    
    @MainActor
    private func attemptReverseGeocodeFallback(latitude: Double, longitude: Double) async -> CadastralVillage? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let pm = placemarks.first else {
            return nil
        }
        
        let searchQueries = [pm.subLocality, pm.locality, pm.name].compactMap { $0 }.filter { !$0.isEmpty }
        for query in searchQueries {
            if let results = try? await LocationSearchService.shared.performSearchNetworkRequest(query: query, limit: 5) {
                if let matched = results.first(where: { $0.revenueVillageId != nil }) {
                    // Prefer the full catalog identity (same as the manual picker).
                    if let direct = matched.directCadastralVillage { return direct }
                    guard let vId = matched.revenueVillageId,
                          let vName = matched.revenueVillage ?? matched.title.components(separatedBy: ",").first else {
                        continue
                    }
                    return CadastralVillage(
                        id: vId,
                        name: vName,
                        gpID: nil,
                        blockID: matched.tahasilId ?? "",
                        districtID: matched.districtId,
                        blockName: matched.tahasil,
                        districtName: matched.district
                    )
                }
            }
        }
        return nil
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
            moveCamera(to: mapCenter, zoom: zoomLevel + 1.0)
        }
    }
    
    @MainActor
    public func zoomOut() {
        if zoomLevel > 5.0 {
            moveCamera(to: mapCenter, zoom: zoomLevel - 1.0)
        }
    }
    
    @MainActor
    private func updateSuggestions() {
        guard !searchQuery.isEmpty else {
            if !searchResults.isEmpty { searchResults = [] }
            LocationSearchService.shared.clearSearch()
            return
        }
        LocationSearchService.shared.search(query: searchQuery)
    }
    
    @MainActor
    public func searchLocation() {
        if let first = searchResults.first ?? LocationSearchService.shared.searchResults.first {
            _Concurrency.Task {
                try? await selectLocation(first)
            }
        }
    }
    
    @MainActor
    public func selectLocation(_ result: LocationSearchResult, isRecent: Bool = false) async throws {
        self.currentFlow = isRecent ? "RECENT" : "LIVE"
        debugLog("[\(currentFlow)-1] selectLocation \(result.title) (type=\(result.type), lat=\(result.latitude ?? 0), lon=\(result.longitude ?? 0))")
        
        // Clear search UI (write only when needed: each write re-renders the map)
        if isSearchFocused { self.isSearchFocused = false }
        if !searchQuery.isEmpty { self.searchQuery = "" }
        if !searchResults.isEmpty { self.searchResults = [] }
        LocationSearchService.shared.clearSearch()
        
        // P0 Fix 3: Invalidate any active GPS task and dismiss previous plot card
        self.activeGPSTask?.cancel()
        self.activeGPSTask = nil
        self.isResolvingGPSLocation = false
        self.gpsAutoSelectionContext = nil
        self.selectedParcel = nil
        self.selectedCadastralParcel = nil
        
        let centerBefore = self.mapCenter
        let zoomBefore = self.zoomLevel
        
        debugLog("DEBUG: 🎯 [selectLocation] BEGIN for '\(result.title)'")
        debugLog("DEBUG: 🎯 [selectLocation] - result title: \(result.title)")
        debugLog("DEBUG: 🎯 [selectLocation] - result type: \(result.type)")
        debugLog("DEBUG: 🎯 [selectLocation] - latitude: \(result.latitude ?? 0)")
        debugLog("DEBUG: 🎯 [selectLocation] - longitude: \(result.longitude ?? 0)")
        debugLog("DEBUG: 🎯 [selectLocation] - recommendedZoomLevel: \(result.type.recommendedZoomLevel)")
        debugLog("DEBUG: 🎯 [selectLocation] - current mapCenter BEFORE selection: (\(centerBefore.latitude), \(centerBefore.longitude)), zoom: \(zoomBefore)")
        
        // 1. PLOT_ONLY check: does not fly camera, requires village context
        if result.type == .plotOnly {
            let targetPlot = result.parsedPlotNumber ?? result.title.replacingOccurrences(of: "Plot:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let activeV = activeCadastralVillage {
                if let parcel = cadastralRepository.getParcelByPlot(village: activeV, plotNumber: targetPlot) {
                    onCadastralParcelSelected(parcel)
                    let c = parcel.centroidCoordinate
                    moveCamera(to: Coordinate(latitude: c.latitude, longitude: c.longitude), zoom: 18.0)
                    showToast("Centered on Plot \(targetPlot)", icon: "scope")
                } else {
                    showToast("Plot \(targetPlot) not found in \(activeV.cleanName)", icon: "exclamationmark.triangle")
                }
            } else {
                showToast("Select a village or location first to find Plot \(targetPlot)", icon: "number.square.fill")
            }
            return
        }
        
        // 1b. Catalog village with a full identity: open it directly, exactly like the
        // District → Tahasil → Village picker does. No coordinate re-resolution (the
        // result's lat/lon is only an approximate tahasil centre for most villages).
        if let village = result.directCadastralVillage {
            await openVillageDirectly(village, from: result)
            return
        }
        
        // 2. Coordinate presence: move camera immediately!
        guard let lat = result.latitude, let lon = result.longitude else {
            showToast("No coordinates available for \(result.title)", icon: "exclamationmark.triangle")
            return
        }
        
        Theme.haptic(.medium)
        RecentLocationSearchStore.shared.addRecent(result)
        self.lastFailedSearchResult = result
        
        // Move MapLibre camera immediately!
        moveCamera(to: Coordinate(latitude: lat, longitude: lon), zoom: result.type.recommendedZoomLevel)
        debugLog("DEBUG: 🎯 [selectLocation] - mapCenter IMMEDIATELY AFTER selection: (\(self.mapCenter.latitude), \(self.mapCenter.longitude))")
        debugLog("DEBUG: 🎯 [selectLocation] - zoomLevel IMMEDIATELY AFTER selection: \(self.zoomLevel)")
        
        // 3. Broad administrative regions (City/District): navigate map directly without invoking village parcel lookup
        if result.type.isBroadAdministrative {
            self.spatialResolutionState = .idle
            showToast("Centered on \(result.title)", icon: "scope")
            return
        }
        
        // Show lightweight non-blocking status
        self.spatialResolutionState = .resolving(title: result.title)
        showToast("Finding this area...", icon: "scope")
        
        // Cancel any pending parcel loading task immediately
        activeParcelLoadTask?.cancel()
        
        // Generate new selection token to prevent stale overwrites
        let selectionToken = UUID()
        self.activeSelectionToken = selectionToken
        self.parcelRenderingConfirmed = false
        
        // Candidate village IDs if known (e.g. from local village suggestion)
        let candidates: [String]? = {
            if let vId = result.revenueVillageId, !vId.isEmpty {
                return [vId]
            }
            return nil
        }()
        
        // Call backend spatial resolver
        debugLog("DEBUG: 🎯 [selectLocation] - spatial resolver request coordinate: (\(lat), \(lon))")
        do {
            let resolution = try await LocationSearchService.shared.resolveCoordinate(
                latitude: lat,
                longitude: lon,
                candidateVillageIds: candidates
            )
            debugLog("DEBUG: 🎯 [selectLocation] - spatial resolver response: status=\(resolution.status.rawValue), reason=\(resolution.resolutionReason ?? "none")")
            debugLog("DEBUG: 🎯 [selectLocation] - resolved district: \(resolution.district ?? "none") (id=\(resolution.districtId ?? "none"))")
            debugLog("DEBUG: 🎯 [selectLocation] - resolved tahasil: \(resolution.tahasil ?? "none") (id=\(resolution.tahasilId ?? "none"))")
            debugLog("DEBUG: 🎯 [selectLocation] - resolved village: \(resolution.revenueVillage ?? "none") (id=\(resolution.revenueVillageId ?? "none"))")
            
            // Check if user has made another selection in the meantime
            guard self.activeSelectionToken == selectionToken else {
                debugLog("DEBUG: 🛑 Stale resolution for \(result.title) ignored (token mismatch).")
                return
            }
            
            switch resolution.status {
            case .exact:
                guard let vId = resolution.revenueVillageId, let vName = resolution.revenueVillage else {
                    self.spatialResolutionState = .unresolved(reason: "Missing village identity")
                    showToast("Could not determine official village", icon: "questionmark.circle")
                    return
                }
                
                // Immediately align map camera with authoritative resolved coordinates!
                if let rLat = resolution.latitude, let rLon = resolution.longitude {
                    moveCamera(to: Coordinate(latitude: rLat, longitude: rLon), zoom: max(self.zoomLevel, 16.5))
                }
                
                let targetVillage = CadastralVillage(
                    id: vId,
                    name: vName,
                    gpID: nil,
                    blockID: resolution.tahasilId ?? "",
                    districtID: resolution.districtId,
                    blockName: resolution.tahasil,
                    districtName: resolution.district
                )
                
                let updatedResult = LocationSearchResult(
                    id: result.id,
                    title: result.title,
                    subtitle: result.subtitle,
                    type: result.type,
                    latitude: resolution.latitude ?? result.latitude,
                    longitude: resolution.longitude ?? result.longitude,
                    boundingBox: result.boundingBox,
                    source: result.source,
                    parsedPlotNumber: result.parsedPlotNumber,
                    district: resolution.district ?? result.district,
                    districtId: resolution.districtId ?? result.districtId,
                    tahasil: resolution.tahasil ?? result.tahasil,
                    tahasilId: resolution.tahasilId ?? result.tahasilId,
                    revenueVillage: resolution.revenueVillage ?? result.revenueVillage,
                    revenueVillageId: resolution.revenueVillageId ?? result.revenueVillageId
                )
                RecentLocationSearchStore.shared.addRecent(updatedResult)
                self.lastFailedSearchResult = updatedResult
                
                self.spatialResolutionState = .loadingParcels(villageName: vName)
                showToast("Loading land parcels...", icon: "map.fill")
                
                let preserveSearchCenter = (result.type == .compoundPlot || result.type == .coordinate || result.type == .plotOnly)
                debugLog("DEBUG: 🎯 [selectLocation] - cadastral request parameters: village=\(targetVillage.name) (id=\(targetVillage.id)), preserveCenter=\(preserveSearchCenter)")
                await loadCadastralVillage(village: targetVillage, preserveCenter: preserveSearchCenter)
                
                // Guard token again after loading parcels
                guard self.activeSelectionToken == selectionToken else { return }
                
                debugLog("DEBUG: 🎯 [selectLocation] - cadastral response parcel count: \(self.cadastralParcels.count)")
                debugLog("DEBUG: 🎯 [selectLocation] - first few parcel identities: \(self.debugFirstPlots)")
                debugLog("DEBUG: 🎯 [selectLocation] - final mapCenter after cadastral loading: (\(self.mapCenter.latitude), \(self.mapCenter.longitude))")
                debugLog("DEBUG: 🎯 [selectLocation] - final zoomLevel after cadastral loading: \(self.zoomLevel)")
                
                // Check if cadastral parcels actually loaded
                if self.cadastralParcels.isEmpty || self.debugPipelineStage == "PARCEL_FETCH_FAILED" {
                    // Cadastral server failure: map camera REMAINS at selected location!
                    // loadCadastralVillage already set a specific, user-readable state
                    // (offline / couldn't load plots / no map here); keep it instead of
                    // overwriting it with the raw technical error text.
                    self.lastFailedSearchResult = updatedResult
                    switch self.spatialResolutionState {
                    case .noInternet, .parcelLoadFailed, .noCoverage:
                        break
                    default:
                        self.spatialResolutionState = .parcelLoadFailed(villageName: vName, reason: self.debugErrorMessage ?? "")
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    return
                }
                
                // If it was a compound plot search (e.g. "Plot 547 Patia"), look up and select the plot!
                let plotToSelect: String? = {
                    if let p = result.parsedPlotNumber, !p.isEmpty { return p }
                    if let p = resolution.plotNumber, !p.isEmpty && result.type == .compoundPlot { return p }
                    return nil
                }()
                
                if let targetPlot = plotToSelect {
                    if let parcel = cadastralRepository.getParcelByPlot(village: targetVillage, plotNumber: targetPlot) {
                        onCadastralParcelSelected(parcel)
                        let c = parcel.centroidCoordinate
                        moveCamera(to: Coordinate(latitude: c.latitude, longitude: c.longitude), zoom: 18.0)
                        showToast("Centered on Plot \(targetPlot)", icon: "scope")
                    } else {
                        showToast("Plot \(targetPlot) not found in \(targetVillage.cleanName)", icon: "exclamationmark.triangle")
                    }
                }
                
                self.lastFailedSearchResult = nil
            case .ambiguous:
                self.lastFailedSearchResult = nil
                self.spatialResolutionState = .ambiguous(resolution.candidates ?? [])
                showToast("Multiple village boundaries found. Please choose.", icon: "person.2.fill")
                
            case .noCadastralCoverage:
                self.lastFailedSearchResult = nil
                let reason = resolution.resolutionReason ?? "No cadastral parcel coverage at this location"
                self.spatialResolutionState = .noCoverage(reason: reason)
                Theme.notificationHaptic(.warning)
                showToast("No cadastral map available for this area", icon: "exclamationmark.triangle")
                
            case .outsideOdisha:
                self.lastFailedSearchResult = nil
                self.spatialResolutionState = .outsideOdisha
                Theme.notificationHaptic(.warning)
                showToast("Location is outside Odisha cadastral coverage", icon: "slash.circle")
                
            case .parcelSourceTemporarilyUnavailable:
                self.lastFailedSearchResult = result
                let reason = resolution.resolutionReason ?? "Land parcel data temporarily unavailable"
                self.spatialResolutionState = .temporarilyUnavailable(reason: reason)
                Theme.notificationHaptic(.warning)
                showToast("Land parcel data temporarily unavailable", icon: "wifi.slash")
                
            case .unresolved:
                self.lastFailedSearchResult = result
                let reason = resolution.resolutionReason ?? "Could not resolve official revenue land area"
                self.spatialResolutionState = .unresolved(reason: reason)
                Theme.notificationHaptic(.warning)
                showToast("Could not determine official land area", icon: "questionmark.circle")
            }
        } catch {
            guard self.activeSelectionToken == selectionToken else { return }
            self.lastFailedSearchResult = result
            self.spatialResolutionState = .temporarilyUnavailable(reason: error.localizedDescription)
            Theme.notificationHaptic(.warning)
            showToast("Resolution failed: \(error.localizedDescription)", icon: "wifi.slash")
        }
    }
    
    /// Opens a searched village straight away using its catalog identity, then
    /// selects the plot when the search named one ("Plot 547 Patia").
    /// Failure states (no map coverage, network, server) come from
    /// `loadCadastralVillage`; `lastFailedSearchResult` makes Retry re-open it.
    @MainActor
    private func openVillageDirectly(_ village: CadastralVillage, from result: LocationSearchResult) async {
        Theme.haptic(.medium)
        RecentLocationSearchStore.shared.addRecent(result)
        self.lastFailedSearchResult = result
        
        activeParcelLoadTask?.cancel()
        let selectionToken = UUID()
        self.activeSelectionToken = selectionToken
        self.parcelRenderingConfirmed = false
        
        // Gentle fly-over toward the area while the real village extent loads.
        if let lat = result.latitude, let lon = result.longitude {
            moveCamera(to: Coordinate(latitude: lat, longitude: lon), zoom: min(self.zoomLevel, 12.5))
        }
        
        self.spatialResolutionState = .loadingParcels(villageName: village.cleanName)
        debugLog("[\(currentFlow)-DIRECT] opening village \(village.name) id=\(village.id) block=\(village.blockID) district=\(village.districtName ?? "-")")
        
        await loadCadastralVillage(village: village)
        guard self.activeSelectionToken == selectionToken else { return }
        
        // Loading failed or the village has no map: keep the state set by the loader.
        guard !self.cadastralParcels.isEmpty, self.debugPipelineStage != "PARCEL_FETCH_FAILED" else { return }
        
        if let plot = result.parsedPlotNumber, !plot.isEmpty {
            if let parcel = cadastralRepository.getParcelByPlot(village: village, plotNumber: plot) {
                onCadastralParcelSelected(parcel)
                let c = parcel.centroidCoordinate
                moveCamera(to: Coordinate(latitude: c.latitude, longitude: c.longitude), zoom: 18.0)
                showToast("Centered on Plot \(plot)", icon: "scope")
            } else {
                showToast("Plot \(plot) not found in \(village.cleanName)", icon: "exclamationmark.triangle")
            }
        }
        self.lastFailedSearchResult = nil
    }
    
    @MainActor
    public func selectResolutionCandidate(_ candidate: LocationResolutionCandidate) async {
        Theme.haptic(.medium)
        activeParcelLoadTask?.cancel()
        let selectionToken = UUID()
        self.activeSelectionToken = selectionToken
        
        let targetVillage = CadastralVillage(
            id: candidate.villageId,
            name: candidate.villageName,
            gpID: nil,
            blockID: "",
            districtID: nil,
            blockName: candidate.tahasilName,
            districtName: candidate.districtName
        )
        
        self.spatialResolutionState = .loadingParcels(villageName: candidate.villageName)
        showToast("Loading land parcels...", icon: "map.fill")
        
        await loadCadastralVillage(village: targetVillage)
        
        guard self.activeSelectionToken == selectionToken else { return }
        self.lastFailedSearchResult = nil
    }
    
    @MainActor
    public func onParcelLayerRenderSuccess(villageId: String, token: UUID? = nil) {
        if let t = token {
            guard self.activeSelectionToken == t else {
                debugLog("DEBUG: 🛑 [CADASTRAL] onParcelLayerRenderSuccess: Ignoring stale token \(t) (current: \(self.activeSelectionToken))")
                return
            }
        }
        guard !parcelRenderingConfirmed else { return }
        self.parcelRenderingConfirmed = true
        self.spatialResolutionState = .ready(message: "Parcels ready")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        let capturedToken = self.activeSelectionToken
        _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(nanoseconds: 1_800_000_000)
            if self.spatialResolutionState == .ready(message: "Parcels ready") && self.activeSelectionToken == capturedToken {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.spatialResolutionState = .idle
                }
            }
        }
    }
    
    @MainActor
    public func onParcelLayerRenderFailure(villageId: String, token: UUID? = nil, reason: String) {
        if let t = token {
            guard self.activeSelectionToken == t else { return }
        }
        self.parcelRenderingConfirmed = false
        self.spatialResolutionState = .temporarilyUnavailable(reason: "Parcel display unavailable: \(reason)")
        Theme.notificationHaptic(.warning)
        showToast("Could not render parcels: \(reason)", icon: "exclamationmark.triangle")
    }
    
    @MainActor
    public func retryLastResolution() async {
        if let last = lastFailedSearchResult {
            try? await selectLocation(last)
        } else {
            locateAndShowNearbyPlots()
        }
    }
    
    @MainActor
    public func openManualLocationSelector() {
        self.spatialResolutionState = .idle
        self.shouldOpenLocationPicker = true
    }
    
    @MainActor
    public func dismissSpatialResolutionState() {
        withAnimation(.easeOut(duration: 0.25)) {
            self.spatialResolutionState = .idle
        }
    }
    
    @MainActor
    public func dismissSearchOnMapInteraction() {
        // @Published emits even when the value is unchanged; this ran on every
        // map pan, re-rendering the screen. Only write when something changes.
        if isSearchFocused { self.isSearchFocused = false }
        if !searchResults.isEmpty || !searchQuery.isEmpty {
            self.searchResults = []
            self.searchQuery = ""
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
