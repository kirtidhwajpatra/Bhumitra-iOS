#!/usr/bin/env python3
"""
FORENSIC SCRIPT 3:
1. Query official Bhulekh for Khordha (20) -> Bhubaneswar (2) -> Raghunathpur Jali (359) -> Plot 333
2. Query nearby plots: 332, 333, 334, 335, 338
3. Inspect ASMX web service (https://bhulekh.ori.nic.in/bhulekhservice.asmx)
4. Check Unique Plot ID
5. Run Bhumitra backend trace on Plot 333
"""
import anyio
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import json
import httpx

async def get_plot_data(page, plot_str):
    print(f"\n>>> QUERYING PLOT {plot_str} ON LIVE PORTAL <<<")
    # Select plot
    await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", label=plot_str)
    await asyncio.sleep(1)
    
    # Click View RoR
    btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORFront")
    await btn.click(force=True)
    await page.wait_for_load_state("domcontentloaded", timeout=20000)
    await asyncio.sleep(2)
    
    html = await page.content()
    soup = BeautifulSoup(html, "html.parser")
    
    # Extract details
    spans = {}
    for s in soup.find_all("span"):
        sid = s.get("id", "")
        txt = s.get_text(strip=True)
        if sid and txt:
            spans[sid] = txt
            
    # Extract tables
    tables_summary = []
    for t in soup.find_all("table"):
        tid = t.get("id", "")
        rows = []
        for tr in t.find_all("tr"):
            cells = [c.get_text(strip=True) for c in tr.find_all(["th", "td"])]
            if any(cells):
                rows.append(cells)
        if rows:
            tables_summary.append({"id": tid, "rows": rows})
            
    # Look for Khata, Owner, Classification, Area in page
    page_text = soup.get_text(separator=" | ")
    
    return {
        "plot": plot_str,
        "spans": spans,
        "tables": tables_summary,
        "page_text": page_text,
        "html": html,
    }


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context()
        page = await ctx.new_page()
        
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        
        # Select Khordha (20), BBSR (2), Raghunathpur Jali (359)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="20")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil').options.length > 1", timeout=15000)
        
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="2")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage').options.length > 1", timeout=15000)
        
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value="359")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlRI').options.length > 1", timeout=15000)
        
        # Click Plot radio
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData') && document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData').options.length > 1", timeout=20000)
        
        # Query Plot 333
        data_333 = await get_plot_data(page, "333")
        print("\n" + "=" * 80)
        print("PLOT 333 RAW RESULTS:")
        print("=" * 80)
        print("Spans:", json.dumps(data_333["spans"], indent=2, ensure_ascii=False))
        print("Tables count:", len(data_333["tables"]))
        for t in data_333["tables"]:
            print(f"Table id='{t['id']}':")
            for r in t["rows"][:5]:
                print("  ", r)
                
        # Also query neighboring plots: 332, 334, 335, 338
        neighbor_results = {}
        for p_no in ["332", "334", "335", "338"]:
            # Need to navigate back or re-select
            try:
                # Reload home page to re-select
                await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
                await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
                await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="20")
                await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil').options.length > 1", timeout=15000)
                await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="2")
                await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage').options.length > 1", timeout=15000)
                await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value="359")
                await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlRI').options.length > 1", timeout=15000)
                await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
                await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData') && document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData').options.length > 1", timeout=20000)
                
                n_data = await get_plot_data(page, p_no)
                neighbor_results[p_no] = n_data
                print(f"Plot {p_no} Spans: {n_data['spans']}")
            except Exception as e:
                print(f"Error on neighbor {p_no}: {e}")

        await browser.close()
        
        # Save complete 333 and neighbor results to a json file
        with open("/Users/uday/Documents/MyBhoomi/BhulekBackend/scratch_plot_333_neighbors.json", "w", encoding="utf-8") as f:
            f.write(json.dumps({
                "plot_333": {
                    "spans": data_333["spans"],
                    "tables": data_333["tables"],
                },
                "neighbors": {
                    p_no: {
                        "spans": neighbor_results[p_no]["spans"],
                        "tables": neighbor_results[p_no]["tables"],
                    } for p_no in neighbor_results
                }
            }, indent=2, ensure_ascii=False))

anyio.run(main)
