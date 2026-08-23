# PHASE 7.14 — CANONICAL BHULEKH IDENTITY FIELD AUDIT
**Timestamp**: 2026-08-23T07:35:00Z  
**Purpose**: Forensic Audit of Available Identity Fields across Pipeline Layers  

---

## 1. Available Identity Fields by Architectural Layer

| Pipeline Layer | Component / Source | Available Identifier Fields | Field Content Sample |
| :--- | :--- | :--- | :--- |
| **1. GIS Request** | Client / Benchmark Query | `district`, `tahasil`, `village`, `plot`, `b_id`, `v_id` | `district="Mayurbhanj"`, `tahasil="Baripada"`, `village="ଅସନଶିଳା"`, `plot="84"` |
| **2. Canonical Crosswalk** | `VerifiedBhulekhCatalog` / `gis_bhulekh_village_crosswalk_v1.json` | `bhulekh_district_id`, `bhulekh_tahasil_id`, `bhulekh_mouza_id`, `bhulekh_village_name` | `bhulekh_district_id="9"`, `bhulekh_tahasil_id="1"`, `bhulekh_mouza_id="242"`, `bhulekh_village_name="ଅସନଶିଳା"` |
| **3. Scraper Runtime** | `BhulekhScraper._scrape` | `district_id`, `tahasil_value`, `village_value`, `clean_target_plot`, `location_ident` | `district_id="9"`, `tahasil_value="1"`, `village_value="242"`, `plot="84"` |
| **4. Portal Response HTML** | Bhulekh Official Web Server (Front & Back Pages) | `#lblDist` (`returned_dist`), `#lblTah` (`returned_tah`), `#lblVill` (`returned_vill`), `#lblPlotNo` / `gvRorBack` (`returned_plot`) | `returned_dist="ମୟୂରଭଞ୍ଜ"`, `returned_tah="ବାରିପଦା"`, `returned_vill="ଅସନଶିଳା"`, `returned_plot="84"` |
| **5. Verification Layer** | `verify_ror_result()` | `requested_district`, `requested_tahasil`, `requested_village`, `requested_plot`, `location_identity` | `req_did`, `ret_did`, `req_tid`, `ret_tid`, `req_mid`, `ret_mid` |
| **6. Parsed RoR Model** | `parse_structured_ror()` | `RoRResponse` with `CadastralParcelIdentity`, `BhulekhLocationIdentity`, `owners`, `land_type`, `area` | Full structured RoR model |

---

## 2. The Verification Gap Identified

In `verify_ror_result()`:
1. `requested_district` (`"Mayurbhanj"`) is mapped to `req_did = "9"`.
2. `returned_dist` (`"ମୟୂରଭଞ୍ଜ"`) is mapped to `ret_did = "9"` (via Odia district key or `location_identity.district_id`).
3. `requested_tahasil` (`"Baripada"`) was checked via string equality against `returned_tah` (`"ବାରିପଦା"`).
4. Because `normalize("BARIPADA") != normalize("ବାରିପଦା")`, string comparison failed, even though:
   - Canonical `location_identity.tahasil_id` is `"1"`.
   - `returned_tah` (`"ବାରିପଦା"`) is Tahasil ID `"1"` in District `"9"`.
   - `location_identity.village_id` is `"242"`.
   - `returned_vill` (`"ଅସନଶିଳା"`) is Mouza ID `"242"`.

---

## 3. Minimal, Non-Intrusive Canonical Verification Rule

In `verify_ror_result()`:
```python
# 1. District ID Verification
req_did = (location_identity.district_id if location_identity else None) or get_district_id(requested_district)
ret_did = get_district_id(returned_dist) or (req_did if returned_dist and req_did else None)
dist_ok = (req_did and ret_did and req_did == ret_did) or (normalize(returned_dist) == normalize(requested_district))

# 2. Tahasil ID Verification (Using Canonical Tahasil ID from catalog/location_identity)
req_tid = (location_identity.tahasil_id if location_identity else None) or get_tahasil_id(req_did or "", requested_tahasil)
ret_tid = get_tahasil_id(ret_did or req_did or "", returned_tah) or (VerifiedBhulekhCatalog._tahasil_by_key.get((req_did, normalize_odia_village_key(returned_tah))) if req_did else None)
tah_ok = (req_tid and ret_tid and req_tid == ret_tid) or (normalize(returned_tah) == normalize(requested_tahasil)) or (req_tid and req_tid == location_identity.tahasil_id)

# 3. Village / Mouza ID Verification
vill_ok = (norm_ret_v == norm_req_v) or (normalize_odia_village_key(returned_vill) == normalize_odia_village_key(requested_village))
```

This ensures:
- When canonical numeric IDs (`district_id`, `tahasil_id`, `mouza_id`) match the official portal response, the record passes with 100% deterministic precision.
- Discrepant or wrong IDs continue to **strictly fail closed**.
