#!/usr/bin/env python3
"""
Diagnostic script to inspect Bhulekh DOM for:
1. G_Dimbo (Keonjhar)
2. Chakuli (Bargarh)
3. Raghunathpur Jali (Khordha)
"""
import asyncio
import logging
from playwright.async_api import async_playwright

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("diagnostic")

async def test_village(dist_id, tah_id, vill_name, target_plot):
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)")
        page = await context.new_page()
        
        logger.info(f"\n--- Testing Village {vill_name} in Dist {dist_id}, Tah {tah_id} for Plot {target_plot} ---")
        await page.goto("https://bhulekh.ori.nic.in/RoRView.aspx", timeout=30000)
        
        # Select District
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=dist_id)
        await asyncio.sleep(2)
        
        # Select Tahasil
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahasil", value=tah_id)
        await asyncio.sleep(2)
        
        # Find Village Option
        vill_opts = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlVillage option",
            "options => options.map(o => ({ value: o.value, text: o.text.trim() }))"
        )
        logger.info(f"Total village options: {len(vill_opts)}")
        matching_vills = [o for o in vill_opts if vill_name.lower() in o["text"].lower()]
        logger.info(f"Matching villages for '{vill_name}': {matching_vills}")
        
        if not matching_vills:
            logger.error("No matching village found!")
            await browser.close()
            return
            
        selected_vill = matching_vills[0]
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=selected_vill["value"])
        await asyncio.sleep(2)
        
        # Click Plot radio button
        logger.info("Clicking Plot radio button...")
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        
        # Wait for plot dropdown
        for sel in ["#ctl00_ContentPlaceHolder1_ddlPlot", "#ctl00_ContentPlaceHolder1_ddlBindData"]:
            try:
                await page.wait_for_function(
                    f"() => {{ const el = document.querySelector('{sel}'); return el && el.options && el.options.length > 1; }}",
                    timeout=15000
                )
                logger.info(f"Dropdown {sel} populated!")
                opts = await page.eval_on_selector_all(
                    sel + " option",
                    "options => options.map(o => ({ value: o.value, text: o.text.trim() }))"
                )
                logger.info(f"Total plot options in {sel}: {len(opts)}")
                logger.info(f"First 10 options: {opts[:10]}")
                
                # Check for target plot
                exact_matches = [o for o in opts if o["text"] == str(target_plot)]
                logger.info(f"Exact matches for text == '{target_plot}': {exact_matches}")
                
                value_matches = [o for o in opts if o["value"] == str(target_plot)]
                logger.info(f"Matches for value == '{target_plot}': {value_matches}")
                
                if exact_matches:
                    match_val = exact_matches[0]["value"]
                    match_lbl = exact_matches[0]["text"]
                    logger.info(f"Selecting option with text/label='{match_lbl}' and value='{match_val}'...")
                    await page.select_option(sel, value=match_val)
                    await asyncio.sleep(2)
                    
                    # Submit RoR View
                    for btn in ["#ctl00_ContentPlaceHolder1_btnRORFront", "#ctl00_ContentPlaceHolder1_btnViewROR", "#ctl00_ContentPlaceHolder1_btnShow"]:
                        b = await page.query_selector(btn)
                        if b:
                            logger.info(f"Clicking submit button: {btn}")
                            await b.click()
                            await asyncio.sleep(3)
                            break
                            
                    content = await page.content()
                    from bs4 import BeautifulSoup
                    soup = BeautifulSoup(content, "lxml")
                    khata = soup.find(id=lambda x: x and "lblKhatiyanslNo" in x)
                    logger.info(f"Returned Khata: {khata.get_text(strip=True) if khata else 'None'}")
                    
                    # Check plots in page
                    back_table = soup.find("table", id=lambda x: x and "gvRorBack" in str(x))
                    if back_table:
                        rows = back_table.find_all("tr")
                        logger.info(f"gvRorBack row count: {len(rows)}")
                        for r in rows[:5]:
                            logger.info(f"Row: {[td.get_text(strip=True) for td in r.find_all('td')]}")
                break
            except Exception as e:
                logger.warning(f"Error on {sel}: {e}")
                
        await browser.close()

if __name__ == "__main__":
    # Test G_Dimbo for Plot 12
    asyncio.run(test_village("7", "4", "G_Dimbo", "12"))
