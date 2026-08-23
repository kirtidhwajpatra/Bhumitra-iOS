#!/usr/bin/env python3
"""
Inspect network traffic on RoRView.aspx when switching to Plot search mode.
"""
import asyncio
from playwright.async_api import async_playwright

async def trace_ror_network():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        requests = []
        page.on("request", lambda r: requests.append((r.method, r.url, r.post_data)))
        
        print("Loading http://bhulekh.ori.nic.in/...")
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        
        # Switch to English mode
        try:
            english_link = await page.query_selector("a#ctl00_btnenglish, a#ctl00_lnkEnglish, a:has-text('English')")
            if english_link:
                async with page.expect_navigation(timeout=10000):
                    await english_link.click()
                print("Switched to English mode")
        except Exception as e:
            print(f"English switch skipped: {e}")

        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        
        # Keonjhar (07 or 7)
        print("Selecting Keonjhar...")
        dist_options = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlDistrict option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        target_dist = next(o["v"] for o in dist_options if o["v"] in ["07", "7"] or "KEONJHAR" in o["t"].upper())
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=target_dist)
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }")
        
        print("Selecting Tahasil (04)...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="04")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }")
        
        # Get village value for G_Dimbo
        opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlVillage option", "opts => opts.map(o => ({v: o.value, t: o.text}))")
        dimbo = next(o for o in opts if "DIMBO" in o["t"].upper() or "317" in o["v"])
        print(f"Selecting Village: {dimbo}...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=dimbo["v"])
        await asyncio.sleep(2)
        
        # Record requests before clicking Plot radio
        req_count_before = len(requests)
        print("Clicking Plot radio button (#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1)...")
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        await asyncio.sleep(4)
        
        print("\n--- Network Requests Triggered by Plot Radio Button ---")
        for method, url, post_data in requests[req_count_before:]:
            print(f"{method} {url}")
            if post_data:
                print(f"  Post Data (first 300 chars): {post_data[:300]}...")
                
        # Now let's inspect the options inside the plot dropdown on page
        for sel in ["#ctl00_ContentPlaceHolder1_ddlPlot", "#ctl00_ContentPlaceHolder1_ddlBindData", "#ctl00_ContentPlaceHolder1_ddlVillagePlot"]:
            el = await page.query_selector(sel)
            if el:
                options = await page.eval_on_selector_all(f"{sel} option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
                print(f"\nDropdown '{sel}' has {len(options)} options.")
                print(f"First 15 options in '{sel}':")
                for o in options[:15]:
                    print(f"  Value: {repr(o['v'])} -> Text/Label: {repr(o['t'])}")
                
                # Check option for Plot 12 and Plot 1
                opt_12_by_text = [o for o in options if o["t"] == "12"]
                opt_12_by_val = [o for o in options if o["v"] == "12"]
                opt_1_by_text = [o for o in options if o["t"] == "1"]
                opt_1_by_val = [o for o in options if o["v"] == "1"]
                print(f"\nPlot 12 by Text: {opt_12_by_text}")
                print(f"Plot 12 by Value: {opt_12_by_val}")
                print(f"Plot 1 by Text: {opt_1_by_text}")
                print(f"Plot 1 by Value: {opt_1_by_val}")
                
        await browser.close()

if __name__ == "__main__":
    asyncio.run(trace_ror_network())
