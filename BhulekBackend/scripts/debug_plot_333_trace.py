#!/usr/bin/env python3
"""
FORENSIC SCRIPT 6:
End-to-End trace of Plot 333 / Raghunathpur Jali through Bhumitra Scraper.
"""
import asyncio
import sys
import os
import json
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from scrapers.bhulekh_scraper import BhulekhScraper
from resolvers.bhulekh_identity_resolver import BhulekhVillageResolver

async def main():
    print("=" * 80)
    print("FORENSIC TRACE: RAGHUNATHPUR JALI / PLOT 333 THROUGH BHUMITRA BACKEND")
    print("=" * 80)
    
    scraper = BhulekhScraper()
    
    # Trace 1: Resolve Village
    print("\n--- STAGE 1: Village Identity Resolution ---")
    available_mock_options = [
        {"value": "358", "text": "ରଘୁନାଥ ପୁର"},
        {"value": "212", "text": "ରଘୁନାଥ ପୁର"},
        {"value": "359", "text": "ରଘୁନାଥପୁର ଜଳି"},
    ]
    
    res_status, matched_opt, method = BhulekhVillageResolver.resolve_mouza_option(
        district_id="20",
        tahasil_id="2",
        gis_village_name="Raghunathpur_Jali",
        gis_village_id="2002359",
        available_options=available_mock_options,
    )
    print(f"Resolution Status: {res_status}")
    print(f"Matched Option: {matched_opt}")
    print(f"Resolution Method: {method}")
    
    # Trace 2: Run Live fetch_ror
    print("\n--- STAGE 2: Live Scrape Execution ---")
    try:
        res = await scraper.fetch_ror(
            district="Khordha",
            tahasil="Bhubaneswar",
            village="Raghunathpur_Jali",
            plot="333",
            b_id="2002",
            v_id="2002359",
        )
        print("\n=== SCRAPE SUCCESSFUL ===")
        print("Success:", res.success)
        print("District:", res.district)
        print("Tahasil:", res.tahasil)
        print("Village:", res.village)
        print("Plot:", res.plot)
        print("Khata:", res.khata_number)
        print("Land Type:", res.land_type)
        print("Area:", res.area)
        print(f"Owners Count: {len(res.owners)}")
        for idx, o in enumerate(res.owners, 1):
            print(f"  [{idx}] Name: '{o.name}', Share: '{o.share}', Khata: '{o.khata_number}'")
        print("Raw fields:", res.raw_fields)
        print("Verification:", res.verification.status if res.verification else "None")
        print("Verification Details:", res.verification.details if res.verification else "None")
    except Exception as e:
        print("\n=== SCRAPE ERROR ===")
        print(f"{type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
