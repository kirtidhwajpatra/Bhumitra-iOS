# CRITICAL BUG INVESTIGATION: BHUMITRA GIS → BHULEKH IDENTITY MISMATCH
## Root Cause Analysis & End-to-End Investigation Report

**Investigation Status:** ROOT CAUSE IDENTIFIED & REPRODUCED  
**Affected Area:** Real-world parcel lookup (Private land reported as "Government Land" / Missing owners)  
**Investigation Date:** August 22, 2026  

---

### Executive Summary

During real-world verification, multiple private parcels were reported in Bhumitra as **"Government Land"** (`ଓଡିଶା ସରକାର`) with missing owner records, despite being verified private raiyati holdings on the official Odisha Bhulekh portal.

By performing a full live DOM trace and packet inspection from the GIS boundary click down to the ASP.NET postback response on `bhulekh.ori.nic.in`, we have pinpointed the exact multi-layer root causes responsible for this anomaly.

---

### Layer-by-Layer Investigation & Trace

#### Layer 1: GIS Data Source (`odisha4kgeo.in` / ORSAC)
- **Finding:** Raw GIS GeoJSON features from ORSAC contain **ONLY ONE** attribute: `revenue_plot`.
- **Identity Origin:** All administrative context (`district_name`, `block_name`, `village_id`, `village_name`) is attached dynamically during client hierarchy navigation.
- **Village Code Structure:** ORSAC uses a 7-digit hierarchical code: `DDBBVVV`
  - `DD`: District (e.g., `07` = Keonjhar)
  - `BB`: Block/Tahasil (e.g., `04` = Keonjhar Sadar)
  - `VVV`: Village sequence (e.g., `317` = Dimbo)
- **Village Name Discrepancy:** ORSAC returns Anglicized names with prefixes and numeric suffixes (e.g., `G_Dimbo`, `G_Baiganapasi`, `G_Kusumita_16`, `G_Talakampadihi_196`), whereas Bhulekh portal dropdowns contain Odia script strings (`ଡ଼ିମ୍ବୋ`, `ବାଇଗଣପସି`, `କୁସୁମିତା`).

#### Layer 2: Scraper Navigation & Dropdown Selection (`bhulekh_scraper.py`)
- **Finding 1 (English Switch Ineffective):** Clicking `ctl00_btnenglish` on the Bhulekh portal does NOT translate the dynamic dropdown `<option>` values into English on many portal nodes; they remain in Odia script.
- **Finding 2 (Dropdown Selection by Label vs Value):** On the Plot search dropdown (`#ctl00_ContentPlaceHolder1_ddlBindData`), the `<option value="...">` is the **Khata Number** (padded with whitespace), while the `<option text="...">` is the **Plot Number**. Selecting by `value` causes all plots sharing a Khata to collapse onto the first plot in that Khata. The scraper must select strictly by `label=plot`.

#### Layer 3: RoR Page Parsing & Government Land Fallback (`structured_ror_parser.py`)
- **ROOT CAUSE 1 (Odia Table Cell Newline Collapse):**
  When parsing tenant names from the Odia format:
  ```python
  page_text = soup.get_text()
  praja_m = re.search(r'2\)\s*ପ୍ରଜାର\s*ନାମ[^\n]*\n([^\n]+)', page_text)
  ```
  `soup.get_text()` concatenates adjacent `<td>` table cells on the same line without a newline:
  `'\n2) ପ୍ରଜାର ନାମ, ପିତାର ନାମ, ଜାତି ଓ ବାସସ୍ଥାନଉଜ୍ଵଳ ଚନ୍ଦ୍ର ସାହୁ ପି:ହରିହର ସାହୁ...\n'`
  Because there is no `\n` between the label and the value, `praja_m` evaluates to `None`, resulting in `owners = []`.

- **ROOT CAUSE 2 (Paramount Landlord False Fallback):**
  In Step 7 of `structured_ror_parser.py`:
  ```python
  if not owners and landlord:
      owners.append(OwnerEntry(name=landlord, share="1.000", khata_number=khata_number))
  ```
  On Odisha land records, the state government is listed as the paramount landlord (`ଜମିଦାରଙ୍କ ନାମ: ଓଡିଶା ସରକାର ଖେଵାଟ ନମ୍ବର 1`) even on private (`ରୟତି` / Raiyati) khatas.
  When the tenant parsing fails due to Root Cause 1, the parser falls back to the landlord and assigns **"ଓଡିଶା ସରକାର" (Government of Odisha)** as the owner.

#### Layer 4: Native iOS Presentation (`ParcelDetailSheet.swift`)
- When `ror.owners.isEmpty`, the iOS app displays:
  ```swift
  Text("No private records found (Government Land).")
  ```
- When `ror.owners` contains the fallback landlord ("ଓଡିଶା ସରକାର"), the UI displays the owner row as "Government of Odisha".

---

### Verification Proof on Live Portal

**Test Case:** District: Keonjhar (07), Tahasil: Keonjhar Sadar (04), Village: Dimbo (317), Plot: 243
- **Official Bhulekh Status:**
  - Khata: `12`
  - Svatwa (Tenure): `ରୟତି` (Raiyati / Private)
  - Raiyat (Tenant): `ଉଜ୍ଵଳ ଚନ୍ଦ୍ର ସାହୁ ପି:ହରିହର ସାହୁ ଜା: ତେଲି ବା: ନିଜଗାଁ` (Ujwal Chandra Sahu)
  - Landlord: `ଓଡିଶା ସରକାର ଖେଵାଟ ନମ୍ବର 1`
  - Land Type: `ଶାରଦ ତିନି`
  - Area: `3 Acre 6500 Decimal`
- **Result:** Successfully traced and verified.

---

### Key Takeaways for Remediation
1. Use separator-aware cell parsing (e.g. `soup.get_text(separator=" | ")` or direct `<tr>`/`<td>` traversal) when extracting Odia raiyat details.
2. NEVER use `landlord` as a fallback for `owners` when `tenure` or `svatwa` is `ରୟତି` (Private/Raiyati).
3. Ensure GIS village code `v_id` (`DDBBVVV`) last 3 digits are used as primary key for dropdown resolution on Bhulekh.
