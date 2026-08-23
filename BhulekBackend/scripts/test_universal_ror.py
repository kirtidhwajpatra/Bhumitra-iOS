#!/usr/bin/env python3
"""
Test Universal RoR Scraper using official ASMX Khata resolution + Khatiyan search.
"""
import asyncio
import httpx
from bs4 import BeautifulSoup
from playwright.async_api import async_playwright
from scrapers.structured_ror_parser import parse_structured_ror

async def get_khata_for_plot(d_code: str, t_code: str, v_code: str, target_plot: str) -> str:
    url = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
    headers_k = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/KhatiyanUnicode"
    }
    body_k = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <KhatiyanUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{d_code}</dCode>
      <tCode>{t_code}</tCode>
      <vCode>{v_code}</vCode>
    </KhatiyanUnicode>
  </soap:Body>
</soap:Envelope>"""

    async with httpx.AsyncClient(timeout=20.0, verify=False) as client:
        r_k = await client.post(url, data=body_k, headers=headers_k)
        soup_k = BeautifulSoup(r_k.text, "xml")
        khatas = [t.text.strip() for t in soup_k.find_all("okhata_no")]
        
        headers_p = {
            "Content-Type": "text/xml; charset=utf-8",
            "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/PlotsUnicode"
        }
        
        async def check_khata(k):
            body_p = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <PlotsUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{d_code}</dCode>
      <tCode>{t_code}</tCode>
      <vCode>{v_code}</vCode>
      <khata_no>{k}</khata_no>
    </PlotsUnicode>
  </soap:Body>
</soap:Envelope>"""
            try:
                r_p = await client.post(url, data=body_p, headers=headers_p)
                soup_p = BeautifulSoup(r_p.text, "xml")
                plots = [p.text.strip() for p in soup_p.find_all("oplot_no")]
                if target_plot in plots:
                    return k
            except Exception:
                pass
            return None

        # Check in batches of 50
        batch_size = 50
        for i in range(0, len(khatas), batch_size):
            batch = khatas[i:i+batch_size]
            results = await asyncio.gather(*[check_khata(k) for k in batch])
            for res in results:
                if res:
                    return res
    return None

async def test_parcel(d_code, t_code, v_code, target_plot, dist_name, tah_name, vil_name):
    print(f"\n============================================================")
    print(f"TESTING: {vil_name} (Plot {target_plot}) in {dist_name} / {tah_name}")
    print(f"============================================================")
    
    # 1. Resolve Khata
    print(f"1. Resolving Khata for Plot {target_plot} via Bhulekh SOAP...")
    khata = await get_khata_for_plot(d_code, t_code, v_code, str(target_plot))
    print(f"   -> Resolved Parent Khata: '{khata}'")
    if not khata:
        print(f"   ERROR: Plot {target_plot} not found in village records.")
        return
        
    # 2. Fetch via Playwright Khatiyan mode
    print(f"2. Fetching verified RoR for Khata {khata} via Playwright...")
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=30000)
        
        # Switch to English
        try:
            english_link = await page.query_selector("a#ctl00_btnenglish, a#ctl00_lnkEnglish, a:has-text('English')")
            if english_link:
                async with page.expect_navigation(timeout=10000):
                    await english_link.click()
        except Exception:
            pass

        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=15000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=str(d_code))
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil'); return s && s.options.length > 1; }", timeout=20000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=str(t_code))
        await page.wait_for_function("() => { const s = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage'); return s && s.options.length > 1; }", timeout=20000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=str(v_code))
        await asyncio.sleep(2)
        
        # In Khatiyan mode, select Khata
        await page.wait_for_function(
            "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 5; }",
            timeout=20000
        )
        
        k_opts = await page.eval_on_selector_all("#ctl00_ContentPlaceHolder1_ddlBindData option", "opts => opts.map(o => ({v: o.value, t: o.text.trim()}))")
        matched_k = next((o for o in k_opts if o["t"] == str(khata)), None)
        if not matched_k:
            print(f"   ERROR: Khata {khata} not found in dropdown.")
            await browser.close()
            return
            
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=matched_k["v"])
        await asyncio.sleep(1)
        
        # Click Front page button
        front_btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORFront, #ctl00_ContentPlaceHolder1_btnViewROR")
        if front_btn and await front_btn.is_visible():
            await front_btn.click()
            await asyncio.sleep(3)
        front_html = await page.content()
        
        # Click Back page button
        back_btn = await page.query_selector("#ctl00_ContentPlaceHolder1_btnRORBack, #ctl00_ContentPlaceHolder1_btnBack, input[value*='Back'], a:has-text('Back')")
        if back_btn and await back_btn.is_visible():
            await back_btn.click()
            await asyncio.sleep(3)
        back_html = await page.content()
        
        full_html = front_html + "\n" + back_html
        ror = parse_structured_ror(full_html, dist_name, tah_name, vil_name, str(target_plot))
        print(f"   SUCCESS!")
        print(f"   Plot: {ror.plot}")
        print(f"   Khata: {ror.khata_number}")
        print(f"   Area: {ror.area}")
        print(f"   Land Type: {ror.land_type}")
        print(f"   Owners ({len(ror.owners)}): {[o.name for o in ror.owners]}")
        print(f"   Plots ({len(ror.plots)}): {[p.plot_number for p in ror.plots]}")
        print(f"   Verification: {ror.verification.status} (Plot Match: {ror.verification.plot_match})")
        
        await browser.close()

async def main():
    # 1. Chakuli Plot 647 (Bargarh)
    await test_parcel("15", "1", "61", "647", "Bargarh", "Atabira", "Chakuli_Mosaic")
    # 2. Raghunathpur Jali Plot 333 (Bhubaneswar)
    await test_parcel("20", "2", "359", "333", "Khordha", "Bhubaneswar", "Raghunathpur_Jali")
    # 3. G_Dimbo Plot 12 (Keonjhar)
    await test_parcel("7", "4", "317", "12", "Keonjhar", "Keonjhar Sadar", "G_Dimbo")
    # 4. G_Dimbo Plot 1 (Keonjhar)
    await test_parcel("7", "4", "317", "1", "Keonjhar", "Keonjhar Sadar", "G_Dimbo")

if __name__ == "__main__":
    asyncio.run(main())
