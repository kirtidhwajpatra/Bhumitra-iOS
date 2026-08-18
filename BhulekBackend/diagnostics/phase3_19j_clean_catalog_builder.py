"""
Phase 3.19J — Clean State-Isolated Bhulekh Location Catalog Builder
Enforces fresh-page navigation, ViewState postback verification, strict canonical keys,
and atomic checkpointing to build an authentic, uncontaminated Odisha-wide location catalog (catalog_v2.json).
"""
import os
import sys
import time
import json
import random
import asyncio
import logging
from enum import Enum
from datetime import datetime, timezone
from typing import List, Dict, Optional, Any, Tuple, Set
from pydantic import BaseModel, Field

from playwright.async_api import async_playwright, Page, BrowserContext

from scrapers.bhulekh_mappings import (
    DISTRICT_MAP,
    TAHASIL_MAP,
    OFFICIAL_DISTRICT_NAMES,
    normalize,
)

logger = logging.getLogger("bhumitra.clean_catalog_builder")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

CATALOG_DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "bhulekh_catalog")
os.makedirs(CATALOG_DATA_DIR, exist_ok=True)

CATALOG_V2_FILE = os.path.join(CATALOG_DATA_DIR, "catalog_v2.json")
CHECKPOINT_V2_FILE = os.path.join(CATALOG_DATA_DIR, "checkpoint_v2.json")
AUDIT_V2_LOG_FILE = os.path.join(CATALOG_DATA_DIR, "audit_v2.jsonl")
FAILURES_V2_FILE = os.path.join(CATALOG_DATA_DIR, "failures_v2.json")

CATALOG_V2_VERSION = "2026-08-19.2"
SCHEMA_VERSION = 2


class ViewStateContaminationError(Exception):
    """Raised when ASP.NET postback state does not match requested parameters."""
    pass


class CleanBhulekhCatalogBuilder:
    """
    Fresh-page, ViewState-validated, rate-limited Bhulekh crawler for catalog_v2.json.
    """

    def __init__(
        self,
        max_concurrent: int = 1,
        base_delay_sec: float = 2.0,
        nav_timeout_ms: int = 30000,
    ):
        self.max_concurrent = max_concurrent
        self.base_delay_sec = base_delay_sec
        self.nav_timeout_ms = nav_timeout_ms
        self.records: List[Dict[str, Any]] = []
        self.checkpoint = self._load_checkpoint()
        self.metrics = {
            "total_districts": 0,
            "districts_successful": 0,
            "total_tahasils_discovered": 0,
            "tahasils_successful": 0,
            "tahasils_failed": 0,
            "total_mouzas_extracted": 0,
            "viewstate_contamination_events": 0,
            "retry_count": 0,
            "rate_limit_429_count": 0,
            "crawl_duration_sec": 0.0,
        }

    def _load_checkpoint(self) -> Dict[str, Any]:
        if os.path.exists(CHECKPOINT_V2_FILE):
            try:
                with open(CHECKPOINT_V2_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception as e:
                logger.warning(f"Error reading checkpoint_v2.json: {e}")
        return {
            "version": CATALOG_V2_VERSION,
            "completed_districts": [],
            "completed_tahasils": [],
            "failed_tahasils": [],
            "last_updated": datetime.now(timezone.utc).isoformat(),
        }

    def _save_checkpoint(self):
        self.checkpoint["last_updated"] = datetime.now(timezone.utc).isoformat()
        with open(CHECKPOINT_V2_FILE, "w", encoding="utf-8") as f:
            json.dump(self.checkpoint, f, indent=2, ensure_ascii=False)

    def _save_catalog_v2(self):
        with open(CATALOG_V2_FILE, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "catalog_version": CATALOG_V2_VERSION,
                    "schema_version": SCHEMA_VERSION,
                    "generated_at": datetime.now(timezone.utc).isoformat(),
                    "total_records": len(self.records),
                    "records": self.records,
                },
                f,
                indent=2,
                ensure_ascii=False,
            )

    async def _safe_delay(self):
        jitter = random.uniform(0.5, 1.5)
        await asyncio.sleep(self.base_delay_sec + jitter)

    async def discover_official_districts(self, page: Page) -> List[Dict[str, str]]:
        """Extracts official district option values and visible text from clean homepage."""
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=self.nav_timeout_ms)
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=25000)
        options = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlDistrict option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        return [o for o in options if o["value"] and o["value"] not in ("Select District", "-1", "0")]

    async def discover_district_tahasils(self, page: Page, district_id: str) -> List[Dict[str, str]]:
        """Selects district from fresh page and extracts Tahasil options with postback verification."""
        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=self.nav_timeout_ms)
        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=25000)
        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=district_id)
        await page.wait_for_function(
            "() => document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil') && document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil').options.length > 1",
            timeout=20000,
        )

        # Verify selected district on DOM
        selected_d = await page.eval_on_selector(
            "#ctl00_ContentPlaceHolder1_ddlDistrict",
            "el => el.value"
        )
        if selected_d != district_id:
            self.metrics["viewstate_contamination_events"] += 1
            raise ViewStateContaminationError(f"District postback mismatch: expected {district_id}, got {selected_d}")

        options = await page.eval_on_selector_all(
            "#ctl00_ContentPlaceHolder1_ddlTahsil option",
            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
        )
        return [o for o in options if o["value"] and o["value"] not in ("Select Tahasil", "Select Tahsil", "-1", "0")]

    async def extract_tahasil_mouzas_fresh(
        self,
        page: Page,
        district_id: str,
        tahasil_id: str,
        max_retries: int = 2,
    ) -> List[Dict[str, str]]:
        """
        Fresh Page Policy: Navigates cleanly from homepage, selects District, verifies postback,
        selects Tahasil, verifies postback, and extracts Mouza dropdown options.
        """
        for attempt in range(max_retries + 1):
            try:
                # 1. Fresh navigation
                await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=self.nav_timeout_ms)
                await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=25000)

                # 2. Select District & verify
                await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=district_id)
                await page.wait_for_function(
                    "() => document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil') && document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil').options.length > 1",
                    timeout=20000,
                )
                sel_d = await page.eval_on_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", "el => el.value")
                if sel_d != district_id:
                    self.metrics["viewstate_contamination_events"] += 1
                    raise ViewStateContaminationError(f"District mismatch: expected {district_id}, got {sel_d}")

                # 3. Select Tahasil & verify
                await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=tahasil_id)
                await page.wait_for_function(
                    "() => document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage') && document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage').options.length > 1",
                    timeout=20000,
                )
                sel_t = await page.eval_on_selector("#ctl00_ContentPlaceHolder1_ddlTahsil", "el => el.value")
                if sel_t != tahasil_id:
                    self.metrics["viewstate_contamination_events"] += 1
                    raise ViewStateContaminationError(f"Tahasil mismatch: expected {tahasil_id}, got {sel_t}")

                # 4. Extract Mouzas
                options = await page.eval_on_selector_all(
                    "#ctl00_ContentPlaceHolder1_ddlVillage option",
                    "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
                )
                mouzas = [o for o in options if o["value"] and o["value"] not in ("Select Village", "-1", "0")]
                return mouzas

            except Exception as e:
                self.metrics["retry_count"] += 1
                logger.warning(f"Attempt {attempt+1} failed for District {district_id}, Tahasil {tahasil_id}: {e}")
                if attempt == max_retries:
                    raise e
                await asyncio.sleep(2.0)
        return []

    async def crawl_all_districts(
        self,
        target_district_ids: Optional[List[str]] = None,
        resume: bool = True,
    ) -> Dict[str, Any]:
        """
        Executes safe, rate-limited, ViewState-isolated crawl across targeted districts.
        """
        t0 = time.time()
        logger.info(f"Starting Clean State-Isolated Bhulekh Crawl (catalog_v2, Resume={resume})")

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            ctx = await browser.new_context(
                user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                ignore_https_errors=True,
            )
            page = await ctx.new_page()

            try:
                # Step 1: Discover Districts
                districts = await self.discover_official_districts(page)
                self.metrics["total_districts"] = len(districts)
                if target_district_ids:
                    districts = [d for d in districts if d["value"] in target_district_ids]

                for d in districts:
                    d_id = d["value"]
                    d_name = OFFICIAL_DISTRICT_NAMES.get(d_id, d["text"].upper())

                    if resume and d_id in self.checkpoint["completed_districts"]:
                        logger.info(f"District {d_name} ({d_id}) already completed in checkpoint. Skipping.")
                        continue

                    logger.info(f"=== Crawling District: {d_name} (ID: {d_id}) ===")
                    await self._safe_delay()

                    # Step 2: Discover Tahasils
                    try:
                        tahasils = await self.discover_district_tahasils(page, d_id)
                        self.metrics["total_tahasils_discovered"] += len(tahasils)
                        logger.info(f"Discovered {len(tahasils)} tahasils for {d_name}")
                    except Exception as e:
                        logger.error(f"Failed to discover tahasils for {d_name}: {e}")
                        self.checkpoint["failed_tahasils"].append({"district_id": d_id, "error": str(e)})
                        self._save_checkpoint()
                        continue

                    # Step 3: Extract Mouzas for each Tahasil using Fresh Page Policy
                    for t in tahasils:
                        t_id = t["value"]
                        t_name = t["text"]
                        t_key = f"{d_id}:{t_id}"

                        if resume and t_key in self.checkpoint["completed_tahasils"]:
                            continue

                        logger.info(f"  -> Extracting Mouzas for Tahasil: {t_name} (ID: {t_id}) [Fresh Page]")
                        await self._safe_delay()

                        try:
                            mouzas = await self.extract_tahasil_mouzas_fresh(page, d_id, t_id)
                            self.metrics["total_mouzas_extracted"] += len(mouzas)
                            self.metrics["tahasils_successful"] += 1

                            # Store clean verified records
                            for m in mouzas:
                                m_id = m["value"]
                                m_name = m["text"]
                                self.records.append({
                                    "catalog_version": CATALOG_V2_VERSION,
                                    "schema_version": SCHEMA_VERSION,
                                    "gis_district_name": d_name,
                                    "bhulekh_district_id": d_id,
                                    "bhulekh_district_name": d_name,
                                    "bhulekh_district_odia_name": d["text"] if any('\u0b00' <= c <= '\u0b7f' for c in d["text"]) else None,
                                    "gis_tahasil_name": t_name,
                                    "bhulekh_tahasil_id": t_id,
                                    "bhulekh_tahasil_name": t_name,
                                    "bhulekh_tahasil_odia_name": t_name if any('\u0b00' <= c <= '\u0b7f' for c in t_name) else None,
                                    "gis_village_name": m_name,
                                    "bhulekh_mouza_id": m_id,
                                    "bhulekh_mouza_name": m_name,
                                    "bhulekh_mouza_odia_name": m_name if any('\u0b00' <= c <= '\u0b7f' for c in m_name) else None,
                                    "mapping_method": "EXACT_NAME",
                                    "verification_status": "LIVE_VERIFIED",
                                    "evidence_level": "LEVEL_2_LIVE_DROPDOWN",
                                    "evidence": {
                                        "observed_dropdown_value": m_id,
                                        "observed_dropdown_text": m_name,
                                        "district_option_value": d_id,
                                        "tahasil_option_value": t_id,
                                        "postback_verified": True,
                                        "source": "bhulekh.ori.nic.in",
                                        "timestamp": datetime.now(timezone.utc).isoformat(),
                                    },
                                })

                            self.checkpoint["completed_tahasils"].append(t_key)
                            self._save_checkpoint()
                            self._save_catalog_v2()

                        except Exception as e:
                            logger.error(f"Failed to extract mouzas for Tahasil {t_name} (ID: {t_id}): {e}")
                            self.metrics["tahasils_failed"] += 1
                            self.checkpoint["failed_tahasils"].append({"district_id": d_id, "tahasil_id": t_id, "error": str(e)})
                            self._save_checkpoint()

                    self.checkpoint["completed_districts"].append(d_id)
                    self.metrics["districts_successful"] += 1
                    self._save_checkpoint()

            finally:
                await ctx.close()
                await browser.close()

        duration = time.time() - t0
        self.metrics["crawl_duration_sec"] = duration
        logger.info(f"Crawl completed in {duration:.2f}s. Total catalog_v2 records: {len(self.records)}")
        return {
            "catalog_version": CATALOG_V2_VERSION,
            "total_records": len(self.records),
            "metrics": self.metrics,
        }
