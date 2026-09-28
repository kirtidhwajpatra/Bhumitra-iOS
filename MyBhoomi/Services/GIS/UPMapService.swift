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
    public let officialRecordUrl: String?
    public let note: String?

    public var id: String { "\(gisCode)#\(plotNo)#\(plotId ?? "")" }

    enum CodingKeys: String, CodingKey {
        case gisCode = "gis_code"
        case plotNo = "plot_no"
        case plotId = "plot_id"
        case bbox, records
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

    /// MapLibre tile template. `{bbox-epsg-3857}` is filled in by MapLibre per tile.
    public func tileURLTemplate(gisCode: String) -> String {
        "\(base)/wms/\(gisCode)?bbox={bbox-epsg-3857}&size=256"
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
