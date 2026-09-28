import UIKit
import MapLibre
import CoreLocation

// ============================================================
// MARK: - GIS EXPLORER MAP COORDINATOR
// ============================================================

public final class GISExplorerMapCoordinator: NSObject {
    public static let shared = GISExplorerMapCoordinator()
    
    // Identifiers for MapLibre Layer Pipeline
    public static let districtsSourceID = "gis-districts-source"
    public static let districtsFillLayerID = "gis-districts-fill"
    public static let districtsOutlineLayerID = "gis-districts-outline"
    public static let districtsHighlightLayerID = "gis-districts-highlight"
    public static let districtsLabelsLayerID = "gis-districts-labels"
    
    public static let tahasilsSourceID = "gis-tahasils-source"
    public static let tahasilsFillLayerID = "gis-tahasils-fill"
    public static let tahasilsOutlineLayerID = "gis-tahasils-outline"
    public static let tahasilsHighlightLayerID = "gis-tahasils-highlight"
    public static let tahasilsLabelsLayerID = "gis-tahasils-labels"
    
    // Bhumitra Purple #7600FF
    public static let bhumitraPurple = UIColor(red: 118/255, green: 0/255, blue: 255/255, alpha: 1.0)
    
    public override init() {
        super.init()
    }
    
    // MARK: - Layer Setup
    
    public func setupDistrictLayers(on mapView: MLNMapView, shape: MLNShape?) {
        guard let style = mapView.style else { return }
        
        // 1. Districts Shape Source
        var source = style.source(withIdentifier: Self.districtsSourceID) as? MLNShapeSource
        if source == nil {
            let newSource = MLNShapeSource(identifier: Self.districtsSourceID, shape: shape, options: nil)
            style.addSource(newSource)
            source = newSource
        } else if source?.shape !== shape {
            source?.shape = shape
        }
        
        guard let shapeSource = source else { return }
        
        // 2. District Fill Layer (High-contrast subtle white translucent fill)
        if style.layer(withIdentifier: Self.districtsFillLayerID) == nil {
            let fillLayer = MLNFillStyleLayer(identifier: Self.districtsFillLayerID, source: shapeSource)
            fillLayer.fillColor = NSExpression(forConstantValue: GISVisualTheme.whiteVectorFill)
            fillLayer.fillOpacity = NSExpression(forConstantValue: 1.0)
            fillLayer.maximumZoomLevel = 12.5
            
            // Insert below parcel layers or labels
            if let parcelFill = style.layer(withIdentifier: "parcel-fill") {
                style.insertLayer(fillLayer, below: parcelFill)
            } else {
                style.addLayer(fillLayer)
            }
        }
        
        // 3. District Outline Layer (Crisp, high-contrast white boundary lines across Odisha)
        if style.layer(withIdentifier: Self.districtsOutlineLayerID) == nil {
            let outlineLayer = MLNLineStyleLayer(identifier: Self.districtsOutlineLayerID, source: shapeSource)
            outlineLayer.lineColor = NSExpression(forConstantValue: GISVisualTheme.whiteVectorStroke)
            outlineLayer.lineWidth = NSExpression(forConstantValue: 1.4)
            outlineLayer.lineBlur = NSExpression(forConstantValue: 0.1)
            outlineLayer.maximumZoomLevel = 12.5
            
            if let fill = style.layer(withIdentifier: Self.districtsFillLayerID) {
                style.insertLayer(outlineLayer, above: fill)
            } else {
                style.addLayer(outlineLayer)
            }
        }
        
        // 4. District Highlight Layer (Luminous selected district outline in bright white)
        if style.layer(withIdentifier: Self.districtsHighlightLayerID) == nil {
            let highlightLayer = MLNLineStyleLayer(identifier: Self.districtsHighlightLayerID, source: shapeSource)
            highlightLayer.lineColor = NSExpression(forConstantValue: GISVisualTheme.selectedWhiteStroke)
            highlightLayer.lineWidth = NSExpression(forConstantValue: 3.4)
            highlightLayer.lineCap = NSExpression(forConstantValue: "round")
            highlightLayer.lineJoin = NSExpression(forConstantValue: "round")
            highlightLayer.maximumZoomLevel = 13.0
            highlightLayer.isVisible = false
            
            if let outline = style.layer(withIdentifier: Self.districtsOutlineLayerID) {
                style.insertLayer(highlightLayer, above: outline)
            } else {
                style.addLayer(highlightLayer)
            }
        }
        
        // 5. District Name Labels (Crisp white text with high-contrast dark halo)
        if style.layer(withIdentifier: Self.districtsLabelsLayerID) == nil {
            let labelLayer = MLNSymbolStyleLayer(identifier: Self.districtsLabelsLayerID, source: shapeSource)
            labelLayer.text = NSExpression(forKeyPath: "district_name")
            labelLayer.textColor = NSExpression(forConstantValue: GISVisualTheme.labelWhiteText)
            labelLayer.textFontSize = NSExpression(forConstantValue: 13.0)
            labelLayer.textHaloWidth = NSExpression(forConstantValue: 2.2)
            labelLayer.textHaloColor = NSExpression(forConstantValue: GISVisualTheme.labelDarkHalo)
            labelLayer.textAllowsOverlap = NSExpression(forConstantValue: false)
            labelLayer.textIgnoresPlacement = NSExpression(forConstantValue: false)
            labelLayer.maximumZoomLevel = 11.5
            
            if let highlight = style.layer(withIdentifier: Self.districtsHighlightLayerID) {
                style.insertLayer(labelLayer, above: highlight)
            } else {
                style.addLayer(labelLayer)
            }
        }
    }
    
    // MARK: - Dynamic Selection Updates (District Level Hierarchy)
    
    public func updateSelectedDistrict(on mapView: MLNMapView, districtID: String?, isExplorerActive: Bool) {
        guard let style = mapView.style else { return }
        
        let fill = style.layer(withIdentifier: Self.districtsFillLayerID) as? MLNFillStyleLayer
        let outline = style.layer(withIdentifier: Self.districtsOutlineLayerID) as? MLNLineStyleLayer
        let highlight = style.layer(withIdentifier: Self.districtsHighlightLayerID) as? MLNLineStyleLayer
        let labels = style.layer(withIdentifier: Self.districtsLabelsLayerID) as? MLNSymbolStyleLayer
        
        // Hide all district layers if explorer is inactive
        fill?.isVisible = isExplorerActive
        outline?.isVisible = isExplorerActive
        labels?.isVisible = isExplorerActive
        
        guard isExplorerActive else {
            highlight?.isVisible = false
            return
        }
        
        if let dID = districtID, !dID.isEmpty {
            // Selected district becomes the primary luminous focus; other 29 districts are substantially muted
            let isSelected = NSPredicate(format: "district_id == %@ OR id == %@", dID, dID)
            
            highlight?.isVisible = true
            highlight?.predicate = isSelected
            highlight?.lineColor = NSExpression(forConstantValue: GISVisualTheme.selectedWhiteStroke)
            highlight?.lineWidth = NSExpression(forConstantValue: 3.4)
            
            // Selected district retains luminous translucent white fill; other district fills become nearly invisible
            fill?.fillColor = NSExpression(
                forMLNConditional: isSelected,
                trueExpression: NSExpression(forConstantValue: GISVisualTheme.selectedWhiteFill),
                falseExpression: NSExpression(forConstantValue: GISVisualTheme.mutedWhiteFill)
            )
            fill?.fillOpacity = NSExpression(forConstantValue: 1.0)
            
            // Selected outline is prominent; other district outlines become faint, thin white lines (0.6pt)
            outline?.lineColor = NSExpression(
                forMLNConditional: isSelected,
                trueExpression: NSExpression(forConstantValue: GISVisualTheme.selectedWhiteStroke),
                falseExpression: NSExpression(forConstantValue: GISVisualTheme.mutedWhiteStroke)
            )
            outline?.lineWidth = NSExpression(
                forMLNConditional: isSelected,
                trueExpression: NSExpression(forConstantValue: 2.4),
                falseExpression: NSExpression(forConstantValue: 0.6)
            )
            
            // Focus label strictly on the selected district to eliminate clutter
            labels?.predicate = isSelected
            labels?.isVisible = true
        } else {
            // At state level: all 30 districts visible with crisp, high-contrast white vector borders & labels
            highlight?.isVisible = false
            highlight?.predicate = nil
            
            fill?.fillColor = NSExpression(forConstantValue: GISVisualTheme.whiteVectorFill)
            fill?.fillOpacity = NSExpression(forConstantValue: 1.0)
            
            outline?.lineColor = NSExpression(forConstantValue: GISVisualTheme.whiteVectorStroke)
            outline?.lineWidth = NSExpression(forConstantValue: 1.4)
            
            labels?.isVisible = true
            labels?.predicate = nil
        }
    }
    
    // MARK: - Tahasil Layers Setup
    
    public func setupTahasilLayers(
        on mapView: MLNMapView,
        shape: MLNShape?,
        selectedTahasilID: String?,
        isExplorerActive: Bool,
        isVillageLevel: Bool = false
    ) {
        guard let style = mapView.style else { return }
        
        // When village level is active (parcels dominant) or explorer inactive, remove Tahasil layers
        guard isExplorerActive, !isVillageLevel, let shape = shape else {
            removeTahasilLayers(on: mapView)
            return
        }
        
        // 1. Tahasils Source
        var source = style.source(withIdentifier: Self.tahasilsSourceID) as? MLNShapeSource
        if source == nil {
            let newSource = MLNShapeSource(identifier: Self.tahasilsSourceID, shape: shape, options: nil)
            style.addSource(newSource)
            source = newSource
        } else if source?.shape !== shape {
            source?.shape = shape
        }
        
        guard let shapeSource = source else { return }
        
        // 2. Tahasil Fill Layer (Subtle translucent white fill inside district)
        if style.layer(withIdentifier: Self.tahasilsFillLayerID) == nil {
            let fillLayer = MLNFillStyleLayer(identifier: Self.tahasilsFillLayerID, source: shapeSource)
            fillLayer.fillColor = NSExpression(forConstantValue: GISVisualTheme.tahasilWhiteFill)
            fillLayer.fillOpacity = NSExpression(forConstantValue: 1.0)
            fillLayer.maximumZoomLevel = 15.5
            
            if let districtOutline = style.layer(withIdentifier: Self.districtsOutlineLayerID) {
                style.insertLayer(fillLayer, above: districtOutline)
            } else {
                style.addLayer(fillLayer)
            }
        }
        
        // 3. Tahasil Outline Layer (Crisp white boundary lines for each Tahasil)
        if style.layer(withIdentifier: Self.tahasilsOutlineLayerID) == nil {
            let outlineLayer = MLNLineStyleLayer(identifier: Self.tahasilsOutlineLayerID, source: shapeSource)
            outlineLayer.lineColor = NSExpression(forConstantValue: GISVisualTheme.tahasilWhiteStroke)
            outlineLayer.lineWidth = NSExpression(forConstantValue: 1.3)
            outlineLayer.lineBlur = NSExpression(forConstantValue: 0.1)
            outlineLayer.maximumZoomLevel = 15.5
            
            if let fill = style.layer(withIdentifier: Self.tahasilsFillLayerID) {
                style.insertLayer(outlineLayer, above: fill)
            } else {
                style.addLayer(outlineLayer)
            }
        }
        
        // 4. Tahasil Highlight Layer (Selected Tahasil boundary in bright luminous white)
        if style.layer(withIdentifier: Self.tahasilsHighlightLayerID) == nil {
            let highlightLayer = MLNLineStyleLayer(identifier: Self.tahasilsHighlightLayerID, source: shapeSource)
            highlightLayer.lineColor = NSExpression(forConstantValue: GISVisualTheme.selectedWhiteStroke)
            highlightLayer.lineWidth = NSExpression(forConstantValue: 3.2)
            highlightLayer.lineCap = NSExpression(forConstantValue: "round")
            highlightLayer.lineJoin = NSExpression(forConstantValue: "round")
            highlightLayer.maximumZoomLevel = 16.0
            highlightLayer.isVisible = false
            
            if let outline = style.layer(withIdentifier: Self.tahasilsOutlineLayerID) {
                style.insertLayer(highlightLayer, above: outline)
            } else {
                style.addLayer(highlightLayer)
            }
        }
        
        // 5. Tahasil Labels (Prominently showing Tahasil names in white with dark halo)
        if style.layer(withIdentifier: Self.tahasilsLabelsLayerID) == nil {
            let labelLayer = MLNSymbolStyleLayer(identifier: Self.tahasilsLabelsLayerID, source: shapeSource)
            labelLayer.text = NSExpression(forKeyPath: "tahasil_name")
            labelLayer.textColor = NSExpression(forConstantValue: GISVisualTheme.labelWhiteText)
            labelLayer.textFontSize = NSExpression(forConstantValue: 12.5)
            labelLayer.textHaloWidth = NSExpression(forConstantValue: 2.0)
            labelLayer.textHaloColor = NSExpression(forConstantValue: GISVisualTheme.labelDarkHalo)
            labelLayer.textAllowsOverlap = NSExpression(forConstantValue: false)
            labelLayer.textIgnoresPlacement = NSExpression(forConstantValue: false)
            labelLayer.minimumZoomLevel = 8.5
            labelLayer.maximumZoomLevel = 15.0
            
            if let highlight = style.layer(withIdentifier: Self.tahasilsHighlightLayerID) {
                style.insertLayer(labelLayer, above: highlight)
            } else {
                style.addLayer(labelLayer)
            }
        }
        
        // Update selection & de-emphasis
        if let tID = selectedTahasilID, !tID.isEmpty {
            let isSelected = NSPredicate(format: "tahasil_id == %@ OR id == %@", tID, tID)
            
            // Highlight selected Tahasil
            if let highlight = style.layer(withIdentifier: Self.tahasilsHighlightLayerID) as? MLNLineStyleLayer {
                highlight.isVisible = true
                highlight.predicate = isSelected
                highlight.lineColor = NSExpression(forConstantValue: GISVisualTheme.selectedWhiteStroke)
                highlight.lineWidth = NSExpression(forConstantValue: 3.2)
            }
            
            // Selected Tahasil gets translucent white fill (0.20); sibling Tahasils muted (0.01)
            if let fillLayer = style.layer(withIdentifier: Self.tahasilsFillLayerID) as? MLNFillStyleLayer {
                fillLayer.fillColor = NSExpression(
                    forMLNConditional: isSelected,
                    trueExpression: NSExpression(forConstantValue: GISVisualTheme.selectedWhiteFill),
                    falseExpression: NSExpression(forConstantValue: GISVisualTheme.mutedWhiteFill)
                )
                fillLayer.fillOpacity = NSExpression(forConstantValue: 1.0)
            }
            
            // De-emphasize sibling Tahasils with faint white borders (0.6pt)
            if let outlineLayer = style.layer(withIdentifier: Self.tahasilsOutlineLayerID) as? MLNLineStyleLayer {
                outlineLayer.lineColor = NSExpression(
                    forMLNConditional: isSelected,
                    trueExpression: NSExpression(forConstantValue: GISVisualTheme.selectedWhiteStroke),
                    falseExpression: NSExpression(forConstantValue: GISVisualTheme.mutedWhiteStroke)
                )
                outlineLayer.lineWidth = NSExpression(
                    forMLNConditional: isSelected,
                    trueExpression: NSExpression(forConstantValue: 2.2),
                    falseExpression: NSExpression(forConstantValue: 0.6)
                )
            }
            
            // Focus label strictly on the selected Tahasil
            if let labelLayer = style.layer(withIdentifier: Self.tahasilsLabelsLayerID) as? MLNSymbolStyleLayer {
                labelLayer.predicate = isSelected
            }
        } else {
            // All Tahasils within district active with crisp white borders & labels
            if let highlight = style.layer(withIdentifier: Self.tahasilsHighlightLayerID) as? MLNLineStyleLayer {
                highlight.isVisible = false
                highlight.predicate = nil
            }
            if let fillLayer = style.layer(withIdentifier: Self.tahasilsFillLayerID) as? MLNFillStyleLayer {
                fillLayer.fillColor = NSExpression(forConstantValue: GISVisualTheme.tahasilWhiteFill)
                fillLayer.fillOpacity = NSExpression(forConstantValue: 1.0)
            }
            if let outlineLayer = style.layer(withIdentifier: Self.tahasilsOutlineLayerID) as? MLNLineStyleLayer {
                outlineLayer.lineColor = NSExpression(forConstantValue: GISVisualTheme.tahasilWhiteStroke)
                outlineLayer.lineWidth = NSExpression(forConstantValue: 1.3)
            }
            if let labelLayer = style.layer(withIdentifier: Self.tahasilsLabelsLayerID) as? MLNSymbolStyleLayer {
                labelLayer.predicate = nil
            }
        }
    }
    
    public func removeTahasilLayers(on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        
        let layerIDs = [
            Self.tahasilsLabelsLayerID,
            Self.tahasilsHighlightLayerID,
            Self.tahasilsOutlineLayerID,
            Self.tahasilsFillLayerID
        ]
        for id in layerIDs {
            if let layer = style.layer(withIdentifier: id) {
                style.removeLayer(layer)
            }
        }
        if let source = style.source(withIdentifier: Self.tahasilsSourceID) {
            style.removeSource(source)
        }
    }
    
    // MARK: - Hierarchy-Specific Camera Control
    
    public func flyToDistrictBounds(mapView: MLNMapView, sw: CLLocationCoordinate2D, ne: CLLocationCoordinate2D) {
        let bounds = MLNCoordinateBounds(sw: sw, ne: ne)
        // Hierarchy-specific edge padding leaving clearance for top breadcrumb and floating bottom card
        let insets = UIEdgeInsets(top: 60, left: 16, bottom: 92, right: 16)
        
        if UIAccessibility.isReduceMotionEnabled {
            mapView.setVisibleCoordinateBounds(bounds, edgePadding: insets, animated: false, completionHandler: nil)
        } else {
            let camera = mapView.cameraThatFitsCoordinateBounds(bounds, edgePadding: insets)
            mapView.setCamera(camera, animated: true)
        }
    }
    
    public func flyToTahasilBounds(mapView: MLNMapView, sw: CLLocationCoordinate2D, ne: CLLocationCoordinate2D) {
        let bounds = MLNCoordinateBounds(sw: sw, ne: ne)
        let insets = UIEdgeInsets(top: 64, left: 18, bottom: 98, right: 18)
        
        if UIAccessibility.isReduceMotionEnabled {
            mapView.setVisibleCoordinateBounds(bounds, edgePadding: insets, animated: false, completionHandler: nil)
        } else {
            let camera = mapView.cameraThatFitsCoordinateBounds(bounds, edgePadding: insets)
            mapView.setCamera(camera, animated: true)
        }
    }
    
    public func flyToVillageExtent(mapView: MLNMapView, sw: CLLocationCoordinate2D, ne: CLLocationCoordinate2D) {
        let bounds = MLNCoordinateBounds(sw: sw, ne: ne)
        let insets = UIEdgeInsets(top: 70, left: 20, bottom: 104, right: 20)
        
        if UIAccessibility.isReduceMotionEnabled {
            mapView.setVisibleCoordinateBounds(bounds, edgePadding: insets, animated: false, completionHandler: nil)
        } else {
            let camera = mapView.cameraThatFitsCoordinateBounds(bounds, edgePadding: insets)
            mapView.setCamera(camera, animated: true)
        }
    }
    
    public func flyToCenter(mapView: MLNMapView, center: CLLocationCoordinate2D, zoom: Double) {
        if UIAccessibility.isReduceMotionEnabled {
            mapView.setCenter(center, zoomLevel: zoom, animated: false)
        } else {
            mapView.setCenter(center, zoomLevel: zoom, animated: true)
        }
    }
    
    // MARK: - District Polygon Tap Hit-Testing
    
    public func hitTestDistrict(at point: CGPoint, in mapView: MLNMapView) -> (id: String, name: String, bbox: [Double]?)? {
        let features = mapView.visibleFeatures(
            at: point,
            styleLayerIdentifiers: [Self.districtsFillLayerID, Self.districtsOutlineLayerID]
        )
        guard let first = features.first else { return nil }
        
        let distID = (first.attribute(forKey: "district_id") as? String) ?? (first.attribute(forKey: "id") as? String) ?? ""
        let distName = (first.attribute(forKey: "district_name") as? String) ?? ""
        let bbox = first.attribute(forKey: "bbox") as? [Double]
        
        guard !distID.isEmpty else { return nil }
        return (id: distID, name: distName, bbox: bbox)
    }
    
    // MARK: - Tahasil Polygon Tap Hit-Testing
    
    public func hitTestTahasil(at point: CGPoint, in mapView: MLNMapView) -> (id: String, name: String, bbox: [Double]?)? {
        let features = mapView.visibleFeatures(
            at: point,
            styleLayerIdentifiers: [Self.tahasilsFillLayerID, Self.tahasilsOutlineLayerID]
        )
        guard let first = features.first else { return nil }
        
        let tahasilID = (first.attribute(forKey: "tahasil_id") as? String) ?? (first.attribute(forKey: "id") as? String) ?? ""
        let tahasilName = (first.attribute(forKey: "tahasil_name") as? String) ?? ""
        let bbox = first.attribute(forKey: "bbox") as? [Double]
        
        guard !tahasilID.isEmpty else { return nil }
        return (id: tahasilID, name: tahasilName, bbox: bbox)
    }
}
