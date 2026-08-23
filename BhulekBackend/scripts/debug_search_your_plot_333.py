#!/usr/bin/env python3
"""
FORENSIC SCRIPT 4:
Run SearchYourPlot.aspx for:
District: Khordha (20)
Tahasil: Bhubaneswar (2)
Village: Raghunathpur Jali (359)
Plot: 333

Extract:
- Unique Plot ID
- Khatiyan (Khata) number
- Plot Area
- Land Classification
- Owners / Tenant details
- Complete response HTML
"""
import anyio
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import json

async def search_your_plot():
    print("=" * 80)
    print("RUNNING SEARCHYOURPLOT.ASPX FOR RAGHUNATHPUR JALI / PLOT 333")
    print("=" * 80)
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context()
        page = await ctx.new_page()
        
        await page.goto("http://bhulekh.ori.nic.in/SearchYourPlot.aspx", wait_until="domcontentloaded", timeout=30000)
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_drpdistrict", timeout=15000)
        
        # 1. Select District (20)
        print("Selecting District (Khordha)...")
        await page.select_option("#ctl00_ContentPlaceHolder1_drpdistrict", value="20")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_drpTahasil').options.length > 1", timeout=15000)
        
        # 2. Select Tahasil (2 - Bhubaneswar)
        print("Selecting Tahasil (Bhubaneswar)...")
        await page.select_option("#ctl00_ContentPlaceHolder1_drpTahasil", value="2")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_drpVillage').options.length > 1", timeout=15000)
        
        # 3. Select Village (359 - Raghunathpur Jali)
        print("Selecting Village (359 - Raghunathpur Jali)...")
        await page.select_option("#ctl00_ContentPlaceHolder1_drpVillage", value="359")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_drpKhatiyan').options.length > 1 || document.getElementById('ctl00_ContentPlaceHolder1_drpPlot').options.length > 1", timeout=20000)
        
        # Check what dropdowns are populated
        k_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_drpKhatiyan option", "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        p_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_drpPlot option", "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        print(f"Khatiyan options count: {len(k_opts)}, Plot options count: {len(p_opts)}")
        
        # Select Plot 333
        print("Selecting Plot 333...")
        target_p = next((o for o in p_opts if o["text"] == "333"), None)
        print("Target plot 333 in drpPlot:", target_p)
        
        if target_p:
            await page.select_option("#ctl00_ContentPlaceHolder1_drpPlot", label="333")
            await asyncio.sleep(1.5)
            
        # Check if Khatiyan automatically gets selected or if we click Search
        selected_khata = await page.eval_on_selector("#ctl00_ContentPlaceHolder1_drpKhatiyan", "el => el.value")
        selected_plot = await page.eval_on_selector("#ctl00_ContentPlaceHolder1_drpPlot", "el => el.value")
        print(f"Selected Khata value: '{selected_khata}', Selected Plot value: '{selected_plot}'")
        
        # Click Know Your Plot Unique Id button or Search button
        search_btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btn_SearchID")
        if search_btn:
            print("Clicking #ctl00_ContentPlaceHolder1_btn_SearchID ...")
            await search_btn.click()
            await page.wait_for_load_state("domcontentloaded", timeout=15000)
            await asyncio.sleep(3)
            
        html = await page.content()
        soup = BeautifulSoup(html, "html.parser")
        
        print("\n=== SEARCHYOURPLOT RESULTS ===")
        # Look for labels, spans, and result tables
        for s in soup.find_all(["span", "label", "div"]):
            sid = s.get("id", "")
            txt = s.get_text(strip=True)
            if any(k in sid.lower() for k in ["unique", "plot", "khata", "owner", "tenant", "area", "khatiyan", "lbl", "result"]) and txt:
                print(f"  {sid}: {txt}")
                
        for t in soup.find_all("table"):
            tid = t.get("id", "")
            rows = []
            for tr in t.find_all("tr"):
                cells = [c.get_text(strip=True) for c in tr.find_all(["th", "td"])]
                if any(cells):
                    rows.append(cells)
            if rows and len(rows) > 1:
                print(f"\nTable id='{tid}':")
                for r in rows:
                    print("  Row:", r)
                    
        # Save HTML
        with open("/Users/uday/Documents/MyBhoomi/BhulekBackend/scratch_search_your_plot_333.html", "w", encoding="utf-8") as f:
            f.write(html)
        print("\nSaved HTML to BhulekBackend/scratch_search_your_plot_333.html")
        
        await browser.close()

if __name__ == "__main__":
    anyio.run(search_your_plot)
