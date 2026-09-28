//
//  SpatialResolutionStatusPill.swift
//  MyBhoomi
//
//  Presentation layer for MapViewModel.spatialResolutionState, built entirely
//  from the shared notice family (MapNotice.swift): progress and confirmations
//  render as a MapStatusPill, states that need the user render as a
//  MapNoticeCard with retry / manual-selection actions.
//

import SwiftUI

struct SpatialResolutionStatusPill: View {
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.25), value: viewModel.spatialResolutionState)
            // Confirmations are informational: show briefly, then get out of
            // the way. Progress and actionable notices are NOT auto-hidden.
            .task(id: viewModel.spatialResolutionState) {
                guard isTransientConfirmation(viewModel.spatialResolutionState) else { return }
                let shown = viewModel.spatialResolutionState
                try? await _Concurrency.Task.sleep(nanoseconds: Self.confirmationSeconds * 1_000_000_000)
                guard !_Concurrency.Task.isCancelled, viewModel.spatialResolutionState == shown else { return }
                viewModel.dismissSpatialResolutionState()
            }
    }

    /// How long "Plots near you" / "Approximate location" / ready stay up.
    private static let confirmationSeconds: UInt64 = 4

    private func isTransientConfirmation(_ state: SpatialResolutionUIState) -> Bool {
        switch state {
        case .ready, .plotsNearYou, .approximateLocation: return true
        default: return false
        }
    }

    // MARK: - Actions

    private var retry: NoticeAction {
        NoticeAction("Try again", icon: "arrow.clockwise") {
            _Concurrency.Task { @MainActor in
                await viewModel.retryLastResolution()
            }
        }
    }

    private func chooseManually(primary: Bool = false) -> NoticeAction {
        NoticeAction(primary ? "Choose location" : "Choose manually", icon: primary ? "map" : nil) {
            viewModel.openManualLocationSelector()
        }
    }

    private var openSettings: NoticeAction {
        NoticeAction("Open Settings") {
            LocationPermissionManager.shared.handleTap()
        }
    }

    private func dismiss() {
        viewModel.dismissSpatialResolutionState()
    }

    // MARK: - State → notice

    @ViewBuilder
    private var content: some View {
        switch viewModel.spatialResolutionState {
        case .idle, .ambiguous, .exact:
            EmptyView()

        case .resolving(let title):
            MapStatusPill(
                tone: .progress,
                title: title.hasPrefix("Finding") ? title : "Finding official area for \(title)…"
            )

        case .loadingParcels(let villageName):
            MapStatusPill(tone: .progress, title: "Loading plots", detail: villageName)

        case .ready(let message):
            MapStatusPill(icon: "checkmark.circle.fill", tone: .success, title: message)

        case .plotsNearYou(let accuracy):
            MapStatusPill(
                icon: "checkmark.circle.fill",
                tone: .success,
                title: "Plots near you",
                detail: "±\(Int(accuracy)) m",
                onDismiss: dismiss
            )

        case .approximateLocation(let accuracy):
            MapStatusPill(
                icon: "location",
                tone: .warning,
                title: "Approximate location",
                detail: "±\(Int(accuracy)) m",
                onDismiss: dismiss
            )

        case .preciseLocationRecommended:
            MapNoticeCard(
                icon: "location.viewfinder", tone: .warning,
                title: "Location not precise enough",
                message: "Move to an open area, or choose your village.",
                primary: retry, secondary: chooseManually(), onDismiss: dismiss
            )

        case .locationPermissionDenied:
            MapNoticeCard(
                icon: "location.slash", tone: .warning,
                title: "Location access is off",
                message: "Allow location to see plots around you.",
                primary: openSettings, secondary: chooseManually(), onDismiss: dismiss
            )

        case .locationServicesDisabled:
            MapNoticeCard(
                icon: "location.slash", tone: .warning,
                title: "Location Services are off",
                message: "Turn them on in Settings to see plots around you.",
                primary: openSettings, secondary: chooseManually(), onDismiss: dismiss
            )

        case .locationTimeout:
            MapNoticeCard(
                icon: "location.circle", tone: .warning,
                title: "Couldn't get a GPS fix",
                message: "Move to an open area and try again.",
                primary: retry, secondary: chooseManually(), onDismiss: dismiss
            )

        case .locationUnavailable:
            MapNoticeCard(
                icon: "location.slash", tone: .warning,
                title: "Location unavailable",
                message: "Your position couldn't be determined. Try again shortly.",
                primary: retry, secondary: chooseManually(), onDismiss: dismiss
            )

        case .noInternet:
            MapNoticeCard(
                icon: "wifi.slash", tone: .danger,
                title: "You're offline",
                message: "Connect to the internet to load plots and land records.",
                primary: retry, onDismiss: dismiss
            )

        case .backendTemporarilyUnavailable(let reason):
            MapNoticeCard(
                icon: "exclamationmark.triangle", tone: .warning,
                title: "Plot service is busy",
                message: reason.isEmpty ? "Official plot maps couldn't be loaded right now." : reason,
                primary: retry, secondary: chooseManually(), onDismiss: dismiss
            )

        case .parcelLoadFailed(let villageName, _):
            MapNoticeCard(
                icon: "map", tone: .warning,
                title: "Couldn't load plots",
                message: "Found \(villageName), but its plot map didn't download.",
                primary: retry, secondary: chooseManually(), onDismiss: dismiss
            )

        case .noCoverage:
            MapNoticeCard(
                icon: "map", tone: .neutral,
                title: "No plot map here yet",
                message: "Boundaries aren't digitised for this area. Land records are still available.",
                primary: chooseManually(primary: true), onDismiss: dismiss
            )

        case .outsideOdisha:
            MapNoticeCard(
                icon: "mappin.slash", tone: .neutral,
                title: "Outside Odisha",
                message: "Plot maps and land records cover Odisha only.",
                primary: chooseManually(primary: true), onDismiss: dismiss
            )

        case .temporarilyUnavailable(let reason):
            MapNoticeCard(
                icon: "exclamationmark.triangle", tone: .warning,
                title: "Plot service unavailable",
                message: reason.isEmpty ? "Check your connection and try again." : reason,
                primary: retry, secondary: chooseManually(), onDismiss: dismiss
            )

        case .unresolved:
            MapNoticeCard(
                icon: "questionmark.circle", tone: .neutral,
                title: "Village not found",
                message: "Choose your village from the district list.",
                primary: chooseManually(primary: true),
                secondary: viewModel.lastFailedSearchResult != nil ? retry : nil,
                onDismiss: dismiss
            )
        }
    }
}
