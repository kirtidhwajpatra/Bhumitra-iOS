#!/usr/bin/env python3
"""
Test fetching Khata 538 (containing Plot 333) in Raghunathpur Jali via Playwright.
"""
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup

async def fetch_jali_khata_538():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        print("Loading http://bhulekh.ori.nic.in/...")
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
        
        # Select District 20 (Khordha)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="20")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        
        # Select Tahasil 2 (Bhubaneswar)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="2")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        
        # Select Village 359 (Raghunathpur Jali)
        v_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlVillage option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        jali_opt = next(o for o in v_opts if "359" in o["v"] or "359" in o["t"])
        print(f"Selecting Village {jali_opt}...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=jali_opt["v"])
        await asyncio.sleep(2)
        
        # In Khatiyan mode (default), wait for Khatiyan dropdown to populate
        print("Waiting for Khatiyan dropdown...")
        await page.wait_for_function(
            "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 10; }",
            timeout=20000
        )
        
        k_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        print(f"Khatiyan dropdown loaded with {len(k_opts)} options.")
        opt_538 = next((o for o in k_opts if o["t"] == "538"), None)
        print(f"Option for Khata 538: {opt_538}")
        
        if opt_538:
            print(f"Selecting Khata 538: value={repr(opt_538['v'])}...")
            await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=opt_538["v"])
            await asyncio.sleep(2)
            
            # Click btnRORFront or btnViewROR
            for btn_id in ["#ctl00_ContentPlaceHolder1_btnRORFront", "#ctl00_ContentPlaceHolder1_btnViewROR", "#ctl00_ContentPlaceHolder1_btnShow"]:
                btn = await page.query_selector(btn_id)
                if btn and await btn.is_visible():
                    print(f"Clicking {btn_id}...")
                    await btn.click()
                    await asyncio.sleep(4)
                    break
            else:
                print("Checking all clickable buttons/links...")
                btns = await page.eval_on_selector_all("input[type='submit'], button, a", "els => els.map(e => ({id: e.id, text: e.textContent.trim(), vis: e.offsetParent !== null}))")
                print("Elements:", [b for b in btns if b['vis']])
            
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
                raiyat_el = soup.find(id=lambda x: x and "lblRaiyat" in x)
                print(f"Owner label: {raiyat_el.get_text(strip=True) if raiyat_el else 'None'}")
                
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
    asyncio.run(fetch_jali_khata_538())
