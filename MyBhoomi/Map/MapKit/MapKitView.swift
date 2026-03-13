import SwiftUI
import MapKit

struct MapKitView: View {
    @Binding var parcels: [Parcel]
    @Binding var selectedParcel: Parcel?
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
        Map(position: $position, selection: $selectedParcel) {
            ForEach(parcels) { parcel in
                let style = style(for: parcel)
                MapPolygon(coordinates: parcel.boundary.map { $0.clLocation })
                    .foregroundStyle(style.fillColor.opacity(0.4))
                    .stroke(style.strokeColor, lineWidth: style.strokeWidth)
                    .tag(parcel)
            }
            UserAnnotation()
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            setupInitialPosition()
        }
    }
    
    private func setupInitialPosition() {
        if let first = parcels.first, let firstCoord = first.boundary.first {
            position = .camera(MapCamera(centerCoordinate: firstCoord.clLocation, distance: 1500))
        }
    }
    
    private func style(for parcel: Parcel) -> ParcelStyle {
        if selectedParcel?.id == parcel.id { return .selected }
        return .normal(landUse: parcel.metadata.landUseType)
    }
}

extension Parcel: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
