#!/usr/bin/env python3
"""
Test capturing both Front and Back pages for Chakuli Plot 647, G_Dimbo Plot 12, and Raghunathpur Jali Plot 333.
"""
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
from scrapers.structured_ror_parser import parse_structured_ror
from scrapers.bhulekh_scraper import verify_ror_result

async def test_full_ror(district_id, tahasil_id, village_id, target_plot, dist_name, tah_name, vil_name):
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        
        # Switch to English
        try:
            english_link = await page.query_selector("a#ctl00_btnenglish, a#ctl00_lnkEnglish, a:has-text('English')")
            if english_link:
                async with page.expect_navigation(timeout=10000):
                    await english_link.click()
        except Exception:
            pass

        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=str(district_id))
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=str(tahasil_id))
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=str(village_id))
        await asyncio.sleep(2)
        
        # Click Plot radio
        print(f"\n--- Testing {vil_name} (Plot {target_plot}) ---")
        plot_radio = await page.query_selector("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        if plot_radio:
            await plot_radio.click()
            await page.wait_for_function(
                "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 0 && el.options[0].text.includes('Plot'); }",
                timeout=20000
            )
            
        opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        matched = next((o for o in opts if o["t"] == str(target_plot)), None)
        if not matched:
            print(f"ERROR: Plot {target_plot} not found in dropdown ({len(opts)} options)!")
            await browser.close()
            return
            
        print(f"Selecting Plot {target_plot}: option value={repr(matched['v'])}...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=matched["v"])
        await asyncio.sleep(1)
        
        # 1. Click Front Page
        front_btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORFront, #ctl00_ContentPlaceHolder1_btnViewROR")
        if front_btn:
            print("Clicking Front Page...")
            await front_btn.click()
            await asyncio.sleep(3)
        front_html = await page.content()
        
        # Inspect available buttons after front page
        buttons_after = await page.eval_on_selector_all("input[type='submit'], button, a", "els => els.map(e => ({id: e.id, text: e.textContent.trim(), vis: e.offsetParent !== null}))")
        print("Buttons after Front Page:", [b for b in buttons_after if b['vis'] and b['text']])
        
        # 2. Click Back Page / Plot Details
        for b in buttons_after:
            if b['vis'] and ("BACK" in b['id'].upper() or "BACK" in b['text'].upper() or "ପ୍ଲଟ" in b['text'] or "ପୃଷ୍ଠା" in b['text']):
                print(f"Clicking Back button: #{b['id']} ({b['text']})...")
                await page.click(f"#{b['id']}")
                await asyncio.sleep(3)
                break
        back_html = await page.content()
            
        combined_html = front_html + "\n" + back_html
        
        # Run structured parser
        ror = parse_structured_ror(combined_html, dist_name, tah_name, vil_name, str(target_plot))
        print("SUCCESS! Parsed RoR:")
        print(f"  Plot: {ror.plot}")
        print(f"  Khata: {ror.khata_number}")
        print(f"  Area: {ror.area}")
        print(f"  Land Type: {ror.land_type}")
        print(f"  Owners ({len(ror.owners)}): {[o.name for o in ror.owners]}")
        print(f"  Plots ({len(ror.plots)}): {[p.plot_number for p in ror.plots]}")
        print(f"  Verification: {ror.verification.status}")
        
        await browser.close()

async def main():
    # 1. Chakuli Plot 647
    await test_full_ror(15, 1, 61, "647", "Bargarh", "Atabira", "Chakuli_Mosaic")
    # 2. G_Dimbo Plot 12
    await test_full_ror(7, 4, 317, "12", "Keonjhar", "Keonjhar Sadar", "G_Dimbo")

if __name__ == "__main__":
    asyncio.run(main())
