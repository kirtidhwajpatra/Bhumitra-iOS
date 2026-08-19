# Phase 3.28 — Good vs Failed Plots Trace & Root Cause Diagnostic Report

## 1. Executive Summary

A comprehensive live LAN diagnostic investigation was executed against `http://10.104.73.242:8000/api/v1/ror` across all target plots (`489`, `508`, `671`, `1035`, `1050`) using the running backend synchronized with GitHub `origin/main` (`eadea80`).

---

## 2. Live LAN API Test Matrix Scorecard

| Plot | Requested Village | Resolver | District ID | Tahasil ID | Mouza ID | Portal Response | Plot Match | Location Match | Owners Count | Final Status | FIRST FAILURE / DIVERGENCE POINT |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **489** | `G_Dimbo` | `VerifiedBhulekhCatalog` | `7` | `4` | `317` (`ଡ଼ିମ୍ବୋ`) | `200 OK` | `True` | `True` | `3` | **`LIVE_VERIFIED_SUCCESS`** | None (Working) |
| **508** | `G_Dimbo` | `VerifiedBhulekhCatalog` | `7` | `4` | `317` (`ଡ଼ିମ୍ବୋ`) | `200 OK` | `True` | `True` | `45` | **`LIVE_VERIFIED_SUCCESS`** | None (Working) |
| **671** | `G_Dimbo` | `VerifiedBhulekhCatalog` | `7` | `4` | `317` (`ଡ଼ିମ୍ବୋ`) | `200 OK` | `True` | `True` | `3` | **`LIVE_VERIFIED_SUCCESS`** | None (Working) |
| **1035** | `G_Dimbo` | `VerifiedBhulekhCatalog` | `7` | `4` | `317` (`ଡ଼ିମ୍ବୋ`) | `404 ROR_NOT_FOUND` | `False` | `True` | `0` | **`RECORD_NOT_FOUND`** | **Village Scope Error**: Plot `1035` does not exist in `G_Dimbo` (Mouza 317); it exists in `G_Keri 271` (Mouza 330). |
| **1050** | `G_Dimbo` | `VerifiedBhulekhCatalog` | `7` | `4` | `317` (`ଡ଼ିମ୍ବୋ`) | `404 ROR_NOT_FOUND` | `False` | `True` | `0` | **`RECORD_NOT_FOUND`** | **Village Scope Error**: Plot `1050` does not exist in `G_Dimbo` (Mouza 317); it exists in `G_Keri 271` (Mouza 330). |
| **1035** | `G_Keri 271` | `VerifiedBhulekhCatalog` | `7` | `4` | `330` (`କେରି`) | `200 OK` | `True` | `True` | `3` | **`LIVE_VERIFIED_SUCCESS`** | None (Working in correct village `G_Keri 271`) |
| **1050** | `G_Keri 271` | `VerifiedBhulekhCatalog` | `7` | `4` | `330` (`କେରି`) | `200 OK` | `True` | `True` | `3` | **`LIVE_VERIFIED_SUCCESS`** | None (Working in correct village `G_Keri 271`) |

---

## 3. Detailed Plot-by-Plot Comparison

### A. Plot 489 — Why It Works
- **Location**: Keonjhar / Keonjhar Sadar / `G_Dimbo` / Plot `489`
- **Resolution**: Canonical IDs `(7, 4, 317, 489)`.
- **Portal Result**: Dropdown option `317` (`ଡ଼ିମ୍ବୋ`) contains plot `489`. Khata `212` with 3 owners extracted and verified.

### B. Plot 508 — Why It Works
- **Location**: Keonjhar / Keonjhar Sadar / `G_Dimbo` / Plot `508`
- **Resolution**: Canonical IDs `(7, 4, 317, 508)`.
- **Portal Result**: Dropdown option `317` contains plot `508`. Khata `195` with 45 owners extracted and verified.

### C. Plot 671 — Why It Works
- **Location**: Keonjhar / Keonjhar Sadar / `G_Dimbo` / Plot `671`
- **Resolution**: Canonical IDs `(7, 4, 317, 671)`.
- **Portal Result**: Dropdown option `317` contains plot `671`. Khata `230` with 3 owners extracted and verified.
- **Previous Failure on iOS**: The iOS `ParcelCrossVerifier.swift` was previously performing a direct English-vs-Odia string comparison (`KEONJHAR` vs `କେନ୍ଦୁଝର`). With the Phase 3.22B fix, `ParcelCrossVerifier.swift` handles Odia headers and trusts backend-verified IDs.

### D. Plot 1035 — Why It Fails vs Works
- **When requested with `village=G_Dimbo`**: **Fails with `ROR_NOT_FOUND`**. Plot 1035 does not physically exist in Dimbo village.
- **When requested with `village=G_Keri 271`**: **Succeeds (`200 OK`, Khata `142`, 3 Owners)**.

### E. Plot 1050 — Why It Fails vs Works
- **When requested with `village=G_Dimbo`**: **Fails with `ROR_NOT_FOUND`**. Plot 1050 is not in Dimbo village.
- **When requested with `village=G_Keri 271`**: **Succeeds (`200 OK`, Khata `139/57`, 3 Owners)**.
- **Why it failed in the earlier session**: The iPhone was hitting an old stale Uvicorn in-memory process where `G_Keri 271` was misrouting to `Kendujhargarh` (Mouza 1) or `Maligaon` (Mouza 179). In the updated synced backend, `G_Keri 271` strictly resolves to Mouza **`330`** (`କେରି`).

---

## 4. Root Cause Analysis

### ROOT CAUSE
1. **Stale Process In-Memory State**: The physical iPhone was communicating with an un-reloaded background Uvicorn process (PID 27260) that held pre-Phase-3.23 code in memory.
2. **Village Discrepancy in Map Selection**: Plots `1035` and `1050` belong to revenue village `G_Keri 271` (Thana 271 / Mouza 330), not `G_Dimbo` (Mouza 317). When queried under their true village `G_Keri 271`, both plots return verified official RoR records.
3. **Client-Side Odia String Mismatch**: `ParcelCrossVerifier.swift` on the iOS app previously rejected verified portal responses because portal headers were Odia (`କେନ୍ଦୁଝର, ସଦର, ଡ଼ିମ୍ବୋ`) while GIS metadata was English (`Keonjhar, Keonjhar Sadar, G_Dimbo`).

### NOT ROOT CAUSE
- **Portal Outage / Anti-Bot**: Ruled out. The official portal responds reliably with full DOM and valid PDFs.
- **Missing RoR Records**: Ruled out. Plots `489`, `508`, `671`, `1035`, and `1050` all have real, active RoR records in Bhulekh.
- **Fuzzy Matching / Transliteration**: Ruled out. Deterministic ID mapping `(7, 4, 317)` and `(7, 4, 330)` resolves all cases without fuzzy matching.

---

## 5. Recommended Next Step
- **No production code changes are required on the backend**. The latest synced backend and updated iOS `ParcelCrossVerifier.swift` correctly resolve and verify all 5 test plots.
