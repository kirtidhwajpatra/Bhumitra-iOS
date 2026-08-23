# PHASE 0: COMPLETE READ-ONLY PRODUCTION BASELINE AUDIT

**Repository:** `Bhumitra-iOS` (Odisha Cadastral GIS & Official Bhulekh Land Records)  
**Date:** 2026-08-22  
**Audit Scope:** Full Stack (iOS Swift Client + FastAPI Backend + ORSAC 4K GEO GIS + Playwright Bhulekh Scraper + Caching & Database)  
**Audit Mode:** Complete Read-Only Inspection (Zero Code/Logic/Config Mutations)

---

## 1. Executive Summary

A comprehensive, read-only baseline audit of the `Bhumitra-iOS` repository was conducted to investigate why parcel selections outside of Keonjhar frequently return incorrect or empty land records, report private plots as government land, or fail with "Level 6: Revenue village could not be resolved from official options".

### Root Finding
The application currently operates under a **two-system semantic divide**:
1. **The GIS Layer (ORSAC 4K GEO)** operates with **English/Romanized village names and 7-digit administrative census IDs** (e.g. District `104`, Block `1406`, Village `Hinjili 13` / `2803320`).
2. **The Land Records Portal (Bhulekh NIC Odisha)** operates with **Odia-script names and internal sequential form dropdown indices** (e.g. District `5`, Tahasil `1`, Mouza `88` / `ହିଞ୍ଜିଳି ୧୩`).

Because the identity bridging layer relies on **hardcoded static dictionaries** (`SCOPED_VILLAGE_ALIASES` with only ~15 villages, `BILINGUAL_VILLAGE_MAP` with only 11 villages, and `GIS_BLOCK_TO_TAHASIL` with only 13 Keonjhar blocks), **any parcel query in the remaining ~51,000 revenue villages across Odisha fails Level 0–5 resolution**. When resolution fails or times out, the client/backend fallbacks kick in:
- The backend returns `404 Not Found` or `502 Bad Gateway`.
- The iOS client catches the error and instantiates a **fallback baseline result** where `khatianNumber = "—"`, `area = "—"`, and `landType = "Stitiban"` (unsettled state baseline) with zero owners.
- If the user clicks "View Official RoR PDF", the client falls back to requesting **Khata `01` / `1`**, which in Odisha revenue records is almost universally **"ଓଡ଼ିଶା ସରକାର" (State of Odisha / Government Land)**, misleading the user into believing their private parcel is state-owned land.
- Furthermore, the iOS client-side cache (`rorCache`) caches full RoR responses against all associated plots in a Khata, causing subsequent taps on neighboring plots within the same Khata to display the first plot's land type and acreage.

---

## 2. Current Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       iOS CLIENT (SwiftUI)                                       │
│                                                                                                  │
│  ┌───────────────────────┐   Tap Coordinate    ┌───────────────────────────┐   Select Village    │
│  │   MapLibre Native     │ ──────────────────> │  CadastralFeatureResolver │ <────────────────┐  │
│  │   Vector Tile Layer   │                     │  (Extracts plot, v_id)    │                  │  │
│  └───────────────────────┘                     └─────────────┬─────────────┘                  │  │
│                                                              │ CanonicalParcelIdentity        │  │
│                                                              ▼                                │  │
│  ┌───────────────────────┐                     ┌───────────────────────────┐                  │  │
│  │ CadastralPlotCardView │ <────────────────── │  MapViewModel             │                  │  │
│  │ (Interactive Sheet)   │   Renders Sheet     │  (Inherits Active Village)│                  │  │
│  └───────────┬───────────┘                     └─────────────┬─────────────┘                  │  │
│              │                                               │                                │  │
│              │ loadRoR()                                     │ loadCadastralVillage()         │  │
│              ▼                                               ▼                                │  │
│  ┌───────────────────────┐                     ┌───────────────────────────┐                  │  │
│  │ RoRService.swift      │ ──────────────────> │ LiquidGlassLocationPicker │ ─────────────────┘  │
│  │ (URLSession + Cache)  │                     │ (4-Level Accordion)       │                     │
│  └───────────┬───────────┘                     └───────────────────────────┘                     │
└──────────────┼───────────────────────────────────────────────────────────────────────────────────┘
               │ HTTP GET /api/v1/ror (district, tahasil, village, plot, b_id, v_id)
               ▼
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   FASTAPI BACKEND (Python 3.11+)                                 │
│                                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ routers/ror.py -> services/ror_service.py                                                  │  │
│  │  1. Canonical Cache Check (district_tahasil_village_plot)                                  │  │
│  │  2. In-Flight SingleFlight Coalescing & Rate Limiting                                      │  │
│  │  3. Playwright Headless Browser Worker Pool                                                │  │
│  └──────────────────────────────────────────────┬─────────────────────────────────────────────┘  │
│                                                 │                                                │
│                                                 ▼                                                │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ resolvers/bhulekh_identity_resolver.py (BhulekhVillageResolver)                            │  │
│  │  • Level 0: VerifiedBhulekhCatalog (catalog_v3.json - 51,826 Odia records)                 │  │
│  │  • Level 1: 7-digit / Exact GIS Village ID Mapping                                         │  │
│  │  • Level 2: Exact Name Match                                                               │  │
│  │  • Level 3: Normalized Name Match                                                          │  │
│  │  • Level 4: Scoped Canonical Aliases (SCOPED_VILLAGE_ALIASES - 15 entries)                 │  │
│  │  • Level 5: Bilingual Odia Map (BILINGUAL_VILLAGE_MAP - 11 entries)                        │  │
│  │  • Level 6: Fail-Closed (NOT_FOUND)                                                        │  │
│  └──────────────────────────────────────────────┬─────────────────────────────────────────────┘  │
│                                                 │                                                │
│                                                 ▼                                                │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ scrapers/bhulekh_scraper.py (Live DOM Automation against http://bhulekh.ori.nic.in/)       │  │
│  │  • ddlDistrict -> ddlTahsil -> ddlVillage -> rbPlot -> ddlPlot -> btnRORFront              │  │
│  └──────────────────────────────────────────────┬─────────────────────────────────────────────┘  │
│                                                 │                                                │
│                                                 ▼                                                │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ scrapers/structured_ror_parser.py                                                          │  │
│  │  • Verification: verify_ror_result (Location + Plot confirmation)                          │  │
│  │  • Front Page: Khata No, Landlord, Raiyats / Tenants (gvfront), Status/Tenure              │  │
│  │  • Back Page: Associated Plots & Area (gvRorBack)                                          │  │
│  └────────────────────────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Complete Parcel Data Flow

| Step | Layer / Component | Input | Output | Source of Truth | Matching Method | Fallback Behavior | Failure Behavior | Identity Type |
|---|---|---|---|---|---|---|---|---|
| **1. Map Tap** | `MapLibreView.swift` | Screen touch `CGPoint`, GPS `CLLocationCoordinate2D` | `[MLNFeature]` vector polygons | Vector tile server (ORSAC 4K GEO) | Point-in-polygon bounding box query | Nearest feature if point on boundary | Ignored if no feature | Inferred |
| **2. Feature Extraction** | `CadastralFeatureResolver.swift` | `[MLNFeature]` attributes | `CadastralParcel` (`plotNumber`, `v_id`, `p_id`) | Vector tile attributes (`revenue_plot`, `v_id`) | Attribute key extraction | Empty string for missing administrative attributes | Drops candidate if no plot number | Inferred |
| **3. Parcel Identity Handoff** | `MapViewModel.onCadastralParcelSelected` | `CadastralParcel` + `activeCadastralVillage` | `CanonicalParcelIdentity` | `MapViewModel.activeCadastralVillage` | Priority cascading | Empty string / `"Odisha"` | Sheet rendered with partial info | Inferred |
| **4. iOS RoR Service** | `RoRService.fetch` | `CanonicalParcelIdentity` | URL request `/api/v1/ror` | Local Swift actor `rorCache` | Key: `district_tahasil_village_plot` | Bypasses cache if cold | Network error thrown | Exact URL |
| **5. Backend Router** | `routers/ror.py` | Query params (`district`, `tahasil`, `village`, `plot`, `b_id`, `v_id`) | Validated sanitized strings | Request parameters | String validation & length limits | Rejection | HTTP 400 | Parametric |
| **6. Backend Cache** | `services/ror_service.py` | Canonical key | `RoRResponse` (if cached) | In-memory `_cache` / `_negative_cache` | Hash equality | Proceeds to live scrape | Negative cache rethrows cached error | Exact key |
| **7. District & Tahasil Resolution** | `bhulekh_mappings.py` & `bhulekh_identity_resolver.py` | `district`, `tahasil`, `b_id` | `district_id` (e.g. `"5"`), `tahasil_id` (e.g. `"1"`) | `DISTRICT_MAP`, `TAHASIL_MAP`, `OFFICIAL_DISTRICT_NAMES` | Direct & Normalized key lookup | 4-digit GIS block suffix stripping | HTTP 404 / 500 (Tahasil not found) | Exact |
| **8. Mouza / Village Resolution** | `BhulekhVillageResolver.resolve_mouza_option` | `district_id`, `tahasil_id`, `village`, `v_id`, Live Dropdown Options | `matched_opt` (Bhulekh Mouza ID & Text) | Live HTML `<select id="ddlVillage">` | 6-Level Priority Cascade (Catalog -> ID -> Exact -> Normalized -> Alias -> Bilingual) | Level 6 Fail-Closed | `ValueError: Level 6 could not be resolved` -> HTTP 502 | Deterministic / Inferred |
| **9. Plot Dropdown Selection** | `bhulekh_scraper.py` | `plot` string | Selected `<select id="ddlPlot">` | Live HTML `<select id="ddlPlot">` | Exact string equality on option text | Textbox `#txtPlotNo` entry | `ValueError: Plot not found` -> HTTP 404 | Exact |
| **10. RoR Front Page Retrieval** | `bhulekh_scraper.py` | Form submission (`btnRORFront`) | HTML DOM string | Bhulekh ASP.NET ViewState Response | HTTP POST / Form postback | Network timeout retry (up to 3 attempts) | HTTP 504 / 502 | Official Portal |
| **11. RoR Verification** | `structured_ror_parser.py` -> `verify_ror_result` | HTML DOM + Target Location & Plot | `RoRVerification` (`.verified` / `.mismatch`) | Scraped HTML text | Location containment & plot regex matching | Permissive if header labels missing | `ValueError: Unable to verify parcel` -> HTTP 422 | Inferred |
| **12. Structured Parsing** | `structured_ror_parser.py` | Verified HTML DOM | `RoRResponse` (`owners`, `khata_number`, `plots`, `land_type`, `area`) | `#gvfront` (tenants), `#gvRorBack` (plots), `#lblKhatiyanslNo` | Table parsing, Odia regex, delimiter splitting | Landlord assigned to owners if rayat table empty | Throws if no owner and no khata | Scraped Data |
| **13. iOS Presentation** | `CadastralPlotCardView.swift` & `KhatianDetailView.swift` | `RoRResponse` JSON | Liquid Glass UI Sheet & Detail Views | Received JSON payload | Direct field binding | Default `"Stitiban"` for landType, `"—"` for area/khatian | Displays placeholder state | Client View |

---

## 4. Sources of Truth

| Source | Official? | Entities Provided | Identifier Types | Village Identification | Parcel Identification | Matching Strategy | Fallback Risk |
|---|---|---|---|---|---|---|---|
| **ORSAC 4K GEO GIS** | Yes (State Remote Sensing Agency) | Spatial Boundaries, Centroids, Revenue Plots, GIS Codes | ORSAC internal IDs (`104`, `1406`, `2803320`), `p_id`, `revenue_plot` | 7-digit code (e.g. `2803320`) and English Name (`"Hinjili 13"`) | Spatial polygon + `revenue_plot` string | Spatial Point-In-Polygon + GeoJSON Feature ID | High: Lacks administrative district/block names on individual vector features |
| **Bhulekh Odisha Portal (`bhulekh.ori.nic.in`)** | Yes (Revenue & Disaster Management Dept) | Legal Title, Khatiyan, Raiyat Names, Shares, Land Class (Kisam), Rent/Cess | Form dropdown indices (`ddlDistrict="5"`, `ddlTahsil="1"`, `ddlVillage="88"`, `ddlPlot="2707"`), Khata No | Odia script Mouza name (`"ହିଞ୍ଜିଳି ୧୩"`) & form index (`"88"`) | Plot number selected from form dropdown | Exact form postback | High: Portal requires active ViewState session; dropdown values change dynamically |
| **`catalog_v3.json` (Backend Catalog)** | Derived from Live Crawl (51,826 entries) | Mappings between ORSAC district/tahasil and Bhulekh Mouza IDs | District ID, Tahasil ID, Mouza ID, Odia Mouza Name | Odia script name + Mouza ID | None (Village level only) | Exact tuple lookup `(did, tid, mouza_id)` | Medium: Keyed primarily by Odia script name; English GIS names miss direct lookup |
| **`SCOPED_VILLAGE_ALIASES` (In-Memory)** | Curated Static Code | Hardcoded alias overrides for 15 villages (Keonjhar, Cuttack, Khurda, Puri, Ganjam) | English GIS name string -> Bhulekh target name | Normalized string lookup `(did, tid, normalized_name)` | None | Normalized dictionary key match | Critical: Incomplete; covers <0.03% of Odisha's revenue villages |
| **`BILINGUAL_VILLAGE_MAP` (In-Memory)** | Curated Static Code | 11 bilingual Odia <-> English name pairs | Odia string -> English string | Exact string equality | None | Dictionary key match | Critical: Incomplete; only 11 entries |

---

## 5. GIS → Bhulekh Identity Mapping

### Resolution Level Architecture

```
Incoming GIS Village ("Hinjili 13", ID: "2803320", Tahasil: "Hinjilicut", District: "Ganjam")
   │
   ▼
[Level 0: Verified Catalog Lookup] ─────────► Fails: Catalog entries indexed by Odia script ("ହିଞ୍ଜିଳି ୧୩")
   │
   ▼
[Level 1: 7-digit Village ID Mapping] ──────► Fails: 2803320 -> suffix 320 != Bhulekh dropdown index 88
   │
   ▼
[Level 2: Exact Name Match] ────────────────► Fails: "Hinjili 13" != "ହିଞ୍ଜିଳି ୧୩"
   │
   ▼
[Level 3: Normalized Name Match] ───────────► Fails: "HINJILI 13" != "ହିଞ୍ଜିଳି ୧୩"
   │
   ▼
[Level 4: Scoped Canonical Alias] ──────────► Fails: Not in SCOPED_VILLAGE_ALIASES (only 15 entries)
   │
   ▼
[Level 5: Bilingual Odia Map] ──────────────► Fails: Not in BILINGUAL_VILLAGE_MAP (only 11 entries)
   │
   ▼
[Level 6: Fail-Closed (NOT_FOUND)] ─────────► RETURNS ERROR 502 / NOT RESOLVED
```

### Safety Evaluation of Matching Mechanisms

1. **Exact String Match (`Level 2`)**: **SAFE**. Never produces false positives, but fails when comparing Romanized names to Odia script.
2. **Normalized Match (`Level 3`)**: **SAFE**. Normalizes whitespace, case, hyphens, and standard English transliterations.
3. **Scoped Canonical Aliases (`Level 4`)**: **SAFE BUT EXTREMELY INCOMPLETE**. Scoped to `(district_id, tahasil_id)` preventing cross-district leakage, but only 15 villages exist in code.
4. **Bilingual Map (`Level 5`)**: **SAFE BUT EXTREMELY INCOMPLETE**. Only 11 villages defined.
5. **Substring / Contains Matching (in `verify_ror_result` & `ParcelCrossVerifier.swift`)**: **UNSAFE FOR LAND OWNERSHIP**.
   - `norm_req_v in norm_ret_v or norm_ret_v in norm_req_v` allows `"DIMBO"` to match `"G_DIMBO"`, but also allows `"BARI"` to match `"BARIPADA"` or `"PURI"` to match `"PIPILI"`.
   - `distMatch = normRorDist.contains(normGisDist)` can match unrelated districts with shared prefixes.

---

## 6. Plot Matching Logic

### How GIS Plot Becomes Bhulekh Plot
1. The user taps a polygon on the map.
2. `MapLibreView.swift` queries the vector tile layer and extracts `revenue_plot` (e.g. `"2707"`, `"12/1"`, `"489"`).
3. The raw string is trimmed of leading/trailing whitespace (`clean_target_plot = plot.strip()`).
4. In `bhulekh_scraper.py` (Step 5):
   - Scans `<select id="ddlPlot">` options for **exact string match** (`[o for o in opts if o["text"] == clean_target_plot]`).
   - If exactly 1 match: selects option.
   - If >1 match: raises `ValueError("Ambiguous plot number")`.
   - If 0 matches: falls back to typing into `#txtPlotNo` textbox.
5. In `verify_ror_result`:
   - Checks `#lblPlotNo` or table cells `<td>` for confirmation.

### Vulnerabilities in Plot Matching
1. **False Positive Plot Verification in `verify_ror_result`**:
   - `verify_ror_result` iterates over **every `<td>` cell in the HTML page** searching for `target_clean`.
   - If the requested plot is `"12"`, and the page contains an area of `"0.12"`, a tenant serial number `"12"`, rent of `"12"`, or another plot `"120"` whose substring contains `"12"`, `returned_plot` gets set to `"12"`, falsely verifying an unrelated page!
2. **Plot Sub-Division Truncation (`12/1` vs `12`)**:
   - If a parcel in GIS is sub-divided (`"12/1"` or `"12/A"`), but Bhulekh lists it as `"12"`, exact matching fails unless properly normalized.
   - Conversely, regex extraction `([0-9]+(?:/[0-9]+)?[A-Za-z]?)` in table search can match `"12/1"` when `"12"` was requested if delimiter boundaries are missing.

---

## 7. Owner Extraction Logic

### Extraction Hierarchy (`structured_ror_parser.py`)
1. **Front Page Table (`#gvfront`)**:
   - Parses each row: `#lblName` (Raiyat name) and `#lblShare` (fractional share, e.g. `0.500`).
   - Splits joint tenant cells on commas and newlines (`split_cell_names`).
   - Strips relation noise (`S/O`, `W/O`, `D/O`, `ପିତା-`, `ସ୍ୱାମୀ-`).
2. **Odia Plain-Text Format**:
   - Searches regex for `2) ପ୍ରଜାର ନାମ, ପିତାର ନାମ...` and splits on Odia relation delimiters (`ପି:`, `ପିତା:`, `ସ୍ଵାମୀ:`, `ଜା:`).
3. **Landlord / Government Land Fallback (Lines 298–301)**:
   - If `owners` table is empty but `#lblLandlordName` is present:
     `owners.append(OwnerEntry(name=landlord, share="1.000", khata_number=khata_number))`

### How Wrong Owners or False "Government Land" Occur
1. **RoR Lookup Failure -> Khata 01 Fallback**:
   - When a private plot lookup fails due to village mismatch, the UI card shows empty owners.
   - When the user taps "View Official RoR PDF", line 534 of `CadastralPlotCardView.swift` executes:
     `let khata = displayKhatian == "—" ? "01" : displayKhatian`
   - Khata `01` in Odisha land records is reserved for **"ଓଡ଼ିଶା ସରକାର" (State of Odisha)**.
   - The PDF generator fetches Khata 01, parses Landlord: "Odisha Government", and displays the private plot as State Land.
2. **Khata-Level Multi-Owner Association**:
   - An RoR in Odisha is issued per **Khata (Account)**, which can contain multiple plots.
   - All owners on a Khata jointly own the land in that account, but individual sub-plots may have distinct tenant possession remarks recorded in the back page (`gvRorBack`). The current parser assigns all Khata-level owners to all plots in that Khata without distinguishing plot-specific tenancy remarks.

---

## 8. Land Classification Logic

### Sources of Land Classification (Kisam / Status)
1. **Back Page (`#gvRorBack`)**:
   - Column 2 contains Kisam (e.g. `Sarada Dofasala`, `Gharabari`, `Taila`, `Bila`, `Gochar`, `Rakhita`, `Patita`).
   - This is the **authoritative plot-specific land classification**.
2. **Front Page (`#lblStatua` / Status)**:
   - Contains general tenancy status (e.g. `Stitiban` / Settled Rayat, `Bebandobasta`, `Khasmahal`).
3. **Fallback in `structured_ror_parser.py` (Line 274)**:
   - `if not land_type and tenure: land_type = tenure`
4. **Fallback in iOS Client (`CadastralPlotCardView.swift` Line 79)**:
   - `return rorResponse?.rawFields?["tenure"] ?? "Stitiban"`

### Why Private Land is Reported as Government Land
1. When scraping fails to load `#gvRorBack` (because only `#btnRORFront` is clicked on initial view), `target_plot_record` is `None`, so `land_type` falls back to `tenure`.
2. If `tenure` is `"Rakhita"` (Protected / Government) or `"Sarbasadharana"` (Public Commons), private plots located within composite survey units get mislabeled.
3. Conversely, if RoR loading fails completely, the iOS client defaults to `"Stitiban"`, falsely assuring users that an unverified parcel is private settled land.

---

## 9. Cache Architecture

| Cache Location | Cache Key Format | Value Stored | TTL | Invalidation Strategy | Plot/Khata Collision Risk | Cross-User Leakage Risk |
|---|---|---|---|---|---|---|
| **Backend Memory (`_cache` in `ror_service.py`)** | `SHA256(canonical_key)` where key = `D_T_V_P_B_V` | Serialized `RoRResponse` | Process lifetime (in-memory `dict`) | Cleared on server restart; negative cache expires in 300s | **Low**: Key incorporates exact plot string and village ID | **Low**: In-memory data is read-only public government records |
| **Backend Negative Cache (`_negative_cache`)** | `SHA256(canonical_key)` | `RoRServiceException` | 300 seconds | Time-based via `time.time()` check | **Low** | **Low** |
| **iOS Swift Actor (`rorCache` in `RoRService.swift`)** | `"\(district)_\(tahasil)_\(village)_\(plot)"` | `RoRResponse` struct | In-memory lifetime | Cleared on app termination | **CRITICAL (Cross-Plot Collision)**: Lines 372–377 populate `rorCache[pKey] = decoded` for **every associated plot in the same Khata**. Because `decoded` contains Plot A's area and land classification, tapping Plot B returns Plot A's area and land type! | **Low** (Single device) |
| **iOS Location Cache (`villageCache` in `OfficialLandRecordsViewModel`)** | `"\(blockID)_\(gpID ?? "all")"` | `[CadastralVillage]` | In-memory lifetime | Cleared on `resetAll()` | **Low** | **Low** |

---

## 10. iOS State & Request Lifecycle

### Concurrency & Async Race Condition Audit

```
Scenario: User rapidly taps Plot 12, then taps Plot 15

Time t0: User taps Plot 12 -> loadRoR() Task 1 launched
Time t1: User taps Plot 15 -> selectedParcel updated to Plot 15 -> loadRoR() Task 2 launched
Time t2: Task 2 completes -> self.rorResponse = Response 15, self.isLoadingRoR = false
Time t3: Task 1 completes (delayed) -> self.rorResponse = Response 12!
Result: Card for Plot 15 displays RoR data of Plot 12!
```

### Analysis of `CadastralPlotCardView.swift`
- `loadRoR()` is called in `.task(id: parcel.id)`.
- While SwiftUI's `.task(id:)` cancels the previous task upon `parcel.id` mutation, `RoRService.shared.fetch` uses `URLSession.shared.data(for: request)` which continues executing over the wire unless explicitly cooperatively checked via `Task.isCancelled`.
- `officialSearchResult` and `rorResponse` are stored in `@State` properties inside `CadastralPlotCardView`. If the sheet view is not destroyed between taps, stale responses from previous plot requests can overwrite newer selections.

---

## 11. Existing Test Coverage

### Backend Test Suite Breakdown (`BhulekBackend/tests/`)

| Category | File Count | Tests | Scope & Focus | Limitations / What is NOT Proven |
|---|---|---|---|---|
| **A. Unit Tests** | 8 | 42 | CRU conversion, coordinate math, regex parsing, rate limiter counters | Uses synthetic inputs; does not prove live portal correctness |
| **B. Mock Integration Tests** | 12 | 68 | FastAPI endpoints using `TestClient` with mocked scraper responses | Verifies HTTP status codes and JSON serialization; does not verify live data |
| **C. Scraper & Parser Tests** | 10 | 45 | Parsing static HTML fixture files (`test_structured_ror_parser.py`) | Fixtures are almost exclusively from **Keonjhar (G_Dimbo / Keri)**; 29 districts have zero HTML fixture coverage |
| **D. Catalog & Identity Tests** | 8 | 32 | `catalog_v3.json` structure, alias lookups, bilingual mapping tables | Only tests that catalog entries load; does not test live resolution of English GIS names against Odia catalog |
| **E. Live / Benchmark Probes** | 7 | 24 | Scripts run against live `bhulekh.ori.nic.in` | Concentrated on sample plots in Keonjhar (plots `489`, `508`, `671`, `1035`, `1050`, `12`); cross-district live coverage is non-existent |

### Geographic Representation in Tests
- **Districts tested live:** 1 of 30 (Keonjhar extensively; Balasore/Cuttack smoke tested).
- **Tahasils represented in test fixtures:** 2 of 317 (Keonjhar Sadar, Athagarh).
- **Villages represented in test fixtures:** 4 of ~51,000 (G_Dimbo, Keri, Dimbo, Anantapur).
- **False-positive security tests:** 3 tests (verifies that invalid characters and oversized plot strings are rejected).

---

## 12. Existing Phase 3.x Validation Coverage

| Phase Report | Focus | What Was Tested | Live vs Mocked | Real-World Validity | Limitation |
|---|---|---|---|---|---|
| **Phase 3.19C** | Authenticity Audit | Scraped HTML vs official portal DOM | Live | Proven for Keonjhar Sadar | Tested only 5 plots in G_Dimbo |
| **Phase 3.19F** | Bilingual Live Report | English <-> Odia script resolution | Live | Proven for 4 hardcoded villages | Relies on static `BILINGUAL_VILLAGE_MAP` |
| **Phase 3.19H / 3.19J** | Catalog Crawl Report | Crawling 51,826 Bhulekh dropdowns | Live crawl | Verified portal dropdown tree structure | Crawled data stored in Odia script; no automated mapping to English GIS layers |
| **Phase 3.20** | Live Benchmark | End-to-end latency & concurrency | Live | Proven for 50 concurrent requests | Only requested Keonjhar G_Dimbo plots |
| **Phase 3.24** | iOS Contract Test | JSON response contract matching Swift models | Mocked | Proven API schema compatibility | Did not test live iOS app over network |
| **Phase 3.28** | Good vs Failed Analysis | Scraper failure modes on timeout | Live | Proven error classification | Evaluated failure recovery, not correctness of returned data |
| **Phase 3.30** | Odisha-Wide Validation | Catalog loading across 30 districts | In-memory | Proven catalog schema uniformity | **False sense of security:** Tested catalog dictionary presence, NOT live GIS-to-Bhulekh matching |

---

## 13. Known Weaknesses

1. **English-to-Odia Transliteration Gap**:
   - ORSAC GIS provides village names in English (e.g. `"Baraguda-47"`, `"Biridi-16"`, `"Hinjili 13"`).
   - Bhulekh dropdowns provide mouza names in Odia (e.g. `"ବରଗୁଡା"`, `"ବିରିଡି"`, `"ହିଞ୍ଜିଳି"`).
   - Without an automated, authoritative phoneme-aware transliteration engine or bilingual index, name matching fails for ~99.9% of Odisha villages.
2. **Khata 01 Government Land Fallback**:
   - Falling back to Khata `01` when plot lookup fails falsely displays private parcels as Government of Odisha land.
3. **Cross-Plot Cache Pollution**:
   - Caching a single Khata response under all associated plot keys overwrites plot-specific acreage and land classification for neighboring plots.
4. **Table-Wide Substring Search in Plot Verification**:
   - Searching all `<td>` cells for numeric plot strings matches areas, serial numbers, and cess values instead of actual plot numbers.

---

## 14. Ranked Failure Points & Risks

### [CRITICAL] Risks
*Can cause Bhumitra to show another person's land/ownership or incorrect government/private classification.*

1. **`SCOPED_VILLAGE_ALIASES` & `BILINGUAL_VILLAGE_MAP` Coverage Void**:
   - **Files:** [`bhulekh_identity_resolver.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/resolvers/bhulekh_identity_resolver.py#L81-L133), [`bhulekh_scraper.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_scraper.py#L479-L498)
   - **Mechanism:** Only ~15 villages have alias entries. All other ~51,000 villages fail Level 0–5 resolution, causing 100% lookup failure outside test villages.
2. **Khata 01 PDF Fallback Misclassifying Land as Government Land**:
   - **Files:** [`CadastralPlotCardView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/CadastralPlotCardView.swift#L534)
   - **Mechanism:** `displayKhatian == "—" ? "01" : displayKhatian` downloads Khata 01 (State of Odisha / Government Land) for unverified plots.
3. **Cross-Plot Khata Cache Pollution**:
   - **Files:** [`RoRService.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Services/RoRService.swift#L372-L377)
   - **Mechanism:** Caches full `RoRResponse` (containing Plot A's specific area and land type) under all other associated plot numbers in the Khata.
4. **False Positive Plot Verification via Global Cell Text Matching**:
   - **Files:** [`bhulekh_scraper.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_scraper.py#L101-L113)
   - **Mechanism:** Any `<td>` containing the plot number string (e.g. `"12"` in `"0.12 Acre"`) falsely verifies the parcel.

---

### [HIGH] Risks
*Can cause wrong parcel identity or unreliable results.*

5. **Substring Matching in Location Verification**:
   - **Files:** [`bhulekh_scraper.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_scraper.py#L140-L143), [`ParcelCrossVerifier.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Services/ParcelCrossVerifier.swift#L102-L120)
   - **Mechanism:** `norm_req_v in norm_ret_v` allows short village names to match completely different revenue villages.
6. **Async Race Condition on Swift Plot Selection**:
   - **Files:** [`CadastralPlotCardView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/CadastralPlotCardView.swift#L455-L501)
   - **Mechanism:** Rapid consecutive taps allow delayed asynchronous responses to overwrite newer selections.
7. **`isVerified` Badge Granted on Unverified Success Responses**:
   - **Files:** [`CadastralPlotCardView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/CadastralPlotCardView.swift#L48)
   - **Mechanism:** `rorResponse?.verification?.status == .verified || (rorResponse?.success == true)` displays "Official / Verified" even when verification failed.

---

### [MEDIUM] Risks
*Reliability, performance, and maintainability issues.*

8. **Missing `#gvRorBack` Extraction on Front Page View**:
   - **Files:** [`structured_ror_parser.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/structured_ror_parser.py#L241-L247)
   - **Mechanism:** When front page is scraped without loading the back page, plot acreage is `nil`, defaulting client display to `"—"`.
9. **Single In-Flight Playwright Worker Queue Saturation**:
   - **Files:** [`ror_service.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/services/ror_service.py#L153-L161)
   - **Mechanism:** Concurrency limit of 5 simultaneous browser instances causes HTTP 429 under multi-user load.

---

### [LOW] Risks
*Non-critical cleanup.*

10. **Residual Hardcoded Coordinate Centroids in Map Defaults**:
    - **Files:** [`StateSelectorView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/StateSelectorView.swift#L56), [`AppConfig.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/AppConfig.swift#L9)

---

## 15. What is Already Good (DO NOT REWRITE)

1. **MapLibre Native Cadastral Vector Rendering**:
   - High-performance vector tile rendering, smooth zooming, dynamic polygon styling, and crisp boundaries.
2. **Apple-Grade Liquid Glass UI & Design System**:
   - Seamless Dark/Light appearance adaptation, fluid spring animations, and native typography pairing.
3. **Database Schema & StoreKit Subscription Infrastructure**:
   - Robust Apple JWS App Store receipt verification, PostgreSQL subscription tracking, and monthly quota enforcement.
4. **FastAPI Architecture & SingleFlight Request Coalescing**:
   - Clean async route structure, deduplication of concurrent duplicate requests, and structured error payloads.

---

## 16. Recommended Correction Order

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Phase 1: Deterministic Identity & Transliteration Engine                   │
│   1. Build automated English <-> Odia phonemic transliteration matcher.     │
│   2. Map all 51,826 catalog entries to normalized English & Odia keys.      │
│   3. Eliminate hardcoded SCOPED_VILLAGE_ALIASES and BILINGUAL_VILLAGE_MAP.  │
├─────────────────────────────────────────────────────────────────────────────┤
│  Phase 2: Fix False Government Land & PDF Fallbacks                         │
│   1. Remove Khata "01" fallback in CadastralPlotCardView.swift.             │
│   2. Display explicit "Unverified / Record Unavailable" instead of Stitiban.│
│   3. Correctly scrape gvRorBack to obtain true plot acreage and Kisam.      │
├─────────────────────────────────────────────────────────────────────────────┤
│  Phase 3: Cache & Concurrency Hardening                                     │
│   1. Fix iOS rorCache to never overwrite distinct plot keys in same Khata.  │
│   2. Add cancellation check / task ID stamping to prevent async race.       │
│   3. Restrict plot verification to exact table column headers (no td scan). │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 17. Proposed Phase 1 Test Strategy

Before implementing code modifications, a deterministic test harness must be established covering:
1. **Statewide Multi-District Matrix**: At least 5 live verified villages per district across all 30 districts of Odisha (150 total villages).
2. **Negative Boundary Tests**: 30 test cases verifying that mismatched villages or invalid plots strictly fail-closed (`NOT_FOUND`) without defaulting to Government Land.
3. **Sub-Plot & Fractional Share Tests**: Verifying sub-plots (`12/1`, `12/A`) and multi-rayat joint accounts.
4. **Cache Isolation Tests**: Verifying that selecting consecutive plots in the same Khata yields distinct plot acreages and classifications.

---

## 18. Production-Readiness Blockers

1. **Statewide Village Resolution Failure**: Lookup fails for >99% of revenue villages outside Keonjhar due to English-Odia script mismatch.
2. **False Government Land Mislabelling**: Private plots are presented as State Land due to Khata 01 fallback.
3. **Client Cache Cross-Contamination**: Neighboring plots in the same Khata receive incorrect land types and areas.
4. **Permissive Verification**: Substring matching in plot verification can verify the wrong parcel.

---

## 19. Final Audit Determination

```
================================================================================
CURRENT PRODUCTION READINESS: 38 / 100
================================================================================
APP STORE STATUS: NO-GO (CRITICAL ACCURACY BLOCKERS)
================================================================================
```

**Conclusion:** The application possesses an exceptional user interface, robust GIS rendering, and a solid backend foundation. However, because land ownership data is legally sensitive, the current identity resolution gaps, false government land fallbacks, and client caching collisions represent critical blockers that must be resolved prior to production release.
