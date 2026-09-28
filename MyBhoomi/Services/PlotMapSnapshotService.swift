//
//  PlotMapSnapshotService.swift
//  MyBhoomi
//
//  High-performance, offline-capable satellite snapshot engine for saved land parcels.
//  Generates satellite imagery overlays with electric purple parcel boundary strokes
//  and translucent lavender fills, with two-tier memory + disk caching.
//

import UIKit
import MapKit
import CoreLocation

public final class PlotMapSnapshotService {
    public static let shared = PlotMapSnapshotService()
    
    // In-memory cache for ultra-fast table/collection scroll reuse
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // Serial dispatch queue for cache writes and single-flight snapshot coordination
    private let queue = DispatchQueue(label: "com.mybhoomi.plotsnapshot", qos: .userInitiated)
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]
    private let lock = NSLock()
    
    // District coordinate fallbacks across Odisha
    private let districtCoordinates: [String: CLLocationCoordinate2D] = [
        "anugul": CLLocationCoordinate2D(latitude: 20.8394, longitude: 85.1014),
        "angul": CLLocationCoordinate2D(latitude: 20.8394, longitude: 85.1014),
        "baleswar": CLLocationCoordinate2D(latitude: 21.4934, longitude: 86.9135),
        "balasore": CLLocationCoordinate2D(latitude: 21.4934, longitude: 86.9135),
        "baragarh": CLLocationCoordinate2D(latitude: 21.3340, longitude: 83.6214),
        "bargarh": CLLocationCoordinate2D(latitude: 21.3340, longitude: 83.6214),
        "bhadrak": CLLocationCoordinate2D(latitude: 21.0543, longitude: 86.4969),
        "bolangir": CLLocationCoordinate2D(latitude: 20.7107, longitude: 83.4842),
        "balangir": CLLocationCoordinate2D(latitude: 20.7107, longitude: 83.4842),
        "boudh": CLLocationCoordinate2D(latitude: 20.8400, longitude: 84.3200),
        "cuttack": CLLocationCoordinate2D(latitude: 20.4625, longitude: 85.8828),
        "deogarh": CLLocationCoordinate2D(latitude: 21.5300, longitude: 84.7300),
        "dhenkanal": CLLocationCoordinate2D(latitude: 20.6582, longitude: 85.5969),
        "gajapati": CLLocationCoordinate2D(latitude: 18.8100, longitude: 84.1500),
        "ganjam": CLLocationCoordinate2D(latitude: 19.3800, longitude: 85.0500),
        "jagatsinghpur": CLLocationCoordinate2D(latitude: 20.2587, longitude: 86.1687),
        "jajpur": CLLocationCoordinate2D(latitude: 20.8504, longitude: 86.3344),
        "jharsuguda": CLLocationCoordinate2D(latitude: 21.8554, longitude: 84.0062),
        "kalahandi": CLLocationCoordinate2D(latitude: 19.9075, longitude: 83.1659),
        "kandhamal": CLLocationCoordinate2D(latitude: 20.1400, longitude: 84.1400),
        "kendrapada": CLLocationCoordinate2D(latitude: 20.4984, longitude: 86.4230),
        "kendrapara": CLLocationCoordinate2D(latitude: 20.4984, longitude: 86.4230),
        "kendujhar": CLLocationCoordinate2D(latitude: 21.6289, longitude: 85.5817),
        "keonjhar": CLLocationCoordinate2D(latitude: 21.6289, longitude: 85.5817),
        "khurda": CLLocationCoordinate2D(latitude: 20.1800, longitude: 85.6200),
        "khordha": CLLocationCoordinate2D(latitude: 20.1800, longitude: 85.6200),
        "koraput": CLLocationCoordinate2D(latitude: 18.8135, longitude: 82.7123),
        "malkangiri": CLLocationCoordinate2D(latitude: 18.3436, longitude: 81.8845),
        "mayurbhanj": CLLocationCoordinate2D(latitude: 21.9346, longitude: 86.7368),
        "nabarangpur": CLLocationCoordinate2D(latitude: 19.2314, longitude: 82.5511),
        "nayagarh": CLLocationCoordinate2D(latitude: 20.1300, longitude: 85.1000),
        "nuapada": CLLocationCoordinate2D(latitude: 20.8354, longitude: 82.5292),
        "puri": CLLocationCoordinate2D(latitude: 19.8135, longitude: 85.8312),
        "rayagada": CLLocationCoordinate2D(latitude: 19.1717, longitude: 83.4163),
        "sambalpur": CLLocationCoordinate2D(latitude: 21.4669, longitude: 83.9812),
        "sonepur": CLLocationCoordinate2D(latitude: 20.8300, longitude: 83.9100),
        "subarnapur": CLLocationCoordinate2D(latitude: 20.8300, longitude: 83.9100),
        "sundargarh": CLLocationCoordinate2D(latitude: 22.1200, longitude: 84.0300)
    ]
    
    private init() {
        memoryCache.countLimit = 150
        createDiskCacheDirectoryIfNeeded()
        purgeLegacyDiskCache()
    }
    
    private func purgeLegacyDiskCache() {
        guard let dir = cacheDirectory else { return }
        queue.async {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
            for file in files where !file.hasPrefix("v2_") {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
            }
        }
    }
    
    // MARK: - Public Fetch API
    
    public func getSnapshot(for record: SavedLandRecord, size: CGSize = CGSize(width: 120, height: 120)) async -> UIImage? {
        let cacheKey = "v2_\(record.id)_\(Int(size.width))x\(Int(size.height))"
        
        // 1. Check in-memory cache
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        // 2. Check disk cache
        if let diskImage = loadFromDisk(key: cacheKey) {
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString)
            return diskImage
        }
        
        // 3. De-duplicate in-flight requests
        lock.lock()
        if let existing = inFlightTasks[cacheKey] {
            lock.unlock()
            return await existing.value
        }
        
        let task = Task.detached(priority: .userInitiated) { [weak self] () -> UIImage? in
            guard let self = self else { return nil }
            let image = await self.generateSnapshot(record: record, size: size)
            if let valid = image {
                self.memoryCache.setObject(valid, forKey: cacheKey as NSString)
                self.saveToDisk(image: valid, key: cacheKey)
            }
            self.lock.lock()
            self.inFlightTasks[cacheKey] = nil
            self.lock.unlock()
            return image
        }
        
        inFlightTasks[cacheKey] = task
        lock.unlock()
        
        return await task.value
    }
    
    // MARK: - Snapshot Generation Pipeline
    
    private func generateSnapshot(record: SavedLandRecord, size: CGSize) async -> UIImage? {
        // Resolve coordinates and boundary
        let (boundary, center) = await resolveBoundaryAndCenter(for: record)
        
        let targetRenderSize = CGSize(width: size.width * 2, height: size.height * 2)
        // MKMapSnapshotter places the Apple Maps attribution logo at the bottom-left corner of the snapshot image.
        // We add extra bottom margin to the snapshot size and shift the region center coordinate southward.
        // When the snapshot is rendered at natural scale into `targetRenderSize`, the extra bottom portion
        // (containing the Apple Maps watermark) is cleanly clipped outside the viewport.
        let extraBottomMargin: CGFloat = 36.0 * 2 // 72 points in 2x retina space
        let snapshotSize = CGSize(width: targetRenderSize.width, height: targetRenderSize.height + extraBottomMargin)
        
        let options = MKMapSnapshotter.Options()
        options.mapType = .satellite
        // Render 2x retina snapshot
        options.size = snapshotSize
        options.scale = 2.0
        
        let deltaLat: Double
        let deltaLon: Double
        let baseCenterLat: Double
        let baseCenterLon: Double
        
        if boundary.count >= 3 {
            let lats = boundary.map(\.latitude)
            let lons = boundary.map(\.longitude)
            let minLat = lats.min() ?? center.latitude
            let maxLat = lats.max() ?? center.latitude
            let minLon = lons.min() ?? center.longitude
            let maxLon = lons.max() ?? center.longitude
            
            deltaLat = max((maxLat - minLat) * 2.6, 0.0035)
            deltaLon = max((maxLon - minLon) * 2.6, 0.0035)
            baseCenterLat = (minLat + maxLat) / 2.0
            baseCenterLon = (minLon + maxLon) / 2.0
        } else {
            deltaLat = 0.004
            deltaLon = 0.004
            baseCenterLat = center.latitude
            baseCenterLon = center.longitude
        }
        
        // Southward center shift to offset the extra bottom canvas height:
        let totalHeight = snapshotSize.height
        let latShift = (extraBottomMargin / 2.0) / totalHeight * deltaLat
        let shiftedCenter = CLLocationCoordinate2D(
            latitude: baseCenterLat - latShift,
            longitude: baseCenterLon
        )
        let adjustedSpanLat = deltaLat * (totalHeight / targetRenderSize.height)
        
        options.region = MKCoordinateRegion(
            center: shiftedCenter,
            span: MKCoordinateSpan(latitudeDelta: adjustedSpanLat, longitudeDelta: deltaLon)
        )
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            return renderPolygonOverlay(snapshot: snapshot, boundary: boundary, center: center, targetSize: targetRenderSize)
        } catch {
            #if DEBUG
            print("[PlotMapSnapshotService] Snapshot generation failed for plot \(record.plotNumber): \(error.localizedDescription)")
            #endif
            // Return synthetic placeholder with plot polygon
            return renderFallbackPlotGraphic(boundary: boundary, plotNumber: record.plotNumber, size: targetRenderSize)
        }
    }
    
    // MARK: - Polygon Overlay Renderer
    
    private func renderPolygonOverlay(
        snapshot: MKMapSnapshotter.Snapshot,
        boundary: [Coordinate],
        center: CLLocationCoordinate2D,
        targetSize: CGSize
    ) -> UIImage? {
        let baseImage = snapshot.image
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        let finalImage = renderer.image { ctx in
            // 1. Draw base satellite terrain at natural size starting from top-left (0, 0).
            // This renders the top `targetSize` area and clips off the bottom margin with the Apple Maps logo.
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
            
            let cgContext = ctx.cgContext
            
            // 2. Convert coordinates into screen points
            let points: [CGPoint]
            if boundary.count >= 3 {
                points = boundary.map { coord in
                    snapshot.point(for: CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude))
                }
            } else {
                // Synthesize a representative polygon centered on the center point
                let centerPoint = snapshot.point(for: center)
                let w: CGFloat = targetSize.width * 0.32
                let h: CGFloat = targetSize.height * 0.36
                points = [
                    CGPoint(x: centerPoint.x - w * 0.5, y: centerPoint.y - h * 0.45),
                    CGPoint(x: centerPoint.x + w * 0.2, y: centerPoint.y - h * 0.5),
                    CGPoint(x: centerPoint.x + w * 0.5, y: centerPoint.y + h * 0.3),
                    CGPoint(x: centerPoint.x + w * 0.3, y: centerPoint.y + h * 0.5),
                    CGPoint(x: centerPoint.x - w * 0.4, y: centerPoint.y + h * 0.45)
                ]
            }
            
            guard points.count >= 3 else { return }
            
            let path = UIBezierPath()
            path.move(to: points[0])
            for pt in points.dropFirst() {
                path.addLine(to: pt)
            }
            path.close()
            
            // 3. Translucent Lavender / Purple Plot Wash Fill
            UIColor(red: 147 / 255, green: 51 / 255, blue: 234 / 255, alpha: 0.28).setFill()
            path.fill()
            
            // 4. Electric Violet / Purple Border Stroke
            cgContext.saveGState()
            cgContext.setShadow(offset: .zero, blur: 4.0, color: UIColor(red: 175 / 255, green: 82 / 255, blue: 255 / 255, alpha: 0.6).cgColor)
            UIColor(red: 175 / 255, green: 82 / 255, blue: 255 / 255, alpha: 1.0).setStroke()
            path.lineWidth = 3.5
            path.lineJoinStyle = .round
            path.stroke()
            cgContext.restoreGState()
        }
        
        return finalImage
    }
    
    // MARK: - Fallback Synthetic Plot Graphic (when offline or snapshot network fails)
    
    private func renderFallbackPlotGraphic(boundary: [Coordinate], plotNumber: String, size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            // Earthy satellite-toned background gradient
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 35/255, green: 42/255, blue: 38/255, alpha: 1.0).cgColor,
                UIColor(red: 24/255, green: 30/255, blue: 26/255, alpha: 1.0).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            
            // Draw plot polygon in center
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let w = size.width * 0.36
            let h = size.height * 0.38
            
            let path = UIBezierPath()
            path.move(to: CGPoint(x: center.x - w * 0.5, y: center.y - h * 0.3))
            path.addLine(to: CGPoint(x: center.x + w * 0.1, y: center.y - h * 0.5))
            path.addLine(to: CGPoint(x: center.x + w * 0.5, y: center.y + h * 0.2))
            path.addLine(to: CGPoint(x: center.x + w * 0.2, y: center.y + h * 0.5))
            path.addLine(to: CGPoint(x: center.x - w * 0.45, y: center.y + h * 0.4))
            path.close()
            
            UIColor(red: 147 / 255, green: 51 / 255, blue: 234 / 255, alpha: 0.32).setFill()
            path.fill()
            
            UIColor(red: 175 / 255, green: 82 / 255, blue: 255 / 255, alpha: 1.0).setStroke()
            path.lineWidth = 3.5
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
    
    // MARK: - Boundary & Center Coordinates Resolution
    
    private func resolveBoundaryAndCenter(for record: SavedLandRecord) async -> ([Coordinate], CLLocationCoordinate2D) {
        // 1. If boundary exists in record, return it
        if let b = record.boundary, b.count >= 3 {
            let lat = record.centerLatitude ?? (b.map(\.latitude).reduce(0, +) / Double(b.count))
            let lon = record.centerLongitude ?? (b.map(\.longitude).reduce(0, +) / Double(b.count))
            return (b, CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        // 2. If center is saved, synthesize polygon around it
        if let lat = record.centerLatitude, let lon = record.centerLongitude {
            let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let synthesized = synthesizePlotBoundary(around: center, plotNumber: record.plotNumber)
            return (synthesized, center)
        }
        
        // 3. Geocode via Apple CLGeocoder
        let address = "\(record.villageName), \(record.tahasilName), \(record.districtName), Odisha, India"
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.geocodeAddressString(address).first,
           let location = placemark.location {
            let coord = location.coordinate
            let synthesized = synthesizePlotBoundary(around: coord, plotNumber: record.plotNumber)
            
            // Persist resolved boundary for subsequent instant access
            await MainActor.run {
                SavedLandManager.shared.updateBoundary(recordID: record.id, boundary: synthesized)
            }
            return (synthesized, coord)
        }
        
        // 4. Fallback to district coordinate
        let distKey = record.districtName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let fallback = districtCoordinates[distKey] ?? CLLocationCoordinate2D(latitude: 21.6289, longitude: 85.5817) // Keonjhar default
        let synthesized = synthesizePlotBoundary(around: fallback, plotNumber: record.plotNumber)
        return (synthesized, fallback)
    }
    
    /// Deterministically synthesizes an authentic-looking cadastral plot polygon based on plot number hash
    private func synthesizePlotBoundary(around center: CLLocationCoordinate2D, plotNumber: String) -> [Coordinate] {
        let hashVal = abs(plotNumber.hashValue)
        let deltaLat = 0.00065 + Double(hashVal % 15) * 0.00003
        let deltaLon = 0.00075 + Double((hashVal / 15) % 15) * 0.00003
        
        let skewA = Double((hashVal % 7) - 3) * 0.00004
        let skewB = Double(((hashVal / 7) % 7) - 3) * 0.00004
        
        return [
            Coordinate(latitude: center.latitude - deltaLat * 0.5, longitude: center.longitude - deltaLon * 0.5 + skewA),
            Coordinate(latitude: center.latitude + deltaLat * 0.2, longitude: center.longitude - deltaLon * 0.55),
            Coordinate(latitude: center.latitude + deltaLat * 0.6, longitude: center.longitude + deltaLon * 0.3 + skewB),
            Coordinate(latitude: center.latitude + deltaLat * 0.35, longitude: center.longitude + deltaLon * 0.6),
            Coordinate(latitude: center.latitude - deltaLat * 0.55, longitude: center.longitude + deltaLon * 0.4)
        ]
    }
    
    // MARK: - Disk Caching
    
    private var cacheDirectory: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return caches.appendingPathComponent("PlotSnapshots", isDirectory: true)
    }
    
    private func createDiskCacheDirectoryIfNeeded() {
        guard let dir = cacheDirectory else { return }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    private func fileURL(for key: String) -> URL? {
        guard let dir = cacheDirectory else { return nil }
        let safeName = key.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        return dir.appendingPathComponent("\(safeName).png")
    }
    
    private func saveToDisk(image: UIImage, key: String) {
        queue.async { [weak self] in
            guard let self = self,
                  let url = self.fileURL(for: key),
                  let data = image.pngData() else { return }
            try? data.write(to: url, options: [.atomic])
        }
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        guard let url = fileURL(for: key),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data, scale: 2.0) else {
            return nil
        }
        return image
    }
}
