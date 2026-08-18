"""
RoR Service Layer with Concurrency Control, Request Coalescing, & Verified Cache
Core business logic for fetching, parsing, validating, and caching Bhulekh RoR data stably.
"""
import logging
import hashlib
import asyncio
import time
from cachetools import TTLCache
from typing import List, Dict, Optional, Any
from models.ror_response import RoRResponse, RoRVerificationStatus
from scrapers.bhulekh_scraper import BhulekhScraper
from scrapers.bhulekh_mappings import get_district_id, get_tahasil_id

logger = logging.getLogger("bhumitra.scraper")

# Cache: max 2000 verified entries, TTL = 24 hours (86400 seconds)
_cache: TTLCache = TTLCache(maxsize=2000, ttl=86400)
_pdf_cache: TTLCache = TTLCache(maxsize=500, ttl=86400)

# Concurrency limits to prevent resource exhaustion
MAX_CONCURRENT_SCRAPES = 5
MAX_CONCURRENT_PDFS = 3
_scrape_semaphore = asyncio.Semaphore(MAX_CONCURRENT_SCRAPES)
_pdf_semaphore = asyncio.Semaphore(MAX_CONCURRENT_PDFS)

# In-flight request coalescing (SingleFlight pattern)
_inflight_scrapes: Dict[str, asyncio.Future] = {}
_inflight_lock = asyncio.Lock()


def get_canonical_cache_key(
    district: str,
    tahasil: str,
    village: str,
    plot: str,
    v_id: str | None = None
) -> str:
    """
    Computes a collision-resistant canonical cache key distinguishing identical plot numbers across mouzas.
    """
    d_id = get_district_id(district.strip().upper()) or district.strip().upper()
    t_id = get_tahasil_id(d_id, tahasil.strip().upper()) if d_id else tahasil.strip().upper()
    raw = f"ror:{d_id}:{t_id}:{village.strip().upper()}:{plot.strip()}:{v_id or ''}"
    return hashlib.sha256(raw.encode()).hexdigest()


class RoRService:
    def __init__(self):
        self.metrics = {
            "total_requests": 0,
            "cache_hits": 0,
            "coalesced_requests": 0,
            "successful_scrapes": 0,
            "failed_scrapes": 0,
            "parser_errors": 0,
            "verification_mismatches": 0,
            "pdf_generations": 0,
            "pdf_failures": 0,
            "total_latency_ms": 0,
        }

    def _validate_ror_response(self, ror: RoRResponse, plot: str, village: str):
        """
        Validates parsed Record of Rights data to detect Bhulekh structural changes or empty responses.
        """
        if not ror.owners or len(ror.owners) == 0:
            # Check if it was official government land with landlord recorded
            if not (ror.raw_fields and "landlord" in ror.raw_fields):
                self.metrics["parser_errors"] += 1
                logger.error(f"SCRAPER_PARSER_ERROR: No owners parsed from portal for plot={plot}, village={village}")
                raise ValueError("No ownership records could be parsed from the portal.")

        for owner in ror.owners:
            if not owner.name or not owner.name.strip():
                self.metrics["parser_errors"] += 1
                logger.error(f"SCRAPER_PARSER_ERROR: Empty owner name parsed for plot={plot}, village={village}")
                raise ValueError("Malformed owner record detected from portal.")

    async def get_ror(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,
    ) -> RoRResponse:
        start_time = time.time()
        self.metrics["total_requests"] += 1
        key = get_canonical_cache_key(district, tahasil, village, plot, v_id)

        # 1. Serve from cache if available (ONLY verified entries are cached)
        if key in _cache:
            self.metrics["cache_hits"] += 1
            cached_res = _cache[key]
            # Return copy with cached=True flag
            res_dict = cached_res.model_dump()
            res_dict["cached"] = True
            logger.info(f"Cache HIT for canonical key={key[:12]}")
            return RoRResponse(**res_dict)

        # 2. In-flight Request Coalescing (SingleFlight)
        should_execute = False
        async with _inflight_lock:
            if key in _inflight_scrapes:
                self.metrics["coalesced_requests"] += 1
                logger.info(f"Coalescing request onto active in-flight scrape for key={key[:12]}")
                future = _inflight_scrapes[key]
            else:
                loop = asyncio.get_running_loop()
                future = loop.create_future()
                _inflight_scrapes[key] = future
                should_execute = True

        if not should_execute:
            # Await the shared in-flight task
            return await future

        # 3. Execute Scrape with Concurrency Throttling & Deterministic Retries
        scraper = BhulekhScraper()
        max_retries = 2
        last_error: Optional[Exception] = None

        try:
            async with _scrape_semaphore:
                for attempt in range(max_retries + 1):
                    try:
                        logger.info(f"Scraping Bhulekh (attempt {attempt + 1}) for plot={plot}, village={village}")
                        result = await scraper.fetch_ror(
                            district=district, tahasil=tahasil, village=village,
                            plot=plot, b_id=b_id, v_id=v_id,
                        )
                        self._validate_ror_response(result, plot, village)

                        # ONLY Cache if VERIFIED
                        if result.verification and result.verification.status == RoRVerificationStatus.VERIFIED:
                            _cache[key] = result

                        self.metrics["successful_scrapes"] += 1
                        future.set_result(result)
                        return result
                    except ValueError as e:
                        # Validation/Mismatch errors are permanent and fail-closed: DO NOT RETRY
                        if "mismatch" in str(e).lower() or "unable to verify" in str(e).lower():
                            self.metrics["verification_mismatches"] += 1
                        self.metrics["failed_scrapes"] += 1
                        future.set_exception(e)
                        raise e
                    except Exception as e:
                        last_error = e
                        if attempt < max_retries:
                            logger.warning(f"Transient scraper error (attempt {attempt + 1}): {e}. Retrying in 1.5s...")
                            await asyncio.sleep(1.5 * (attempt + 1))
                        else:
                            self.metrics["failed_scrapes"] += 1
                            conn_err = ConnectionError(f"Temporary issue accessing portal: {str(e)}")
                            future.set_exception(conn_err)
                            raise conn_err

        finally:
            elapsed_ms = int((time.time() - start_time) * 1000)
            self.metrics["total_latency_ms"] += elapsed_ms
            async with _inflight_lock:
                _inflight_scrapes.pop(key, None)

    async def get_ror_pdf(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,
    ) -> bytes:
        self.metrics["pdf_generations"] += 1
        key = f"pdf:{get_canonical_cache_key(district, tahasil, village, plot, v_id)}"
        
        # Check verified PDF cache
        if key in _pdf_cache:
            logger.info(f"PDF Cache HIT for canonical key={key[:16]}")
            return _pdf_cache[key]

        scraper = BhulekhScraper()
        try:
            async with _pdf_semaphore:
                pdf_bytes = await scraper.download_ror_pdf(
                    district=district,
                    tahasil=tahasil,
                    village=village,
                    plot=plot,
                    b_id=b_id,
                    v_id=v_id,
                )
                if pdf_bytes and len(pdf_bytes) > 10:
                    _pdf_cache[key] = pdf_bytes
                return pdf_bytes
        except Exception as e:
            self.metrics["pdf_failures"] += 1
            raise e

    def get_health_metrics(self) -> Dict[str, Any]:
        total_req = max(1, self.metrics["total_requests"])
        return {
            "status": "healthy",
            "active_inflight_scrapes": len(_inflight_scrapes),
            "cached_verified_records": len(_cache),
            "cache_hit_rate_pct": round((self.metrics["cache_hits"] / total_req) * 100.0, 1),
            "coalesced_rate_pct": round((self.metrics["coalesced_requests"] / total_req) * 100.0, 1),
            "successful_scrapes": self.metrics["successful_scrapes"],
            "failed_scrapes": self.metrics["failed_scrapes"],
            "verification_mismatches": self.metrics["verification_mismatches"],
            "pdf_generations": self.metrics["pdf_generations"],
            "pdf_failures": self.metrics["pdf_failures"],
            "avg_latency_ms": round(self.metrics["total_latency_ms"] / total_req, 1),
        }

    async def list_districts(self) -> List[BhulekhDistrict]:
        from scrapers.bhulekh_mappings import get_all_districts
        return get_all_districts()

    async def list_tahasils(self, district_id: str) -> List[BhulekhTahasil]:
        from scrapers.bhulekh_mappings import get_tahasils_for_district
        return get_tahasils_for_district(district_id)

    async def list_villages(self, district_id: str, tahasil_id: str) -> List[BhulekhVillage]:
        from scrapers.bhulekh_mappings import get_villages_for_tahasil
        return get_villages_for_tahasil(district_id, tahasil_id)

    async def list_ri_circles(self, district_id: str, tahasil_id: str) -> List[BhulekhRICircle]:
        from scrapers.bhulekh_mappings import get_ri_circles_for_tahasil
        return get_ri_circles_for_tahasil(district_id, tahasil_id)

