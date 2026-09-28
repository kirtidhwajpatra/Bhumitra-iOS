//
//  UPMapService.swift
//  MyBhoomi
//
//  Uttar Pradesh map-layer prototype. Talks only to our backend
//  (/api/v1/gis/up/*), never to the UP portal directly. Fully separate from
//  the Odisha cadastral pipeline.
//

import Foundation
import CoreLocation
import UIKit

// MARK: - Feature gate

public enum UPFeature {
    /// Debug-only local override so the prototype can be tested on a device
    /// while the server flag stays off for App Store users.
    public static let debugOverrideKey = "bhumitra_up_map_debug_override"

    @MainActor
    public static var isAvailable: Bool {
        if RemoteConfigManager.shared.isUPMapEnabled { return true }
        #if DEBUG
        // Explicit opt-in only: the Xcode scheme sets this for the prototype build.
        let env = ProcessInfo.processInfo.environment["BHUMITRA_UP_MAP_PROTOTYPE"]
        return env == "1" || env == "true" || UserDefaults.standard.bool(forKey: debugOverrideKey)
        #else
        return false
        #endif
    }

    public static let officialRecordURL = URL(string: "https://upbhulekh.gov.in/")!
}

// MARK: - Models

public struct UPLevelItem: Codable, Identifiable, Hashable, Sendable {
    public let code: String
    public let name: String
    public var id: String { code }
}

struct UPLevelResponse: Codable {
    let level: Int
    let items: [UPLevelItem]
    let label: String?
}

public struct UPVillageExtent: Codable, Equatable, Sendable {
    public let gisCode: String
    public let districtCode: String
    public let tehsilCode: String
    public let villageCode: String
    public let crs: String
    /// [minLng, minLat, maxLng, maxLat]
    public let bbox: [Double]
    public let centerLat: Double
    public let centerLng: Double

    enum CodingKeys: String, CodingKey {
        case gisCode = "gis_code"
        case districtCode = "district_code"
        case tehsilCode = "tehsil_code"
        case villageCode = "village_code"
        case crs, bbox
        case centerLat = "center_lat"
        case centerLng = "center_lng"
    }
}

public struct UPPlotRecord: Codable, Hashable, Sendable {
    public let khataNo: String
    public let plotNo: String
    public let area: Double?
    public let areaUnit: String?

    enum CodingKeys: String, CodingKey {
        case khataNo = "khata_no"
        case plotNo = "plot_no"
        case area
        case areaUnit = "area_unit"
    }
}

public struct UPPlotResult: Codable, Equatable, Identifiable, Sendable {
    public let gisCode: String
    public let plotNo: String
    public let plotId: String?
    /// [minLng, minLat, maxLng, maxLat]
    public let bbox: [Double]
    public let records: [UPPlotRecord]
    /// Short-lived signed token for the official exact-plot highlight tiles.
    public let selectionToken: String?
    public let officialRecordUrl: String?
    public let note: String?

    public var id: String { "\(gisCode)#\(plotNo)#\(plotId ?? "")" }

    public init(gisCode: String, plotNo: String, plotId: String?, bbox: [Double],
                records: [UPPlotRecord] = [], selectionToken: String? = nil,
                officialRecordUrl: String? = nil, note: String? = nil) {
        self.gisCode = gisCode
        self.plotNo = plotNo
        self.plotId = plotId
        self.bbox = bbox
        self.records = records
        self.selectionToken = selectionToken
        self.officialRecordUrl = officialRecordUrl
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case gisCode = "gis_code"
        case plotNo = "plot_no"
        case plotId = "plot_id"
        case bbox, records
        case selectionToken = "selection_token"
        case officialRecordUrl = "official_record_url"
        case note
    }
}

/// The village the user is currently viewing in UP mode.
public struct UPVillageSession: Equatable, Sendable {
    public let extent: UPVillageExtent
    public let districtName: String
    public let tehsilName: String
    public let villageName: String

    public var gisCode: String { extent.gisCode }
    public var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: extent.centerLat, longitude: extent.centerLng)
    }

    /// Zoom that roughly fits the village on a phone screen.
    public var fittingZoom: Double {
        guard extent.bbox.count == 4 else { return 15 }
        let span = max(extent.bbox[2] - extent.bbox[0], extent.bbox[3] - extent.bbox[1])
        guard span > 0 else { return 15 }
        // ~360° at z0 across 256pt; aim for the village to fill ~80% of ~390pt width.
        let z = log2(360.0 * 390.0 * 0.8 / (256.0 * span))
        return min(17.5, max(13.5, z))
    }
}

// MARK: - Viewport image request

/// One official border image for the current screen, rendered at 1 image pixel
/// per screen point. Tiles get stretched up to 2x between zoom levels, which
/// makes the borders look thick and thin; a per-viewport image keeps the line
/// width and plot-number size constant at every zoom.
public struct UPViewportRequest: Equatable, Sendable {
    /// [minX, minY, maxX, maxY] in EPSG:3857 metres.
    public let bbox: [Double]
    public let width: Int
    public let height: Int
    public let zoom: Double
    /// The bare on-screen area (no overscan margin), EPSG:3857.
    public let screenBBox: [Double]

    public static let minimumZoom: Double = 13
    static let maxSide: Double = 1600
    static let maxPixels: Double = 1_300_000
    private static let earthRadius = 6_378_137.0
    /// EPSG:3857 metres per screen point at zoom 0 (MapLibre's world is 512pt wide).
    private static let unitsPerPointAtZ0 = 2 * Double.pi * earthRadius / 512

    public static func make(center: CLLocationCoordinate2D, zoom: Double, bearingDegrees: Double,
                            viewSize: CGSize, overscan: Double = 1.5) -> UPViewportRequest? {
        guard zoom >= minimumZoom, zoom.isFinite, viewSize.width > 0, viewSize.height > 0,
              CLLocationCoordinate2DIsValid(center) else { return nil }
        // Axis-aligned box that still covers the screen when the map is rotated.
        let rad = bearingDegrees * .pi / 180
        let vw = Double(viewSize.width), vh = Double(viewSize.height)
        let w = abs(vw * cos(rad)) + abs(vh * sin(rad))
        let h = abs(vw * sin(rad)) + abs(vh * cos(rad))
        // Extra margin so small pans don't reveal an empty edge before the refresh.
        let factor = min(overscan, maxSide / w, maxSide / h, (maxPixels / (w * h)).squareRoot())
        let pw = max(64, min(Int(maxSide), Int((w * factor).rounded())))
        let ph = max(64, min(Int(maxSide), Int((h * factor).rounded())))
        let upp = unitsPerPointAtZ0 / pow(2, zoom)
        let (cx, cy) = mercator(center)
        let halfW = Double(pw) * upp / 2, halfH = Double(ph) * upp / 2
        let screenHalfW = w * upp / 2, screenHalfH = h * upp / 2
        return UPViewportRequest(bbox: [cx - halfW, cy - halfH, cx + halfW, cy + halfH],
                                 width: pw, height: ph, zoom: zoom,
                                 screenBBox: [cx - screenHalfW, cy - screenHalfH, cx + screenHalfW, cy + screenHalfH])
    }

    /// Top-left, bottom-left, bottom-right, top-right in WGS84.
    public var corners: (topLeft: CLLocationCoordinate2D, bottomLeft: CLLocationCoordinate2D,
                         bottomRight: CLLocationCoordinate2D, topRight: CLLocationCoordinate2D) {
        (Self.coordinate(bbox[0], bbox[3]), Self.coordinate(bbox[0], bbox[1]),
         Self.coordinate(bbox[2], bbox[1]), Self.coordinate(bbox[2], bbox[3]))
    }

    /// True when this image already covers `other`'s on-screen area at the same zoom.
    public func covers(visibleAreaOf other: UPViewportRequest) -> Bool {
        guard abs(zoom - other.zoom) < 0.01 else { return false }
        let s = other.screenBBox
        return bbox[0] <= s[0] && bbox[1] <= s[1] && bbox[2] >= s[2] && bbox[3] >= s[3]
    }

    static func mercator(_ c: CLLocationCoordinate2D) -> (Double, Double) {
        let lat = max(-85.05112878, min(85.05112878, c.latitude))
        let x = earthRadius * c.longitude * .pi / 180
        let y = earthRadius * log(tan(.pi / 4 + lat * .pi / 360))
        return (x, y)
    }

    static func coordinate(_ x: Double, _ y: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (2 * atan(exp(y / earthRadius)) - .pi / 2) * 180 / .pi,
                               longitude: x / earthRadius * 180 / .pi)
    }
}

// MARK: - Errors

public enum UPMapError: LocalizedError, Equatable {
    case disabled
    case notFound(String)
    case upstream(String)
    case invalid(String)
    case network

    public var errorDescription: String? {
        switch self {
        case .disabled: return "Uttar Pradesh map view is turned off right now."
        case .notFound(let m), .upstream(let m), .invalid(let m): return m
        case .network: return "Couldn't reach the server. Check your connection and try again."
        }
    }
}

private struct UPErrorBody: Decodable {
    let errorCode: String?
    let message: String?
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case message
    }
}

// MARK: - Service

public final class UPMapService: Sendable {
    public static let shared = UPMapService()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: cfg)
    }()

    private var base: String { APIConfiguration.shared.baseURL + "/gis/up" }

    /// Transparent official parcel borders + plot numbers. `{bbox-epsg-3857}`
    /// is filled in by MapLibre per tile. 256px per 256pt tile keeps plot
    /// numbers at the same on-screen size as the official web map.
    public func tileURLTemplate(gisCode: String) -> String {
        "\(base)/wms/base/\(gisCode)?bbox={bbox-epsg-3857}&size=256"
    }

    /// Official exact-plot highlight for one resolved plot. Returns nil when the
    /// server did not issue a selection token (e.g. plot without an upstream id).
    public func selectionTileURLTemplate(for plot: UPPlotResult) -> String? {
        guard let token = plot.selectionToken, !token.isEmpty,
              token.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }),
              token.unicodeScalars.allSatisfy({ $0.isASCII }) else { return nil }
        return "\(base)/wms/selection/\(token)?bbox={bbox-epsg-3857}&size=256"
    }

    /// Official transparent borders for one viewport. Returns nil when the
    /// village has no map at that spot (HTTP 204).
    public func viewImage(gisCode: String, request: UPViewportRequest) async throws -> UIImage? {
        try await requireAvailable()
        guard var comps = URLComponents(string: "\(base)/view/\(gisCode)") else { throw UPMapError.network }
        comps.queryItems = [
            URLQueryItem(name: "bbox", value: request.bbox.map { String(format: "%.3f", $0) }.joined(separator: ",")),
            URLQueryItem(name: "width", value: String(request.width)),
            URLQueryItem(name: "height", value: String(request.height)),
        ]
        guard let url = comps.url else { throw UPMapError.network }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw UPMapError.network
        }
        let http = response as? HTTPURLResponse
        if http?.statusCode == 204 { return nil }
        guard http?.statusCode == 200, http?.mimeType == "image/png", let image = UIImage(data: data) else {
            throw UPMapError.upstream("Map image unavailable.")
        }
        return image
    }

    @MainActor
    private func requireAvailable() throws {
        guard UPFeature.isAvailable else { throw UPMapError.disabled }
    }

    public func levels(level: Int, parentCodes: [String]) async throws -> [UPLevelItem] {
        try await requireAvailable()
        var q = [URLQueryItem(name: "level", value: String(level))]
        if !parentCodes.isEmpty {
            q.append(URLQueryItem(name: "codes", value: parentCodes.joined(separator: ",")))
        }
        let r: UPLevelResponse = try await get("/levels", query: q)
        return r.items
    }

    public func villageExtent(district: String, tehsil: String, village: String) async throws -> UPVillageExtent {
        try await requireAvailable()
        return try await get("/village/extent", query: [
            URLQueryItem(name: "district", value: district),
            URLQueryItem(name: "tehsil", value: tehsil),
            URLQueryItem(name: "village", value: village),
        ])
    }

    public func identify(gisCode: String, coordinate: CLLocationCoordinate2D) async throws -> UPPlotResult {
        try await requireAvailable()
        return try await get("/identify", query: [
            URLQueryItem(name: "gis_code", value: gisCode),
            URLQueryItem(name: "lat", value: String(format: "%.7f", coordinate.latitude)),
            URLQueryItem(name: "lng", value: String(format: "%.7f", coordinate.longitude)),
        ])
    }

    public func plot(gisCode: String, plotNo: String) async throws -> UPPlotResult {
        try await requireAvailable()
        return try await get("/plot", query: [
            URLQueryItem(name: "gis_code", value: gisCode),
            URLQueryItem(name: "plot_no", value: plotNo),
        ])
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        guard var comps = URLComponents(string: base + path) else { throw UPMapError.network }
        comps.queryItems = query
        guard let url = comps.url else { throw UPMapError.network }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw UPMapError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(status) {
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw UPMapError.upstream("The server sent an unexpected response.")
            }
        }
        let body = try? JSONDecoder().decode(UPErrorBody.self, from: data)
        let message = body?.message ?? "Something went wrong (HTTP \(status))."
        switch body?.errorCode {
        case "UP_GIS_DISABLED": throw UPMapError.disabled
        case "UP_NOT_FOUND": throw UPMapError.notFound(message)
        case "UP_INVALID_INPUT": throw UPMapError.invalid(message)
        default:
            if status == 429 { throw UPMapError.upstream("Too many requests. Wait a moment and try again.") }
            throw UPMapError.upstream(message)
        }
    }
}
