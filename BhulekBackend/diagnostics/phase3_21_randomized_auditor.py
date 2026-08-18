"""
Phase 3.21A — 30-District Randomized Live Audit Engine
Performs independent, un-cached live Playwright audits across all 30 districts (5 records per district = 150 sample checks)
to verify exact district, tahasil, mouza ID, and label match against http://bhulekh.ori.nic.in/.
"""
import os
import sys
import time
import json
import random
import asyncio
import logging
from typing import List, Dict, Any, Tuple

from playwright.async_api import async_playwright

from scrapers.bhulekh_mappings import OFFICIAL_DISTRICT_NAMES, normalize

logger = logging.getLogger("bhumitra.random_auditor")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

CATALOG_V3_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "data",
    "bhulekh_catalog",
    "catalog_v3.json",
)


class StateWideRandomizedAuditor:
    """Samples and audits 5 records per district across all 30 Odisha districts."""

    @classmethod
    def sample_all_districts(cls, records: List[Dict[str, Any]], per_district: int = 5, seed: int = 321) -> List[Dict[str, Any]]:
        rng = random.Random(seed)
        by_district: Dict[str, List[Dict[str, Any]]] = {}
        for r in records:
            did = str(r.get("bhulekh_district_id", "")).strip()
            by_district.setdefault(did, []).append(r)

        sample = []
        for did in sorted(by_district.keys(), key=lambda x: int(x) if x.isdigit() else 99):
            d_records = by_district[did]
            sampled = rng.sample(d_records, min(per_district, len(d_records)))
            sample.extend(sampled)
        return sample

    @classmethod
    async def perform_live_audit(cls, sample: List[Dict[str, Any]], max_checks: int = 150) -> Dict[str, Any]:
        results = []
        sample_subset = sample[:max_checks]
        total = len(sample_subset)
        logger.info(f"Starting 30-District Randomized Live Audit (N={total})")

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            ctx = await browser.new_context(
                user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                ignore_https_errors=True,
            )
            page = await ctx.new_page()

            try:
                for idx, r in enumerate(sample_subset, 1):
                    d_id = str(r.get("bhulekh_district_id", ""))
                    t_id = str(r.get("bhulekh_tahasil_id", ""))
                    m_id = str(r.get("bhulekh_mouza_id", ""))
                    m_name = r.get("bhulekh_mouza_name", "")
                    d_name = r.get("bhulekh_district_name", "")
                    t_name = r.get("bhulekh_tahasil_name", "")

                    logger.info(f"[{idx}/{total}] Auditing District {d_name} ({d_id}), Tahasil {t_name} ({t_id}), Mouza {m_name} ({m_id})...")

                    try:
                        # Fresh Page Navigation
                        await page.goto("http://bhulekh.ori.nic.in/", wait_until="domcontentloaded", timeout=25000)
                        await page.wait_for_selector("#ctl00_ContentPlaceHolder1_ddlDistrict", timeout=20000)

                        # Select District
                        await page.select_option("#ctl00_ContentPlaceHolder1_ddlDistrict", value=d_id)
                        await page.wait_for_function(
                            "() => document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil') && document.getElementById('ctl00_ContentPlaceHolder1_ddlTahsil').options.length > 1",
                            timeout=20000,
                        )

                        # Select Tahasil
                        await page.select_option("#ctl00_ContentPlaceHolder1_ddlTahsil", value=t_id)
                        await page.wait_for_function(
                            "() => document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage') && document.getElementById('ctl00_ContentPlaceHolder1_ddlVillage').options.length > 1",
                            timeout=20000,
                        )

                        # Extract Mouzas
                        opts = await page.eval_on_selector_all(
                            "#ctl00_ContentPlaceHolder1_ddlVillage option",
                            "opts => opts.map(o => ({value: o.value, text: o.textContent.trim()}))"
                        )
                        match = next((o for o in opts if o["value"] == m_id), None)

                        if match:
                            results.append({
                                "district_id": d_id,
                                "district_name": d_name,
                                "tahasil_id": t_id,
                                "mouza_id": m_id,
                                "mouza_name": m_name,
                                "live_mouza_text": match["text"],
                                "verified": True,
                                "comparison": "EXACT_MATCH" if normalize(match["text"]) == normalize(m_name) else "ID_MATCH_NAME_DIFF",
                            })
                        else:
                            results.append({
                                "district_id": d_id,
                                "district_name": d_name,
                                "tahasil_id": t_id,
                                "mouza_id": m_id,
                                "mouza_name": m_name,
                                "live_mouza_text": None,
                                "verified": False,
                                "comparison": "MOUZA_ID_NOT_FOUND",
                            })
                    except Exception as e:
                        results.append({
                            "district_id": d_id,
                            "district_name": d_name,
                            "tahasil_id": t_id,
                            "mouza_id": m_id,
                            "mouza_name": m_name,
                            "live_mouza_text": None,
                            "verified": False,
                            "comparison": f"ERROR: {e}",
                        })

                    await asyncio.sleep(0.3)

            finally:
                await ctx.close()
                await browser.close()

        verified_count = sum(1 for r in results if r["verified"])
        return {
            "total_sampled": total,
            "verified_count": verified_count,
            "pass_rate": round(verified_count / total, 4) if total > 0 else 0.0,
            "results": results,
        }
