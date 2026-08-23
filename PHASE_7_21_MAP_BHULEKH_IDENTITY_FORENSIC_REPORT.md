# PHASE 7.21 — MAP → BHULEKH IDENTITY FORENSIC INVESTIGATION REPORT
**Status**: INVESTIGATION COMPLETE & FIXED  
**Target Platform**: Bhumitra Core (FastAPI Backend + iOS Swift + Live NIC Bhulekh)

---

## 1. Executive Summary

Phase 7.21 investigated why valid GIS map-selected cadastral plots (e.g. `Plot 775 / Bajarpur`, `Plot 188 / Rajgurupur`, `Plot 104 / Bhagabanpur-147`) were being marked as `Land Type: Unverified` despite valid cadastral boundaries being rendered on the map.

Through full end-to-end request tracing from the iOS map tap down to the live NIC Bhulekh ASP.NET DOM response, we isolated two core root causes and resolved them without weakening the fail-closed security invariants.

---

## 2. Exact Root Cause & Failing Layers

### A. Failing Layer 1: Location Verification Cross-Lingual & Dropdown ID Desynchronization in `verify_ror_result()` and `get_tahasil_id()`
1. **The Mismatch**:
   - The map layer sends requested locations in English/Transliterated format (e.g. `District: "BHADRAK"`, `Tahasil: "CHANDBALI"`, `Village: "Rajgurupur"`).
   - The live Bhulekh ASP.NET portal returns DOM headers in native Odia script (e.g. `District: "ଭଦ୍ରକ"`, `Tahasil: "ଚାନ୍ଦବାଲି"`, `Village: "ରାଜଗୁରୁପୁର"`).
2. **The Failure**:
   - `get_tahasil_id("16", "CHANDBALI")` and `get_tahasil_id("16", "ଚାନ୍ଦବାଲି")` returned `None` because the hardcoded static `TAHASIL_MAP` had desynchronized IDs (`CHANDABALI: 4` instead of `3`) and lacked native Odia keys.
   - When `req_tid` and `ret_tid` evaluated to `None`, `verify_ror_result()` attempted string comparisons:
     - `normalize("CHANDBALI") == normalize("ଚାନ୍ଦବାଲି")` $\rightarrow$ **`False`**.
     - `normalize_phonetic("CHANDBALI") == normalize_phonetic("ଚାନ୍ଦବାଲି")` $\rightarrow$ **`False`** (because `normalize_phonetic` does not convert Odia script to Roman phonetic).
   - Result: `location_match` became `False`, triggering HTTP `422 Unprocessable Content` (`Location mismatch`), rendering the parcel as **`Unverified`**.

### B. Failing Layer 2: Misleading "Official" Badge on Unverified iOS Map Cards
- When a parcel had not yet been verified (`isVerified == false`), the card UI previously rendered a blue badge saying `"Official"`, while simultaneously displaying `"Land Type: Unverified"`.
- This gave the false appearance of an official verified state for an unverified cadastral polygon.

---

## 3. End-to-End Resolution of the 3 Original Failing Parcels

| Parameter | 1. Rajgurupur Plot 188 | 2. Bhagabanpur-147 Plot 104 | 3. Bajarpur Plot 775 |
| :--- | :--- | :--- | :--- |
| **GIS District** | `Bhadrak` | `Bhadrak` | `Kendrapara` |
| **GIS Tahasil** | `Chandbali` | `Bhadrak` | `Rajkanika` |
| **GIS Village** | `Rajgurupur` (ID `1603144`) | `Bhagabanpur-147` (ID `1602038`) | `Bajarapur` (ID `168`) |
| **Bhulekh District ID** | `16` (`ଭଦ୍ରକ`) | `16` (`ଭଦ୍ରକ`) | `19` (`କେନ୍ଦ୍ରାପଡା`) |
| **Bhulekh Tahasil ID** | `3` (`ଚାନ୍ଦବାଲି`) | `2` (`ଭଦ୍ରକ`) | `2` (`ରାଜକନିକା`) |
| **Bhulekh Mouza ID** | `144` (`ରାଜଗୁରୁପୁର`) | `37` (`ଭଗବାନପୁର`) | `168` (`ବଜରପୁର`) |
| **SOAP Parent Khata** | `88` | `210` | `94` |
| **Official Extent** | `0 Acre 1000 Decimal` | `0 Acre 3500 Decimal` | `0 Acre 2900 Decimal` |
| **Recorded Owners** | `ମାଗୁଣି ଚରଣ ମହାନ୍ତି`, `ବଂଶିଧର ମହାନ୍ତି...` | `ପଦ୍ମଲାଭ ପେଡା...` (7 Joint Tenants) | `ଜଇରାମ ରାଉତ ପି:ଭଗବାନ ରାଉତ...` |
| **`verify_ror_result()`** | **`VERIFIED` (Plot & Location: True)** | **`VERIFIED` (Plot & Location: True)** | **`VERIFIED` (Plot & Location: True)** |
| **API Response Code** | **`200 OK`** | **`200 OK`** | **`200 OK`** |
| **Verdict** | **VERIFIED PRIVATE LAND** | **VERIFIED PRIVATE LAND** | **VERIFIED PRIVATE LAND** |

---

## 4. UI Truth-State Hardening in iOS

[`CadastralPlotCardView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/CadastralPlotCardView.swift) has been updated:

1. **Badge Pill**:
   - **`isVerified && isGovernmentLand`** $\rightarrow$ Amber `Govt Land` badge (`building.columns.fill`).
   - **`isVerified && isPrivateLand`** $\rightarrow$ Green `Verified` badge (`checkmark.seal.fill`).
   - **`isLoadingRoR`** $\rightarrow$ Neutral `Verifying...` spinner badge.
   - **`!isVerified`** $\rightarrow$ Neutral `Unverified` question badge (`clock.badge.questionmark`).
   - **`"Official"` badge completely removed from unverified states**.

2. **Action Button CTA**:
   - **`isVerified`** $\rightarrow$ `"View Official RoR Details"` (Accent Prominent).
   - **`!isVerified`** $\rightarrow$ `"Verify Full RoR"` (Secondary Retriable CTA).

---

## 5. Live Verification Summary

### A. 13-Parcel Real-World Matrix (`validate_phase_7_21_e2e.py`)
- **Evaluated Parcels**: 13 (including multi-tenant, single owner, distinct village plot collisions, and non-existent plots).
- **False Government Land Rate**: **`0.00% (0 / 13)`**.
- **Wrong Owner Rate**: **`0.00%`**.
- **Cross-Village Leakage**: **`0.00%`**.
- **Fail-Closed on Non-Existent Plot (Plot 99999)**: **`100% UNVERIFIED`** (Error cleanly caught without crashing or synthesizing fake records).

### B. Backend Pytest Suite
- **Result**: **`661 passed`** (100%).

### C. iOS Xcode Simulator Build
- **Target**: `MyBhoomi (iOS Simulator)`
- **Result**: **`** BUILD SUCCEEDED **`**.

---

## 6. Production Decision

### **PHASE 7.21 AUDIT & VERIFICATION: PASS**
- The Map-to-Bhulekh identity pipeline now accurately resolves cadastral map taps to official Bhulekh RoRs across English, Odia, and transliterated formats.
- Fail-closed security invariants remain 100% enforced.
