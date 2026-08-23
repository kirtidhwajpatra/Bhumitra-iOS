# PHASE 7.7 BASELINE FAILURE REPORT

**Date:** August 23, 2026  
**Status:** REPRODUCED & ISOLATED  
**Production Status:** **NO-GO**  

---

## 1. Case A: Chakuli_Mosaic Plot 647 (Atabira vs Attabira)

- **Requested Identity:**
  - District: `Bargarh`
  - Tahasil: `Atabira`
  - Village: `Chakuli_Mosaic`
  - Plot: `647`
- **Request Parameters:** `district=Bargarh&tahasil=Atabira&village=Chakuli_Mosaic&plot=647`
- **Bhulekh Identity Expected:** District `01` (Bargarh), Tahasil `02` (Attabira / `ଅତାବିରା`), Village `Chakuli`
- **HTTP Status:** `HTTP 404 Not Found` (5.82s)
- **Raw Backend JSON:**
  ```json
  {
    "detail": {
      "code": "ROR_NOT_FOUND",
      "message": "No official RoR record found for plot '647' in village 'Chakuli_Mosaic'.",
      "retryable": false,
      "details": "Tahasil 'ATABIRA' could not be verified in official Bhulekh records for district 'BARGARH'."
    }
  }
  ```
- **Root Cause:** In Bhulekh's official catalog, District `Bargarh` has Tahasil `Attabira` (double 't'), whereas cadastral GIS passes `Atabira` (single 't'). Resolver fails closed because no scoped alias maps `Atabira` $\rightarrow$ `Attabira` in District `Bargarh`.

---

## 2. Case B: G_Dimbo Plot 12 and Plot 1 (Option Value vs Label Mismatch)

### Case B1: Plot 12
- **Requested Identity:**
  - District: `Keonjhar` (ID `07`)
  - Tahasil: `Keonjhar Sadar` (ID `04`)
  - Village: `G_Dimbo` (ID `0704317` / Mouza `317`)
  - Requested Plot: `12`
- **Request Parameters:** `district=Keonjhar&tahasil=Keonjhar+Sadar&village=G_Dimbo&plot=12&b_id=0704&v_id=0704317`
- **Bhulekh Dropdown State:** Contains `<option value="12">168</option>` (where value `12` is Khata 12, and visible label is Plot 168).
- **Scraper Behavior:** Selected dropdown by option `value="12"`, querying **Khata 12** instead of Plot 12!
- **Bhulekh Returned Plot:** Plot `168` (Khata `12`).
- **HTTP Status:** `HTTP 422 Unprocessable Entity` (25.49s)
- **Raw Backend JSON:**
  ```json
  {
    "detail": {
      "code": "ROR_IDENTITY_MISMATCH",
      "message": "Official land record could not be verified as the exact same parcel.",
      "retryable": false,
      "details": "Unable to verify this parcel from the official land record: Plot mismatch: Requested plot '12', but portal returned plot '168'."
    }
  }
  ```

### Case B2: Plot 1
- **Requested Identity:** Plot `1`
- **Bhulekh Dropdown State:** Contains `<option value="1">453/975</option>` (where value `1` is Khata 1, and visible label is Plot 453/975).
- **Scraper Behavior:** Selected option `value="1"`, querying **Khata 1** instead of Plot 1!
- **Bhulekh Returned Plot:** Plot `453/975` (Khata `1`).
- **HTTP Status:** `HTTP 422 Unprocessable Entity` (24.16s)
- **Raw Backend JSON:**
  ```json
  {
    "detail": {
      "code": "ROR_IDENTITY_MISMATCH",
      "message": "Official land record could not be verified as the exact same parcel.",
      "retryable": false,
      "details": "Unable to verify this parcel from the official land record: Plot mismatch: Requested plot '1', but portal returned plot '453/975'."
    }
  }
  ```
- **Root Cause:** `bhulekh_scraper.py` selected dropdown option by `value` instead of `text/label`.

---

## 3. Case C: Raghunathpur Jali Plot 333 (Mega-Village Dropdown Scale)

- **Requested Identity:**
  - District: `Khordha` (ID `20`)
  - Tahasil: `Bhubaneswar` (ID `02`)
  - Village: `Raghunathpur_Jali` (Mouza `359` - `ରଘୁନାଥପୁର ଜଳି`)
  - Plot: `333`
- **Request Parameters:** `district=Khordha&tahasil=Bhubaneswar&village=Raghunathpur_Jali&plot=333&b_id=2002&v_id=2002359`
- **Bhulekh Village Plot Count:** 5,537 plots.
- **Scraper Behavior:** Switched mode to `Plot` (`#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1`). The official ASP.NET AJAX server script takes 45–90s to serialize 5,537 `<option>` elements, exceeding the scraper timeout and holding the HTTP client request until timeout (>120s).
- **HTTP Status:** Client Timeout / 504 Gateway Timeout.
- **Root Cause:** The browser dropdown population mechanism cannot scale to mega-villages with >1,000 plots when relying on ASP.NET DOM injection.

---

## 4. Baseline Summary Table

| Case | Requested Plot | Portal Returned Plot | Status Code | Failure Reason |
| :--- | :--- | :--- | :--- | :--- |
| **A (Atabira)** | `647` | None | `404` | Tahasil alias `Atabira` $\rightarrow$ `Attabira` missing in Bargarh catalog |
| **B1 (Dimbo 12)** | `12` | `168` (Khata 12) | `422` | Selected dropdown by `value="12"` instead of `text="12"` |
| **B2 (Dimbo 1)** | `1` | `453/975` (Khata 1) | `422` | Selected dropdown by `value="1"` instead of `text="1"` |
| **C (Jali 333)** | `333` | None | `Timeout` | 5,537 option ASP.NET AJAX rendering timeout |

Production Status: **NO-GO**
