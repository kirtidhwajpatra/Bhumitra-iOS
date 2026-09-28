"""
Location Search & Spatial Resolution Router
============================================
Exposes:
  - GET  /api/v1/location/search   : Fast place discovery, local 51k village search, intent routing.
  - POST /api/v1/location/resolve  : Authoritative coordinate-to-cadastral resolution via Step 1 Spatial Resolver.
  - GET  /api/v1/location/resolve  : Query-parameter variant of spatial resolution for URL-based navigation.
"""

import time
import logging
from typing import Optional, List, Dict, Any, Tuple
from fastapi import APIRouter, Query, HTTPException, Body
from pydantic import BaseModel, Field

from services.location_search_service import (
    location_search_service,
    LocationSearchResponse,
    KNOWN_VILLAGE_COORDINATES,
)
from services.spatial_resolver_service import (
    spatial_resolver_service,
    LocationResolutionStatus,
    CandidateVillage,
    haversine_distance_meters,
)

logger = logging.getLogger("bhumitra.routers.location_search")

router = APIRouter()


def find_nearby_candidate_villages(lat: float, lng: float, max_distance_meters: float = 6000.0) -> List[str]:
    """Finds known village candidate codes within proximity for fast targeted resolution."""
    candidates = []
    for (did, tid, mid), (vlat, vlng) in KNOWN_VILLAGE_COORDINATES.items():
        d = haversine_distance_meters(lat, lng, vlat, vlng)
        if d <= max_distance_meters:
            code = f"{int(did):02d}{int(tid):02d}{int(mid):03d}"
            candidates.append((code, d))
    candidates.sort(key=lambda x: x[1])
    return [c[0] for c in candidates]


# ==============================================================================
# Request & Response Models for Resolution
# ==============================================================================

class CandidateVillageSummary(BaseModel):
    village_id: str = Field(..., description="7-digit village code")
    village_name: str = Field(..., description="Village name")
    village_name_odia: Optional[str] = Field(None, description="Odia name if available")
    tahasil_name: Optional[str] = Field(None, description="Parent tahasil name")
    district_name: Optional[str] = Field(None, description="Parent district name")
    distance_meters: float = Field(..., description="Distance in meters from coordinate")
    reason: str = Field(..., description="Candidate inclusion justification")


class LocationResolveRequest(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0, description="WGS84 Latitude (-90 to +90)")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="WGS84 Longitude (-180 to +180)")
    plot_number: Optional[str] = Field(None, description="Optional target plot number to verify")
    candidate_village_ids: Optional[List[str]] = Field(None, description="Optional list of candidate village IDs to scope search")


class LocationResolveResponse(BaseModel):
    status: LocationResolutionStatus = Field(..., description="Authoritative resolution state")
    latitude: float = Field(..., description="Resolved latitude")
    longitude: float = Field(..., description="Resolved longitude")

    district: Optional[str] = Field(None, description="Official district name")
    district_id: Optional[str] = Field(None, description="Official district ID")

    tahasil: Optional[str] = Field(None, description="Official tahasil name")
    tahasil_id: Optional[str] = Field(None, description="Official tahasil ID")

    revenue_village: Optional[str] = Field(None, description="Official canonical revenue village name")
    revenue_village_id: Optional[str] = Field(None, description="Official 7-digit village code")
    bhulekh_mouza_id: Optional[str] = Field(None, description="Bhulekh portal mouza numeric ID")

    plot_number: Optional[str] = Field(None, description="Containing cadastral plot number")

    resolution_reason: str = Field(..., description="Clear explanation of resolution outcome")
    candidates: List[CandidateVillageSummary] = Field(default_factory=list, description="Candidate villages when status is AMBIGUOUS")
    executionTimeMs: float = Field(..., description="Resolution latency in milliseconds")
    extraMetadata: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Supplementary cadastral metadata")


# ==============================================================================
# Helper Function for Common Spatial Resolution Logic
# ==============================================================================

async def _execute_resolution(
    latitude: float,
    longitude: float,
    plot_number: Optional[str] = None,
    candidate_village_ids: Optional[List[str]] = None,
) -> LocationResolveResponse:
    t0 = time.time()
    effective_candidates = candidate_village_ids or find_nearby_candidate_villages(latitude, longitude) or None
    try:
        res = await spatial_resolver_service.resolve_coordinate(
            lat=latitude,
            lng=longitude,
            candidate_village_ids=effective_candidates,
            plot_number=plot_number,
        )

        candidates_summary = [
            CandidateVillageSummary(
                village_id=c.village_id,
                village_name=c.village_name,
                village_name_odia=c.village_name_odia,
                tahasil_name=c.tahasil_name,
                district_name=c.district_name,
                distance_meters=c.distance_meters,
                reason=c.reason,
            )
            for c in res.candidates
        ]

        exec_ms = round((time.time() - t0) * 1000, 2)

        tahasil_clean = None
        if res.tahasil and res.tahasil.name:
            import re
            tahasil_clean = re.sub(r"\s*\(M\.Corp\.?\)|\s*\(CT\)", "", res.tahasil.name, flags=re.I).strip()

        return LocationResolveResponse(
            status=res.status,
            latitude=res.latitude,
            longitude=res.longitude,
            district=res.district.name if res.district else None,
            district_id=res.district.id if res.district else None,
            tahasil=tahasil_clean,
            tahasil_id=res.tahasil.bhulekh_id or res.tahasil.id if res.tahasil else None,
            revenue_village=res.village.name if res.village else None,
            revenue_village_id=res.village.id if res.village else None,
            bhulekh_mouza_id=res.village.bhulekh_mouza_id if res.village else None,
            plot_number=res.parcel.plot_number if res.parcel else None,
            resolution_reason=res.message or str(res.status.value),
            candidates=candidates_summary,
            executionTimeMs=exec_ms,
            extraMetadata=res.provenance or {},
        )
    except Exception as e:
        logger.error(f"LOCATION_RESOLVE_FAILED: lat={latitude}, lng={longitude}: {e}", exc_info=True)
        exec_ms = round((time.time() - t0) * 1000, 2)
        return LocationResolveResponse(
            status=LocationResolutionStatus.PARCEL_SOURCE_TEMPORARILY_UNAVAILABLE,
            latitude=latitude,
            longitude=longitude,
            resolution_reason=f"Resolution service encountered an unexpected error: {str(e)}",
            candidates=[],
            executionTimeMs=exec_ms,
        )


# ==============================================================================
# Endpoints
# ==============================================================================

@router.get(
    "/location/search",
    response_model=LocationSearchResponse,
    summary="Search for locations, villages, landmarks, plots, or coordinates",
    description="Multi-tier search: intent routing, local 51k canonical village catalog, and provider-agnostic POI discovery.",
)
async def search_location(
    q: str = Query(..., description="Search query string"),
    limit: int = Query(10, ge=1, le=50, description="Maximum suggestions to return (1-50)"),
    bbox: Optional[str] = Query(None, description="Optional bounding box 'min_lng,min_lat,max_lng,max_lat'"),
    district_id: Optional[str] = Query(None, description="Optional parent district filter ID"),
    tahasil_id: Optional[str] = Query(None, description="Optional parent tahasil filter ID"),
    near: Optional[str] = Query(None, description="Optional proximity hint 'lat,lng' used to rank same-named villages"),
) -> LocationSearchResponse:
    # 1. Validate Query
    clean_q = q.strip()
    if not clean_q:
        raise HTTPException(
            status_code=400,
            detail="Search query must not be empty or whitespace only",
        )
    if len(q) > 200:
        raise HTTPException(
            status_code=400,
            detail="Search query exceeds maximum length of 200 characters",
        )

    # 2. Validate Bounding Box
    parsed_bbox: Optional[List[float]] = None
    if bbox:
        try:
            parts = [float(p.strip()) for p in bbox.split(",")]
            if len(parts) != 4:
                raise ValueError("Expected 4 comma-separated values")
            # Verify coordinates are valid geographic coordinates
            if not (-180.0 <= parts[0] <= 180.0 and -90.0 <= parts[1] <= 90.0 and -180.0 <= parts[2] <= 180.0 and -90.0 <= parts[3] <= 90.0):
                raise ValueError("Coordinates out of geographic range")
            parsed_bbox = parts
        except ValueError as e:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid bbox format: Expected 'min_lng,min_lat,max_lng,max_lat'. {str(e)}",
            )

    # 3. Validate Context IDs if provided
    if district_id and (len(district_id) > 10 or not district_id.replace("_", "").isalnum()):
        raise HTTPException(status_code=400, detail="Invalid district_id parameter")
    if tahasil_id and (len(tahasil_id) > 10 or not tahasil_id.replace("_", "").isalnum()):
        raise HTTPException(status_code=400, detail="Invalid tahasil_id parameter")

    # 3b. Validate proximity hint (ignored rather than rejected if outside Odisha,
    # so a user travelling elsewhere still gets normal results).
    parsed_near: Optional[Tuple[float, float]] = None
    if near:
        try:
            n_parts = [float(p.strip()) for p in near.split(",")]
            if len(n_parts) != 2:
                raise ValueError("Expected 'lat,lng'")
            n_lat, n_lng = n_parts
            if not (-90.0 <= n_lat <= 90.0 and -180.0 <= n_lng <= 180.0):
                raise ValueError("Coordinates out of geographic range")
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid near format: Expected 'lat,lng'. {str(e)}")
        if 17.0 <= n_lat <= 23.5 and 81.0 <= n_lng <= 88.0:
            parsed_near = (n_lat, n_lng)

    # 4. Execute Search
    try:
        response = await location_search_service.search(
            query=clean_q,
            limit=limit,
            bbox=parsed_bbox,
            district_id=district_id,
            tahasil_id=tahasil_id,
            near=parsed_near,
        )
        return response
    except Exception as e:
        logger.error(f"LOCATION_SEARCH_ERROR: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Location search failed: {str(e)}")


@router.post(
    "/location/resolve",
    response_model=LocationResolveResponse,
    summary="Resolve coordinates to official Odisha cadastral jurisdiction (POST)",
    description="Passes coordinates through the Step 1 Spatial Resolver. Resolves official district, tahasil, revenue village, and containing plot.",
)
async def resolve_location_post(
    payload: LocationResolveRequest = Body(..., description="Coordinate and optional scoping parameters"),
) -> LocationResolveResponse:
    return await _execute_resolution(
        latitude=payload.latitude,
        longitude=payload.longitude,
        plot_number=payload.plot_number,
        candidate_village_ids=payload.candidate_village_ids,
    )


@router.get(
    "/location/resolve",
    response_model=LocationResolveResponse,
    summary="Resolve coordinates to official Odisha cadastral jurisdiction (GET)",
    description="URL query-parameter variant for resolving coordinates to official cadastral jurisdiction.",
)
async def resolve_location_get(
    lat: float = Query(..., ge=-90.0, le=90.0, description="WGS84 Latitude (-90 to +90)"),
    lng: float = Query(..., ge=-180.0, le=180.0, description="WGS84 Longitude (-180 to +180)"),
    plot_number: Optional[str] = Query(None, description="Optional target plot number"),
    village_ids: Optional[str] = Query(None, description="Optional comma-separated candidate village IDs"),
) -> LocationResolveResponse:
    candidates = [v.strip() for v in village_ids.split(",") if v.strip()] if village_ids else None
    return await _execute_resolution(
        latitude=lat,
        longitude=lng,
        plot_number=plot_number,
        candidate_village_ids=candidates,
    )
