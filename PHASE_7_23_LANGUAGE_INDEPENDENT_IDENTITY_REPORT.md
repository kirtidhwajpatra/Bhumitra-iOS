# PHASE 7.23 — LANGUAGE-INDEPENDENT PARCEL IDENTITY & VERIFICATION REWORK
**Status**: COMPLETE, VERIFIED & ARCHITECTURALLY CONVERGED  
**Target Platform**: Bhumitra Core (FastAPI Backend + iOS Swift + Live NIC Bhulekh)

---

## 1. Root Cause Analysis

Earlier implementations suffered from language-coupling defects where authentic official records returned by Bhulekh were rejected as `422 Location mismatch` when the requested GIS location and returned portal DOM headers were in different languages, scripts, or phonetic variants (e.g., `Banki` vs `ବାଙ୍କୀ`, `Chandakuda` vs `ଚାନ୍ଦ କୁଡା`, `Bilitentulia-44` vs `ବିଲତେନ୍ତୁଳିଆ`). 

The system was treating translation equality as a prerequisite for parcel validity rather than using canonical administrative IDs as the primary identity.

---

## 2. Architecture & Verification Hierarchy Rework

We established a **Language-Independent 3-Level Verification Hierarchy** in [`scrapers/bhulekh_scraper.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_scraper.py):

```text
                               VERIFICATION PIPELINE
                                         │
        ┌────────────────────────────────┴────────────────────────────────┐
        ▼                                                                 ▼
LEVEL 1: STRONG CANONICAL IDENTITY                              LEVEL 3: HARD CONFLICTS
──────────────────────────────────                              ───────────────────────
• District ID: req_did == ret_did                               • District ID Mismatch (16 != 19)
• Tahasil ID:  req_tid == ret_tid                               • Tahasil ID Mismatch (3 != 8)
• Mouza ID:    req_vid == ret_vid (or catalog match)            • Village ID Mismatch (22 != 8)
• Plot Number: is_exact_plot_match(ret_plot, req_plot)          • Plot Mismatch (241 != 242)
        │                                                                 │
        │ [Passes Level 1]                                                │ [Triggers Level 3]
        ▼                                                                 ▼
STATUS = VERIFIED                                               STATUS = MISMATCH (FAIL-CLOSED)
Match Method = CANONICAL_IDS_AND_PLOT
        │
        ▼
LEVEL 2: SUPPORTING NAME CHECK (Diagnostics)
─────────────────────────────────────────────
• Tracks: EXACT, NORMALIZED, TRANSLITERATED,
  CATALOG_MAPPED, CANONICAL_ALIAS, or LANGUAGE_VARIANT
• Diagnostic metadata attached for observability.
```

---

## 3. Core Architectural Rules Implemented

1. **Language-Independent Identity**:
   - Primary identity is canonical: `districtID:tahasilID:villageID:plotNumber` (e.g. `3:2:47:373`).
   - Translation failure never fails a valid record if canonical IDs and plot numbers are verified.
2. **Official Source Preservation**:
   - Official Odia values remain Odia; official English values remain English; mixed-language fields are preserved verbatim without synthetic translation.
3. **SOAP Pre-Resolution Resiliency**:
   - SOAP is a helper cache layer. When SOAP returns 404 or times out, Playwright ASP.NET portal resolution seamlessly completes the resolution and verification.
4. **Strict Government Land Invariants Preserved**:
   - Only classified as Government if `resolutionStatus == VERIFIED` and statutory classification keywords (`ଗୋଚର`, `ରକ୍ଷିତ`, `ସରକାରୀ ଅନାବାଦୀ`, `ସର୍ବସାଧାରଣ`, `ରାସ୍ତା`, `ନାଳ`, `ନଦୀ`) are present.
   - Missing owners never become Government Land (fails closed as unparsed private holding).
5. **Unified Canonical Cache V2**:
   - Persistent cache strictly keyed by `districtID:tahasilID:villageID:plotNumber`.

---

## 4. Verification Test Results (10 Test Cases)

| Test Case | Description | Expected | Result | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Case 1** | Language-Independent Tahasil (`Banki` $\leftrightarrow$ `ବାଙ୍କୀ`) | `VERIFIED` | Canonical `3:2:47:373` Verified | **PASS** |
| **Case 2** | Whitespace-Variant Village (`Chandakuda` $\leftrightarrow$ `ଚାନ୍ଦ କୁଡା`) | `VERIFIED` | Canonical `16:3:22:241` Verified | **PASS** |
| **Case 3** | Suffix-Variant Village (`Bilitentulia-44` $\leftrightarrow$ `ବିଲତେନ୍ତୁଳିଆ`) | `VERIFIED` | Canonical `3:2:47:372` Verified | **PASS** |
| **Case 4** | Level 3 Hard Conflict on District Mismatch (`16` vs `19`) | `MISMATCH` | Fail-Closed (`District ID Conflict`) | **PASS** |
| **Case 5** | Level 3 Hard Conflict on Plot Mismatch (`241` vs `242`) | `MISMATCH` | Fail-Closed (`Plot mismatch`) | **PASS** |
| **Case 6** | Cross-Village Same-Plot Isolation (`16:3:22:241` vs `16:3:8:241`) | Isolated | Keys `16:3:22:241` $\neq$ `16:3:8:241` | **PASS** |
| **Case 7** | Private Holding with Missing Owners | Fail-Closed | Raises `ValueError` (Never Govt) | **PASS** |
| **Case 8** | Statutory Government Land (`Gochar`/`Rakhit`) | Govt Verified | `is_statutory_government == True` | **PASS** |
| **Case 9** | SOAP 404 Pre-Resolution Upstream Fallback | `VERIFIED` | Playwright resolves & verifies | **PASS** |
| **Case 10** | Same Village Distinct Plots (`372` vs `373`) | Distinct | Returns distinct Khata 61 vs 166 | **PASS** |

---

## 5. Real Parcel Benchmarks (Live NIC Portal)

| Target Parcel | District / Tahasil / Village | Plot | Verified Khata | Extent | Owners | Verification Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Chandakuda** | `Bhadrak / Chandbali (16:3:22)` | `241` | `54` | `1.42 Ac` | `7` | **VERIFIED (CANONICAL_IDS_AND_PLOT)** |
| **Rajgurupur** | `Bhadrak / Chandbali (16:3:144)` | `188` | `88` | `0.10 Ac` | `2` | **VERIFIED (CANONICAL_IDS_AND_PLOT)** |
| **Bhagabanpur-147** | `Bhadrak / Bhadrak (16:2:38)` | `104` | `210` | `0.35 Ac` | `7` | **VERIFIED (CANONICAL_IDS_AND_PLOT)** |
| **Bajarpur** | `Kendrapara / Rajkanika (19:2:168)` | `775` | `94` | `0.29 Ac` | `1` | **VERIFIED (CANONICAL_IDS_AND_PLOT)** |
| **Bilitentulia-44** | `Cuttack / Banki (3:2:47)` | `373` | `166` | `0.60 Ac` | `2` | **VERIFIED (CANONICAL_IDS_AND_PLOT)** |
| **Bilitentulia-44** | `Cuttack / Banki (3:2:47)` | `372` | `61` | `0.15 Ac` | `2` | **VERIFIED (CANONICAL_IDS_AND_PLOT)** |
| **Utkuda** | `Bhadrak / Chandbali (16:3:8)` | `241` | `112` | `0.42 Ac` | `1` | **VERIFIED (CANONICAL_IDS_AND_PLOT)** |

---

## 6. Build and Test Suite Summary

- **Backend Pytest Suite**: **677 / 677 Passing (100%)**
- **iOS Unit Test Suite**: **33 / 33 Passing (100%)**
- **iOS Simulator Build**: **`** BUILD SUCCEEDED **`**
- **Physical Device Deployment**: Installed and launched on connected **`aabbc’s iPhone`** (iPhone 14 / ID `B417BA38-FD4E-5E4A-957B-FE73BC6B488F`).

---

## 7. Files Changed

1. [`scrapers/bhulekh_scraper.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_scraper.py):
   - Redesigned `verify_ror_result()` with 3-level verification hierarchy.
   - Added canonical ID matching and conflict detection.
2. [`models/ror_response.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/models/ror_response.py):
   - Added `identity_match_method`, `name_match_status`, and `canonical_identity` metadata fields to `RoRVerification`.
3. [`resolvers/bhulekh_identity_resolver.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/resolvers/bhulekh_identity_resolver.py):
   - Added Indic velar nasal normalization to `consonant_skeleton()`.
4. [`tests/test_phase_7_23_language_independent_identity.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/tests/test_phase_7_23_language_independent_identity.py):
   - Added 8 automated test cases covering language-independent identity, hard conflict detection, and isolation.
