#!/usr/bin/env python3
"""
DEBUG SCRIPT 5: Investigate Bhulekh ROR Front vs Back page rendering and owner extraction.
Test a known private parcel in Keonjhar / Keonjhar Sadar / Dimbo / Plot 1182 (or other plot).
"""
import asyncio
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import json

async def test_bhulekh_front_back():
    print("=" * 70)
    print("BHULEKH FRONT VS BACK PAGE INSPECTION")
    print("=" * 70)
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        url = "http://bhulekh.ori.nic.in/RoRView.aspx"
        print(f"Loading {url}...")
        await page.goto(url, wait_until="domcontentloaded", timeout=30000)
        
        # 1. Select District: Keonjhar (value=7 or 07 or text='Keonjhar'/'କେନ୍ଦୁଝର')
        print("Selecting district...")
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict")
        opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlDistrict option", 
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        print(f"District options: {opts[:5]}...")
        
        # Select Keonjhar (07 or 7)
        dist_val = next((o['value'] for o in opts if 'keonjhar' in o['text'].lower() or 'କେନ୍ଦୁଝର' in o['text'] or o['value'] in ('7', '07', '224')), opts[1]['value'])
        print(f"Selected District value: {dist_val}")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=dist_val)
        
        # 2. Wait for Tahasil
        print("Waiting for Tahasil...")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        t_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlTahsil option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        print(f"Tahasil options ({len(t_opts)}): {[o['text'] for o in t_opts[:5]]}")
        
        t_val = next((o['value'] for o in t_opts if 'sadar' in o['text'].lower() or 'ସଦର' in o['text'] or o['value'] in ('4', '04')), t_opts[1]['value'])
        print(f"Selected Tahasil value: {t_val}")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=t_val)
        
        # 3. Wait for Village
        print("Waiting for Village...")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        v_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlVillage option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        print(f"Village options ({len(v_opts)}): {[o['text'] for o in v_opts[:5]]}")
        
        # Look for Dimbo (317)
        v_val = next((o['value'] for o in v_opts if o['value'] == '317' or 'dimbo' in o['text'].lower() or 'ଡ଼ିମ୍ବୋ' in o['text'] or 'ଡିମ୍ବୋ' in o['text']), v_opts[1]['value'])
        v_text = next((o['text'] for o in v_opts if o['value'] == v_val), '')
        print(f"Selected Village: value={v_val}, text='{v_text}'")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=v_val)
        await asyncio.sleep(1.5)
        
        # 4. Click Plot radio button
        print("Clicking Plot radio button...")
        radio = await page.wait_for_selector("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1, #ctl00_ContentPlaceHolder1_rbPlot, input[value='rbPlot']", timeout=10000)
        await radio.click()
        await asyncio.sleep(2)
        
        # 5. Wait for Plot dropdown
        print("Waiting for plot dropdown...")
        await page.wait_for_function("() => { const s = document.querySelector('#ctl00_ContentPlaceHolder1_ddlPlot, #ctl00_ContentPlaceHolder1_ddlBindData, #ctl00_ContentPlaceHolder1_ddlVillagePlot'); return s && s.options.length > 1; }", timeout=15000)
        
        p_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlPlot option, #ctl00_ContentPlaceHolder1_ddlBindData option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        print(f"Plot options count: {len(p_opts)}, first 10: {[o['text'] for o in p_opts[:10]]}")
        
        # Pick a plot: try plot 1182 or first non-empty plot
        test_plot = next((o['text'] for o in p_opts if o['text'] == '1182'), p_opts[1]['text'] if len(p_opts) > 1 else '1')
        print(f"Testing plot: '{test_plot}'")
        
        # Select plot
        sel_id = "#ctl00_ContentPlaceHolder1_ddlPlot" if await page.query_selector("#ctl00_ContentPlaceHolder1_ddlPlot") else "#ctl00_ContentPlaceHolder1_ddlBindData"
        await page.select_option(sel_id, label=test_plot)
        await asyncio.sleep(2)
        
        # 6. Check what buttons are available
        buttons = await page.eval_on_selector_all("input[type='submit'], button",
            "btns => btns.map(b => ({id: b.id, value: b.value, text: b.textContent.trim(), visible: b.offsetWidth > 0}))")
        print(f"\nAvailable buttons: {json.dumps(buttons, indent=2)}")
        
        # Check btnRORFront click
        front_btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORFront")
        back_btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORBack")
        print(f"\nbtnRORFront present: {front_btn is not None}, btnRORBack present: {back_btn is not None}")
        
        if front_btn:
            print("\n--- Clicking btnRORFront ---")
            await front_btn.click()
            await asyncio.sleep(3)
            html_front = await page.content()
            soup_front = BeautifulSoup(html_front, "lxml")
            
            # Check what's in Front page
            print("Front page checks:")
            print("  #gvfront present:", soup_front.find(id=lambda x: x and "gvfront" in str(x)) is not None)
            print("  #gvRorBack present:", soup_front.find(id=lambda x: x and "gvRorBack" in str(x)) is not None)
            print("  lblLandlordName:", soup_front.find(id=lambda x: x and "lblLandlordName" in str(x)))
            print("  lblKhatiyanslNo:", soup_front.find(id=lambda x: x and "lblKhatiyanslNo" in str(x)))
            
            # List all table elements on Front page
            tables = soup_front.find_all("table")
            print(f"  Total tables on Front page: {len(tables)}")
            for idx, t in enumerate(tables):
                t_id = t.get('id', 'no-id')
                rows = len(t.find_all('tr'))
                print(f"    Table {idx}: id='{t_id}', rows={rows}")
                # Print text snippet
                txt = t.get_text(separator=" | ")[:120].strip()
                print(f"      Text: {txt}")
        
        if back_btn:
            print("\n--- Clicking btnRORBack ---")
            await back_btn.click()
            await asyncio.sleep(3)
            html_back = await page.content()
            soup_back = BeautifulSoup(html_back, "lxml")
            
            # Check what's in Back page
            print("Back page checks:")
            print("  #gvfront present:", soup_back.find(id=lambda x: x and "gvfront" in str(x)) is not None)
            print("  #gvRorBack present:", soup_back.find(id=lambda x: x and "gvRorBack" in str(x)) is not None)
            print("  lblLandlordName:", soup_back.find(id=lambda x: x and "lblLandlordName" in str(x)))
            print("  lblKhatiyanslNo:", soup_back.find(id=lambda x: x and "lblKhatiyanslNo" in str(x)))
            
            tables_b = soup_back.find_all("table")
            print(f"  Total tables on Back page: {len(tables_b)}")
            for idx, t in enumerate(tables_b):
                t_id = t.get('id', 'no-id')
                rows = len(t.find_all('tr'))
                print(f"    Table {idx}: id='{t_id}', rows={rows}")
                txt = t.get_text(separator=" | ")[:120].strip()
                print(f"      Text: {txt}")

        await browser.close()


if __name__ == '__main__':
    asyncio.run(test_bhulekh_front_back())
