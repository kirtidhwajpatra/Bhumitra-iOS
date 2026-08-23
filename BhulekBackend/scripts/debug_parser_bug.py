#!/usr/bin/env python3
"""
DEBUG SCRIPT 6: Test parse_structured_ror directly on the full HTML from scratch_inspect_ror.
"""
import anyio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
from scrapers.structured_ror_parser import parse_structured_ror
import json

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context()
        page = await ctx.new_page()
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="7")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil').options.length > 1", timeout=15000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value="4")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage').options.length > 1", timeout=15000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value="317")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlRI').options.length > 1", timeout=15000)
        
        await page.click("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
        await page.wait_for_function("() => document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData') && document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData').options.length > 1", timeout=20000)
        
        plot_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option", "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))")
        target_p = next(p for p in plot_opts if p["text"] == "12")
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=target_p["value"])
        await page.wait_for_load_state("domcontentloaded", timeout=10000)
        
        print("Clicking #ctl00_ContentPlaceHolder1_btnRORFront ...")
        async with page.expect_navigation(timeout=20000):
            await page.click("#ctl00_ContentPlaceHolder1_btnRORFront")
            
        html = await page.content()
        await browser.close()
        
        print("=== RUNNING parse_structured_ror ON REAL HTML ===")
        try:
            res = parse_structured_ror(
                html=html,
                district="KEONJHAR",
                tahasil="KEONJHAR SADAR",
                village="ଡ଼ିମ୍ବୋ",
                plot="12",
            )
            print("RoR Response:")
            print("  Khata:", res.khata_number)
            print("  Owners count:", len(res.owners))
            for o in res.owners:
                print(f"    Owner: name='{o.name}', share='{o.share}', father='{o.father_husband_name}'")
            print("  Land type:", res.land_type)
            print("  Area:", res.area)
            print("  Raw fields:", res.raw_fields)
        except Exception as e:
            print("ERROR in parse_structured_ror:", type(e), e)

anyio.run(main)
