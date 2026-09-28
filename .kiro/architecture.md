# MyBhoomi — Architecture Map

> **Product:** MyBhoomi (branded "Bhumitra" / "PrettyPlot") — an Indian land-records app for Odisha (and, feature-flagged off, Bihar). Users find a parcel on a satellite/cadastral map or by drilling District → Tahasil → Village → Plot, then view the official Record of Rights (RoR) with owner details.
>
> **Scope of this document:** iOS app, the two backend services, external APIs, MapLibre integration, location search, cadastral data flow, networking, and data models — plus dependencies and risk areas. This is a read-only analysis; no source was modified.

---

## 1. System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                          iOS App (SwiftUI)                             │
│  Presentation ─ Domain ─ Data ─ Core ─ Services ─ GISExplorer ─ Map    │
└───────────────┬───────────────────────────────┬──────────────────────┘
                │ REST/JSON + GeoJSON            │ GET /location-info
                │ (Bearer auth on RoR)           │ (3s fail-fast)
                ▼                                 ▼
┌──────────────────────────────────┐   ┌──────────────────────────────┐
│  BhulekBackend (Python/FastAPI)  │   │  OdishaAdminService (Node/     │
│  api.prettyplot.in/api/v1        │   │  Express) — Cloud Run          │
│  • RoR scraping (Playwright)     │   │  • coord → admin hierarchy     │
│  • Cadastral GIS proxy           │   │  • PostGIS ST_Contains          │
│  • Subscriptions (Apple StoreKit)│   │  • Nominatim fallback          │
└───────────────┬──────────────────┘   └──────────────────────────────┘
                │ scrapes / calls
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  External government + tile sources                                    │
│  • bhulekh.ori.nic.in (ASP.NET WebForms RoR portal + SOAP)             │
│  • Odisha "4K GEO" cadastral SDI / Bihar BhuNaksha (GIS)               │
│  • Google raster tiles (satellite + hybrid labels), OpenStreetMap      │
│  • Firebase (analytics), Google Sign-In                                │
└──────────────────────────────────────────────────────────────────────┘
```

**Key architectural fact:** the iOS app does **not** call government portals directly. Everything except coordinate→admin geocoding is proxied through `BhulekBackend` (`api.prettyplot.in`). The one exception is `LocalAdminClient`, which calls the separate `OdishaAdminService` on Cloud Run.

---

## 2. iOS App Architecture

SwiftUI app (`MyBhoomi.xcodeproj`, targets `MyBhoomi` + `MyBhoomiTests`, built with Xcode 26.6). It follows a loosely-applied Clean Architecture. Dependency wiring is done through `.shared` singletons injected into a small number of `ObservableObject` ViewModels — there is **no formal DI container**.

### 2.1 Boot sequence

- **`MyBhoomiApp.swift`** (`@main`): `init()` configures Firebase analytics, registers Google Sans fonts, and (DEBUG only) runs in-code test suites. Hosts a single `WindowGroup` → `RootContainerView`; forwards `.onOpenURL` to Google Sign-In.
- **`RootContainerView`**: the real launch router. Observes `RemoteConfigManager.shared`, `AuthManager.shared`, `AppearanceManager.shared` and renders one of five mutually-exclusive states:
  1. `maintenanceMode` → block screen
  2. `isUpdateRequired` → blurred `MainView` behind `ForceUpdateView`
  3. not authenticated → `LoginView`
  4. authenticated → `MainView` (+ optional recommended-update alert)
  5. always: `SplashScreenView` overlay until `isSplashFinished`
- **`AppConfig.swift`**: static constants + feature flags — default focus Keonjhar, Odisha (`21.6289, 85.5817`, `defaultDistrictID = "224"`), `biharGisFeatureEnabled = false` (hard-off), `gisNavigationEnabled`, `useProductionBackendOnDevice = true`.

### 2.2 Layer responsibilities

| Layer | Path | Responsibility |
|---|---|---|
| **Presentation** | `MyBhoomi/Presentation/{Views,ViewModels,Theme}` | ~60 SwiftUI screens/sheets; ViewModels (state controllers); design system (`Theme.swift`, `LiquidGlass*`, fonts, motion) |
| **Domain** | `MyBhoomi/Domain/{Models,Repositories}` | Pure value/domain types and the `ParcelRepositoryProtocol` inversion boundary. No UI/network deps |
| **Data** | `MyBhoomi/Data/{Repositories,Services,GIS,Models}` | Concrete repo implementations, persistence (`VerifiedParcelCache`, `StorageService`), GeoJSON parsing, `LocalAdminClient` |
| **Core** | `MyBhoomi/Core/Utils` | Cross-cutting primitives — currently `NetworkMonitor` (NWPathMonitor) |
| **Services** | `MyBhoomi/Services` (+ `Analytics/`, `GIS/`, `MapKit/`) | Largest folder: app managers (Auth, RemoteConfig, Subscription, Appearance, Navigation) + domain services (RoRService, PDF, ParcelCrossVerifier, LocationSearch, SavedLand) |
| **Utilities** | `MyBhoomi/Utilities` | Stateless helpers — GeoJSON parsers, `KeychainHelper`, extensions |
| **GISExplorer** | `MyBhoomi/GISExplorer` | Self-contained "Apple Maps-style" hierarchy navigation mini-MVVM (View/VM/Repo/Models/Coordinator/Theme), gated by `gisNavigationEnabled` |
| **Map** | `MyBhoomi/Map/{MapLibre,MapKit}` | Map rendering integration — `MapLibreView` (primary), `CadastralFeatureResolver`; MapKit alternative |
| **Resources** | `MyBhoomi/Resources` | Assets, onboarding videos, `sample_parcels.json`, fonts, `Map/style.json` |

### 2.3 Navigation & state

- **`MainView`** is the primary authenticated shell — map-centric, not a tab controller. It owns `@StateObject MapViewModel()`, renders `MapLibreView` full-screen, and layers overlays (`CadastralBoundaryDrawingOverlayView`, `GISExplorerView`, `DetailSheetsOverlay`, `MapHomeOverlay`). Screens surface as `.sheet` / `.fullScreenCover` / `.overlay` driven by `@State` booleans; global tab state via `AppNavigationManager.shared`.
- **`MapViewModel`** is the central state hub — an `NSObject, ObservableObject` with dozens of `@MainActor @Published` properties covering the whole map/cadastral pipeline (parcels, `cadastralShape: MLNShape?`, search, camera, and the `spatialResolutionState` enum). It subscribes to `LocationSearchService.shared.$searchResults` and `NetworkMonitor.shared.$isConnected` via Combine, and calls service singletons directly for actions.
- **Shared manager singletons:** `AppearanceManager` (theme/units via `@AppStorage`), `NetworkMonitor`, `SavedLandManager` (offline-first saved records), `AuthManager` (`selectedStateCode`, tokens), `RemoteConfigManager`, `GISExplorerViewModel`, `RecentLocationSearchStore`.

---

## 3. Networking Layer

There is **no generic HTTP client abstraction**. Instead, four purpose-specific clients each create their own `URLSession` and call Swift `async` `URLSession` methods directly.

### 3.1 Endpoint configuration — `Services/APIConfiguration.swift`
Single source of truth (`APIConfiguration.shared.baseURL`):
- **Release / prod device:** `https://api.prettyplot.in/api/v1` (labeled "AWS EC2 Backend over HTTPS")
- **Simulator DEBUG:** `http://127.0.0.1:8000/api/v1`
- **Physical device DEBUG (prod flag off):** hardcoded LAN IP `http://10.138.60.242:8000/api/v1`
- DEBUG overrides (priority): UserDefaults `bhumitra_custom_api_base` → `bhumitra_use_aws_testing` → env `MYBHOOMI_API_BASE` / `USE_AWS_BACKEND`. Release `init()` purges these keys.

### 3.2 The four clients

| Client | File | Endpoints | Auth | Timeouts / notes |
|---|---|---|---|---|
| **RoRService** (`actor`) | `Services/RoRService.swift` | `GET /ror`, `/ror/pdf`, `/ror/official-document/{id}`, `/version`, `/districts`, `/tahasils`, `/villages`, `/ri-circles` | Bearer (from `AuthManager`) | 55s request / 65s resource (long, because backend synchronously scrapes portal); in-flight coalescing (`inFlightTasks`); verified-only in-memory cache; rich typed-error mapping |
| **CadastralAPIClient** | `Services/GIS/CadastralAPIClient.swift` | `/gis/districts`, `/blocks`, `/gps`, `/villages`, `/gis/village/{id}/extent`, `/parcels` (raw GeoJSON), `/plot/{plot}`, `/gis/parcel/identify` | **none** | 30s/45s, `reloadIgnoringLocalCacheData`; `validateResponse` maps 413→mapTooLarge, 503+`BIHAR_GIS_DISABLED`→biharGisDisabled, 404→notFound, ≥500→serverUnavailable |
| **GISExplorerRepository** | `GISExplorer/GISExplorerRepository.swift` | `/gis/navigation/districts-geojson`, `/districts`, `/{id}/tahasils-geojson`, `/{id}/subdivisions`, `/subdivisions/{id}/villages` | none | 20s, `URLRequest` builder pattern with cache-policy control; in-memory GeoJSON caches under `NSLock`; falls back to `CadastralRepository` |
| **LocalAdminClient** | `Data/GIS/LocalAdminClient.swift` | `GET /location-info?lat=&lng=` | none | **Hardcoded** URL `https://odisha-admin-service-prod-758542001999.asia-south1.run.app`; 3s fail-fast → `CLGeocoder` reverse-geocode fallback |

- **`LocationSearchService`** (`Services/LocationSearchService.swift`, `@MainActor` singleton): `GET /location/search?q=` (debounced ~250ms, sequence-guarded, query cache) and `POST /location/resolve` (spatial resolution). Feeds `MapViewModel`.
- **Auth/secrets:** Bearer-token only, no API keys embedded. `AuthManager.bearerToken` reads `bhumitra_access_token` (JWT) from Keychain via `KeychainHelper`, falling back to `bhumitra_device_token` (guest). 401 → purge + re-acquire device session. GIS clients send no credentials.
- **Reliability:** no automatic retry-with-backoff. Instead: in-flight/single-flight dedup, verified-only caching, user-driven retry buttons gated by `RoRError.isRetryable`, and layered fallback (`LocalAdminClient` → Apple geocoding).

---

## 4. MapLibre Integration & Cadastral Data Flow

### 4.1 `MapLibreView` (`Map/MapLibre/MapLibreView.swift`)
A SwiftUI `UIViewRepresentable` wrapping MapLibre Native's `MLNMapView` (imports `MapLibre` + `MapLibreSwiftUI`). Driven by `@Binding` state + callbacks (`onParcelTapped`, `onParcelRenderingVerified`, …).

**Style layers (bottom-up):**
- `satellite-layer` / `satellite-source` → Google `lyrs=s` raster tiles
- `map-labels-layer` → Google hybrid labels (`lyrs=h`)
- `osm-layer` → OpenStreetMap tiles
- Cadastral (persistent `cadastral-parcels-source`, all `minimumZoomLevel = 10`): `parcel-fill` (transparent — pure hit-test target), `parcel-outline-casing` (dark blur), `parcel-outline` (yellow boundary), `parcel-labels` (plot number from `revenue_plot`, min zoom 12)
- Highlight: `selected-parcel-source` feeds `parcel-highlight`/`parcel-highlight-fill` which are **disabled** — selection is rendered "borderless" via an `AnimatedParcelGradientOverlayView` UIKit subview + a camera fly-to with ambient orbit (`CADisplayLink`).

**Rendering reconciliation:** `reconcileCadastralPipeline(on:style:)` ensures base + cadastral infrastructure, then diffs target shape vs installed state by `selectionToken: UUID`, `installedVillageID`, and shape identity. Data arriving before style load is stashed (`pendingCadastralShape`/`pendingVillage`/`pendingToken`). Render success is confirmed in `mapViewDidFinishRenderingFrame`/`DidBecomeIdle` and reported via `onParcelRenderingVerified` (14-item diagnostic report).

### 4.2 Cadastral flow
1. **Fetch:** `CadastralAPIClient.fetchVillageParcelsRawGeoJSON` → `/gis/village/{id}/parcels` returns **raw WGS84 GeoJSON bytes** for direct `MLNShape` ingestion. `CadastralRepository` wraps this with per-state in-memory caches + single-flight coalescing (`NSLock`), keyed `{STATE}_{villageID}_{sheet|all}`.
2. **Tap:** `handleMapTap` → `visibleFeatures(at:styleLayerIdentifiers:["parcel-fill"])` → ray-cast `pointInPolygon` → build `CadastralParcel` (attribute extraction with many fallback key names) → set `selectedCadastralParcel`, fire `onParcelTapped`. One containing feature = select; multiple = "zoom in" toast; zero = GISExplorer district/tahasil hit-test.
3. **Identity → land record:** `MapViewModel.onCadastralParcelSelected` → build `CanonicalParcelIdentity` → `RoRService.fetchOwnerDetails` → `ParcelCrossVerifier.verify` (§6).

### 4.3 Coordinates, geometry, area
- WGS84 lon/lat throughout; GeoJSON `[lng, lat]` consistently mapped to `Coordinate(latitude: p[1], longitude: p[0])`.
- Polygon + MultiPolygon supported. **Inconsistency:** the coordinator picks the *first* polygon of a MultiPolygon while `CadastralFeatureResolver` picks the *largest*.
- **No true area computation** in the map path — GIS area comes from the `area_in_acre` attribute; RoR area is parsed from strings ("1 Acre 45 Decimal") by `ParcelCrossVerifier.parseAcreageFromRoR`; `OdishaAreaFormatter.calculateAcre(from:)` offers a spherical polygon area. `Parcel.center` is a naive vertex average, not a polygon centroid.

### 4.4 Tile / offline storage
- **No** MapLibre `MLNOfflineStorage`/`OfflinePack` usage in Swift (headers only). An "Offline Maps" settings section exists but tile packs aren't managed in code read.
- Cadastral parcels cached in-memory/session only. Land records persisted on disk: `VerifiedParcelCache` (verified-only LRU) and `SavedLandManager` (JSON snapshots).

---

## 5. Location Search & Admin Hierarchy Resolution

Two parallel paths converge on `RoRService.fetchOwnerDetails` → `GET /ror`:

- **Free-text search:** `LocationSearchService.search` → `GET /location/search` → `[LocationSearchResult]` (types: REVENUE_VILLAGE, LANDMARK, COMPOUND_PLOT, PLOT_ONLY, COORDINATE, PIN_CODE, BROAD_CITY, BROAD_DISTRICT, each with icon + zoom). `LocationSearchResult.init(from:)` reads nested `extraMetadata` and **synthesizes `revenueVillageId`** by zero-padding district/tahasil/mouza IDs into `%02d%02d%03d`.
- **Manual drill-down:** `ManualRoRSearchView` + `ManualSearchViewModel` — cascading District → Tahasil → Village → criterion, each loaded lazily from the backend (`/districts`, `/tahasils`, `/villages`, `/ri-circles`) via `didSet` observers. Cache-first via `VerifiedParcelCache`; also surfaces saved verified suggestions.
- **Spatial resolution:** `POST /location/resolve` → `LocationResolutionResponse` with `ResolutionStatus` (EXACT/AMBIGUOUS/UNRESOLVED/OUTSIDE_ODISHA/NO_CADASTRAL_COVERAGE/PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE). Drives the `spatialResolutionState` machine → `SpatialResolutionStatusPill` (progress capsule / accuracy pill / fail-closed retry card).
- **Crosswalks (backend concern):** GIS↔Bhulekh admin-code mapping via `BhulekBackend/models/gis_bhulekh_crosswalk.py` + `data/bhulekh_catalog/tahasil_crosswalk_v1.json`, `gis_bhulekh_village_crosswalk_v1.json`. iOS mirrors only small helpers (`MapViewModel.districtNameForGISPrefix`, `tahasilNameForGISCodes`) used in `RoRService.prepareParams` to backfill names from `villageID` digit slices (falls back to `"<District> Sadar"`).

---

## 6. Data Models & Identity Resolution

### 6.1 The identity model (`Domain/Models/Parcel.swift`)
- **`CanonicalParcelIdentity`** — the type binding a GIS parcel to a Bhulekh record. Fields: `parcelID`, `plotNumber`, district/tahasil/village name+ID, `panchayatName`, and computed `isFullyResolved` (true only when plot+district+tahasil+village are non-empty and ≠ "N/A"). When no `parcelID`, builds compound key `"district:tahasil:village:plot"` preferring ID variants.
- **`ParcelMetadata`** wraps identity + `estimatedAreaAcre` + raw tile attributes; **`Parcel`** = id + identity + boundary + metadata.

### 6.2 RoR models (`Domain/Models/RoRModels.swift`)
`RoRResponse` (plot, village, district, tahasil, khataNumber, area, landType, `owners: [OwnerEntry]`, `plots: [AssociatedPlot]`, `rawFields`, `verification: RoRVerification?`, `isPreview`/`isLocked`), `OwnerEntry`, `AssociatedPlot`, `RoRVerification` (requested vs returned + `locationMatch`/`plotMatch`/`status`). Helpers: `OwnerParserHelper` (decomposes Odia/English owner strings), `OdishaAreaFormatter`, `RoRErrorCode`/`RoRErrorState`.

### 6.3 Cadastral + hierarchy (`Domain/Models/CadastralModels.swift`, `BhulekhHierarchy.swift`)
`CadastralDistrict/Block/GP/Village` (names sanitized via `VillageNameSanitizer`), `CadastralExtent`, `CadastralParcel` (custom decoder parses nested geometry via `AnyCodable`). Parallel Bhulekh-portal hierarchy: `BhulekhDistrict/Tahasil/Village/RICircle`.

### 6.4 Persistence models
- **`SavedLandRecord`** (`+ SavedLandManager`): id = `"district_tahasil_village_plot"` (**underscore**-joined), full identity + `rawResponse` for offline viewing + boundary/centroid. Persisted as JSON to `Application Support/Bhumitra/bhumitra_saved_lands.json` with UserDefaults fallback.
- **`CachedVerifiedParcel`** (`+ VerifiedParcelCache`): `canonicalKey = "district:tahasil:village:plot"` (**colon**-joined), strict enums `LandClassificationStatus` (VERIFIED_PRIVATE/GOVERNMENT/OTHER/UNVERIFIED) and `ParcelResolutionStatus`. **Fail-closed** `init?` returns nil unless verification is `.verified` and all IDs+plot are present. `determineLandClassification` classifies from Odia/English tenure markers, defaulting to `.unverified` rather than guessing.
- **`LandAreaUnit`** conversion system (acre/decimal/sq_ft/sq_m/gaj/hectare/guntha/mana/bigha/katha/cent), region-aware, `isSupported(in:)` guards regional units.

### 6.5 The verification engine — `Services/ParcelCrossVerifier.swift` ⚠️
The heart of GIS→Bhulekh reconciliation. `verify(gisIdentity:rorResponse:gisAreaInAcre:error:)` is fail-closed:
- `error` → `.sourceUnavailable`; nil RoR → `.insufficientData`; not fully resolved → `.insufficientData`.
- District/tahasil/village matching is **fuzzy**: normalized uppercase + bidirectional substring `contains` + **hardcoded English↔Odia transliteration pair tables** (or backend `locationMatch == true && status == .verified`).
- Plot matching is **strict exact equality** (no prefix/substring).
- Area comparison informational only (25% tolerance).
- Only all-four-match → `.verified`; else `.mismatch` with reasons.

---

## 7. Backend Services

### 7.1 BhulekBackend (Python 3.12 / FastAPI) — the main backend
- **Stack:** FastAPI + Gunicorn/Uvicorn; Playwright (headless Chromium) + BeautifulSoup/lxml for scraping; SQLAlchemy + Alembic + psycopg2 (Postgres prod / SQLite dev); PyJWT + cryptography + `app-store-server-library`.
- **Entry:** `main.py` → `app = create_app()` (`app.py` factory). Auto-creates tables, adds `StructuredLoggingMiddleware` + CORS (restricted in prod), mounts routers.
- **What it does:** real-time scraper + government-data gateway.
  - **RoR scraping** (`services/ror_service.py` + `scrapers/bhulekh_scraper.py`): drives Playwright against `bhulekh.ori.nic.in/RoRView.aspx` (ASP.NET WebForms), parses Odia/English HTML, runs a 3-level language-independent verification that fail-closes on mismatch.
  - **SOAP:** `resolvers/bhulekh_soap_resolver.py` (`resolve_khata_for_plot_soap`) + bundled WSDL for khata-for-plot resolution.
  - **IGR valuation:** `services/igr_benchmark_service.py` — benchmark valuations + registration-fee/stamp-duty estimates.
  - **Cadastral GIS:** `services/gis_router.py` dispatches per-state (Odisha 4K GEO / Bihar BhuNaksha) with fail-closed flags, returning GeoJSON.
  - **Monetization:** `usage_service` (server-authoritative monthly quotas/credits) + Apple StoreKit server verification (`apple_verification_service`, Apple root CAs from `certs/`).
- **Endpoints:** `GET /health`, `/ready` (checks DB + Apple certs), `/api/v1/health/providers`; `/api/v1/ror` (+`/ror/pdf`, `/ror/benchmark-valuation`, `/igr/*`), `/api/v1/gis/*`, plus `auth`/`usage`/`subscriptions`/`config`/`support`/`bhulekh_coverage`/`gis_navigation`/`location_search`. Rate limits: 60/min authed, 30/min anon; RoR PDF 10/min.
- **Resilience/caching:** three `TTLCache`s — `_cache` (2000 verified, 24h — **verified-only**), `_pdf_cache` (500, 24h), `_negative_cache` (1000 NOT_FOUND, 5min). SingleFlight coalescing (`_inflight_scrapes`), bounded queue (`MAX_PENDING_BHULEKH_REQUESTS`), concurrency semaphore (`BHULEKH_MAX_CONCURRENT`), cross-process POSIX `flock` global scrape lock (at most 1 Chromium scrape host-wide). `RoRErrorCode` → HTTP: NOT_FOUND→404, IDENTITY_MISMATCH/AMBIGUOUS→422, TIMEOUT→504, TEMPORARY_UNAVAILABLE→503, PARSE_FAILED→502. Timing headers `X-Backend-Duration-Ms`/`X-Upstream-Duration-Ms`/`X-Cache-Hit`.
- **Data:** Postgres/SQLite via SQLAlchemy; ~59MB `data/bhulekh_catalog/catalog_v3.json` statewide catalog loaded by the identity resolver.
- **Container:** `Dockerfile` = `python:3.12-slim`, installs deps + `playwright install chromium`, non-root user, EXPOSE 10000, `gunicorn main:app` with `UvicornWorker`, `--workers ${WORKERS:-2}`, `--timeout 120`.

### 7.2 OdishaAdminService (Node.js / Express 5) — reverse-geocoding microservice
- **Stack:** Express 5 (CommonJS), `pg` (PostgreSQL/PostGIS), `node-cache`, `axios`.
- **Entry:** `src/index.js` — mounts `src/routes/location.js` at `/`, adds `GET /health`, listens on `PORT || 3000`.
- **What it does:** single-purpose coordinate → Odisha admin hierarchy resolver. `GET /location-info?lat=&lng=` → `locationService.getLocationInfo` → node-cache (key `loc_{lat}_{lng}`, TTL 3600s) → PostGIS `ST_Contains(geom, ST_SetSRID(ST_MakePoint(lng,lat),4326))` on a `villages` table → **falls back to OpenStreetMap Nominatim** on DB failure. Returns district/tehsil/panchayat/village/village_code.

### 7.3 Deployment & CI
- **`render.yaml`:** Render Docker web service `mybhoomi-backend-prod`, rootDir `BhulekBackend`, region Singapore, plan **free**, healthCheck `/health`, autoDeploy. Env: `ENV=production`, generated `JWT_SECRET_KEY`/`ADMIN_API_KEY`, `APPLE_BUNDLE_ID=com.kirtidhwaj.Bhumitra`, `BHULEKH_MAX_CONCURRENT=3`, `MAX_PENDING_BHULEKH_REQUESTS=10`, `ROR_TIMEOUT_SECONDS=90`, etc.
- **`.github/workflows/ci.yml`:** on push/PR to `main` — `backend-tests` (Python 3.12, `pytest tests/`) + `secrets-audit` (greps for committed private keys). **Only `BhulekBackend` is tested.**
- **⚠️ Deployment target confusion (see §8):** `render.yaml` → Render; `BACKEND_DEPLOYMENT_AUDIT.md` → Cloud Run (asia-south1); the shipping iOS client → `api.prettyplot.in` (AWS EC2). `OdishaAdminService` runs on Cloud Run with **no Dockerfile/IaC in the repo and no CI coverage**.

---

## 8. Dependencies & Risk Register

### 8.1 Cross-cutting dependency map
- `MapViewModel` is the coupling hub: depends on `LocationSearchService`, `CadastralRepository`/`CadastralAPIClient`, `LocalAdminClient`, `RoRService`, `SavedLandManager`, `NetworkMonitor`, `AuthManager`, `GISExplorerViewModel`.
- `RoRService`, `CadastralAPIClient`, `GISExplorerRepository`, `LocationSearchService` all depend on `APIConfiguration.shared.baseURL`.
- The whole verified-record pipeline funnels through `ParcelCrossVerifier` → `VerifiedParcelCache` → `SavedLandManager`.
- The iOS app is **backend-dependent** for both hierarchy and resolution; offline it can only serve `VerifiedParcelCache`/`SavedLandManager` hits.

### 8.2 Risk register

| # | Risk | Location | Impact | Suggested mitigation |
|---|---|---|---|---|
| R1 | **Fuzzy identity matching** — hardcoded EN↔Odia transliteration tables + bidirectional substring `contains`; incomplete coverage, false-positive prone; effectively defers to backend `locationMatch` outside the enumerated set | `Services/ParcelCrossVerifier.swift` | Wrong or missed parcel↔RoR matches → showing/withholding wrong ownership data | Move canonical matching to the backend crosswalk catalog; replace substring with token/ID matching; add coverage tests |
| R2 | **Two parallel tap resolvers** with divergent logic and different MultiPolygon extraction (first vs largest polygon) | `MapLibreView.handleMapTap` vs `CadastralFeatureResolver.resolveTappedParcel` | Inconsistent parcel selection depending on code path | Consolidate on `CadastralFeatureResolver`; delete the inline builder |
| R3 | **Cache key format inconsistency** — colon-joined `canonicalKey` vs underscore-joined `SavedLandRecord.id`; zero-padded vs raw IDs | `CachedVerifiedParcel`, `SavedLandRecord`, `LocationSearchResult.init(from:)` | Cache misses or wrong hits when tracing identity across layers | Single canonical key builder shared by all persistence layers; normalize ID zero-padding |
| R4 | **Deployment target confusion** — Render vs Cloud Run vs AWS `api.prettyplot.in`; docs disagree with shipping config | `render.yaml`, `BACKEND_DEPLOYMENT_AUDIT.md`, `APIConfiguration.swift` | Deploys/monitoring may target a host the app doesn't use | Document the single source of truth; reconcile IaC to the real prod host |
| R5 | **Backend scalability** — single Chromium scrape host-wide (POSIX flock), Render **free** plan, synchronous 55–90s scrapes, `--workers 2` | `services/ror_service.py`, `render.yaml`, `Dockerfile` | Throughput bottleneck; queue rejections under load; cold starts | Horizontal scaling with distributed lock; async worker pool; paid tier |
| R6 | **OdishaAdminService has no CI and no IaC in repo** | `OdishaAdminService/` | Undocumented, untested deploy; drift risk | Add Dockerfile + CI + Nominatim usage-policy compliance |
| R7 | **Hardcoded values** — dev `style.json` absolute path (`/Users/uday/...`), LAN IP `10.138.60.242`, Cloud Run URL in `LocalAdminClient` | `MapLibreView.makeUIView`, `APIConfiguration`, `LocalAdminClient` | Machine-specific breakage; env leakage | Bundle-relative style path; move hosts to config |
| R8 | **Map tile licensing** — Google raster tiles (`mt1.google.com/vt`) used directly with logo/attribution hidden; OSM tiles direct | `MapLibreView.ensureBaseLayers` | Terms-of-service / attribution compliance exposure | Use a licensed tile provider or restore attribution |
| R9 | **Strict exact plot equality** rejects legitimate fraction/suffix variants (e.g. `1182` vs `1182/1`) | `ParcelCrossVerifier` | False "not verified" for valid parcels | Normalize plot numbers consistently on both sides |
| R10 | **Attribute schema fragility** — long fallback key chains across Odisha 4K GEO / Bihar BhuNaksha / bundled GeoJSON; a renamed key silently degrades identity | `CadastralFeatureResolver`, `handleMapTap`, `GeoJSONService` | Silent identity degradation on upstream schema change | Schema validation + contract tests against provider payloads |
| R11 | **59MB catalog** loaded by resolver | `BhulekBackend/data/bhulekh_catalog/catalog_v3.json` | Memory/startup cost per worker | Move to a queryable store (DB/index) instead of in-memory JSON |

### 8.3 Notable positive patterns
- **Fail-closed verification** end to end: ownership shown only when GIS parcel and RoR are proven the same parcel; `VerifiedParcelCache`/`CachedVerifiedParcel.init?` never store unverified/404/5xx records (asserted by tests).
- **SingleFlight coalescing** on both client and server prevents duplicate expensive scrapes.
- **Bearer + Keychain** token handling with no embedded secrets; CI secrets-audit.
- **Layered graceful fallback** (`LocalAdminClient` 3s → Apple geocoder; backend negative cache).
- **Bihar GIS hard-disabled** via `AppConfig.biharGisFeatureEnabled = false` (fail-closed feature flag).

---

## 9. Key File Index

| Concern | Primary files |
|---|---|
| App entry / boot | `MyBhoomi/MyBhoomiApp.swift`, `AppConfig.swift` |
| Central state | `Presentation/ViewModels/MapViewModel.swift`, `Presentation/Views/MainView.swift` |
| Networking config | `Services/APIConfiguration.swift` |
| RoR client | `Services/RoRService.swift`, `Domain/Models/RoRModels.swift` |
| Cadastral GIS client | `Services/GIS/CadastralAPIClient.swift`, `Data/Repositories/CadastralRepository.swift` |
| Map rendering | `Map/MapLibre/MapLibreView.swift`, `Map/MapLibre/CadastralFeatureResolver.swift` |
| Identity / verification | `Domain/Models/Parcel.swift`, `Services/ParcelCrossVerifier.swift` |
| Persistence | `Domain/Models/CachedVerifiedParcel.swift`, `Domain/Models/SavedLandRecord.swift`, `Data/Services/VerifiedParcelCache.swift` |
| Search / resolution | `Services/LocationSearchService.swift`, `Domain/Models/LocationSearchModels.swift` |
| Backend (RoR) | `BhulekBackend/app.py`, `routers/ror.py`, `services/ror_service.py`, `scrapers/bhulekh_scraper.py` |
| Backend (GIS) | `BhulekBackend/routers/gis.py`, `services/gis_router.py`, `models/gis_bhulekh_crosswalk.py` |
| Admin geocoder | `OdishaAdminService/src/index.js`, `src/services/locationService.js` |
| Deploy / CI | `render.yaml`, `.github/workflows/ci.yml`, `BhulekBackend/Dockerfile` |

---

*Generated from a read-only investigation of the codebase. No source files were modified.*
