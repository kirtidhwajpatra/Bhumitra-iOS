import SwiftUI
import UIKit
import CoreLocation
import MapLibre
import MapLibreSwiftUI

struct MapLibreView: UIViewRepresentable {
    @Binding var selectedParcel: Parcel?
    @Binding var selectedCadastralParcel: CadastralParcel?
    @Binding var cadastralShape: MLNShape?
    @Binding var center: Coordinate
    @Binding var zoom: Double
    @Binding var isSatellite: Bool
    @Binding var showParcels: Bool
    @Binding var parcelDisplayStyle: ParcelDisplayStyle
    @Binding var shouldCenterOnUser: Bool
    @Binding var isTrackingUser: Bool
    @Binding var tapPoint: CGPoint?
    @Binding var selectedLocationInfo: LocalAdminClient.LocationInfo?
    var activeCadastralVillage: CadastralVillage? = nil
    var visualFilter: MapVisualFilter = .natural
    
    var onRegionChanged: ((Coordinate, Coordinate) -> Void)?
    var onMapTap: ((Coordinate, CGPoint) -> Void)?
    var onParcelTapped: ((CadastralParcel) -> Void)?
    
    func makeUIView(context: Context) -> MLNMapView {
        print("DEBUG: 🗺️ makeUIView - Initializing MapView with 4K GEO Cadastral Pipeline...")
        
        let stylePath = Bundle.main.path(forResource: "style", ofType: "json", inDirectory: "Resources/Map") ??
                        Bundle.main.path(forResource: "style", ofType: "json")
        
        let styleURL = stylePath.map { URL(fileURLWithPath: $0) } ?? 
                       URL(fileURLWithPath: "/Users/uday/Documents/MyBhoomi/MyBhoomi/Resources/Map/style.json")
        
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = context.coordinator
        
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
        mapView.attributionButton.isHidden = true
        
        // Hide scale bar initially; will reveal dynamically on pan/zoom interaction
        DispatchQueue.main.async {
            context.coordinator.findScaleBarView(in: mapView)?.alpha = 0.0
        }
        
        let initialCenter = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
        mapView.setCenter(initialCenter, zoomLevel: zoom, animated: false)
        mapView.maximumZoomLevel = 22
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        // 1. User Location Tracking (Triggered only when location button is explicitly tapped)
        if shouldCenterOnUser || isTrackingUser {
            if !uiView.showsUserLocation {
                uiView.showsUserLocation = true
                uiView.showsUserHeadingIndicator = true
            }
            if let userLocation = uiView.userLocation?.coordinate, CLLocationCoordinate2DIsValid(userLocation) && (userLocation.latitude != 0.0 || userLocation.longitude != 0.0) {
                uiView.setCenter(userLocation, zoomLevel: 16, animated: true)
                DispatchQueue.main.async {
                    self.shouldCenterOnUser = false
                }
            }
        }
        
        // 2. Map State Sync & Dynamic Cadastral Shape Updates
        if let style = uiView.style {
            style.layer(withIdentifier: "osm-layer")?.isVisible = !isSatellite
            
            // Dynamic Satellite Layer Filter Settings (Pure clean satellite imagery)
            if let satLayer = style.layer(withIdentifier: "satellite-layer") as? MLNRasterStyleLayer {
                satLayer.isVisible = isSatellite
                satLayer.rasterContrast = NSExpression(forConstantValue: visualFilter.rasterContrast)
                satLayer.rasterSaturation = NSExpression(forConstantValue: visualFilter.rasterSaturation)
            }
            
            // Map POI / Shop / Road / Location Labels: Only visible when cadastral plots are HIDDEN (eye icon inactive)
            if let labelsLayer = style.layer(withIdentifier: "map-labels-layer") as? MLNRasterStyleLayer {
                labelsLayer.isVisible = isSatellite && !showParcels
            }
            
            // Dynamic Cadastral Shape Source Update (from 4K GEO WGS84 GeoJSON)
            if let parcelSource = style.source(withIdentifier: "cadastral-parcels-source") as? MLNShapeSource {
                if context.coordinator.lastLoadedShape !== cadastralShape {
                    parcelSource.shape = cadastralShape
                    context.coordinator.lastLoadedShape = cadastralShape
                }
            }
            
            let isAnyParcelSelected = (selectedCadastralParcel != nil || selectedParcel != nil)
            
            // Dynamic Fill Opacity: Clean, default transparent overlay
            if let fillLayer = style.layer(withIdentifier: "parcel-fill") as? MLNFillStyleLayer {
                fillLayer.fillOpacity = NSExpression(forConstantValue: 0.0)
                fillLayer.isVisible = showParcels
            }
            
            // Dynamic Outline: Crisp high-contrast default boundary lines (classic golden yellow)
            if let outlineLayer = style.layer(withIdentifier: "parcel-outline") as? MLNLineStyleLayer {
                let lineColor = UIColor(red: 255/255, green: 220/255, blue: 0/255, alpha: 0.90)
                let lineWidth: Float = 1.50
                let lineOpacity: Float = showParcels ? (isAnyParcelSelected ? 0.55 : 1.0) : 0.0
                outlineLayer.lineColor = NSExpression(forConstantValue: lineColor)
                outlineLayer.lineWidth = NSExpression(forConstantValue: lineWidth)
                outlineLayer.lineOpacity = NSExpression(forConstantValue: lineOpacity)
                outlineLayer.isVisible = showParcels
            }
            
            // Dynamic Labels: High-contrast Plot Numbers with bold dark halo
            if let labelLayer = style.layer(withIdentifier: "parcel-labels") as? MLNSymbolStyleLayer {
                labelLayer.text = NSExpression(forKeyPath: "revenue_plot")
                labelLayer.textColor = NSExpression(forConstantValue: UIColor.white)
                labelLayer.textFontSize = NSExpression(forConstantValue: 12.0)
                labelLayer.textHaloWidth = NSExpression(forConstantValue: 1.8)
                labelLayer.textHaloColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.95))
                labelLayer.textOpacity = NSExpression(forConstantValue: showParcels ? (isAnyParcelSelected ? 0.75 : 1.0) : 0.0)
                labelLayer.isVisible = showParcels
            }
            
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
                        var coords = coordsList.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                        highlightSource.shape = MLNPolygonFeature(coordinates: &coords, count: UInt(coords.count))
                        context.coordinator.highlightedParcelID = parcelID
                        
                        // Calculate Safe Visible Bounds placing the plot smoothly in the upper viewport well above the bottom card
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
                            
                            // Generous viewing altitude ensuring comfortable padding on left and right margins
                            let targetAltitude = max(380.0, plotDiameterMeters * 3.4)
                            
                            // High-detail aerial 3D camera centered directly on the parcel centroid
                            let targetCamera = MLNMapCamera(
                                lookingAtCenter: targetLookAt,
                                altitude: targetAltitude,
                                pitch: 26.0,   // Balanced 26° aerial perspective tilt
                                heading: uiView.direction
                            )
                            
                            context.coordinator.stopAmbientRotation(on: uiView)
                            
                            let reduceMotion = UIAccessibility.isReduceMotionEnabled
                            if reduceMotion {
                                uiView.setCamera(targetCamera, animated: false)
                            } else {
                                // Cinematic smooth zoom approach
                                uiView.setCamera(targetCamera, withDuration: 1.15, animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut))
                                
                                // Initiate ultra-slow continuous 3D ambient orbit centered directly on the parcel
                                let workItem = DispatchWorkItem { [weak coordinator = context.coordinator, weak uiView] in
                                    guard let c = coordinator, let mv = uiView, c.highlightedParcelID == parcelID else { return }
                                    c.startAmbientRotation(on: mv)
                                }
                                context.coordinator.focusTask = workItem
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
                            }
                        }
                    }
                    style.layer(withIdentifier: "parcel-highlight")?.isVisible = showParcels
                    style.layer(withIdentifier: "parcel-highlight-fill")?.isVisible = showParcels
                } else {
                    if context.coordinator.highlightedParcelID != nil {
                        highlightSource.shape = nil
                        context.coordinator.highlightedParcelID = nil
                        context.coordinator.stopAmbientRotation(on: uiView)
                        
                        // Reset camera pitch and direction back smoothly
                        var resetCam = uiView.camera
                        resetCam.pitch = 0
                        resetCam.heading = 0
                        uiView.setCamera(resetCam, withDuration: 0.85, animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut))
                    }
                    style.layer(withIdentifier: "parcel-highlight")?.isVisible = false
                    style.layer(withIdentifier: "parcel-highlight-fill")?.isVisible = false
                }
            }
        }
        
        // 3. Coordinate Sync (when not focusing on a parcel)
        if !shouldCenterOnUser && selectedCadastralParcel == nil && selectedParcel == nil {
            let targetCenter = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
            let currentCenter = uiView.centerCoordinate
            
            let latDiff = abs(currentCenter.latitude - targetCenter.latitude)
            let lonDiff = abs(currentCenter.longitude - targetCenter.longitude)
            let zoomDiff = abs(uiView.zoomLevel - zoom)
            
            if latDiff > 0.00001 || lonDiff > 0.00001 || zoomDiff > 0.05 {
                uiView.setCenter(targetCenter, zoomLevel: zoom, animated: true)
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
        
        private var displayLink: CADisplayLink?
        private weak var activeMapView: MLNMapView?
        private var isOrbiting: Bool = false
        var focusTask: DispatchWorkItem?
        var scaleBarHideTask: DispatchWorkItem?
        
        init(_ parent: MapLibreView) {
            self.parent = parent
        }
        
        func findScaleBarView(in mapView: MLNMapView) -> UIView? {
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
            return search(mapView)
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
        
        func startAmbientRotation(on mapView: MLNMapView) {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            stopAmbientRotation(on: mapView)
            
            self.activeMapView = mapView
            self.isOrbiting = true
            
            let link = CADisplayLink(target: self, selector: #selector(handleAmbientRotationStep))
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
        
        @objc private func handleAmbientRotationStep() {
            guard isOrbiting, let mapView = activeMapView else { return }
            // Smooth, living continuous ambient rotation (~2.4 degrees / sec)
            let currentHeading = mapView.direction
            let newHeading = (currentHeading + 0.04).truncatingRemainder(dividingBy: 360.0)
            mapView.setDirection(newHeading, animated: false)
        }
        
        func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
            // Reveal scale bar dynamically on user pan/zoom interaction
            if !isOrbiting {
                showScaleBar(on: mapView)
            }
            
            // Only stop ambient rotation if the user actually touches/drags the map
            if isOrbiting, let gestures = mapView.gestureRecognizers {
                let isUserInteracting = gestures.contains { $0.state == .began || $0.state == .changed }
                if isUserInteracting {
                    stopAmbientRotation(on: mapView)
                }
            }
        }
        
        func mapViewRegionIsChanging(_ mapView: MLNMapView) {
            if !isOrbiting {
                showScaleBar(on: mapView)
            }
        }
        
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            parent.setupLayers(on: mapView)
        }
        
        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard let coord = userLocation?.coordinate, CLLocationCoordinate2DIsValid(coord), (coord.latitude != 0.0 || coord.longitude != 0.0) else { return }
            if parent.shouldCenterOnUser || parent.isTrackingUser {
                mapView.setCenter(coord, zoomLevel: 16, animated: true)
                DispatchQueue.main.async {
                    self.parent.shouldCenterOnUser = false
                }
            }
        }
        
        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            // Auto-hide scale bar after 1.2s of map stillness
            if !isOrbiting {
                scheduleScaleBarFadeOut(on: mapView)
            }
            
            let bounds = mapView.visibleCoordinateBounds
            let ne = Coordinate(latitude: bounds.ne.latitude, longitude: bounds.ne.longitude)
            let sw = Coordinate(latitude: bounds.sw.latitude, longitude: bounds.sw.longitude)
            
            parent.onRegionChanged?(ne, sw)
            
            // Avoid triggering rapid SwiftUI state mutations during continuous ambient rotation
            if !isOrbiting {
                DispatchQueue.main.async {
                    self.parent.center = Coordinate(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
                    self.parent.zoom = mapView.zoomLevel
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
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                let activeVill = self.parent.activeCadastralVillage
                let plotNumber = CadastralFeatureResolver.extractPlotNumber(match.attribute(forKey: "revenue_plot") ?? match.attribute(forKey: "plot_number")) ?? String(describing: match.attribute(forKey: "revenue_plot") ?? match.attribute(forKey: "plot_number") ?? "")
                let rawVillID = CadastralFeatureResolver.extractString(match.attribute(forKey: "village_id") ?? match.attribute(forKey: "v_id")) ?? ""
                let villageID = rawVillID.isEmpty ? (activeVill?.id ?? "") : rawVillID
                let rawVillName = CadastralFeatureResolver.extractString(match.attribute(forKey: "village_name") ?? match.attribute(forKey: "v_name") ?? match.attribute(forKey: "Village")) ?? ""
                let villageName = rawVillName.isEmpty ? (activeVill?.name ?? "") : rawVillName
                let rawBlockID = CadastralFeatureResolver.extractString(match.attribute(forKey: "block_id") ?? match.attribute(forKey: "b_id") ?? match.attribute(forKey: "t_id")) ?? ""
                let blockID = rawBlockID.isEmpty ? (activeVill?.blockID ?? "") : rawBlockID
                let rawBlockName = CadastralFeatureResolver.extractString(match.attribute(forKey: "block_name") ?? match.attribute(forKey: "t_name") ?? match.attribute(forKey: "Tahasil")) ?? ""
                let blockName = rawBlockName.isEmpty ? (activeVill?.blockName ?? "") : rawBlockName
                let rawDistID = CadastralFeatureResolver.extractString(match.attribute(forKey: "district_id") ?? match.attribute(forKey: "d_id")) ?? ""
                let districtID = rawDistID.isEmpty ? (activeVill?.districtID ?? "") : rawDistID
                let rawDistName = CadastralFeatureResolver.extractString(match.attribute(forKey: "district_name") ?? match.attribute(forKey: "d_name") ?? match.attribute(forKey: "District")) ?? ""
                let districtName = rawDistName.isEmpty ? (activeVill?.districtName ?? "") : rawDistName
                let gpID = CadastralFeatureResolver.extractString(match.attribute(forKey: "gp_id")) ?? activeVill?.gpID
                let boundary = Coordinator.boundaryCoordinates(of: match)
                
                let cadastralParcel = CadastralParcel(
                    source: "ODISHA_4K_GEO",
                    sourceFeatureID: match.identifier as? String ?? (villageID.isEmpty ? plotNumber : "\(villageID)_\(plotNumber)"),
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
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
                NotificationCenter.default.post(
                    name: NSNotification.Name("BhumitraShowToast"),
                    object: nil,
                    userInfo: ["message": "Multiple overlapping boundaries detected. Please zoom in.", "icon": "magnifyingglass.circle.fill"]
                )
            }
        }
        
        static func pointInPolygon(coord: CLLocationCoordinate2D, polygon: [Coordinate]) -> Bool {
            guard polygon.count >= 3 else { return false }
            var inside = false
            var j = polygon.count - 1
            
            for i in 0..<polygon.count {
                let pi = polygon[i]
                let pj = polygon[j]
                
                if (pi.latitude > coord.latitude) != (pj.latitude > coord.latitude) &&
                    (coord.longitude < (pj.longitude - pi.longitude) * (coord.latitude - pi.latitude) / (pj.latitude - pi.latitude) + pi.longitude) {
                    inside = !inside
                }
                j = i
            }
            return inside
        }
        
        static func boundaryCoordinates(of feature: MLNFeature) -> [Coordinate] {
            let polygon: MLNPolygon?
            if let poly = feature as? MLNPolygonFeature {
                polygon = poly
            } else if let multi = feature as? MLNMultiPolygonFeature {
                polygon = multi.polygons.max(by: { $0.pointCount < $1.pointCount })
            } else {
                polygon = nil
            }
            
            guard let polygon = polygon, polygon.pointCount >= 3 else { return [] }
            
            let count = Int(polygon.pointCount)
            var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
            polygon.getCoordinates(&coords, range: NSRange(location: 0, length: count))
            return coords
                .filter { CLLocationCoordinate2DIsValid($0) }
                .map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        }
    }
    
    fileprivate func setupLayers(on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        
        // 1. Pure Clean Satellite Base Layer (No labels, no POIs, no road text)
        if style.layer(withIdentifier: "satellite-layer") == nil {
            let satSource = MLNRasterTileSource(identifier: "satellite-source", tileURLTemplates: ["https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}"], options: [.tileSize: 256])
            style.addSource(satSource)
            let satLayer = MLNRasterStyleLayer(identifier: "satellite-layer", source: satSource)
            satLayer.isVisible = isSatellite
            style.insertLayer(satLayer, at: 0)
        }
        
        // 2. Map POI / Shop / Road / Location Labels Overlay Layer (Shown only when parcels are hidden)
        if style.layer(withIdentifier: "map-labels-layer") == nil {
            let labelsSource = MLNRasterTileSource(identifier: "map-labels-source", tileURLTemplates: ["https://mt1.google.com/vt/lyrs=h&x={x}&y={y}&z={z}"], options: [.tileSize: 256])
            style.addSource(labelsSource)
            let labelsLayer = MLNRasterStyleLayer(identifier: "map-labels-layer", source: labelsSource)
            labelsLayer.isVisible = isSatellite && !showParcels
            if let satLayer = style.layer(withIdentifier: "satellite-layer") {
                style.insertLayer(labelsLayer, above: satLayer)
            } else {
                style.addLayer(labelsLayer)
            }
        }
        
        // 3. OSM Base Layer
        if style.layer(withIdentifier: "osm-layer") == nil {
            let osmSource = MLNRasterTileSource(identifier: "osm-source", tileURLTemplates: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], options: [.tileSize: 256])
            style.addSource(osmSource)
            let osmLayer = MLNRasterStyleLayer(identifier: "osm-layer", source: osmSource)
            osmLayer.isVisible = !isSatellite
            if let labelsLayer = style.layer(withIdentifier: "map-labels-layer") {
                style.insertLayer(osmLayer, above: labelsLayer)
            } else if let satLayer = style.layer(withIdentifier: "satellite-layer") {
                style.insertLayer(osmLayer, above: satLayer)
            } else {
                style.addLayer(osmLayer)
            }
        }
        
        // 3. Dynamic Cadastral Parcels Source (4K GEO WGS84 GeoJSON)
        if style.source(withIdentifier: "cadastral-parcels-source") == nil {
            let parcelSource = MLNShapeSource(identifier: "cadastral-parcels-source", shape: cadastralShape, options: nil)
            style.addSource(parcelSource)
            
            // Parcel Fill (Transparent base layer)
            let fillLayer = MLNFillStyleLayer(identifier: "parcel-fill", source: parcelSource)
            fillLayer.fillColor = NSExpression(forConstantValue: UIColor.clear)
            fillLayer.fillOpacity = NSExpression(forConstantValue: 0.0)
            fillLayer.minimumZoomLevel = 10.0
            fillLayer.isVisible = showParcels
            style.addLayer(fillLayer)
            
            // Parcel Outline (Crisp High-Contrast Default Gold Grid Boundaries)
            let outlineLayer = MLNLineStyleLayer(identifier: "parcel-outline", source: parcelSource)
            let initialLineColor = UIColor(red: 255/255, green: 220/255, blue: 0/255, alpha: 0.90)
            outlineLayer.lineColor = NSExpression(forConstantValue: initialLineColor)
            outlineLayer.lineWidth = NSExpression(forConstantValue: 1.50)
            outlineLayer.minimumZoomLevel = 10.0
            outlineLayer.isVisible = showParcels
            style.addLayer(outlineLayer)
            
            // Parcel Labels (High-contrast bold numbers with dark halo)
            let labelLayer = MLNSymbolStyleLayer(identifier: "parcel-labels", source: parcelSource)
            labelLayer.text = NSExpression(forKeyPath: "revenue_plot")
            labelLayer.textColor = NSExpression(forConstantValue: UIColor.white)
            labelLayer.textFontSize = NSExpression(forConstantValue: 12.0)
            labelLayer.textHaloWidth = NSExpression(forConstantValue: 1.8)
            labelLayer.textHaloColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.95))
            labelLayer.minimumZoomLevel = 12.0
            labelLayer.isVisible = showParcels
            style.addLayer(labelLayer)
            
            // 4. Dedicated Single-Parcel Highlight Source
            let highlightSource = MLNShapeSource(identifier: "selected-parcel-source", shape: nil, options: nil)
            style.addSource(highlightSource)
            
            let highlightFill = MLNFillStyleLayer(identifier: "parcel-highlight-fill", source: highlightSource)
            highlightFill.fillColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 0.28))
            highlightFill.isVisible = false
            style.addLayer(highlightFill)
            
            let highlightLayer = MLNLineStyleLayer(identifier: "parcel-highlight", source: highlightSource)
            highlightLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 1.0))
            highlightLayer.lineWidth = NSExpression(forConstantValue: 3.5)
            highlightLayer.isVisible = false
            style.addLayer(highlightLayer)
        }
    }
}
