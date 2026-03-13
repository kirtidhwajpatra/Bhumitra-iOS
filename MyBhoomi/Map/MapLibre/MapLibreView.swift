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
            
            let isZoomedIn = uiView.zoomLevel >= 14.5
            let isVisible = showParcels && isZoomedIn
            
            style.layer(withIdentifier: "parcel-fill")?.isVisible = isVisible
            style.layer(withIdentifier: "parcel-outline")?.isVisible = isVisible
            style.layer(withIdentifier: "parcel-labels")?.isVisible = isVisible
            style.layer(withIdentifier: "parcel-highlight")?.isVisible = isVisible
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
            parent.setupLayers(on: mapView)
        }
        
        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.center = Coordinate(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
                self.parent.zoom = mapView.zoomLevel
            }
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MLNMapView else { return }
            
            // Only allow selection if plots are visible (engine level optimization)
            guard mapView.zoomLevel >= 14.0 else { return }
            
            let point = gesture.location(in: mapView)
            
            let features = mapView.visibleFeatures(at: point, styleLayerIdentifiers: ["parcel-fill"])
            
            if let feature = features.first {
                // SUBTLE HAPTIC (Professional click)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                let attributes = feature.attributes
                let pId = attributes["p_id"] as? String ?? ""
                
                // SUBTLE HIGHLIGHT
                if let style = mapView.style, let selectedLayer = style.layer(withIdentifier: "parcel-highlight") as? MLNVectorStyleLayer {
                    selectedLayer.predicate = NSPredicate(format: "p_id == %@", pId)
                }
                
                let plotNo = (attributes["revenue_plot"] as? String) ?? 
                            ((attributes["revenuc_plot"] as? String) ?? "N/A")
                
                let village = (attributes["v_namc"] as? String) ?? (attributes["v_name"] as? String ?? "N/A")
                let block = (attributes["b_namc"] as? String) ?? (attributes["b_name"] as? String ?? "N/A")
                
                var allInfo: [String: String] = [:]
                for (key, value) in attributes {
                    allInfo[key] = "\(value)"
                }
                
                let parcel = Parcel(
                    id: pId.isEmpty ? UUID().uuidString : pId,
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
                    self.parent.selectedParcel = parcel
                }
            } else {
                if let style = mapView.style, let selectedLayer = style.layer(withIdentifier: "parcel-highlight") as? MLNVectorStyleLayer {
                    selectedLayer.predicate = NSPredicate(format: "p_id == 'NONE'")
                }
                DispatchQueue.main.async {
                    self.parent.selectedParcel = nil
                }
            }
        }
    }
    
    fileprivate func setupLayers(on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        
        // Base Layers
        if style.layer(withIdentifier: "satellite-layer") == nil {
            // High-resolution Satellite Source (Google Satellite has better coverage in India up to z20-22)
            let satSource = MLNRasterTileSource(identifier: "satellite-source", tileURLTemplates: ["https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}"], options: [
                .tileSize: 256,
                .maximumZoomLevel: 22, // Google supports much higher zoom
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
        
        // Parcel Geometry
        if style.layer(withIdentifier: "parcel-fill") == nil {
            let pmtilesPath = AppConfig.pmtilesPath
            let source = MLNVectorTileSource(identifier: "odisha-cadastral", configurationURL: URL(string: "pmtiles://file://\(pmtilesPath)")!)
            style.addSource(source)
            
            let fillLayer = MLNFillStyleLayer(identifier: "parcel-fill", source: source)
            fillLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
            fillLayer.fillColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.05))
            fillLayer.isVisible = showParcels
            style.addLayer(fillLayer)
            
            let outlineLayer = MLNLineStyleLayer(identifier: "parcel-outline", source: source)
            outlineLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
            outlineLayer.lineColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.4))
            outlineLayer.lineWidth = NSExpression(forConstantValue: 0.8)
            outlineLayer.lineJoin = NSExpression(forConstantValue: "round")
            outlineLayer.lineCap = NSExpression(forConstantValue: "round")
            outlineLayer.isVisible = showParcels
            style.addLayer(outlineLayer)

            // SUBTLE HIGHLIGHT (White 1.5pt line)
            let highlightLayer = MLNLineStyleLayer(identifier: "parcel-highlight", source: source)
            highlightLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
            highlightLayer.lineColor = NSExpression(forConstantValue: UIColor.white)
            highlightLayer.lineWidth = NSExpression(forConstantValue: 1.5)
            highlightLayer.predicate = NSPredicate(format: "p_id == 'NONE'")
            highlightLayer.isVisible = showParcels
            style.addLayer(highlightLayer)

            let labelLayer = MLNSymbolStyleLayer(identifier: "parcel-labels", source: source)
            labelLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
            
            // Using simple key path to avoid NSExpression evaluation crash
            // The overlap and padding settings below handle the user's duplicate label issue
            labelLayer.text = NSExpression(forKeyPath: "revenue_plot")
            
            labelLayer.textColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.95))
            labelLayer.textFontSize = NSExpression(forConstantValue: 12)
            labelLayer.textHaloWidth = NSExpression(forConstantValue: 1.2)
            labelLayer.textHaloColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.5))
            
            // CRITICAL: Prevent duplicate labels from crowding the map
            labelLayer.textAllowsOverlap = NSExpression(forConstantValue: false)
            labelLayer.textPadding = NSExpression(forConstantValue: 15.0)
            
            labelLayer.isVisible = showParcels
            labelLayer.minimumZoomLevel = 14.5
            style.addLayer(labelLayer)
            
            fillLayer.minimumZoomLevel = 14.0
            outlineLayer.minimumZoomLevel = 14.0
            highlightLayer.minimumZoomLevel = 14.0
        }
    }
}
