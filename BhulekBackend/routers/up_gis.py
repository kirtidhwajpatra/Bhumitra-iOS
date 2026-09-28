"""
Uttar Pradesh map-layer prototype routes (/api/v1/gis/up/*).

Fail-closed: every route returns 503 UP_GIS_DISABLED unless the
UP_GIS_PROVIDER_ENABLED env flag is true. Isolated from the Odisha/Bihar
GISRouter; nothing here touches the Odisha flow.

Responses carry plot number, khata and area only. Owner names are dropped in
the provider's parser.
"""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, Path, Query, Request, Response, status
from fastapi.responses import JSONResponse

from core.config import settings
from core.rate_limiter import enforce_rate_limit
from models.up_gis import UPLevelResponse, UPPlotResult, UPVillageExtent
from providers.up_bhunaksha_provider import (
    UPBhunakshaError,
    UPBhunakshaProvider,
    UPNotFound,
    up_bhunaksha_provider,
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
        return await provider.identify(gis_code.strip(), lat, lng)
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
        return await provider.plot_by_number(gis_code.strip(), plot_no)
    except UPBhunakshaError as e:
        return _error_response(e)


@router.get("/wms/{gis_code}", summary="Parcel-line PNG tile (EPSG:3857 bbox)",
            responses={200: {"content": {"image/png": {}}}})
async def up_wms_tile(
    request: Request,
    gis_code: str = Path(..., max_length=20),
    bbox: str = Query(..., max_length=120, description="minx,miny,maxx,maxy in EPSG:3857"),
    size: int = Query(256),
    provider: UPBhunakshaProvider = Depends(get_up_provider),
):
    if not settings.UP_GIS_PROVIDER_ENABLED:
        return _disabled_response()
    # One screen of map pulls 20-40 tiles; allow bursts while still capping abuse.
    enforce_rate_limit(request, max_requests=1200, tag="up_wms")
    try:
        parts = [float(v) for v in bbox.split(",")]
    except ValueError:
        parts = []
    if len(parts) != 4:
        return JSONResponse(status_code=422, content={
            "error_code": "UP_INVALID_INPUT", "message": "bbox must be 4 comma-separated numbers.", "retryable": False})
    try:
        png = await provider.wms_tile(gis_code.strip(), parts, size)
    except UPNotFound:
        return Response(status_code=204)
    except UPBhunakshaError as e:
        return _error_response(e)
    return Response(content=png, media_type="image/png",
                    headers={"Cache-Control": "public, max-age=3600"})
