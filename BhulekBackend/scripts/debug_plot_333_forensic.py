#!/usr/bin/env python3
"""
FORENSIC SCRIPT 1:
1. Inspect official Bhulekh dropdowns for District=Khordha, Tahasil=Bhubaneswar.
2. Find Raghunathpur Jali and list its exact dropdown code and text.
3. Query Plot 333 on official Bhulekh portal and extract the raw HTML, spans, tables, Khata, owners, land classification, and area.
4. Test nearby plots: 332, 333, 334, 335, 338.
"""
import anyio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import json
import httpx

async def inspect_official_bhulekh():
    print("=" * 80)
    print("STEP 1: INSPECTING OFFICIAL BHULEKH DROPDOWNS FOR KHORDHA / BHUBANESWAR")
    print("=" * 80)
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context()
        page = await ctx.new_page()
        
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        
        # 1. District options
        dist_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlDistrict option", 
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        
        khordha_opt = next((o for o in dist_opts if "khordha" in o["text"].lower() or "khurda" in o["text"].lower() or "ଖୋର୍ଦ୍ଧା" in o["text"] or "ଖୋର୍ଦ୍ଧା" in o["text"] or o["value"] in ("20", "234")), None)
        print("Khordha option:", khordha_opt)
        
        if not khordha_opt:
            print("All district options:", dist_opts)
            await browser.close()
            return
            
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=khordha_opt["value"])
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil').options.length > 1", timeout=15000)
        
        # 2. Tahasil options
        tah_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlTahsil option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        
        bbsr_opt = next((o for o in tah_opts if "bhubaneswar" in o["text"].lower() or "ଭୁବନେଶ୍ୱର" in o["text"] or "ଭୁବନେଶ୍ଵର" in o["text"]), None)
        print("Bhubaneswar Tahasil option:", bbsr_opt)
        print(f"All Tahasils in Khordha ({len(tah_opts)}):", [o["text"] for o in tah_opts])
        
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=bbsr_opt["value"])
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage').options.length > 1", timeout=15000)
        
        # 3. Village options
        vill_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlVillage option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        
        print(f"\nTotal villages in Bhubaneswar Tahasil: {len(vill_opts)}")
        
        # Find Raghunathpur or Jali villages
        raghu_villages = [o for o in vill_opts if "raghunath" in o["text"].lower() or "ରଘୁନାଥ" in o["text"] or "jali" in o["text"].lower() or "ଜାଲି" in o["text"]]
        print("Matching Raghunathpur/Jali villages in dropdown:")
        for rv in raghu_villages:
            print(f"  value: '{rv['value']}', text: '{rv['text']}'")
            
        # Select the target village
        target_v_opt = raghu_villages[0] if raghu_villages else vill_opts[1]
        print(f"\nSelecting village: {target_v_opt}")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=target_v_opt["value"])
        
        # 4. Check RI Circle dropdown
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlRI').options.length > 1", timeout=15000)
        ri_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlRI option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        print("RI Circle options:", ri_opts)
        
        # 5. Click Plot radio
        print("\nClicking Plot radio button...")
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData') && document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData').options.length > 1", timeout=20000)
        
        # 6. Get all plot options
        plot_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        print(f"Total plots in village: {len(plot_opts)}")
        
        # Check target plot 333 and surrounding plots
        plots_to_check = ["332", "333", "334", "335", "338"]
        found_plots = {}
        for p_no in plots_to_check:
            matches = [o for o in plot_opts if o["text"] == p_no]
            found_plots[p_no] = matches
            print(f"Plot {p_no}: {matches}")
            
        # 7. Query Plot 333 on official portal
        print("\n" + "=" * 80)
        print("STEP 2: QUERYING PLOT 333 ON OFFICIAL PORTAL")
        print("=" * 80)
        
        if found_plots.get("333"):
            await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", label="333")
            await page.wait_for_load_state("domcontentloaded", timeout=5000)
            
            print("Clicking #ctl00_ContentPlaceHolder1_btnRORFront ...")
            async with page.expect_navigation(timeout=20000):
                await page.click("#ctl00_ContentPlaceHolder1_btnRORFront")
                
            html_front = await page.content()
            soup_front = BeautifulSoup(html_front, "html.parser")
            
            print("\n=== PLOT 333 FRONT PAGE SPANS ===")
            for s in soup_front.find_all("span"):
                sid = s.get("id", "")
                txt = s.get_text(strip=True)
                if sid and txt:
                    print(f"  {sid}: {txt}")
                    
            print("\n=== PLOT 333 FRONT PAGE TABLES ===")
            for t in soup_front.find_all("table"):
                tid = t.get("id", "")
                print(f"Table id={tid}")
                for tr in t.find_all("tr"):
                    cells = [c.get_text(strip=True) for c in tr.find_all(["th", "td"])]
                    if any(cells):
                        print("  Row:", cells)
                        
            # Save raw HTML artifact
            with open("/Users/uday/Documents/MyBhoomi/BhulekBackend/scratch_plot_333_front.html", "w", encoding="utf-8") as f:
                f.write(html_front)
            print("\nSaved raw HTML to BhulekBackend/scratch_plot_333_front.html")
            
        await browser.close()

if __name__ == "__main__":
    anyio.run(inspect_official_bhulekh)
