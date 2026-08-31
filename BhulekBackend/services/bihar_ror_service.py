"""
Bihar RoR Service Layer with Complete Operational Isolation
Provides independent concurrency control, SingleFlight request coalescing,
namespaced caching (bihar:ror:*), and fail-closed feature flag gating.
"""

import logging
import hashlib
import asyncio
import time
from cachetools import TTLCache
from typing import Dict, Optional, Any

from models.ror_response import (
    RoRResponse,
    RoRErrorCode,
    RoRErrorDetail,
    RoRVerificationStatus,
)
from scrapers.bihar.bihar_jamabandi_parser import BiharJamabandiParser
from core.config import settings

logger = logging.getLogger("bhumitra.service.bihar")


class BiharRoRServiceException(Exception):
    def __init__(self, code: RoRErrorCode, message: str, retryable: bool = False, details: Optional[str] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable
        self.details = details


# Dedicated Isolated Bihar Caches (Zero cross-talk with Odisha cache)
# L1 Verified Cache: max 2000 entries, TTL = 24 hours (86400 seconds)
_bihar_cache: TTLCache = TTLCache(maxsize=2000, ttl=86400)
# L2 Negative Cache: max 1000 entries for confirmed NOT_FOUND, TTL = 5 minutes (300 seconds)
_bihar_negative_cache: TTLCache = TTLCache(maxsize=1000, ttl=300)

# Dedicated Dynamic Bounded Concurrency Semaphore
_bihar_semaphore = asyncio.Semaphore(settings.BIHAR_MAX_CONCURRENT)
_bihar_pending_count = 0

# In-flight request coalescing (SingleFlight pattern for Bihar)
_bihar_inflight_scrapes: Dict[str, asyncio.Future] = {}
_bihar_inflight_lock = asyncio.Lock()


def get_bihar_cache_key(
    district: str,
    anchal: str,
    village: str,
    plot: str,
    khata: Optional[str] = None,
) -> str:
    """
    Computes a collision-resistant canonical cache key strictly namespaced to Bihar.
    Format: bihar:ror:{district}:{anchal}:{village}:{khata}:{plot}
    """
    d_clean = district.strip().upper()
    a_clean = anchal.strip().upper()
    v_clean = village.strip().upper()
    p_clean = str(plot).strip()
    k_clean = str(khata or "").strip()
    
    raw = f"bihar:ror:{d_clean}:{a_clean}:{v_clean}:{k_clean}:{p_clean}"
    return hashlib.sha256(raw.encode()).hexdigest()


class BiharRoRService:
    """
    Isolated service manager for Bihar land record lookups.
    Encapsulates caching, rate control, and parser execution.
    """

    def __init__(self):
        self.metrics = {
            "total_requests": 0,
            "cache_hits": 0,
            "negative_cache_hits": 0,
            "coalesced_requests": 0,
            "successful_lookups": 0,
            "failed_lookups": 0,
            "parser_errors": 0,
            "queue_rejections": 0,
            "total_latency_ms": 0.0,
        }

    def clear_caches(self):
        """Flushes only the isolated Bihar caches."""
        _bihar_cache.clear()
        _bihar_negative_cache.clear()

    def get_metrics(self) -> Dict[str, Any]:
        return {
            **self.metrics,
            "cache_size": len(_bihar_cache),
            "negative_cache_size": len(_bihar_negative_cache),
            "active_inflight_count": len(_bihar_inflight_scrapes),
            "pending_queue_count": _bihar_pending_count,
            "provider_enabled": settings.BIHAR_PROVIDER_ENABLED,
        }

    async def get_ror(
        self,
        district: str,
        anchal: str,
        village: str,
        plot: str,
        khata: Optional[str] = None,
        request_id: str = "req-unknown",
        raw_html: Optional[str] = None,
        raw_payload: Optional[Dict[str, Any]] = None,
    ) -> RoRResponse:
        """
        Executes an isolated, cached, and single-flight coalesced Bihar RoR lookup.
        """
        t_start = time.perf_counter()
        self.metrics["total_requests"] += 1
        req_tag = request_id[:8] if request_id else "unknown"

        # 1. Strict Feature Flag Enforcement (Fail-Closed Default)
        if not settings.BIHAR_PROVIDER_ENABLED:
            logger.warning(f"[{req_tag}] Bihar provider lookup rejected: BIHAR_PROVIDER_ENABLED is False.")
            self.metrics["failed_lookups"] += 1
            raise BiharRoRServiceException(
                code=RoRErrorCode.BHULEKH_TEMPORARILY_UNAVAILABLE,
                message="Bihar land records provider is currently disabled by administrative feature flag.",
                retryable=False,
            )

        cache_key = get_bihar_cache_key(
            district=district,
            anchal=anchal,
            village=village,
            plot=plot,
            khata=khata,
        )

        # 2. Check L1 Verified TTLCache
        if cache_key in _bihar_cache:
            self.metrics["cache_hits"] += 1
            cached_res: RoRResponse = _bihar_cache[cache_key]
            logger.info(f"[{req_tag}] Bihar RoR Cache HIT for {district}/{anchal}/{village} plot={plot}")
            res_dict = cached_res.model_dump()
            res_dict["cached"] = True
            return RoRResponse(**res_dict)

        # 3. Check L2 Negative TTLCache
        if cache_key in _bihar_negative_cache:
            self.metrics["negative_cache_hits"] += 1
            logger.info(f"[{req_tag}] Bihar RoR Negative Cache HIT (NOT_FOUND) for plot={plot}")
            raise BiharRoRServiceException(
                code=RoRErrorCode.PLOT_NOT_FOUND,
                message="No land records found for the specified criteria in Bihar Jamabandi Register-II (Cached).",
                retryable=False,
            )

        # 4. SingleFlight Request Coalescing
        should_execute = False
        async with _bihar_inflight_lock:
            if cache_key in _bihar_inflight_scrapes:
                self.metrics["coalesced_requests"] += 1
                logger.info(f"[{req_tag}] Coalescing concurrent Bihar request into in-flight task: key={cache_key[:8]}")
                future = _bihar_inflight_scrapes[cache_key]
            else:
                loop = asyncio.get_running_loop()
                future = loop.create_future()
                _bihar_inflight_scrapes[cache_key] = future
                should_execute = True

        if not should_execute:
            try:
                coalesced_res = await asyncio.wait_for(asyncio.shield(future), timeout=settings.BIHAR_TIMEOUT_SECONDS)
                res_dict = coalesced_res.model_dump()
                res_dict["cached"] = True
                return RoRResponse(**res_dict)
            except Exception as e:
                if isinstance(e, BiharRoRServiceException):
                    raise e
                raise BiharRoRServiceException(
                    code=RoRErrorCode.BHULEKH_TIMEOUT,
                    message=f"Coalesced Bihar request failed: {str(e)}",
                    retryable=True,
                )

        # 5. Execute Protected Lookup with Bounded Concurrency
        global _bihar_pending_count
        if _bihar_pending_count >= settings.BIHAR_MAX_PENDING_REQUESTS:
            self.metrics["queue_rejections"] += 1
            err_msg = "Bihar lookup queue limit exceeded. Please retry shortly."
            err = BiharRoRServiceException(code=RoRErrorCode.BHULEKH_RATE_LIMITED, message=err_msg, retryable=True)
            async with _bihar_inflight_lock:
                _bihar_inflight_scrapes.pop(cache_key, None)
                if not future.done():
                    future.set_exception(err)
            raise err

        _bihar_pending_count += 1
        try:
            async with _bihar_semaphore:
                result = await self._execute_parse(
                    district=district,
                    anchal=anchal,
                    village=village,
                    plot=plot,
                    khata=khata,
                    raw_html=raw_html,
                    raw_payload=raw_payload,
                )

                if result.success:
                    _bihar_cache[cache_key] = result
                    self.metrics["successful_lookups"] += 1
                else:
                    if result.error and result.error.code == RoRErrorCode.PLOT_NOT_FOUND:
                        _bihar_negative_cache[cache_key] = True
                    self.metrics["failed_lookups"] += 1

                async with _bihar_inflight_lock:
                    _bihar_inflight_scrapes.pop(cache_key, None)
                    if not future.done():
                        future.set_result(result)

                elapsed_ms = (time.perf_counter() - t_start) * 1000.0
                self.metrics["total_latency_ms"] += elapsed_ms
                return result

        except Exception as exc:
            self.metrics["failed_lookups"] += 1
            svc_err = exc if isinstance(exc, BiharRoRServiceException) else BiharRoRServiceException(
                code=RoRErrorCode.SERVER_ERROR,
                message=f"Bihar RoR parsing error: {str(exc)}",
                retryable=False,
            )
            async with _bihar_inflight_lock:
                _bihar_inflight_scrapes.pop(cache_key, None)
                if not future.done():
                    future.set_exception(svc_err)
            raise svc_err

        finally:
            _bihar_pending_count = max(0, _bihar_pending_count - 1)

    async def _execute_parse(
        self,
        district: str,
        anchal: str,
        village: str,
        plot: str,
        khata: Optional[str] = None,
        raw_html: Optional[str] = None,
        raw_payload: Optional[Dict[str, Any]] = None,
    ) -> RoRResponse:
        """
        Dispatches payload to the deterministic parser.
        """
        if raw_payload is not None:
            return BiharJamabandiParser.parse_dict(
                payload=raw_payload,
                requested_district=district,
                requested_anchal=anchal,
                requested_village=village,
                requested_plot=plot,
            )

        if raw_html is not None:
            return BiharJamabandiParser.parse_html(
                html_content=raw_html,
                requested_district=district,
                requested_anchal=anchal,
                requested_village=village,
                requested_plot=plot,
                requested_khata=khata,
            )

        # In offline/mock mode without live credentials, returns plot not found rather than faking data
        return BiharJamabandiParser._create_error_response(
            code=RoRErrorCode.PLOT_NOT_FOUND,
            message="No direct scraper session provided in offline test environment.",
            retryable=False,
            district=district,
            tahasil=anchal,
            village=village,
            plot=plot,
        )
