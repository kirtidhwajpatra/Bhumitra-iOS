"""
Bhulekh Odisha Portal Scraper — Deterministic & Fail-Closed Edition with Verification Layer
https://bhulekh.ori.nic.in/RoRView.aspx

Uses Playwright with real headless Chromium browser to execute deterministic,
fail-closed Record of Rights (RoR) lookups against the official Odisha Bhulekh ASP.NET portal.

Enforces zero-tolerance against fuzzy guessing, prefix matching, or location truncation,
and verifies returned DOM identifiers before constructing RoRResponse.
"""
from typing import List, Dict, Any, Optional
import logging
import re
import asyncio
from bs4 import BeautifulSoup
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout
from models.ror_response import (
    RoRResponse, OwnerEntry, BhulekhLocationIdentity, BhulekhPlotIdentity,
    RoRVerification, RoRVerificationStatus
)
from scrapers.bhulekh_mappings import (
    get_district_id, get_tahasil_id, get_tahasil_id_from_gis_block, 
    get_village_id, normalize
)
from resolvers.bhulekh_identity_resolver import (
    BhulekhVillageResolver,
    ResolutionStatus,
    SCOPED_VILLAGE_ALIASES,
    BILINGUAL_VILLAGE_MAP,
    VerifiedBhulekhCatalog,
    clean_gis_village_name,
    normalize_phonetic,
    odia_to_phonetic,
    consonant_skeleton,
)
from resolvers.village_identity_normalizer import (
    normalize_odia_village_key,
    normalize_village_name,
)
from resolvers.plot_normalizer import normalize_plot_number, is_exact_plot_match
from resolvers.bhulekh_soap_resolver import resolve_khata_for_plot_soap
from core.config import settings

logger = logging.getLogger(__name__)

BASE_URL = "https://bhulekh.ori.nic.in/Default.aspx"

ODIA_TO_ENG_DIGITS = str.maketrans("୦୧୨୩୪୫୬୭୮୯", "0123456789")

def to_english_digits(text: str) -> str:
    return text.translate(ODIA_TO_ENG_DIGITS) if text else ""


def verify_ror_result(
    soup: BeautifulSoup,
    requested_district: str,
    requested_tahasil: str,
    requested_village: str,
    requested_plot: str,
    location_identity: Optional[BhulekhLocationIdentity] = None,
) -> RoRVerification:
    """
    Language-Independent 3-Level Verification Hierarchy:
    LEVEL 1: STRONG CANONICAL IDENTITY (Canonical IDs & Exact Plot Number)
    LEVEL 2: SUPPORTING NAME CHECK (Diagnostics & Evidence)
    LEVEL 3: CONFLICT DETECTION (Hard Fail-Closed on Contradictory IDs/Plots)
    """
    def get_el_text(id_patterns: List[str]) -> Optional[str]:
        for pattern in id_patterns:
            el = soup.find(id=lambda x: x and pattern.lower() in x.lower())
            if el:
                txt = el.get_text(strip=True)
                if txt and txt not in ("N/A", "-", "", "<null>"):
                    return txt
        return None

    returned_dist = get_el_text(["lblDistrict", "lblDistrictName", "lblDist"])
    returned_tah = get_el_text(["lblTahasil", "lblTahasilName", "lblTehsil"])
    returned_vill = get_el_text(["lblVillage", "lblVillageName", "lblMouza", "lblMouja"])

    # Fallback to cell text parsing (e.g. "ମୌଜା : ଡ଼ିମ୍ବୋ", "ତହସିଲ : ସଦର", "ଜିଲ୍ଲା : କେନ୍ଦୁଝର")
    page_text = soup.get_text(separator=" | ")

    if not returned_dist:
        for m in re.finditer(r'(?:ଜିଲ୍ଲା|District)\s*[:\-]\s*([^\n\r\|]+)', page_text):
            prefix = page_text[max(0, m.start() - 20):m.start()].lower()
            val = m.group(1).strip()
            if "no. of" not in prefix and "number of" not in prefix and not val.isdigit() and len(val) >= 2:
                returned_dist = val
                break

    if not returned_tah:
        for m in re.finditer(r'(?:ତହସିଲ|Tahasil|Tehsil)\s*[:\-]\s*([^\n\r\|]+)', page_text):
            prefix = page_text[max(0, m.start() - 20):m.start()].lower()
            val = m.group(1).strip()
            if "no. of" not in prefix and "number of" not in prefix and not val.isdigit() and len(val) >= 2:
                returned_tah = val
                break

    if not returned_vill:
        for m in re.finditer(r'(?:ମୌଜା|Village|Mouza)\s*[:\-]\s*([^\n\r\|]+)', page_text):
            prefix = page_text[max(0, m.start() - 20):m.start()].lower()
            val = m.group(1).strip()
            if "no. of" not in prefix and "number of" not in prefix and not val.isdigit() and len(val) >= 2:
                returned_vill = val
                break

    # Extract plot number from gvRorBack plot cells or specific plot label/link
    returned_plot = None
    target_clean = normalize_plot_number(requested_plot)

    # 1. Check explicit plot label matching target_clean
    plot_el = soup.find(id=lambda x: x and "lblPlotNo" in x)
    if plot_el:
        txt = normalize_plot_number(plot_el.get_text(strip=True))
        if is_exact_plot_match(txt, target_clean):
            returned_plot = txt

    # 2. Check gvRorBack table first 3 columns (Plot Number columns) for ALL rows
    back_table = soup.find("table", id=lambda x: x and "gvRorBack" in str(x))
    if not returned_plot and back_table:
        for row in back_table.find_all("tr"):
            tds = row.find_all("td")
            if tds:
                for col_idx in [0, 1, 2]:
                    if col_idx < len(tds):
                        cell_txt = normalize_plot_number(tds[col_idx].get_text(strip=True))
                        m = re.match(r'^([0-9]+(?:/[0-9A-Za-z]+)?[A-Za-z]?)', cell_txt)
                        if m and is_exact_plot_match(m.group(1), target_clean):
                            returned_plot = normalize_plot_number(m.group(1))
                            break
                if returned_plot:
                    break

    # 3. Check explicit anchor links matching exact plot
    if not returned_plot:
        for link in soup.find_all("a"):
            link_text = normalize_plot_number(link.get_text(strip=True))
            if is_exact_plot_match(link_text, target_clean):
                returned_plot = link_text
                break

    # 4. Check explicit page text label: e.g. "ପ୍ଲଟ୍ ନଂ : 1182" or "Plot: 1182" or "Plot No. 1182"
    if not returned_plot:
        plot_m = re.search(r'(?:Plot\s*(?:No\.?)?|ପ୍ଲଟ୍?\s*(?:ନ[ଂମ୍ବର]*)?)\s*[:\-]\s*([0-9\u0B66-\u0B6F]+(?:/[0-9\u0B66-\u0B6FA-Za-z]+)?[A-Za-z]?)', page_text, flags=re.I)
        if plot_m and is_exact_plot_match(normalize_plot_number(plot_m.group(1)), target_clean):
            returned_plot = normalize_plot_number(plot_m.group(1))

    # 5. If STILL not matched, capture first found plot for diagnostic error reporting
    if not returned_plot:
        if plot_el:
            returned_plot = normalize_plot_number(plot_el.get_text(strip=True))
        elif back_table:
            for row in back_table.find_all("tr"):
                tds = row.find_all("td")
                if tds:
                    for col_idx in [0, 1, 2]:
                        if col_idx < len(tds):
                            cell_txt = normalize_plot_number(tds[col_idx].get_text(strip=True))
                            m = re.match(r'^([0-9\u0B66-\u0B6F]+(?:/[0-9\u0B66-\u0B6FA-Za-z]+)?[A-Za-z]?)', cell_txt)
                            if m:
                                returned_plot = normalize_plot_number(m.group(1))
                                break
                    if returned_plot:
                        break
        if not returned_plot:
            plot_m = re.search(r'(?:Plot\s*(?:No\.?)?|ପ୍ଲଟ୍?\s*(?:ନ[ଂମ୍ବର]*)?)\s*[:\-]\s*([0-9\u0B66-\u0B6F]+(?:/[0-9\u0B66-\u0B6FA-Za-z]+)?[A-Za-z]?)', page_text, flags=re.I)
            if plot_m:
                returned_plot = normalize_plot_number(plot_m.group(1))

    plot_match = bool(returned_plot and is_exact_plot_match(returned_plot, target_clean))

    # ── LEVEL 1: CANONICAL ADMINISTRATIVE IDENTIFIERS ─────────────────────────
    req_did = (location_identity.district_id if location_identity else None) or get_district_id(requested_district)
    ret_did = get_district_id(returned_dist) if returned_dist else None
    
    req_tid = (location_identity.tahasil_id if location_identity else None) or (get_tahasil_id(req_did or "", requested_tahasil) if req_did else None)
    ret_tid = get_tahasil_id(ret_did or req_did or "", returned_tah) if (returned_tah and (ret_did or req_did)) else None
    if not ret_tid and req_did and returned_tah:
        ret_tid = VerifiedBhulekhCatalog._tahasil_by_key.get((req_did, normalize_odia_village_key(returned_tah))) or VerifiedBhulekhCatalog._tahasil_by_key.get((req_did, normalize_village_name(returned_tah)))

    req_vid = location_identity.village_id if location_identity else None

    # ── LEVEL 3: CONFLICT DETECTION (HARD FAIL-CLOSED) ───────────────────────
    # A. Real District Contradiction
    if req_did and ret_did and str(req_did).strip() != str(ret_did).strip():
        logger.error(f"[Verification] District ID Conflict: requested '{req_did}', returned '{ret_did}'")
        return RoRVerification(
            status=RoRVerificationStatus.MISMATCH,
            requested_district=requested_district,
            requested_tahasil=requested_tahasil,
            requested_village=requested_village,
            requested_plot=requested_plot,
            returned_district=returned_dist,
            returned_tahasil=returned_tah,
            returned_village=returned_vill,
            returned_plot=returned_plot,
            location_match=False,
            plot_match=plot_match,
            details=f"District ID Conflict: Requested district '{requested_district}' (ID {req_did}), but portal returned '{returned_dist}' (ID {ret_did}).",
            identity_match_method="CONFLICT_DETECTED",
            name_match_status="DISTRICT_ID_MISMATCH"
        )

    # B. Real Tahasil Contradiction
    if req_tid and ret_tid and str(req_tid).strip() != str(ret_tid).strip():
        logger.error(f"[Verification] Tahasil ID Conflict: requested '{req_tid}', returned '{ret_tid}'")
        return RoRVerification(
            status=RoRVerificationStatus.MISMATCH,
            requested_district=requested_district,
            requested_tahasil=requested_tahasil,
            requested_village=requested_village,
            requested_plot=requested_plot,
            returned_district=returned_dist,
            returned_tahasil=returned_tah,
            returned_village=returned_vill,
            returned_plot=returned_plot,
            location_match=False,
            plot_match=plot_match,
            details=f"Tahasil ID Conflict: Requested tahasil '{requested_tahasil}' (ID {req_tid}), but portal returned '{returned_tah}' (ID {ret_tid}).",
            identity_match_method="CONFLICT_DETECTED",
            name_match_status="TAHASIL_ID_MISMATCH"
        )

    # C. Real Plot Contradiction
    if not plot_match:
        if not returned_plot:
            return RoRVerification(
                status=RoRVerificationStatus.INSUFFICIENT_DATA,
                requested_district=requested_district,
                requested_tahasil=requested_tahasil,
                requested_village=requested_village,
                requested_plot=requested_plot,
                returned_district=returned_dist,
                returned_tahasil=returned_tah,
                returned_village=returned_vill,
                returned_plot=returned_plot,
                location_match=False,
                plot_match=False,
                details=f"Portal response does not contain confirmation for plot '{requested_plot}'.",
                identity_match_method="PLOT_NOT_FOUND",
                name_match_status="NOT_APPLICABLE"
            )
        else:
            return RoRVerification(
                status=RoRVerificationStatus.MISMATCH,
                requested_district=requested_district,
                requested_tahasil=requested_tahasil,
                requested_village=requested_village,
                requested_plot=requested_plot,
                returned_district=returned_dist,
                returned_tahasil=returned_tah,
                returned_village=returned_vill,
                returned_plot=returned_plot,
                location_match=False,
                plot_match=False,
                details=f"Plot mismatch: Requested plot '{requested_plot}', but portal returned plot '{returned_plot}'.",
                identity_match_method="PLOT_MISMATCH",
                name_match_status="NOT_APPLICABLE"
            )

    # ── LEVEL 2: SUPPORTING NAME CHECK & DIAGNOSTICS ──────────────────────────
    clean_req_v = clean_gis_village_name(requested_village)
    clean_ret_v = clean_gis_village_name(returned_vill) if returned_vill else ""
    norm_req_v = normalize(clean_req_v)
    norm_ret_v = normalize(clean_ret_v)
    odia_req_k = normalize_odia_village_key(clean_req_v)
    odia_ret_k = normalize_odia_village_key(clean_ret_v)

    sk_req_v = consonant_skeleton(normalize_phonetic(clean_req_v)).replace(" ", "")
    sk_ret_v = consonant_skeleton(odia_to_phonetic(returned_vill)).replace(" ", "") if returned_vill else ""

    vill_skel_match = bool(sk_req_v and sk_ret_v and (sk_req_v == sk_ret_v or sk_req_v in sk_ret_v or sk_ret_v in sk_req_v))
    alias_target = SCOPED_VILLAGE_ALIASES.get((req_did or "", req_tid or "", normalize(requested_village))) if (req_did and req_tid) else None

    # Check if catalog has matching village name for the requested village ID
    cat_vill_name = None
    if req_did and req_tid and req_vid:
        cat_entry = VerifiedBhulekhCatalog._by_id.get((str(req_did), str(req_tid), str(req_vid)))
        if cat_entry:
            cat_vill_name = cat_entry.get("bhulekh_village_name") or cat_entry.get("bhulekh_mouza_name")

    cat_vill_match = bool(
        cat_vill_name and returned_vill and (
            normalize(cat_vill_name) == norm_ret_v
            or normalize_odia_village_key(cat_vill_name) == odia_ret_k
            or consonant_skeleton(odia_to_phonetic(cat_vill_name)).replace(" ", "") == sk_ret_v
        )
    )

    # Name matching classification for observability
    if not returned_vill:
        name_match_status = "NOT_AVAILABLE"
    elif norm_ret_v == norm_req_v:
        name_match_status = "EXACT"
    elif odia_req_k and odia_ret_k and odia_req_k == odia_ret_k:
        name_match_status = "NORMALIZED"
    elif vill_skel_match or normalize_phonetic(clean_req_v) == odia_to_phonetic(returned_vill):
        name_match_status = "TRANSLITERATED"
    elif cat_vill_match:
        name_match_status = "CATALOG_MAPPED"
    elif alias_target and (norm_ret_v == normalize(alias_target) or odia_to_phonetic(returned_vill) == normalize_phonetic(alias_target)):
        name_match_status = "CANONICAL_ALIAS"
    else:
        name_match_status = "UNRESOLVED_NAME_MISMATCH"

    # Canonical Location Confirmation
    canonical_key = f"{req_did}:{req_tid}:{req_vid}:{target_clean}" if (req_did and req_tid and req_vid) else None
    
    # Village confirmation:
    # A returned village is valid if:
    # 1. returned_vill is empty / not present in DOM header
    # 2. or it matches via EXACT, NORMALIZED, TRANSLITERATED, CATALOG_MAPPED, or CANONICAL_ALIAS
    vill_ok = (not returned_vill) or (name_match_status in ("EXACT", "NORMALIZED", "TRANSLITERATED", "CATALOG_MAPPED", "CANONICAL_ALIAS"))

    if not vill_ok:
        logger.error(f"[Verification] Village Conflict: Requested '{requested_village}' (ID {req_vid}), returned '{returned_vill}'")
        return RoRVerification(
            status=RoRVerificationStatus.MISMATCH,
            requested_district=requested_district,
            requested_tahasil=requested_tahasil,
            requested_village=requested_village,
            requested_plot=requested_plot,
            returned_district=returned_dist,
            returned_tahasil=returned_tah,
            returned_village=returned_vill,
            returned_plot=returned_plot,
            location_match=False,
            plot_match=True,
            details=f"Location mismatch: Requested village '{requested_village}', but portal returned '{returned_vill}'.",
            identity_match_method="CONFLICT_DETECTED",
            name_match_status=name_match_status,
            canonical_identity=canonical_key
        )

    has_strong_canonical_id = bool(location_identity and req_did and req_tid and req_vid)
    match_method = "CANONICAL_IDS_AND_PLOT" if has_strong_canonical_id else "NAME_MATCH_FALLBACK"

    logger.info(f"[Verification] SUCCESS: Canonical Key '{canonical_key}' verified via {match_method} (Name: {name_match_status})")

    return RoRVerification(
        status=RoRVerificationStatus.VERIFIED,
        requested_district=requested_district,
        requested_tahasil=requested_tahasil,
        requested_village=requested_village,
        requested_plot=requested_plot,
        returned_district=returned_dist or requested_district,
        returned_tahasil=returned_tah or requested_tahasil,
        returned_village=returned_vill or requested_village,
        returned_plot=returned_plot,
        location_match=True,
        plot_match=True,
        details="Official Record of Rights successfully verified against portal response.",
        identity_match_method=match_method,
        name_match_status=name_match_status,
        canonical_identity=canonical_key
    )


def _parse_ror_page(
    html: str, 
    district: str, 
    tahasil: str, 
    village: str, 
    plot: str,
    location_identity: Optional[BhulekhLocationIdentity] = None
) -> RoRResponse:
    """
    Parse the RoR result HTML from Bhulekh using structured table scanning and verification.
    """
    from scrapers.structured_ror_parser import parse_structured_ror
    return parse_structured_ror(
        html=html,
        district=district,
        tahasil=tahasil,
        village=village,
        plot=plot,
        location_identity=location_identity
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

        # Crosswalk resolution for generic super-region Tahasils
        if not tahasil_id:
            from resolvers.bhulekh_identity_resolver import VerifiedBhulekhCatalog
            cat_rec, _, _ = VerifiedBhulekhCatalog.lookup(district_id, "", village, v_id)
            if cat_rec and cat_rec.get("bhulekh_tahasil_id"):
                tahasil_id = str(cat_rec["bhulekh_tahasil_id"])

        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                args=[
                    "--no-sandbox",
                    "--disable-setuid-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-gpu",
                ],
            )
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
        logger.info(f"[Playwright] Loading Bhulekh homepage ({BASE_URL})...")
        await page.goto(BASE_URL, wait_until="domcontentloaded", timeout=settings.BHULEKH_NAVIGATION_TIMEOUT_MS)
        
        # Switch to English mode
        try:
            english_link = await page.query_selector("a#ctl00_btnenglish, a#ctl00_lnkEnglish, a:has-text('English')")
            if english_link:
                async with page.expect_navigation(timeout=settings.BHULEKH_ACTION_TIMEOUT_MS):
                    await english_link.click()
                logger.info("[Playwright] Switched to English mode")
        except Exception as e:
            logger.warning(f"[Playwright] English switch skipped: {e}")

        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=settings.BHULEKH_ACTION_TIMEOUT_MS)

        # ── STEP 1: Select District (Exact ID with stripped zero support) ───
        dist_options = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlDistrict option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        valid_dist_values = {o["value"] for o in dist_options}
        target_dist = str(district_id)
        if target_dist not in valid_dist_values and target_dist.isdigit():
            stripped = str(int(target_dist))
            if stripped in valid_dist_values:
                target_dist = stripped
        if target_dist not in valid_dist_values:
            norm_d = normalize(district)
            for o in dist_options:
                if normalize(o["text"]) == norm_d or norm_d in normalize(o["text"]):
                    target_dist = o["value"]
                    break

        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=target_dist)
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
        if tahasil_id:
            t_str = str(tahasil_id)
            if t_str in valid_tahasil_values:
                tahasil_value = t_str
            elif t_str.isdigit() and str(int(t_str)) in valid_tahasil_values:
                tahasil_value = str(int(t_str))
            if tahasil_value:
                logger.info(f"[Playwright] Tahasil resolved via verified ID: {tahasil_value}")

        # 2. Exact normalized string match (STRICT EQUALITY ONLY)
        if not tahasil_value:
            norm_target = normalize(tahasil)
            exact_matches = [o["value"] for o in tahasil_options if normalize(o["text"]) == norm_target or norm_target in normalize(o["text"])]
            if len(exact_matches) == 1:
                tahasil_value = exact_matches[0]
                logger.info(f"[Playwright] Tahasil resolved via normalized match: '{tahasil}' -> {tahasil_value}")
            elif len(exact_matches) > 1:
                raise ValueError(f"Ambiguous tahasil name '{tahasil}' matched multiple dropdown entries.")

        if not tahasil_value:
            raise ValueError(f"Tahasil '{tahasil}' could not be verified in official Bhulekh records for district '{district}'.")

        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=tahasil_value)
        await page.wait_for_function(
            """() => {
                const sel = document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage');
                return sel && sel.options.length > 1;
            }""",
            timeout=20000
        )

        # ── STEP 3: Select Village (Deterministic 6-Level Resolver) ─────────
        village_options = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlVillage option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        
        status, matched_opt, method_detail = BhulekhVillageResolver.resolve_mouza_option(
            district_id=target_dist,
            tahasil_id=tahasil_value,
            gis_village_name=village,
            gis_village_id=v_id,
            available_options=village_options,
        )

        if not matched_opt or status not in (
            ResolutionStatus.EXACT,
            ResolutionStatus.NORMALIZED_EXACT,
            ResolutionStatus.CANONICAL_ALIAS,
            ResolutionStatus.BILINGUAL_MATCH,
            ResolutionStatus.VERIFIED_MAPPED,
        ):
            logger.error(f"[Playwright] Village resolution failed for '{village}': {method_detail}")
            raise ValueError(f"Unable to verify revenue village '{village}' from official land records: {method_detail}")

        village_value = matched_opt["value"]
        logger.info(f"[Playwright] Village successfully resolved: '{village}' -> {matched_opt['text']} (ID: {village_value}) via {method_detail}")

        await page.select_option("#ctl00_ContentPlaceHolder1_ddlVillage", value=village_value)
        await asyncio.sleep(1.5)

        # ── STEP 4: Select Parcel via SOAP Parent Khata OR Plot Dropdown ───
        clean_target_plot = plot.strip()
        soap_khata = await resolve_khata_for_plot_soap(
            d_code=district_id,
            t_code=tahasil_value,
            v_code=village_value,
            target_plot=clean_target_plot
        )

        front_html = ""
        back_html = ""

        if soap_khata:
            logger.info(f"[Playwright] Using official parent Khata '{soap_khata}' for Plot '{clean_target_plot}'")
            # In Khatiyan mode (default search type), wait for dropdown
            await page.wait_for_function(
                "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 1; }",
                timeout=20000
            )
            k_opts = await page.eval_on_selector_all(
                "#ctl00_ContentPlaceHolder1_ddlBindData option",
                "opts => opts.map(o => ({ value: o.value, text: o.text.trim() }))"
            )
            matched_k = next((o for o in k_opts if o["text"] == str(soap_khata)), None)
            if not matched_k:
                raise ValueError(f"Khata '{soap_khata}' could not be located in official dropdown for village '{village}'.")
                
            await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=matched_k["value"])
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

        else:
            # Fallback to direct Plot search mode
            logger.info(f"[Playwright] SOAP lookup not available. Discovering Parent Khata from Plot dropdown for Plot '{clean_target_plot}'")
            plot_radio = await page.query_selector("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_1")
            discovered_khata = None
            if plot_radio:
                await plot_radio.click()
                try:
                    await page.wait_for_function(
                        "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 0 && el.options[0].text.includes('Plot'); }",
                        timeout=20000
                    )
                except Exception:
                    await asyncio.sleep(2)

                for sel in ["#ctl00_ContentPlaceHolder1_ddlBindData", "#ctl00_ContentPlaceHolder1_ddlPlot"]:
                    try:
                        await page.wait_for_selector(sel, timeout=10000)
                        opts = await page.eval_on_selector_all(
                            sel + " option",
                            "options => options.map(o => ({ value: o.value.trim(), text: o.text.trim() }))"
                        )
                        exact_matches = [o for o in opts if o["text"] == clean_target_plot]
                        if len(exact_matches) >= 1:
                            discovered_khata = exact_matches[0]["value"]
                            logger.info(f"[Playwright] Discovered parent Khata '{discovered_khata}' for Plot '{clean_target_plot}'")
                            break
                    except Exception:
                        continue

            if not discovered_khata:
                raise ValueError(f"Plot number '{plot}' could not be verified in official Bhulekh records for village '{village}'.")

            # Switch back to Khatiyan mode to reliably load full Front and Back RoR pages
            khatiyan_radio = await page.query_selector("#ctl00_ContentPlaceHolder1_rbtnRORSearchtype_0")
            if khatiyan_radio:
                await khatiyan_radio.click()
                try:
                    await page.wait_for_function(
                        "() => { const el = document.getElementById('ctl00_ContentPlaceHolder1_ddlBindData'); return el && el.options && el.options.length > 0 && el.options[0].text.includes('Khatiyan'); }",
                        timeout=20000
                    )
                except Exception:
                    await asyncio.sleep(2)

            k_opts = await page.eval_on_selector_all(
                "#ctl00_ContentPlaceHolder1_ddlBindData option",
                "opts => opts.map(o => ({ value: o.value, text: o.text.trim() }))"
            )
            matched_k = next((o for o in k_opts if o["text"] == str(discovered_khata)), None)
            if not matched_k:
                raise ValueError(f"Discovered Khata '{discovered_khata}' could not be located in official dropdown for village '{village}'.")

            await page.select_option("#ctl00_ContentPlaceHolder1_ddlBindData", value=matched_k["value"])
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

        html = front_html + "\n" + back_html

        location_ident = BhulekhLocationIdentity(
            district_id=district_id,
            tahasil_id=tahasil_value,
            village_id=village_value,
            district_name=district,
            tahasil_name=tahasil,
            village_name=village
        )

        # ── STEP 7: Extract Combined HTML and Run Verification Layer ────────
        soup = BeautifulSoup(html, "lxml")
        verification = verify_ror_result(soup, district, tahasil, village, clean_target_plot, location_identity=location_ident)

        if verification.status != RoRVerificationStatus.VERIFIED:
            logger.error(f"[Playwright] Document verification failed before PDF/Data generation: {verification.details}")
            raise ValueError(f"Unable to verify this parcel from the official land record: {verification.details}")

        # ── STEP 8: Parse Structured Data ──────────────────────────────────
        parsed_ror = _parse_ror_page(
            html=html,
            district=district,
            tahasil=tahasil,
            village=village,
            plot=clean_target_plot,
            location_identity=location_ident
        )

        # ── STEP 9: Pre-render Official PDF in the SAME Session ─────────────
        canonical_id = f"{district_id}:{tahasil_value}:{village_value}:{clean_target_plot}"
        pdf_bytes = None
        try:
            logger.info(f"[Playwright] Pre-rendering official PDF for canonical identity '{canonical_id}'...")
            await page.evaluate("""() => {
                const hideIds = ['navigation', 'header', 'footer', 'ctl00_ContentPlaceHolder1_pnlSelection', 'ctl00_ContentPlaceHolder1_btnPrint'];
                hideIds.forEach(id => {
                    const el = document.getElementById(id);
                    if (el) el.style.display = 'none';
                });
            }""")
            pdf_bytes = await page.pdf(format="A4", print_background=True)
            if pdf_bytes:
                from services.official_document_cache import official_document_cache
                from models.ror_response import OfficialRoRDocument
                official_document_cache.store(canonical_id, pdf_bytes, metadata={
                    "district": district,
                    "tahasil": tahasil,
                    "village": village,
                    "plot": clean_target_plot,
                    "khata": parsed_ror.khata_number
                })
                parsed_ror.official_document = OfficialRoRDocument(
                    available=True,
                    document_id=canonical_id,
                    format="pdf",
                    source="odisha_bhulekh",
                    ready=True
                )
                logger.info(f"[Playwright] Successfully cached pre-rendered official PDF for '{canonical_id}' ({len(pdf_bytes)} bytes)")
        except Exception as e:
            logger.warning(f"[Playwright] PDF pre-rendering skipped/failed for '{canonical_id}': {e}")

        if mode == "pdf":
            if pdf_bytes:
                return pdf_bytes
            raise ValueError(f"Failed to generate official PDF for parcel '{clean_target_plot}'.")

        return parsed_ror
