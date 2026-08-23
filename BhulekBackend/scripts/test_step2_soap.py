#!/usr/bin/env python3
"""
Phase 7.17 Step 2 & Step 3: Controlled SOAP Resolution Test.
Tests:
  - Step 2: Historical known-good parcels (Plot 12, Plot 1, Plot 333, Plot 647).
  - Step 3: Persistent 502/504 failing parcels.
"""
import asyncio
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from resolvers.bhulekh_soap_resolver import resolve_khata_for_plot_soap
from resolvers.bhulekh_identity_resolver import VerifiedBhulekhCatalog

KNOWN_GOOD = [
    {"district": "Keonjhar", "tahasil": "Keonjhar Sadar", "village": "ଡ଼ିମ୍ବୋ", "did": "7", "tid": "4", "vid": "317", "plot": "12", "expected_khata": "112"},
    {"district": "Keonjhar", "tahasil": "Keonjhar Sadar", "village": "ଡ଼ିମ୍ବୋ", "did": "7", "tid": "4", "vid": "317", "plot": "1", "expected_khata": "230"},
    {"district": "Khordha", "tahasil": "Bhubaneswar", "village": "ରଘୁନାଥପୁର ଜଳି", "did": "20", "tid": "2", "vid": "359", "plot": "333", "expected_khata": "538"},
    {"district": "Bargarh", "tahasil": "Atabira", "village": "ଚକୁଳି", "did": "15", "tid": "1", "vid": "61", "plot": "647", "expected_khata": "277"},
]

PERSISTENT_FAILURES = [
    {"district": "Cuttack", "tahasil": "Cuttack Sadar", "village": "ଅନନ୍ତପୁର", "plot": "159"},
    {"district": "Cuttack", "tahasil": "Cuttack Sadar", "village": "ଅମୃତମଣୋହିପାଟଣା", "plot": "533"},
    {"district": "Dhenkanal", "tahasil": "Dhenkanal", "village": "ଅଳସୁଆ", "plot": "48/204"},
    {"district": "Balasore", "tahasil": "Balasore", "village": "ଅକ୍ତିଆରପୁର ୟୁନିଟ ନଂ:12", "plot": "11"},
    {"district": "Ganjam", "tahasil": "Berhampur", "village": "ଅତରଙ୍ଗ", "plot": "1138"},
    {"district": "Ganjam", "tahasil": "Berhampur", "village": "ଅମଲା ପଡ଼ା", "plot": "18"},
]

async def main():
    VerifiedBhulekhCatalog.load()

    print("\n" + "="*80)
    print("PHASE 7.17 STEP 2: CONTROLLED SOAP TEST ON KNOWN-GOOD PARCELS")
    print("="*80)
    
    step2_passed = True
    for item in KNOWN_GOOD:
        t0 = time.time()
        khata = await resolve_khata_for_plot_soap(item["did"], item["tid"], item["vid"], item["plot"])
        lat = (time.time() - t0) * 1000
        match = (khata == item["expected_khata"])
        if not match:
            step2_passed = False
        print(f"[{'PASS' if match else 'FAIL'}] {item['district']} / {item['village']} / Plot {item['plot']} -> Got Khata '{khata}' (Expected '{item['expected_khata']}', {lat:.1f}ms)")

    print(f"\nStep 2 Verdict: {'PASSED (Proceeding to Step 3 & 4)' if step2_passed else 'FAILED (STOP)'}")

    print("\n" + "="*80)
    print("PHASE 7.17 STEP 3: TESTING PERSISTENT 502/504 PARCELS WITH SOAP")
    print("="*80)

    for item in PERSISTENT_FAILURES:
        rec, status, detail = VerifiedBhulekhCatalog.lookup("", "", item["village"])
        if not rec:
            print(f"[UNRESOLVED VILLAGE] {item['district']} / {item['village']} (Catalog status: {status})")
            continue
        did = rec["bhulekh_district_id"]
        tid = rec["bhulekh_tahasil_id"]
        mid = rec["bhulekh_mouza_id"]
        t0 = time.time()
        khata = await resolve_khata_for_plot_soap(did, tid, mid, item["plot"])
        lat = (time.time() - t0) * 1000
        print(f"[{'RESOLVED' if khata else 'NOT_FOUND'}] {item['district']} (did:{did}, tid:{tid}, mid:{mid}) / {item['village']} / Plot {item['plot']} -> SOAP Khata: '{khata}' ({lat:.1f}ms)")

if __name__ == "__main__":
    asyncio.run(main())
