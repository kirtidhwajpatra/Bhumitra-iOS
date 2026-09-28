//
//  MapTileProvider.swift
//  MyBhoomi
//
//  Licensed basemap tiles (Esri ArcGIS Location Platform).
//
//  Replaces the undocumented Google `mt1.google.com/vt` endpoints and the
//  community OpenStreetMap tile servers, neither of which may be used by a
//  commercial app. Esri's basemap tiles are licensed for this use with an
//  API key (free tier available) and require visible attribution.
//
//  Key: set `ArcGISAPIKey` in CustomInfo.plist. Create one at
//  https://location.arcgis.com (Developer credentials → API key, with the
//  "Basemaps" privilege). Without a key the tile servers return an error
//  and the base layers render empty.
//

import Foundation

enum MapTileProvider {
    private static let base = "https://ibasemaps-api.arcgis.com/arcgis/rest/services"

    static var apiKey: String {
        let key = (Bundle.main.object(forInfoDictionaryKey: "ArcGISAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if key.isEmpty { debugLog("[MapTileProvider] ⚠️ ArcGISAPIKey missing from Info.plist — base tiles will not load") }
        return key
    }

    private static func template(_ service: String) -> String {
        // Esri tile order is {z}/{y}/{x}.
        "\(base)/\(service)/MapServer/tile/{z}/{y}/{x}?token=\(apiKey)"
    }

    static var satelliteTemplate: String { template("World_Imagery") }
    static var labelsTemplate: String { template("Reference/World_Boundaries_and_Places") }
    static var streetsTemplate: String { template("World_Street_Map") }

    /// Attribution Esri requires wherever its basemaps are shown.
    static let satelliteAttribution = "Powered by Esri | Esri, Maxar, Earthstar Geographics, and the GIS User Community"
    static let streetsAttribution = "Powered by Esri | Esri, HERE, Garmin, FAO, NOAA, USGS, © OpenStreetMap contributors"
}
