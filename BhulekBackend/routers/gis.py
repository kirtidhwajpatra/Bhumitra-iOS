"""
Bhumitra Normalized Cadastral GIS Router
Exposes clean, isolated REST endpoints for administrative hierarchy and parcel geometries.
"""

import logging
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query, status
from fastapi.responses import JSONResponse

from models.cadastral import (
    CadastralDistrict,
    CadastralBlock,
    CadastralGP,
    CadastralVillage,
    CadastralExtent,
    CadastralParcel,
    CadastralFeatureCollection,
    CadastralErrorResponse,
)
from providers.odisha_4kgeo_provider import Odisha4KGEOProvider

from datetime import datetime, timezone

logger = logging.getLogger("bhumitra.routers.gis")

router = APIRouter(prefix="/api/v1/gis", tags=["Cadastral GIS"])

# Singleton Provider instance
provider = Odisha4KGEOProvider()


@router.get("/health", summary="Cadastral GIS Health Probe")
async def gis_health():
    """Returns official provider connectivity, git version, and timestamp."""
    try:
        districts = await provider.get_districts()
        provider_status = "reachable" if len(districts) > 0 else "unreachable"
    except Exception as e:
        provider_status = f"unreachable: {str(e)}"
    
    return {
        "status": "healthy" if provider_status == "reachable" else "degraded",
        "gis_provider": "ODISHA_4K_GEO",
        "provider_status": provider_status,
        "app_version": "1.0.0",
        "git_commit": "fd44311",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@router.get(
    "/districts",
    response_model=List[CadastralDistrict],
    summary="Get all official districts",
)
async def get_districts():
    try:
        return await provider.get_districts()
    except Exception as e:
        logger.error(f"GIS_DISTRICTS_ERROR: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="CADASTRAL_SOURCE_UNAVAILABLE",
                message="Unable to fetch districts from official cadastral provider.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/blocks",
    response_model=List[CadastralBlock],
    summary="Get all blocks/tahasils for a district",
)
async def get_blocks(
    district_id: str = Query(..., description="District identifier (e.g. '224' or '07')"),
    district_name: Optional[str] = Query(None, description="Optional district name"),
):
    try:
        return await provider.get_blocks(district_id=district_id, district_name=district_name)
    except Exception as e:
        logger.error(f"GIS_BLOCKS_ERROR: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="CADASTRAL_SOURCE_UNAVAILABLE",
                message=f"Unable to fetch blocks for district {district_id} from official provider.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/gps",
    response_model=List[CadastralGP],
    summary="Get all Gram Panchayats for a block",
)
async def get_gps(
    block_id: str = Query(..., description="Block/Tahasil identifier (e.g. '0704')"),
    block_name: Optional[str] = Query(None, description="Optional block name"),
    district_name: Optional[str] = Query(None, description="Optional district name"),
):
    try:
        return await provider.get_gram_panchayats(
            block_id=block_id, block_name=block_name, district_name=district_name
        )
    except Exception as e:
        logger.error(f"GIS_GPS_ERROR: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="CADASTRAL_SOURCE_UNAVAILABLE",
                message=f"Unable to fetch Gram Panchayats for block {block_id}.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/villages",
    response_model=List[CadastralVillage],
    summary="Get all revenue villages for a GP/Block",
)
async def get_villages(
    block_id: str = Query(..., description="Block identifier (e.g. '0704')"),
    gp_id: Optional[str] = Query(None, description="Optional Gram Panchayat code (e.g. '07040001')"),
    block_name: Optional[str] = Query(None, description="Optional block name"),
    district_name: Optional[str] = Query(None, description="Optional district name"),
):
    try:
        return await provider.get_villages(
            gp_id=gp_id,
            block_id=block_id,
            block_name=block_name,
            district_name=district_name,
        )
    except Exception as e:
        logger.error(f"GIS_VILLAGES_ERROR: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="CADASTRAL_SOURCE_UNAVAILABLE",
                message=f"Unable to fetch villages for block {block_id}.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/village/{village_id}/extent",
    response_model=Optional[CadastralExtent],
    summary="Get bounding extent for a revenue village",
)
async def get_village_extent(
    village_id: str,
    gp_id: Optional[str] = Query(None, description="Optional GP code"),
):
    try:
        extent = await provider.get_village_extent(village_id=village_id, gp_id=gp_id)
        if not extent:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Extent not found for village {village_id}",
            )
        return extent
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"GIS_EXTENT_ERROR: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="CADASTRAL_SOURCE_UNAVAILABLE",
                message=f"Unable to fetch extent for village {village_id}.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/village/{village_id}/parcels",
    response_model=CadastralFeatureCollection,
    summary="Get official cadastral parcel polygons for a revenue village",
)
async def get_village_parcels(
    village_id: str,
    district_name: Optional[str] = Query(None, description="District name (e.g. 'Keonjhar')"),
    block_name: Optional[str] = Query(None, description="Block name (e.g. 'Keonjhar Sadar')"),
    gp_name: Optional[str] = Query(None, description="Gram Panchayat name"),
    village_name: Optional[str] = Query(None, description="Village name"),
):
    try:
        return await provider.get_village_parcels(
            village_id=village_id,
            district_name=district_name,
            block_name=block_name,
            gp_name=gp_name,
            village_name=village_name,
        )
    except Exception as e:
        logger.error(f"GIS_PARCELS_ERROR: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="CADASTRAL_SOURCE_UNAVAILABLE",
                message=f"Unable to fetch cadastral parcels for village {village_id} from official 4K GEO source.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/village/{village_id}/plot/{plot_number:path}",
    response_model=CadastralParcel,
    summary="Get single cadastral parcel by exact plot number",
)
async def get_parcel_by_plot(
    village_id: str,
    plot_number: str,
    district_name: Optional[str] = Query(None, description="District name"),
    block_name: Optional[str] = Query(None, description="Block name"),
    gp_name: Optional[str] = Query(None, description="Gram Panchayat name"),
    village_name: Optional[str] = Query(None, description="Village name"),
):
    try:
        parcel = await provider.get_parcel_by_plot(
            village_id=village_id,
            exact_plot_number=plot_number,
            district_name=district_name,
            block_name=block_name,
            gp_name=gp_name,
            village_name=village_name,
        )
        if not parcel:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Plot '{plot_number}' was not found in village '{village_id}' in official cadastral records.",
            )
        return parcel
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"GIS_PARCEL_PLOT_ERROR: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="CADASTRAL_SOURCE_UNAVAILABLE",
                message=f"Unable to retrieve plot {plot_number} for village {village_id}.",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/parcel/identify",
    response_model=CadastralParcel,
    summary="Identify cadastral parcel by GPS (lat, lng) within a village",
)
async def identify_parcel_by_coordinate(
    lat: float = Query(..., description="Latitude in decimal degrees (e.g. 21.6365)"),
    lng: float = Query(..., description="Longitude in decimal degrees (e.g. 85.6565)"),
    village_id: str = Query(..., description="Revenue village code (e.g. '0704317')"),
    district_name: Optional[str] = Query(None, description="District name"),
    block_name: Optional[str] = Query(None, description="Block name"),
    gp_name: Optional[str] = Query(None, description="Gram Panchayat name"),
    village_name: Optional[str] = Query(None, description="Village name"),
):
    try:
        parcel = await provider.get_parcel_by_coordinate(
            lat=lat,
            lng=lng,
            village_id=village_id,
            district_name=district_name,
            block_name=block_name,
            gp_name=gp_name,
            village_name=village_name,
        )
        if not parcel:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No cadastral parcel contains coordinate ({lat}, {lng}) in village '{village_id}'.",
            )
        return parcel
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"GIS_IDENTIFY_ERROR: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=CadastralErrorResponse(
                error_code="CADASTRAL_SOURCE_UNAVAILABLE",
                message=f"Spatial parcel identification failed for ({lat}, {lng}).",
                details=str(e),
            ).model_dump(),
        )


@router.get(
    "/coverage/diagnostic",
    summary="Cadastral Coverage Discovery Diagnostic Tool (Admin/Dev)",
    description="Inspects dynamic 4K GEO coverage, extent availability, parcel counts, and geometry types for a village.",
)
async def coverage_diagnostic(
    village_id: str = Query(..., description="Official Revenue Village Code (e.g. '0704317')"),
    district_name: Optional[str] = Query(None, description="Optional district name"),
    block_name: Optional[str] = Query(None, description="Optional block name"),
    gp_id: Optional[str] = Query(None, description="Optional GP code"),
):
    """Admin diagnostic tool returning 4K GEO availability and geometry metadata."""
    extent_status = "UNAVAILABLE"
    extent_data = None
    try:
        ext = await provider.get_village_extent(village_id=village_id, gp_id=gp_id)
        if ext:
            extent_status = "PASS"
            extent_data = ext.model_dump()
    except Exception as e:
        extent_status = f"FAIL: {e}"

    parcels_status = "UNAVAILABLE"
    parcel_count = 0
    polygon_count = 0
    multipolygon_count = 0
    invalid_plot_numbers = 0
    plots_sample = []

    try:
        fc = await provider.get_village_parcels(
            village_id=village_id,
            district_name=district_name,
            block_name=block_name,
        )
        parcel_count = fc.total_parcels
        parcels_status = "PASS" if parcel_count > 0 else "ZERO_PARCELS"

        for feat in fc.features:
            g_type = feat.geometry.type
            if g_type == "Polygon":
                polygon_count += 1
            elif g_type == "MultiPolygon":
                multipolygon_count += 1
            
            p_num = feat.properties.get("plot_number")
            if not p_num or p_num == "UNKNOWN":
                invalid_plot_numbers += 1
            elif len(plots_sample) < 10:
                plots_sample.append(p_num)
    except Exception as e:
        parcels_status = f"FAIL: {e}"

    return {
        "village_id": village_id,
        "district_name": district_name,
        "block_name": block_name,
        "hierarchy_status": "PASS",
        "extent_status": extent_status,
        "extent": extent_data,
        "parcels_status": parcels_status,
        "total_parcels": parcel_count,
        "polygon_count": polygon_count,
        "multipolygon_count": multipolygon_count,
        "invalid_plot_numbers": invalid_plot_numbers,
        "sample_plots": plots_sample,
    }
