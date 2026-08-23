# PHASE 7.27.1 — PRE-FETCH OFFICIAL RoR DURING PARCEL VERIFICATION

**Status**: IMPLEMENTATION COMPLETE & VERIFIED ON PHYSICAL IPHONE  
**Target Platform**: Bhumitra Core (FastAPI Backend + OfficialDocumentCache + iOS Swift)

---

## 1. Architectural Transformation

### Previous Inefficient Flow:
```text
User taps plot
      ↓
Fetch official RoR (Playwright scrape #1)
      ↓
Display parsed RoR details
      ↓
User taps "Download Official RoR (PDF)"
      ↓
Trigger SECOND Playwright scrape (#2) ❌
      ↓
Slow, redundant portal navigation, prone to 502/504 errors
```

### New Unified Pipeline:
```text
User taps plot
      ↓
GET /api/v1/ror
      ↓
Single Playwright session opens Bhulekh & verifies parcel
      ↓
Capture official Front & Back pages HTML
      ↓
Parse structured data (Khata, Area, Land Type, Owners)
      ↓
Run verification layer (`verify_ror_result`)
      ↓
If VERIFIED:
  1. Render official Bhulekh page to PDF bytes within the SAME session
  2. Store PDF in server-side `OfficialDocumentCache` keyed by canonical identity (e.g. `3:4:196:1110`)
  3. Populate `official_document` metadata (`document_id`, `ready: true`) in JSON response
      ↓
iOS displays detailed RoR screen + silently prefetches PDF in background
      ↓
User taps "Download Official RoR"
      ↓
GET /api/v1/ror/official-document/{document_id}
      ↓
Delivered directly from cache in ~50ms (ZERO SECOND SCRAPING!)
      ↓
iOS Share / Save / Preview opens instantly
```

---

## 2. Key Changes Implemented

1. **[`services/official_document_cache.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/services/official_document_cache.py)**:
   - Implemented thread-safe `OfficialDocumentCache` combining in-memory `TTLCache` (24h TTL) and disk persistence (`data/document_cache/`).
   - Keyed strictly by canonical identity (`district_id:tahasil_id:village_id:plot`, e.g. `3:4:196:1110`).
   - Strict isolation ensures distinct villages with identical plot numbers (e.g., Chandakuda Plot 241 vs Utkuda Plot 241) cannot leak documents.

2. **[`scrapers/bhulekh_scraper.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_scraper.py)**:
   - Added Step 9 in `_scrape()`: After verification succeeds, the official page DOM is rendered to PDF bytes within the active Playwright page.
   - Populates `OfficialRoRDocument` metadata with `ready=True` and stores the PDF in `OfficialDocumentCache`.

3. **[`routers/ror.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/routers/ror.py)**:
   - Added dedicated fast endpoint: `GET /api/v1/ror/official-document/{document_id:path}`.
   - Optimized legacy `/ror/pdf` with a fast-path cache lookup before attempting any browser initialization.

4. **[`models/ror_response.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/models/ror_response.py)**:
   - Added `OfficialRoRDocument` model to the standard API schema.

5. **iOS Client (`MyBhoomi`)**:
   - **[`RoRModels.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Domain/Models/RoRModels.swift)**: Added `OfficialRoRDocument` struct with `documentID` and `isReady` fields.
   - **[`RoRService.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Services/RoRService.swift)**: Added `downloadOfficialDocument(documentID:)` targeting the fast-path endpoint.
   - **[`KhatianDetailView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/KhatianDetailView.swift)**: Added background `.task` prefetch on view appearance, enabling instant share sheet display on button tap.

---

## 3. Verification & Benchmark Results

### Live Fast-Path Download Benchmark:
```text
Endpoint: GET /api/v1/ror/official-document/3:4:196:1110
Status Code: 200 OK
Response Latency: 57ms
Content-Type: application/pdf
PDF Size: 270,891 bytes
Upstream Portal Scrapes on Download: 0
```

### Test Suite Execution:
- **Phase 7.27.1 Unit & Integration Tests**: 6 / 6 passing
- **Full Backend Pytest Suite**: **675 / 675 tests passing (100%)**
- **iOS Physical Build**: Compiled and successfully installed on `aabbc’s iPhone`.
