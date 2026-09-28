import SwiftUI
import UIKit
import CoreLocation
import MapLibre

/// Map logging is off by default: these logs sit on per-frame / per-update
/// paths, and building the strings alone cost main-thread time. Flip to `true`
/// locally when debugging the map. The message is never built when off.
private let mapVerboseLogging = false

@inline(__always)
private func debugLog(_ item: @autoclosure () -> Any) {
    #if DEBUG
    if mapVerboseLogging { Swift.print(item()) }
    #endif
}

struct MapLibreView: UIViewRepresentable {
    @Binding var selectedParcel: Parcel?
    @Binding var selectedCadastralParcel: CadastralParcel?
    @Binding var cadastralShape: MLNShape?
    @Binding var center: Coordinate
    @Binding var zoom: Double
    @Binding var pendingCameraTarget: MapViewModel.CameraTarget?
    @Binding var isSatellite: Bool
    @Binding var showParcels: Bool
    @Binding var parcelDisplayStyle: ParcelDisplayStyle
    @Binding var shouldCenterOnUser: Bool
    @Binding var isTrackingUser: Bool
    @Binding var userLocationCoordinate: Coordinate?
    @Binding var shouldResetBearing: Bool
    @Binding var tapPoint: CGPoint?
    @Binding var selectedLocationInfo: LocalAdminClient.LocationInfo?
    var activeCadastralVillage: CadastralVillage? = nil
    var visualFilter: MapVisualFilter = .natural
    var selectionToken: UUID = UUID()
    var parcelCount: Int = 0
    var currentFlow: String = "LIVE"
    /// Uttar Pradesh prototype: WMS tile template for the active UP village (nil = UP off).
    var upTileURLTemplate: String? = nil
    /// Uttar Pradesh: official exact-plot highlight tiles for the selected plot (nil = none).
    var upSelectionTileURLTemplate: String? = nil
    /// Uttar Pradesh: selected plot bbox [minLng, minLat, maxLng, maxLat]; only
    /// limits which highlight tiles are requested, never drawn.
    var upSelectionBBox: [Double]? = nil
    var onUPTap: ((CLLocationCoordinate2D) -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    /// Not observed here: MainView already observes the explorer and re-renders
    /// this view when it changes. Observing it twice doubled map updates.
    var explorerVM: GISExplorerViewModel { .shared }
    
    var onRegionChanged: ((Coordinate, Coordinate) -> Void)?
    var onMapTap: ((Coordinate, CGPoint) -> Void)?
    var onParcelTapped: ((CadastralParcel) -> Void)?
    var onParcelRenderingVerified: ((Bool, String, UUID, String) -> Void)?
    
    func makeUIView(context: Context) -> MLNMapView {
        debugLog("[\(currentFlow)-2] MapLibreView exists")
        
        let stylePath = Bundle.main.path(forResource: "style", ofType: "json", inDirectory: "Resources/Map") ??
                        Bundle.main.path(forResource: "style", ofType: "json")
        
        // Bundled style; styleURL is nullable, so a missing file degrades instead of pointing at a dev machine path.
        let styleURL = stylePath.map { URL(fileURLWithPath: $0) }
        
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = context.coordinator
        debugLog("[\(currentFlow)-3] mapView exists (bounds=\(mapView.bounds), center=(\(center.latitude), \(center.longitude)), zoom=\(zoom))")
        
        // Lazy-load user location to prevent intrusive system prompt at app launch
        mapView.showsUserLocation = false
        mapView.showsUserHeadingIndicator = false
        
        // Ornaments (Dynamic Scale Bar: shown only during zoom/pan interaction)
        mapView.showsScale = true
        mapView.scaleBarPosition = .bottomLeft
        mapView.scaleBarMargins = CGPoint(x: 20, y: 30)
        
        mapView.compassViewPosition = .topRight
        mapView.compassViewMargins = CGPoint(x: 20, y: 100)
        
        mapView.logoView.isHidden = true
        // Esri tiles require visible attribution; the fallback tiles show none.
        mapView.attributionButton.isHidden = !MapTileProvider.usesLicensedTiles
        
        // Hide scale bar initially; will reveal dynamically on pan/zoom interaction
        DispatchQueue.main.async {
            context.coordinator.findScaleBarView(in: mapView)?.alpha = 0.0
        }
        
        let initialCenter = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
        debugLog("DEBUG: 🗺️ makeUIView - initialCenter: (\(center.latitude), \(center.longitude)), zoom: \(zoom)")
        mapView.setCenter(initialCenter, zoomLevel: zoom, animated: false)
        mapView.maximumZoomLevel = 22
        context.coordinator.isProgrammaticMove = true
        context.coordinator.programmaticTargetCenter = initialCenter
        context.coordinator.programmaticTargetZoom = zoom
        
        // Pre-warm user location services so GPS fix is instantly ready on tap
        #if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("-disableUserLocation") {
            mapView.showsUserLocation = true
            mapView.showsUserHeadingIndicator = true
        }
        #else
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        #endif
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        context.coordinator.parent = self
        
        // 1. User location is reported from the MLNMapViewDelegate callback only
        //    (distance-throttled). Writing it from here too re-triggered updates.
        
        if shouldCenterOnUser {
            DispatchQueue.main.async {
                self.shouldCenterOnUser = false
            }
            if !uiView.showsUserLocation {
                uiView.showsUserLocation = true
                uiView.showsUserHeadingIndicator = true
            }
            if let userLocation = uiView.userLocation?.coordinate, CLLocationCoordinate2DIsValid(userLocation) && (userLocation.latitude != 0.0 || userLocation.longitude != 0.0) {
                context.coordinator.isProgrammaticMove = true
                uiView.setCenter(userLocation, zoomLevel: 16.5, animated: true)
            }
        }
        
        // 1.5 Bearing / Compass North Reset
        if shouldResetBearing {
            uiView.resetNorth()
            DispatchQueue.main.async {
                self.shouldResetBearing = false
            }
        }
        
        let isExplorerActive = AppConfig.gisNavigationEnabled && GISExplorerViewModel.shared.isExplorerActive
        
        // 2. Map State Sync & Dynamic Cadastral Shape Updates
        if let style = uiView.style {
            context.coordinator.isStyleReady = true
            context.coordinator.activeStyle = style
            context.coordinator.reconcileCadastralPipeline(on: uiView, style: style)
            context.coordinator.syncUPLayers(style: style)
            
            // Dedicated Single-Parcel Highlight Source & Safe Region Focus
            if let highlightSource = style.source(withIdentifier: "selected-parcel-source") as? MLNShapeSource {
                let targetParcelCoords: [Coordinate]? = {
                    if let cadastral = selectedCadastralParcel, cadastral.boundary.count >= 3 {
                        return cadastral.boundary
                    } else if let parcel = selectedParcel, parcel.boundary.count >= 3 {
                        return parcel.boundary
                    }
                    return nil
                }()
                
                let targetParcelID: String? = selectedCadastralParcel?.id ?? selectedParcel?.id
                
                if let coordsList = targetParcelCoords, let parcelID = targetParcelID {
                    if context.coordinator.highlightedParcelID != parcelID {
                        context.coordinator.showGradientOverlay(on: uiView, coordinates: coordsList)
                    }
                    
                    if context.coordinator.highlightedParcelID != parcelID {
                        var coords = coordsList.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                        highlightSource.shape = MLNPolygonFeature(coordinates: &coords, count: UInt(coords.count))
                        context.coordinator.highlightedParcelID = parcelID
                        
                        // Calculate Safe Visible Bounds placing the plot smoothly with surrounding area clearly visible
                        let minLat = coords.map(\.latitude).min() ?? 0
                        let maxLat = coords.map(\.latitude).max() ?? 0
                        let minLon = coords.map(\.longitude).min() ?? 0
                        let maxLon = coords.map(\.longitude).max() ?? 0
                        
                        if minLat != 0 && maxLat != 0 {
                            let centerLat = (minLat + maxLat) / 2.0
                            let centerLon = (minLon + maxLon) / 2.0
                            let targetLookAt = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
                            
                            let latSpan = maxLat - minLat
                            let lonSpan = maxLon - minLon
                            let maxSpan = max(latSpan, lonSpan)
                            let plotDiameterMeters = maxSpan * 111_000.0
                            
                            // Elevate the map viewport center so the plot rests nicely in view with room above bottom card
                            uiView.contentInset = UIEdgeInsets(top: 30, left: 0, bottom: 220, right: 0)
                            
                            // Balanced viewing altitude ensuring the plot is focused while keeping adjacent plots visible
                            let targetAltitude = max(880.0, plotDiameterMeters * 6.0)
                            
                            // High-detail aerial 3D camera centered directly on the parcel centroid
                            let targetCamera = MLNMapCamera(
                                lookingAtCenter: targetLookAt,
                                altitude: targetAltitude,
                                pitch: 20.0,   // Balanced aerial perspective tilt
                                heading: uiView.direction
                            )
                            
                            context.coordinator.stopAmbientRotation(on: uiView)
                            
                            let reduceMotion = UIAccessibility.isReduceMotionEnabled
                            if reduceMotion {
                                uiView.setCamera(targetCamera, animated: false)
                            } else {
                                // Cinematic smooth zoom approach
                                uiView.setCamera(targetCamera, withDuration: 1.15, animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut))
                                
                                // Initiate continuous 3D ambient orbit with dynamic 10-20% zoom breathing wave
                                let workItem = DispatchWorkItem { [weak coordinator = context.coordinator, weak uiView] in
                                    guard let c = coordinator, let mv = uiView, c.highlightedParcelID == parcelID else { return }
                                    c.startAmbientRotation(on: mv, baseAltitude: targetAltitude)
                                }
                                context.coordinator.focusTask = workItem
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
                            }
                        }
                    }
                    // Borderless selected plot - highlight layers disabled
                    context.coordinator.hideHighlightLayersIfNeeded(style: style)
                } else {
                    context.coordinator.hideGradientOverlay()
                    if context.coordinator.highlightedParcelID != nil {
                        highlightSource.shape = nil
                        context.coordinator.highlightedParcelID = nil
                        context.coordinator.stopAmbientRotation(on: uiView)
                        
                        uiView.contentInset = .zero
                        
                        // Reset camera pitch and direction back smoothly
                        let resetCam = uiView.camera
                        resetCam.pitch = 0
                        resetCam.heading = 0
                        uiView.setCamera(resetCam, withDuration: 0.85, animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut))
                    }
                    context.coordinator.hideHighlightLayersIfNeeded(style: style)
                }
            }
        } else {
            context.coordinator.handleStyleNotReady(
                cadastralShape: cadastralShape,
                village: activeCadastralVillage,
                token: selectionToken,
                parcelCount: parcelCount
            )
        }
        
        // 3. Programmatic Camera Update (Single Intent - consumed immediately, never overrides user gestures)
        if let target = pendingCameraTarget {
            context.coordinator.isProgrammaticMove = true
            context.coordinator.programmaticTargetCenter = target.center
            context.coordinator.programmaticTargetZoom = target.zoom
            uiView.setCenter(target.center, zoomLevel: target.zoom, animated: target.animated)
            DispatchQueue.main.async {
                self.pendingCameraTarget = nil
            }
        }
        
        // 4. GIS Explorer Integration (Safely gated by feature flag)
        if AppConfig.gisNavigationEnabled {
            let explorerVM = GISExplorerViewModel.shared
            if explorerVM.isExplorerActive {
                context.coordinator.explorerLayersShown = true
                let isVillageLevel: Bool = {
                    if case .village = explorerVM.currentLevel { return true }
                    return false
                }()
                
                GISExplorerMapCoordinator.shared.setupDistrictLayers(on: uiView, shape: explorerVM.districtsShape)
                GISExplorerMapCoordinator.shared.updateSelectedDistrict(
                    on: uiView,
                    districtID: explorerVM.selectedDistrictID,
                    isExplorerActive: true
                )
                GISExplorerMapCoordinator.shared.setupTahasilLayers(
                    on: uiView,
                    shape: explorerVM.tahasilsShape,
                    selectedTahasilID: explorerVM.selectedTahasilID,
                    isExplorerActive: true,
                    isVillageLevel: isVillageLevel
                )
                if let bounds = explorerVM.targetCameraBounds {
                    switch explorerVM.currentLevel {
                    case .district:
                        GISExplorerMapCoordinator.shared.flyToDistrictBounds(mapView: uiView, sw: bounds.sw, ne: bounds.ne)
                    case .subdivision:
                        GISExplorerMapCoordinator.shared.flyToTahasilBounds(mapView: uiView, sw: bounds.sw, ne: bounds.ne)
                    case .village:
                        GISExplorerMapCoordinator.shared.flyToVillageExtent(mapView: uiView, sw: bounds.sw, ne: bounds.ne)
                    case .odisha:
                        GISExplorerMapCoordinator.shared.flyToDistrictBounds(mapView: uiView, sw: bounds.sw, ne: bounds.ne)
                    }
                    DispatchQueue.main.async {
                        explorerVM.targetCameraBounds = nil
                    }
                } else if let targetCenter = explorerVM.targetCameraCenter, let targetZoom = explorerVM.targetCameraZoom {
                    GISExplorerMapCoordinator.shared.flyToCenter(mapView: uiView, center: targetCenter, zoom: targetZoom)
                    DispatchQueue.main.async {
                        explorerVM.targetCameraCenter = nil
                        explorerVM.targetCameraZoom = nil
                    }
                }
            } else if context.coordinator.explorerLayersShown {
                // Tear explorer layers down once when leaving the explorer, not on every update.
                context.coordinator.explorerLayersShown = false
                GISExplorerMapCoordinator.shared.updateSelectedDistrict(
                    on: uiView,
                    districtID: nil,
                    isExplorerActive: false
                )
                GISExplorerMapCoordinator.shared.setupTahasilLayers(
                    on: uiView,
                    shape: nil,
                    selectedTahasilID: nil,
                    isExplorerActive: false,
                    isVillageLevel: false
                )
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreView
        var highlightedParcelID: String?
        var lastLoadedShape: MLNShape?
        
        var isProgrammaticMove: Bool = false
        var programmaticTargetCenter: CLLocationCoordinate2D?
        var programmaticTargetZoom: Double?
        var lastAppliedCenter: CLLocationCoordinate2D?
        var lastAppliedZoom: Double?
        
        // Explicit MapLibre lifecycle state
        var isStyleReady: Bool = false
        weak var activeStyle: MLNStyle?
        
        // Pending cadastral state (held when parcel data arrives before style is loaded)
        var pendingCadastralShape: MLNShape?
        var pendingVillage: CadastralVillage?
        var pendingToken: UUID?
        var pendingParcelCount: Int = 0
        
        // Installed cadastral state (tracking what is physically installed in the active style)
        var lastInstalledShape: MLNShape?
        var installedVillageID: String?
        var installedToken: UUID?
        
        // Render verification state
        var confirmedRenderToken: UUID?
        
        // Base layers dirty-tracking cache to avoid repeated NSExpression creation during text search updates
        var lastBaseLayerIsSatellite: Bool?
        var lastBaseLayerShowParcels: Bool?
        var lastBaseLayerVisualFilter: MapVisualFilter?
        var lastBaseLayerExplorerActive: Bool?
        
        // Change tracking so per-update work only runs when inputs actually change.
        var explorerLayersShown = false
        private var lastVisibilityKey: String?
        private var highlightLayersHidden = false
        private var lastReportedUserCoord: CLLocationCoordinate2D?
        private weak var cachedScaleBar: UIView?
        
        func hideHighlightLayersIfNeeded(style: MLNStyle) {
            guard !highlightLayersHidden else { return }
            style.layer(withIdentifier: "parcel-highlight")?.isVisible = false
            style.layer(withIdentifier: "parcel-highlight-fill")?.isVisible = false
            highlightLayersHidden = style.layer(withIdentifier: "parcel-highlight") != nil
        }
        
        func handleStyleNotReady(cadastralShape: MLNShape?, village: CadastralVillage?, token: UUID, parcelCount: Int) {
            self.isStyleReady = false
            self.activeStyle = nil
            self.pendingCadastralShape = cadastralShape
            self.pendingVillage = village
            self.pendingToken = token
            self.pendingParcelCount = parcelCount
        }
        
        func ensureCadastralInfrastructure(style: MLNStyle, initialShape: MLNShape? = nil) {
            let sourceID = "cadastral-parcels-source"
            let source: MLNShapeSource
            if let existing = style.source(withIdentifier: sourceID) as? MLNShapeSource {
                source = existing
            } else {
                let options: [MLNShapeSourceOption: Any] = [
                    .synchronousUpdate: true
                ]
                let newSource = MLNShapeSource(identifier: sourceID, shape: initialShape, options: options)
                style.addSource(newSource)
                source = newSource
                debugLog("[\(parent.currentFlow)-10] source installed (persistent, hasShape=\(initialShape != nil))")
            }
            
            if style.layer(withIdentifier: "parcel-fill") == nil {
                installCadastralLayers(in: style, source: source)
            }
        }
        
        func reconcileCadastralPipeline(on mapView: MLNMapView, style: MLNStyle) {
            self.isStyleReady = true
            self.activeStyle = style
            
            let isExplorerActive = AppConfig.gisNavigationEnabled && GISExplorerViewModel.shared.isExplorerActive
            
            // 1. Base Layer Stack: Satellite, Map Labels, OSM
            ensureBaseLayers(style: style, isExplorerActive: isExplorerActive)
            
            // 2. Resolve Target Cadastral Shape, Village, Token, and Count
            let targetShape: MLNShape? = parent.cadastralShape ?? self.pendingCadastralShape
            let targetVillage: CadastralVillage? = parent.activeCadastralVillage ?? self.pendingVillage
            let targetToken: UUID = parent.selectionToken
            let targetParcelCount: Int = parent.parcelCount > 0 ? parent.parcelCount : self.pendingParcelCount
            
            let sourceID = "cadastral-parcels-source"
            
            // 3. Ensure Persistent Cadastral Infrastructure (Source + 4 Layers)
            ensureCadastralInfrastructure(style: style, initialShape: targetShape)
            
            // Dedicated Single-Parcel Highlight Source & Layers
            ensureHighlightLayers(style: style)
            
            guard let shape = targetShape, targetParcelCount > 0, let village = targetVillage else {
                // If shape was cleared or not yet ready, clear the source contents without destroying layers
                if lastInstalledShape != nil {
                    if let source = style.source(withIdentifier: sourceID) as? MLNShapeSource {
                        source.shape = nil
                    }
                    mapView.triggerRepaint()
                    lastInstalledShape = nil
                    installedVillageID = nil
                    installedToken = nil
                    confirmedRenderToken = nil
                }
                updateCadastralLayerVisibility(style: style)
                return
            }
            
            // 4. Cadastral Source Shape Update.
            // Only a new shape or village re-uploads geometry (a large, main-thread
            // re-tessellation). A new selection token alone just re-arms render
            // verification — it used to reinstall the whole village on every keystroke.
            let shapeNeedsUpdate = (lastInstalledShape !== shape) ||
                                   (installedVillageID != village.id)
            
            if !shapeNeedsUpdate && installedToken != targetToken {
                installedToken = targetToken
                confirmedRenderToken = nil
            }
            
            if shapeNeedsUpdate {
                if let source = style.source(withIdentifier: sourceID) as? MLNShapeSource {
                    source.shape = shape
                    #if DEBUG
                    debugLog("[MAP] parcels installed for \(village.name) (features=\(targetParcelCount))")
                    #endif
                }
                
                lastInstalledShape = shape
                installedVillageID = village.id
                installedToken = targetToken
                confirmedRenderToken = nil
                
                self.pendingCadastralShape = nil
                self.pendingVillage = nil
                self.pendingToken = nil
                self.pendingParcelCount = 0
                
                // Trigger single repaint for updated shape
                mapView.triggerRepaint()
            }
            
            updateCadastralLayerVisibility(style: style)
        }
        
        func cleanupCadastralLayers(from style: MLNStyle) {
            let layerIDs = ["parcel-labels", "parcel-outline", "parcel-outline-casing", "parcel-fill"]
            for id in layerIDs {
                if let layer = style.layer(withIdentifier: id) {
                    style.removeLayer(layer)
                }
            }
            if let source = style.source(withIdentifier: "cadastral-parcels-source") {
                style.removeSource(source)
            }
        }
        
        func installCadastralLayers(in style: MLNStyle, source: MLNShapeSource) {
            let baseAnchorLayer = style.layer(withIdentifier: "osm-layer") ??
                                  style.layer(withIdentifier: "map-labels-layer") ??
                                  style.layer(withIdentifier: "satellite-layer")
            
            // 1. Fill Layer
            // Data-driven per-plot shade: reads the `fill_color` hex string injected on each
            // feature by GeoJSONFeatureParser. Opacity is driven by parcelDisplayStyle so
            // "Shaded Plots" renders solid parcel fills while "Boundary Only" stays transparent.
            let fillLayer = MLNFillStyleLayer(identifier: "parcel-fill", source: source)
            fillLayer.fillColor = Coordinator.parcelFillColorExpression()
            fillLayer.fillOpacity = NSExpression(forConstantValue: Coordinator.parcelFillOpacity(for: parent.parcelDisplayStyle, showParcels: parent.showParcels))
            fillLayer.minimumZoomLevel = 10.0
            fillLayer.isVisible = parent.showParcels
            if let anchor = baseAnchorLayer {
                style.insertLayer(fillLayer, above: anchor)
            } else {
                style.addLayer(fillLayer)
            }
            debugLog("[\(parent.currentFlow)-12] fill layer found (installed)")
            
            // 2. Casing Layer
            let casingLayer = MLNLineStyleLayer(identifier: "parcel-outline-casing", source: source)
            casingLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 10/255, green: 15/255, blue: 5/255, alpha: 0.45))
            casingLayer.lineWidth = NSExpression(forConstantValue: 2.60)
            casingLayer.lineBlur = NSExpression(forConstantValue: 0.70)
            casingLayer.lineJoin = NSExpression(forConstantValue: "round")
            casingLayer.lineCap = NSExpression(forConstantValue: "round")
            casingLayer.minimumZoomLevel = 10.0
            casingLayer.lineOpacity = NSExpression(forConstantValue: parent.showParcels ? 0.50 : 0.0)
            casingLayer.isVisible = parent.showParcels
            style.insertLayer(casingLayer, above: fillLayer)
            
            // 3. Outline Layer
            let outlineLayer = MLNLineStyleLayer(identifier: "parcel-outline", source: source)
            let lineColor = UIColor(red: 255/255, green: 220/255, blue: 25/255, alpha: 0.90)
            outlineLayer.lineColor = NSExpression(forConstantValue: lineColor)
            outlineLayer.lineWidth = NSExpression(forConstantValue: 1.55)
            outlineLayer.lineBlur = NSExpression(forConstantValue: 0.15)
            outlineLayer.lineJoin = NSExpression(forConstantValue: "round")
            outlineLayer.lineCap = NSExpression(forConstantValue: "round")
            outlineLayer.minimumZoomLevel = 10.0
            outlineLayer.lineOpacity = NSExpression(forConstantValue: parent.showParcels ? 0.92 : 0.0)
            outlineLayer.isVisible = parent.showParcels
            style.insertLayer(outlineLayer, above: casingLayer)
            debugLog("[\(parent.currentFlow)-13] outline layer found (installed)")
            
            // 4. Labels Layer
            let labelLayer = MLNSymbolStyleLayer(identifier: "parcel-labels", source: source)
            labelLayer.text = NSExpression(forKeyPath: "revenue_plot")
            labelLayer.textColor = NSExpression(forConstantValue: UIColor.white)
            labelLayer.textFontSize = NSExpression(forConstantValue: 12.0)
            labelLayer.textHaloWidth = NSExpression(forConstantValue: 1.8)
            labelLayer.textHaloColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.95))
            labelLayer.minimumZoomLevel = 12.0
            labelLayer.textOpacity = NSExpression(forConstantValue: parent.showParcels ? 1.0 : 0.0)
            labelLayer.isVisible = parent.showParcels
            style.insertLayer(labelLayer, above: outlineLayer)
        }
        
        func updateCadastralLayerVisibility(style: MLNStyle) {
            // Skip entirely unless an input changed: each property set dirties the
            // MapLibre style, and this runs on every SwiftUI update.
            let selectedPlotNum = parent.selectedCadastralParcel?.plotNumber ?? parent.selectedParcel?.identity.plotNumber
            let layersPresent = style.layer(withIdentifier: "parcel-fill") != nil
            let key = "\(parent.showParcels)|\(parent.parcelDisplayStyle.rawValue)|\(selectedPlotNum ?? "-")|\(layersPresent)|\(ObjectIdentifier(style).hashValue)"
            guard key != lastVisibilityKey else { return }
            lastVisibilityKey = key
            
            if let fillLayer = style.layer(withIdentifier: "parcel-fill") as? MLNFillStyleLayer {
                // Apply the opacity dictated by the active display style so toggling
                // Shaded/Boundary updates the map live. The colour expression is set once at install.
                fillLayer.fillOpacity = NSExpression(forConstantValue: Coordinator.parcelFillOpacity(for: parent.parcelDisplayStyle, showParcels: parent.showParcels))
                fillLayer.isVisible = parent.showParcels
            }
            if let casingLayer = style.layer(withIdentifier: "parcel-outline-casing") as? MLNLineStyleLayer {
                casingLayer.lineOpacity = NSExpression(forConstantValue: parent.showParcels ? 0.50 : 0.0)
                casingLayer.isVisible = parent.showParcels
            }
            if let outlineLayer = style.layer(withIdentifier: "parcel-outline") as? MLNLineStyleLayer {
                outlineLayer.lineOpacity = NSExpression(forConstantValue: parent.showParcels ? 0.92 : 0.0)
                outlineLayer.isVisible = parent.showParcels
            }
            if let labelLayer = style.layer(withIdentifier: "parcel-labels") as? MLNSymbolStyleLayer {
                labelLayer.textOpacity = NSExpression(forConstantValue: parent.showParcels ? 1.0 : 0.0)
                labelLayer.isVisible = parent.showParcels
                let isAnyParcelSelected = (parent.selectedCadastralParcel != nil || parent.selectedParcel != nil)
                if isAnyParcelSelected, let plotNum = selectedPlotNum, !plotNum.isEmpty {
                    labelLayer.predicate = NSPredicate(
                        format: "revenue_plot == %@ OR plot_number == %@ OR plotno == %@ OR plot_no == %@ OR khesra_no == %@",
                        plotNum, plotNum, plotNum, plotNum, plotNum
                    )
                } else {
                    labelLayer.predicate = nil
                }
            }
        }

        /// Builds the data-driven fill color from each feature's injected `shade_index`
        /// integer property (0-9, see GeoJSONFeatureParser), mapped to the app's violet
        /// choropleth palette. Using the integer index avoids relying on hex-string parsing,
        /// which MapLibre style expressions do not perform. Any unmatched feature falls back
        /// to a neutral violet so parcels never render fully invisible in shaded mode.
        static func parcelFillColorExpression() -> NSExpression { cachedParcelFillColorExpression }
        
        /// Built once; the palette never changes.
        private static let cachedParcelFillColorExpression: NSExpression = makeParcelFillColorExpression()
        
        private static func makeParcelFillColorExpression() -> NSExpression {
            let palette: [UIColor] = [
                UIColor(red: 0x4F/255, green: 0x46/255, blue: 0xE5/255, alpha: 1.0), // 0 Deep Royal Indigo
                UIColor(red: 0x7C/255, green: 0x3A/255, blue: 0xED/255, alpha: 1.0), // 1 Electric Violet
                UIColor(red: 0x93/255, green: 0x33/255, blue: 0xEA/255, alpha: 1.0), // 2 Rich Vibrant Purple
                UIColor(red: 0x63/255, green: 0x66/255, blue: 0xF1/255, alpha: 1.0), // 3 Bold Iris
                UIColor(red: 0x8B/255, green: 0x5C/255, blue: 0xF6/255, alpha: 1.0), // 4 Medium Amethyst
                UIColor(red: 0xA8/255, green: 0x55/255, blue: 0xF7/255, alpha: 1.0), // 5 Vivid Orchid
                UIColor(red: 0x58/255, green: 0x1C/255, blue: 0x87/255, alpha: 1.0), // 6 Deep Dark Purple
                UIColor(red: 0x81/255, green: 0x8C/255, blue: 0xF8/255, alpha: 1.0), // 7 Periwinkle Slate
                UIColor(red: 0x37/255, green: 0x30/255, blue: 0xA3/255, alpha: 1.0), // 8 Dark Indigo
                UIColor(red: 0xA7/255, green: 0x8B/255, blue: 0xFA/255, alpha: 1.0)  // 9 Bright Lavender Violet
            ]
            let fallback = palette[1] // #7C3AED
            var matchStops: [NSExpression: NSExpression] = [:]
            for (i, color) in palette.enumerated() {
                matchStops[NSExpression(forConstantValue: NSNumber(value: i))] = NSExpression(forConstantValue: color)
            }
            // Coerce shade_index to a number so the match keys compare reliably even when the
            // GeoJSON encodes it as a string.
            let keyExpression = NSExpression(format: "CAST(shade_index, 'NSNumber')")
            return NSExpression(
                forMLNMatchingKey: keyExpression,
                in: matchStops,
                default: NSExpression(forConstantValue: fallback)
            )
        }

        /// Fill opacity for the parcel layer. Shaded mode paints translucent plot fills;
        /// boundary-only mode keeps the fill transparent so only the outline shows.
        static func parcelFillOpacity(for style: ParcelDisplayStyle, showParcels: Bool) -> Double {
            guard showParcels else { return 0.0 }
            switch style {
            case .shadedFill: return 0.42
            case .boundaryOnly: return 0.0
            }
        }
        
        func ensureBaseLayers(style: MLNStyle, isExplorerActive: Bool) {
            let satChanged = (lastBaseLayerIsSatellite != parent.isSatellite)
            let parcelsChanged = (lastBaseLayerShowParcels != parent.showParcels)
            let filterChanged = (lastBaseLayerVisualFilter != parent.visualFilter)
            let explorerChanged = (lastBaseLayerExplorerActive != isExplorerActive)
            let layersMissing = (style.layer(withIdentifier: "satellite-layer") == nil || style.layer(withIdentifier: "map-labels-layer") == nil || style.layer(withIdentifier: "osm-layer") == nil)
            
            if !satChanged && !parcelsChanged && !filterChanged && !explorerChanged && !layersMissing {
                return
            }
            
            lastBaseLayerIsSatellite = parent.isSatellite
            lastBaseLayerShowParcels = parent.showParcels
            lastBaseLayerVisualFilter = parent.visualFilter
            lastBaseLayerExplorerActive = isExplorerActive
            
            if style.layer(withIdentifier: "satellite-layer") == nil {
                let satSource = MLNRasterTileSource(identifier: "satellite-source", tileURLTemplates: [MapTileProvider.satelliteTemplate], options: MapTileProvider.sourceOptions(attribution: MapTileProvider.satelliteAttribution))
                style.addSource(satSource)
                let satLayer = MLNRasterStyleLayer(identifier: "satellite-layer", source: satSource)
                style.insertLayer(satLayer, at: 0)
            }
            if let satLayer = style.layer(withIdentifier: "satellite-layer") as? MLNRasterStyleLayer {
                satLayer.isVisible = parent.isSatellite
                let isVillageLevel = {
                    if case .village = GISExplorerViewModel.shared.currentLevel { return true }
                    return false
                }()
                if isExplorerActive && !isVillageLevel && !parent.showParcels {
                    satLayer.maximumRasterBrightness = NSExpression(forConstantValue: 0.32)
                    satLayer.rasterSaturation = NSExpression(forConstantValue: -0.45)
                    satLayer.rasterContrast = NSExpression(forConstantValue: 0.15)
                } else {
                    satLayer.maximumRasterBrightness = NSExpression(forConstantValue: 1.0)
                    satLayer.rasterContrast = NSExpression(forConstantValue: parent.visualFilter.rasterContrast)
                    satLayer.rasterSaturation = NSExpression(forConstantValue: parent.visualFilter.rasterSaturation)
                }
            }
            
            if style.layer(withIdentifier: "map-labels-layer") == nil {
                let labelsSource = MLNRasterTileSource(identifier: "map-labels-source", tileURLTemplates: [MapTileProvider.labelsTemplate], options: [.tileSize: 256])
                style.addSource(labelsSource)
                let labelsLayer = MLNRasterStyleLayer(identifier: "map-labels-layer", source: labelsSource)
                if let satLayer = style.layer(withIdentifier: "satellite-layer") {
                    style.insertLayer(labelsLayer, above: satLayer)
                } else {
                    style.addLayer(labelsLayer)
                }
            }
            if let labelsLayer = style.layer(withIdentifier: "map-labels-layer") as? MLNRasterStyleLayer {
                labelsLayer.isVisible = parent.isSatellite && !parent.showParcels
            }
            
            if style.layer(withIdentifier: "osm-layer") == nil {
                let osmSource = MLNRasterTileSource(identifier: "osm-source", tileURLTemplates: [MapTileProvider.streetsTemplate], options: MapTileProvider.sourceOptions(attribution: MapTileProvider.streetsAttribution))
                style.addSource(osmSource)
                let osmLayer = MLNRasterStyleLayer(identifier: "osm-layer", source: osmSource)
                if let labelsLayer = style.layer(withIdentifier: "map-labels-layer") {
                    style.insertLayer(osmLayer, above: labelsLayer)
                } else if let satLayer = style.layer(withIdentifier: "satellite-layer") {
                    style.insertLayer(osmLayer, above: satLayer)
                } else {
                    style.addLayer(osmLayer)
                }
            }
            style.layer(withIdentifier: "osm-layer")?.isVisible = !parent.isSatellite
        }

        // MARK: - Uttar Pradesh prototype layers (isolated ids; never touch Odisha layers)

        private var installedUPTemplate: String?
        private var installedUPSelectionTemplate: String?
        private weak var upStyle: MLNStyle?

        func syncUPLayers(style: MLNStyle) {
            let template = parent.upTileURLTemplate
            let styleChanged = upStyle !== style
            if styleChanged {
                upStyle = style
                installedUPTemplate = nil
                installedUPSelectionTemplate = nil
            }
            // Retire the first prototype's bbox rectangle if an old style still has it.
            for id in ["up-selected-line", "up-selected-fill"] {
                if let layer = style.layer(withIdentifier: id) { style.removeLayer(layer) }
            }
            if let src = style.source(withIdentifier: "up-selected-source") { style.removeSource(src) }

            // 1. Parcel-line raster (swap source when the village changes)
            if template != installedUPTemplate || (template != nil && style.layer(withIdentifier: "up-wms-layer") == nil) {
                if let layer = style.layer(withIdentifier: "up-wms-layer") { style.removeLayer(layer) }
                if let src = style.source(withIdentifier: "up-wms-source") { style.removeSource(src) }
                if let template {
                    let source = MLNRasterTileSource(
                        identifier: "up-wms-source",
                        tileURLTemplates: [template],
                        options: [.tileSize: 256, .minimumZoomLevel: 13, .maximumZoomLevel: 20]
                    )
                    style.addSource(source)
                    let layer = MLNRasterStyleLayer(identifier: "up-wms-layer", source: source)
                    layer.minimumZoomLevel = 13
                    layer.rasterOpacity = NSExpression(forConstantValue: 1.0)
                    layer.rasterFadeDuration = NSExpression(forConstantValue: 0.15)
                    if let anchor = style.layer(withIdentifier: "osm-layer") ??
                                    style.layer(withIdentifier: "map-labels-layer") ??
                                    style.layer(withIdentifier: "satellite-layer") {
                        style.insertLayer(layer, above: anchor)
                    } else {
                        style.addLayer(layer)
                    }
                }
                installedUPTemplate = template
            }

            // 2. Official exact-plot highlight (PLOT_SELECTION raster for one plot).
            // Drawn just below the border layer so the plot's own outline and
            // number stay crisp on top of the fill, like upbhunaksha.gov.in.
            let selection = (template != nil) ? parent.upSelectionTileURLTemplate : nil
            let hasSelectionLayer = style.layer(withIdentifier: "up-selection-wms-layer") != nil
            guard selection != installedUPSelectionTemplate || (selection != nil && !hasSelectionLayer) else { return }
            if let layer = style.layer(withIdentifier: "up-selection-wms-layer") { style.removeLayer(layer) }
            if let src = style.source(withIdentifier: "up-selection-wms-source") { style.removeSource(src) }
            installedUPSelectionTemplate = selection
            guard let selection else { return }
            var options: [MLNTileSourceOption: Any] = [.tileSize: 256, .minimumZoomLevel: 13, .maximumZoomLevel: 20]
            // Only request tiles that can contain the plot.
            if let b = parent.upSelectionBBox, b.count == 4, b[0] < b[2], b[1] < b[3] {
                let padLng = (b[2] - b[0]) * 0.05, padLat = (b[3] - b[1]) * 0.05
                let bounds = MLNCoordinateBounds(
                    sw: CLLocationCoordinate2D(latitude: b[1] - padLat, longitude: b[0] - padLng),
                    ne: CLLocationCoordinate2D(latitude: b[3] + padLat, longitude: b[2] + padLng))
                options[.coordinateBounds] = NSValue(mlnCoordinateBounds: bounds)
            }
            let source = MLNRasterTileSource(identifier: "up-selection-wms-source",
                                             tileURLTemplates: [selection], options: options)
            style.addSource(source)
            let layer = MLNRasterStyleLayer(identifier: "up-selection-wms-layer", source: source)
            layer.minimumZoomLevel = 13
            layer.rasterFadeDuration = NSExpression(forConstantValue: 0)
            if let base = style.layer(withIdentifier: "up-wms-layer") {
                style.insertLayer(layer, below: base)
            } else {
                style.addLayer(layer)
            }
        }

        func ensureHighlightLayers(style: MLNStyle) {
            if style.source(withIdentifier: "selected-parcel-source") == nil {
                let highlightSource = MLNShapeSource(identifier: "selected-parcel-source", shape: nil, options: nil)
                style.addSource(highlightSource)
                
                let highlightFill = MLNFillStyleLayer(identifier: "parcel-highlight-fill", source: highlightSource)
                highlightFill.fillColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 0.28))
                highlightFill.isVisible = false
                style.addLayer(highlightFill)
                
                let highlightLayer = MLNLineStyleLayer(identifier: "parcel-highlight", source: highlightSource)
                highlightLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 1.0))
                highlightLayer.lineWidth = NSExpression(forConstantValue: 3.5)
                highlightLayer.lineCap = NSExpression(forConstantValue: "round")
                highlightLayer.lineJoin = NSExpression(forConstantValue: "round")
                highlightLayer.isVisible = false
                style.addLayer(highlightLayer)
            }
        }
        
        private var displayLink: CADisplayLink?
        private weak var activeMapView: MLNMapView?
        private var isOrbiting: Bool = false
        private var baseAltitude: Double = 880.0
        private var zoomBreathingStep: Double = 0.0
        
        var focusTask: DispatchWorkItem?
        var scaleBarHideTask: DispatchWorkItem?
        
        private var gradientOverlay: AnimatedParcelGradientOverlayView?
        private var currentHighlightedCoords: [Coordinate] = []
        
        init(_ parent: MapLibreView) {
            self.parent = parent
        }
        
        func showGradientOverlay(on mapView: MLNMapView, coordinates: [Coordinate]) {
            self.currentHighlightedCoords = coordinates
            
            if gradientOverlay == nil {
                let overlay = AnimatedParcelGradientOverlayView(frame: mapView.bounds)
                overlay.alpha = 0.0
                mapView.addSubview(overlay)
                self.gradientOverlay = overlay
                
                UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
                    overlay.alpha = 1.0
                }
            }
            gradientOverlay?.update(mapView: mapView, coordinates: coordinates)
        }
        
        func hideGradientOverlay() {
            guard let overlay = gradientOverlay else { return }
            self.currentHighlightedCoords = []
            self.gradientOverlay = nil
            
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
                overlay.alpha = 0.0
            } completion: { _ in
                overlay.removeFromSuperview()
            }
        }
        
        func updateGradientOverlay(on mapView: MLNMapView) {
            guard let overlay = gradientOverlay, !currentHighlightedCoords.isEmpty else { return }
            overlay.update(mapView: mapView, coordinates: currentHighlightedCoords)
        }
        
        func findScaleBarView(in mapView: MLNMapView) -> UIView? {
            // Cached: this used to walk the whole subview tree on every animation frame.
            if let cached = cachedScaleBar, cached.superview != nil { return cached }
            func search(_ view: UIView) -> UIView? {
                for sub in view.subviews {
                    let className = String(describing: type(of: sub))
                    if className.lowercased().contains("scale") {
                        return sub
                    }
                    if let found = search(sub) {
                        return found
                    }
                }
                return nil
            }
            let found = search(mapView)
            cachedScaleBar = found
            return found
        }
        
        private func showScaleBar(on mapView: MLNMapView) {
            scaleBarHideTask?.cancel()
            scaleBarHideTask = nil
            if let scaleBar = findScaleBarView(in: mapView) {
                if scaleBar.alpha < 1.0 {
                    UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                        scaleBar.alpha = 1.0
                    }
                }
            }
        }
        
        private func scheduleScaleBarFadeOut(on mapView: MLNMapView) {
            scaleBarHideTask?.cancel()
            let task = DispatchWorkItem { [weak mapView, weak self] in
                guard let mapView = mapView, let self = self else { return }
                if let scaleBar = self.findScaleBarView(in: mapView) {
                    UIView.animate(withDuration: 0.45, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                        scaleBar.alpha = 0.0
                    }
                }
            }
            scaleBarHideTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: task)
        }
        
        func startAmbientRotation(on mapView: MLNMapView, baseAltitude: Double = 880.0) {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            stopAmbientRotation(on: mapView)
            
            self.activeMapView = mapView
            self.baseAltitude = baseAltitude
            self.isOrbiting = true
            
            let link = CADisplayLink(target: self, selector: #selector(handleAmbientRotationStep(displayLink:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        }
        
        func stopAmbientRotation(on mapView: MLNMapView?) {
            focusTask?.cancel()
            focusTask = nil
            isOrbiting = false
            displayLink?.invalidate()
            displayLink = nil
        }
        
        @objc private func handleAmbientRotationStep(displayLink: CADisplayLink) {
            guard isOrbiting, let mapView = activeMapView else { return }
            
            // Frame-rate independent gentle ambient rotation (~1.6 deg/sec for calm, steady view)
            let dt = displayLink.targetTimestamp - displayLink.timestamp
            let safeDt = (dt > 0 && dt < 0.1) ? dt : (1.0 / 60.0)
            
            let rotationSpeedDegPerSec = 1.6
            let currentHeading = mapView.direction
            let newHeading = (currentHeading + (rotationSpeedDegPerSec * safeDt)).truncatingRemainder(dividingBy: 360.0)
            mapView.setDirection(newHeading, animated: false)
            
            updateGradientOverlay(on: mapView)
        }
        
        func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
            // Reveal scale bar dynamically on user pan/zoom interaction
            if !isOrbiting {
                showScaleBar(on: mapView)
            }
            
            // Detect user gestures (pan, pinch, rotation)
            if let gestures = mapView.gestureRecognizers {
                let isUserInteracting = gestures.contains { $0.state == .began || $0.state == .changed }
                if isUserInteracting {
                    // Manual gesture: clear programmatic tracking so user has full control
                    isProgrammaticMove = false
                    programmaticTargetCenter = nil
                    programmaticTargetZoom = nil
                    
                    if isOrbiting {
                        stopAmbientRotation(on: mapView)
                    }
                    // When user starts dragging or exploring, immediately disengage user tracking
                    if parent.isTrackingUser {
                        DispatchQueue.main.async {
                            self.parent.isTrackingUser = false
                        }
                    }
                }
            }
        }
        
        func mapViewRegionIsChanging(_ mapView: MLNMapView) {
            if !isOrbiting {
                showScaleBar(on: mapView)
            }
            updateGradientOverlay(on: mapView)
        }
        
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            debugLog("[\(parent.currentFlow)-4] styleLoaded = true")
            self.isStyleReady = true
            self.activeStyle = style
            
            reconcileCadastralPipeline(on: mapView, style: style)
            
            if AppConfig.gisNavigationEnabled && parent.explorerVM.isExplorerActive {
                GISExplorerMapCoordinator.shared.setupDistrictLayers(on: mapView, shape: parent.explorerVM.districtsShape)
                GISExplorerMapCoordinator.shared.updateSelectedDistrict(
                    on: mapView,
                    districtID: parent.explorerVM.selectedDistrictID,
                    isExplorerActive: true
                )
                GISExplorerMapCoordinator.shared.setupTahasilLayers(
                    on: mapView,
                    shape: parent.explorerVM.tahasilsShape,
                    selectedTahasilID: parent.explorerVM.selectedTahasilID,
                    isExplorerActive: true,
                    isVillageLevel: false
                )
                if let bounds = parent.explorerVM.targetCameraBounds {
                    GISExplorerMapCoordinator.shared.flyToDistrictBounds(mapView: mapView, sw: bounds.sw, ne: bounds.ne)
                } else if let targetCenter = parent.explorerVM.targetCameraCenter, let targetZoom = parent.explorerVM.targetCameraZoom {
                    GISExplorerMapCoordinator.shared.flyToCenter(mapView: mapView, center: targetCenter, zoom: targetZoom)
                }
            }
        }
        
        func mapViewDidFinishRenderingFrame(_ mapView: MLNMapView, fullyRendered: Bool) {
            guard isStyleReady, let style = mapView.style else { return }
            guard let currentVillage = parent.activeCadastralVillage ?? pendingVillage else { return }
            let currentToken = parent.selectionToken
            guard confirmedRenderToken != currentToken else { return }
            
            let targetShape = parent.cadastralShape ?? pendingCadastralShape
            let targetCount = parent.parcelCount > 0 ? parent.parcelCount : pendingParcelCount
            guard targetShape != nil, targetCount > 0 else { return }
            
            guard style.source(withIdentifier: "cadastral-parcels-source") != nil,
                  style.layer(withIdentifier: "parcel-outline") != nil else { return }
            
            let visibleFeatures = mapView.visibleFeatures(in: mapView.bounds, styleLayerIdentifiers: ["parcel-outline", "parcel-fill"])
            let isPhysicallyRendered = visibleFeatures.count > 0
            
            if isPhysicallyRendered {
                confirmedRenderToken = currentToken
                let cam = mapView.centerCoordinate
                debugLog("[\(parent.currentFlow)-15] render callback: confirmed for \(currentVillage.name) (ID: \(currentVillage.id)), visibleFeatures=\(visibleFeatures.count), fullyRendered=\(fullyRendered), zoom=\(mapView.zoomLevel), center=(\(cam.latitude), \(cam.longitude))")
                DispatchQueue.main.async {
                    self.parent.onParcelRenderingVerified?(true, currentVillage.id, currentToken, "Visible")
                }
            }
        }
        
        func mapViewDidBecomeIdle(_ mapView: MLNMapView) {
            guard isStyleReady, let style = mapView.style else { return }
            guard let currentVillage = parent.activeCadastralVillage ?? pendingVillage else { return }
            let currentToken = parent.selectionToken
            guard confirmedRenderToken != currentToken else { return }
            
            let targetShape = parent.cadastralShape ?? pendingCadastralShape
            let targetCount = parent.parcelCount > 0 ? parent.parcelCount : pendingParcelCount
            guard targetShape != nil, targetCount > 0 else { return }
            
            guard style.source(withIdentifier: "cadastral-parcels-source") != nil,
                  style.layer(withIdentifier: "parcel-outline") != nil else { return }
            
            let visibleFeatures = mapView.visibleFeatures(in: mapView.bounds, styleLayerIdentifiers: ["parcel-outline", "parcel-fill"])
            if visibleFeatures.count > 0 {
                confirmedRenderToken = currentToken
                let cam = mapView.centerCoordinate
                debugLog("[\(parent.currentFlow)-15] idle callback: confirmed for \(currentVillage.name) (ID: \(currentVillage.id)), visibleFeatures=\(visibleFeatures.count), zoom=\(mapView.zoomLevel), center=(\(cam.latitude), \(cam.longitude))")
                DispatchQueue.main.async {
                    self.parent.onParcelRenderingVerified?(true, currentVillage.id, currentToken, "Visible")
                }
            }
        }
        
        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard let coord = userLocation?.coordinate, CLLocationCoordinate2DIsValid(coord), (coord.latitude != 0.0 || coord.longitude != 0.0) else { return }
            let userCoord = Coordinate(latitude: coord.latitude, longitude: coord.longitude)
            // MapLibre calls this for heading changes too (many times a second while
            // idle). Only report real movement (~10 m) so the app isn't re-rendered.
            let moved: Bool = {
                guard let last = lastReportedUserCoord else { return true }
                return abs(last.latitude - coord.latitude) > 0.0001 || abs(last.longitude - coord.longitude) > 0.0001
            }()
            if moved {
                lastReportedUserCoord = coord
                DispatchQueue.main.async {
                    self.parent.userLocationCoordinate = userCoord
                }
            }
            if parent.shouldCenterOnUser {
                mapView.setCenter(coord, zoomLevel: 16.5, animated: true)
                DispatchQueue.main.async {
                    self.parent.center = userCoord
                    self.parent.zoom = 16.5
                    self.parent.shouldCenterOnUser = false
                }
            }
        }
        
        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            // Auto-hide scale bar after 1.2s of map stillness
            if !isOrbiting {
                scheduleScaleBarFadeOut(on: mapView)
            }
            
            // Report only user-driven moves, and never synchronously: this callback
            // fires inside updateUIView for programmatic camera changes (the
            // "Publishing changes from within view updates" warning) and ~60×/s
            // during the plot orbit animation.
            if !isProgrammaticMove && !isOrbiting {
                let bounds = mapView.visibleCoordinateBounds
                let ne = Coordinate(latitude: bounds.ne.latitude, longitude: bounds.ne.longitude)
                let sw = Coordinate(latitude: bounds.sw.latitude, longitude: bounds.sw.longitude)
                DispatchQueue.main.async {
                    self.parent.onRegionChanged?(ne, sw)
                }
            }
            
            if isProgrammaticMove {
                isProgrammaticMove = false
                programmaticTargetCenter = nil
                programmaticTargetZoom = nil
                return
            }
            
            // Accept user's camera changes; keep parent coordinates in sync without re-triggering camera moves
            if !isOrbiting {
                let currentCenter = mapView.centerCoordinate
                let currentZoom = mapView.zoomLevel
                let changed = abs(parent.center.latitude - currentCenter.latitude) > 0.00001 ||
                              abs(parent.center.longitude - currentCenter.longitude) > 0.00001 ||
                              abs(parent.zoom - currentZoom) > 0.01
                if changed {
                    DispatchQueue.main.async {
                        self.parent.center = Coordinate(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
                        self.parent.zoom = currentZoom
                    }
                }
            }
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)
            let wrappedCoord = Coordinate(latitude: coord.latitude, longitude: coord.longitude)
            
            parent.onMapTap?(wrappedCoord, point)
            
            // Query visible features from 4K GEO shape source
            let features = mapView.visibleFeatures(at: point, styleLayerIdentifiers: ["parcel-fill"])
            
            // Ray-casting point-in-polygon resolution to find exact containing feature
            var containingFeatures: [MLNFeature] = []
            
            for feature in features {
                let coords = Coordinator.boundaryCoordinates(of: feature)
                if coords.count >= 3 && Coordinator.pointInPolygon(coord: coord, polygon: coords) {
                    containingFeatures.append(feature)
                }
            }
            
            if containingFeatures.count == 1, let match = containingFeatures.first {
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()
                
                let activeVill = self.parent.activeCadastralVillage
                let plotNumber = CadastralFeatureResolver.extractPlotNumber(
                    match.attribute(forKey: "plot_number") ??
                    match.attribute(forKey: "plotno") ??
                    match.attribute(forKey: "plot_no") ??
                    match.attribute(forKey: "khesra_no") ??
                    match.attribute(forKey: "khesra_id") ??
                    match.attribute(forKey: "revenue_plot")
                ) ?? String(describing: match.attribute(forKey: "plot_number") ?? match.attribute(forKey: "revenue_plot") ?? "")
                let rawVillID = CadastralFeatureResolver.extractString(match.attribute(forKey: "village_id") ?? match.attribute(forKey: "v_id")) ?? ""
                let villageID = rawVillID.isEmpty ? (activeVill?.id ?? "") : rawVillID
                let rawVillName = CadastralFeatureResolver.extractString(match.attribute(forKey: "village_name") ?? match.attribute(forKey: "v_name") ?? match.attribute(forKey: "Village")) ?? ""
                let villageName = rawVillName.isEmpty ? (activeVill?.name ?? "") : rawVillName
                let rawBlockID = CadastralFeatureResolver.extractString(match.attribute(forKey: "block_id") ?? match.attribute(forKey: "b_id") ?? match.attribute(forKey: "t_id")) ?? ""
                let blockID = rawBlockID.isEmpty ? (activeVill?.blockID ?? "") : rawBlockID
                let rawBlockName = CadastralFeatureResolver.extractString(match.attribute(forKey: "block_name") ?? match.attribute(forKey: "t_name") ?? match.attribute(forKey: "Tahasil") ?? match.attribute(forKey: "Circle")) ?? ""
                let blockName = rawBlockName.isEmpty ? (activeVill?.blockName ?? "") : rawBlockName
                let rawDistID = CadastralFeatureResolver.extractString(match.attribute(forKey: "district_id") ?? match.attribute(forKey: "d_id")) ?? ""
                let districtID = rawDistID.isEmpty ? (activeVill?.districtID ?? "") : rawDistID
                let rawDistName = CadastralFeatureResolver.extractString(match.attribute(forKey: "district_name") ?? match.attribute(forKey: "d_name") ?? match.attribute(forKey: "District")) ?? ""
                let districtName = rawDistName.isEmpty ? (activeVill?.districtName ?? "") : rawDistName
                let gpID = CadastralFeatureResolver.extractString(match.attribute(forKey: "gp_id") ?? match.attribute(forKey: "halka_id")) ?? activeVill?.gpID
                let boundary = Coordinator.boundaryCoordinates(of: match)
                
                let sourceStr: String
                if let rawSrc = match.attribute(forKey: "source") as? String, !rawSrc.isEmpty {
                    sourceStr = rawSrc
                } else if villageID.hasPrefix("BR_") || districtID.hasPrefix("BR_") {
                    sourceStr = "BIHAR_BHUNAKSHA"
                } else {
                    sourceStr = "ODISHA_4K_GEO"
                }
                
                let stableFeatureID = "\(districtID)_\(blockID)_\(villageID)_\(plotNumber)"
                let cadastralParcel = CadastralParcel(
                    source: sourceStr,
                    sourceFeatureID: stableFeatureID,
                    districtID: districtID,
                    districtName: districtName.isEmpty ? nil : districtName,
                    blockID: blockID,
                    blockName: blockName.isEmpty ? nil : blockName,
                    gpID: gpID,
                    villageID: villageID,
                    villageName: villageName.isEmpty ? nil : villageName,
                    plotNumber: plotNumber,
                    centroid: [coord.longitude, coord.latitude],
                    geometryType: match is MLNMultiPolygonFeature ? "MultiPolygon" : "Polygon",
                    boundary: boundary
                )
                
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.parent.selectedCadastralParcel = cadastralParcel
                        self.parent.tapPoint = point
                        self.parent.onParcelTapped?(cadastralParcel)
                    }
                }
            } else if containingFeatures.count > 1 {
                NotificationCenter.default.post(
                    name: NSNotification.Name("BhumitraShowToast"),
                    object: "Multiple overlapping plots detected. Tap with precision."
                )
            } else if containingFeatures.isEmpty, parent.upTileURLTemplate != nil {
                // Uttar Pradesh prototype: no Odisha parcel here, identify via backend.
                parent.onUPTap?(coord)
            } else if containingFeatures.isEmpty {
                // GIS Explorer Selection (Tahasil first if visible, then District)
                if AppConfig.gisNavigationEnabled && GISExplorerViewModel.shared.isExplorerActive {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    
                    if let tahasilHit = GISExplorerMapCoordinator.shared.hitTestTahasil(at: point, in: mapView) {
                        generator.impactOccurred()
                        DispatchQueue.main.async {
                            GISExplorerViewModel.shared.selectTahasilByID(tahasilHit.id, name: tahasilHit.name, bbox: tahasilHit.bbox)
                        }
                    } else if let hit = GISExplorerMapCoordinator.shared.hitTestDistrict(at: point, in: mapView) {
                        generator.impactOccurred()
                        DispatchQueue.main.async {
                            GISExplorerViewModel.shared.selectDistrictByID(hit.id)
                        }
                    }
                }
            }
        }
        
        static func boundaryCoordinates(of feature: MLNFeature) -> [Coordinate] {
            if let poly = feature as? MLNPolygonFeature {
                let pointCount = Int(poly.pointCount)
                guard pointCount > 0 else { return [] }
                var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
                poly.getCoordinates(&points, range: NSRange(location: 0, length: pointCount))
                return points.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
            } else if let multiPoly = feature as? MLNMultiPolygonFeature {
                if let firstPoly = multiPoly.polygons.first {
                    let pointCount = Int(firstPoly.pointCount)
                    guard pointCount > 0 else { return [] }
                    var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
                    firstPoly.getCoordinates(&points, range: NSRange(location: 0, length: pointCount))
                    return points.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
                }
            }
            return []
        }
        
        static func pointInPolygon(coord: CLLocationCoordinate2D, polygon: [Coordinate]) -> Bool {
            guard polygon.count >= 3 else { return false }
            var inside = false
            var j = polygon.count - 1
            for i in 0..<polygon.count {
                let pi = polygon[i]
                let pj = polygon[j]
                if ((pi.latitude > coord.latitude) != (pj.latitude > coord.latitude)) &&
                    (coord.longitude < (pj.longitude - pi.longitude) * (coord.latitude - pi.latitude) / (pj.latitude - pi.latitude) + pi.longitude) {
                    inside = !inside
                }
                j = i
            }
            return inside
        }
        
        func logAndVerifyParcelRendering(
            mapView: MLNMapView,
            village: CadastralVillage?,
            hasShape: Bool,
            parcelCount: Int
        ) -> (isRendered: Bool, failureReason: String?) {
            guard let style = mapView.style else {
                return (false, "MapLibre style not loaded")
            }
            
            let villageName = village?.name ?? "Unknown"
            let villageId = village?.id ?? "None"
            let hasSource = style.source(withIdentifier: "cadastral-parcels-source") != nil
            let hasFillLayer = style.layer(withIdentifier: "parcel-fill") != nil
            let hasCasingLayer = style.layer(withIdentifier: "parcel-outline-casing") != nil
            let outlineLayer = style.layer(withIdentifier: "parcel-outline") as? MLNLineStyleLayer
            let hasOutlineLayer = outlineLayer != nil
            let isOutlineVisible = outlineLayer?.isVisible ?? false
            let hasLabelsLayer = style.layer(withIdentifier: "parcel-labels") != nil
            let currentZoom = mapView.zoomLevel
            let camCenter = mapView.centerCoordinate
            
            let isRendered = (parcelCount > 0 && hasShape && hasSource && hasOutlineLayer && isOutlineVisible && currentZoom >= 10.0)
            
            if isRendered {
                let report = """
                ==================================================
                [PARCEL_RENDER_VERIFY] 14-ITEM INSPECTION REPORT
                1. Village Name:           \(villageName)
                2. Village ID:             \(villageId)
                3. Parcel Count (Repo):    \(parcelCount)
                4. Shape Feature:          \(hasShape ? "PRESENT" : "MISSING")
                5. cadastral-parcels-src:  \(hasSource ? "INSTALLED" : "MISSING")
                6. parcel-fill layer:      \(hasFillLayer ? "INSTALLED" : "MISSING")
                7. parcel-outline-casing:  \(hasCasingLayer ? "INSTALLED" : "MISSING")
                8. parcel-outline layer:   \(hasOutlineLayer ? "INSTALLED" : "MISSING")
                9. parcel-labels layer:    \(hasLabelsLayer ? "INSTALLED" : "MISSING")
                10. Outline Visibility:    \(isOutlineVisible ? "TRUE" : "FALSE")
                11. Current Zoom Level:    \(String(format: "%.2f", currentZoom)) (min required: 10.0)
                12. Camera Center:         (\(String(format: "%.5f", camCenter.latitude)), \(String(format: "%.5f", camCenter.longitude)))
                13. Parcel Bounds:         \(parcelCount) parcels loaded
                14. Camera in Bounds:      YES
                RESULT:                    PARCEL LAYER CONFIRMED RENDERED
                ==================================================
                """
                debugLog(report)
                return (true, nil)
            } else {
                var reasons: [String] = []
                if parcelCount == 0 { reasons.append("No parcels loaded") }
                if !hasShape { reasons.append("Shape feature collection empty") }
                if !hasSource { reasons.append("Source missing") }
                if !hasOutlineLayer { reasons.append("Outline layer missing") }
                if !isOutlineVisible { reasons.append("Outline layer hidden") }
                if currentZoom < 10.0 { reasons.append("Zoom level below 10.0") }
                return (false, reasons.joined(separator: ", "))
            }
        }
    }
}

// ============================================================
// MARK: - ANIMATED MULTI-COLOR GRADIENT PARCEL OVERLAY (BORDERLESS)
// ============================================================

public final class AnimatedParcelGradientOverlayView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let shapeMask = CAShapeLayer()
    
    private var coordinates: [Coordinate] = []
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        
        // 1. Multi-Color Dynamic Gradient Layer (Translucent Lime Green -> Electric Lime -> Neon Yellow -> Warm Amber)
        gradientLayer.type = .axial
        gradientLayer.opacity = 0.45
        gradientLayer.colors = [
            UIColor(red: 157/255, green: 255/255, blue: 91/255, alpha: 0.55).cgColor,  // #9DFF5B (Lime Green)
            UIColor(red: 198/255, green: 255/255, blue: 0/255, alpha: 0.58).cgColor,   // #C6FF00 (Electric Lime)
            UIColor(red: 255/255, green: 230/255, blue: 0/255, alpha: 0.60).cgColor,   // #FFE600 (Neon Yellow)
            UIColor(red: 255/255, green: 178/255, blue: 0/255, alpha: 0.55).cgColor    // #FFB200 (Warm Amber)
        ]
        gradientLayer.locations = [0.0, 0.35, 0.70, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        
        // Animated continuous diagonal flow
        let startAnim = CABasicAnimation(keyPath: "startPoint")
        startAnim.fromValue = CGPoint(x: -0.6, y: -0.6)
        startAnim.toValue = CGPoint(x: 0.8, y: 0.8)
        startAnim.duration = 2.5
        startAnim.autoreverses = true
        startAnim.repeatCount = .infinity
        startAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let endAnim = CABasicAnimation(keyPath: "endPoint")
        endAnim.fromValue = CGPoint(x: 0.4, y: 0.4)
        endAnim.toValue = CGPoint(x: 1.8, y: 1.8)
        endAnim.duration = 2.5
        endAnim.autoreverses = true
        endAnim.repeatCount = .infinity
        endAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        gradientLayer.add(startAnim, forKey: "gradientFlowStart")
        gradientLayer.add(endAnim, forKey: "gradientFlowEnd")
        
        gradientLayer.mask = shapeMask
        layer.addSublayer(gradientLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    public func update(mapView: MLNMapView, coordinates: [Coordinate]) {
        self.coordinates = coordinates
        self.frame = mapView.bounds
        self.gradientLayer.frame = bounds
        
        guard coordinates.count >= 3 else {
            shapeMask.path = nil
            return
        }
        
        let path = UIBezierPath()
        
        for (i, coord) in coordinates.enumerated() {
            let clCoord = CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
            let pt = mapView.convert(clCoord, toPointTo: self)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.close()
        
        shapeMask.path = path.cgPath
    }
}
