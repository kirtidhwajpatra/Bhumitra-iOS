import SwiftUI
import Combine
import CoreLocation
import MapLibre

// ============================================================
// MARK: - GIS EXPLORER VIEW MODEL
// ============================================================

@MainActor
public final class GISExplorerViewModel: ObservableObject {
    public static let shared = GISExplorerViewModel()
    
    // MARK: - Published State
    @Published public var isExplorerActive: Bool = false {
        didSet { updateHasBottomCard() }
    }
    @Published public var currentLevel: GISNavigationLevel = .odisha {
        didSet { updateHasBottomCard() }
    }
    @Published public var breadcrumbs: [GISBreadcrumbItem] = []
    @Published public var navigationState: GISNavigationState = .idle
    
    @Published public var districts: [GISDistrictFeature] = []
    @Published public var tahasils: [GISTahasilFeature] = [] {
        didSet { updateHasBottomCard() }
    }
    @Published public var subdivisions: [CadastralBlock] = []
    @Published public var villages: [CadastralVillage] = []
    
    @Published public var selectedDistrictID: String? = nil
    @Published public var selectedDistrictFeature: GISDistrictFeature? = nil
    @Published public var selectedTahasilID: String? = nil
    @Published public var selectedSubdivision: CadastralBlock? = nil
    @Published public var selectedVillage: CadastralVillage? = nil
    
    @Published public var districtsShape: MLNShape? = nil
    @Published public var tahasilsShape: MLNShape? = nil
    /// True if the backend returned renderable Tahasil polygons for the selected district.
    /// False when geometry is genuinely absent (4 districts) — UI must not show "tap the map" in this case.
    @Published public var tahasilGeometryAvailable: Bool = true {
        didSet { updateHasBottomCard() }
    }
    @Published public var hasBottomCard: Bool = false
    @Published public var targetCameraCenter: CLLocationCoordinate2D? = nil
    @Published public var targetCameraZoom: Double? = nil
    @Published public var targetCameraBounds: GISCoordinateBounds? = nil
    
    // State-wide center for Odisha
    public static let odishaCenter = CLLocationCoordinate2D(latitude: 20.5000, longitude: 84.4000)
    public static let odishaZoom: Double = 6.8
    
    private let repository: GISExplorerRepository
    private weak var mapViewModel: MapViewModel?
    
    nonisolated deinit {}
    
    public init(
        repository: GISExplorerRepository? = nil,
        mapViewModel: MapViewModel? = nil
    ) {
        self.repository = repository ?? .shared
        self.mapViewModel = mapViewModel
        buildBreadcrumbs()
    }
    
    public func setMapViewModel(_ vm: MapViewModel) {
        self.mapViewModel = vm
    }
    
    // MARK: - Exploration Lifecycle
    
    public func toggleExplorer() {
        if isExplorerActive {
            exitExplorer()
        } else {
            enterExplorer()
        }
    }
    
    public func enterExplorer() {
        guard AppConfig.gisNavigationEnabled else { return }
        isExplorerActive = true
        resetToOdisha()
    }
    
    public func exitExplorer() {
        isExplorerActive = false
        navigationState = .idle
        selectedDistrictID = nil
        selectedDistrictFeature = nil
        selectedTahasilID = nil
        selectedSubdivision = nil
        selectedVillage = nil
        tahasils = []
        tahasilsShape = nil
        tahasilGeometryAvailable = true
        subdivisions = []
        villages = []
        mapViewModel?.clearCadastralVillage()
    }
    
    public func resetToOdisha(forceRefresh: Bool = false) {
        currentLevel = .odisha
        selectedDistrictID = nil
        selectedDistrictFeature = nil
        selectedTahasilID = nil
        selectedSubdivision = nil
        selectedVillage = nil
        tahasils = []
        tahasilsShape = nil
        tahasilGeometryAvailable = true
        subdivisions = []
        villages = []
        mapViewModel?.clearCadastralVillage()
        
        targetCameraBounds = nil
        targetCameraCenter = Self.odishaCenter
        targetCameraZoom = Self.odishaZoom
        
        buildBreadcrumbs()
        loadDistricts(forceRefresh: forceRefresh)
    }
    
    // MARK: - Breadcrumb Management
    
    private func buildBreadcrumbs() {
        var items: [GISBreadcrumbItem] = [
            GISBreadcrumbItem(
                title: "Odisha",
                level: .odisha,
                isCurrent: currentLevel == .odisha
            )
        ]
        
        if let d = selectedDistrictFeature {
            let isCurrent = {
                if case .district = currentLevel { return true }
                return false
            }()
            items.append(
                GISBreadcrumbItem(
                    title: d.name,
                    level: .district(CadastralDistrict(id: d.id, name: d.name), bbox: d.bbox),
                    isCurrent: isCurrent
                )
            )
        }
        
        if let b = selectedSubdivision {
            let isCurrent = {
                if case .subdivision = currentLevel { return true }
                return false
            }()
            items.append(
                GISBreadcrumbItem(
                    title: b.name,
                    level: .subdivision(b),
                    isCurrent: isCurrent
                )
            )
        }
        
        if let v = selectedVillage {
            items.append(
                GISBreadcrumbItem(
                    title: v.name,
                    level: .village(v),
                    isCurrent: true
                )
            )
        }
        
        self.breadcrumbs = items
    }
    
    // MARK: - Level 1: Districts
    
    public func loadDistricts(forceRefresh: Bool = false) {
        navigationState = .loading("Loading Odisha districts…")
        _Concurrency.Task {
            do {
                // 1. Fetch District Metadata
                let list = try await repository.getDistricts(forceRefresh: forceRefresh)
                
                // 2. Fetch District Boundaries GeoJSON for MapLibre
                let rawGeoJSON = try await repository.getDistrictsGeoJSON(forceRefresh: forceRefresh)
                let shape = Self.enrichDistrictsGeoJSON(rawGeoJSON)
                
                await MainActor.run {
                    self.districts = list
                    self.districtsShape = shape
                    self.navigationState = .loaded
                    #if DEBUG
                    if let districtIdx = CommandLine.arguments.firstIndex(of: "-selectDistrict"),
                       districtIdx + 1 < CommandLine.arguments.count {
                        let targetDistrict = CommandLine.arguments[districtIdx + 1]
                        self.selectDistrictByID(targetDistrict)
                    }
                    #endif
                }
            } catch {
                await MainActor.run {
                    self.navigationState = .error("Unable to load Odisha districts: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func updateHasBottomCard() {
        guard isExplorerActive else {
            if hasBottomCard != false { hasBottomCard = false }
            return
        }
        let newValue: Bool
        switch currentLevel {
        case .odisha:
            newValue = false
        case .district:
            newValue = (!tahasilGeometryAvailable || tahasils.isEmpty)
        case .subdivision:
            newValue = true
        case .village:
            newValue = false
        }
        if hasBottomCard != newValue {
            hasBottomCard = newValue
        }
    }
    
    // MARK: - Level 2: District Selection -> Tahasils / Subdivisions
    
    public func selectDistrict(feature: GISDistrictFeature) {
        self.selectedDistrictID = feature.id
        self.selectedDistrictFeature = feature
        self.selectedTahasilID = nil
        self.selectedSubdivision = nil
        self.selectedVillage = nil
        self.currentLevel = .district(CadastralDistrict(id: feature.id, name: feature.name), bbox: feature.bbox)
        
        // Reset previous district's tahasils and subdivisions
        self.tahasils = []
        self.tahasilsShape = nil
        self.subdivisions = []
        let hasKnownGeom = (feature.name.caseInsensitiveCompare("Cuttack") == .orderedSame || feature.name.caseInsensitiveCompare("Keonjhar") == .orderedSame || feature.name.caseInsensitiveCompare("Kendujhar") == .orderedSame)
        self.tahasilGeometryAvailable = hasKnownGeom
        
        // Smooth camera fly-to district bbox
        if feature.bbox.count >= 4 {
            let sw = CLLocationCoordinate2D(latitude: feature.bbox[1], longitude: feature.bbox[0])
            let ne = CLLocationCoordinate2D(latitude: feature.bbox[3], longitude: feature.bbox[2])
            self.targetCameraBounds = GISCoordinateBounds(sw: sw, ne: ne)
        } else {
            self.targetCameraCenter = feature.centerCoordinate
            self.targetCameraZoom = 9.8
        }
        
        buildBreadcrumbs()
        mapViewModel?.clearCadastralVillage()
        loadTahasilsGeoJSON(for: feature.id)
        loadSubdivisions(for: feature.id, districtName: feature.name)
    }
    
    public func selectDistrictByID(_ idOrCode: String) {
        if let found = districts.first(where: { $0.id == idOrCode || $0.code2Digit == idOrCode || $0.name.caseInsensitiveCompare(idOrCode) == .orderedSame }) {
            selectDistrict(feature: found)
        }
    }
    
    public func loadTahasilsGeoJSON(for districtID: String) {
        _Concurrency.Task {
            do {
                let rawGeoJSON = try await repository.getTahasilsGeoJSON(districtID: districtID)
                let shape = Self.enrichTahasilsGeoJSON(rawGeoJSON)
                
                var tahasilList: [GISTahasilFeature] = []
                var geometryAvailable = true
                if let decoded = try? JSONDecoder().decode(GeoJSONTahasilCollection.self, from: rawGeoJSON) {
                    tahasilList = decoded.features.map(\.properties)
                    // Honour the backend's explicit geometry_available flag.
                    // If the backend says false (or features are empty), the UI must not
                    // show a "tap the map" hint that has nothing to tap.
                    geometryAvailable = decoded.geometryAvailable && !tahasilList.isEmpty
                } else {
                    geometryAvailable = false
                }
                
                await MainActor.run {
                    self.tahasils = tahasilList
                    self.tahasilsShape = shape
                    self.tahasilGeometryAvailable = geometryAvailable
                }
            } catch {
                debugLog("[GISExplorerViewModel] ⚠️ Tahasils GeoJSON not available for district \(districtID): \(error)")
                await MainActor.run {
                    self.tahasils = []
                    self.tahasilsShape = nil
                    self.tahasilGeometryAvailable = false
                }
            }
        }
    }
    
    private func loadSubdivisions(for districtID: String, districtName: String) {
        navigationState = .loading("Finding subdivisions in \(districtName)…")
        _Concurrency.Task {
            do {
                let blocks = try await repository.getSubdivisions(districtID: districtID)
                await MainActor.run {
                    self.subdivisions = blocks
                    self.navigationState = blocks.isEmpty ? .error("No subdivisions found for \(districtName)") : .loaded
                    #if DEBUG
                    if let tahasilIdx = CommandLine.arguments.firstIndex(of: "-selectTahasil"),
                       tahasilIdx + 1 < CommandLine.arguments.count {
                        let targetTahasil = CommandLine.arguments[tahasilIdx + 1]
                        if let b = blocks.first(where: { $0.id == targetTahasil || $0.name.caseInsensitiveCompare(targetTahasil) == .orderedSame }) {
                            self.selectSubdivision(b)
                        } else {
                            self.selectTahasilByID(targetTahasil)
                        }
                    }
                    #endif
                }
            } catch {
                await MainActor.run {
                    self.navigationState = .error("Failed to load subdivisions: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Level 3: Tahasil / Subdivision Selection -> Villages
    
    public func selectTahasilByID(_ idOrName: String, name: String? = nil, bbox: [Double]? = nil) {
        let cleanID = idOrName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let block: CadastralBlock
        if let match = subdivisions.first(where: {
            $0.id == cleanID || $0.name.caseInsensitiveCompare(cleanID) == .orderedSame
        }) {
            block = match
        } else if let tahasilFeature = tahasils.first(where: {
            $0.id == cleanID || $0.name.caseInsensitiveCompare(cleanID) == .orderedSame
        }) {
            block = CadastralBlock(id: tahasilFeature.id, name: tahasilFeature.name, districtID: selectedDistrictID ?? "")
        } else {
            let tahasilName = name ?? cleanID
            block = CadastralBlock(id: cleanID, name: tahasilName, districtID: selectedDistrictID ?? "")
        }
        
        self.selectedTahasilID = block.id
        self.selectedSubdivision = block
        self.selectedVillage = nil
        self.currentLevel = .subdivision(block)
        
        let effectiveBbox = bbox ?? tahasils.first(where: { $0.id == block.id })?.bbox
        if let box = effectiveBbox, box.count >= 4 {
            let sw = CLLocationCoordinate2D(latitude: box[1], longitude: box[0])
            let ne = CLLocationCoordinate2D(latitude: box[3], longitude: box[2])
            self.targetCameraBounds = GISCoordinateBounds(sw: sw, ne: ne)
        }
        
        buildBreadcrumbs()
        mapViewModel?.clearCadastralVillage()
        loadVillages(for: block.id, blockName: block.name)
    }
    
    public func selectSubdivision(_ block: CadastralBlock) {
        selectTahasilByID(block.id, name: block.name, bbox: nil)
    }
    
    private func loadVillages(for subdivisionID: String, blockName: String) {
        navigationState = .loading("Loading villages in \(blockName)…")
        _Concurrency.Task {
            do {
                let vills = try await repository.getVillages(subdivisionID: subdivisionID)
                await MainActor.run {
                    self.villages = vills
                    self.navigationState = vills.isEmpty ? .error("No villages found in \(blockName)") : .loaded
                    #if DEBUG
                    if let villageIdx = CommandLine.arguments.firstIndex(of: "-selectVillage"),
                       villageIdx + 1 < CommandLine.arguments.count {
                        let targetVillage = CommandLine.arguments[villageIdx + 1]
                        if let v = vills.first(where: { $0.name.caseInsensitiveCompare(targetVillage) == .orderedSame || $0.id == targetVillage || $0.name.localizedCaseInsensitiveContains(targetVillage) }) {
                            self.selectVillage(v)
                        }
                    }
                    #endif
                }
            } catch {
                await MainActor.run {
                    self.navigationState = .error("Failed to load villages: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Level 4: Village Selection -> Parcels (Handoff to MapViewModel)
    
    public func selectVillage(_ village: CadastralVillage) {
        self.selectedVillage = village
        self.currentLevel = .village(village)
        buildBreadcrumbs()
        
        let distName = selectedDistrictFeature?.name ?? village.districtName ?? "Odisha"
        let distID = selectedDistrictFeature?.id ?? village.districtID ?? ""
        let blockName = selectedSubdivision?.name ?? village.blockName ?? ""
        let blockID = selectedSubdivision?.id ?? village.blockID
        
        let enriched = CadastralVillage(
            id: village.id,
            name: village.name,
            gpID: village.gpID,
            blockID: blockID,
            districtID: distID,
            blockName: blockName,
            districtName: distName
        )
        
        navigationState = .loading("Loading land parcels for \(village.name)…")
        
        // Fetch village extent for smooth camera framing and hand off to MapViewModel
        if let mapVM = self.mapViewModel {
            _Concurrency.Task { @MainActor in
                do {
                    let extent = try await self.repository.getVillageExtent(village: enriched)
                    let sw = CLLocationCoordinate2D(latitude: extent.minLat, longitude: extent.minLng)
                    let ne = CLLocationCoordinate2D(latitude: extent.maxLat, longitude: extent.maxLng)
                    self.targetCameraBounds = GISCoordinateBounds(sw: sw, ne: ne)
                } catch {
                    debugLog("[GISExplorerViewModel] ⚠️ Extent fetch failed for \(village.name): \(error)")
                }
                await mapVM.loadCadastralVillage(village: enriched, state: "ODISHA")
                self.navigationState = .loaded
                
                #if DEBUG
                if let parcelIdx = CommandLine.arguments.firstIndex(of: "-selectParcel"),
                   parcelIdx + 1 < CommandLine.arguments.count {
                    let targetPlot = CommandLine.arguments[parcelIdx + 1]
                    if let p = mapVM.cadastralParcels.first(where: { $0.plotNumber == targetPlot || $0.id == targetPlot }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            mapVM.onCadastralParcelSelected(p)
                        }
                    }
                }
                #endif
            }
        }
    }
    
    // MARK: - Breadcrumb Navigation
    
    public func navigateToBreadcrumb(_ item: GISBreadcrumbItem) {
        switch item.level {
        case .odisha:
            resetToOdisha()
        case .district(let d, let bbox):
            mapViewModel?.clearCadastralVillage()
            self.selectedTahasilID = nil
            self.selectedSubdivision = nil
            self.selectedVillage = nil
            self.currentLevel = .district(d, bbox: bbox)
            if let box = bbox, box.count >= 4 {
                let sw = CLLocationCoordinate2D(latitude: box[1], longitude: box[0])
                let ne = CLLocationCoordinate2D(latitude: box[3], longitude: box[2])
                self.targetCameraBounds = GISCoordinateBounds(sw: sw, ne: ne)
            }
            buildBreadcrumbs()
            loadTahasilsGeoJSON(for: d.id)
            if let feat = selectedDistrictFeature {
                loadSubdivisions(for: feat.id, districtName: feat.name)
            } else {
                loadSubdivisions(for: d.id, districtName: d.name)
            }
        case .subdivision(let b):
            mapViewModel?.clearCadastralVillage()
            self.selectedVillage = nil
            self.selectedTahasilID = b.id
            self.selectedSubdivision = b
            self.currentLevel = .subdivision(b)
            let effectiveBbox = tahasils.first(where: { $0.id == b.id })?.bbox
            if let box = effectiveBbox, box.count >= 4 {
                let sw = CLLocationCoordinate2D(latitude: box[1], longitude: box[0])
                let ne = CLLocationCoordinate2D(latitude: box[3], longitude: box[2])
                self.targetCameraBounds = GISCoordinateBounds(sw: sw, ne: ne)
            }
            buildBreadcrumbs()
            loadVillages(for: b.id, blockName: b.name)
        case .village(let v):
            selectVillage(v)
        }
    }
    
    /// Navigates one level up the hierarchy tree (e.g. Village -> Tahasil -> District -> Odisha)
    public func stepBack() {
        guard breadcrumbs.count >= 2 else {
            resetToOdisha()
            return
        }
        let previous = breadcrumbs[breadcrumbs.count - 2]
        navigateToBreadcrumb(previous)
    }
    
    // MARK: - GeoJSON Enrichment with Deterministic Semantic Palettes
    
    public static func enrichDistrictsGeoJSON(_ data: Data) -> MLNShape? {
        if var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var features = json["features"] as? [[String: Any]] {
            for i in 0..<features.count {
                var feat = features[i]
                var props = (feat["properties"] as? [String: Any]) ?? [:]
                let dID = (props["district_id"] as? String) ?? (props["id"] as? String) ?? "\(i)"
                props["fill_color"] = GISVisualTheme.deterministicColorHex(for: dID, palette: GISVisualTheme.districtPaletteHex)
                feat["properties"] = props
                features[i] = feat
            }
            json["features"] = features
            if let enrichedData = try? JSONSerialization.data(withJSONObject: json) {
                return try? MLNShape(data: enrichedData, encoding: String.Encoding.utf8.rawValue)
            }
        }
        return try? MLNShape(data: data, encoding: String.Encoding.utf8.rawValue)
    }

    public static func enrichTahasilsGeoJSON(_ data: Data) -> MLNShape? {
        if var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var features = json["features"] as? [[String: Any]] {
            for i in 0..<features.count {
                var feat = features[i]
                var props = (feat["properties"] as? [String: Any]) ?? [:]
                let tID = (props["tahasil_id"] as? String) ?? (props["id"] as? String) ?? "\(i)"
                props["fill_color"] = GISVisualTheme.deterministicColorHex(for: tID, palette: GISVisualTheme.tahasilPaletteHex)
                feat["properties"] = props
                features[i] = feat
            }
            json["features"] = features
            if let enrichedData = try? JSONSerialization.data(withJSONObject: json) {
                return try? MLNShape(data: enrichedData, encoding: String.Encoding.utf8.rawValue)
            }
        }
        return try? MLNShape(data: data, encoding: String.Encoding.utf8.rawValue)
    }
}

// MARK: - Private GeoJSON Decodable Helper

private struct GeoJSONTahasilFeature: Decodable {
    let properties: GISTahasilFeature
}

private struct GeoJSONTahasilCollection: Decodable {
    let features: [GeoJSONTahasilFeature]
    /// Backend sets this to false for districts absent from the census dataset.
    /// Defaults to true when absent (Keonjhar/Cuttack custom files don't include it).
    let geometryAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case features
        case geometryAvailable = "geometry_available"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.features = try container.decode([GeoJSONTahasilFeature].self, forKey: .features)
        self.geometryAvailable = try container.decodeIfPresent(Bool.self, forKey: .geometryAvailable) ?? true
    }
}
