# PHASE 7.24 — REAL MAP PARCEL FAILURE FORENSIC INVESTIGATION REPORT
**Status**: INVESTIGATION COMPLETE & FIXED  
**Target Platform**: Bhumitra Core (FastAPI Backend + Playwright / ASP.NET Scraper + Live NIC Bhulekh)

---

## 1. GIS Map Feature Trace

When the user taps **Barimelak / Plot 378** and **Barinayada / Plot 347** on the physical iPhone:

### Feature 1: Barimelak / Plot 378
- **districtName**: `Baleswar` (or `Balasore`)
- **districtID**: `218` (GIS) $\rightarrow$ `1` (Bhulekh)
- **tahasilName**: `Simulia`
- **tahasilID (Block ID)**: `0106`
- **gpName**: `Bari` (GP ID `01060006`)
- **villageName**: `Barimelak`
- **villageID (GIS)**: `0106140` $\rightarrow$ Bhulekh Mouza ID: `140` (`ବରିମେଳକ`)
- **plotNumber**: `378`

### Feature 2: Barinayada / Plot 347
- **districtName**: `Baleswar` (or `Balasore`)
- **districtID**: `218` (GIS) $\rightarrow$ `1` (Bhulekh)
- **tahasilName**: `Simulia`
- **tahasilID (Block ID)**: `0106`
- **gpName**: `Bari` (GP ID `01060006`)
- **villageName**: `Barinayada`
- **villageID (GIS)**: `0106146` $\rightarrow$ Bhulekh Mouza ID: `146` (`ବରିନୟାଦା`)
- **plotNumber**: `347`

---

## 2. Complete Request & Pipeline Trace (First Point of Failure)

```text
Physical iPhone Map Tap
        │
        ▼
[iOS Request]: GET /api/v1/ror?district=Baleswar&tahasil=Simulia&village=Barimelak&plot=378&b_id=0106&v_id=0106140
        │
        ▼
[FastAPI / Bhulekh Router]: Calls ror_service.get_ror(...)
        │
        ▼
[SOAP Pre-Resolution]: SOAP does not have parent Khata mapping for Plot 378 (returns None)
        │
        ▼
[Playwright Fallback Execution]:
  1. Selects District: 1 (Balasore)
  2. Selects Tahasil: 6 (Simulia / ସିମିଳିଆ)
  3. Selects Village: 140 (Barimelak / ବରିମେଳକ)
        │
        ▼
[FIRST POINT OF FAILURE #1 — Corrupt Static TAHASIL_MAP]:
  • `TAHASIL_MAP` in `scrapers/bhulekh_mappings.py` had static, corrupt mapping: `("1", "SIMULIA"): "10"`.
  • In official live Bhulekh, Simulia is Tahasil `6` (Tahasil `10` is `ଔପଦା` / Oupada).
  • `get_tahasil_id("1", "Simulia")` returned `10`.
  • Portal returned Tahasil `6` (`ସିମିଳିଆ`).
  • `verify_ror_result()` detected a hard Level 3 Tahasil Conflict (`10 != 6`) and returned `422 Location mismatch`.

[FIRST POINT OF FAILURE #2 — Plot Dropdown PostBack Parsing]:
  • When SOAP fails to pre-resolve parent Khata, Playwright switches to Plot mode.
  • In Bhulekh ASP.NET, dropdown options in Plot mode have:
      - `text`: Plot Number (`378`)
      - `value`: Parent Khata Number (`160                           `)
  • Selecting by `value` selected the FIRST plot on that Khata (Plot 57) instead of Plot 378, and failed to load the back page (`gvRorBack`).
```

---

## 3. Root Cause Statement

1. **Tahasil ID Inaccuracy in `TAHASIL_MAP`**: District 1 (Balasore) in `TAHASIL_MAP` had shifted/incorrect tahasil IDs (`Simulia` mapped to `10` instead of `6`, `Basta` to `5` instead of `2`, etc.), causing Level 3 conflict detection to reject live portal results as a Tahasil mismatch (`10 != 6`).
2. **Plot Search Parent-Khata Discovery**: When SOAP pre-resolution is absent, the scraper did not use the parent Khata value discovered from the Plot dropdown to execute a full Khatiyan mode extraction (loading both Front and Back RoR pages).

---

## 4. Fix Applied

1. **Corrected Tahasil Table in [`scrapers/bhulekh_mappings.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_mappings.py)**:
   Updated District 1 (Balasore) Tahasil mappings to strictly match the official 12 Tahasils from the live Bhulekh catalog:
   - `ID 1`: Baleswar (`ବାଲେଶ୍ଵର`)
   - `ID 2`: Basta (`ବସ୍ତା`)
   - `ID 3`: Jaleswar (`ଜଳେଶ୍ଵର`)
   - `ID 4`: Nilagiri (`ନୀଳଗିରି`)
   - `ID 5`: Soro (`ସୋରୋ`)
   - `ID 6`: Simulia (`ସିମିଳିଆ`)
   - `ID 7`: Baliapal (`ବାଲିଆପାଳ`)
   - `ID 8`: Bhogarai (`ଭୋଗରାଇ`)
   - `ID 9`: Khaira (`ଖଇରା`)
   - `ID 10`: Oupada (`ଔପଦା`)
   - `ID 11`: Remuna (`ରେମୁଣା`)
   - `ID 12`: Bahanaga (`ବାହାନଗା`)

2. **Automated Parent-Khata Discovery in [`scrapers/bhulekh_scraper.py`](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/scrapers/bhulekh_scraper.py)**:
   When SOAP pre-resolution is unavailable, Playwright inspects the Plot dropdown, extracts the exact parent Khata ID (e.g. `Khata 160` for `Plot 378`), and automatically loads the full Khatiyan Front & Back pages.

---

## 5. Live Verification Results

### 1. Barimelak / Simulia / Plot 378
- **Canonical Key**: `1:6:140:378`
- **Khata**: `160`
- **Area**: `0 Acre 1700 Decimal`
- **Land Type**: `ଘରବାରି`
- **Owners**:
  1. `ବୃନ୍ଦାବନ ଲେଙ୍କା ପି:ରାଧାଶ୍ୟାମ ଲେଙ୍କା ଜା: ଖଣ୍ଡାୟତ ବା: ନିଜଗାଁ`
- **Verification**: `VERIFIED (HTTP 200 OK)`

### 2. Barinayada / Simulia / Plot 347
- **Canonical Key**: `1:6:146:347`
- **Khata**: `48`
- **Area**: `1 Acre 6100 Decimal`
- **Land Type**: `ସ୍ଥିତିବାନ`
- **Owners**:
  1. `ବ୍ରଜ ସୁନ୍ଦର ପଟ୍ଟନାୟକ`
  2. `ଗୌର ସୁନ୍ଦର ପଟ୍ଟନାୟକ ପି: ପୀତାମ୍ବର ପଟ୍ଟନାୟକ`
  3. `ଶଚୀମଣି ପଟ୍ଟନାୟକ ସ୍ଵା: ପୀତାମ୍ବର ପଟ୍ଟନାୟକ ଜା: କରଣ ବା: ନିଜଗାଁ`
- **Verification**: `VERIFIED (HTTP 200 OK)`

---

## 6. Test Suite Status

- **Backend Pytest Suite**: **669 / 669 Passing (100%)**
- **Live Cloudflare Tunnel**: **HTTP 200 OK for both target parcels**
- **Connected iPhone**: **Ready for live testing on `aabbc’s iPhone`**
