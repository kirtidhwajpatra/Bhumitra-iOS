# Phase 4.02 — Map / Manual RoR Unification Report

## Executive Summary
In Phase 4.02, we unified the **Interactive Map Ownership Experience** with the **Manual Record of Rights (RoR) Search flow**. The Map parcel flow now directly converts authoritative backend `RoRResponse` into `OfficialSearchResult` and presents the exact same [`KhatianDetailView`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/KhatianDetailView.swift) used by Manual Search. 

No backend APIs, scraper routines, or manual search pipelines were altered. Zero duplicate network requests were introduced.

---

## 1. Files Changed

1. [`MyBhoomi/Presentation/ViewModels/OfficialLandRecordsViewModel.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/ViewModels/OfficialLandRecordsViewModel.swift):
   - Added shared initializer `init(ror: RoRResponse, identity: CanonicalParcelIdentity)` and explicit memberwise initializer to `OfficialSearchResult` to allow direct creation from `RoRResponse` in any presentation flow without code duplication.
2. [`MyBhoomi/Presentation/ViewModels/MapViewModel.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/ViewModels/MapViewModel.swift):
   - Updated `onCadastralParcelSelected(_ parcel: CadastralParcel)` to prioritize the parcel's own `districtID`, `blockID`, `villageID`, `districtName`, `blockName`, and `villageName`, with fallback to `activeCadastralVillage` metadata only when vector attributes are absent.
3. [`MyBhoomi/Presentation/Views/CadastralPlotCardView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/CadastralPlotCardView.swift):
   - Replaced old `showOwnersSheet` / `CleanOwnersModalSheet` with `selectedResultForDetail: OfficialSearchResult?` and presented `KhatianDetailView(result: result)`.
   - On successful `RoRService.shared.fetch(...)`, converted `RoRResponse` to `OfficialSearchResult` locally in memory.
   - Preserved background single-flight PDF prefetch and instant presentation if tapped while in-flight.
   - Removed deprecated `CleanOwnersModalSheet`.

---

## 2. Old Map Flow vs. New Map Flow

### Old Map Flow
$$\text{Map Parcel Tap} \rightarrow \text{CadastralPlotCardView} \rightarrow \text{RoRService.shared.fetch(...)} \rightarrow \text{RoRResponse stored in @State} \rightarrow \text{CleanOwnersModalSheet (Simplified modal)}$$
- Missing: Full Khatian detail view, Thana, RI Circle, Tenant details, Tenure classification, Remarks, Related Khatian plots list, and unified PDF actions.

### New Unified Map Flow
$$\text{Map Parcel Tap} \rightarrow \text{CadastralPlotCardView} \rightarrow \text{RoRService.shared.fetch(...)} \rightarrow \text{RoRResponse} \rightarrow \text{OfficialSearchResult} \rightarrow \text{KhatianDetailView}$$
- 100% Feature Parity with Manual Search:
  - Official Verified Record seal pill
  - Full Location Hierarchy (Khatian number, Village, Tahasil, District, Thana, RI Circle)
  - Tenant Section (Owner names, Share distributions, Tenure classification)
  - Remarks Section
  - Plots Section (All associated plots in the Khatian with areas)
  - Actionable Print / Download Official RoR PDF button

---

## 3. Shared Components

| Component | Role in Manual Flow | Role in Map Flow | Shared Status |
| :--- | :--- | :--- | :--- |
| **`RoRService.shared.fetch(...)`** | Network request to `/api/v1/ror` | Network request to `/api/v1/ror` | **100% Shared** |
| **`RoRResponse`** | Authoritative backend data model | Authoritative backend data model | **100% Shared** |
| **`OfficialSearchResult`** | View model container for result | View model container for result | **100% Shared** |
| **`KhatianDetailView`** | Official detailed presentation | Official detailed presentation | **100% Shared** |
| **`OfficialRoRPDFService`** | SingleFlight background prefetching | SingleFlight background prefetching | **100% Shared** |
| **`PDFDocumentManager`** | Disk caching and document SHA-256 validation | Disk caching and document SHA-256 validation | **100% Shared** |

---

## 4. Network Requests Before vs After

### Before
- Map tap triggered `GET /api/v1/ror` on appear.
- "View Owners" opened `CleanOwnersModalSheet` with local data.
- PDF download triggered `GET /api/v1/ror/pdf`.

### After
- Map tap triggers single `GET /api/v1/ror` on appear.
- "View Owners" opens `KhatianDetailView` using the cached `OfficialSearchResult` in memory without any additional network call.
- Background PDF prefetch continues using `OfficialRoRPDFService` single-flight coalescing; if already completed or in-flight, `KhatianDetailView` attaches directly to the task.

---

## 5. PDF Behavior
- When the map parcel card appears, `OfficialRoRPDFService.shared.fetchOrGetPDF(...)` starts a silent background prefetch using SingleFlight coalescing.
- When the user taps "View Owners", `KhatianDetailView` opens immediately without waiting for PDF downloading.
- If the PDF is already cached locally on disk, `KhatianDetailView` instantly shows "Official Document Ready" / "Open Official PDF".
- If the PDF is still downloading, `KhatianDetailView` shows the preparing progress indicator and transitions to ready upon download completion.

---

## 6. Test Results

### 6.1 Backend Test Suite Execution
- **Command**: `PYTHONPATH=. ../BhulekBackend/venv/bin/pytest tests` (from `BhulekBackend/`)
- **Results**: **566 passed**, 0 failed across all 45 test suites in 82.51s.
- **Coverage**: Includes auth, security, canonical parcel identity, concurrency, live dropdown hardening, iOS contract tests (`test_phase3_24_ios_ror_contract.py`), handoff tests (`test_phase3_29_parcel_identity_handoff.py`), and performance benchmarks.

### 6.2 Key Verification Scenarios
- `G_Dimbo` / Plot `489` $\rightarrow$ Verified RoR, exact Khatian, 1 holder, PDF available.
- `G_Dimbo` / Plot `508` $\rightarrow$ Verified RoR, exact Khatian, PDF available.
- `G_Dimbo` / Plot `671` $\rightarrow$ Verified RoR, exact Khatian, PDF available.
- `G_Keri 271` / Plot `1035` $\rightarrow$ Verified RoR, exact Khatian, PDF available.
- `G_Keri 271` / Plot `1050` $\rightarrow$ Verified RoR, exact Khatian, PDF available.

---

## 7. iOS Build Result
- **Command**: `xcodebuild -scheme MyBhoomi -project MyBhoomi.xcodeproj -destination 'generic/platform=iOS Simulator' build`
- **Result**: `** BUILD SUCCEEDED **` (0 errors).

---

## 8. Remaining Risks & Mitigations
- **Memory Retention on Repeated Taps**: Mitigated by `@State private var selectedResultForDetail: OfficialSearchResult?` and `.task(id: parcel.id)` which cleans and replaces state per selected parcel ID.
- **Network Flakiness**: Handled through backend exponential retry and client-level user retry actions.
