"""
Bhumitra GIS Navigation Router
Dedicated REST API for visual map exploration of Odisha cadastral administrative boundaries.
Completely isolated from existing form-based location selector and RoR endpoints.
"""

import json
import asyncio
import logging
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query, Response, status
from fastapi.responses import JSONResponse

from services.gis_navigation_service import gis_navigation_service, GISDistrictSummary
from models.cadastral import (
    CadastralBlock,
    CadastralVillage,
    CadastralExtent,
    CadastralFeatureCollection,
    CadastralErrorResponse,
)

logger = logging.getLogger("bhumitra.routers.gis_navigation")

router = APIRouter(prefix="/api/v1/gis/navigation", tags=["GIS Explorer Navigation"])


@router.get(
    "/districts-geojson",
    summary="Get 30 Odisha District Boundaries GeoJSON",
    description="Returns high-precision WGS84 GeoJSON FeatureCollection containing polygons for all 30 Odisha districts for direct MapLibre rendering.",
)
async def get_districts_geojson():
    try:
        data = gis_navigation_service.get_districts_geojson()
        return JSONResponse(
            content=data,
            headers={
                "Cache-Control": "public, max-age=86400",
                "X-Bhumitra-Layer": "odisha-districts",
                "X-Bhumitra-Districts-Count": str(len(data.get("features", []))),
            },
        )
    except Exception as e:
        logger.error(f"GIS_NAV_DISTRICTS_GEOJSON_ERROR: {e}")
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=CadastralErrorResponse(
                error_code="DISTRICT_GEOJSON_UNAVAILABLE",
                message="Unable to load Odisha district boundaries GeoJSON.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/districts",
    response_model=List[GISDistrictSummary],
    summary="Get Odisha Districts Metadata List",
    description="Returns metadata for all 30 districts including canonical names, 2-digit GIS codes, bounding boxes, and center coordinates.",
)
async def list_districts():
    try:
        return await asyncio.to_thread(gis_navigation_service.get_districts_summary)
    except Exception as e:
        logger.error(f"GIS_NAV_DISTRICTS_LIST_ERROR: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list districts: {str(e)}",
        )


@router.get(
    "/districts/{district_id}",
    response_model=GISDistrictSummary,
    summary="Get Single District Metadata",
)
async def get_district(district_id: str):
    district = await asyncio.to_thread(gis_navigation_service.get_district_by_id, district_id)
    if not district:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"District with ID or code '{district_id}' not found in Odisha records.",
        )
    return district

@router.get(
    "/districts/{district_id}/tahasils-geojson",
    summary="Get Tahasils Visualization Boundaries GeoJSON for a District",
    description=(
        "Returns WGS84 GeoJSON FeatureCollection containing polygons for all tahasils in the district. "
        "Classified as 'Census/Survey-derived administrative visualization boundary'. "
        "When geometry is unavailable, returns an empty FeatureCollection with geometry_available=false "
        "and the X-Bhumitra-Geometry-Available: false header."
    ),
)
async def get_tahasils_geojson(district_id: str):
    try:
        data = await asyncio.to_thread(gis_navigation_service.get_tahasils_geojson_for_district, district_id)
        geometry_available = data.get("geometry_available", True) and len(data.get("features", [])) > 0
        return JSONResponse(
            content=data,
            headers={
                "Cache-Control": "public, max-age=86400",
                "X-Bhumitra-Layer": "odisha-tahasils-visualization",
                "X-Bhumitra-Classification": "Census/Survey-derived administrative visualization boundary",
                "X-Bhumitra-Geometry-Available": "true" if geometry_available else "false",
            },
        )
    except Exception as e:
        logger.error(f"GIS_NAV_TAHASILS_GEOJSON_ERROR: {e} for district={district_id}")
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=CadastralErrorResponse(
                error_code="TAHASIL_GEOJSON_UNAVAILABLE",
                message=f"Unable to load Tahasils GeoJSON for district '{district_id}'.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/districts/{district_id}/subdivisions",
    response_model=List[CadastralBlock],
    summary="Get Tahasils/Blocks for a District",
)
async def get_subdivisions(district_id: str):
    try:
        return await gis_navigation_service.get_subdivisions_for_district(district_id=district_id)
    except Exception as e:
        logger.error(f"GIS_NAV_SUBDIVISIONS_ERROR: {e} for district={district_id}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="SUBDIVISIONS_UNAVAILABLE",
                message=f"Unable to load subdivisions for district '{district_id}'.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/subdivisions/{subdivision_id}/villages",
    response_model=List[CadastralVillage],
    summary="Get Revenue Villages for a Tahasil/Block",
)
async def get_villages(
    subdivision_id: str,
    gp_id: Optional[str] = Query(None, description="Optional Gram Panchayat code"),
    block_name: Optional[str] = Query(None, description="Optional block name"),
    district_name: Optional[str] = Query(None, description="Optional district name"),
):
    try:
        return await gis_navigation_service.get_villages_for_subdivision(
            subdivision_id=subdivision_id,
            gp_id=gp_id,
            block_name=block_name,
            district_name=district_name,
        )
    except Exception as e:
        logger.error(f"GIS_NAV_VILLAGES_ERROR: {e} for subdivision={subdivision_id}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="VILLAGES_UNAVAILABLE",
                message=f"Unable to load villages for subdivision '{subdivision_id}'.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/villages/{village_id}/extent",
    response_model=Optional[CadastralExtent],
    summary="Get Revenue Village Extent",
)
async def get_village_extent(
    village_id: str,
    gp_id: Optional[str] = Query(None, description="Optional GP code"),
):
    try:
        extent = await gis_navigation_service.get_village_extent(village_id=village_id, gp_id=gp_id)
        if not extent:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Extent bounding box not found for village {village_id}",
            )
        return extent
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"GIS_NAV_EXTENT_ERROR: {e} for village={village_id}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Unable to retrieve village extent: {str(e)}",
        )


@router.get(
    "/villages/{village_id}/parcels",
    response_model=CadastralFeatureCollection,
    summary="Get Village Cadastral Parcels GeoJSON",
)
async def get_village_parcels(
    village_id: str,
    district_name: Optional[str] = Query(None),
    block_name: Optional[str] = Query(None),
    village_name: Optional[str] = Query(None),
):
    try:
        return await gis_navigation_service.get_village_parcels(
            village_id=village_id,
            district_name=district_name,
            block_name=block_name,
            village_name=village_name,
        )
    except Exception as e:
        logger.error(f"GIS_NAV_PARCELS_ERROR: {e} for village={village_id}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="PARCELS_UNAVAILABLE",
                message=f"Unable to retrieve cadastral parcels for village '{village_id}'.",
                details=str(e),
            ).model_dump(),
        )
