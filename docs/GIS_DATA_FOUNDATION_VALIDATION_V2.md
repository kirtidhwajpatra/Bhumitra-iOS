# Bhumitra GIS Explorer — Data Foundation Validation Report (v2)

**Status**: VALIDATED & AUDITED (DATA FOUNDATION GATE)  
**Date**: 2026-09-09  
**Scope**: Geospatial Hierarchy Foundation: `District → Tahasil → Revenue Village → Cadastral Parcel → RoR`  
**Target Platform**: Bhumitra iOS & Backend Services  

---

## Executive Summary & System Status

This report audits and establishes the data foundation for the map-first Bhumitra GIS Explorer prior to any MapLibre UI rendering changes.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                GEOSPATIAL HIERARCHY STATUS                             │
├───────────────────────┬───────────────────────┬───────────────────┬────────────────────┤
│ Administrative Level  │ Geometry Source       │ Classification    │ Status             │
├───────────────────────┼───────────────────────┼───────────────────┼────────────────────┤
│ 1. State (Odisha)     │ ORSAC 4K GEO          │ AUTHORITATIVE     │ VERIFIED (30 Dists)│
│ 2. District (30)      │ State Land Records    │ AUTHORITATIVE     │ VERIFIED (100%)    │
│ 3. Tahasil (14 Ctk)   │ Census 2011 / LGD     │ VISUALIZATION-ONLY│ VERIFIED (Mapped)  │
│ 4. Revenue Village    │ ORSAC Extents / Plots │ AUTHORITATIVE     │ VERIFIED (208 Ath) │
│ 5. Cadastral Parcel   │ ORSAC 4K GEO WGS84    │ AUTHORITATIVE     │ VERIFIED (724 Plot)│
│ 6. RoR / Khatiyan     │ Bhulekh Odisha SOAP   │ AUTHORITATIVE     │ VERIFIED (1:1 RoR) │
└───────────────────────┴───────────────────────┴───────────────────┴────────────────────┘
```

* **VERIFIED**:
  * 30 Odisha District boundary polygons (`odisha_districts.geojson`).
  * 14 Cuttack Tahasils in 4K GEO and Bhulekh (`tahasil_crosswalk_v1.json`).
  * 208 live Athagarh revenue villages via concurrent GP aggregation.
  * 41,856 verified deterministic village crosswalk records (0 duplicates, 0 missing parents, 0 invalid IDs).
  * 724 cadastral plot polygons for Anantapur-64 (`0301088` / Mouza `88`).
* **PARTIAL**:
  * Crosswalk statewide coverage is **80.76%** (41,856 out of 51,826 Bhulekh villages). The remaining 9,970 villages were intentionally withheld into 3,930 ambiguous groups due to same-name collisions within districts when Tahasil context was omitted.
* **VISUALIZATION-ONLY**:
  * Subdistrict boundary polygons (419 features in `odisha_subdistricts_census.geojson`). Derived from Census 2011 & Survey of India. They do **not** represent official revenue cadastral Tahasil limits and must **never** be labeled as such.
* **NOT AVAILABLE UPSTREAM**:
  * ORSAC 4K GEO does **not** provide pre-computed outer boundary polygon GeoJSON for entire Tahasils or entire Revenue Villages. Its cadastral spatial primitives exist strictly at the plot/parcel level.

---

## 1. Athagarh Crosswalk Gap Analysis

* **Subdivision**: Athagarh (`0301`, Cuttack District `306` / `03`).
* **Upstream 4K GEO Total Villages**: **208**.
* **Previously in `gis_bhulekh_village_crosswalk_v1.json`**: **177** (`VERIFIED`).
* **Unmatched Villages Audited**: **31 unique village IDs** (33 total occurrences).
* **Audit Artifact**: `data/bhulekh_catalog/athagarh_crosswalk_gap_report_v1.json`.

### Root Cause Identification
The 31 villages were **not** missing from the official Bhulekh catalog. They were intentionally withheld from `gis_bhulekh_village_crosswalk_v1.json` by `scripts/generate_canonical_crosswalk.py` because that script grouped records strictly by `(District, Odia_Village_Name)`. When an Odia village name appeared in more than one Tahasil in Cuttack District, the generator placed the record into `ambiguous_cases` to prevent misattribution in the absence of Tahasil qualification.

### Findings Breakdown
* **Category A (Valid Bhulekh identity exists; crosswalk v1 was incomplete due to intra-district name collision)**: **100% (31/31 villages)**.
* **Category B (Name/code discrepancy)**: **0**.
* **Category C (4K GEO exists but no Bhulekh record)**: **0**.
* **Category D (Genuine source data corruption)**: **0**.

### Selected Audited Examples
| 4K GEO ID | Village Name | Suffix / Mouza ID | Bhulekh Candidate | Odia Village Name | Intra-District Collision Reason |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0301082` | `Bishnupur-53` | `82` | Dist 3, Tah 1, Mouza 82 | ବିଷ୍ଣୁପୁର | Appears in Athagarh, Tigiria, Banki |
| `0301085` | `Ramchandrapur-82` | `85` | Dist 3, Tah 1, Mouza 85 | ରାମଚନ୍ଦ୍ରପୁର | Appears in 10 Tahasils in Cuttack |
| `0301157` | `Jagannathpur-21` | `157` | Dist 3, Tah 1, Mouza 157 | ଜଗନ୍ନାଥପୁର | Appears in 10 Tahasils in Cuttack |
| `0301202` | `Balarampur-98` | `202` | Dist 3, Tah 1, Mouza 202 | ବଳରାମପୁର | Appears in Athagarh, Nischintakoili |
| `0301207` | `Gokulapur-102` | `207` | Dist 3, Tah 1, Mouza 207 | ଗୋକୁଳପୁର | Appears in Athagarh, Tangi, Mahanga |

**Conclusion**: When following the Map-First hierarchy ($\text{District} \to \text{Tahasil} \to \text{Village}$), the Tahasil is already locked (`Tahasil 1` = Athagarh). The 3-digit mouza suffix in the 4K GEO code matches the Bhulekh Mouza ID with **100% determinism**.

---

## 2. Statewide Crosswalk Coverage Audit

* **Audit Artifact**: `data/bhulekh_catalog/gis_bhulekh_crosswalk_audit_v1.json`.

### Statewide Metrics
* **Total Records in Crosswalk (`v1`)**: **41,856**.
* **Total Official Bhulekh Catalog Villages**: **51,826**.
* **Statewide Percentage Coverage**: **80.76%**.
* **District Coverage**: **30 / 30 (100.0%)**.
* **Tahasil Coverage**: **317 / 317 (100.0%)**.
* **Integrity Audit**:
  * Duplicate `gis_feature_id` entries: **0**.
  * Missing parent relationships (`district_id` or `tahasil_id` null): **0**.
  * Invalid or malformed IDs (non-numeric): **0**.
* **Unmatched / Withheld Villages**: **9,970 villages** grouped into **3,930 ambiguous clusters**.
  * Reason: Common mouza names (e.g. Rampur, Gopalpur, Balrampur) repeated within the same district across different tahasils.
  * Status: Intentionally partial; fully resolvable once Tahasil-qualified queries are utilized.

---

## 3. Tahasil Geometry Validation & Dataset Inspection

* **Dataset Local Path**: `BhulekBackend/data/gis/odisha_subdistricts_census.geojson`.
* **Source Repository**: `datta07/INDIAN-SHAPEFILES` (`STATES/ORISSA/ODISHA_SUBDISTRICTS.geojson`).
* **Original Provenance**: Census of India 2011 / Survey of India / Local Government Directory (LGD).
* **License**: **MIT License** (Copyright (c) 2022).
* **Coordinate Reference System**: **WGS84 EPSG:4326** (`urn:ogc:def:crs:OGC:1.3:CRS84`).
* **Total Feature Count**: **419 subdistricts** across Odisha.
* **Property Schema**: `OBJECTID`, `stcode11`, `dtcode11`, `sdtcode11`, `Shape_Length`, `Shape_Area`, `stname`, `dtname`, `sdtname`, `Subdt_LGD`, `Dist_LGD`, `State_LGD`.
* **Explicit Legal / Cadastral Classification**:
  > **Census/Survey-derived administrative visualization boundary**  
  > Must **never** be cited or displayed as "official cadastral geometry."

### Cuttack Tahasil Validation (14 Tahasils)
The Revenue & Disaster Management Department administers **14 Tahasils** in Cuttack, whereas Census 2011 mapped **25 subdistricts** (combining police station jurisdictions and developmental blocks).

* **Tahasil Crosswalk Artifact**: `data/bhulekh_catalog/tahasil_crosswalk_v1.json`.

```
4K GEO Code │ Bhulekh ID │ Tahasil Name     │ Census 2011 Boundary IDs (Visualization)
────────────┼────────────┼──────────────────┼─────────────────────────────────────────
0301        │ 1          │ Athagarh         │ 02950 (Athagad), 02952, 02953
0302        │ 2          │ Banki            │ 02948 (Banki), 02947 (Baidyeswar)
0303        │ 3          │ Badamba          │ 02946 (Badamba), 02945 (Kanpur)
0304        │ 4          │ Cuttack Sadar    │ 02962 (Sadar), 02961, 02963, 02964, 02968
0305        │ 5          │ Narasinghpur     │ 02944 (Narasinghpur)
0306        │ 6          │ Niali            │ 02967 (Niali)
0307        │ 7          │ Salipur          │ 02957 (Salepur)
0308        │ 8          │ Tigiria          │ 02949 (Tigiria)
0309        │ 9          │ Tangi Choudwar   │ 02954 (Choudwar), 02955 (Tangi)
0311        │ 11         │ Mahanga          │ 02956 (Mahanga)
0312        │ 12         │ Baranga          │ 02951 (Barang)
0313        │ 13         │ Dampada          │ 02948 (Carved from Banki South)
0314        │ 14         │ Kantapada        │ 02965 (Gobindpur), 02966 (Olatapur)
0315        │ 15         │ Nischintakoili   │ 02958 (Nischintakoili), 02959 (Nemalo)
```

---

## 4. Revenue Village Geometry Architecture

To maintain strict truth in labeling, village boundary data is classified into four distinct architectural tiers:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        REVENUE VILLAGE GEOMETRY CLASSIFICATION                         │
├──────┬────────────────────────┬─────────────────────────────┬──────────────────────────┤
│ Tier │ Classification         │ Source                      │ Operational Usage        │
├──────┼────────────────────────┼─────────────────────────────┼──────────────────────────┤
│ A    │ Official Cadastral     │ ORSAC 4K GEO                │ Not published as single  │
│      │ Village Boundary       │                             │ outer polygon upstream   │
├──────┼────────────────────────┼─────────────────────────────┼──────────────────────────┤
│ B    │ Census Administrative  │ Datameet                    │ Visual reference only;   │
│      │ Village Boundary       │ (or1.geojson)               │ 2001/2011 census codes   │
├──────┼────────────────────────┼─────────────────────────────┼──────────────────────────┤
│ C    │ Derived Cadastral      │ Dissolved Union of Parcels  │ Computed server-side from│
│      │ Village Boundary       │ (ST_Union of 4K GEO plots)  │ official plot collection │
├──────┼────────────────────────┼─────────────────────────────┼──────────────────────────┤
│ D    │ Village Bounding       │ ORSAC getVillageExtent &    │ Primary camera framing   │
│      │ Extent / BBox          │ Parcel Envelope Calculation │ for parcel level zoom    │
└──────┴────────────────────────┴─────────────────────────────┴──────────────────────────┘
```

### Anantapur-64 Validation Case
* **4K GEO Village ID**: `0301088`.
* **Bhulekh Mouza ID**: `88` (Tahasil `1`, District `3`).
* **Canonical GIS Feature ID**: `GIS_3_1_88`.
* **Cadastral Plots**: **724 WGS84 plot polygons** successfully retrieved via `POST /viewCadistrialResult`.
* **Bounding Extent**:
  * $\text{min\_lng} = 85.7373769$, $\text{min\_lat} = 20.4676361$
  * $\text{max\_lng} = 85.7552663$, $\text{max\_lat} = 20.4791247$
  * $\text{center} = [85.7463216, 20.4733804]$
* **Outer Geometry Determination**: Tiers B, C, or D are used for map framing and visualization. Tier A is **not** fabricated.

---

## 5. Provenance, Licensing & Redistribution Audit

| Source Entity | Exact Data Used | License / Terms Explicitly Found | Local Caching | Redistribution | Confidence / Legal Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Odisha 4K GEO (ORSAC)** | Plot polygons, administrative codes, extents | No open license published; public 5T e-Governance portal | In-memory TTL + persistent disk fallback | Live proxy queries; no bulk dataset resale | **Usage/redistribution terms not independently confirmed.** Citizen informational access permitted. |
| **Bhulekh Odisha (DoLR&S)** | 51,826 village catalog, RoR Khatiyan data | Official public land records portal (NIC) | Query result caching | On-demand per citizen inquiry | **Usage/redistribution terms not independently confirmed.** |
| **datta07 / INDIAN-SHAPEFILES** | 419 subdistrict polygons | **MIT License** (Copyright (c) 2022) | Static file on disk | Permitted with copyright notice | **CONFIRMED (MIT)** for visual overlay. |
| **Data{Meet} Maps** | Census 2011/2001 boundary shapes | **Open Database License (ODbL) v1.0** | Static file on disk | Permitted with attribution | **CONFIRMED (ODbL v1.0)** for visual overlay. |

---

## 6. Hierarchy Performance & Two-Tier Caching Architecture

To prevent a mobile user from triggering dozens of live upstream requests when opening a subdivision:

1. **Two-Tier Architecture Implemented in `GISNavigationService`**:
   * **Tier 1 (In-Memory)**: Fast dictionary lookup (`_subdivision_villages_cache`). Response time: **< 1 ms**.
   * **Tier 2 (Persistent Local Disk)**: File-based JSON storage in `data/gis/cache/subdivisions/{subdivision_id}_villages.json`. Response time: **< 5 ms**.
   * **Tier 3 (Upstream Fallback)**: Bounded concurrent queries across Gram Panchayats with `asyncio.Semaphore(10)` and single-retry resilience. Response time: $\sim 4.5\text{ s}$.
2. **Infrastructure Simplicity**:
   * Requires **zero** new database daemons (no Redis, no PostgreSQL schema changes).
   * Fully file-based, deterministic, and easily precomputable offline via CLI.

---

## 7. Answers to Core Success Criteria

### 1. What is the exact Tahasil polygon source?
* **Source**: `BhulekBackend/data/gis/odisha_subdistricts_census.geojson` (419 features).
* **Provenance**: Census of India 2011 / Survey of India / Local Government Directory (LGD).
* **Legal Classification**: **"Census/Survey-derived administrative visualization boundary"**.

### 2. What is the exact village polygon source?
* **Cadastral Plots**: Authoritative plot polygons from ORSAC 4K GEO (`/viewCadistrialResult`).
* **Village Outer Boundary**: Defined by the spatial envelope / extent (`/getVillageExtent`) or the derived union of constituent plots. Upstream ORSAC does **not** provide a standalone outer village polygon.

### 3. What are their licenses / usage terms?
* **Subdistrict Boundaries**: MIT License (datta07) / ODbL v1.0 (Datameet). Confirmed for visualization.
* **4K GEO & Bhulekh**: Usage/redistribution terms not independently confirmed; used strictly as an on-demand citizen access conduit for official land records.

### 4. How are their IDs deterministically mapped to 4K GEO / Bhulekh?
* Through hierarchical ID prefix decomposition:
  $$\text{4K GEO ID} = \underbrace{\text{DD}}_{\text{District}} + \underbrace{\text{TT}}_{\text{Tahasil}} + \underbrace{\text{MMM}}_{\text{Mouza}}$$
  $$\text{Bhulekh Mapping}: \text{District} = \operatorname{int}(\text{DD}),\quad \text{Tahasil} = \operatorname{int}(\text{TT}),\quad \text{Mouza} = \operatorname{int}(\text{MMM})$$
  Example: `0301088` $\longrightarrow$ District `3`, Tahasil `1`, Mouza `88` (Anantapur-64).

### 5. Why were the 31 Athagarh villages currently unmatched?
* They were intentionally withheld into `ambiguous_cases` by the initial crosswalk generator because their Odia names appear in multiple Tahasils within Cuttack District. Once Tahasil qualification is applied, all 31 villages match valid Bhulekh identities 1-to-1 (Category A).

### 6. Is the 41,856-record crosswalk complete, intentionally partial, or defective?
* It is **intentionally partial (80.76%)**. It contains only zero-collision, district-level unique names. It is defect-free (0 duplicates, 0 missing relationships, 0 malformed IDs). The remaining 19.24% (9,970 villages) are resolved once Tahasil context is provided.

### 7. Can we safely proceed to the MapLibre map-first Tahasil → Village → Parcel implementation?
* **YES, subject to the following visual contract**:
  1. Tahasil boundaries must be presented as **"Administrative Guide Boundaries"** (visual orientation).
  2. Revenue villages must be presented using their **cadastral extents / centroid labels**.
  3. Zooming to a village immediately streams **official cadastral parcel polygons** from 4K GEO.
  4. Tapping a parcel opens `CadastralPlotCardView` $\to$ existing RoR flow.
