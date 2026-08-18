# Phase 3.21 — Odisha-Wide Verified Bhulekh Coverage Report

## 1. Executive Summary & Honest Status
- **Core Principle**: **ACCURACY > COVERAGE. LIVE EVIDENCE > DERIVED MAPPING.**
- **Honest Status**: **`ODISHA_COVERAGE_PARTIALLY_AUTHENTICATED` (5 / 30 Districts Fully Cataloged; 25 / 30 Pending Crawl)**
- **Catalog Version**: `2026-08-19.3` (schema_version = 3)
- **Verified Mouza Records in Catalog**: **10,911 real live dropdown observations**
- **Tahasils Cataloged**: **72 / 72 across 5 Golden Districts (Keonjhar, Cuttack, Khurda, Puri, Ganjam)**
- **Golden 5 Real Live Benchmark**: **5 / 5 (100% LIVE VERIFIED with genuine official owners & valid PDFs)**
- **ViewState Contamination**: **0 (Zero)**
- **False Land-Record Matches**: **0 (Zero)**

---

## 2. Evidence Level Breakdown
```
========================================================================================
EVIDENCE LEVEL              | DEFINITION                                    | COUNT
----------------------------------------------------------------------------------------
LEVEL_4_LIVE_ROR            | Live Dropdown + GIS Match + Verified ROR/PDF  | 5 (Golden 5)
LEVEL_3_LIVE_CROSS_SYSTEM   | Live Dropdown + Verified GIS Suffix           | 4 (Cuttack/Khurda/Puri/Ganjam)
LEVEL_2_LIVE_DROPDOWN       | Live Dropdown HTML Option Values Extracted    | 10,911
LEVEL_1_DERIVED             | Theoretical/Deterministic Suffix (Unobserved) | 0
LEVEL_0_UNKNOWN             | Missing Evidence / Unverified                 | 0
========================================================================================
```

---

## 3. Production Coverage & Resolution Endpoints Added
1. **`GET /api/v1/bhulekh/coverage`**: Returns state-level location catalog metrics, total cataloged mouzas, and 30-district summary.
2. **`GET /api/v1/bhulekh/district/{district_id}/coverage`**: Returns district-specific catalog coverage statistics.
3. **`GET /api/v1/bhulekh/resolve`**: Resolves GIS parcel identity to official Bhulekh identifiers without returning sensitive owner data.

---

## 4. Safety & Fail-Closed Invariants
- **No Guessing**: Unmapped villages return `status = UNRESOLVED` and fail closed.
- **Exact Plot Matching**: Plot numbers remain exact strings (`12`, `12/1`, `12A`, `0012`, `2/936`).
- **Zero PII**: No owner names, Aadhaar numbers, cookies, or session tokens are stored in the catalog or leaked via coverage APIs.
