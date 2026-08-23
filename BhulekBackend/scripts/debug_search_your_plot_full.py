#!/usr/bin/env python3
"""
FORENSIC SCRIPT 5:
Complete automated flow on SearchYourPlot.aspx with page postbacks:
District -> Tahasil -> Village -> Plot 333 -> Know Your Plot Unique Id
"""
import anyio
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import json

async def run_search_your_plot_333():
    print("=" * 80)
    print("SEARCHYOURPLOT.ASPX AUTOMATION: RAGHUNATHPUR JALI / PLOT 333")
    print("=" * 80)
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context()
        page = await ctx.new_page()
        
        await page.goto("http://bhulekh.ori.nic.in/SearchYourPlot.aspx", wait_until="domcontentloaded", timeout=30000)
        
        # 1. District 20
        print("1. Selecting District (Khordha - 20)...")
        async with page.expect_navigation(timeout=20000):
            await page.select_option("#ctl00_ContentPlaceHolder1_drpdistrict", value="20")
            
        # 2. Tahasil 2 (Bhubaneswar)
        print("2. Selecting Tahasil (Bhubaneswar - 2)...")
        async with page.expect_navigation(timeout=20000):
            await page.select_option("#ctl00_ContentPlaceHolder1_drpTahasil", value="2")
            
        # 3. Village 359 (Raghunathpur Jali)
        print("3. Selecting Village (Raghunathpur Jali - 359)...")
        async with page.expect_navigation(timeout=20000):
            await page.select_option("#ctl00_ContentPlaceHolder1_drpVillage", value="359")
            
        # 4. Check plots dropdown
        plots = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_drpPlot option", "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        khatas = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_drpKhatiyan option", "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        print(f"Total plots in drpPlot: {len(plots)}, Total khatas in drpKhatiyan: {len(khatas)}")
        
        # 5. Select Plot 333
        target_333 = next((o for o in plots if o["text"] == "333"), None)
        print("Target 333 in drpPlot:", target_333)
        
        if target_333:
            print("Selecting Plot 333...")
            # Check if selecting plot causes postback
            try:
                async with page.expect_navigation(timeout=10000):
                    await page.select_option("#ctl00_ContentPlaceHolder1_drpPlot", label="333")
            except Exception:
                await page.select_option("#ctl00_ContentPlaceHolder1_drpPlot", label="333")
                
        await asyncio.sleep(1.5)
        
        # 6. Click Know Your Plot Unique Id
        print("Clicking #ctl00_ContentPlaceHolder1_btn_SearchID ...")
        btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btn_SearchID")
        if btn:
            try:
                async with page.expect_navigation(timeout=20000):
                    await btn.click()
            except Exception:
                await btn.click()
                await page.wait_for_load_state("domcontentloaded", timeout=10000)
                
        await asyncio.sleep(2)
        html = await page.content()
        soup = BeautifulSoup(html, "html.parser")
        
        print("\n" + "=" * 80)
        print("SEARCHYOURPLOT RESULTS FOR PLOT 333:")
        print("=" * 80)
        
        # Find all spans with data
        for s in soup.find_all("span"):
            sid = s.get("id", "")
            txt = s.get_text(strip=True)
            if sid and txt:
                print(f"  Span '{sid}': {txt}")
                
        for t in soup.find_all("table"):
            tid = t.get("id", "")
            rows = []
            for tr in t.find_all("tr"):
                cells = [c.get_text(strip=True) for c in tr.find_all(["th", "td"])]
                if any(cells):
                    rows.append(cells)
            if len(rows) > 1:
                print(f"\nTable id='{tid}':")
                for r in rows:
                    print("  Row:", r)
                    
        # Check txtplotUId
        uid_val = await page.eval_on_selector("#ctl00_ContentPlaceHolder1_txtplotUId", "el => el.value") if await page.query_selector("#ctl00_ContentPlaceHolder1_txtplotUId") else None
        print(f"\n>>> UNIQUE PLOT ID VALUE: '{uid_val}' <<<")
        
        await browser.close()

if __name__ == "__main__":
    anyio.run(run_search_your_plot_333)
