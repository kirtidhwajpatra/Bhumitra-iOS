#!/usr/bin/env python3
"""
DEBUG SCRIPT: Trace Bhulekh official portal identity resolution
Compares GIS attributes with actual Bhulekh dropdown values.
"""
import asyncio
import json
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from playwright.async_api import async_playwright
from bs4 import BeautifulSoup

# ── Official Bhulekh Portal Investigation ──

async def get_all_districts():
    """Get all districts from official Bhulekh portal in English mode."""
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        
        # Switch to English
        english_btn = await page.query_selector("a#ctl00_btnenglish")
        if english_btn:
            async with page.expect_navigation(timeout=15000):
                await english_btn.click()
            print("[OK] Switched to English mode")
        
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        
        dist_opts = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlDistrict option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        print(f"\n=== DISTRICTS ({len(dist_opts)}) ===")
        for o in dist_opts:
            if o['value']:
                print(f"  ID={o['value']:>3}  Name={o['text']}")
        
        await browser.close()
        return dist_opts


async def trace_keonjhar_dimbo():
    """
    Trace Keonjhar > Keonjhar Sadar > Dimbo (known test parcel).
    Record exact dropdown values at each stage.
    """
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        
        # Switch to English
        english_btn = await page.query_selector("a#ctl00_btnenglish")
        if english_btn:
            async with page.expect_navigation(timeout=15000):
                await english_btn.click()
        
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        
        # Step 1: Select KEONJHAR (ID=7)
        print("\n=== STEP 1: Select District KEONJHAR ===")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="7")
        await page.wait_for_function(
            """() => {
                const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil');
                return s && s.options.length > 1;
            }""",
            timeout=20000
        )
        
        tah_opts = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlTahsil option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        print(f"\nTahasils in Keonjhar ({len(tah_opts)}):")
        for o in tah_opts:
            if o['value']:
                print(f"  ID={o['value']:>3}  Name={o['text']}")
        
        # Step 2: Select Keonjhar Sadar (should be ID=4)
        sadar_value = None
        for o in tah_opts:
            if 'SADAR' in o['text'].upper() or 'Sadar' in o['text']:
                sadar_value = o['value']
                break
        
        if not sadar_value:
            print("[ERROR] Keonjhar Sadar not found in dropdown!")
            await browser.close()
            return
        
        print(f"\n=== STEP 2: Select Tahasil Keonjhar Sadar (ID={sadar_value}) ===")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=sadar_value)
        await page.wait_for_function(
            """() => {
                const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage');
                return s && s.options.length > 1;
            }""",
            timeout=20000
        )
        
        vill_opts = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlVillage option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        print(f"\nVillages in Keonjhar Sadar ({len(vill_opts)}):")
        
        # Find Dimbo
        dimbo_candidates = []
        for o in vill_opts:
            if not o['value']:
                continue
            text_lower = o['text'].lower()
            if 'dimbo' in text_lower or 'dimb' in text_lower:
                dimbo_candidates.append(o)
                print(f"  *** DIMBO MATCH: ID={o['value']:>5}  Name={o['text']}")
        
        # Print all villages
        for o in vill_opts:
            if o['value']:
                print(f"  ID={o['value']:>5}  Name={o['text']}")
        
        if not dimbo_candidates:
            print("\n[CRITICAL] No Dimbo-like village found in Keonjhar Sadar dropdown!")
            # Check if it appears in a different tahasil
            print("\n=== Searching ALL tahasils for Dimbo ===")
            for tah_o in tah_opts:
                if not tah_o['value']:
                    continue
                await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=tah_o['value'])
                try:
                    await page.wait_for_function(
                        """() => {
                            const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage');
                            return s && s.options.length > 1;
                        }""",
                        timeout=10000
                    )
                except Exception:
                    continue
                
                v_opts = await page.eval_on_selector_all(
                    "#ctl00_ContentPlaceHolder1_ddlVillage option",
                    "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
                )
                for vo in v_opts:
                    if vo['value'] and ('dimbo' in vo['text'].lower() or 'dimb' in vo['text'].lower()):
                        print(f"  FOUND in Tahasil {tah_o['text']} (ID={tah_o['value']}): Village ID={vo['value']} Name={vo['text']}")
        
        await browser.close()


async def compare_catalog_with_portal():
    """
    Take sample parcels from our catalog and verify their IDs match what the portal actually uses.
    """
    catalog_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'bhulekh_catalog', 'catalog_v3.json')
    with open(catalog_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    records = data.get('records', [])
    
    # Get sample of Keonjhar Sadar records from catalog
    keonjhar_sadar = [
        r for r in records 
        if r.get('bhulekh_district_id') == '7' and r.get('bhulekh_tahasil_id') == '4'
    ]
    print(f"\n=== CATALOG: Keonjhar Sadar villages ({len(keonjhar_sadar)}) ===")
    for r in keonjhar_sadar[:20]:
        print(f"  MouzaID={r.get('bhulekh_mouza_id'):>5}  Name={r.get('bhulekh_mouza_name')}  Odia={r.get('bhulekh_mouza_odia_name')}  GIS={r.get('gis_village_name')}  Method={r.get('mapping_method')}")
    
    # Now compare with portal
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        
        # Switch to English
        english_btn = await page.query_selector("a#ctl00_btnenglish")
        if english_btn:
            async with page.expect_navigation(timeout=15000):
                await english_btn.click()
        
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="7")
        await page.wait_for_function(
            """() => {
                const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil');
                return s && s.options.length > 1;
            }""",
            timeout=20000
        )
        
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="4")
        await page.wait_for_function(
            """() => {
                const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage');
                return s && s.options.length > 1;
            }""",
            timeout=20000
        )
        
        portal_opts = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlVillage option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        
        portal_by_id = {o['value']: o['text'] for o in portal_opts if o['value']}
        portal_by_name = {o['text']: o['value'] for o in portal_opts if o['value']}
        
        print(f"\n=== PORTAL: Keonjhar Sadar villages ({len(portal_by_id)}) ===")
        
        # Compare
        print(f"\n=== COMPARISON ===")
        match_count = 0
        mismatch_count = 0
        missing_count = 0
        
        for r in keonjhar_sadar:
            cat_id = r.get('bhulekh_mouza_id')
            cat_name = r.get('bhulekh_mouza_name', '')
            cat_odia = r.get('bhulekh_mouza_odia_name', '')
            
            portal_name = portal_by_id.get(str(cat_id))
            if portal_name:
                if portal_name == cat_name or portal_name == cat_odia:
                    match_count += 1
                    print(f"  [MATCH]    CatalogID={cat_id:>5} CatalogName={cat_name:>20} PortalName={portal_name}")
                else:
                    mismatch_count += 1
                    print(f"  [MISMATCH] CatalogID={cat_id:>5} CatalogName={cat_name:>20} PortalName={portal_name}")
            else:
                missing_count += 1
                print(f"  [MISSING]  CatalogID={cat_id:>5} CatalogName={cat_name:>20} Not in portal dropdown!")
        
        print(f"\n--- SUMMARY ---")
        print(f"Match:    {match_count}")
        print(f"Mismatch: {mismatch_count}")
        print(f"Missing:  {missing_count}")
        print(f"Total Catalog: {len(keonjhar_sadar)}")
        print(f"Total Portal:  {len(portal_by_id)}")
        
        # Print portal villages not in catalog
        catalog_ids = {str(r.get('bhulekh_mouza_id')) for r in keonjhar_sadar}
        uncatalogued = [v for k, v in portal_by_id.items() if k not in catalog_ids]
        if uncatalogued:
            print(f"\n--- PORTAL VILLAGES NOT IN CATALOG ({len(uncatalogued)}) ---")
            for v in uncatalogued[:20]:
                print(f"  {v}")
        
        await browser.close()


async def main():
    print("=" * 70)
    print("BHULEKH PORTAL IDENTITY INVESTIGATION")
    print("=" * 70)
    
    await get_all_districts()
    await trace_keonjhar_dimbo()
    await compare_catalog_with_portal()


if __name__ == '__main__':
    asyncio.run(main())
