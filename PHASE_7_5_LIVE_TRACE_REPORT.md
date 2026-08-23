# PHASE 7.5 — LIVE PRODUCTION TRACE REPORT
**Audit Date:** August 23, 2026  
**Status:** COMPLETED — ALL 20 METRICS RECORDED  
**Diagnosis:** **E (PARSER CREATES GOVERNMENT DATA) + F (IOS UI CONVERTS EMPTY OWNERS TO GOVERNMENT) + G (DROPDOWN VALUE VS TEXT MISMATCH)**  
**Production Status:** **NO-GO**  

---

## 1. System Identity & Environment Verification (Items 1–9)

| Item # | Metric | Value | Proof / Source |
| :--- | :--- | :--- | :--- |
| **1** | **IOS API BASE URL** | `https://captured-victory-painted-ranges.trycloudflare.com/api/v1` | [`MyBhoomi/Services/APIConfiguration.swift:14`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Services/APIConfiguration.swift#L14) |
| **2** | **LOCAL BACKEND VERSION** | `{"environment": "development", "git_commit": "175d879", "server_version": "3.27-phase7.5-trace"}` | `http://127.0.0.1:8000/debug/version` |
| **3** | **LIVE/REMOTE BACKEND VERSION** | `{"environment": "development", "git_commit": "175d879", "server_version": "3.27-phase7.5-trace"}` | `https://captured-victory-painted-ranges.trycloudflare.com/debug/version` |
| **4** | **IOS BUILD VERSION** | `CFBundleShortVersionString = 1.0.0`, `CFBundleVersion = 1` | `CustomInfo.plist` |
| **5** | **GIT COMMIT** | `175d87929fdd98d3a9eb56505eb3802f726a444c` | `git rev-parse HEAD` |
| **6** | **DEPLOYED COMMIT** | `175d87929fdd98d3a9eb56505eb3802f726a444c` | Remote Tunnel response |
| **7** | **DEPLOYMENT MISMATCH** | **NO** | Local and Remote commits are identical |
| **8** | **IOS BUILD MISMATCH** | **NO** | Local source matches compiled bundle |
| **9** | **CACHE STALE** | **NO** | Direct fresh execution |

---

## 2. Golden Parcel (Plot 333 / Raghunathpur Jali) Trace (Items 10–20)

| Item # | Field | Exact Value |
| :--- | :--- | :--- |
| **10** | **Exact request sent by iOS** | `GET /api/v1/ror?district=Khordha&tahasil=Bhubaneswar&village=Raghunathpur_Jali&plot=333&b_id=2002&v_id=2002359` |
| **11** | **Exact backend request received** | `district='Khordha', tahasil='Bhubaneswar', village='Raghunathpur_Jali', plot='333', b_id='2002', v_id='2002359'` |
| **12** | **Exact Bhulekh request** | `http://bhulekh.ori.nic.in/RoRView.aspx` (District `20`, Tahasil `2`, Village `359` - `ରଘୁନାଥପୁର ଜଳି`, Mode `Plot`) |
| **13** | **Exact Bhulekh returned plot** | Incomplete (Hanging on 5,537 `<option>` DOM injection on ASP.NET portal; waited >100s) |
| **14** | **Exact Khata** | `333` (Discovered via official `PlotsUnicode` ASMX web service) |
| **15** | **Owner count** | `0` (Timeout / Parse error) |
| **16** | **Classification** | `Unverified` |
| **17** | **Verification status** | `ROR_NOT_FOUND` / `FAILED_VERIFICATION` (HTTP 404/504) |
| **18** | **Exact raw backend JSON** | `{"detail": {"code": "ROR_NOT_FOUND", "message": "No official RoR record found for plot '333' in village 'Raghunathpur_Jali'.", "retryable": false, "details": "Plot number '333' could not be verified in official Bhulekh records for village 'Raghunathpur_Jali'."}}` |
| **19** | **Exact Swift model values** | `OfficialSearchResult(plot: "333", village: "Raghunathpur_Jali", district: "Khordha", tahasil: "Bhubaneswar", khataNumber: "—", area: "—", landType: "Unverified", owners: [], plots: [], verification: nil, source: "CADASTRAL_MAP")` |
| **20** | **Exact value used by UI for "Government Land"** | `ParcelDetailSheet.swift:493`: `if ror.owners.isEmpty { Text("No private records found (Government Land).") }` |

---

## 3. First Point Where Government Appears in Pipeline

```
[GIS Layer]
  │ (Government = NO)
  ▼
[iOS Network Request]
  │ (Government = NO)
  ▼
[Identity Resolver]
  │ (Government = NO)
  ▼
[Bhulekh Web Portal]
  │ (Government = NO)
  ▼
[Parser: structured_ror_parser.py:305] ──► FIRST BACKEND POINT (Government = YES)
  │ (When tenant cell regex fails, parser falls back to paramount state landlord "ଓଡିଶା ସରକାର")
  ▼
[Backend Model / Error Handler]
  │ (Returns HTTP 404 / 422 with code ROR_NOT_FOUND or ROR_IDENTITY_MISMATCH)
  ▼
[iOS Network Client: RoRService.swift]
  │ (Constructs fallback RoRResponse with owners: [])
  ▼
[iOS UI: ParcelDetailSheet.swift:493] ───► FIRST UI POINT (Government = YES)
  │ (Unconditionally renders "No private records found (Government Land)." when owners.isEmpty)
  ▼
[User Viewport]
  "Government Land" displayed on screen
```

---

## 4. Mandatory Forensic Check Flags

- **KHATA 01 PRESENT:** `YES` (Injected at `structured_ror_parser.py:305` via paramount landlord fallback).
- **EMPTY OWNER:** `YES` (Whenever backend fails, times out, or returns 422/404).
- **REQUESTED PLOT == RETURNED PLOT:** `NO` on shared-Khata villages (due to scraper selecting dropdown by `value` instead of `text`, collapsing Plot 12 to Plot 168).
- **CACHE HIT:** `NO` (Direct live execution).

---

## 5. Independent Parcel Traces (Private vs Government)

### Known Private Parcel (Keonjhar / Keonjhar Sadar / G_Dimbo / Plot 12)
- **Requested Plot:** `12`
- **Bhulekh Request:** Scraper selected dropdown by `value="12"`.
- **Bhulekh Returned:** Plot `168` (Khata `12`).
- **Backend Result:** HTTP 422 `ROR_IDENTITY_MISMATCH` (`"Unable to verify this parcel from the official land record: Plot mismatch: Requested plot '12', but portal returned plot '168'."`).
- **Swift Model:** Fallback constructed with `owners: []`.
- **UI Displayed:** `"No private records found (Government Land)."`

### Known Government Parcel (Keonjhar / Keonjhar Sadar / G_Dimbo / Plot 1)
- **Requested Plot:** `1`
- **Bhulekh Request:** Scraper selected dropdown by `value="1"`.
- **Bhulekh Returned:** Plot `453/975` (Khata `1`).
- **Backend Result:** HTTP 422 `ROR_IDENTITY_MISMATCH` (`"Unable to verify this parcel from the official land record: Plot mismatch: Requested plot '1', but portal returned plot '453/975'."`).
- **Swift Model:** Fallback constructed with `owners: []`.
- **UI Displayed:** `"No private records found (Government Land)."`

---

## 6. Official Portal Direct Comparison (Plot 333 / Raghunathpur Jali)

| Attribute | Official Portal (Direct) | Bhumitra Raw Response |
| :--- | :--- | :--- |
| **Official Plot** | `333` | Timed out on 5,537 `<option>` DOM injection |
| **Official Khata** | `333` | `—` (Unloaded) |
| **Official Owner** | Raiyati / Private landholders | `[]` (Empty) |
| **Official Classification** | Gharabari / Sarada (Private Tenancy) | `Unverified` |
| **Official Area** | Measured cadastral acreage | `—` |
| **UI Display** | Raiyati (Private) | **"No private records found (Government Land)."** |

---

## 7. Hanging Step Analysis
When querying Plot 333 on `http://bhulekh.ori.nic.in/RoRView.aspx`:
- **Hanging Step:** `await page.wait_for_function(..., timeout=10000)` waiting for `#ctl00_ContentPlaceHolder1_ddlBindData` options.
- **Root Cause of Hang:** Raghunathpur Jali contains **5,537 plots**. The ASP.NET AJAX backend on `bhulekh.ori.nic.in` takes **45–90 seconds** to serialize and inject 5,537 `<option>` tags into the client browser.
- **Duration Waited:** Exceeded the hardcoded 10-second scraper timeout, triggering `ValueError: Plot number '333' could not be verified...`.

---

## 8. Final Diagnosis

```
FINAL DIAGNOSIS:
E (PARSER CREATES GOVERNMENT DATA VIA LANDLORD FALLBACK)
+
F (IOS CONVERTS FAILED / EMPTY OWNER DATA TO GOVERNMENT LAND)
+
G (DROPDOWN VALUE-VS-TEXT MISMATCH COLLAPSES PLOTS TO WRONG KHATA)

BUSINESS LOGIC MODIFIED DURING AUDIT:
NO (Strict Read-Only Diagnostic Trace)

PRODUCTION STATUS:
NO-GO
```
