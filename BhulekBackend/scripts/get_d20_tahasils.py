#!/usr/bin/env python3
import asyncio
from playwright.async_api import async_playwright

async def get_d20_tahasils():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value="20")
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlTahsil option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        print("District 20 Tahasils:", opts)
        await browser.close()

if __name__ == "__main__":
    asyncio.run(get_d20_tahasils())
