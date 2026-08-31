# Bihar iOS Cadastral GIS Integration Architecture

## 1. Architecture Overview

```
[ Location Picker: CadastralVillagePickerSheet ]
  ├── Feature Flag: AppConfig.biharGisFeatureEnabled (default: false)
  ├── State Selector: Segmented Control [ Odisha | Bihar ]
  └── Stepper Breadcrumbs: District ──► Circle ──► Halka ──► Mauza
                    │ (User selects Mauza)
                    ▼
           [ MapViewModel ]
  ├── loadCadastralVillage(village, state="BIHAR", sheetNo=nil)
  ├── Resets prior shapes, selected plots, and map bounds
  └── Observes loading & drawing states
                    │
                    ▼
        [ CadastralRepository ]
  ├── State-namespaced in-memory cache ("BIHAR_\(village.id)_\(sheetNo)")
  └── SingleFlight in-flight task coalescing
                    │
                    ▼
         [ CadastralAPIClient ]
  └── GET /api/v1/gis/village/{id}/parcels?state=BIHAR
                    │
                    ▼
           [ MapLibreView ]
  ├── Ingests GeoJSON into MLNShapeSource ("cadastral-parcels-source")
  ├── Vector rendering: "parcel-outline", "parcel-fill", "parcel-selected-outline"
  └── Tap gesture ray-casting point-in-polygon resolution
```

---

## 2. Key Components & Implementation Details

### 2.1 Feature Gating (`AppConfig.swift`)
- Centralized toggle: `AppConfig.biharGisFeatureEnabled: Bool = false`.
- Fail-closed: Prevents Bihar options from appearing in production builds until explicitly enabled.

### 2.2 State-Aware Client (`CadastralAPIClient.swift`)
- Extends all GIS hierarchy and parcel methods with `state: String = "ODISHA"`.
- Explicit error handling for `BIHAR_GIS_DISABLED` (HTTP 503) and `GIS_MAP_TOO_LARGE` (HTTP 413).

### 2.3 State-Isolated Caching (`CadastralRepository.swift`)
- All in-memory dictionary keys prefix state: `"\(state)_\(id)"`.
- Complete isolation ensures Bihar and Odisha caches never leak across state transitions.

### 2.4 Vector Map Ingestion & Tap Resolution (`MapLibreView.swift`)
- MapLibre vectors render at 60/120 FPS directly from GeoJSON shapes.
- Ray-casting point-in-polygon tap resolver recognizes standard Bihar property attributes: `plot_number`, `plotno`, `plot_no`, `khesra_no`, `khesra_id`.

---

## 3. Backward Compatibility & Odisha Safety

- All existing API client and repository methods retain default parameter `state: String = "ODISHA"`.
- Zero changes to Odisha RoR, Scrapers, PDF generation, StoreKit, or Authentication.
- Clean state switching clears all prior vector layers before loading new geometries.
