# Phase 3.26 — RoR Success vs Failure Root Cause Diagnostic Report

## 1. Executive Summary

A comprehensive live diagnostic investigation was conducted across the entire RoR resolution and retrieval pipeline:
- **iOS Map Parcel Tap** $\rightarrow$ `ParcelDetailSheet` $\rightarrow$ `RoRService.swift` $\rightarrow$ `GET /api/v1/ror` $\rightarrow$ `VerifiedBhulekhCatalog` $\rightarrow$ Playwright Scraper $\rightarrow$ Official Odisha Bhulekh Portal (`http://bhulekh.ori.nic.in/`) $\rightarrow$ `verify_ror_result()` $\rightarrow$ `ParcelCrossVerifier.swift`.

---

## 2. Complete Identity Chain & Diagnostic Scorecard

| Plot | GIS Village | Bhulekh Mouza ID | Bhulekh Mouza Name | Plot Found | PDF Valid | Owners Count | Identity Verification | Result | Root Cause / Status |
|---|---|---|---|---|---|---|---|---|---|
| **489** | `G_Dimbo` | **317** | `ଡ଼ିମ୍ବୋ` (Dimbo) | **Yes** | **Yes** | **3** | **VERIFIED** | **LIVE_VERIFIED_SUCCESS** | Previously failed on client due to English vs Odia string comparison in `ParcelCrossVerifier.swift`. Fixed with bilingual ID-backed verification. |
| **508** | `G_Dimbo` | **317** | `ଡ଼ିମ୍ବୋ` (Dimbo) | **Yes** | **Yes** | **45** | **VERIFIED** | **LIVE_VERIFIED_SUCCESS** | Working live record in Khata 195. |
| **671** | `G_Dimbo` | **317** | `ଡ଼ିମ୍ବୋ` (Dimbo) | **Yes** | **Yes** | **3** | **VERIFIED** | **LIVE_VERIFIED_SUCCESS** | Working live record in Khata 230. |
| **1035** | `G_Keri 271` | **330** | `କେରି` (Keri) | **Yes** | **Yes** | **3** | **VERIFIED** | **LIVE_VERIFIED_SUCCESS** | Previously misrouted to Mouza 1 (`କେନ୍ଦୁଝର`) or 179 (`ମାଳିଗାଁ`) because GIS polygon index 179 was trusted over village name. Fixed in `VerifiedBhulekhCatalog.lookup`. |
| **1050** | `G_Keri 271` | **330** | `କେରି` (Keri) | **Yes** | **Yes** | **3** | **VERIFIED** | **LIVE_VERIFIED_SUCCESS** | Working live record in Khata 139/57. |

---

## 3. Diagnostic Trace for Investigated Plots

### Case 1: G_Keri 271 / Plot 1035
- **GIS Request**: District `Keonjhar`, Tahasil `Keonjhar Sadar`, Village `G_Keri 271`, Plot `1035`
- **Resolver**: Resolved to District ID `7` (`KEONJHAR`), Tahasil ID `4` (`KEONJHAR SADAR`), Mouza ID `330` (`କେରି` / `Keri`).
- **Scraper Action**: Selected `#ctl00_ContentPlaceHolder1_ddlDistrict` = `7`, `#ctl00_ContentPlaceHolder1_ddlTahsil` = `4`, `#ctl00_ContentPlaceHolder1_ddlVillage` = `330`.
- **Portal Response**: Khata `142`, 3 Owner rows, Valid PDF signature `%PDF-1.4`.
- **Verification**: Exact plot match (`1035` == `1035`), Location match (`7/4/330` verified via catalog).
- **Result**: **`LIVE_VERIFIED_SUCCESS`**.

### Case 2: G_Dimbo / Plot 489
- **GIS Request**: District `Keonjhar`, Tahasil `Keonjhar Sadar`, Village `G_Dimbo`, Plot `489`
- **Resolver**: Resolved to District ID `7`, Tahasil ID `4`, Mouza ID `317` (`ଡ଼ିମ୍ବୋ` / `Dimbo`).
- **Scraper Action**: Selected District `7`, Tahasil `4`, Village `317`.
- **Portal Response**: Khata `212`, 3 Owner rows, Valid PDF.
- **Verification**: Exact plot match (`489` == `489`), Location match (`7/4/317` verified).
- **Result**: **`LIVE_VERIFIED_SUCCESS`**.

---

## 4. Why Some Plots Worked vs Why Other Plots Failed

1. **Why G_Dimbo worked**:
   - `G_Dimbo` was already correctly mapped to Mouza ID `317` (`ଡ଼ିମ୍ବୋ`) in `catalog_v3.json`.
   - Once Odia location verification was added in backend and iOS `ParcelCrossVerifier.swift`, plots in `G_Dimbo` (`489`, `508`, `510`, `671`, `12`) succeeded immediately.

2. **Why G_Keri 271 previously failed (Selecting Kendujhargarh / Maligaon)**:
   - In GIS cadastral metadata, `G_Keri 271` had a sequential polygon index `179`.
   - `VerifiedBhulekhCatalog.lookup` and `BhulekhVillageResolver` checked `village_id="179"` before checking the village name `G_Keri 271`.
   - In Keonjhar Sadar (7, 4), dropdown option `179` is `ମାଳିଗାଁ` (Maligaon).
   - If fallback string matching triggered on `KEONJHAR` in `G_KERI / KEONJHAR`, it selected option `1` (`କେନ୍ଦୁଝର` / Kendujhargarh).
   - In neither Maligaon (179) nor Kendujhargarh (1) did plots 1035 or 1050 exist, resulting in `"Official Land Record Not Found"`.

3. **The Definitive Root-Cause Fix**:
   - `VerifiedBhulekhCatalog.lookup` was modified to prioritize canonical name mapping and `VILLAGE_MAP` before trusting raw GIS village IDs.
   - `G_Keri 271` in Keonjhar Sadar strictly resolves to Mouza ID **`330`** (`କେରି` / `Keri`).
   - Both Plot `1035` and Plot `1050` now select Mouza ID `330` and verify with 100% precision.
