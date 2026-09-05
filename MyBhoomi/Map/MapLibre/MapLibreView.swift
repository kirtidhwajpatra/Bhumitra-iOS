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
            
            // Dynamic Outline Casing (Soft embedded terrain groove underneath the boundary)
            if let casingLayer = style.layer(withIdentifier: "parcel-outline-casing") as? MLNLineStyleLayer {
                let casingOpacity: Float = showParcels ? 0.50 : 0.0
                casingLayer.lineOpacity = NSExpression(forConstantValue: casingOpacity)
                casingLayer.lineWidth = NSExpression(forConstantValue: 2.60)
                casingLayer.lineBlur = NSExpression(forConstantValue: 0.70)
                casingLayer.isVisible = showParcels
            }
            
            // Dynamic Outline (Crisp, vibrant golden boundary lines naturally blended into satellite terrain)
            if let outlineLayer = style.layer(withIdentifier: "parcel-outline") as? MLNLineStyleLayer {
                let lineColor = UIColor(red: 255/255, green: 220/255, blue: 25/255, alpha: 0.90)
                let lineWidth: Float = 1.55
                let lineOpacity: Float = showParcels ? 0.92 : 0.0
                outlineLayer.lineColor = NSExpression(forConstantValue: lineColor)
                outlineLayer.lineWidth = NSExpression(forConstantValue: lineWidth)
                outlineLayer.lineBlur = NSExpression(forConstantValue: 0.15)
                outlineLayer.lineOpacity = NSExpression(forConstantValue: lineOpacity)
                outlineLayer.isVisible = showParcels
            }
            
            // Dynamic Labels: High-contrast Plot Numbers (Filtered to ONLY the selected plot when selected)
            if let labelLayer = style.layer(withIdentifier: "parcel-labels") as? MLNSymbolStyleLayer {
                labelLayer.text = NSExpression(forKeyPath: "revenue_plot")
                labelLayer.textColor = NSExpression(forConstantValue: UIColor.white)
                labelLayer.textFontSize = NSExpression(forConstantValue: 12.0)
                labelLayer.textHaloWidth = NSExpression(forConstantValue: 1.8)
                labelLayer.textHaloColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.95))
                labelLayer.textOpacity = NSExpression(forConstantValue: showParcels ? 1.0 : 0.0)
                labelLayer.isVisible = showParcels
                
                // Hide all other plot numbers when a plot is selected; only show the selected plot number
                let selectedPlotNum = selectedCadastralParcel?.plotNumber ?? selectedParcel?.identity.plotNumber
                if isAnyParcelSelected, let plotNum = selectedPlotNum, !plotNum.isEmpty {
                    labelLayer.predicate = NSPredicate(
                        format: "revenue_plot == %@ OR plot_number == %@ OR plotno == %@ OR plot_no == %@ OR khesra_no == %@",
                        plotNum, plotNum, plotNum, plotNum, plotNum
                    )
                } else {
                    labelLayer.predicate = nil
                }
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
                    context.coordinator.showGradientOverlay(on: uiView, coordinates: coordsList)
                    
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
                    style.layer(withIdentifier: "parcel-highlight")?.isVisible = false
                    style.layer(withIdentifier: "parcel-highlight-fill")?.isVisible = false
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
            updateGradientOverlay(on: mapView)
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
        
        // 4. Dynamic Cadastral Parcels Source (4K GEO WGS84 GeoJSON)
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
            
            // Parcel Outline Casing (Soft embedded terrain groove underneath the boundary)
            let casingLayer = MLNLineStyleLayer(identifier: "parcel-outline-casing", source: parcelSource)
            casingLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 10/255, green: 15/255, blue: 5/255, alpha: 0.45))
            casingLayer.lineWidth = NSExpression(forConstantValue: 2.60)
            casingLayer.lineBlur = NSExpression(forConstantValue: 0.70)
            casingLayer.lineJoin = NSExpression(forConstantValue: "round")
            casingLayer.lineCap = NSExpression(forConstantValue: "round")
            casingLayer.minimumZoomLevel = 10.0
            casingLayer.isVisible = showParcels
            style.addLayer(casingLayer)
            
            // Parcel Outline (Crisp, vibrant golden cartographic boundary line naturally blended into satellite terrain)
            let outlineLayer = MLNLineStyleLayer(identifier: "parcel-outline", source: parcelSource)
            let initialLineColor = UIColor(red: 255/255, green: 220/255, blue: 25/255, alpha: 0.90)
            outlineLayer.lineColor = NSExpression(forConstantValue: initialLineColor)
            outlineLayer.lineWidth = NSExpression(forConstantValue: 1.55)
            outlineLayer.lineBlur = NSExpression(forConstantValue: 0.15)
            outlineLayer.lineJoin = NSExpression(forConstantValue: "round")
            outlineLayer.lineCap = NSExpression(forConstantValue: "round")
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
            
            // 5. Dedicated Single-Parcel Highlight Source
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
