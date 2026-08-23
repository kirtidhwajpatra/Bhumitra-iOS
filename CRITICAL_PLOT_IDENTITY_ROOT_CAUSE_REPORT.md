# CRITICAL FORENSIC AUDIT: PLOT 333 / RAGHUNATHPUR JALI & GIS-TO-BHULEKH IDENTITY REPORT

**Investigation Date:** August 22, 2026  
**Status:** COMPREHENSIVELY ISOLATED & REPRODUCED  
**Severity:** CRITICAL / PRODUCTION-BLOCKING  
**Production Verdict:** NO-GO  

---

## 1. Plot 333 Complete Trace (GIS → iOS → Backend → Scraper → UI)

### Part 1: Selected Parcel Object in iOS
```json
{
  "district": "Khordha",
  "district_id": "20",
  "tahasil": "Bhubaneswar",
  "tahasil_id": "2002",
  "village": "Raghunathpur_Jali",
  "village_id": "2002359",
  "mouza": "ରଘୁନାଥପୁର ଜଳି",
  "mouza_id": "359",
  "ri_circle": "Sadar RI",
  "plot": "333",
  "plot_normalized": "333",
  "parcel_id": "2002359_333",
  "feature_id": "2002359_333",
  "source_layer": "odisha_4kgeo_parcels"
}
```

### Part 2: iOS → Backend HTTP Request
- **Endpoint:** `GET /api/v1/ror`
- **Query Parameters:**
  ```
  district=Khordha&tahasil=Bhubaneswar&village=Raghunathpur_Jali&plot=333&b_id=2002&v_id=2002359
  ```
- **Headers:** `Accept: application/json`, `Authorization: Bearer <REDACTED>`

### Part 3: Backend Canonical Identity
- **Computed Cache Key:** `SHA256("ror:20:2:2002:RAGHUNATHPUR_JALI:2002359:333")`
- **Parameters passed to `BhulekhVillageResolver`:**
  - `district_id="20"`
  - `tahasil_id="2"`
  - `gis_village_name="Raghunathpur_Jali"`
  - `gis_village_id="2002359"`

### Part 4: Bhulekh Identity Resolution Matrix

| Field | Bhumitra Internal | Official Bhulekh Portal | Match Status |
| :--- | :--- | :--- | :--- |
| **District** | Khordha | ଖୋର୍ଦ୍ଧା (Khordha) | **PASS** |
| **District Code** | `20` | `20` | **PASS** |
| **Tahasil** | Bhubaneswar | ଭୁବନେଶ୍ଵର (Bhubaneswar) | **PASS** |
| **Tahasil Code** | `2` (or `2002`) | `2` | **PASS** |
| **Village** | Raghunathpur_Jali | ରଘୁନାଥପୁର ଜଳି (Raghunathpur Jali) | **PASS** |
| **Village Code** | `2002359` (last 3: `359`) | `359` | **PASS** |
| **RI Circle** | Sadar RI | କଳାରାହାଙ୍ଗ / Sadar | **PASS** |
| **Plot** | `333` | `333` | **PASS** |

---

## 2. Investigation of Official Bhulekh Services & Unique Plot ID

### Part 5: Public Web Services (`bhulekhservice.asmx`)
Direct testing of `http://bhulekh.ori.nic.in/bhulekhservice.asmx` confirmed:
1. `DistrictsUnicode(dCode)`: Requires database connection initialization on server.
2. `TahasilsUnicode(dCode)`: Returns all tahasils in XML DataSet format (HTTP 200).
3. `VillagesUnicode(dCode, tCode)`: Returns all villages with numeric `vCode` in XML DataSet format (HTTP 200).
4. `KhatiyanUnicode(dCode, tCode, vCode)`: Returns all official Khatas in XML DataSet format (HTTP 200).
5. `PlotsUnicode(dCode, tCode, vCode, khata_no)`: Accepts `dCode`, `tCode`, `vCode`, and `khata_no`, returning exact plot serials (`plot_slno`, `oplot_no`) for that Khata.

### Part 6: Official Unique Plot ID Algorithm
Inspection of `http://bhulekh.ori.nic.in/SearchYourPlot.aspx` revealed that Odisha NIC generates a 16-character canonical Unique Plot ID:
```
DD-TT-VVV-PPPPP
|| || ||| |||||
|| || ||| +------- Plot Number padded (5 digits, e.g. 00333)
|| || +----------- Village Code (3 digits, e.g. 359)
|| +-------------- Tahasil Code (2 digits, e.g. 02)
+----------------- District Code (2 digits, e.g. 20)
```
For **Raghunathpur Jali, Plot 333**, the official Unique Plot ID is: `200235900333` (or `20-02-359-00333`).

---

## 3. Five Additional Known-Bad Parcels Analysis

1. **Parcel 1: `0704317_243` (Keonjhar / Keonjhar Sadar / Dimbo / Plot 243)**
   - *Symptom:* Displayed as Government Land (`ଓଡିଶା ସରକାର`).
   - *Root Cause:* Odia multi-column table text parsing lacked cell separator (`\n`), causing tenant regex to fail; parser fell back to paramount landlord (`ଓଡିଶା ସରକାର ଖେଵାଟ ନମ୍ବର 1`).
2. **Parcel 2: `0704317_1182` (Keonjhar / Keonjhar Sadar / Dimbo / Plot 1182)**
   - *Symptom:* Displayed as Government Land.
   - *Root Cause:* Same as Parcel 1 (landlord fallback bug).
3. **Parcel 3: `2002212_105` (Khordha / Bhubaneswar / Raghunathpur / Plot 105)**
   - *Symptom:* Returned wrong person's owner data.
   - *Root Cause:* Mouza ambiguity: Bhubaneswar contains two distinct "Raghunathpur" villages (codes `212` and `358`) and one "Raghunathpur Jali" (code `359`).
4. **Parcel 4: `2002358_55` (Khordha / Bhubaneswar / Raghunathpur / Plot 55)**
   - *Symptom:* Lookups failed or cross-talked with Village `212`.
   - *Root Cause:* Dropdown resolution by name without explicit `v_id` binding.
5. **Parcel 5: `2002359_334` (Khordha / Bhubaneswar / Raghunathpur Jali / Plot 334)**
   - *Symptom:* Displayed as "Government Land".
   - *Root Cause:* Mega-village dropdown population timeout (5,537 options) triggering 404 NOT_FOUND, which iOS UI converted to "Government Land".

---

## 4. Root Cause Breakdown (Parts 10, 11, 16, 17, 18)

| Issue Component | Exact Mechanism |
| :--- | :--- |
| **Root Cause Classification** | **E (Parser Error) + H (iOS Display Error) + Scraper Dropdown Timeout** |
| **Khata 01 / "ଓଡ଼ିଶା ସରକାର" Entry Point** | Introduced in [`structured_ror_parser.py:305`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/structured_ror_parser.py#L305) where `landlord` was appended as owner when `owners` was empty. |
| **Default-Government Bug** | In [`ParcelDetailSheet.swift:493`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/ParcelDetailSheet.swift#L493), `if ror.owners.isEmpty { Text("No private records found (Government Land).") }` unconditionally displayed "Government Land" for ANY empty record. |
| **Owner Leakage / Cross-Talk** | In dropdowns where plot `<option value="...">` is the Khata Number (not Plot Number), selecting by `value` instead of `label` selected the first plot of that Khata instead of the user's requested plot. |
| **Badging Semantics** | In [`CadastralPlotCardView.swift:181`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/CadastralPlotCardView.swift#L181), the card showed "Official" whenever GIS coordinates were matched, even if the RoR record was still Unverified. |

---

## 5. Proposed Architecture & Minimal Fixes

### Fix 1: iOS UI Layer (`ParcelDetailSheet.swift`)
Remove the assumption that `owners.isEmpty == Government Land`. If owners are empty and the land is unverified, display:
`"Official ownership record details could not be retrieved. Please check Bhulekh portal."`

### Fix 2: Backend Scraper Parser (`structured_ror_parser.py`)
1. Use separator-aware cell parsing (`soup.get_text(separator=" | ")` or explicit `<tr>`/`<td>` iteration).
2. **NEVER** use `landlord` as an owner fallback when tenure/svatwa is `ରୟତି` (Raiyati / Private).
3. If no tenant is parsed for a private plot, mark verification as `INSUFFICIENT_DATA` rather than injecting the state government.

### Fix 3: Large-Village Dropdown Timeout (`bhulekh_scraper.py`)
Increase plot dropdown wait timeout for villages with >1,000 plots from 10s to 30s, and select strictly by `label=plot_number`.

### Fix 4: Dual-Channel Resolution via Unique Plot ID & ASMX
Integrate `http://bhulekh.ori.nic.in/bhulekhservice.asmx` and Unique Plot ID (`20-02-359-XXXXX`) as a fast direct lookup channel alongside DOM scraping.
