//
//  MapTileProvider.swift
//  MyBhoomi
//
//  Base-map raster tiles for MapLibre.
//
//  - With `ArcGISAPIKey` set in CustomInfo.plist: licensed Esri ArcGIS basemaps
//    (satellite, labels, streets) with the attribution Esri requires.
//  - Without a key: the previous tile servers (Google satellite/labels,
//    OpenStreetMap streets) so the map always renders. These are not licensed
//    for commercial use — add a key before scaling up.
//

import Foundation
import MapLibre

enum MapTileProvider {
    private static let esriBase = "https://ibasemaps-api.arcgis.com/arcgis/rest/services"

    private static let apiKey: String = {
        (Bundle.main.object(forInfoDictionaryKey: "ArcGISAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }()

    /// True when licensed Esri tiles are in use.
    static var usesLicensedTiles: Bool { !apiKey.isEmpty }

    private static func esri(_ service: String) -> String {
        // Esri tile order is {z}/{y}/{x}.
        "\(esriBase)/\(service)/MapServer/tile/{z}/{y}/{x}?token=\(apiKey)"
    }

    static var satelliteTemplate: String {
        usesLicensedTiles ? esri("World_Imagery")
                          : "https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}"
    }

    static var labelsTemplate: String {
        usesLicensedTiles ? esri("Reference/World_Boundaries_and_Places")
                          : "https://mt1.google.com/vt/lyrs=h&x={x}&y={y}&z={z}"
    }

    static var streetsTemplate: String {
        usesLicensedTiles ? esri("World_Street_Map")
                          : "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
    }

    /// Source options, including attribution when the licence requires it.
    static func sourceOptions(attribution: String) -> [MLNTileSourceOption: Any] {
        var options: [MLNTileSourceOption: Any] = [.tileSize: 256]
        if usesLicensedTiles {
            options[.attributionInfos] = [MLNAttributionInfo(title: NSAttributedString(string: attribution), url: nil)]
        }
        return options
    }

    static let satelliteAttribution = "Powered by Esri | Esri, Maxar, Earthstar Geographics, and the GIS User Community"
    static let streetsAttribution = "Powered by Esri | Esri, HERE, Garmin, FAO, NOAA, USGS, © OpenStreetMap contributors"
}
