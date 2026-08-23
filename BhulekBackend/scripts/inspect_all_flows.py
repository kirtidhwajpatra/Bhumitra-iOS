#!/usr/bin/env python3
"""
Diagnostic script: Inspect exact option values and labels on Bhulekh portal.
"""
import asyncio
from playwright.async_api import async_playwright

async def inspect_village_flow(dist_id, tah_id, vill_keyword, target_plot):
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        print(f"\n============================================================")
        print(f"TESTING: {vill_keyword} (Tahasil ID {tah_id}, District ID {dist_id}) - Target Plot: {target_plot}")
        print(f"============================================================")
        
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        try:
            english_link = await page.query_selector("a#ctl00_btnenglish, a#ctl00_lnkEnglish, a:has-text('English')")
            if english_link:
                async with page.expect_navigation(timeout=10000):
                    await english_link.click()
                print("Switched to English")
        except Exception:
            pass

        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        
        # 1. District by ID
        print(f"Selecting District ID {dist_id}...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=str(dist_id))
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        
        # 2. Tahasil by ID
        t_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlTahsil option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        print(f"Available Tahasils in District {dist_id} ({len(t_opts)}): {t_opts}")
        print(f"Selecting Tahasil ID {tah_id}...")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=str(tah_id))
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        
        # 3. Village
        v_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlVillage option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        print(f"Total Villages in Tahasil: {len(v_opts)}")
        matched_v = next((o for o in v_opts if vill_keyword.upper() in o["t"].upper()), None)
        if not matched_v:
            print(f"ERROR: Village '{vill_keyword}' not found among {len(v_opts)} villages!")
            await browser.close()
            return
        print(f"Selected Village: {matched_v}")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=matched_v["v"])
        await asyncio.sleep(2)
        
        # 4. Search by Plot Radio
        print("Clicking Plot Radio Button...")
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        
        # Wait for plot dropdown
        for sel in ["#ctl00_ContentPlaceHolder1_ddlPlot", "#ctl00_ContentPlaceHolder1_ddlBindData", "#ctl00_ContentPlaceHolder1_ddlVillagePlot"]:
            try:
                await page.wait_for_function(
                    f"() => {{ const el = document.querySelector('{sel}'); return el && el.options && el.options.length > 1; }}",
                    timeout=25000
                )
                p_opts = await page.eval_on_selector_all(f"{sel} option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
                print(f"Dropdown '{sel}' loaded with {len(p_opts)} options.")
                print(f"First 10 options: {p_opts[:10]}")
                
                # Check for exact plot
                exact_plot = [o for o in p_opts if o["t"] == str(target_plot)]
                val_plot = [o for o in p_opts if o["v"] == str(target_plot)]
                print(f"Target Plot '{target_plot}':")
                print(f"  Matched by Text (Visible Label): {exact_plot}")
                print(f"  Matched by Value: {val_plot}")
                
                if exact_plot:
                    chosen_val = exact_plot[0]["v"]
                    chosen_lbl = exact_plot[0]["t"]
                    print(f"Selecting option: label='{chosen_lbl}', value='{chosen_val}'...")
                    await page.select_option(sel, value=chosen_val)
                    await asyncio.sleep(2)
                    
                    # Submit View RoR
                    for btn_sel in ["#ctl00_ContentPlaceHolder1_btnRORFront", "#ctl00_ContentPlaceHolder1_btnViewROR", "#ctl00_ContentPlaceHolder1_btnShow"]:
                        btn = await page.query_selector(btn_sel)
                        if btn:
                            print(f"Clicking submit button {btn_sel}...")
                            await btn.click()
                            await asyncio.sleep(3)
                            break
                            
                    from bs4 import BeautifulSoup
                    soup = BeautifulSoup(await page.content(), "lxml")
                    khata = soup.find(id=lambda x: x and "lblKhatiyanslNo" in x)
                    print(f"Returned Khata: {khata.get_text(strip=True) if khata else 'Not Found'}")
                    
                    # Owner table
                    raiyat_el = soup.find(id=lambda x: x and "lblRaiyat" in x)
                    print(f"Returned Owner: {raiyat_el.get_text(strip=True) if raiyat_el else 'Not Found'}")
                    
                    # Plot in back table
                    back_table = soup.find("table", id=lambda x: x and "gvRorBack" in str(x))
                    if back_table:
                        rows = back_table.find_all("tr")
                        print(f"Back table rows: {len(rows)}")
                        for r in rows[:5]:
                            print(f"  Row: {[td.get_text(strip=True) for td in r.find_all('td')]}")
                break
            except Exception as e:
                print(f"Dropdown wait failed on {sel}: {e}")
                
        await browser.close()

async def main():
    # 1. G_Dimbo Plot 12
    await inspect_village_flow(7, 4, "DIMBO", "12")
    # 2. G_Dimbo Plot 1
    await inspect_village_flow(7, 4, "DIMBO", "1")
    # 3. Chakuli Plot 647
    await inspect_village_flow(15, 3, "CHAKULI", "647")

if __name__ == "__main__":
    asyncio.run(main())
