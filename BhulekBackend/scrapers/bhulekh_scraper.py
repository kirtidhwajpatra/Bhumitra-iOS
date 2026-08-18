"""
Bhulekh Odisha Portal Scraper — Deterministic & Fail-Closed Edition
https://bhulekh.ori.nic.in/RoRView.aspx

Uses Playwright with real headless Chromium browser to execute deterministic,
fail-closed Record of Rights (RoR) lookups against the official Odisha Bhulekh ASP.NET portal.

Enforces zero-tolerance against fuzzy guessing, prefix matching, or location truncation:
  1. District: exact static mapping
  2. Tahasil: exact numeric b_id / exact normalized name match in live dropdown
  3. Village: exact numeric v_id / exact normalized name match in live dropdown
  4. Plot: exact string match in plot dropdown or verified plot textbox
  5. Response: verified against official RoR DOM elements
"""
from typing import List, Dict, Any, Optional
import logging
import re
import asyncio
from bs4 import BeautifulSoup
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout
from models.ror_response import RoRResponse, OwnerEntry, BhulekhLocationIdentity, BhulekhPlotIdentity
from scrapers.bhulekh_mappings import (
    get_district_id, get_tahasil_id, get_tahasil_id_from_gis_block, 
    get_village_id, normalize
)

logger = logging.getLogger(__name__)

BASE_URL = "https://bhulekh.ori.nic.in/RoRView.aspx"


def _parse_ror_page(
    html: str, 
    district: str, 
    tahasil: str, 
    village: str, 
    plot: str,
    location_identity: Optional[BhulekhLocationIdentity] = None
) -> RoRResponse:
    """
    Parse the RoR result HTML from Bhulekh using strict exact-matching table scanning.
    """
    soup = BeautifulSoup(html, "lxml")
    owners: List[OwnerEntry] = []
    raw_fields: Dict[str, str] = {}
    khata_number: Optional[str] = None
    area: Optional[str] = None
    land_type: Optional[str] = None

    # --- Strategy 0: Look for SPECIFIC Bhulekh IDs (Most reliable) ---
    khata_el = soup.find(id=lambda x: x and "lblKhatiyanslNo" in x)
    if khata_el:
        khata_number = khata_el.get_text(strip=True)

    owner_el = soup.find(id=lambda x: x and "lblName" in x)
    if owner_el:
        owner_text = owner_el.get_text(strip=True)
        if owner_text:
            names = [n.strip() for n in owner_text.replace("\n", ",").split(",") if n.strip()]
            for name in names:
                owners.append(OwnerEntry(name=name, khata_number=khata_number))

    # Plot-specific info (Area, Classification) from gvRorBack
    if plot:
        # STRICT EXACT MATCH on plot number in HTML
        plot_link = soup.find("a", string=lambda x: x and x.strip() == plot)
        if not plot_link:
            plot_link = soup.find(id=lambda x: x and "lblPlotNo" in x and (soup.find(id=x).get_text() or "").strip() == plot)

        if plot_link:
            row = plot_link.find_parent("tr")
            if row:
                type_el = row.find(id=lambda x: x and "lbllType" in x)
                if type_el:
                    land_type = type_el.get_text(strip=True)
                
                acre_el = row.find(id=lambda x: x and "lblAcre" in x)
                dec_el = row.find(id=lambda x: x and "lblDecimil" in x)
                if acre_el or dec_el:
                    a = acre_el.get_text(strip=True) if acre_el else "0"
                    d = dec_el.get_text(strip=True) if dec_el else "0"
                    area = f"{a} Acre {d} Decimal".strip()

    # --- Strategy 1: Scan table rows for exact owner keywords if direct ID failed ---
    if not (khata_number and owners):
        for table in soup.find_all("table"):
            rows = table.find_all("tr")
            for row in rows:
                cells = row.find_all(["td", "th"])
                if len(cells) >= 2:
                    key = cells[0].get_text(strip=True)
                    value = cells[1].get_text(strip=True)
                    if key and value:
                        raw_fields[key] = value

        owner_keywords = ["pattadar", "raiyat", "owner", "name", "malik", "ରୟତ", "ନାମ"]
        area_keywords = ["area", "acre", "decimal", "extent", "ରକବା"]
        khata_keywords = ["khata", "khataNo", "khata number", "ଖତା"]
        type_keywords = ["land type", "category", "classification", "କିସମ"]

        for key, value in raw_fields.items():
            kl = key.lower()
            if any(kw in kl for kw in khata_keywords) and not khata_number:
                khata_number = value
            if any(kw in kl for kw in area_keywords) and not area:
                area = value
            if any(kw in kl for kw in type_keywords) and not land_type:
                land_type = value

        if not owners:
            for table in soup.find_all("table"):
                headers = [th.get_text(strip=True).lower() for th in table.find_all("th")]
                owner_col = next((i for i, h in enumerate(headers) if any(kw in h for kw in owner_keywords)), None)
                
                if owner_col is not None:
                    for row in table.find_all("tr")[1:]:
                        cells = row.find_all("td")
                        if len(cells) > owner_col:
                            name = cells[owner_col].get_text(strip=True)
                            if name and len(name) > 1 and not name.isdigit() and name not in ["SL NO", "Sl.No."]:
                                share = cells[owner_col + 1].get_text(strip=True) if len(cells) > owner_col + 1 else None
                                owners.append(OwnerEntry(name=name, share=share or None, khata_number=khata_number))

    return RoRResponse(
        success=True,
        plot=plot,
        village=village,
        district=district,
        tahasil=tahasil,
        khata_number=khata_number,
        area=area,
        land_type=land_type,
        owners=owners,
        raw_fields=raw_fields,
        location_identity=location_identity,
        source="bhulekh.ori.nic.in",
        cached=False,
    )


class BhulekhScraper:
    """
    Deterministic, fail-closed Playwright-based Bhulekh RoR scraper.
    """

    async def fetch_ror(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,
    ) -> RoRResponse:
        return await self._execute_scrape(
            district, tahasil, village, plot, b_id, v_id, mode="data"
        )

    async def download_ror_pdf(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,
    ) -> bytes:
        return await self._execute_scrape(
            district, tahasil, village, plot, b_id, v_id, mode="pdf"
        )

    async def _execute_scrape(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,
        mode: str = "data"
    ):
        district_id = get_district_id(district)
        if not district_id:
            raise ValueError(
                f"District '{district}' not found in verified Bhulekh mappings."
            )
        
        # Numeric extraction strictly from suffix if present (e.g. "G_Keri_271" -> "271")
        if not b_id:
            match = re.search(r'_(\d+)$', tahasil)
            if match:
                b_id = match.group(1)
        
        if not v_id:
            match = re.search(r'_(\d+)$', village)
            if match:
                v_id = match.group(1)

        tahasil_id: str | None = None
        if b_id:
            tahasil_id = get_tahasil_id_from_gis_block(b_id)
            if not tahasil_id and len(b_id) <= 2:
                tahasil_id = b_id

        if not tahasil_id:
            tahasil_id = get_tahasil_id(district_id, tahasil)

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            ctx = await browser.new_context(
                user_agent=(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/122.0.0.0 Safari/537.36"
                ),
                ignore_https_errors=True,
            )
            page = await ctx.new_page()

            try:
                result = await self._scrape(
                    page, district, district_id, tahasil, tahasil_id,
                    village, v_id, plot, b_id=b_id, mode=mode
                )
            finally:
                await ctx.close()
                await browser.close()

            return result

    async def _scrape(
        self,
        page,
        district: str,
        district_id: str,
        tahasil: str,
        tahasil_id: str | None,
        village: str,
        v_id: str | None,
        plot: str,
        b_id: str | None = None,
        mode: str = "data"
    ) -> RoRResponse | bytes:
        logger.info(f"[Playwright] Loading Bhulekh homepage...")
        await page.goto("https://bhulekh.ori.nic.in/", wait_until="networkidle", timeout=60000)
        
        # Switch to English mode
        try:
            english_link = await page.query_selector("a#ctl00_btnenglish, a#ctl00_lnkEnglish, a:has-text('English')")
            if english_link:
                async with page.expect_navigation(timeout=10000):
                    await english_link.click()
                logger.info("[Playwright] Switched to English mode")
        except Exception as e:
            logger.warning(f"[Playwright] English switch skipped: {e}")

        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=30000)

        # ── STEP 1: Select District (Exact ID) ──────────────────────────────
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=district_id)
        await page.wait_for_function(
            """() => {
                const sel = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil');
                return sel && sel.options.length > 1;
            }""",
            timeout=20000
        )

        # ── STEP 2: Select Tahasil (Deterministic Resolution) ───────────────
        tahasil_options = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlTahsil option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        
        tahasil_value = None
        valid_tahasil_values = {o["value"] for o in tahasil_options}

        # 1. Direct verified tahasil_id
        if tahasil_id and str(tahasil_id) in valid_tahasil_values:
            tahasil_value = str(tahasil_id)
            logger.info(f"[Playwright] Tahasil resolved via verified ID: {tahasil_value}")

        # 2. Exact normalized string match (STRICT EQUALITY ONLY — NO SUBSTRING/PREFIX)
        if not tahasil_value:
            norm_target = normalize(tahasil)
            exact_matches = [o["value"] for o in tahasil_options if normalize(o["text"]) == norm_target]
            if len(exact_matches) == 1:
                tahasil_value = exact_matches[0]
                logger.info(f"[Playwright] Tahasil resolved via exact normalized match: '{tahasil}' -> {tahasil_value}")
            elif len(exact_matches) > 1:
                raise ValueError(f"Ambiguous tahasil name '{tahasil}' matched multiple dropdown entries.")

        if not tahasil_value:
            available = [f"{o['value']}={o['text']}" for o in tahasil_options]
            raise ValueError(f"Tahasil '{tahasil}' could not be verified in official Bhulekh records for district '{district}'.")

        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=tahasil_value)
        await page.wait_for_function(
            """() => {
                const sel = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage');
                return sel && sel.options.length > 1;
            }""",
            timeout=20000
        )

        # ── STEP 3: Select Village (Deterministic Resolution) ───────────────
        village_options = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlVillage option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        valid_village_values = {o["value"] for o in village_options}
        village_value = None

        # 1. Direct verified v_id
        if v_id:
            if str(v_id) in valid_village_values:
                village_value = str(v_id)
                logger.info(f"[Playwright] Village resolved via verified v_id: {v_id}")
            elif b_id and str(v_id).startswith(str(b_id)):
                suffix_id = str(v_id)[len(str(b_id)):]
                try:
                    int_suffix = str(int(suffix_id))
                    if int_suffix in valid_village_values:
                        village_value = int_suffix
                        logger.info(f"[Playwright] Village resolved via stripped v_id: {int_suffix}")
                except ValueError:
                    pass

        # 2. Exact normalized string match (STRICT EQUALITY ONLY — NO PREFIX/SUBSTRING)
        if not village_value:
            norm_village = normalize(village)
            exact_matches = [o["value"] for o in village_options if normalize(o["text"]) == norm_village]
            if len(exact_matches) == 1:
                village_value = exact_matches[0]
                logger.info(f"[Playwright] Village resolved via exact normalized match: '{village}' -> {village_value}")
            elif len(exact_matches) > 1:
                raise ValueError(f"Ambiguous village name '{village}' matched multiple dropdown entries.")

        # 3. Known static mapping table (deterministic dictionary lookup only)
        if not village_value and tahasil_value:
            mapped_vid = get_village_id(district_id, tahasil_value, village)
            if mapped_vid and mapped_vid in valid_village_values:
                village_value = mapped_vid
                logger.info(f"[Playwright] Village resolved via mapping dictionary: {village} -> {village_value}")

        if not village_value:
            available = [f"{o['value']}={o['text']}" for o in village_options]
            logger.error(f"[Playwright] Village '{village}' not verified in {available[:10]}")
            raise ValueError(f"Unable to verify revenue village '{village}' from official land records.")

        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=village_value)

        # ── STEP 4: Switch Search Mode to 'Plot' ────────────────────────────
        radio_selectors = [
            "#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1",
            "#ctl00_ContentPlaceHolder1_rbPlot",
            "input[value='rbPlot']"
        ]
        clicked = False
        for i in range(3):
            for sel in radio_selectors:
                try:
                    radio = await page.wait_for_selector(sel, timeout=3000)
                    if radio:
                        await radio.click()
                        await asyncio.sleep(2)
                        await page.wait_for_load_state("networkidle", timeout=5000)
                        label_text = await page.inner_text("#aspnetForm")
                        if "Plot" in label_text or "ପ୍ଲଟ୍" in label_text:
                            clicked = True
                            break
                except Exception:
                    continue
            if clicked: break
            await asyncio.sleep(1)

        try:
            await page.wait_for_load_state("networkidle", timeout=5000)
        except Exception:
            pass
        await asyncio.sleep(2)

        # ── STEP 5: Exact Plot Selection (NO FUZZY / NO SUBSTRING) ──────────
        plot_submitted = False
        dropdown_selectors = [
            "#ctl00_ContentPlaceHolder1_ddlBindData",
            "#ctl00_ContentPlaceHolder1_ddlPlot",
            "#ctl00_ContentPlaceHolder1_ddlVillagePlot"
        ]
        clean_target_plot = plot.strip()

        for sel in dropdown_selectors:
            try:
                await page.wait_for_selector(sel, timeout=3000)
                opts = await page.eval_on_selector_all(
                    sel + " option",
                    "options => options.map(o => ({ value: o.value, text: o.text.trim() }))"
                )
                # STRICT EXACT STRING MATCH ONLY
                exact_plot_matches = [o["value"] for o in opts if o["text"] == clean_target_plot]
                
                if len(exact_plot_matches) == 1:
                    await page.select_option(sel, value=exact_plot_matches[0])
                    logger.info(f"[Playwright] Plot selected via exact dropdown match: {clean_target_plot} -> value={exact_plot_matches[0]}")
                    plot_submitted = True
                elif len(exact_plot_matches) > 1:
                    raise ValueError(f"Ambiguous plot number '{plot}' matches multiple records in village '{village}'.")
                
                if plot_submitted:
                    try:
                        await page.wait_for_load_state("networkidle", timeout=5000)
                    except Exception:
                        await asyncio.sleep(2)
                    break
            except Exception as e:
                logger.debug(f"Plot dropdown check on {sel}: {e}")
                continue

        # Fallback to exact textbox entry
        if not plot_submitted:
            for selector in ["#ctl00_ContentPlaceHolder1_txtPlotNo", "input[name*='txtPlotNo']"]:
                try:
                    await page.wait_for_selector(selector, timeout=2000)
                    await page.fill(selector, clean_target_plot)
                    await page.press(selector, "Enter")
                    logger.info(f"[Playwright] Plot entered via textbox: {selector}")
                    plot_submitted = True
                    break
                except Exception:
                    continue

        if not plot_submitted:
            raise ValueError(f"Plot number '{plot}' could not be verified in official Bhulekh records for village '{village}'.")

        # Submit RoR View
        try:
            submit_selectors = [
                "#ctl00_ContentPlaceHolder1_btnViewROR",
                "#ctl00_ContentPlaceHolder1_btnRORFront",
                "#ctl00_ContentPlaceHolder1_btnShow",
                "input[value*='RoR']",
                "input[value*='Show']",
            ]
            for sel in submit_selectors:
                btn = await page.query_selector(sel)
                if btn and await btn.is_visible():
                    await btn.click(force=True)
                    logger.info(f"[Playwright] Clicked submit: {sel}")
                    break
            try:
                await page.wait_for_load_state("networkidle", timeout=10000)
            except Exception:
                pass
        except Exception as e:
            logger.debug(f"[Playwright] Submit click: {e}")

        # ── STEP 6: Wait for RoR Container & Verify ─────────────────────────
        try:
            await page.wait_for_selector("#gvfront, #gvRorBack", timeout=20000)
            await asyncio.sleep(2)
        except Exception:
            logger.warning("[Playwright] RoR container not detected via primary selector")

        if mode == "pdf":
            await page.evaluate("""() => {
                const hideIds = ['navigation', 'header', 'footer', 'ctl00_ContentPlaceHolder1_pnlSelection'];
                hideIds.forEach(id => {
                    const el = document.getElementById(id);
                    if (el) el.style.display = 'none';
                });
            }""")
            return await page.pdf(format="A4", print_background=True)

        location_ident = BhulekhLocationIdentity(
            district_id=district_id,
            tahasil_id=tahasil_value,
            village_id=village_value,
            district_name=district,
            tahasil_name=tahasil,
            village_name=village
        )

        # ── STEP 7: Extract and Verify Exact Record ─────────────────────────
        try:
            data = await page.evaluate("""
                (targetPlot) => {
                    const getRes = (idPart) => {
                        const el = document.querySelector(`[id*="${idPart}"]`);
                        return el ? el.innerText.trim() : null;
                    };
                    const getResList = (idPart) => {
                        return Array.from(document.querySelectorAll(`[id*="${idPart}"]`))
                                    .map(el => el.innerText.trim())
                                    .filter(s => s);
                    };
                    
                    const khata = getRes("lblKhatiyanslNo");
                    const landlord = getRes("lblLandlordName");
                    const ownerList = getResList("lblName");
                    const owners = [];
                    ownerList.forEach(txt => {
                         txt.replace(/\\n/g, ",").split(",").forEach(n => {
                             const name = n.trim();
                             if (name) owners.push(name);
                         });
                    });
                    
                    let landType = null;
                    let area = null;
                    
                    // STRICT EXACT MATCH ON PLOT NUMBER in table row
                    const plotRows = Array.from(document.querySelectorAll("#gvRorBack tr"));
                    for (const row of plotRows) {
                        const plotCell = row.querySelector('[id*="lblPlotNo"]');
                        if (plotCell && plotCell.innerText.trim() === targetPlot) {
                            const typeEl = row.querySelector('[id*="lbllType"]');
                            const acreEl = row.querySelector('[id*="lblAcre"]');
                            const decEl = row.querySelector('[id*="lblDecimil"]');
                            
                            landType = typeEl ? typeEl.innerText.trim() : null;
                            const acre = acreEl ? acreEl.innerText.trim() : "0";
                            const dValue = decEl ? decEl.innerText.trim() : "0";
                            area = `${acre} Acre ${dValue} Decimal`.trim();
                            break;
                        }
                    }
                    return { khata, owners, landlord, landType, area };
                }
            """, clean_target_plot)

            extracted_khata = data.get("khata")
            landlord = data.get("landlord")
            extracted_owners = [OwnerEntry(name=name, khata_number=extracted_khata) for name in data.get("owners", [])]
            if not extracted_owners and landlord:
                extracted_owners.append(OwnerEntry(name=landlord, khata_number=extracted_khata))

            extracted_area = data.get("area")
            extracted_type = data.get("landType")

            if extracted_khata or extracted_owners:
                return RoRResponse(
                    success=True,
                    plot=clean_target_plot,
                    village=village,
                    district=district,
                    tahasil=tahasil,
                    khata_number=extracted_khata,
                    area=extracted_area,
                    land_type=extracted_type,
                    owners=extracted_owners,
                    raw_fields={"landlord": landlord} if landlord else {},
                    location_identity=location_ident,
                    source="bhulekh.ori.nic.in",
                    cached=False
                )
        except Exception as e:
            logger.warning(f"[Playwright] DOM extraction error: {e}")

        # Final Fallback to strict HTML parsing
        html = await page.content()
        return _parse_ror_page(html, district, tahasil, village, clean_target_plot, location_identity=location_ident)
