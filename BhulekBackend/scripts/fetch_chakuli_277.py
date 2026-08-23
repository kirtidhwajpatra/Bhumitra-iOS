#!/usr/bin/env python3
"""
Fetch Khata 277 in Chakuli (15, 1, 61) via RoRView.aspx
"""
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup

async def fetch_chakuli_277():
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
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value="61")
        await asyncio.sleep(2)
        
        # In Khatiyan mode (default), select Khata 277
        await page.wait_for_function(
            "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 10; }",
            timeout=20000
        )
        
        k_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        opt_277 = next((o for o in k_opts if o["t"] == "277"), None)
        print(f"Option for Khata 277: {opt_277}")
        
        if opt_277:
            await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=opt_277["v"])
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
            print(f"\n============================================================")
            print(f"RETURNED KHATA: {khata.get_text(strip=True) if khata else 'Not Found'}")
            print(f"============================================================")
            
            gvfront = soup.find(id=lambda x: x and "gvfront" in x)
            if gvfront:
                print("OWNERS (#gvfront):")
                for r in gvfront.find_all("tr"):
                    print(f"  Owner Row: {[td.get_text(strip=True) for td in r.find_all(['td', 'th'])]}")
            else:
                praja_el = soup.find(id=lambda x: x and "lblRaiyat" in x)
                print(f"Raiyat label: {praja_el.get_text(strip=True) if praja_el else 'None'}")
                
            back_table = soup.find("table", id=lambda x: x and "gvRorBack" in str(x))
            if back_table:
                print("\nASSOCIATED PLOTS (#gvRorBack):")
                for r in back_table.find_all("tr"):
                    tds = [td.get_text(strip=True) for td in r.find_all(["td", "th"])]
                    if any(tds):
                        print(f"  Plot Row: {tds}")
            print(f"============================================================")
            
        await browser.close()

if __name__ == "__main__":
    asyncio.run(fetch_chakuli_277())
