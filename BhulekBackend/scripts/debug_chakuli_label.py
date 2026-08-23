#!/usr/bin/env python3
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup

async def debug_labels():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="15")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="1")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value="61")
        await asyncio.sleep(2)
        
        await page.wait_for_function("() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 5; }", timeout=20000)
        k_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        opt_277 = next(o for o in k_opts if o["t"] == "277")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=opt_277["v"])
        await asyncio.sleep(1)
        
        btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORFront")
        await btn.click()
        await asyncio.sleep(3)
        
        soup = BeautifulSoup(await page.content(), "lxml")
        print("All spans with id:")
        for sp in soup.find_all(["span", "label", "td"], id=True):
            print(f"  ID: {sp.get('id')} -> {repr(sp.get_text(strip=True))}")
            
        print("\nPage text occurrences of ମୌଜା:")
        text = soup.get_text()
        for line in text.split("\n"):
            if "ମୌଜା" in line or "ଚକୁଳି" in line or "ଜିଲ୍ଲା" in line:
                print(f"  Line: {repr(line.strip())}")
                
        await browser.close()

if __name__ == "__main__":
    asyncio.run(debug_labels())
