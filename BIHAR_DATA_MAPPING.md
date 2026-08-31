# Bihar Land Records Data Mapping & Normalization Specification

## 1. Overview & Data Sources

Bihar's Department of Revenue and Land Reforms (राजस्व एवं भूमि सुधार विभाग, बिहार सरकार) digitizes land records across two primary subsystems:
1. **जमाबंदी पंजी (Jamabandi Register-II / Register-II)**: The active tenancy and revenue register recording current title holders, plot-wise possession, annual rent (Lagan), cess breakdown, and mutation (Dakhil-Kharij) references.
2. **खतियान (Khatiyan / RoR)**: The Cadastral / Survey Record of Rights detailing historical settlement rights, shares, classification, and tenant genealogy.
3. **भू-नक्शा (BhuNaksha Bihar)**: The cadastral parcel mapping system providing GeoJSON / vector parcel boundaries and plot spatial topologies.

---

## 2. Bihar Land Record Field Mapping Table

| Bihar Portal Field (Hindi / Vernacular) | English Revenue Meaning | Bhumitra Normalized Field (`models/ror_response.py`) | Normalization Confidence | Mapping Notes & Rules |
| :--- | :--- | :--- | :--- | :--- |
| **जिला (Zila)** | Administrative District | `RoRResponse.district` | **High (100%)** | Normalized uppercase English name (e.g., `"PATNA"`, `"GAYA"`). |
| **अंचल / प्रखण्ड (Anchal / Circle)** | Revenue Circle / Tehsil | `RoRResponse.tahasil` | **High (100%)** | Mapped to `tahasil` in Bhumitra normalized schema. |
| **हल्का (Halka)** | Revenue Sub-Circle / GP | `RoRResponse.raw_fields["halka"]` | **High (100%)** | Bihar administrative level between Anchal and Mauza. |
| **मौजा (Mauza)** | Revenue Village with Thana No. | `RoRResponse.village` | **High (100%)** | Contains Village name and Revenue Thana number (e.g., `"BEGAMPUR (थाना नं. 124)"`). |
| **थाना संख्या (Thana No.)** | Revenue Survey Jurisdiction No. | `BhulekhLocationIdentity.village_id` / `raw_fields["thana_no"]` | **High (100%)** | Critical cadastral identifier for disambiguating identical village names. |
| **खाता संख्या (Khata Number)** | Account / Ledger Number | `RoRResponse.khata_number` | **High (100%)** | Direct 1:1 mapping to `khata_number`. |
| **खेसरा संख्या (Khesra Number)** | Plot / Survey Number | `RoRResponse.plot` / `AssociatedPlot.plot_number` | **High (100%)** | Standardized using numeric cleaner (e.g. `"142"`, `"142/1"`). |
| **जमाबंदी संख्या (Jamabandi No.)** | Register-II Page / Entry No. | `RoRResponse.raw_fields["jamabandi_no"]` | **High (100%)** | Unique register serial within the Mauza. |
| **भाग वर्तमान / पृष्ठ वर्तमान** | Current Volume / Page Number | `RoRResponse.raw_fields["vol_page_no"]` | **High (100%)** | Used in Bihar physical register cross-referencing. |
| **रैयत का नाम (Raiyat Name)** | Current Titleholder / Landowner | `OwnerEntry.name` | **High (100%)** | Extracted into `RoRResponse.owners[]`. |
| **पिता / पति का नाम (Father/Husband)** | Guardian / Parent Name | `OwnerEntry.relation_name` | **High (100%)** | Relationship designated as `"Father"` or `"Husband"`. |
| **संबंध (Relation)** | Relationship Type | `OwnerEntry.relation` | **High (100%)** | Extracted as `"Father"`, `"Husband"`, etc. |
| **जाति (Caste / Category)** | Social category recorded in RoR | `OwnerEntry.ownership_details` | **Medium (90%)** | Stored in supplementary details if present; not used for identity matching. |
| **कुल रकबा (Total Rakba / Area)** | Land Parcel Area | `RoRResponse.area` / `AssociatedPlot.area` | **High (100%)** | Standardized to Decimal / Acre with original local units preserved in raw fields. |
| **एकड़ (Acre) / डिसमिल (Decimal)** | Metric / Standard Land Units | `RoRResponse.area` | **High (100%)** | Direct standard unit in newer Bihar digital surveys. |
| **बीघा - कट्ठा - धूर (Bigha-Katha-Dhur)** | Traditional Bihar Land Units | `RoRResponse.raw_fields["traditional_area"]` | **High (100%)** | Converted to Decimal (1 Bigha = 20 Katha = 400 Dhur = ~62 Decimal in Bihar standard). |
| **जमीन का प्रकार / किस्म (Land Classification)** | Land Classification (Bhit, Dhanhar, Makan) | `RoRResponse.land_type` / `AssociatedPlot.land_type` | **High (100%)** | Normalized into agricultural / residential / commercial categories. |
| **लगान (Lagaan / Rent)** | Base Land Revenue Tax | `AssociatedPlot.rent_cess` / `raw_fields["lagan"]` | **High (100%)** | Base annual government revenue demand. |
| **पथ कर (Road Cess)** | Road Infrastructure Cess | `RoRResponse.raw_fields["road_cess"]` | **High (100%)** | Specific Bihar cess item. |
| **शिक्षा उपकर (Education Cess)** | Educational Development Cess | `RoRResponse.raw_fields["education_cess"]` | **High (100%)** | Specific Bihar cess item. |
| **कृषि उपकर / विकास उपकर (Agri/Dev Cess)** | Development / Agricultural Cess | `RoRResponse.raw_fields["dev_cess"]` | **High (100%)** | Aggregated with rent for total tax liability. |
| **चौहद्दी - उत्तर (North Boundary)** | North Neighboring Plot/Owner | `RoRResponse.raw_fields["boundary_north"]` | **High (100%)** | Physical parcel demarcation. |
| **चौहद्दी - दक्षिण (South Boundary)** | South Neighboring Plot/Owner | `RoRResponse.raw_fields["boundary_south"]` | **High (100%)** | Physical parcel demarcation. |
| **चौहद्दी - पूर्व (East Boundary)** | East Neighboring Plot/Owner | `RoRResponse.raw_fields["boundary_east"]` | **High (100%)** | Physical parcel demarcation. |
| **चौहद्दी - पश्चिम (West Boundary)** | West Neighboring Plot/Owner | `RoRResponse.raw_fields["boundary_west"]` | **High (100%)** | Physical parcel demarcation. |
| **दाखिल-खारिज वाद संख्या (Mutation Case No)** | Latest Mutation Order Reference | `RoRResponse.raw_fields["mutation_case_no"]` | **High (100%)** | Legal title transfer history reference. |
| **दाखिल-खारिज वर्ष (Mutation Year)** | Year of Mutation Order | `RoRResponse.raw_fields["mutation_year"]` | **High (100%)** | Temporal validity of current record. |
| **अंतिम लगान भुगतान रसीद (Last Receipt No)** | Online Tax Payment Receipt No. | `RoRResponse.raw_fields["last_receipt_no"]` | **High (100%)** | Proof of tax compliance. |
| **डिजिटल हस्ताक्षर स्थिति (Digital Sign Status)** | RoR Authentication Status | `RoRVerification.status` | **High (100%)** | Maps to `VERIFIED` when digitally signed by Revenue Officer. |

---

## 3. Fields with No Direct Bhumitra Equivalent (Preserved in `raw_fields`)

The following Bihar-specific attributes do not have a dedicated 1:1 top-level field in `RoRResponse` and will be safely preserved in the `raw_fields` dictionary to avoid breaking the shared client contract:

1. **`halka`**: Revenue sub-circle jurisdiction identifier.
2. **`thana_no`**: Revenue Thana number associated with the cadastral survey of the Mauza.
3. **`vol_page_no`**: Physical Register volume (`भाग`) and page (`पृष्ठ`) references.
4. **`chauhaddi`**: North/South/East/West physical plot boundaries.
5. **`mutation_case_no`**: Mutation case registration number (`वाद संख्या`).
6. **`cess_breakup`**: Detailed breakdown of road, education, and development cesses.

---

## 4. Sanitized Raw Response Structure & Fixture

Below is a sanitized, representative JSON fixture demonstrating how a raw Bihar Jamabandi Register-II record is ingested and parsed by the scraper pipeline:

```json
{
  "state": "BIHAR",
  "portal_source": "biharbhumi.bihar.gov.in",
  "document_type": "JAMABANDI_REGISTER_2",
  "location": {
    "district": "PATNA",
    "anchal": "PATNA SADAR",
    "halka": "HALKA-04",
    "mauza": "SAMPLE_MAUZA",
    "thana_number": "108"
  },
  "register_identifiers": {
    "jamabandi_number": "412",
    "bhag_vartaman": "12",
    "prishth_vartaman": "85",
    "khata_number": "78",
    "khesra_number": "245"
  },
  "raiyat_details": [
    {
      "raiyat_name": "SAMPLE_TENANT_A",
      "guardian_name": "SAMPLE_GUARDIAN_X",
      "relation": "FATHER",
      "caste": "GENERAL",
      "address": "SAMPLE_MAUZA"
    }
  ],
  "land_schedule": [
    {
      "khesra_no": "245",
      "area_bigha": "0",
      "area_katha": "12",
      "area_dhur": "0",
      "area_decimal": "37.5",
      "area_acre": "0.375",
      "land_type": "BHIT-2",
      "lagan_breakdown": {
        "mool_lagan": "15.50",
        "road_cess": "3.10",
        "education_cess": "1.55",
        "development_cess": "1.55",
        "total_annual_demand": "21.70"
      },
      "boundaries": {
        "north": "ROAD_OR_SAMPLE_PLOT_244",
        "south": "SAMPLE_PLOT_246",
        "east": "SAMPLE_PLOT_250",
        "west": "SAMPLE_PLOT_240"
      }
    }
  ],
  "mutation_history": {
    "case_number": "04/2021-2022",
    "order_date": "2021-11-14",
    "status": "APPROVED"
  },
  "verification_metadata": {
    "digitally_signed": true,
    "signing_authority": "CIRCLE_OFFICER_PATNA_SADAR",
    "timestamp": "2026-04-10T11:20:00Z"
  }
}
```

---

## 5. Normalized Bhumitra Output Mapping

When transformed through `BiharJamabandiParser`, the record yields the following fully compliant `RoRResponse`:

```json
{
  "success": true,
  "plot": "245",
  "village": "SAMPLE_MAUZA",
  "district": "PATNA",
  "tahasil": "PATNA SADAR",
  "khata_number": "78",
  "area": "0.375 Acre",
  "land_type": "BHIT-2",
  "owners": [
    {
      "name": "SAMPLE_TENANT_A",
      "relation": "Father",
      "relation_name": "SAMPLE_GUARDIAN_X",
      "share": null,
      "khata_number": "78",
      "ownership_details": "Caste: GENERAL"
    }
  ],
  "plots": [
    {
      "plot_number": "245",
      "area": "0.375 Acre",
      "land_type": "BHIT-2",
      "rent_cess": "Rs. 21.70",
      "remarks": "Bigha: 0, Katha: 12, Dhur: 0"
    }
  ],
  "raw_fields": {
    "jamabandi_no": "412",
    "vol_page_no": "Vol 12, Page 85",
    "thana_no": "108",
    "halka": "HALKA-04",
    "mutation_case_no": "04/2021-2022",
    "boundary_north": "ROAD_OR_SAMPLE_PLOT_244",
    "boundary_south": "SAMPLE_PLOT_246",
    "boundary_east": "SAMPLE_PLOT_250",
    "boundary_west": "SAMPLE_PLOT_240",
    "source_state": "BIHAR"
  },
  "verification": {
    "status": "VERIFIED",
    "requested_district": "PATNA",
    "requested_tahasil": "PATNA SADAR",
    "requested_village": "SAMPLE_MAUZA",
    "requested_plot": "245",
    "returned_district": "PATNA",
    "returned_tahasil": "PATNA SADAR",
    "returned_village": "SAMPLE_MAUZA",
    "returned_plot": "245",
    "location_match": true,
    "plot_match": true,
    "details": "Bihar Jamabandi Register-II record verified matching requested plot and location."
  },
  "source": "biharbhumi.bihar.gov.in",
  "cached": false
}
```
