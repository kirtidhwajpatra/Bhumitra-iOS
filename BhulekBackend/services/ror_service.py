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
from models.ror_response import (
    RoRResponse,
    RoRVerificationStatus,
    RoRErrorCode,
    RoRErrorDetail,
    BhulekhDistrict,
    BhulekhTahasil,
    BhulekhVillage,
    BhulekhRICircle,
)
from scrapers.bhulekh_scraper import BhulekhScraper
from scrapers.bhulekh_mappings import get_district_id, get_tahasil_id
from resolvers.plot_normalizer import normalize_plot_number

logger = logging.getLogger("bhumitra.scraper")


class RoRServiceException(Exception):
    def __init__(self, code: RoRErrorCode, message: str, retryable: bool = False, details: Optional[str] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable
        self.details = details


from core.config import settings

# Cache: max 2000 verified entries, TTL = 24 hours (86400 seconds)
_cache: TTLCache = TTLCache(maxsize=2000, ttl=86400)
_pdf_cache: TTLCache = TTLCache(maxsize=500, ttl=86400)
# Negative Cache: max 1000 entries for confirmed NOT_FOUND, TTL = 5 minutes (300 seconds)
_negative_cache: TTLCache = TTLCache(maxsize=1000, ttl=300)

# Dynamic Bounded Concurrency Semaphores
_scrape_semaphore = asyncio.Semaphore(settings.BHULEKH_MAX_CONCURRENT)
_pdf_semaphore = asyncio.Semaphore(settings.BHULEKH_MAX_CONCURRENT)

# In-flight request queue tracking
_pending_ror_count = 0
_pending_pdf_count = 0

# In-flight request coalescing (SingleFlight pattern)
_inflight_scrapes: Dict[str, asyncio.Future] = {}
_inflight_pdf_scrapes: Dict[str, asyncio.Future] = {}
_inflight_lock = asyncio.Lock()


def get_canonical_cache_key(
    district: str,
    tahasil: str,
    village: str,
    plot: str,
    b_id: str | None = None,
    v_id: str | None = None,
) -> str:
    """
    Computes a collision-resistant canonical cache key uniquely binding district, tahasil, village/mouza, and exact plot.
    """
    d_id = get_district_id(district.strip().upper()) or district.strip().upper()
    t_id = get_tahasil_id(d_id, tahasil.strip().upper()) if d_id else tahasil.strip().upper()
    norm_p = normalize_plot_number(plot)
    raw = f"ror:{d_id}:{t_id}:{b_id or ''}:{village.strip().upper()}:{v_id or ''}:{norm_p}"
    return hashlib.sha256(raw.encode()).hexdigest()


class RoRService:
    def __init__(self):
        self.metrics = {
            "total_requests": 0,
            "cache_hits": 0,
            "negative_cache_hits": 0,
            "coalesced_requests": 0,
            "successful_scrapes": 0,
            "failed_scrapes": 0,
            "parser_errors": 0,
            "verification_mismatches": 0,
            "pdf_generations": 0,
            "pdf_failures": 0,
            "queue_rejections": 0,
            "total_latency_ms": 0,
        }

    def _validate_ror_response(self, ror: RoRResponse, plot: str, village: str):
        """
        Validates parsed Record of Rights data to detect Bhulekh structural changes or empty responses.
        """
        if not ror.owners or len(ror.owners) == 0:
            from scrapers.structured_ror_parser import is_statutory_government_classification
            tenure_val = ror.raw_fields.get("tenure") if ror.raw_fields else None
            is_govt = is_statutory_government_classification(ror.land_type, tenure_val)
            if not is_govt:
                self.metrics["parser_errors"] += 1
                logger.error(f"SCRAPER_PARSER_ERROR: Empty owner list parsed for private plot={plot}, village={village}")
                raise RoRServiceException(
                    code=RoRErrorCode.BHULEKH_PARSE_FAILED,
                    message="Malformed owner record detected from portal.",
                    retryable=False,
                )

        for owner in ror.owners:
            if not owner.name or not owner.name.strip():
                self.metrics["parser_errors"] += 1
                logger.error(f"SCRAPER_PARSER_ERROR: Empty owner name parsed for plot={plot}, village={village}")
                raise RoRServiceException(
                    code=RoRErrorCode.BHULEKH_PARSE_FAILED,
                    message="Malformed owner record detected from portal.",
                    retryable=False,
                )

    async def get_ror(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,
        request_id: Optional[str] = None,
    ) -> RoRResponse:
        start_time = time.time()
        self.metrics["total_requests"] += 1
        req_tag = f"[{request_id[:8]}]" if request_id else ""
        key = get_canonical_cache_key(district, tahasil, village, plot, b_id, v_id)

        # 1. Serve from cache if available (ONLY verified entries are cached)
        if key in _cache:
            self.metrics["cache_hits"] += 1
            cached_res = _cache[key]
            res_dict = cached_res.model_dump()
            res_dict["cached"] = True
            logger.info(f"{req_tag} Cache HIT for canonical key={key[:12]}")
            return RoRResponse(**res_dict)

        # 1b. Serve from negative cache if recently confirmed not found
        if key in _negative_cache:
            self.metrics["negative_cache_hits"] += 1
            neg_err = _negative_cache[key]
            logger.info(f"{req_tag} Negative Cache HIT for key={key[:12]}")
            raise neg_err

        # 2. In-flight Request Coalescing (SingleFlight) & Queue Bounding
        global _pending_ror_count, _pending_pdf_count
        should_execute = False
        async with _inflight_lock:
            if key in _inflight_scrapes:
                self.metrics["coalesced_requests"] += 1
                logger.info(f"{req_tag} Coalescing duplicate request onto in-flight scrape for key={key[:12]}")
                future = _inflight_scrapes[key]
            else:
                if _pending_ror_count >= settings.MAX_PENDING_BHULEKH_REQUESTS:
                    self.metrics["queue_rejections"] += 1
                    logger.warning(f"{req_tag} Rejecting request: in-flight queue full ({_pending_ror_count}/{settings.MAX_PENDING_BHULEKH_REQUESTS})")
                    raise RoRServiceException(
                        code=RoRErrorCode.BHULEKH_RATE_LIMITED,
                        message="Official land records service is currently busy. Please try again shortly.",
                        retryable=True,
                        details="Maximum pending scrape queue capacity reached.",
                    )
                _pending_ror_count += 1
                loop = asyncio.get_running_loop()
                future = loop.create_future()
                _inflight_scrapes[key] = future
                should_execute = True

        if not should_execute:
            return await future

        # 3. Execute Scrape with Concurrency Throttling & Exponential Backoff Retries
        scraper = BhulekhScraper()
        retry_delays = [0.0, 0.5, 1.5]
        max_attempts = len(retry_delays)

        try:
            async with _scrape_semaphore:
                for attempt_idx, delay in enumerate(retry_delays, 1):
                    if delay > 0:
                        logger.info(f"{req_tag} Retrying Bhulekh scrape in {delay}s (attempt {attempt_idx}/{max_attempts})...")
                        await asyncio.sleep(delay)

                    try:
                        logger.info(f"{req_tag} Scraping Bhulekh (attempt {attempt_idx}/{max_attempts}) for plot={plot}, village={village}")
                        result = await asyncio.wait_for(
                            scraper.fetch_ror(
                                district=district, tahasil=tahasil, village=village,
                                plot=plot, b_id=b_id, v_id=v_id,
                            ),
                            timeout=settings.ROR_TIMEOUT_SECONDS,
                        )
                        self._validate_ror_response(result, plot, village)

                        # ONLY Cache if VERIFIED
                        if result.verification and result.verification.status == RoRVerificationStatus.VERIFIED:
                            _cache[key] = result

                        self.metrics["successful_scrapes"] += 1
                        future.set_result(result)
                        return result

                    except ValueError as e:
                        # Deterministic validation or not found error - DO NOT RETRY
                        msg = str(e)
                        if "not found" in msg.lower() or "could not be verified" in msg.lower():
                            err = RoRServiceException(
                                code=RoRErrorCode.ROR_NOT_FOUND,
                                message=f"No official RoR record found for plot '{plot}' in village '{village}'.",
                                retryable=False,
                                details=msg,
                            )
                            _negative_cache[key] = err
                        elif "mismatch" in msg.lower():
                            self.metrics["verification_mismatches"] += 1
                            err = RoRServiceException(
                                code=RoRErrorCode.ROR_IDENTITY_MISMATCH,
                                message="Official land record could not be verified as the exact same parcel.",
                                retryable=False,
                                details=msg,
                            )
                            _negative_cache[key] = err
                        else:
                            self.metrics["parser_errors"] += 1
                            err = RoRServiceException(
                                code=RoRErrorCode.BHULEKH_PARSE_FAILED,
                                message="Unable to parse official land record from portal response.",
                                retryable=False,
                                details=msg,
                            )
                        self.metrics["failed_scrapes"] += 1
                        future.set_exception(err)
                        raise err

                    except RoRServiceException as e:
                        self.metrics["failed_scrapes"] += 1
                        future.set_exception(e)
                        raise e

                    except Exception as e:
                        msg = str(e)
                        is_timeout = isinstance(e, asyncio.TimeoutError) or "timeout" in msg.lower() or "timed out" in msg.lower()
                        if attempt_idx < max_attempts:
                            logger.warning(f"{req_tag} Transient scrape error (attempt {attempt_idx}): {e}")
                            continue
                        
                        self.metrics["failed_scrapes"] += 1
                        code = RoRErrorCode.BHULEKH_TIMEOUT if is_timeout else RoRErrorCode.BHULEKH_TEMPORARY_UNAVAILABLE
                        err_msg = (
                            "Official RoR service timed out. Please try again."
                            if is_timeout
                            else "Official RoR service is temporarily unavailable. Please try again."
                        )
                        err = RoRServiceException(
                            code=code,
                            message=err_msg,
                            retryable=True,
                            details=msg,
                        )
                        future.set_exception(err)
                        raise err

        finally:
            elapsed_ms = int((time.time() - start_time) * 1000)
            self.metrics["total_latency_ms"] += elapsed_ms
            async with _inflight_lock:
                _pending_ror_count = max(0, _pending_ror_count - 1)
                _inflight_scrapes.pop(key, None)

    async def get_ror_pdf(
        self,
        district: str,
        tahasil: str,
        village: str,
        plot: str,
        b_id: str | None = None,
        v_id: str | None = None,
        request_id: Optional[str] = None,
    ) -> bytes:
        global _pending_pdf_count
        self.metrics["pdf_generations"] += 1
        req_tag = f"[{request_id[:8]}]" if request_id else ""
        key = f"pdf:{get_canonical_cache_key(district, tahasil, village, plot, v_id)}"
        
        # Check verified PDF cache
        if key in _pdf_cache:
            logger.info(f"{req_tag} PDF Cache HIT for canonical key={key[:16]}")
            return _pdf_cache[key]

        # 2. SingleFlight Coalescing
        async with _inflight_lock:
            if key in _inflight_pdf_scrapes:
                logger.info(f"{req_tag} SingleFlight COALESCE for in-flight PDF key={key[:16]}")
                future = _inflight_pdf_scrapes[key]
                return await asyncio.shield(future)

            if _pending_pdf_count >= settings.MAX_PENDING_BHULEKH_REQUESTS:
                self.metrics["queue_rejections"] += 1
                logger.warning(f"{req_tag} Rejecting PDF request: queue full ({_pending_pdf_count}/{settings.MAX_PENDING_BHULEKH_REQUESTS})")
                raise RoRServiceException(
                    code=RoRErrorCode.BHULEKH_RATE_LIMITED,
                    message="Official document generator is currently busy. Please try again shortly.",
                    retryable=True,
                    details="Maximum pending PDF queue capacity reached.",
                )
            _pending_pdf_count += 1
            loop = asyncio.get_running_loop()
            future = loop.create_future()
            _inflight_pdf_scrapes[key] = future

        scraper = BhulekhScraper()
        pdf_retry_delays = [0.0, 0.5]

        try:
            for attempt_idx, delay in enumerate(pdf_retry_delays, 1):
                if delay > 0:
                    await asyncio.sleep(delay)
                try:
                    async with _pdf_semaphore:
                        logger.info(f"{req_tag} Generating RoR PDF (attempt {attempt_idx}) for plot={plot}, village={village}")
                        pdf_bytes = await asyncio.wait_for(
                            scraper.download_ror_pdf(
                                district=district,
                                tahasil=tahasil,
                                village=village,
                                plot=plot,
                                b_id=b_id,
                                v_id=v_id,
                            ),
                            timeout=settings.PDF_TIMEOUT_SECONDS,
                        )
                        if not pdf_bytes or len(pdf_bytes) < 10:
                            raise ValueError("Generated PDF bytes were empty or truncated.")
                        
                        if not pdf_bytes.startswith(b"%PDF-"):
                            # If upstream returned HTML error page or JSON error blob
                            if b"<html" in pdf_bytes.lower() or b"<!doctype" in pdf_bytes.lower():
                                raise ValueError("Upstream portal returned an HTML page instead of PDF document.")
                            elif pdf_bytes.strip().startswith(b"{"):
                                raise ValueError("Upstream portal returned an error JSON payload instead of PDF document.")
                            else:
                                raise ValueError("Generated file did not match valid PDF signature (%PDF-).")

                        if len(pdf_bytes) > settings.MAX_PDF_SIZE_BYTES:
                            raise ValueError(f"Generated PDF exceeded safe maximum size ({len(pdf_bytes)} > {settings.MAX_PDF_SIZE_BYTES})")

                        _pdf_cache[key] = pdf_bytes
                        future.set_result(pdf_bytes)
                        return pdf_bytes
                except Exception as e:
                    if attempt_idx < len(pdf_retry_delays):
                        logger.warning(f"{req_tag} Transient PDF generation failure: {e}")
                        continue
                    self.metrics["pdf_failures"] += 1
                    err = RoRServiceException(
                        code=RoRErrorCode.PDF_GENERATION_FAILED,
                        message="Official RoR record found, but the PDF document could not be generated.",
                        retryable=True,
                        details=str(e),
                    )
                    future.set_exception(err)
                    raise err
        finally:
            async with _inflight_lock:
                _pending_pdf_count = max(0, _pending_pdf_count - 1)
                _inflight_pdf_scrapes.pop(key, None)

    def get_health_metrics(self) -> Dict[str, Any]:
        total_req = max(1, self.metrics["total_requests"])
        active_workers = settings.BHULEKH_MAX_CONCURRENT - _scrape_semaphore._value
        return {
            "status": "healthy",
            "active_workers": max(0, active_workers),
            "max_workers": settings.BHULEKH_MAX_CONCURRENT,
            "pending_queue_depth": _pending_ror_count + _pending_pdf_count,
            "queue_rejections": self.metrics.get("queue_rejections", 0),
            "active_inflight_scrapes": len(_inflight_scrapes),
            "cached_verified_records": len(_cache),
            "cached_verified_pdfs": len(_pdf_cache),
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

