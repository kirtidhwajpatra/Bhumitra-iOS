#!/usr/bin/env python3
"""
Diagnostic test for Raghunathpur Jali Plot 333 on RoRView.aspx
"""
import asyncio
import time
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup

async def test_raghunathpur_jali():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        print("1. Loading http://bhulekh.ori.nic.in/...")
        t0 = time.time()
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
        print("Selecting Khordha (20)...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="20")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        
        # Select Tahasil 2 (Bhubaneswar)
        print("Selecting Tahasil Bhubaneswar (2)...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="2")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        
        # Select Village Raghunathpur Jali (359)
        v_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlVillage option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        jali_opt = next(o for o in v_opts if "359" in o["v"] or "ରଘୁନାଥପୁର" in o["t"] or "RAGHUNATHPUR" in o["t"].upper())
        print(f"Selecting Village: {jali_opt}...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=jali_opt["v"])
        await asyncio.sleep(2)
        
        # Click Plot radio button
        print("Clicking Plot radio (#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1)...")
        t_click = time.time()
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        
        # Wait for plot dropdown
        print("Waiting for plot dropdown to populate...")
        await page.wait_for_function(
            "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 10; }",
            timeout=45000
        )
        t_loaded = time.time() - t_click
        print(f"Plot dropdown populated in {t_loaded:.2f}s!")
        
        opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        print(f"Total plots loaded in Raghunathpur Jali: {len(opts)}")
        
        opt_333 = [o for o in opts if o["t"] == "333"]
        print(f"Option for Plot 333: {opt_333}")
        
        if opt_333:
            val_333 = opt_333[0]["v"]
            print(f"Selecting Plot 333: value={repr(val_333)}...")
            async with page.expect_navigation(timeout=15000):
                await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=val_333)
            print("Postback navigation completed!")
            
            await asyncio.sleep(2)
            
            content = await page.content()
            with open("/Users/uday/Documents/MyBhoomi/BhulekBackend/jali_333_page.html", "w") as f:
                f.write(content)
            print("Saved page content to jali_333_page.html (length:", len(content), ")")
            
            soup = BeautifulSoup(content, "lxml")
            khata = soup.find(id=lambda x: x and "lblKhatiyanslNo" in x)
            print(f"Plot 333 -> Returned Khata: {khata.get_text(strip=True) if khata else 'Not Found'}")
            
            # Raiyat names
            gvfront = soup.find(id=lambda x: x and "gvfront" in x)
            if gvfront:
                print("Found #gvfront Raiyat Table:")
                for r in gvfront.find_all("tr"):
                    print(f"  Raiyat Row: {[td.get_text(strip=True) for td in r.find_all(['td', 'th'])]}")
            else:
                praja_el = soup.find(id=lambda x: x and "lblRaiyat" in x)
                print(f"Raiyat label: {praja_el.get_text(strip=True) if praja_el else 'Not Found'}")
                
            back_table = soup.find("table", id=lambda x: x and "gvRorBack" in str(x))
            if back_table:
                print("Found #gvRorBack Plot Table:")
                for r in back_table.find_all("tr"):
                    tds = [td.get_text(strip=True) for td in r.find_all(["td", "th"])]
                    if any(tds):
                        print(f"  Plot Row: {tds}")
            
            raiyat_rows = soup.find_all("tr")
            print(f"Page total table rows: {len(raiyat_rows)}")
            for r in raiyat_rows[:15]:
                txts = [td.get_text(strip=True) for td in r.find_all(["td", "th"])]
                if any(txts):
                    print(f"  Row: {txts}")
                    
            back_table = soup.find("table", id=lambda x: x and "gvRorBack" in str(x))
            if back_table:
                rows = back_table.find_all("tr")
                print(f"Plot 333 -> gvRorBack rows: {len(rows)}")
                for r in rows[:10]:
                    print(f"  Plot Row: {[td.get_text(strip=True) for td in r.find_all('td')]}")
                    
        total_time = time.time() - t0
        print(f"\nTotal execution time: {total_time:.2f}s")
        await browser.close()

if __name__ == "__main__":
    asyncio.run(test_raghunathpur_jali())
