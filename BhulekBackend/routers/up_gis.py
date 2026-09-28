"""
Uttar Pradesh map-layer prototype routes (/api/v1/gis/up/*).

Fail-closed: every route returns 503 UP_GIS_DISABLED unless the
UP_GIS_PROVIDER_ENABLED env flag is true. Isolated from the Odisha/Bihar
GISRouter; nothing here touches the Odisha flow.

Responses carry plot number, khata and area only. Owner names are dropped in
the provider's parser.
"""
import ipaddress
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, Path, Query, Request, Response, status
from fastapi.responses import JSONResponse

from core.config import settings
from core.rate_limiter import enforce_rate_limit, limiter
from core.up_selection_token import (
    MAX_TOKEN_LENGTH,
    SelectionTokenError,
    mint_selection_token,
    verify_selection_token,
)
from models.up_gis import UPLevelResponse, UPPlotResult, UPVillageExtent
from providers.up_bhunaksha_provider import (
    UPBhunakshaError,
    UPBhunakshaProvider,
    UPNotFound,
    up_bhunaksha_provider,
    valid_up_view_request,
    valid_up_web_mercator_bbox,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/gis/up", tags=["UP Map (prototype)"])

LEVEL_LABELS = {1: "District", 2: "Tehsil", 3: "Village"}


def get_up_provider() -> UPBhunakshaProvider:
    return up_bhunaksha_provider


def _disabled_response() -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={
            "error_code": "UP_GIS_DISABLED",
            "message": "Uttar Pradesh map view is currently turned off.",
            "retryable": False,
        },
    )


def _error_response(e: UPBhunakshaError) -> JSONResponse:
    return JSONResponse(
        status_code=e.http_status,
        content={"error_code": e.code, "message": e.message, "retryable": e.retryable},
    )


def _parse_codes(raw: Optional[str]) -> List[str]:
    return [c.strip() for c in (raw or "").split(",") if c.strip()]


def _trusted_client_id(request: Request) -> str:
    """nginx appends the real peer address to X-Forwarded-For. Use the last
    valid entry, not the caller-controlled first entry."""
    forwarded = request.headers.get("X-Forwarded-For", "")
    candidate = forwarded.split(",")[-1].strip() if forwarded else ""
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError:
        return request.client.host if request.client else "unknown"


def _wms_budget(request: Request) -> Optional[JSONResponse]:
    enforce_rate_limit(request, max_requests=300, tag="up_wms", user_id=_trusted_client_id(request))
    # Per-worker global budget; with two production workers this caps upstream
    # tile traffic at 600/min even under distributed or spoofed traffic.
    allowed, _, retry_after = limiter.is_allowed("up_wms_global", max_requests=300, window_seconds=60)
    if not allowed:
        return JSONResponse(
            status_code=429,
            content={"error_code": "UP_RATE_LIMITED", "message": "UP map is busy. Try again shortly.", "retryable": True},
            headers={"Retry-After": str(retry_after)},
        )
    return None


def _with_selection_token(plot: UPPlotResult) -> UPPlotResult:
    # Copy: the provider caches plot results and must never hold a token.
    return plot.model_copy(update={"selection_token": mint_selection_token(plot.gis_code, plot.plot_id)})


def _parse_tile_bbox(bbox: str) -> Optional[List[float]]:
    try:
        parts = [float(v) for v in bbox.split(",")]
    except ValueError:
        return None
    return parts if valid_up_web_mercator_bbox(parts) else None


_BAD_BBOX = {"error_code": "UP_INVALID_INPUT", "message": "bbox must be one finite UP map tile in EPSG:3857.", "retryable": False}


@router.get("/health", summary="UP map prototype status")
async def up_health():
    return {"enabled": settings.UP_GIS_PROVIDER_ENABLED, "source": "UP_BHUNAKSHA"}


@router.get("/levels", response_model=UPLevelResponse,
            summary="District (1) -> Tehsil (2) -> Village (3) lists")
async def up_levels(
    request: Request,
    level: int = Query(..., ge=1, le=3),
    codes: Optional[str] = Query(None, description="Comma-separated parent codes, e.g. '159' or '159,00830'"),
    provider: UPBhunakshaProvider = Depends(get_up_provider),
):
    if not settings.UP_GIS_PROVIDER_ENABLED:
        return _disabled_response()
    enforce_rate_limit(request, max_requests=120, tag="up_levels")
    parents = _parse_codes(codes)
    try:
        items = await provider.list_level(level, parents)
    except UPBhunakshaError as e:
        return _error_response(e)
    return UPLevelResponse(level=level, parent_codes=parents, items=items, label=LEVEL_LABELS[level])


@router.get("/village/extent", response_model=UPVillageExtent,
            summary="Village gisCode and WGS84 bounds")
async def up_village_extent(
    request: Request,
    district: str = Query(..., max_length=8),
    tehsil: str = Query(..., max_length=8),
    village: str = Query(..., max_length=8),
    provider: UPBhunakshaProvider = Depends(get_up_provider),
):
    if not settings.UP_GIS_PROVIDER_ENABLED:
        return _disabled_response()
    enforce_rate_limit(request, max_requests=120, tag="up_extent")
    try:
        return await provider.village_extent(district.strip(), tehsil.strip(), village.strip())
    except UPBhunakshaError as e:
        return _error_response(e)


@router.get("/identify", response_model=UPPlotResult, summary="Plot at a tapped point")
async def up_identify(
    request: Request,
    gis_code: str = Query(..., max_length=20),
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    provider: UPBhunakshaProvider = Depends(get_up_provider),
):
    if not settings.UP_GIS_PROVIDER_ENABLED:
        return _disabled_response()
    enforce_rate_limit(request, max_requests=60, tag="up_identify")
    try:
        return _with_selection_token(await provider.identify(gis_code.strip(), lat, lng))
    except UPBhunakshaError as e:
        return _error_response(e)


@router.get("/plot", response_model=UPPlotResult, summary="Find a plot by number")
async def up_plot(
    request: Request,
    gis_code: str = Query(..., max_length=20),
    plot_no: str = Query(..., max_length=20),
    provider: UPBhunakshaProvider = Depends(get_up_provider),
):
    if not settings.UP_GIS_PROVIDER_ENABLED:
        return _disabled_response()
    enforce_rate_limit(request, max_requests=60, tag="up_plot")
    try:
        return _with_selection_token(await provider.plot_by_number(gis_code.strip(), plot_no))
    except UPBhunakshaError as e:
        return _error_response(e)


async def _base_tile(request: Request, gis_code: str, bbox: str, size: int,
                     provider: UPBhunakshaProvider):
    if not settings.UP_GIS_PROVIDER_ENABLED:
        return _disabled_response()
    # One screen pulls 20-40 tiles; cap both each real client and total upstream load.
    if limited := _wms_budget(request):
        return limited
    parts = _parse_tile_bbox(bbox)
    if parts is None:
        return JSONResponse(status_code=422, content=_BAD_BBOX)
    try:
        png = await provider.wms_tile(gis_code.strip(), parts, size)
    except UPNotFound:
        return Response(status_code=204)
    except UPBhunakshaError as e:
        return _error_response(e)
    return Response(content=png, media_type="image/png",
                    headers={"Cache-Control": "public, max-age=3600"})


@router.get("/wms/base/{gis_code}", summary="Transparent parcel borders + plot numbers (EPSG:3857 bbox)",
            responses={200: {"content": {"image/png": {}}}})
async def up_wms_base_tile(
    request: Request,
    gis_code: str = Path(..., max_length=20),
    bbox: str = Query(..., max_length=120, description="minx,miny,maxx,maxy in EPSG:3857"),
    size: int = Query(256),
    provider: UPBhunakshaProvider = Depends(get_up_provider),
):
    return await _base_tile(request, gis_code, bbox, size, provider)


@router.get("/wms/selection/{token}", summary="Official exact highlight for one resolved plot",
            responses={200: {"content": {"image/png": {}}}})
async def up_wms_selection_tile(
    request: Request,
    token: str = Path(..., max_length=MAX_TOKEN_LENGTH),
    bbox: str = Query(..., max_length=120, description="minx,miny,maxx,maxy in EPSG:3857"),
    size: int = Query(256),
    provider: UPBhunakshaProvider = Depends(get_up_provider),
):
    if not settings.UP_GIS_PROVIDER_ENABLED:
        return _disabled_response()
    try:
        claim = verify_selection_token(token)
    except SelectionTokenError as e:
        return JSONResponse(status_code=403, content={"error_code": e.code, "message": e.message, "retryable": False})
    if limited := _wms_budget(request):
        return limited
    parts = _parse_tile_bbox(bbox)
    if parts is None:
        return JSONResponse(status_code=422, content=_BAD_BBOX)
    try:
        png = await provider.selection_tile(claim.gis_code, claim.plot_id, parts, size)
    except UPNotFound:
        return Response(status_code=204)
    except UPBhunakshaError as e:
        return _error_response(e)
    return Response(content=png, media_type="image/png",
                    headers={"Cache-Control": "private, max-age=300"})


@router.get("/view/{gis_code}", summary="Transparent borders + plot numbers for one screen viewport",
            responses={200: {"content": {"image/png": {}}}})
async def up_view_image(
    request: Request,
    gis_code: str = Path(..., max_length=20),
    bbox: str = Query(..., max_length=120, description="minx,miny,maxx,maxy in EPSG:3857"),
    width: int = Query(..., ge=64, le=1600),
    height: int = Query(..., ge=64, le=1600),
    provider: UPBhunakshaProvider = Depends(get_up_provider),
):
    if not settings.UP_GIS_PROVIDER_ENABLED:
        return _disabled_response()
    if limited := _wms_budget(request):
        return limited
    try:
        parts = [float(v) for v in bbox.split(",")]
    except ValueError:
        parts = []
    if not valid_up_view_request(parts, width, height):
        return JSONResponse(status_code=422, content={
            "error_code": "UP_INVALID_INPUT", "message": "bbox and size must describe one UP map viewport.",
            "retryable": False})
    try:
        png = await provider.view_image(gis_code.strip(), parts, width, height)
    except UPNotFound:
        return Response(status_code=204)
    except UPBhunakshaError as e:
        return _error_response(e)
    return Response(content=png, media_type="image/png",
                    headers={"Cache-Control": "public, max-age=600"})


# Legacy path used by the first prototype build; same transparent tiles.
@router.get("/wms/{gis_code}", include_in_schema=False)
async def up_wms_tile(
    request: Request,
    gis_code: str = Path(..., max_length=20),
    bbox: str = Query(..., max_length=120),
    size: int = Query(256),
    provider: UPBhunakshaProvider = Depends(get_up_provider),
):
    return await _base_tile(request, gis_code, bbox, size, provider)
