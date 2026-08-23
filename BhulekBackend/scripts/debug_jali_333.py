#!/usr/bin/env python3
"""
FORENSIC SCRIPT 2 (Fixed):
Query official Bhulekh for:
District: 20 (Khordha)
Tahasil: 2 (Bhubaneswar)
Village: 359 (ରଘୁନାଥପୁର ଜଳି / Raghunathpur Jali)
Plot: 333
and inspect the Front & Back RoR page.
Then run BhulekhScraper().fetch_ror() to see how Bhumitra processes it!
"""
import anyio
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import json
from scrapers.bhulekh_scraper import BhulekhScraper

async def inspect_jali_333():
    print("=" * 80)
    print("OFFICIAL BHULEKH QUERY: KHORDHA (20) -> BHUBANESWAR (2) -> RAGHUNATHPUR JALI (359) -> PLOT 333")
    print("=" * 80)
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context()
        page = await ctx.new_page()
        
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        
        # 1. District 20
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="20")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil').options.length > 1", timeout=15000)
        
        # 2. Tahasil 2
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="2")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage').options.length > 1", timeout=15000)
        
        # 3. Village 359 (Raghunathpur Jali)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value="359")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlRI').options.length > 1", timeout=15000)
        
        v_text = await page.eval_on_selector("#ctl00_ContentPlaceHolder1_ddlVillage option:checked", "o => o.textContent.trim()")
        ri_text = await page.eval_on_selector("#ctl00_ContentPlaceHolder1_ddlRI option:checked", "o => o.textContent.trim()")
        print(f"Selected Village: value=359, text='{v_text}'")
        print(f"Selected RI Circle: '{ri_text}'")
        
        # 4. Click Plot radio button
        print("Clicking Plot radio button...")
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData') && document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData').options.length > 1", timeout=20000)
        
        # 5. Check Plot 333 in dropdown
        plot_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        
        target_333 = [o for o in plot_opts if o["text"] == "333"]
        print(f"Total plots in Raghunathpur Jali: {len(plot_opts)}")
        print(f"Option for Plot 333: {target_333}")
        
        # Select Plot 333 by LABEL
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", label="333")
        await asyncio.sleep(2)
        
        # Click btnRORFront
        print("\n--- Clicking btnRORFront ---")
        async with page.expect_navigation(timeout=25000):
            await page.click("#ctl00_ContentPlaceHolder1_btnRORFront")
            
        html_front = await page.content()
        soup_front = BeautifulSoup(html_front, "html.parser")
        
        print("\n=== FRONT PAGE DETAILS FOR RAGHUNATHPUR JALI / PLOT 333 ===")
        for s in soup_front.find_all("span"):
            sid = s.get("id", "")
            txt = s.get_text(strip=True)
            if sid and txt:
                print(f"  Span {sid}: {txt}")
                
        for t in soup_front.find_all("table"):
            tid = t.get("id", "")
            rows = []
            for tr in t.find_all("tr"):
                cells = [c.get_text(strip=True) for c in tr.find_all(["th", "td"])]
                if any(cells):
                    rows.append(cells)
            if rows:
                print(f"\nTable id='{tid}':")
                for r in rows:
                    print("  Row:", r)
                    
        # Check Back page
        print("\n--- Checking Back Page ---")
        back_btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORBack")
        if back_btn:
            async with page.expect_navigation(timeout=25000):
                await back_btn.click()
            html_back = await page.content()
            soup_back = BeautifulSoup(html_back, "html.parser")
            print("\n=== BACK PAGE DETAILS FOR RAGHUNATHPUR JALI / PLOT 333 ===")
            for t in soup_back.find_all("table"):
                tid = t.get("id", "")
                rows = []
                for tr in t.find_all("tr"):
                    cells = [c.get_text(strip=True) for c in tr.find_all(["th", "td"])]
                    if any(cells):
                        rows.append(cells)
                if rows:
                    print(f"\nTable id='{tid}':")
                    for r in rows:
                        print("  Row:", r)
                        
        await browser.close()
        
    print("\n" + "=" * 80)
    print("STEP 3: RUNNING BHUMITRA BACKEND SCRAPER FOR RAGHUNATHPUR JALI / PLOT 333")
    print("=" * 80)
    scraper = BhulekhScraper()
    try:
        res = await scraper.fetch_ror(
            district="Khordha",
            tahasil="Bhubaneswar",
            village="Raghunathpur_Jali",
            plot="333",
            b_id="2002",
            v_id="2002359",
        )
        print("Bhumitra Scraper Response:")
        print("  Success:", res.success)
        print("  District:", res.district)
        print("  Tahasil:", res.tahasil)
        print("  Village:", res.village)
        print("  Plot:", res.plot)
        print("  Khata:", res.khata_number)
        print("  Land Type:", res.land_type)
        print("  Area:", res.area)
        print("  Owners count:", len(res.owners))
        for o in res.owners:
            print(f"    Owner: {o.name}, Share: {o.share}")
        print("  Raw fields:", res.raw_fields)
        print("  Verification:", res.verification.status if res.verification else None)
    except Exception as e:
        print("Bhumitra Scraper Error:", type(e), e)

if __name__ == "__main__":
    anyio.run(inspect_jali_333)
