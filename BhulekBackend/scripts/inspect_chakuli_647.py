#!/usr/bin/env python3
"""
Inspect Chakuli dropdown plots and test Plot 647 on RoRView.aspx
"""
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup

async def inspect_chakuli():
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
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="15")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="1")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        
        # Select Chakuli (61)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value="61")
        await asyncio.sleep(2)
        
        # Click Plot radio
        print("Clicking Plot radio...")
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        await page.wait_for_function(
            "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 0 && el.options[0].text.includes('Plot'); }",
            timeout=20000
        )
        print("Plot dropdown ready!")
        
        opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        print(f"Total plots in Chakuli: {len(opts)}")
        print(f"Sample plots in Chakuli: {opts[:15]}")
        
        opt_647 = [o for o in opts if o["t"] == "647"]
        print(f"Option for Plot 647: {opt_647}")
        
        if opt_647:
            val_647 = opt_647[0]["v"]
            print(f"Selecting Plot 647: value={repr(val_647)}...")
            await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=val_647)
            await asyncio.sleep(2)
            
            # Click submit button
            for btn_id in ["#ctl00_ContentPlaceHolder1_btnRORFront", "#ctl00_ContentPlaceHolder1_btnViewROR", "#ctl00_ContentPlaceHolder1_btnShow"]:
                btn = await page.query_selector(btn_id)
                if btn and await btn.is_visible():
                    print(f"Clicking {btn_id}...")
                    await btn.click()
                    await asyncio.sleep(4)
                    break
            
            soup = BeautifulSoup(await page.content(), "lxml")
            khata = soup.find(id=lambda x: x and "lblKhatiyanslNo" in x)
            print(f"Plot 647 -> Returned Khata: {khata.get_text(strip=True) if khata else 'Not Found'}")
            
            gvfront = soup.find(id=lambda x: x and "gvfront" in x)
            if gvfront:
                print("Owners in #gvfront:")
                for r in gvfront.find_all("tr"):
                    print(f"  Owner Row: {[td.get_text(strip=True) for td in r.find_all(['td', 'th'])]}")
            else:
                raiyat_el = soup.find(id=lambda x: x and "lblRaiyat" in x)
                print(f"Owner label: {raiyat_el.get_text(strip=True) if raiyat_el else 'None'}")
                
            back_table = soup.find("table", id=lambda x: x and "gvRorBack" in str(x))
            if back_table:
                print("Associated Plots (#gvRorBack):")
                for r in back_table.find_all("tr"):
                    tds = [td.get_text(strip=True) for td in r.find_all(["td", "th"])]
                    if any(tds):
                        print(f"  Plot Row: {tds}")
                        
        await browser.close()

if __name__ == "__main__":
    asyncio.run(inspect_chakuli())
