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
    @Binding var shouldCenterOnUser: Bool
    @Binding var tapPoint: CGPoint?
    @Binding var selectedLocationInfo: LocalAdminClient.LocationInfo?
    
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
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        
        // Ornaments
        mapView.showsScale = true
        mapView.scaleBarPosition = .bottomLeft
        mapView.scaleBarMargins = CGPoint(x: 20, y: 30)
        
        mapView.compassViewPosition = .topRight
        mapView.compassViewMargins = CGPoint(x: 20, y: 100)
        
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
        
        // 2. Map State Sync & Dynamic Cadastral Shape Updates
        if let style = uiView.style {
            style.layer(withIdentifier: "osm-layer")?.isVisible = !isSatellite
            style.layer(withIdentifier: "satellite-layer")?.isVisible = isSatellite
            
            // Dynamic Cadastral Shape Source Update (from 4K GEO WGS84 GeoJSON)
            if let parcelSource = style.source(withIdentifier: "cadastral-parcels-source") as? MLNShapeSource {
                if context.coordinator.lastLoadedShape !== cadastralShape {
                    parcelSource.shape = cadastralShape
                    context.coordinator.lastLoadedShape = cadastralShape
                }
            }
            
            if let fillLayer = style.layer(withIdentifier: "parcel-fill") as? MLNFillStyleLayer {
                fillLayer.fillOpacity = NSExpression(forConstantValue: showParcels ? 1.0 : 0.0)
            }
            
            if let outlineLayer = style.layer(withIdentifier: "parcel-outline") as? MLNLineStyleLayer {
                outlineLayer.lineOpacity = NSExpression(forConstantValue: showParcels ? 1.0 : 0.0)
            }
            
            if let labelLayer = style.layer(withIdentifier: "parcel-labels") as? MLNSymbolStyleLayer {
                labelLayer.textOpacity = NSExpression(forConstantValue: showParcels ? 1.0 : 0.0)
            }
            
            // Dedicated Single-Parcel Highlight Source
            if let highlightSource = style.source(withIdentifier: "selected-parcel-source") as? MLNShapeSource {
                if let cadastral = selectedCadastralParcel, cadastral.boundary.count >= 3 {
                    if context.coordinator.highlightedParcelID != cadastral.id {
                        var coords = cadastral.boundary.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                        highlightSource.shape = MLNPolygonFeature(coordinates: &coords, count: UInt(coords.count))
                        context.coordinator.highlightedParcelID = cadastral.id
                    }
                    style.layer(withIdentifier: "parcel-highlight")?.isVisible = showParcels
                    style.layer(withIdentifier: "parcel-highlight-fill")?.isVisible = showParcels
                } else if let parcel = selectedParcel, parcel.boundary.count >= 3 {
                    if context.coordinator.highlightedParcelID != parcel.id {
                        var coords = parcel.boundary.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                        highlightSource.shape = MLNPolygonFeature(coordinates: &coords, count: UInt(coords.count))
                        context.coordinator.highlightedParcelID = parcel.id
                    }
                    style.layer(withIdentifier: "parcel-highlight")?.isVisible = showParcels
                    style.layer(withIdentifier: "parcel-highlight-fill")?.isVisible = showParcels
                } else {
                    if context.coordinator.highlightedParcelID != nil {
                        highlightSource.shape = nil
                        context.coordinator.highlightedParcelID = nil
                    }
                    style.layer(withIdentifier: "parcel-highlight")?.isVisible = false
                    style.layer(withIdentifier: "parcel-highlight-fill")?.isVisible = false
                }
            }
        }
        
        // 3. Coordinate Sync
        if !shouldCenterOnUser {
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
                
                let plotNumber = CadastralFeatureResolver.extractPlotNumber(match.attribute(forKey: "revenue_plot") ?? match.attribute(forKey: "plot_number")) ?? String(describing: match.attribute(forKey: "revenue_plot") ?? match.attribute(forKey: "plot_number") ?? "")
                let villageID = CadastralFeatureResolver.extractString(match.attribute(forKey: "village_id") ?? match.attribute(forKey: "v_id")) ?? ""
                let villageName = CadastralFeatureResolver.extractString(match.attribute(forKey: "village_name") ?? match.attribute(forKey: "v_name") ?? match.attribute(forKey: "Village")) ?? ""
                let blockID = CadastralFeatureResolver.extractString(match.attribute(forKey: "block_id") ?? match.attribute(forKey: "b_id") ?? match.attribute(forKey: "t_id")) ?? ""
                let blockName = CadastralFeatureResolver.extractString(match.attribute(forKey: "block_name") ?? match.attribute(forKey: "t_name") ?? match.attribute(forKey: "Tahasil")) ?? ""
                let districtID = CadastralFeatureResolver.extractString(match.attribute(forKey: "district_id") ?? match.attribute(forKey: "d_id")) ?? ""
                let districtName = CadastralFeatureResolver.extractString(match.attribute(forKey: "district_name") ?? match.attribute(forKey: "d_name") ?? match.attribute(forKey: "District")) ?? ""
                let gpID = CadastralFeatureResolver.extractString(match.attribute(forKey: "gp_id"))
                let boundary = Coordinator.boundaryCoordinates(of: match)
                
                let cadastralParcel = CadastralParcel(
                    source: "ODISHA_4K_GEO",
                    sourceFeatureID: match.identifier as? String ?? (villageID.isEmpty ? plotNumber : "\(villageID)_\(plotNumber)"),
                    districtID: districtID.isEmpty ? "07" : districtID,
                    districtName: districtName.isEmpty ? nil : districtName,
                    blockID: blockID.isEmpty ? "0704" : blockID,
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
        
        // 1. Satellite Base Layer
        if style.layer(withIdentifier: "satellite-layer") == nil {
            let satSource = MLNRasterTileSource(identifier: "satellite-source", tileURLTemplates: ["https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}"], options: [.tileSize: 256])
            style.addSource(satSource)
            let satLayer = MLNRasterStyleLayer(identifier: "satellite-layer", source: satSource)
            satLayer.isVisible = isSatellite
            style.insertLayer(satLayer, at: 0)
        }
        
        // 2. OSM Base Layer
        if style.layer(withIdentifier: "osm-layer") == nil {
            let osmSource = MLNRasterTileSource(identifier: "osm-source", tileURLTemplates: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], options: [.tileSize: 256])
            style.addSource(osmSource)
            let osmLayer = MLNRasterStyleLayer(identifier: "osm-layer", source: osmSource)
            osmLayer.isVisible = !isSatellite
            style.insertLayer(osmLayer, above: style.layer(withIdentifier: "satellite-layer")!)
        }
        
        // 3. Dynamic Cadastral Parcels Source (4K GEO WGS84 GeoJSON)
        if style.source(withIdentifier: "cadastral-parcels-source") == nil {
            let parcelSource = MLNShapeSource(identifier: "cadastral-parcels-source", shape: cadastralShape, options: nil)
            style.addSource(parcelSource)
            
            // Parcel Fill
            let fillLayer = MLNFillStyleLayer(identifier: "parcel-fill", source: parcelSource)
            fillLayer.fillColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.06))
            fillLayer.minimumZoomLevel = 10.0
            fillLayer.isVisible = showParcels
            style.addLayer(fillLayer)
            
            // Parcel Outline
            let outlineLayer = MLNLineStyleLayer(identifier: "parcel-outline", source: parcelSource)
            outlineLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 0.65))
            outlineLayer.lineWidth = NSExpression(forConstantValue: 1.0)
            outlineLayer.minimumZoomLevel = 10.0
            outlineLayer.isVisible = showParcels
            style.addLayer(outlineLayer)
            
            // Parcel Labels (using exact verbatim revenue_plot)
            let labelLayer = MLNSymbolStyleLayer(identifier: "parcel-labels", source: parcelSource)
            labelLayer.text = NSExpression(forKeyPath: "revenue_plot")
            labelLayer.textColor = NSExpression(forConstantValue: UIColor.white)
            labelLayer.textFontSize = NSExpression(forConstantValue: 11)
            labelLayer.textHaloWidth = NSExpression(forConstantValue: 1.2)
            labelLayer.textHaloColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.75))
            labelLayer.minimumZoomLevel = 12.0
            labelLayer.isVisible = showParcels
            style.addLayer(labelLayer)
            
            // 4. Dedicated Single-Parcel Highlight Source
            let highlightSource = MLNShapeSource(identifier: "selected-parcel-source", shape: nil, options: nil)
            style.addSource(highlightSource)
            
            let highlightFill = MLNFillStyleLayer(identifier: "parcel-highlight-fill", source: highlightSource)
            highlightFill.fillColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 0.22))
            highlightFill.isVisible = false
            style.addLayer(highlightFill)
            
            let highlightLayer = MLNLineStyleLayer(identifier: "parcel-highlight", source: highlightSource)
            highlightLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 0.95))
            highlightLayer.lineWidth = NSExpression(forConstantValue: 3.0)
            highlightLayer.isVisible = false
            style.addLayer(highlightLayer)
        }
    }
}
