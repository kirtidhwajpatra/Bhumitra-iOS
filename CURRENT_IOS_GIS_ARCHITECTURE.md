# Current iOS Cadastral GIS Architecture & Bihar Integration Points

## 1. Existing Odisha GIS Flow & Architecture

The Bhumitra iOS application provides cadastral GIS mapping through a layered, reactive architecture:

```
[ CadastralVillagePickerSheet / SearchBarView ]
                    │ (User selects village)
                    ▼
           [ MapViewModel ]
                    │
                    ▼
        [ CadastralRepository ] ──► [ In-Memory / Disk Cache ]
                    │
                    ▼
         [ CadastralAPIClient ] ──► GET /api/v1/gis/village/{id}/parcels
                    │
                    ▼
          [ GeoJSON / MLNShape ]
                    │
                    ▼
           [ MapLibreView ] ──► MapLibre MLNShapeSource & Fill/Line Layers
```

---

## 2. Component Inventory

1. **`AppConfig.swift`**:
   - Holds default camera coordinates and configuration constants.
   - Central point to define `biharGisFeatureEnabled = false`.

2. **`CadastralAPIClient.swift`**:
   - Networking service for `/api/v1/gis/*` endpoints using `URLSession`.
   - Currently hardcoded to Odisha paths without state parameter.

3. **`CadastralRepository.swift`**:
   - SingleFlight coalescing, in-memory caching, and local disk persistence.
   - Caches `[CadastralDistrict]`, `[CadastralBlock]`, `[CadastralGP]`, and `[CadastralVillage]`.

4. **`MapViewModel.swift`**:
   - Manages `@Published var cadastralShape: MLNShape?`, `@Published var cadastralParcels: [CadastralParcel]`, and `@Published var selectedCadastralParcel: CadastralParcel?`.
   - Handles map camera positioning and plot selection highlights.

5. **`MapLibreView.swift`**:
   - `UIViewRepresentable` wrapping `MLNMapView`.
   - Renders GeoJSON vector features directly via `MLNShapeSource` (`"cadastral-parcels-source"`), `"parcel-fill"`, and `"parcel-outline"`.

6. **`CadastralVillagePickerSheet.swift`**:
   - Multi-step location picker navigating the administrative hierarchy.

---

## 3. Bihar Integration Points

- **Non-Invasive Extensibility**: The normalized backend contract matches `CadastralDistrict`, `CadastralBlock`, `CadastralGP`, and `CadastralVillage`.
- **State Selection**: When `AppConfig.biharGisFeatureEnabled` is enabled, the picker provides a State switch (`Odisha` / `Bihar`).
- **Terminology Mapping**:
  - Odisha: District $\rightarrow$ Block $\rightarrow$ GP $\rightarrow$ Village
  - Bihar: District $\rightarrow$ Circle (Anchal) $\rightarrow$ Halka $\rightarrow$ Mauza (with Thana No) $\rightarrow$ Sheet
- **MapLibre Reuse**: `MapLibreView` does not need duplication; it consumes standard `MLNShape` GeoJSON features seamlessly.
