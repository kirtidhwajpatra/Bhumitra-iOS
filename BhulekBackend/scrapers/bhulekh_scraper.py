"""
Bhulekh Odisha Portal Scraper — Playwright Edition
https://bhulekh.ori.nic.in/RoRView.aspx

Uses a real headless Chromium browser to:
  1. Navigate to the Bhulekh RoR page via the homepage (session required)
  2. Select district by numeric ID from static mapping
  3. Wait for tahasil dropdown to populate, select by numeric ID from static mapping
  4. Wait for village dropdown to populate, fuzzy-match by romanized name
  5. Fill plot number and submit
  6. Parse the resulting RoR HTML page for owners, khata, area

Why Playwright?
  The site uses ASP.NET Web Forms with ScriptManager EventValidation.
  EventValidation cryptographically ties dropdown changes to JavaScript-triggered
  postbacks. Programmatic httpx POSTs are rejected server-side. A headless browser
  handles all of this naturally.

Why static mappings for district/tahasil?
  Bhulekh dropdown text is in Odia script only. We maintain a static English→ID
  mapping file (bhulekh_mappings.py) instead of fuzzy-matching Odia text.
"""
import logging
import asyncio
from bs4 import BeautifulSoup
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout
from models.ror_response import RoRResponse, OwnerEntry
from scrapers.bhulekh_mappings import (
    get_district_id, get_tahasil_id, get_tahasil_id_from_gis_block, 
    get_village_id, normalize
)
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

BASE_URL = "https://bhulekh.ori.nic.in/RoRView.aspx"


def _parse_ror_page(html: str, district: str, tahasil: str, village: str, plot: str) -> RoRResponse:
    """
    Parse the RoR result HTML from Bhulekh.
    Extracts owners, khata, area using multi-strategy table scanning.
    """
    soup = BeautifulSoup(html, "lxml")
    owners: List[OwnerEntry] = []
    raw_fields: Dict[str, str] = {}
    khata_number: Optional[str] = None
    area: Optional[str] = None
    land_type: Optional[str] = None

    # --- Strategy 0: Look for SPECIFIC Bhulekh IDs (Most reliable) ---
    
    # Khata Number
    khata_el = soup.find(id=lambda x: x and "lblKhatiyanslNo" in x)
    if khata_el:
        khata_number = khata_el.get_text(strip=True)
        logger.info(f"Parsed Khata Number from ID: {khata_number}")

    # Owner Name(s)
    owner_el = soup.find(id=lambda x: x and "lblName" in x)
    if owner_el:
        owner_text = owner_el.get_text(strip=True)
        if owner_text:
            # Sometimes owners are comma separated or have relation info
            # For now, we take the whole string as one owner or split by common separators
            names = [n.strip() for n in owner_text.replace("\n", ",").split(",") if n.strip()]
            for name in names:
                owners.append(OwnerEntry(name=name, khata_number=khata_number))
            logger.info(f"Parsed {len(owners)} owners from ID: {owner_text}")

    # Plot-specific info (Area, Classification) from gvRorBack
    # We look for the row containing our plot number
    if plot:
        plot_link = soup.find("a", string=lambda x: x and x.strip() == plot)
        if not plot_link:
            # Try finding an element with an ID that looks like a PlotNo label
            plot_link = soup.find(id=lambda x: x and "lblPlotNo" in x and plot in (soup.find(id=x).get_text() or ""))

        if plot_link:
            row = plot_link.find_parent("tr")
            if row:
                cells = row.find_all("td")
                # Based on observation:
                # Col 0: Plot No
                # Col 1: Extraction/Type (lbllType)
                # Col 2: Kisama (lblKisama)
                # Col 3: Acre (lblAcre)
                # Col 4: Decimal (lblDecimil)
                # Col 5: Hectare (lblHector)
                
                # Fetching Land Type
                type_el = row.find(id=lambda x: x and "lbllType" in x)
                if type_el:
                    land_type = type_el.get_text(strip=True)
                
                # Fetching Area (Acre + Decimal)
                acre_el = row.find(id=lambda x: x and "lblAcre" in x)
                dec_el = row.find(id=lambda x: x and "lblDecimil" in x)
                
                if acre_el or dec_el:
                    a = acre_el.get_text(strip=True) if acre_el else "0"
                    d = dec_el.get_text(strip=True) if dec_el else "0"
                    area = f"{a} Acre {d} Decimal".strip()
                    logger.info(f"Parsed Plot Area from row: {area}")

    # --- Strategy 1: Scan ALL tables for key-value pairs (Fallback) ---
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

        # Odia keywords
        # ଖତା ନମ୍ବର (Khata Number), ରୟତ (Raiyat), ରକବା (Area), କିସମ (Type)
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

        # Owner column detection in tables
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

    # Single-owner fallback
    if not owners and any(kw in str(raw_fields.keys()).lower() for kw in ["owner", "ରୟତ"]):
        for key, value in raw_fields.items():
            if any(kw in key.lower() for kw in ["owner", "ନାମ", "ରୟତ"]):
                if value and len(value) > 1 and value not in ["N/A", "-", ""]:
                    owners.append(OwnerEntry(name=value, khata_number=khata_number))

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
        source="bhulekh.ori.nic.in",
        cached=False,
    )


class BhulekhScraper:
    """
    Playwright-based Bhulekh RoR scraper.
    Uses a real Chromium browser to handle ASP.NET UpdatePanel AJAX postbacks,
    EventValidation, and all JavaScript interactions.
    """

    async def fetch_ror(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,    # GIS village ID for direct dropdown selection
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
        import re
        district_id = get_district_id(district)
        if not district_id:
            raise ValueError(
                f"District '{district}' not found in Bhulekh mapping. "
                f"Please check the district name spelling."
            )
        
        # If IDs aren't provided explicitly, try to extract them from names (e.g. "G_Keri_271" -> 271)
        if not b_id:
            match = re.search(r'(\d+)$', tahasil)
            if match:
                b_id = match.group(1)
        
        if not v_id:
            match = re.search(r'(\d+)$', village)
            if match:
                v_id = match.group(1)
                logger.info(f"Extracted v_id={v_id} from village name '{village}'")
        
        # Try to resolve tahasil ID: GIS b_id first, then static map, then live fallback
        tahasil_id: str | None = None
        if b_id:
            # First try direct GIS mapping
            tahasil_id = get_tahasil_id_from_gis_block(b_id)
            # If not in map, try using the number directly if it's short (likely a Bhulekh ID)
            if not tahasil_id and len(b_id) <= 2:
                tahasil_id = b_id
            
            if tahasil_id:
                logger.info(f"Resolved tahasil via b_id={b_id} → tahasil_id={tahasil_id}")
        
        if not tahasil_id:
            tahasil_id = get_tahasil_id(district_id, tahasil)
            if tahasil_id:
                logger.info(f"Resolved tahasil via name mapping '{tahasil}' → {tahasil_id}")

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
                result = await self._scrape(page, district, district_id, tahasil, tahasil_id, village, v_id, plot, mode=mode)
            finally:
                await ctx.close()
                await browser.close()

            return result

    async def _scrape(self, page, district: str, district_id: str, tahasil: str, tahasil_id: str | None, village: str, v_id: str | None, plot: str, mode: str = "data") -> RoRResponse | bytes:
        logger.info(f"[Playwright] Loading Bhulekh homepage...")
        
        # ── STEP 1: Load the HOMEPAGE ───────────────────────────────────────
        await page.goto("https://bhulekh.ori.nic.in/", wait_until="networkidle", timeout=60000)
        
        # ── STEP 1b: Switch to English for more predictable labels/IDs ────────
        try:
            # Look for English link - often in a small table at top right
            english_link = await page.query_selector("a#ctl00_lnkEnglish, a:has-text('English')")
            if english_link:
                await english_link.click()
                await page.wait_for_load_state("networkidle", timeout=10000)
                logger.info("[Playwright] Switched to English mode")
        except Exception as e:
            logger.warning(f"[Playwright] Could not switch to English mode: {e}")

        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=30000)
        logger.info(f"[Playwright] Page loaded at {page.url}. Selecting district ID={district_id}...")

        # ── STEP 2: Select District ─────────────────────────────────────────
        await page.select_option(
            "#ctl00_ContentPlaceHolder1_ddlDistrict",
            value=district_id
        )
        # Wait for tahasil dropdown to be populated (UpdatePanel refresh)
        await page.wait_for_function(
            """() => {
                const sel = document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil');
                return sel && sel.options.length > 1;
            }""",
            timeout=20000
        )
        logger.info(f"[Playwright] District selected ({district_id}). Selecting tahasil...")

        # ── STEP 3: Select Tahasil ──────────────────────────────────────────
        # Get all tahasil options
        tahasil_options = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlTahsil option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        logger.info(f"[Playwright] Got {len(tahasil_options)} tahasil options")
        
        # Use pre-resolved tahasil_id if available (from static mapping or GIS b_id)
        tahasil_value = tahasil_id
        
        # Validate that the resolved ID actually exists in the live dropdown
        if tahasil_value:
            valid_values = {o["value"] for o in tahasil_options}
            if tahasil_value not in valid_values:
                logger.warning(f"Tahasil ID '{tahasil_value}' not in live dropdown. Falling back to live lookup.")
                tahasil_value = None
        
        # Fallback: fuzzy match on romanized text (last resort)
        if not tahasil_value:
            tahasil_value = self._fuzzy_match(tahasil, tahasil_options)
        
        if not tahasil_value:
            available = [f"{o['value']}={o['text']}" for o in tahasil_options]
            logger.error(f"[Playwright] Tahasil '{tahasil}' (normalized: {normalize(tahasil)}) not found in {available}")
            raise ValueError(f"Tahasil '{tahasil}' not found. Available: {available[:15]}...")

        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=tahasil_value)
        await page.wait_for_function(
            """() => {
                const sel = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage');
                return sel && sel.options.length > 1;
            }""",
            timeout=20000
        )
        logger.info(f"[Playwright] Tahasil selected. Selecting village...")

        # ── STEP 4: Select Village ──────────────────────────────────────────
        village_options = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlVillage option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        village_value = None
        if v_id:
            valid_village_values = {o["value"] for o in village_options}
            if str(v_id) in valid_village_values:
                village_value = str(v_id)
                logger.info(f"[Playwright] Village selected directly via v_id={v_id}")
        
        # Second: Try the village mapping table (handles GIS romanization mismatches)
        if not village_value and tahasil_id:
            village_value = get_village_id(district_id, tahasil_id, village)
            if village_value:
                logger.info(f"[Playwright] Village resolved via mapping table: {village} → {village_value}")
        
        # Third: Fallback to fuzzy match on romanized text
        if not village_value:
            village_value = self._fuzzy_match(village, village_options)
        
        if not village_value:
            available = [f"{o['value']}={o['text']}" for o in village_options]
            logger.error(f"[Playwright] Village '{village}' (normalized: {normalize(village)}) not found in {available}")
            raise ValueError(f"Village '{village}' not found. Check backend logs for full list.")

        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=village_value)
        logger.info(f"[Playwright] Village selected ({village_value}). Selecting 'Plot' search mode...")

        # ── STEP 4b: Ensure 'Plot' search mode is selected ──────────────────
        # In English mode, these are ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1
        # In Odia mode, they might be rbPlot. We try all.
        radio_selectors = [
            "#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1",
            "#ctl00_ContentPlaceHolder1_rbPlot",
            "input[value='rbPlot']"
        ]
        
        clicked = False
        for i in range(3): # Retry 3 times
            for sel in radio_selectors:
                try:
                    radio = await page.wait_for_selector(sel, timeout=3000)
                    if radio:
                        await radio.click()
                        # Wait for UpdatePanel to refresh the next dropdown
                        await asyncio.sleep(2)
                        await page.wait_for_load_state("networkidle", timeout=5000)
                        
                        # Check if the dropdown label has changed to 'Plot' or 'ପ୍ଲଟ୍'
                        label_text = await page.inner_text("#aspnetForm")
                        if "Plot" in label_text or "ପ୍ଲଟ୍" in label_text:
                            logger.info(f"[Playwright] Search mode successfully changed to Plot via {sel}")
                            clicked = True
                            break
                except Exception:
                    continue
            if clicked: break
            logger.warning(f"[Playwright] Plot radio click retry {i+1}...")
            await asyncio.sleep(1)

        # ── STEP 5: Fill Plot Number and Submit ─────────────────────────────
        # Sometimes it's a dropdown 'ddlBindData' or 'ddlPlot', sometimes a textbox 'txtPlotNo'
        plot_submitted = False
        
        # Try Dropdown first (very common on Bhulekh after Plot radio selection)
        dropdown_selectors = [
            "#ctl00_ContentPlaceHolder1_ddlBindData", # Primary in English mode
            "#ctl00_ContentPlaceHolder1_ddlPlot",
            "#ctl00_ContentPlaceHolder1_ddlVillagePlot"
        ]
        for sel in dropdown_selectors:
            try:
                await page.wait_for_selector(sel, timeout=3000)
                # Select the plot in the dropdown
                await page.select_option(sel, label=plot)
                logger.info(f"[Playwright] Plot selected via dropdown: {sel}")
                plot_submitted = True
                # Wait a bit for AutoPostBack if it exists
                await asyncio.sleep(1)
                break
            except Exception:
                continue
        
        # Try Textbox if dropdown didn't work
        if not plot_submitted:
            for selector in ["#ctl00_ContentPlaceHolder1_txtPlotNo", "input[name*='txtPlotNo']"]:
                try:
                    await page.wait_for_selector(selector, timeout=2000)
                    await page.fill(selector, plot)
                    await page.press(selector, "Enter")
                    logger.info(f"[Playwright] Plot filled via textbox: {selector}")
                    plot_submitted = True
                    break
                except Exception:
                    continue

        # IMPORTANT: Even if submitted (selected in dropdown or hit Enter), 
        # Bhulekh usually requires clicking "View RoR" or "Front Page" / "Back Page"
        # Let's try to click any visible 'Show' or 'RoR' button to be sure.
        try:
            submit_selectors = [
                "#ctl00_ContentPlaceHolder1_btnViewROR", # Explicit RoR button
                "#ctl00_ContentPlaceHolder1_btnShow",
                "input[value*='RoR']",
                "input[value*='Show']",
            ]
            for sel in submit_selectors:
                btn = await page.query_selector(sel)
                if btn and await btn.is_visible():
                    # Use force=True and multiple clicks if needed, or dispatch event
                    await btn.click(force=True)
                    logger.info(f"[Playwright] Clicked submit button: {sel}")
                    break
            
            # Additional wait for the postback/navigation
            await page.wait_for_load_state("networkidle", timeout=10000)
        except Exception as e:
            logger.debug(f"[Playwright] Submit button click skipped/failed: {e}")

        if not plot_submitted:
            raise ValueError(f"Could not enter/submit plot number '{plot}' on Bhulekh site")

        # ── STEP 6: Wait for the RoR result ─────────────────────────────────
        # Wait specifically for the result container
        try:
            await page.wait_for_selector("#gvfront, #gvRorBack", timeout=20000)
            logger.info("[Playwright] RoR container detected")
            await asyncio.sleep(2) # Brief wait for rendering
        except Exception:
            logger.warning("[Playwright] RoR container not found via selector")

        if mode == "pdf":
            logger.info("[Playwright] Generating PDF...")
            # Hide the navigation/header elements for a clean PDF
            await page.evaluate("""() => {
                const hideIds = ['navigation', 'header', 'footer', 'ctl00_ContentPlaceHolder1_pnlSelection'];
                hideIds.forEach(id => {
                    const el = document.getElementById(id);
                    if (el) el.style.display = 'none';
                });
            }""")
            return await page.pdf(format="A4", print_background=True)

        # ── STEP 7: Extract Data directly via Page Evaluation ───────────────
        try:
            logger.info("[Playwright] Extracting data via page evaluation...")
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
                    
                    // Khata
                    const khata = getRes("lblKhatiyanslNo");
                    
                    // Landlord
                    const landlord = getRes("lblLandlordName");
                    
                    // Owners (can be multiple)
                    const ownerList = getResList("lblName");
                    const owners = [];
                    ownerList.forEach(txt => {
                         // Replace newlines with commas then split to avoid regex literals
                         txt.replace(/\\n/g, ",").split(",").forEach(n => {
                             const name = n.trim();
                             if (name) owners.push(name);
                         });
                    });
                    
                    // Plot details from the table gvRorBack (Back Page)
                    let landType = null;
                    let area = null;
                    
                    const plotRows = Array.from(document.querySelectorAll("#gvRorBack tr"));
                    for (const row of plotRows) {
                        const plotCell = row.querySelector('[id*="lblPlotNo"]');
                        if (plotCell && (plotCell.innerText.trim() === targetPlot || plotCell.innerText.includes(targetPlot))) {
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
            """, plot)
            
            extracted_khata = data.get("khata")
            landlord = data.get("landlord")
            
            extracted_owners = []
            for name in data.get("owners", []):
                extracted_owners.append(OwnerEntry(name=name, khata_number=extracted_khata))
            
            # If no owners found but landlord exists, add landlord as owner for Government land
            if not extracted_owners and landlord:
                extracted_owners.append(OwnerEntry(name=landlord, khata_number=extracted_khata))

            extracted_area = data.get("area")
            extracted_type = data.get("landType")
            
            if extracted_khata or extracted_owners:
                logger.info(f"[Playwright] Successfully extracted data: Khata={extracted_khata}, Owners={len(extracted_owners)}")
                
                # Cleanup debug files if they exist (optional)
                import os
                for f in ["last_ror_attempt.png", "last_ror_attempt.html", "ror_result_debug.png", "ror_result_debug.html"]:
                    if os.path.exists(f): os.remove(f)

                return RoRResponse(
                    success=True,
                    plot=plot,
                    village=village,
                    district=district,
                    tahasil=tahasil,
                    khata_number=extracted_khata,
                    area=extracted_area,
                    land_type=extracted_type,
                    owners=extracted_owners,
                    raw_fields={"landlord": landlord} if landlord else {},
                    source="bhulekh.ori.nic.in",
                    cached=False
                )
        except Exception as e:
            logger.warning(f"[Playwright] Direct extraction failed: {e}. Falling back to HTML parsing.")

        # FINAL FALLBACK: HTML Parsing
        html = await page.content()
        return _parse_ror_page(html, district, tahasil, village, plot)

    def _fuzzy_match(self, target: str, options: list) -> Optional[str]:
        """
        Advanced fuzzy-matching for Odia/English regional names.
        Handles common transliteration variations (pali/pally, pura/para, etc.)
        """
        target_norm = normalize(target)
        if not target_norm: return None
        
        # 1. Level 1: Precise normalized match
        for opt in options:
            if normalize(opt["text"]) == target_norm:
                return opt["value"]
        
        # 2. Level 2: Substring match (normalized)
        # Handles "KIMIRIBOLIDHANGADPARA" finding "KIMIRIBOLIDHANGADPARA 12"
        for opt in options:
            opt_norm = normalize(opt["text"])
            if target_norm in opt_norm or opt_norm in target_norm:
                logger.debug(f"[Fuzzy] Substring match: {target_norm} ~ {opt_norm}")
                return opt["value"]
        
        # 3. Level 3: Word overlap with transliteration tolerance
        # e.g. "Keonjhar Sadar" matching "Kendujhar Sadar"
        def get_stem(w):
            # Strip common suffixes for better matching
            w = re.sub(r'(PALI|PALLI|PALLY|PURA|PARA|GARH|GADA)$', '', w)
            return w

        target_words = {get_stem(w) for w in target_norm.split() if len(w) > 2}
        for opt in options:
            opt_norm = normalize(opt["text"])
            opt_words = {get_stem(w) for w in opt_norm.split() if len(w) > 2}
            
            # If significant word overlap (at least 75% or 1 key word)
            intersection = target_words & opt_words
            if intersection and (len(intersection) >= len(target_words) - 1):
                logger.info(f"[Fuzzy] Word overlap match: {target_norm} ~ {opt_norm}")
                return opt["value"]

        # 4. Level 4: Prefix match (greedy)
        for opt in options:
            opt_norm = normalize(opt["text"])
            if opt_norm.startswith(target_norm[:6]) or target_norm.startswith(opt_norm[:6]):
                logger.info(f"[Fuzzy] Prefix match: {target_norm} ~ {opt_norm}")
                return opt["value"]

        return None
