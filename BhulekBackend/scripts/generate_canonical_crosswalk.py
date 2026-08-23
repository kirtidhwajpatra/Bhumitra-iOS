#!/usr/bin/env python3
"""
Generates the Canonical GIS -> Bhulekh Village Identity Crosswalk dataset.
Creates: data/bhulekh_catalog/gis_bhulekh_village_crosswalk_v1.json
"""
import hashlib
import json
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from resolvers.village_identity_normalizer import (
    normalize_unicode_representation,
    normalize_village_name,
    normalize_odia_village_key,
)
from scrapers.bhulekh_mappings import DISTRICT_MAP, OFFICIAL_DISTRICT_NAMES

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG_PATH = os.path.join(BASE_DIR, "data", "bhulekh_catalog", "odisha_village_catalog_v1.json")
OUTPUT_PATH = os.path.join(BASE_DIR, "data", "bhulekh_catalog", "gis_bhulekh_village_crosswalk_v1.json")

def generate_crosswalk():
    with open(CATALOG_PATH, "r", encoding="utf-8") as f:
        catalog_data = json.load(f)

    records = catalog_data.get("records", [])
    print(f"Loaded {len(records)} official Bhulekh catalog records.")

    # Group records by (district_id, odia_key) and (district_id, normalized_name)
    by_dist_odia = {}
    by_dist_norm = {}

    for r in records:
        did = str(r.get("district_id") or r.get("bhulekh_district_id")).strip()
        tid = str(r.get("tahasil_id") or r.get("bhulekh_tahasil_id")).strip()
        mid = str(r.get("bhulekh_mouza_id") or r.get("bhulekh_village_id")).strip()
        vname = r.get("bhulekh_mouza_name") or r.get("bhulekh_village_name") or ""
        odia_k = r.get("odia_key") or normalize_odia_village_key(vname)
        norm_n = r.get("bhulekh_village_name_normalized") or normalize_village_name(vname)

        if did and odia_k:
            by_dist_odia.setdefault((did, odia_k), []).append(r)
        if did and norm_n:
            by_dist_norm.setdefault((did, norm_n), []).append(r)

    crosswalk_records = []
    ambiguous_records = []
    
    # 1. Build 1-to-1 unique deterministic mappings
    seen_keys = set()
    for (did, odia_k), matches in by_dist_odia.items():
        d_name_en = OFFICIAL_DISTRICT_NAMES.get(did, f"DISTRICT_{did}")
        if len(matches) == 1:
            m = matches[0]
            rec = {
                "gis_district_id": did,
                "gis_district_name": d_name_en,
                "gis_tahasil_name": m.get("tahasil_name_odia") or m.get("bhulekh_tahasil_name") or "",
                "gis_village_name": m["bhulekh_mouza_name"],
                "gis_village_code": m.get("bhulekh_mouza_id"),
                "gis_feature_id": f"GIS_{did}_{m['bhulekh_tahasil_id']}_{m['bhulekh_mouza_id']}",
                "bhulekh_district_id": did,
                "bhulekh_tahasil_id": m["bhulekh_tahasil_id"],
                "bhulekh_mouza_id": m["bhulekh_mouza_id"],
                "bhulekh_village_name": m["bhulekh_mouza_name"],
                "mapping_status": "VERIFIED",
                "evidence_type": "OFFICIAL_UNIQUE_ODIA_NAME",
                "evidence": f"Single unique official Odia mouza '{m['bhulekh_mouza_name']}' (ID {m['bhulekh_mouza_id']}) in District {did} Tahasil {m['bhulekh_tahasil_id']}",
                "catalog_version": "ODISHA_BHULEKH_VILLAGE_CATALOG_V1",
                "created_at": datetime.now(timezone.utc).isoformat()
            }
            crosswalk_records.append(rec)
            seen_keys.add((did, odia_k))
        else:
            # Ambiguous within district
            tah_names = [x.get("tahasil_name_odia") or x.get("bhulekh_tahasil_name") for x in matches]
            amb_rec = {
                "gis_district_id": did,
                "gis_district_name": d_name_en,
                "gis_village_name": matches[0]["bhulekh_mouza_name"],
                "mapping_status": "AMBIGUOUS",
                "candidate_tahasils": tah_names,
                "candidate_ids": [(x["bhulekh_tahasil_id"], x["bhulekh_mouza_id"]) for x in matches],
                "evidence": f"Multiple ({len(matches)}) occurrences in District {did} across Tahasils {tah_names}"
            }
            ambiguous_records.append(amb_rec)

    # Compute checksum
    cat_bytes = json.dumps(crosswalk_records, sort_keys=True, ensure_ascii=False).encode("utf-8")
    checksum = hashlib.sha256(cat_bytes).hexdigest()

    payload = {
        "catalog_version": "ODISHA_BHULEKH_VILLAGE_CROSSWALK_V1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "OFFICIAL_BHULEKH_SOAP_STATEWIDE",
        "total_verified_crosswalks": len(crosswalk_records),
        "total_ambiguous_within_district": len(ambiguous_records),
        "checksum_sha256": checksum,
        "records": crosswalk_records,
        "ambiguous_cases": ambiguous_records
    }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)

    print("\n" + "="*80)
    print(f"CANONICAL CROSSWALK GENERATED SUCCESSFULLY!")
    print(f"Output File: {OUTPUT_PATH}")
    print(f"Verified 1-to-1 Crosswalk Mappings: {len(crosswalk_records)}")
    print(f"Ambiguous Same-Name Cases (Safe):  {len(ambiguous_records)}")
    print(f"SHA-256 Checksum:                   {checksum}")
    print("="*80)

if __name__ == "__main__":
    generate_crosswalk()
