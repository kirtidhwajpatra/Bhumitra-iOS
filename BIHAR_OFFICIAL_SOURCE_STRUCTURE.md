# Official Bihar Land Record Source Structure & Data Quality Specification

## 1. Official Government Source & Access Architecture

- **Primary Authority**: Department of Revenue and Land Reforms, Government of Bihar (राजस्व एवं भूमि सुधार विभाग, बिहार सरकार).
- **Official Public Portal**: `https://biharbhumi.bihar.gov.in/`
- **Jamabandi Register-II Service URL**: `https://biharbhumi.bihar.gov.in/Biharbhumi/ViewJamabandi`
- **Detailed Jamabandi Register View**: `https://biharbhumi.bihar.gov.in/Biharbhumi/ViewJamabandiDetail` (or `JamabandiPrint.aspx`)
- **Historical Khatiyan Archive**: `https://bhuabhilekh.bihar.gov.in/`
- **Cadastral GIS / Spatial Maps**: `https://bhunaksha.bihar.gov.in/`

---

## 2. Official Search Workflow

```
[ Step 1: Select District (जिला) ] ── (38 Districts)
                 │
                 ▼
[ Step 2: Select Anchal / Circle (अंचल) ] ── (534 Circles)
                 │
                 ▼
[ Step 3: Select Halka (हल्का) ] ── (Revenue Sub-circle)
                 │
                 ▼
[ Step 4: Select Mauza / Village (मौजा) ] ── (Revenue Village + Thana Number)
                 │
                 ▼
[ Step 5: Choose Search Criterion & Submit ]
       ├── (A) Search by Raiyat / Owner Name (रैयत के नाम से खोजें)
       ├── (B) Search by Khata Number (खाता संख्या से खोजें)
       ├── (C) Search by Khesra / Plot Number (खेसरा संख्या से खोजें)
       ├── (D) Search by Jamabandi Number (जमाबंदी संख्या से खोजें)
       └── (E) Search by Volume & Page Number (भाग वर्तमान एवं पृष्ठ संख्या)
                 │
                 ▼
[ Step 6: Solve Human Security CAPTCHA ]
                 │
                 ▼
[ Step 7: View Jamabandi Register-II Slip (जमाबंदी पंजी प्रति) ]
```

---

## 3. Comprehensive Field Inventory & Model Alignment

### A. Location & Administrative Hierarchy

| Official Source Field | Hindi Label | Status in Source | Bhumitra Model Target | Representation & Handling |
| :--- | :--- | :--- | :--- | :--- |
| **District** | जिला | **Mandatory** | `RoRResponse.district` | Normalized uppercase ASCII string (e.g., `"PATNA"`). |
| **Anchal / Circle** | अंचल / प्रखण्ड | **Mandatory** | `RoRResponse.tahasil` | Mapped to `tahasil` for normalized API compatibility. |
| **Halka** | हल्का | Optional / Conditional | `RoRResponse.raw_fields["halka"]` | Revenue sub-jurisdiction preserved in `raw_fields`. |
| **Mauza / Village** | मौजा / ग्राम | **Mandatory** | `RoRResponse.village` | Normalized revenue village name. |
| **Thana Number** | थाना संख्या / थाना नं | Highly Common | `BhulekhLocationIdentity.village_id` / `raw_fields["thana_no"]` | Critical survey identifier used to disambiguate identical village names. |

### B. Register Identifiers

| Official Source Field | Hindi Label | Status in Source | Bhumitra Model Target | Representation & Handling |
| :--- | :--- | :--- | :--- | :--- |
| **Jamabandi Number** | जमाबंदी संख्या | Highly Common | `RoRResponse.raw_fields["jamabandi_no"]` | Unique page index in physical/digital Register-II. |
| **Current Volume** | भाग वर्तमान | Optional | `RoRResponse.raw_fields["bhag_no"]` | Volume serial in revenue record room. |
| **Current Page** | पृष्ठ संख्या वर्तमान | Optional | `RoRResponse.raw_fields["prishth_no"]` | Page serial in revenue record room. |
| **Khata Number** | खाता संख्या | **Core Search Key** | `RoRResponse.khata_number` | Top-level normalized field. *May be missing in un-digitized legacy records*. |
| **Khesra Number** | खेसरा संख्या / प्लॉट | **Core Search Key** | `RoRResponse.plot` & `AssociatedPlot.plot_number` | Standardized parcel number. |

### C. Tenancy & Titleholders (Raiyat)

| Official Source Field | Hindi Label | Status in Source | Bhumitra Model Target | Representation & Handling |
| :--- | :--- | :--- | :--- | :--- |
| **Raiyat Name** | रैयत का नाम | **Mandatory** | `OwnerEntry.name` | Scrubbed of whitespace and honorifics; preserved as distinct person. |
| **Father / Husband** | पिता/पति का नाम | Common | `OwnerEntry.relation_name` | Name of parent/guardian. |
| **Relationship** | संबंध | Common | `OwnerEntry.relation` | Normalized to `"Father"`, `"Husband"`, `"Mother"`, `"Guardian"`. |
| **Caste / Social Group** | जाति / श्रेणी | Optional | `OwnerEntry.ownership_details` | Stored as supplementary context; not used for identity resolution. |
| **Share / Hissa** | हिस्सा / अंश | Optional | `OwnerEntry.share` | Fractional holding (e.g., `"1/2"`, `"1/4"`, `"16 आना"`). |

### D. Parcel Schedule, Area & Classification

| Official Source Field | Hindi Label | Status in Source | Bhumitra Model Target | Representation & Handling |
| :--- | :--- | :--- | :--- | :--- |
| **Total Area (Acre/Decimal)**| कुल रकबा (एकड़ - डिसमिल)| Common in Modern Records| `RoRResponse.area` / `AssociatedPlot.area` | Standardized format: `"X.XXX Acre"`. |
| **Traditional Units (B-K-D)**| बीघा - कट्ठा - धूर | Common in Legacy Records | `RoRResponse.area` + `raw_fields["traditional_area"]` | Normalized to Acre mathematically; original unit string preserved in `remarks`. |
| **Land Classification** | जमीन का प्रकार / किस्म | Common | `RoRResponse.land_type` / `AssociatedPlot.land_type` | Standardized descriptive classification (e.g. `Bhit-2`, `Dhanhar-1`). |
| **Rent (Lagan)** | मूल लगान | Optional | `AssociatedPlot.rent_cess` / `raw_fields["lagan"]` | Base annual government revenue demand. |
| **Cesses (Road, Edu, Dev)** | उपकर (पथ, शिक्षा, विकास)| Optional | `RoRResponse.raw_fields["cess_breakup"]` | Itemized tax surcharges. |

### E. Physical Boundaries & Legal Mutation History

| Official Source Field | Hindi Label | Status in Source | Bhumitra Model Target | Representation & Handling |
| :--- | :--- | :--- | :--- | :--- |
| **North Boundary (उत्तर)** | चौहद्दी उत्तर | Optional / Common | `RoRResponse.raw_fields["boundary_north"]` | Physical parcel neighbor/road boundary. |
| **South Boundary (दक्षिण)**| चौहद्दी दक्षिण | Optional / Common | `RoRResponse.raw_fields["boundary_south"]` | Physical parcel neighbor boundary. |
| **East Boundary (पूर्व)** | चौहद्दी पूर्व | Optional / Common | `RoRResponse.raw_fields["boundary_east"]` | Physical parcel neighbor boundary. |
| **West Boundary (पश्चिम)** | चौहद्दी पश्चिम | Optional / Common | `RoRResponse.raw_fields["boundary_west"]` | Physical parcel neighbor boundary. |
| **Mutation Case Number** | दाखिल-खारिज वाद संख्या | Optional / Historical | `RoRResponse.raw_fields["mutation_case_no"]` | Legal title transfer case reference. |
| **Mutation Year** | दाखिल-खारिज वर्ष | Optional / Historical | `RoRResponse.raw_fields["mutation_year"]` | Year of Circle Officer mutation order. |
| **Last Tax Receipt** | अंतिम लगान रसीद संख्या | Optional | `RoRResponse.raw_fields["last_receipt_no"]` | Online tax payment receipt reference. |

---

## 4. Critical Data Quality Rules & Field State Taxonomy

The Government of Bihar portal explicitly notes that legacy Jamabandi records digitized from manual registers may contain missing Khata numbers, blank Khesra numbers, or unrecorded areas.

### Parser Field State Taxonomy:

1. **`SOURCE_FIELD_PRESENT`**: Field exists in the HTML/JSON payload and contains valid data.
2. **`SOURCE_FIELD_MISSING`**: Field is genuinely absent from the official source record.
   - *Rule*: Never fabricate a placeholder value (e.g. do NOT invent `"Khata 0"` or `"0.000 Acre"` for missing areas). Represent as `None` / `null`.
3. **`PARSER_EXTRACTION_FAILED`**: Field exists in DOM but parser failed to extract it due to DOM mutation or unhandled markup.
   - *Rule*: Fails verification and generates an alert.
4. **`SOURCE_RECORD_INVALID`**: Source document contains impossible or contradictory data (e.g. negative area, conflicting Raiyat identities).
   - *Rule*: Sets `verification.status = "INSUFFICIENT_DATA"` or returns `RoRErrorCode.PARSE_FAILED`.
