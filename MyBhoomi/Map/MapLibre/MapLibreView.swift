import SwiftUI
import UIKit
import MapLibre
import MapLibreSwiftUI

struct MapLibreView: UIViewRepresentable {
    @Binding var selectedParcel: Parcel?
    @Binding var center: Coordinate
    @Binding var zoom: Double
    @Binding var isSatellite: Bool
    @Binding var showParcels: Bool
    @Binding var shouldCenterOnUser: Bool
    @Binding var tapPoint: CGPoint?
    @Binding var parcels: [Parcel]
    var onRegionChanged: ((Coordinate, Coordinate) -> Void)?
    
    func makeUIView(context: Context) -> MLNMapView {
        print("DEBUG: 🗺️ makeUIView - Initializing MapView...")
        
        let stylePath = Bundle.main.path(forResource: "style", ofType: "json", inDirectory: "Map") ??
        Bundle.main.path(forResource: "style", ofType: "json") ??
        Bundle.main.path(forResource: "style", ofType: "json", inDirectory: "Resources/Map")
        
        let styleURL: URL
        if let path = stylePath {
            styleURL = URL(fileURLWithPath: path)
        } else {
            styleURL = URL(fileURLWithPath: "/Users/uday/Documents/MyBhoomi/MyBhoomi/Resources/Map/style.json")
        }
        
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        mapView.compassView.compassVisibility = .adaptive
        mapView.showsScale = true
        mapView.scaleBarPosition = .bottomLeft
        mapView.scaleBarMargins = CGPoint(x: 12, y: 18)
        
        // Hide MapLibre logo and info button for a cleaner, premium look
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        
        mapView.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        let initialCenter = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
        mapView.setCenter(initialCenter, zoomLevel: zoom, animated: false)
        
        mapView.maximumZoomLevel = 22
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        let targetCenter = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
        
        if shouldCenterOnUser, let userLocation = uiView.userLocation?.coordinate {
            uiView.setCenter(userLocation, zoomLevel: 16, animated: true)
            DispatchQueue.main.async {
                self.shouldCenterOnUser = false
            }
        }
        
        if let style = uiView.style {
            style.layer(withIdentifier: "osm-layer")?.isVisible = !isSatellite
            style.layer(withIdentifier: "satellite-layer")?.isVisible = isSatellite
            
            // Sync layer visibility with state and zoom (Enhanced Visibility)
            let canShowLines = uiView.zoomLevel >= 13.5
            let canShowDetails = uiView.zoomLevel >= 14.0
            
            style.layer(withIdentifier: "parcel-fill")?.isVisible = showParcels && canShowDetails
            style.layer(withIdentifier: "parcel-outline")?.isVisible = showParcels && canShowLines
            style.layer(withIdentifier: "parcel-labels")?.isVisible = showParcels && canShowDetails
            style.layer(withIdentifier: "parcel-highlight")?.isVisible = showParcels && canShowLines
            style.layer(withIdentifier: "parcel-highlight-fill")?.isVisible = showParcels && canShowLines
            
            // REACTIVE HIGHLIGHT: Surgical precision for only the tapped polygon
            if let parcel = selectedParcel {
                let targetId = parcel.id
                let plotNo = parcel.metadata.plotNumber
                let village = parcel.metadata.additionalInfo?["v_namc"] ?? parcel.metadata.additionalInfo?["v_name"] ?? ""
                let block = parcel.metadata.additionalInfo?["b_namc"] ?? parcel.metadata.additionalInfo?["b_name"] ?? ""
                
                // 1. Line Highlight
                if let highlight = style.layer(withIdentifier: "parcel-highlight") as? MLNLineStyleLayer {
                    // COMPOSITE PREDICATE: Matches by (Plot Number + Village + Block)
                    // This prevents cross-village highlighting and works around the $id crash.
                    let crit = NSPredicate(format: "revenue_plot == %@ AND (v_namc == %@ OR v_name == %@)", 
                                          plotNo, village, village)
                    highlight.predicate = crit
                    highlight.lineWidth = NSExpression(forConstantValue: 4.2)
                    highlight.lineColor = NSExpression(forConstantValue: UIColor.cyan)
                }
                
                // 2. Fill Highlight
                if let fillHighlight = style.layer(withIdentifier: "parcel-highlight-fill") as? MLNFillStyleLayer {
                    let crit = NSPredicate(format: "revenue_plot == %@ AND (v_namc == %@ OR v_name == %@)", 
                                          plotNo, village, village)
                    fillHighlight.predicate = crit
                    fillHighlight.fillColor = NSExpression(forConstantValue: UIColor.cyan.withAlphaComponent(0.42))
                }
            } else {
                (style.layer(withIdentifier: "parcel-highlight") as? MLNLineStyleLayer)?.predicate = NSPredicate(format: "revenue_plot == 'NONE'")
                (style.layer(withIdentifier: "parcel-highlight-fill") as? MLNFillStyleLayer)?.predicate = NSPredicate(format: "revenue_plot == 'NONE'")
            }
            
            // Re-sync deduped labels on UI update (toggles)
            context.coordinator.updateDedupedLabels(for: uiView)
            
            // ENSURE LABELS ARE ON TOP: Force labeling layer to top of stack
            if let labelLayer = style.layer(withIdentifier: "parcel-labels") {
                style.removeLayer(labelLayer)
                style.addLayer(labelLayer)
            }
        }
        
        if !shouldCenterOnUser {
            let currentCenter = uiView.centerCoordinate
            let latDiff = abs(currentCenter.latitude - targetCenter.latitude)
            let lonDiff = abs(currentCenter.longitude - targetCenter.longitude)
            let zoomDiff = abs(uiView.zoomLevel - zoom)
            
            if latDiff > 0.00001 || lonDiff > 0.00001 || zoomDiff > 0.05 {
                uiView.setCenter(targetCenter, zoomLevel: zoom, animated: true)
            }
        }
        
        // Dynamic Data Refresh: Sync ViewModel parcels with Map source
        if let style = uiView.style, let source = style.source(withIdentifier: "live-cadastral-source") as? MLNShapeSource {
            let shapes = parcels.map { parcel -> MLNFeature in
                let coords = parcel.boundary.map { $0.clLocation }
                let feature = MLNPolygonFeature(coordinates: coords, count: UInt(coords.count))
                feature.attributes = ["revenue_plot": parcel.metadata.plotNumber, "type": parcel.metadata.landUseType ?? "parcel"]
                return feature
            }
            source.shape = MLNShapeCollection(shapes: shapes)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreView
        
        init(_ parent: MapLibreView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            let potentialOldLayers = ["revenue_plot", "plot_labels", "cadastral_labels", "labels"]
            for id in potentialOldLayers {
                style.layer(withIdentifier: id)?.isVisible = false
            }
            
            parent.setupLayers(on: mapView)
            updateDedupedLabels(for: mapView)
        }
        
        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            let bounds = mapView.visibleCoordinateBounds
            let ne = Coordinate(latitude: bounds.ne.latitude, longitude: bounds.ne.longitude)
            let sw = Coordinate(latitude: bounds.sw.latitude, longitude: bounds.sw.longitude)
            
            parent.onRegionChanged?(ne, sw)
            
            DispatchQueue.main.async {
                self.parent.center = Coordinate(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
                self.parent.zoom = mapView.zoomLevel
            }
            
            // Re-deduplicate labels after the user stops moving the map
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.updateDedupedLabels(for: mapView)
            }
        }
        
        func updateDedupedLabels(for mapView: MLNMapView) {
            // Robust Detection: Compute labels starting at 14.0
            guard let style = mapView.style, parent.showParcels, mapView.zoomLevel >= 14.0 else {
                if let source = mapView.style?.source(withIdentifier: "deduped-labels-source") as? MLNShapeSource {
                    source.shape = nil
                }
                return
            }
            
            // REMOVED PRE-FLUSH: Replacing shape directly is more stable than setting to nil first
            
            // 1. RUTHLESS DEDUPLICATION: Query all cadastral features
            // We query both fill and outline for redundancy
            let features = mapView.visibleFeatures(in: mapView.bounds, styleLayerIdentifiers: ["parcel-fill", "parcel-outline"])
            
            var uniqueLabels: [String: MLNPointFeature] = [:]
            
            for feature in features {
                let attributes = feature.attributes
                
                let rawPlot = attributes["revenue_plot"] ?? attributes["revenuc_plot"]
                let plotNo: String
                if let s = rawPlot as? String {
                    plotNo = s.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let n = rawPlot as? NSNumber {
                    plotNo = "\(n)"
                } else {
                    continue
                }
                
                let village = (attributes["v_namc"] as? String) ?? (attributes["v_name"] as? String ?? "")
                
                // Composite key normalization: Plot + Village = Unique labeling context
                let normalizedKey = "\(plotNo)_\(village)".lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                guard !plotNo.isEmpty, plotNo != "0" else { continue }
                
                if uniqueLabels[normalizedKey] == nil {
                    // CENTER CALCULATION: For polygons, we must ensure the point is actually inside
                    // MLNPolygonFeature's 'coordinate' is a decent fallback, but we can verify it
                    let point = MLNPointFeature()
                    point.coordinate = feature.coordinate
                    point.attributes = ["revenue_plot": plotNo]
                    uniqueLabels[normalizedKey] = point
                }
            }
            
            // 2. DYNAMIC SOURCE REFRESH: Force a clean state refresh
            if let source = style.source(withIdentifier: "deduped-labels-source") as? MLNShapeSource {
                let collection = MLNShapeCollection(shapes: Array(uniqueLabels.values))
                source.shape = collection
            }
            
            // 3. NUCLEAR SCRUBBER: Kill ALL native symbol layers
            // This ensures NO labels from the PMTiles can ever "pop" through
            let protectedLayerIDs = ["parcel-labels", "parcel-highlight", "parcel-highlight-fill", "parcel-outline", "parcel-fill", "osm-layer", "satellite-layer"]
            for layer in style.layers {
                if !protectedLayerIDs.contains(layer.identifier) {
                    if layer is MLNSymbolStyleLayer || layer.identifier.contains("label") || layer.identifier.contains("revenue") {
                        layer.isVisible = false
                        layer.minimumZoomLevel = 24
                    }
                }
            }
        }
        
        // REMOVED regionDidChange from here as it's now handled as an override above
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MLNMapView else { return }
            
            // Sync selection threshold with line visibility
            guard mapView.zoomLevel >= 14.0 else { return }
            
            let point = gesture.location(in: mapView)
            let features = mapView.visibleFeatures(at: point, styleLayerIdentifiers: ["parcel-fill"])
            
            if let feature = features.first {
                // Capture the actual unique ID from the vector tile
                let featureId: String
                if let fid = feature.identifier as? String {
                    featureId = fid
                } else if let fid = feature.identifier as? NSNumber {
                    featureId = "\(fid)"
                } else {
                    featureId = (feature.attributes["p_id"] as? String) ?? UUID().uuidString
                }

                // SUBTLE HAPTIC (Professional click)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                let attributes = feature.attributes
                
                // DATA ROBUSTNESS: Unified plot number parsing
                let rawPlot = attributes["revenue_plot"] ?? attributes["revenuc_plot"]
                var plotNo = "N/A"
                if let s = rawPlot as? String {
                    plotNo = s.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let n = rawPlot as? NSNumber {
                    plotNo = "\(n)"
                }
                
                let village = (attributes["v_namc"] as? String) ?? (attributes["v_name"] as? String ?? "N/A")
                let block = (attributes["b_namc"] as? String) ?? (attributes["b_name"] as? String ?? "N/A")
                
                var allInfo: [String: String] = [:]
                for (key, value) in attributes {
                    allInfo[key] = "\(value)"
                }
                
                let parcel = Parcel(
                    id: featureId,
                    boundary: [],
                    metadata: ParcelMetadata(
                        plotNumber: plotNo,
                        area: {
                            // Try multiple possible area keys and handle both String and Double types
                            let areaKeys = ["area_in_acre", "area", "acre", "Acre", "AREA"]
                            for key in areaKeys {
                                if let val = attributes[key] {
                                    if let doubleVal = val as? Double { return doubleVal }
                                    if let stringVal = val as? String, let doubleVal = Double(stringVal) { return doubleVal }
                                }
                            }
                            return 0.0
                        }(),
                        ownerName: "N/A",
                        landUseType: block,
                        additionalInfo: allInfo
                    )
                )
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.parent.tapPoint = point
                        self.parent.selectedParcel = parcel
                    }
                }
            } else {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self.parent.selectedParcel = nil
                        self.parent.tapPoint = nil
                    }
                }
            }
        }
    }
    
    fileprivate func setupLayers(on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        
        // Base Layers
        if style.layer(withIdentifier: "satellite-layer") == nil {
            let satSource = MLNRasterTileSource(identifier: "satellite-source", tileURLTemplates: ["https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}"], options: [
                .tileSize: 256,
                .maximumZoomLevel: 22,
                .minimumZoomLevel: 0
            ])
            style.addSource(satSource)
            let satLayer = MLNRasterStyleLayer(identifier: "satellite-layer", source: satSource)
            satLayer.isVisible = isSatellite
            satLayer.rasterFadeDuration = NSExpression(forConstantValue: 0)
            style.insertLayer(satLayer, at: 0)
        }
        
        if style.layer(withIdentifier: "osm-layer") == nil {
            let osmSource = MLNRasterTileSource(identifier: "osm-source", tileURLTemplates: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], options: [
                .tileSize: 256,
                .maximumZoomLevel: 19,
                .minimumZoomLevel: 0
            ])
            style.addSource(osmSource)
            let osmLayer = MLNRasterStyleLayer(identifier: "osm-layer", source: osmSource)
            osmLayer.isVisible = !isSatellite
            osmLayer.rasterFadeDuration = NSExpression(forConstantValue: 0)
            if let sat = style.layer(withIdentifier: "satellite-layer") {
                style.insertLayer(osmLayer, above: sat)
            } else {
                style.addLayer(osmLayer)
            }
        }
        
        let sourceID = "odisha-cadastral"
        let fillID = "parcel-fill"
        let outlineID = "parcel-outline"
        let highlightID = "parcel-highlight"
        let highlightFillID = "parcel-highlight-fill"
        let labelID = "parcel-labels"
        
        // --- DYNAMIC SOURCE (LIVE API) ---
        if style.source(withIdentifier: "live-cadastral-source") == nil {
            let liveSource = MLNShapeSource(identifier: "live-cadastral-source", features: [], options: nil)
            style.addSource(liveSource)
            
            // Dynamic Fill
            let liveFill = MLNFillStyleLayer(identifier: "live-fill", source: liveSource)
            liveFill.fillColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.12))
            liveFill.predicate = NSPredicate(format: "type == 'parcel'")
            style.addLayer(liveFill)
            
            // Dynamic Outline
            let liveOutline = MLNLineStyleLayer(identifier: "live-outline", source: liveSource)
            liveOutline.lineColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.8))
            liveOutline.lineWidth = NSExpression(forConstantValue: 1.0)
            liveOutline.predicate = NSPredicate(format: "type == 'parcel'")
            style.addLayer(liveOutline)
            
            // Roads Layer (from Odisha API)
            let roadLayer = MLNLineStyleLayer(identifier: "live-roads", source: liveSource)
            roadLayer.lineColor = NSExpression(forConstantValue: UIColor.orange.withAlphaComponent(0.7))
            roadLayer.lineWidth = NSExpression(forConstantValue: 2.0)
            roadLayer.predicate = NSPredicate(format: "type == 'road'")
            style.addLayer(roadLayer)
            
            // Rivers Layer (from Odisha API)
            let riverLayer = MLNFillStyleLayer(identifier: "live-rivers", source: liveSource)
            riverLayer.fillColor = NSExpression(forConstantValue: UIColor.systemBlue.withAlphaComponent(0.5))
            riverLayer.predicate = NSPredicate(format: "type == 'river'")
            style.addLayer(riverLayer)
        }
        
        // Ensure Source exists (PMTiles - kept for background discovery)
        let source: MLNSource
        if let existingSource = style.source(withIdentifier: sourceID) {
            source = existingSource
        } else {
            let pmtilesPath = AppConfig.pmtilesPath
            let newSource = MLNVectorTileSource(identifier: sourceID, configurationURL: URL(string: "pmtiles://file://\(pmtilesPath)")!)
            style.addSource(newSource)
            source = newSource
        }
        
        // 1. FILL LAYER
        let fillLayer: MLNFillStyleLayer
        if let existing = style.layer(withIdentifier: fillID) as? MLNFillStyleLayer {
            fillLayer = existing
        } else {
            fillLayer = MLNFillStyleLayer(identifier: fillID, source: source)
            fillLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
            fillLayer.fillColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.12)) // Increased for visibility query engine
            style.addLayer(fillLayer)
        }
        fillLayer.isVisible = showParcels && mapView.zoomLevel >= 14.0
        fillLayer.minimumZoomLevel = 10.0
        
        // 2. OUTLINE LAYER
        let outlineLayer: MLNLineStyleLayer
        if let existing = style.layer(withIdentifier: outlineID) as? MLNLineStyleLayer {
            outlineLayer = existing
        } else {
            outlineLayer = MLNLineStyleLayer(identifier: outlineID, source: source)
            outlineLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
            style.addLayer(outlineLayer)
        }
        // High-contrast crisp boundaries
        outlineLayer.lineColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.7))
        outlineLayer.lineWidth = NSExpression(forConstantValue: 0.8)
        outlineLayer.lineJoin = NSExpression(forConstantValue: "round")
        outlineLayer.lineCap = NSExpression(forConstantValue: "round")
        outlineLayer.isVisible = showParcels && mapView.zoomLevel >= 13.5
        outlineLayer.minimumZoomLevel = 10.0
        
        // 3. HIGHLIGHT LAYERS (Line + High-Contrast Fill)
        if style.layer(withIdentifier: highlightFillID) == nil {
            let fillHighlight = MLNFillStyleLayer(identifier: highlightFillID, source: source)
            fillHighlight.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
            fillHighlight.fillColor = NSExpression(forConstantValue: UIColor.cyan.withAlphaComponent(0.42))
            fillHighlight.predicate = NSPredicate(format: "revenue_plot == 'NONE'")
            style.insertLayer(fillHighlight, above: fillLayer)
        }

        if style.layer(withIdentifier: highlightID) == nil {
            let highlightLayer = MLNLineStyleLayer(identifier: highlightID, source: source)
            highlightLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
            highlightLayer.lineColor = NSExpression(forConstantValue: UIColor.cyan)
            highlightLayer.lineWidth = NSExpression(forConstantValue: 4.5)
            style.insertLayer(highlightLayer, above: outlineLayer)
            highlightLayer.predicate = NSPredicate(format: "revenue_plot == 'NONE'")
            highlightLayer.isVisible = showParcels && mapView.zoomLevel >= 13.5
            highlightLayer.minimumZoomLevel = 10.0
        }
        
        // 4. REINVENTED LABELING SYSTEM (MASTER)
        let dedupedSourceID = "deduped-labels-source"
        if style.source(withIdentifier: dedupedSourceID) == nil {
            style.addSource(MLNShapeSource(identifier: dedupedSourceID, features: [], options: nil))
        }
        
        // Ensure ONLY our custom labels are visible at high zoom
        if style.layer(withIdentifier: labelID) == nil {
            let labelLayer = MLNSymbolStyleLayer(identifier: labelID, source: style.source(withIdentifier: dedupedSourceID)!)
            labelLayer.text = NSExpression(forKeyPath: "revenue_plot")
            labelLayer.textColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 255/255, blue: 240/255, alpha: 1.0)) // High-contrast White/Ivory
            labelLayer.textFontSize = NSExpression(forConstantValue: 13) // Slightly larger
            labelLayer.textHaloWidth = NSExpression(forConstantValue: 2.0) // Thicker halo for satellite visibility
            labelLayer.textHaloColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.95))
            labelLayer.textAllowsOverlap = NSExpression(forConstantValue: true) 
            labelLayer.textIgnoresPlacement = NSExpression(forConstantValue: true)
            labelLayer.textVariableAnchor = NSExpression(forConstantValue: ["center", "top", "bottom", "left", "right"])
            labelLayer.isVisible = showParcels && mapView.zoomLevel >= 14.0
            labelLayer.minimumZoomLevel = 10.0
            style.addLayer(labelLayer)
        }
        
        // 5. ATTRIBUTION DISCLAIMER
        if style.layer(withIdentifier: "arcgis-attribution") == nil {
            let attributionSource = MLNShapeSource(identifier: "attribution-source", features: [], options: nil)
            style.addSource(attributionSource)
            let layer = MLNSymbolStyleLayer(identifier: "arcgis-attribution", source: attributionSource)
            layer.text = NSExpression(forConstantValue: "Cadastral data sourced from Government of Odisha public GIS services (BhuNaksha). This platform provides visualization only.")
            layer.textColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.6))
            layer.textFontSize = NSExpression(forConstantValue: 10)
            style.addLayer(layer)
        }
    }
}
