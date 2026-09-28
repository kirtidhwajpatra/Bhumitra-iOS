//
//  MapViewModel+UP.swift
//  MyBhoomi
//
//  Uttar Pradesh map-layer prototype. Kept out of the Odisha code paths: it
//  only touches the `upSession` / `selectedUPPlot` state and the camera.
//

import Foundation
import CoreLocation
import UIKit

extension MapViewModel {

    @MainActor
    public var isInUPMode: Bool { upSession != nil }

    /// Enters UP mode for one village: clears any Odisha selection and flies there.
    @MainActor
    public func enterUP(_ session: UPVillageSession) {
        guard UPFeature.isAvailable else {
            showToast("Uttar Pradesh map view is turned off", icon: "map")
            return
        }
        // Remember the current map and Odisha village so Exit is reversible.
        upReturnVillage = activeCadastralVillage
        upReturnCenter = mapCenter
        upReturnZoom = zoomLevel
        upReturnIsSatellite = isSatellite
        upReturnShowParcels = showParcels
        cancelActiveGPSAndClearPlotSelection()
        // Release the large Odisha shape before installing the raster layer.
        clearCadastralVillage()
        selectedUPPlot = nil
        upSession = session
        isSatellite = true
        showParcels = true
        moveCamera(
            to: Coordinate(latitude: session.extent.centerLat, longitude: session.extent.centerLng),
            zoom: session.fittingZoom,
            animated: true
        )
        showToast("\(session.villageName) · tap a plot", icon: "hand.tap")
    }

    @MainActor
    public func exitUP(restorePrevious: Bool = true) {
        let village = restorePrevious ? upReturnVillage : nil
        let returnCenter = upReturnCenter
        let returnZoom = upReturnZoom
        let returnSatellite = upReturnIsSatellite
        let returnShowParcels = upReturnShowParcels
        upReturnVillage = nil
        upReturnCenter = nil
        upIdentifyTask?.cancel()
        upIdentifyTask = nil
        isUPIdentifying = false
        selectedUPPlot = nil
        upSession = nil
        guard restorePrevious else { return }
        isSatellite = returnSatellite
        showParcels = returnShowParcels
        if let center = returnCenter {
            moveCamera(to: center, zoom: returnZoom, animated: true)
        }
        if let village {
            _Concurrency.Task { @MainActor [weak self] in
                guard let self else { return }
                await self.loadCadastralVillage(village: village, preserveCenter: true)
            }
        }
    }

    /// Called from the map when a tap lands on no Odisha parcel while in UP mode.
    @MainActor
    public func identifyUPPlot(at coordinate: CLLocationCoordinate2D) {
        guard let session = upSession else { return }
        upIdentifyTask?.cancel()
        isUPIdentifying = true
        upIdentifyTask = _Concurrency.Task { @MainActor [weak self] in
            defer { self?.isUPIdentifying = false }
            do {
                let plot = try await UPMapService.shared.identify(gisCode: session.gisCode, coordinate: coordinate)
                guard !_Concurrency.Task.isCancelled, let self, self.upSession?.gisCode == session.gisCode else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                self.selectedUPPlot = plot
            } catch is CancellationError {
                return
            } catch {
                guard let self, !_Concurrency.Task.isCancelled else { return }
                self.selectedUPPlot = nil
                self.showToast(Self.upMessage(for: error, notFound: "No plot at this spot"), icon: "mappin.slash")
            }
        }
    }

    /// Plot-number search inside the current UP village.
    @MainActor
    public func findUPPlot(number: String) async -> Bool {
        guard let session = upSession else { return false }
        let clean = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        isUPIdentifying = true
        defer { isUPIdentifying = false }
        do {
            let plot = try await UPMapService.shared.plot(gisCode: session.gisCode, plotNo: clean)
            guard upSession?.gisCode == session.gisCode else { return false }
            selectedUPPlot = plot
            if plot.bbox.count == 4 {
                moveCamera(
                    to: Coordinate(latitude: (plot.bbox[1] + plot.bbox[3]) / 2,
                                   longitude: (plot.bbox[0] + plot.bbox[2]) / 2),
                    zoom: max(zoomLevel, 17.5),
                    animated: true
                )
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard !_Concurrency.Task.isCancelled else { return false }
            showToast(Self.upMessage(for: error, notFound: "Plot \(clean) not found in this village"), icon: "magnifyingglass")
            return false
        }
    }

    @MainActor
    static func upMessage(for error: Error, notFound: String) -> String {
        if let e = error as? UPMapError {
            if case .notFound = e { return notFound }
            return e.errorDescription ?? "Something went wrong"
        }
        return "Something went wrong"
    }
}
