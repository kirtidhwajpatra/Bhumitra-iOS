"""
Uttar Pradesh BhuNaksha provider (map-layer prototype).

Talks to the public endpoints the upbhunaksha.gov.in web app itself uses:
  POST /masterdata/levelvalue          District -> Tehsil -> Village lists
  POST /MapInfo/getVVVVExtentGeoref    village extent in UTM (EPSG:326xx) + gisCode
  GET  /WMS                            parcel-line raster for one village
  POST /MapInfo/getPlotAtXY            plot at a UTM point
  POST /MapInfo/getPlotByPlotNo        plot by number
  POST /MapInfo/getPlotInfo            plain-text khata / plot / area (+ owner rows)

No login, no CAPTCHA. Owner rows in plot info are dropped inside the parser and
never logged, cached, or returned.

Isolated from the Odisha and Bihar providers on purpose: nothing in the Odisha
flow imports this module.
"""
import asyncio
import json
import logging
import math
import re
import time
from collections import OrderedDict
from typing import Dict, List, Optional, Tuple

import httpx
from cachetools import TTLCache

from models.up_gis import (
    UPLevelItem,
    UPPlotRecord,
    UPPlotResult,
    UPVillageExtent,
)

logger = logging.getLogger(__name__)

UP_BASE_URL = "https://upbhunaksha.gov.in/bhunakshaserver"
DEFAULT_UTM_ZONE = 44
USER_AGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148"

_CODE_RE = re.compile(r"^[0-9]{1,8}$")
_GIS_CODE_RE = re.compile(r"^[0-9]{6,20}$")
_CRS_RE = re.compile(r"^EPSG:326(\d{2})$")
_PLOT_TOKEN_RE = re.compile(r"^[0-9A-Za-z/\-\u0900-\u097F]{1,30}$")
_FEATURE_ID_RE = re.compile(r"^[0-9A-Za-z_\-]{1,128}$")
_RECORD_RE = re.compile(
    r"Khata\s*No\.?\s*:\s*(?P<khata>[0-9A-Za-z/\-]{1,20})\s+"
    r"Plot\s*No\.?\s*:\s*(?P<plot>[0-9A-Za-z/\-\u0900-\u097F]{1,30})\s+"
    r"Area\s*:\s*(?P<area>[0-9]{1,10}(?:\.[0-9]{1,8})?)\s*(?P<unit>[A-Za-z]{1,16})?",
    re.IGNORECASE,
)
_WEB_MERCATOR_LIMIT = 20_037_508.35
# Broad UP bounds in EPSG:3857; a tile's centre must fall inside these.
_UP_3857_BOUNDS = (8_571_600.0, 2_693_000.0, 9_440_000.0, 3_695_000.0)
_MAX_RESPONSE_BYTES = 2 * 1024 * 1024
_MAX_TILE_BYTES = 512 * 1024
_TILE_CACHE_BYTES = 24 * 1024 * 1024


class UPBhunakshaError(Exception):
    """Base error. `code` is surfaced to the API client."""

    code = "UP_UPSTREAM_ERROR"
    http_status = 502
    retryable = True

    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


class UPUpstreamUnavailable(UPBhunakshaError):
    code = "UP_UPSTREAM_UNAVAILABLE"
    http_status = 503


class UPUpstreamBusy(UPBhunakshaError):
    code = "UP_UPSTREAM_BUSY"
    http_status = 503


class UPResponseTooLarge(UPBhunakshaError):
    code = "UP_RESPONSE_TOO_LARGE"
    http_status = 502


class UPNotFound(UPBhunakshaError):
    code = "UP_NOT_FOUND"
    http_status = 404
    retryable = False


class UPInvalidInput(UPBhunakshaError):
    code = "UP_INVALID_INPUT"
    http_status = 422
    retryable = False


# --------------------------------------------------------------------------
# Coordinate math (WGS84 <-> UTM north, WGS84 <-> Web Mercator)
# --------------------------------------------------------------------------

_A = 6378137.0
_F = 1 / 298.257223563
_K0 = 0.9996
_E2 = _F * (2 - _F)
_EP2 = _E2 / (1 - _E2)


def utm_to_latlng(easting: float, northing: float, zone: int = DEFAULT_UTM_ZONE) -> Tuple[float, float]:
    x = easting - 500000.0
    m = northing / _K0
    mu = m / (_A * (1 - _E2 / 4 - 3 * _E2 ** 2 / 64 - 5 * _E2 ** 3 / 256))
    e1 = (1 - math.sqrt(1 - _E2)) / (1 + math.sqrt(1 - _E2))
    p = (mu + (3 * e1 / 2 - 27 * e1 ** 3 / 32) * math.sin(2 * mu)
         + (21 * e1 ** 2 / 16 - 55 * e1 ** 4 / 32) * math.sin(4 * mu)
         + (151 * e1 ** 3 / 96) * math.sin(6 * mu))
    c = _EP2 * math.cos(p) ** 2
    t = math.tan(p) ** 2
    n = _A / math.sqrt(1 - _E2 * math.sin(p) ** 2)
    r = _A * (1 - _E2) / (1 - _E2 * math.sin(p) ** 2) ** 1.5
    d = x / (n * _K0)
    lat = p - (n * math.tan(p) / r) * (
        d ** 2 / 2
        - (5 + 3 * t + 10 * c - 4 * c ** 2 - 9 * _EP2) * d ** 4 / 24
        + (61 + 90 * t + 298 * c + 45 * t ** 2 - 252 * _EP2 - 3 * c ** 2) * d ** 6 / 720
    )
    lng = (d - (1 + 2 * t + c) * d ** 3 / 6
           + (5 - 2 * c + 28 * t - 3 * c ** 2 + 8 * _EP2 + 24 * t ** 2) * d ** 5 / 120) / math.cos(p)
    return math.degrees(lat), (zone - 1) * 6 - 180 + 3 + math.degrees(lng)


def latlng_to_utm(lat: float, lng: float, zone: int = DEFAULT_UTM_ZONE) -> Tuple[float, float]:
    lat_r = math.radians(lat)
    lng0 = math.radians((zone - 1) * 6 - 180 + 3)
    n = _A / math.sqrt(1 - _E2 * math.sin(lat_r) ** 2)
    t = math.tan(lat_r) ** 2
    c = _EP2 * math.cos(lat_r) ** 2
    a = math.cos(lat_r) * (math.radians(lng) - lng0)
    m = _A * ((1 - _E2 / 4 - 3 * _E2 ** 2 / 64 - 5 * _E2 ** 3 / 256) * lat_r
              - (3 * _E2 / 8 + 3 * _E2 ** 2 / 32 + 45 * _E2 ** 3 / 1024) * math.sin(2 * lat_r)
              + (15 * _E2 ** 2 / 256 + 45 * _E2 ** 3 / 1024) * math.sin(4 * lat_r)
              - (35 * _E2 ** 3 / 3072) * math.sin(6 * lat_r))
    easting = _K0 * n * (a + (1 - t + c) * a ** 3 / 6
                         + (5 - 18 * t + t ** 2 + 72 * c - 58 * _EP2) * a ** 5 / 120) + 500000.0
    northing = _K0 * (m + n * math.tan(lat_r) * (
        a ** 2 / 2 + (5 - t + 9 * c + 4 * c ** 2) * a ** 4 / 24
        + (61 - 58 * t + t ** 2 + 600 * c - 330 * _EP2) * a ** 6 / 720))
    return easting, northing


def utm_bbox_to_latlng_bbox(minx: float, miny: float, maxx: float, maxy: float,
                            zone: int = DEFAULT_UTM_ZONE) -> List[float]:
    """Converts all four corners so the WGS84 box fully contains the UTM box."""
    corners = [utm_to_latlng(x, y, zone) for x in (minx, maxx) for y in (miny, maxy)]
    lats = [c[0] for c in corners]
    lngs = [c[1] for c in corners]
    return [min(lngs), min(lats), max(lngs), max(lats)]


def zone_from_crs(crs: Optional[str]) -> int:
    m = _CRS_RE.match(str(crs or "").strip())
    return int(m.group(1)) if m else DEFAULT_UTM_ZONE


def valid_utm_bbox(values: List[float]) -> bool:
    if len(values) != 4 or not all(math.isfinite(v) for v in values):
        return False
    minx, miny, maxx, maxy = values
    return (100_000 <= minx < maxx <= 900_000
            and 2_500_000 <= miny < maxy <= 3_700_000
            and maxx - minx <= 100_000 and maxy - miny <= 100_000)


def valid_up_web_mercator_bbox(values: List[float]) -> bool:
    if len(values) != 4 or not all(math.isfinite(v) for v in values):
        return False
    minx, miny, maxx, maxy = values
    if not (-_WEB_MERCATOR_LIMIT <= minx < maxx <= _WEB_MERCATOR_LIMIT
            and -_WEB_MERCATOR_LIMIT <= miny < maxy <= _WEB_MERCATOR_LIMIT):
        return False
    width, height = maxx - minx, maxy - miny
    # MapLibre z13-z20 tiles are square and roughly 38m-4892m wide.
    if not (10 <= width <= 6_000 and 10 <= height <= 6_000 and 0.9 <= width / height <= 1.1):
        return False
    cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
    ux0, uy0, ux1, uy1 = _UP_3857_BOUNDS
    return ux0 <= cx <= ux1 and uy0 <= cy <= uy1


# --------------------------------------------------------------------------
# Plot-info parsing (owner rows are discarded here)
# --------------------------------------------------------------------------

def parse_plot_info(text: str) -> List[UPPlotRecord]:
    """Extracts khata / plot / area rows. Everything else, including every
    owner-detail line, is ignored and never leaves this function."""
    records: List[UPPlotRecord] = []
    seen = set()
    for line in (text or "").splitlines():
        m = _RECORD_RE.search(line)
        if not m:
            continue
        khata = m.group("khata").strip()
        plot = m.group("plot").strip()
        # Defense in depth: never serialize unrestricted upstream text.
        if not _PLOT_TOKEN_RE.fullmatch(plot):
            continue
        key = (khata, plot)
        if key in seen:
            continue
        seen.add(key)
        try:
            area = float(m.group("area"))
        except (TypeError, ValueError):
            area = None
        unit = (m.group("unit") or "").strip() or None
        records.append(UPPlotRecord(khata_no=khata, plot_no=plot, area=area, area_unit=unit))
    return records


def split_gis_code(gis_code: str) -> Optional[Tuple[str, str, str]]:
    """UP gisCodes observed as district(3) + tehsil(5) + village(6), e.g.
    15900830145758 -> (159, 00830, 145758)."""
    if len(gis_code) == 14 and gis_code.isdigit():
        return gis_code[:3], gis_code[3:8], gis_code[8:]
    return None


# --------------------------------------------------------------------------
# Provider
# --------------------------------------------------------------------------

class UPBhunakshaProvider:
    def __init__(self, base_url: str = UP_BASE_URL, timeout_seconds: float = 10.0,
                 max_concurrency: int = 6, transport: Optional[httpx.AsyncBaseTransport] = None):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout_seconds
        self._transport = transport
        self._client: Optional[httpx.AsyncClient] = None
        self._client_lock = asyncio.Lock()
        # Politeness: cap active upstream calls and queued callers per worker.
        self._sem = asyncio.Semaphore(max_concurrency)
        self._pending = asyncio.Semaphore(max_concurrency * 4)

        self._levels_cache: TTLCache = TTLCache(maxsize=4000, ttl=86400)
        self._extent_cache: TTLCache = TTLCache(maxsize=5000, ttl=86400)
        self._zone_cache: TTLCache = TTLCache(maxsize=20000, ttl=7 * 86400)
        self._plot_cache: TTLCache = TTLCache(maxsize=2000, ttl=600)
        # Byte-budgeted LRU: never let tile bodies exceed 24 MB per worker.
        self._tile_cache: OrderedDict[str, Tuple[float, bytes]] = OrderedDict()
        self._tile_cache_bytes = 0
        self._tile_lock = asyncio.Lock()
        self._tile_inflight: Dict[str, asyncio.Task] = {}

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None or self._client.is_closed:
            async with self._client_lock:
                if self._client is None or self._client.is_closed:
                    self._client = httpx.AsyncClient(
                        timeout=self.timeout,
                        headers={
                            "User-Agent": USER_AGENT,
                            "Accept": "application/json, text/plain, */*",
                            # UP's JSON endpoints sometimes send malformed compressed bodies.
                            # Identity encoding also keeps streaming byte limits deterministic.
                            "Accept-Encoding": "identity",
                        },
                        limits=httpx.Limits(max_connections=8, max_keepalive_connections=4),
                        transport=self._transport,
                    )
        return self._client

    async def aclose(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    async def _request(self, method: str, path: str, *, data=None, json_body=None,
                       params=None, max_bytes: int = _MAX_RESPONSE_BYTES) -> httpx.Response:
        client = await self._get_client()
        try:
            await asyncio.wait_for(self._pending.acquire(), timeout=1.0)
        except asyncio.TimeoutError:
            raise UPUpstreamBusy("UP map service is busy. Please try again shortly.")
        try:
            async with self._sem:
                async with client.stream(method, self.base_url + path, data=data, json=json_body, params=params) as streamed:
                    chunks = []
                    total = 0
                    async for chunk in streamed.aiter_bytes():
                        total += len(chunk)
                        if total > max_bytes:
                            raise UPResponseTooLarge("UP BhuNaksha response exceeded the safe size limit.")
                        chunks.append(chunk)
                    res = httpx.Response(
                        status_code=streamed.status_code,
                        headers=streamed.headers,
                        content=b"".join(chunks),
                        request=streamed.request,
                    )
        except httpx.TimeoutException:
            logger.warning("UP_BHUNAKSHA_TIMEOUT path=%s", path)
            raise UPUpstreamUnavailable("UP BhuNaksha did not respond in time.")
        except httpx.HTTPError as e:
            logger.warning("UP_BHUNAKSHA_NETWORK path=%s err=%s", path, type(e).__name__)
            raise UPUpstreamUnavailable("UP BhuNaksha is unreachable right now.")
        finally:
            self._pending.release()
        if res.status_code >= 500:
            logger.warning("UP_BHUNAKSHA_HTTP_%s path=%s", res.status_code, path)
            raise UPUpstreamUnavailable(f"UP BhuNaksha returned HTTP {res.status_code}.")
        if res.status_code >= 400:
            raise UPBhunakshaError(f"UP BhuNaksha rejected the request (HTTP {res.status_code}).")
        return res

    @staticmethod
    def _json(res: httpx.Response):
        try:
            return res.json()
        except (ValueError, json.JSONDecodeError):
            raise UPBhunakshaError("UP BhuNaksha returned an unexpected response.")

    # ---------------- hierarchy

    async def list_level(self, level: int, parent_codes: List[str]) -> List[UPLevelItem]:
        if level not in (1, 2, 3):
            raise UPInvalidInput("level must be 1 (district), 2 (tehsil) or 3 (village).")
        if len(parent_codes) != level - 1 or not all(_CODE_RE.match(c) for c in parent_codes):
            raise UPInvalidInput(f"level {level} needs exactly {level - 1} numeric parent code(s).")
        key = f"{level}:{','.join(parent_codes)}"
        if key in self._levels_cache:
            return self._levels_cache[key]
        res = await self._request("POST", "/masterdata/levelvalue",
                                  data={"level": str(level), "codes": ",".join(parent_codes)})
        raw = self._json(res)
        if not isinstance(raw, list):
            raise UPBhunakshaError("UP BhuNaksha level list had an unexpected shape.")
        items: List[UPLevelItem] = []
        for it in raw:
            if not isinstance(it, dict):
                continue
            extra = it.get("extraParams") or it.get("extraParms") or {}
            if isinstance(extra, dict) and extra.get("hasData") is False:
                continue
            code = str(it.get("code") or "").strip()
            name = str(it.get("value") or "").strip()
            if code and name:
                items.append(UPLevelItem(code=code, name=name))
        self._levels_cache[key] = items
        return items

    # ---------------- village extent

    async def village_extent(self, district: str, tehsil: str, village: str) -> UPVillageExtent:
        codes = [district, tehsil, village]
        if not all(_CODE_RE.match(c or "") for c in codes):
            raise UPInvalidInput("district, tehsil and village must be numeric codes.")
        key = ",".join(codes)
        if key in self._extent_cache:
            return self._extent_cache[key]
        res = await self._request("POST", "/MapInfo/getVVVVExtentGeoref", data={"gisLevels": key})
        raw = self._json(res)
        if not isinstance(raw, dict):
            raise UPNotFound("No georeferenced map is available for this village.")
        raw_gis_code = str(raw.get("gisCode") or "").strip()
        if raw.get("xmax") is None or not _GIS_CODE_RE.fullmatch(raw_gis_code):
            raise UPNotFound("No georeferenced map is available for this village.")
        crs = str(raw.get("crs") or f"EPSG:326{DEFAULT_UTM_ZONE}")
        if not _CRS_RE.match(crs):
            raise UPNotFound(f"Village map uses an unsupported coordinate system ({crs}).")
        zone = zone_from_crs(crs)
        try:
            native_bbox = [float(raw[k]) for k in ("xmin", "ymin", "xmax", "ymax")]
        except (KeyError, TypeError, ValueError):
            raise UPBhunakshaError("UP BhuNaksha returned an invalid village extent.")
        if not valid_utm_bbox(native_bbox):
            raise UPBhunakshaError("UP BhuNaksha returned an unsafe village extent.")
        minx, miny, maxx, maxy = native_bbox
        bbox = utm_bbox_to_latlng_bbox(minx, miny, maxx, maxy, zone)
        extent = UPVillageExtent(
            gis_code=raw_gis_code,
            district_code=district, tehsil_code=tehsil, village_code=village,
            crs=crs,
            utm_bbox=[minx, miny, maxx, maxy],
            bbox=[round(v, 7) for v in bbox],
            center_lat=round((bbox[1] + bbox[3]) / 2, 7),
            center_lng=round((bbox[0] + bbox[2]) / 2, 7),
        )
        self._extent_cache[key] = extent
        self._zone_cache[extent.gis_code] = zone
        return extent

    async def _zone_for(self, gis_code: str) -> int:
        if gis_code in self._zone_cache:
            return self._zone_cache[gis_code]
        parts = split_gis_code(gis_code)
        if parts:
            try:
                return zone_from_crs((await self.village_extent(*parts)).crs)
            except UPBhunakshaError:
                pass
        return DEFAULT_UTM_ZONE

    # ---------------- plots

    def _plot_from_raw(self, gis_code: str, raw, zone: int) -> Optional[UPPlotResult]:
        if not isinstance(raw, dict):
            return None
        raw_plot = str(raw.get("kide") or "").strip()
        if not _PLOT_TOKEN_RE.fullmatch(raw_plot):
            return None
        raw_id = str(raw.get("id") or "").strip()
        safe_id = raw_id if _FEATURE_ID_RE.fullmatch(raw_id) else None
        try:
            native_bbox = [float(raw[k]) for k in ("minx", "miny", "maxx", "maxy")]
            if not valid_utm_bbox(native_bbox):
                return None
            bbox = utm_bbox_to_latlng_bbox(*native_bbox, zone)
        except (KeyError, TypeError, ValueError):
            return None
        return UPPlotResult(
            gis_code=gis_code,
            plot_no=raw_plot,
            plot_id=safe_id,
            bbox=[round(v, 7) for v in bbox],
        )

    async def _attach_records(self, plot: UPPlotResult) -> UPPlotResult:
        try:
            res = await self._request("POST", "/MapInfo/getPlotInfo",
                                      json_body={"gisCode": plot.gis_code, "plotNo": plot.plot_no})
            plot.records = parse_plot_info(res.text)
        except UPBhunakshaError as e:
            # Map identity is still useful without the text record.
            logger.info("UP_PLOT_INFO_UNAVAILABLE gis=%s err=%s", plot.gis_code, e.code)
        return plot

    async def identify(self, gis_code: str, lat: float, lng: float) -> UPPlotResult:
        if not _GIS_CODE_RE.match(gis_code or ""):
            raise UPInvalidInput("gis_code must be numeric.")
        if not (23.5 <= lat <= 31.5 and 77.0 <= lng <= 84.8):
            raise UPInvalidInput("Point is outside Uttar Pradesh.")
        zone = await self._zone_for(gis_code)
        x, y = latlng_to_utm(lat, lng, zone)
        key = f"xy:{gis_code}:{x:.1f}:{y:.1f}"
        if key in self._plot_cache:
            return self._plot_cache[key]
        res = await self._request("POST", "/MapInfo/getPlotAtXY",
                                  data={"giscode": gis_code, "x": f"{x:.3f}", "y": f"{y:.3f}"})
        plot = self._plot_from_raw(gis_code, self._json_or_none(res), zone)
        if plot is None:
            raise UPNotFound("No plot found at this spot.")
        plot = await self._attach_records(plot)
        self._plot_cache[key] = plot
        return plot

    async def plot_by_number(self, gis_code: str, plot_no: str) -> UPPlotResult:
        clean = (plot_no or "").strip()
        if not _GIS_CODE_RE.match(gis_code or ""):
            raise UPInvalidInput("gis_code must be numeric.")
        if not clean or len(clean) > 20 or not _PLOT_TOKEN_RE.fullmatch(clean):
            raise UPInvalidInput("Enter a valid plot number.")
        key = f"no:{gis_code}:{clean}"
        if key in self._plot_cache:
            return self._plot_cache[key]
        zone = await self._zone_for(gis_code)
        res = await self._request("POST", "/MapInfo/getPlotByPlotNo",
                                  data={"giscode": gis_code, "plotno": clean})
        plot = self._plot_from_raw(gis_code, self._json_or_none(res), zone)
        if plot is None:
            raise UPNotFound(f"Plot {clean} was not found in this village.")
        plot = await self._attach_records(plot)
        self._plot_cache[key] = plot
        return plot

    @staticmethod
    def _json_or_none(res: httpx.Response):
        if not res.content or not res.content.strip():
            return None
        try:
            return res.json()
        except (ValueError, json.JSONDecodeError):
            return None

    # ---------------- raster tiles

    async def _cached_tile(self, key: str) -> Optional[bytes]:
        async with self._tile_lock:
            entry = self._tile_cache.get(key)
            if entry is None:
                return None
            expires, body = entry
            if expires <= time.monotonic():
                self._tile_cache.pop(key, None)
                self._tile_cache_bytes -= len(body)
                return None
            self._tile_cache.move_to_end(key)
            return body

    async def _store_tile(self, key: str, body: bytes) -> None:
        async with self._tile_lock:
            old = self._tile_cache.pop(key, None)
            if old:
                self._tile_cache_bytes -= len(old[1])
            while self._tile_cache and self._tile_cache_bytes + len(body) > _TILE_CACHE_BYTES:
                _, (_, evicted) = self._tile_cache.popitem(last=False)
                self._tile_cache_bytes -= len(evicted)
            self._tile_cache[key] = (time.monotonic() + 3600, body)
            self._tile_cache_bytes += len(body)

    async def _clear_inflight(self, key: str, task: asyncio.Task) -> None:
        async with self._tile_lock:
            if self._tile_inflight.get(key) is task:
                self._tile_inflight.pop(key, None)

    async def _fetch_wms_tile(self, gis_code: str, bbox_3857: List[float], size: int, key: str) -> bytes:
        params = {
            "SERVICE": "WMS", "VERSION": "1.1.1", "REQUEST": "GetMap",
            "LAYERS": "VILLAGE_MAP", "STYLES": "VILLAGE_MAP", "FORMAT": "image/png",
            "TRANSPARENT": "true", "SRS": "EPSG:3857",
            "BBOX": ",".join(f"{v:.4f}" for v in bbox_3857),
            "WIDTH": str(size), "HEIGHT": str(size),
            "state": "", "gis_code": gis_code, "overlay_codes": "",
        }
        res = await self._request("GET", "/WMS", params=params, max_bytes=_MAX_TILE_BYTES)
        body = res.content
        if not body.startswith(b"\x89PNG"):
            raise UPBhunakshaError("UP BhuNaksha did not return a map image.")
        await self._store_tile(key, body)
        return body

    async def wms_tile(self, gis_code: str, bbox_3857: List[float], size: int = 256) -> bytes:
        if not _GIS_CODE_RE.match(gis_code or ""):
            raise UPInvalidInput("gis_code must be numeric.")
        if not valid_up_web_mercator_bbox(bbox_3857):
            raise UPInvalidInput("bbox must be a finite UP map tile in EPSG:3857.")
        if size not in (256, 512):
            raise UPInvalidInput("size must be 256 or 512.")
        key = f"{gis_code}:{size}:" + ",".join(f"{v:.2f}" for v in bbox_3857)
        cached = await self._cached_tile(key)
        if cached is not None:
            return cached
        # Coalesce simultaneous MapLibre requests for the same tile.
        async with self._tile_lock:
            task = self._tile_inflight.get(key)
            if task is None:
                task = asyncio.create_task(self._fetch_wms_tile(gis_code, bbox_3857, size, key))
                self._tile_inflight[key] = task
                task.add_done_callback(lambda done: asyncio.create_task(self._clear_inflight(key, done)))
        return await asyncio.shield(task)


def _default_timeout() -> float:
    try:
        from core.config import settings
        return float(settings.UP_TIMEOUT_SECONDS)
    except Exception:
        return 10.0


up_bhunaksha_provider = UPBhunakshaProvider(timeout_seconds=_default_timeout())
