#!/usr/bin/env python3
"""
Test G_Dimbo Plot 12 and Plot 1 with strict dropdown isolation.
"""
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup

async def test_dimbo_exact():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        print("1. Loading http://bhulekh.ori.nic.in/...")
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        
        # Switch to English
        try:
            english_link = await page.query_selector("a#ctl00_btnenglish, a#ctl00_lnkEnglish, a:has-text('English')")
            if english_link:
                async with page.expect_navigation(timeout=10000):
                    await english_link.click()
                print("Switched to English")
        except Exception:
            pass

        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        
        # Select District 7 (Keonjhar)
        print("Selecting Keonjhar (7)...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="7")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        
        # Select Tahasil 4 (Sadar)
        print("Selecting Tahasil Sadar (4)...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="4")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        
        # Select Village G_Dimbo (317)
        v_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlVillage option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        dimbo_opt = next(o for o in v_opts if "317" in o["v"] or "ଡ଼ିମ୍ବୋ" in o["t"] or "DIMBO" in o["t"].upper())
        print(f"Selecting Village: {dimbo_opt}...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=dimbo_opt["v"])
        await asyncio.sleep(2)
        
        # Inspect visible controls BEFORE clicking Plot radio
        print("\n--- Inspecting Controls BEFORE clicking Plot radio ---")
        visible_selects_before = await page.eval_on_selector_all("select", "sels => sels.map(s => ({id: s.id, name: s.name, visible: s.offsetParent !== null, optionsCount: s.options.length}))")
        for s in visible_selects_before:
            print(f"  Select: {s}")
            
        # Click Plot radio button
        print("\nClicking Plot radio (#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1)...")
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        await asyncio.sleep(3)
        
        # Inspect visible controls AFTER clicking Plot radio
        print("\n--- Inspecting Controls AFTER clicking Plot radio ---")
        visible_selects_after = await page.eval_on_selector_all("select", "sels => sels.map(s => ({id: s.id, name: s.name, visible: s.offsetParent !== null, optionsCount: s.options.length}))")
        for s in visible_selects_after:
            print(f"  Select: {s}")
            
        # Inspect all options in any select with options > 1
        for s in visible_selects_after:
            if s["id"] not in ["ctl00_ContentPlaceHolder1_ddlDistrict", "ctl00_ContentPlaceHolder1_ddlTahsil", "ctl00_ContentPlaceHolder1_ddlVillage"]:
                opts = await page.eval_on_selector_all(f"#{s['id']} option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
                # Check for Plot 12 and Plot 1
                opt_12 = [o for o in opts if o["t"] == "12"]
                opt_1 = [o for o in opts if o["t"] == "1"]
                print(f"  Options with text=='12': {opt_12}")
                print(f"  Options with text=='1': {opt_1}")
                
                if opt_12:
                    val_12 = opt_12[0]["v"]
                    print(f"\nSelecting Plot 12: value={repr(val_12)}...")
                    await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=val_12)
                    await asyncio.sleep(2)
                    
                    # Submit View RoR
                    for btn_sel in ["#ctl00_ContentPlaceHolder1_btnRORFront", "#ctl00_ContentPlaceHolder1_btnViewROR", "#ctl00_ContentPlaceHolder1_btnShow"]:
                        btn = await page.query_selector(btn_sel)
                        if btn:
                            print(f"Clicking submit button {btn_sel}...")
                            await btn.click()
                            await asyncio.sleep(3)
                            break
                            
                    soup = BeautifulSoup(await page.content(), "lxml")
                    khata = soup.find(id=lambda x: x and "lblKhatiyanslNo" in x)
                    print(f"Plot 12 -> Returned Khata: {khata.get_text(strip=True) if khata else 'Not Found'}")
                    
                    raiyat_el = soup.find(id=lambda x: x and "lblRaiyat" in x)
                    print(f"Plot 12 -> Returned Owner: {raiyat_el.get_text(strip=True) if raiyat_el else 'Not Found'}")
                    
                    back_table = soup.find("table", id=lambda x: x and "gvRorBack" in str(x))
                    if back_table:
                        rows = back_table.find_all("tr")
                        print(f"Plot 12 -> gvRorBack rows: {len(rows)}")
                        for r in rows:
                            print(f"  Plot Row: {[td.get_text(strip=True) for td in r.find_all('td')]}")
                
        await browser.close()

if __name__ == "__main__":
    asyncio.run(test_dimbo_exact())
