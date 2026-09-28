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
        // Remember the Odisha map only on first entry. Switching UP villages must
        // not overwrite it, or Exit would "restore" the previous UP village.
        if upSession == nil {
            upReturnVillage = activeCadastralVillage
            upReturnCenter = mapCenter
            upReturnZoom = zoomLevel
            upReturnIsSatellite = isSatellite
            upReturnShowParcels = showParcels
            cancelActiveGPSAndClearPlotSelection()
            // Release the large Odisha shape before installing the raster layer.
            clearCadastralVillage()
        }
        cancelPendingUPRequest()
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
        cancelPendingUPRequest()
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
        let generation = beginUPRequest()
        // Clear the old highlight immediately so it never sits on the wrong plot.
        selectedUPPlot = nil
        upIdentifyTask = _Concurrency.Task { @MainActor [weak self] in
            defer { self?.finishUPRequest(generation) }
            do {
                let plot = try await UPMapService.shared.identify(gisCode: session.gisCode, coordinate: coordinate)
                guard let self, self.isCurrentUPRequest(generation, gisCode: session.gisCode) else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                self.selectedUPPlot = plot
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.isCurrentUPRequest(generation, gisCode: session.gisCode) else { return }
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
        let generation = beginUPRequest()
        defer { finishUPRequest(generation) }
        do {
            let plot = try await UPMapService.shared.plot(gisCode: session.gisCode, plotNo: clean)
            guard isCurrentUPRequest(generation, gisCode: session.gisCode) else { return false }
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
            guard isCurrentUPRequest(generation, gisCode: session.gisCode) else { return false }
            showToast(Self.upMessage(for: error, notFound: "Plot \(clean) not found in this village"), icon: "magnifyingglass")
            return false
        }
    }

    // MARK: - Request generations (latest tap or search wins)

    @MainActor
    private func beginUPRequest() -> UUID {
        upIdentifyTask?.cancel()
        upIdentifyTask = nil
        let generation = UUID()
        upRequestGeneration = generation
        isUPIdentifying = true
        return generation
    }

    @MainActor
    private func finishUPRequest(_ generation: UUID) {
        if upRequestGeneration == generation { isUPIdentifying = false }
    }

    @MainActor
    func isCurrentUPRequest(_ generation: UUID, gisCode: String) -> Bool {
        !_Concurrency.Task.isCancelled && upRequestGeneration == generation && upSession?.gisCode == gisCode
    }

    @MainActor
    func cancelPendingUPRequest() {
        upIdentifyTask?.cancel()
        upIdentifyTask = nil
        upRequestGeneration = UUID()
        isUPIdentifying = false
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
