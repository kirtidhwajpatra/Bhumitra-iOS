# MyBhoomi - Odisha Cadastral GIS (MapLibre Edition)

## Features
- ✅ **MapLibre Engine**: High-performance vector tile rendering for 1.2GB dataset.
- ✅ **Odisha PMTiles**: Direct streaming of Cadastral plots from local disk.
- ✅ **Clean Architecture**: Decoupled presentation from GIS logic.

## Setup Instructions

1. **Install Dependencies**:
   - Open Xcode and go to **File > Add Packages...**
   - **MapLibre Native**: Use URL `https://github.com/maplibre/maplibre-gl-native-distribution`
     - Select the latest version and the `MapLibre` library.
   - **MapLibre SwiftUI**: Use URL `https://github.com/maplibre/swiftui-dsl`
     - Select the `MapLibreSwiftUI` library.

2. **Configure Data**:
   - Ensure the file `Odisha4kgeo_OD_Cadastrals-part0000.pmtiles` is in your Downloads folder.
   
3. **Run**:
   - Select an iOS Simulator.
   - Press `Cmd + R`.

## Implementation Details
- The app uses `MLNVectorTileSource` with a local URI to stream tiles directly from the PMTiles container.
- Polygon layers are dynamically rendered with specialized cadatral fields (`revenue_plot`, etc.).
