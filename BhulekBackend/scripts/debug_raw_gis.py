#!/usr/bin/env python3
"""
DEBUG SCRIPT 3: Fetch REAL GIS data from odisha4kgeo.in and inspect raw properties.
Then compare with what the iOS app sees.
"""
import asyncio
import json
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import httpx

async def fetch_raw_gis_village(village_code, district, block):
    """Fetch raw GIS parcels from odisha4kgeo.in for a specific village."""
    url = "https://odisha4kgeo.in/index.php/mapview/viewCadistrialResult"
    payload = {
        "district": district,
        "block": block,
        "value": village_code,
        "field": "revenue_village_code",
    }
    headers = {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json, text/javascript, */*; q=0.01",
        "X-Requested-With": "XMLHttpRequest",
    }
    
    async with httpx.AsyncClient(timeout=30.0, verify=False) as client:
        res = await client.post(url, data=payload, headers=headers)
        print(f"HTTP {res.status_code}, Content-Length={len(res.text)}")
        return res.json()


async def fetch_village_list(block_code):
    """Fetch the list of revenue villages from 4K GEO for a block."""
    url = "https://odisha4kgeo.in/index.php/mapview/getVillage"
    payload = {"blocks": block_code}
    headers = {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json, text/javascript, */*; q=0.01",
        "X-Requested-With": "XMLHttpRequest",
    }
    
    async with httpx.AsyncClient(timeout=30.0, verify=False) as client:
        res = await client.post(url, data=payload, headers=headers)
        return res.json()


async def main():
    print("=" * 70)
    print("RAW GIS DATA INVESTIGATION")
    print("=" * 70)
    
    # Step 1: Keonjhar district ID in 4K GEO is 224
    # Keonjhar Sadar block ID - find it
    print("\n--- Fetching blocks for Keonjhar (4K GEO district=224) ---")
    url = "https://odisha4kgeo.in/index.php/mapview/getBlocks"
    headers = {
        "User-Agent": "Mozilla/5.0",
        "Accept": "application/json, text/javascript, */*; q=0.01",
        "X-Requested-With": "XMLHttpRequest",
    }
    
    async with httpx.AsyncClient(timeout=30.0, verify=False) as client:
        res = await client.post(url, data={"district": "224"}, headers=headers)
        blocks = res.json()
        print(f"Blocks ({len(blocks)}):")
        for b in blocks:
            print(f"  block_code={b.get('block_code')}  block_name={b.get('block_name')}")
    
    # Step 2: Find Keonjhar Sadar block code
    sadar_block = None
    for b in blocks:
        if 'sadar' in b.get('block_name', '').lower() or 'keonjhar' in b.get('block_name', '').lower():
            sadar_block = b
            break
    
    if not sadar_block:
        sadar_block = blocks[0]  # fallback to first
    
    print(f"\nSelected block: {sadar_block}")
    block_code = sadar_block.get('block_code')
    
    # Step 3: Get villages
    print(f"\n--- Fetching villages for block {block_code} ---")
    villages = await fetch_village_list(block_code)
    print(f"Villages ({len(villages)}):")
    for v in villages[:10]:
        print(f"  code={v.get('revenue_village_code')}  name={v.get('revenue_village_name')}")
    
    # Step 4: Find a Dimbo-like village
    dimbo_village = None
    for v in villages:
        vn = v.get('revenue_village_name', '')
        if 'dimbo' in vn.lower() or 'ଡ଼ିମ୍ବୋ' in vn:
            dimbo_village = v
            break
    
    if dimbo_village:
        print(f"\n*** Found Dimbo: code={dimbo_village['revenue_village_code']} name={dimbo_village['revenue_village_name']}")
    else:
        print("\n[WARNING] No Dimbo found - using first village as sample")
        dimbo_village = villages[0] if villages else None
    
    if not dimbo_village:
        print("[ERROR] No villages found!")
        return
    
    # Step 5: Fetch raw parcels for this village
    v_code = dimbo_village.get('revenue_village_code')
    print(f"\n--- Fetching raw GIS parcels for village code={v_code} ---")
    geo = await fetch_raw_gis_village(v_code, "Keonjhar", sadar_block.get('block_name', ''))
    
    features = geo.get('features', [])
    print(f"Total features: {len(features)}")
    
    if features:
        # Show ALL properties of the first feature
        first = features[0]
        raw_props = first.get('properties', {})
        print(f"\n=== FIRST FEATURE RAW PROPERTIES ===")
        print(json.dumps(raw_props, indent=2, ensure_ascii=False))
        
        # Show ALL property keys across all features
        all_keys = set()
        for f in features:
            all_keys.update(f.get('properties', {}).keys())
        print(f"\n=== ALL UNIQUE PROPERTY KEYS ({len(all_keys)}) ===")
        for k in sorted(all_keys):
            # Show sample values
            sample_vals = set()
            for f in features[:5]:
                v = f.get('properties', {}).get(k)
                if v is not None:
                    sample_vals.add(str(v)[:50])
            print(f"  {k}: {list(sample_vals)[:3]}")
        
        # Key question: Does the GIS data contain v_id, d_id, t_id, b_id?
        print(f"\n=== CRITICAL IDENTITY FIELD CHECK ===")
        for key in ['d_id', 'd_name', 'd_namc', 'District', 'district',
                     't_id', 't_name', 't_namc', 'b_id', 'b_name', 'b_namc', 'Tahasil', 'block',
                     'v_id', 'v_name', 'v_namc', 'Village', 'village',
                     'p_id', 'p_name', 'p_namc',
                     'revenue_plot', 'plot_number',
                     'revenue_village_code', 'revenue_village_name',
                     'district_code', 'block_code', 'gp_code',
                     'area_in_acre']:
            found = False
            for f in features[:3]:
                val = f.get('properties', {}).get(key)
                if val is not None:
                    print(f"  {key} = {val}")
                    found = True
                    break
            if not found:
                print(f"  {key} = NOT PRESENT")


if __name__ == '__main__':
    asyncio.run(main())
