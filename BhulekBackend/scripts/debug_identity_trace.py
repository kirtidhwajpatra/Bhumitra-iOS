#!/usr/bin/env python3
"""
DEBUG SCRIPT 2: End-to-end identity trace for known-bad GIS parcels.
Tests what happens when English GIS names hit the identity resolver.
"""
import asyncio
import json
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from scrapers.bhulekh_mappings import get_district_id, get_tahasil_id, normalize, DISTRICT_MAP, TAHASIL_MAP
from resolvers.bhulekh_identity_resolver import (
    BhulekhVillageResolver,
    VerifiedBhulekhCatalog,
    ResolutionStatus,
    clean_gis_village_name,
    normalize_phonetic,
    odia_to_phonetic,
    consonant_skeleton,
    SCOPED_VILLAGE_ALIASES,
)


def trace_parcel(parcel_name, district, tahasil, village, plot, d_id=None, t_id=None, v_id=None):
    """Trace a single parcel through the identity resolution pipeline."""
    print(f"\n{'='*70}")
    print(f"PARCEL TRACE: {parcel_name}")
    print(f"{'='*70}")
    
    # Step 1: GIS Input
    print(f"\n--- GIS INPUT ---")
    print(f"  District: {district}")
    print(f"  Tahasil:  {tahasil}")
    print(f"  Village:  {village}")
    print(f"  Plot:     {plot}")
    print(f"  d_id:     {d_id}")
    print(f"  t_id:     {t_id}")
    print(f"  v_id:     {v_id}")
    
    # Step 2: District Resolution
    resolved_d_id = d_id or get_district_id(district)
    print(f"\n--- DISTRICT RESOLUTION ---")
    print(f"  Input:   '{district}' (d_id={d_id})")
    print(f"  Resolved: {resolved_d_id}")
    
    if not resolved_d_id:
        print(f"  [FAIL] District not resolved!")
        return
    
    # Step 3: Tahasil Resolution
    resolved_t_id = t_id or get_tahasil_id(resolved_d_id, tahasil)
    print(f"\n--- TAHASIL RESOLUTION ---")
    print(f"  Input:   '{tahasil}' (t_id={t_id})")
    print(f"  Resolved: {resolved_t_id}")
    
    # Also try the resolver
    bd_id, bd_name, bt_id, bt_name = BhulekhVillageResolver.resolve_district_and_tahasil(
        district_name=district,
        tahasil_name=tahasil,
        district_id=d_id,
        tahasil_id=t_id,
    )
    print(f"  Resolver D: {bd_id} ({bd_name})")
    print(f"  Resolver T: {bt_id} ({bt_name})")
    
    if not bt_id:
        print(f"  [FAIL] Tahasil not resolved!")
        return
    
    # Step 4: Village Resolution (catalog lookup)
    print(f"\n--- VILLAGE RESOLUTION (CATALOG) ---")
    clean_v = clean_gis_village_name(village)
    norm_v = normalize(clean_v)
    phon_v = normalize_phonetic(clean_v)
    skel_v = consonant_skeleton(phon_v)
    
    print(f"  Raw Village:      '{village}'")
    print(f"  Cleaned:          '{clean_v}'")
    print(f"  Normalized:       '{norm_v}'")
    print(f"  Phonetic:         '{phon_v}'")
    print(f"  Skeleton:         '{skel_v}'")
    
    cat_rec, cat_status, cat_detail = VerifiedBhulekhCatalog.lookup(
        district_id=bd_id or resolved_d_id,
        tahasil_id=bt_id or resolved_t_id,
        village_name=village,
        village_id=v_id,
    )
    
    print(f"\n  Catalog Status:   {cat_status}")
    print(f"  Catalog Detail:   {cat_detail}")
    if cat_rec:
        print(f"  Catalog Mouza ID: {cat_rec.get('bhulekh_mouza_id')}")
        print(f"  Catalog Mouza:    {cat_rec.get('bhulekh_mouza_name')}")
        print(f"  Catalog Odia:     {cat_rec.get('bhulekh_mouza_odia_name')}")
        print(f"  GIS Village:      {cat_rec.get('gis_village_name')}")
        print(f"  Method:           {cat_rec.get('mapping_method')}")
    else:
        print(f"  [NO CATALOG MATCH]")
    
    # Step 5: Check scoped aliases
    alias_key = (str(bd_id or resolved_d_id), str(bt_id or resolved_t_id), norm_v)
    alias_target = SCOPED_VILLAGE_ALIASES.get(alias_key)
    print(f"\n--- SCOPED ALIAS CHECK ---")
    print(f"  Key:    {alias_key}")
    print(f"  Target: {alias_target}")
    
    return cat_rec, cat_status


# ── SIMULATE GIS INPUT ──
# These simulate what the iOS app sends when a user taps a parcel on the map

TEST_PARCELS = [
    {
        "name": "Keonjhar Dimbo Plot 12 (KNOWN-GOOD from Phase 0)",
        "district": "KEONJHAR",
        "tahasil": "KEONJHAR SADAR",
        "village": "G_Dimbo",
        "plot": "12",
        "d_id": None,
        "t_id": None,
        "v_id": None,
    },
    {
        "name": "Keonjhar Keri Plot 1182 (KNOWN-GOOD from Phase 0)",
        "district": "KEONJHAR",
        "tahasil": "KEONJHAR SADAR",
        "village": "G_Keri 271",
        "plot": "1182",
        "d_id": None,
        "t_id": None,
        "v_id": None,
    },
    {
        "name": "Cuttack Anantapur Plot 55",
        "district": "CUTTACK",
        "tahasil": "ATHAGARH",
        "village": "Anantapur-64",
        "plot": "55",
        "d_id": None,
        "t_id": None,
        "v_id": None,
    },
    {
        "name": "Khurda Baindolo",
        "district": "KHORDHA",
        "tahasil": "BALIANTA",
        "village": "Baindolo",
        "plot": "101",
        "d_id": None,
        "t_id": None,
        "v_id": None,
    },
    # Simulate a RANDOM village with GIS attributes similar to what ORSAC provides
    {
        "name": "GIS with 7-digit v_id",
        "district": "KEONJHAR",
        "tahasil": "KEONJHAR SADAR",
        "village": "Dimbo",
        "plot": "12",
        "d_id": "7",
        "t_id": "4",
        "v_id": "0704317",  # 07=district, 04=tahasil, 317=mouza
    },
    {
        "name": "GIS with census-style v_id",
        "district": "KEONJHAR",
        "tahasil": "KEONJHAR SADAR",
        "village": "SOME_UNKNOWN_VILLAGE",
        "plot": "50",
        "d_id": "7",
        "t_id": "4",
        "v_id": "317",
    },
    {
        "name": "Odia village name direct",
        "district": "KEONJHAR",
        "tahasil": "KEONJHAR SADAR",
        "village": "ଡ଼ିମ୍ବୋ",
        "plot": "12",
        "d_id": None,
        "t_id": None,
        "v_id": None,
    },
]


def main():
    print("=" * 70)
    print("END-TO-END IDENTITY RESOLUTION TRACE")
    print("=" * 70)
    
    VerifiedBhulekhCatalog.load()
    print(f"\nCatalog loaded: {VerifiedBhulekhCatalog._loaded}")
    print(f"Catalog by_id entries: {len(VerifiedBhulekhCatalog._by_id)}")
    print(f"Catalog by_name entries: {len(VerifiedBhulekhCatalog._by_name)}")
    print(f"Catalog by_odia entries: {len(VerifiedBhulekhCatalog._by_odia)}")
    print(f"Catalog by_phonetic entries: {len(VerifiedBhulekhCatalog._by_phonetic)}")
    print(f"Catalog by_skeleton entries: {len(VerifiedBhulekhCatalog._by_skeleton)}")
    
    results = []
    for p in TEST_PARCELS:
        rec, status = trace_parcel(
            p["name"], p["district"], p["tahasil"], p["village"], p["plot"],
            p.get("d_id"), p.get("t_id"), p.get("v_id")
        ) or (None, None)
        results.append({
            "name": p["name"],
            "status": str(status),
            "resolved": rec is not None,
            "mouza_id": rec.get("bhulekh_mouza_id") if rec else None,
        })
    
    print(f"\n\n{'='*70}")
    print("SUMMARY")
    print(f"{'='*70}")
    for r in results:
        tag = "PASS" if r["resolved"] else "FAIL"
        print(f"  [{tag}] {r['name']:>50} -> Status={r['status']} MouzaID={r['mouza_id']}")


if __name__ == '__main__':
    main()
