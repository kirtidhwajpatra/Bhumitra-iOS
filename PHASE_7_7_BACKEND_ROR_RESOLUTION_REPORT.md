# PHASE 7.7 — BACKEND BHULEKH RESOLUTION FINAL REPORT
**Timestamp**: 2026-08-23T04:30:00Z  
**Status**: ✅ **PRODUCTION READY — ALL 3 CORE BUGS RESOLVED**  
**False Owner Rate**: **0.00% (0 / 20 Parcels)**  
**Backend Pytest Suite**: **617 / 617 Tests Passing (100%)**

---

## 1. Executive Summary

Phase 7.7 resolved the root cause backend resolution bugs identified during the Phase 7.5 forensic trace:
1. **Chakuli_Mosaic / Atabira (Bargarh)**: Fixed Tahasil ID mapping (`Attabira` $\rightarrow$ ID 1, `Bargarh` $\rightarrow$ ID 2, etc.), Odia district/village Unicode variations, and Consolidation Village multi-plot table parsing (`gvRorBack` columns 1 & 2).
2. **G_Dimbo / Keonjhar (Keonjhar)**: Fixed dropdown option selection to match visible plot text/label rather than option value, and eliminated first-row plot hijacking in multi-plot Khatas.
3. **Raghunathpur Jali / Bhubaneswar (Khordha)**: Solved mega-village ASP.NET postback timeouts (5,537 plots) by integrating official high-speed SOAP Unicode web methods (`BhulekhService.asmx`) to deterministically resolve parent Khatas and fetch complete Front + Back RoR records.

---

## 2. Verification of the 3 Critical Problem Parcels

| Parcel Identity | Requested | Resolved Khata | Returned Plot | Owners | Land Classification | Verification Status | False Owner? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Chakuli_Mosaic** (Bargarh / Atabira) | Plot `647` | **277** | `647` | 1 Private Owner (*Sanatan Pradhan*) | `ଖଳାବାରି` (0.09 Ac) | `VERIFIED` | **NO (0%)** |
| **Raghunathpur_Jali** (Khordha / Bhubaneswar) | Plot `333` | **538** | `333` | 2 Private Owners (*Hadu Behera, Hari Behera*) | `ବିଆଳି ଦୋଫସଲ` (0.01 Ac) | `VERIFIED` | **NO (0%)** |
| **G_Dimbo** (Keonjhar / Keonjhar Sadar) | Plot `12` | **112** | `12` | 6 Private Owners (*Fulmani Jena, Babaji Jena, etc.*) | `ଶାରଦ ତିନି` (0.41 Ac) | `VERIFIED` | **NO (0%)** |
| **G_Dimbo** (Keonjhar / Keonjhar Sadar) | Plot `1` | **230** | `1` | 1 Government Record (*Rakshit / Gochar*) | `ଗୋଚର` (0.29 Ac) | `VERIFIED` | **NO (0%)** |

---

## 3. Phase 7.7F & 7.7G: Caching & Concurrency Performance

- **Cache Verification (Phase 7.7F)**:
  - Cold Request: `12,093 ms` (`cached: false`)
  - Warm Cache Hit: `3.08 ms` (`cached: true`) $\rightarrow$ **Sub-5ms response time**
- **Concurrency & SingleFlight Coalescing (Phase 7.7G)**:
  - 5 simultaneous requests for the exact same uncached parcel completed with `100% 200 OK` status without overloading upstream servers.

---

## 4. Phase 7.7J: 20-Parcel Official Comparison Benchmark

| # | District / Tahasil / Village | Requested Plot | Khata | Owners Found | Land Type | Benchmark Verdict | Latency (ms) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 01 | Bargarh / Atabira / Chakuli_Mosaic | `647` | 277 | 1 | ଖଳାବାରି | **PASS** | 10,153.6 |
| 02 | Khordha / Bhubaneswar / Raghunathpur_Jali | `333` | 538 | 2 | ବିଆଳି ଦୋଫସଲ | **PASS** | 41,347.6 |
| 03 | Keonjhar / Keonjhar Sadar / G_Dimbo | `12` | 112 | 6 | ଶାରଦ ତିନି | **PASS** (Cache) | 2.2 |
| 04 | Keonjhar / Keonjhar Sadar / G_Dimbo | `1` | 230 | 1 | ଗୋଚର | **PASS** | 12,418.1 |
| 05 | Keonjhar / Keonjhar Sadar / G_Dimbo | `168` | 112 | 6 | ଶାରଦ ଦୁଇ | **PASS** | 11,207.2 |
| 06 | Keonjhar / Keonjhar Sadar / G_Dimbo | `174` | 112 | 6 | ଶାରଦ ଦୁଇ | **PASS** | 12,200.2 |
| 07 | Keonjhar / Keonjhar Sadar / G_Dimbo | `341` | 112 | 6 | ଶାରଦ ଦୁଇ | **PASS** | 10,166.7 |
| 08 | Keonjhar / Keonjhar Sadar / G_Dimbo | `3` | 230 | 1 | ଗୋଚର | **PASS** | 12,341.8 |
| 09 | Bargarh / Atabira / Chakuli_Mosaic | `614` | 277 | 1 | ମାଳ ପାଣି | **PASS** | 10,830.6 |
| 10 | Bargarh / Atabira / Chakuli_Mosaic | `652` | 277 | 1 | ରାସ୍ତା | **PASS** | 10,314.0 |
| 11 | Bargarh / Atabira / Chakuli_Mosaic | `654` | 277 | 1 | ବାରି ଖାରି | **PASS** | 10,260.7 |
| 12 | Bargarh / Atabira / Chakuli_Mosaic | `656` | 277 | 1 | ଘର | **PASS** | 11,713.0 |
| 13 | Khordha / Bhubaneswar / Raghunathpur_Jali | `555` | 538 | 2 | ବିଆଳି ଦୋଫସଲ | **PASS** | 39,334.1 |
| 14 | Khordha / Bhubaneswar / Raghunathpur_Jali | `1465` | 538 | 2 | ଡାଳୁଅ ଏକ | **PASS** | 39,437.5 |
| 15 | Khordha / Bhubaneswar / Raghunathpur_Jali | `718/3372` | 538 | 2 | ଘରବାରି | **PASS** | 37,627.9 |
| 16 | Khordha / Bhubaneswar / Raghunathpur_Jali | `333/3370` | 538 | 2 | ଘରବାରି | **PASS** | 39,194.1 |
| 17 | Keonjhar / Keonjhar Sadar / G_Dimbo | `99999` | - | 0 | - | **PASS (Failed Closed 404)** | 20,611.7 |
| 18 | Bargarh / Atabira / Chakuli_Mosaic | `88888` | - | 0 | - | **PASS (Failed Closed 404)** | 30,469.3 |
| 19 | Khordha / Bhubaneswar / Raghunathpur_Jali | `77777` | - | 0 | - | **PASS (Failed Closed 404)** | 78,636.9 |
| 20 | Keonjhar / Keonjhar Sadar / G_Dimbo | `684` | 41 | 1 | ତଇଳା ଏକ | **PASS** | 15,854.0 |

- **Total Parcels Tested**: 20
- **Passed**: 20 / 20 (100.0%)
- **False Owner Rate (Phase 7.7K)**: **0.00%**

---

## 5. Summary of Architectural Code Changes

1. [`scrapers/bhulekh_mappings.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_mappings.py):
   - Corrected Bargarh (District 15) Tahasil IDs (`Attabira = 1`, `Bargarh = 2`, etc.).
   - Corrected Khordha (District 20) Tahasil IDs (`Banapur = 1`, `Bhubaneswar = 2`, `Khordha = 3`, etc.).
   - Added complete Odia Unicode decompositions & nukta variants across all 30 districts.
2. [`resolvers/bhulekh_soap_resolver.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/resolvers/bhulekh_soap_resolver.py):
   - Implemented high-concurrency SOAP resolver (`PlotsUnicode` + `KhatiyanUnicode`) with in-memory LRU cache and parallel connection pooling.
3. [`scrapers/bhulekh_scraper.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_scraper.py):
   - Strict visible label option matching (`o["text"] == requested_plot`) eliminating label-value mismatches.
   - Dual-page capture (`btnRORFront` + `btnRORBack`) ensuring complete ownership and plot coverage.
   - Multi-plot and consolidation table parsing across columns 0, 1, 2.
4. [`core/config.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/core/config.py):
   - Increased default `ROR_TIMEOUT_SECONDS` to 90s to accommodate mega-villages on cold lookups.
