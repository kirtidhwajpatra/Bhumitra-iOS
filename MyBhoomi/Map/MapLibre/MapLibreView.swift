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
    @Binding var parcels: [Parcel] // Still bound for selection/highlight sync
    @Binding var selectedLocationInfo: LocalAdminClient.LocationInfo?
    var onRegionChanged: ((Coordinate, Coordinate) -> Void)?
    var onMapTap: ((Coordinate, CGPoint) -> Void)?
    
    func makeUIView(context: Context) -> MLNMapView {
        print("DEBUG: 🗺️ makeUIView - Initializing MapView...")
        
        // Use the empty style.json as a base
        let stylePath = Bundle.main.path(forResource: "style", ofType: "json", inDirectory: "Resources/Map") ??
                        Bundle.main.path(forResource: "style", ofType: "json")
        
        let styleURL = stylePath.map { URL(fileURLWithPath: $0) } ?? 
                       URL(fileURLWithPath: "/Users/uday/Documents/MyBhoomi/MyBhoomi/Resources/Map/style.json")
        
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        mapView.compassView.compassVisibility = .adaptive
        mapView.showsScale = true
        
        // Hide logos for premium look
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        
        let initialCenter = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
        mapView.setCenter(initialCenter, zoomLevel: zoom, animated: false)
        
        mapView.maximumZoomLevel = 22
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MLNMapView, context: Context) {
        // 1. User Location Tracking
        if shouldCenterOnUser, let userLocation = uiView.userLocation?.coordinate {
            uiView.setCenter(userLocation, zoomLevel: 16, animated: true)
            DispatchQueue.main.async {
                self.shouldCenterOnUser = false
            }
        }
        
        // 2. Map State Sync
        if let style = uiView.style {
            style.layer(withIdentifier: "osm-layer")?.isVisible = !isSatellite
            style.layer(withIdentifier: "satellite-layer")?.isVisible = isSatellite
            
            let isZoomedIn = uiView.zoomLevel >= 13.0
            let isVisible = showParcels && isZoomedIn
            
            style.layer(withIdentifier: "parcel-fill")?.isVisible = isVisible
            style.layer(withIdentifier: "parcel-outline")?.isVisible = isVisible
            style.layer(withIdentifier: "parcel-labels")?.isVisible = showParcels && uiView.zoomLevel >= 14.5
            
            if let parcel = selectedParcel {
                if let highlight = style.layer(withIdentifier: "parcel-highlight") as? MLNLineStyleLayer {
                    highlight.isVisible = true
                    highlight.predicate = NSPredicate(format: "revenue_plot == %@", parcel.metadata.plotNumber)
                }
            } else {
                style.layer(withIdentifier: "parcel-highlight")?.isVisible = false
            }
        }
        
        // 3. Coordinate Sync (Navigation from Search)
        // If shouldCenterOnUser is false, we follow the ViewModel's center
        if !shouldCenterOnUser {
            let targetCenter = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
            let currentCenter = uiView.centerCoordinate
            
            let latDiff = abs(currentCenter.latitude - targetCenter.latitude)
            let lonDiff = abs(currentCenter.longitude - targetCenter.longitude)
            let zoomDiff = abs(uiView.zoomLevel - zoom)
            
            // If the difference is significant, move the map
            if latDiff > 0.00001 || lonDiff > 0.00001 || zoomDiff > 0.05 {
                print("DEBUG: 🗺️ Map moving to search target: \(targetCenter.latitude), \(targetCenter.longitude)")
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
            let bounds = mapView.visibleCoordinateBounds
            let ne = Coordinate(latitude: bounds.ne.latitude, longitude: bounds.ne.longitude)
            let sw = Coordinate(latitude: bounds.sw.latitude, longitude: bounds.sw.longitude)
            
            parent.onRegionChanged?(ne, sw)
            
            DispatchQueue.main.async {
                self.parent.center = Coordinate(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
                self.parent.zoom = mapView.zoomLevel
            }
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)
            let wrappedCoord = Coordinate(latitude: coord.latitude, longitude: coord.longitude)
            
            // Pass tap to parent for admin lookup etc
            parent.onMapTap?(wrappedCoord, point)
            
            // Query vector features from PMTiles source
            let features = mapView.visibleFeatures(at: point, styleLayerIdentifiers: ["parcel-fill"])
            
            if let feature = features.first {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                let attrs = feature.attributes
                let plotNo = (attrs["revenue_plot"] as? String) ?? "N/A"
                
                var allInfo: [String: String] = [:]
                for (key, value) in attrs {
                    allInfo[key] = "\(value)"
                }
                
                let parcel = Parcel(
                    id: (attrs["p_id"] as? String) ?? UUID().uuidString,
                    boundary: [], // Boundary is in PMTiles, no need for redundant coords here if only detail sheet is shown
                    metadata: ParcelMetadata(
                        plotNumber: plotNo,
                        area: (attrs["area_in_acre"] as? Double) ?? 0.0,
                        ownerName: attrs["v_name"] as? String,
                        landUseType: attrs["b_name"] as? String,
                        additionalInfo: allInfo
                    )
                )
                
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.parent.selectedParcel = parcel
                        self.parent.tapPoint = point
                    }
                }
            } else {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        self.parent.selectedParcel = nil
                        self.parent.tapPoint = point
                    }
                }
            }
        }
    }
    
    fileprivate func setupLayers(on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        
        // 1. Satellite Layer
        if style.layer(withIdentifier: "satellite-layer") == nil {
            let satSource = MLNRasterTileSource(identifier: "satellite-source", tileURLTemplates: ["https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}"], options: [.tileSize: 256])
            style.addSource(satSource)
            let satLayer = MLNRasterStyleLayer(identifier: "satellite-layer", source: satSource)
            satLayer.isVisible = isSatellite
            style.insertLayer(satLayer, at: 0)
        }
        
        // 2. OSM Layer
        if style.layer(withIdentifier: "osm-layer") == nil {
            let osmSource = MLNRasterTileSource(identifier: "osm-source", tileURLTemplates: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], options: [.tileSize: 256])
            style.addSource(osmSource)
            let osmLayer = MLNRasterStyleLayer(identifier: "osm-layer", source: osmSource)
            osmLayer.isVisible = !isSatellite
            style.insertLayer(osmLayer, above: style.layer(withIdentifier: "satellite-layer")!)
        }
        
        // 3. PMTiles Vector Source (STATIC DATA SOURCE)
        if style.source(withIdentifier: "odisha-cadastral") == nil {
            let path = AppConfig.pmtilesPath
            if !path.isEmpty {
                let pmtilesURL = URL(string: "pmtiles://file://\(path)")!
                let source = MLNVectorTileSource(identifier: "odisha-cadastral", configurationURL: pmtilesURL)
                style.addSource(source)
                
                // Static Fill
                let fillLayer = MLNFillStyleLayer(identifier: "parcel-fill", source: source)
                fillLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
                fillLayer.fillColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.05))
                fillLayer.isVisible = showParcels
                style.addLayer(fillLayer)
                
                // Static Outline
                let outlineLayer = MLNLineStyleLayer(identifier: "parcel-outline", source: source)
                outlineLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
                outlineLayer.lineColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.4))
                outlineLayer.lineWidth = NSExpression(forConstantValue: 0.8)
                outlineLayer.isVisible = showParcels
                style.addLayer(outlineLayer)
                
                // Labels
                let labelLayer = MLNSymbolStyleLayer(identifier: "parcel-labels", source: source)
                labelLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
                labelLayer.text = NSExpression(forKeyPath: "revenue_plot")
                labelLayer.textColor = NSExpression(forConstantValue: UIColor.white)
                labelLayer.textFontSize = NSExpression(forConstantValue: 11)
                labelLayer.textHaloWidth = NSExpression(forConstantValue: 1.2)
                labelLayer.textHaloColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.6))
                labelLayer.isVisible = showParcels
                style.addLayer(labelLayer)
                
                // Highlight
                let highlightLayer = MLNLineStyleLayer(identifier: "parcel-highlight", source: source)
                highlightLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
                highlightLayer.lineColor = NSExpression(forConstantValue: UIColor.cyan)
                highlightLayer.lineWidth = NSExpression(forConstantValue: 2.0)
                highlightLayer.isVisible = false
                style.addLayer(highlightLayer)
            }
        }
    }
}
