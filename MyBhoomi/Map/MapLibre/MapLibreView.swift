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
        // Ornaments Configuration
        mapView.showsScale = true
        mapView.scaleBarPosition = .bottomLeft
        mapView.scaleBarMargins = CGPoint(x: 20, y: 30)
        
        mapView.compassViewPosition = .topRight
        mapView.compassViewMargins = CGPoint(x: 20, y: 100) // Nudge down below search bar
        
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
            
            if let fillLayer = style.layer(withIdentifier: "parcel-fill") as? MLNFillStyleLayer {
                fillLayer.fillOpacity = NSExpression(forConstantValue: showParcels ? 1.0 : 0.0)
            }
            
            if let outlineLayer = style.layer(withIdentifier: "parcel-outline") as? MLNLineStyleLayer {
                outlineLayer.lineOpacity = NSExpression(forConstantValue: showParcels ? 1.0 : 0.0)
            }
            
            if let labelLayer = style.layer(withIdentifier: "parcel-labels") as? MLNSymbolStyleLayer {
                labelLayer.textOpacity = NSExpression(forConstantValue: showParcels ? 1.0 : 0.0)
            }
            
            if let parcel = selectedParcel {
                if let highlight = style.layer(withIdentifier: "parcel-highlight") as? MLNLineStyleLayer {
                    highlight.isVisible = showParcels
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
            // If a sheet/overlay is currently active, ignore map taps and let SwiftUI's backdrop handle dismissing.
            if parent.selectedParcel != nil || parent.selectedLocationInfo != nil {
                print("DEBUG: Ignored map tap because a sheet is already visible.")
                return
            }
            
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
                print("DEBUG: Tap detected on map with no feature found. Dispatching selectedParcel = nil")
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
                if path.starts(with: "http") {
                    guard let checkURL = URL(string: path) else { return }
                    var request = URLRequest(url: checkURL)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5.0
                    
                    URLSession.shared.dataTask(with: request) { _, response, error in
                        if let httpResponse = response as? HTTPURLResponse,
                           (200...299).contains(httpResponse.statusCode) {
                            DispatchQueue.main.async {
                                // Double check if style is still valid and doesn't have source
                                if mapView.style?.source(withIdentifier: "odisha-cadastral") == nil, let currentStyle = mapView.style {
                                    self.addPMTilesLayer(to: currentStyle, path: path)
                                }
                            }
                        } else {
                            print("DEBUG: ⚠️ PMTiles network check failed, skipping layer to prevent crash: \(error?.localizedDescription ?? "Unknown")")
                        }
                    }.resume()
                } else {
                    self.addPMTilesLayer(to: style, path: path)
                }
            }
        }
    }
    
    fileprivate func addPMTilesLayer(to style: MLNStyle, path: String) {
        let pmtilesURL: URL
        if path.starts(with: "http") {
            pmtilesURL = URL(string: "pmtiles://" + path)!
        } else {
            pmtilesURL = URL(string: "pmtiles://file://" + path)!
        }
        
        let source = MLNVectorTileSource(identifier: "odisha-cadastral", configurationURL: pmtilesURL)
        style.addSource(source)
        
        // Static Fill
        let fillLayer = MLNFillStyleLayer(identifier: "parcel-fill", source: source)
        fillLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
        fillLayer.fillColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.05))
        fillLayer.minimumZoomLevel = 14.5
        fillLayer.isVisible = true
        style.addLayer(fillLayer)
        
        // Static Outline
        let outlineLayer = MLNLineStyleLayer(identifier: "parcel-outline", source: source)
        outlineLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
        outlineLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 0.5))
        outlineLayer.lineWidth = NSExpression(forConstantValue: 1.0)
        outlineLayer.minimumZoomLevel = 14.5
        outlineLayer.isVisible = true
        style.addLayer(outlineLayer)
        
        // Labels
        let labelLayer = MLNSymbolStyleLayer(identifier: "parcel-labels", source: source)
        labelLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
        labelLayer.text = NSExpression(forKeyPath: "revenue_plot")
        labelLayer.textColor = NSExpression(forConstantValue: UIColor.white)
        labelLayer.textFontSize = NSExpression(forConstantValue: 11)
        labelLayer.textHaloWidth = NSExpression(forConstantValue: 1.2)
        labelLayer.textHaloColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.6))
        labelLayer.minimumZoomLevel = 15.5
        labelLayer.isVisible = true
        style.addLayer(labelLayer)
        
        // Highlight
        let highlightLayer = MLNLineStyleLayer(identifier: "parcel-highlight", source: source)
        highlightLayer.sourceLayerIdentifier = "Odisha4kgeo_OD_Cadastrals"
        highlightLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 0.5))
        highlightLayer.lineWidth = NSExpression(forConstantValue: 3.5)
        highlightLayer.isVisible = false
        style.addLayer(highlightLayer)
    }
}
