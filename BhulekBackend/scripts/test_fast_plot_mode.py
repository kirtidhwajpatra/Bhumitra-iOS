#!/usr/bin/env python3
import asyncio
import time
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
from scrapers.bhulekh_scraper import verify_ror_result
from scrapers.structured_ror_parser import parse_structured_ror

async def test_fast_plot_mode():
    t0 = time.time()
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        print("Navigating...")
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        
        # 1. District: 20
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="20")
        
        # 2. Tahasil: 2
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="2")
        
        # 3. Village: 359
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value="359")
        await asyncio.sleep(3)
        
        # 4. Switch to Plot search mode
        print("Switching to Plot Search mode...")
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1:not([disabled])", timeout=15000)
        plot_radio = await page.query_selector("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        await plot_radio.click()
        
        print("Waiting for Plot dropdown...")
        await page.wait_for_function(
            "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 0 && el.options[0].text.includes('Plot'); }",
            timeout=20000
        )
        
        # 5. Exact text match for Plot 333
        opts = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlBindData option",
            "options => options.map(o => ({ value: o.value, text: o.text.trim() }))"
        )
        print(f"Total plot options in dropdown: {len(opts)}")
        matches = [o for o in opts if o["text"] == "333"]
        print(f"Matches for '333': {matches}")
        assert len(matches) == 1, f"Expected 1 match, found {len(matches)}"
        
        matched_value = matches[0]["value"]
        print(f"Selecting option with value={repr(matched_value)}...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=matched_value)
        await asyncio.sleep(1)
        
        # 6. Click Front & Back
        print("Clicking Front...")
        front_btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORFront")
        await front_btn.click()
        await asyncio.sleep(3)
        front_html = await page.content()
        
        print("Clicking Back...")
        back_btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORBack")
        await back_btn.click()
        await asyncio.sleep(3)
        back_html = await page.content()
        
        full_html = front_html + "\n" + back_html
        ror = parse_structured_ror(full_html, "Khordha", "Bhubaneswar", "Raghunathpur_Jali", "333")
        print(f"SUCCESS in {time.time() - t0:.2f}s!")
        print(f"Plot: {ror.plot}, Khata: {ror.khata_number}, Land Type: {ror.land_type}")
        print(f"Owners: {[o.name for o in ror.owners]}")
        print(f"Verification Status: {ror.verification.status}")
        
        await browser.close()

if __name__ == "__main__":
    asyncio.run(test_fast_plot_mode())
