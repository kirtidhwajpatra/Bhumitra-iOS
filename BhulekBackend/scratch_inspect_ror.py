import anyio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup

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
            
        print("Navigation finished! New URL:", page.url)
        soup = BeautifulSoup(await page.content(), "html.parser")
        
        print("=== SPANS ON ROR PAGE ===")
        for s in soup.find_all("span"):
            sid = s.get("id", "")
            txt = s.get_text(strip=True)
            if sid and txt:
                print(f"  {sid}: {txt}")
                
        print("=== TABLES ON ROR PAGE ===")
        for t in soup.find_all("table"):
            tid = t.get("id", "")
            print(f"Table id={tid}")
            for tr in t.find_all("tr")[:5]:
                print("  Row:", [c.get_text(strip=True) for c in tr.find_all(["th", "td"])])
                
        await browser.close()

anyio.run(main)
