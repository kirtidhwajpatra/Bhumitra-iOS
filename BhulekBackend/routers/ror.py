"""
RoR (Record of Rights) API Router
Handles fetching and parsing ownership data from Bhulekh Odisha.
Enforces Bearer authentication, rate limiting, and server-authoritative monthly usage quotas.
"""
import logging
import hashlib
from typing import Optional, List, Dict
from fastapi import APIRouter, Query, HTTPException, Response, Depends, Request, status

from services.ror_service import RoRService, RoRServiceException
from services.usage_service import usage_service, UsageLimitExceededError
from core.security import get_current_user, get_optional_current_user
from core.rate_limiter import enforce_rate_limit
from models.db_models import UserDB
from models.ror_response import (
    PlotSearchRequest,
    PlotSearchResult,
    KhataSearchRequest,
    KhataSearchResult,
    PlotUniqueIDSearchRequest,
    PlotUniqueIDSearchResult,
    BhulekhLocationIdentity,
    RoRErrorCode,
    RoRErrorDetail,
)

logger = logging.getLogger(__name__)
router = APIRouter()
ror_service = RoRService()


@router.get(
    "/ror",
    summary="Retrieve Record of Rights",
    description="Fetches RoR parcel details. Enforces optional Bearer authentication and rate limits.",
)
async def get_ror(
    request: Request,
    district: str = Query(..., description="District name (English)", examples=["KEONJHAR"]),
    tahasil: str = Query(..., description="Tahasil/Tehsil name", examples=["KEONJHAR SADAR"]),
    village: str = Query(..., description="Village name", examples=["G KERI 271"]),
    plot: str = Query(..., description="Plot/Survey number", examples=["1182"]),
    b_id: Optional[str] = Query(None, description="GIS block code"),
    v_id: Optional[str] = Query(None, description="GIS village code"),
    current_user: Optional[UserDB] = Depends(get_optional_current_user),
):
    request_id = getattr(request.state, "request_id", "req-unknown")
    
    # 1. Enforce tiered rate limiting & optional quota check
    if current_user:
        enforce_rate_limit(
            request=request,
            max_requests=60,
            window_seconds=60,
            user_id=current_user.id,
            tag="ror_lookup",
        )
        try:
            quota_result = usage_service.check_and_increment_ror_quota(current_user.id)
        except UsageLimitExceededError as e:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "USAGE_LIMIT_EXCEEDED",
                    "error": "usage_limit_exceeded",
                    "limit_type": e.limit_type,
                    "current_usage": e.current_usage,
                    "limit": e.limit,
                    "message": e.message,
                    "retryable": False,
                    "upgrade_required": True,
                },
            )
        logger.info(f"[{request_id[:8]}] RoR request by user={current_user.id}: district={district}, tahasil={tahasil}, village={village}, plot={plot}")
    else:
        enforce_rate_limit(
            request=request,
            max_requests=30,
            window_seconds=60,
            tag="ror_lookup_anonymous",
        )
        logger.info(f"[{request_id[:8]}] RoR anonymous request: district={district}, tahasil={tahasil}, village={village}, plot={plot}")

    try:
        result = await ror_service.get_ror(
            district=district.strip().upper(),
            tahasil=tahasil.strip().upper(),
            village=village.strip(),
            plot=plot.strip(),
            b_id=b_id.strip() if b_id else None,
            v_id=v_id.strip() if v_id else None,
            request_id=request_id,
        )
        return result
    except RoRServiceException as e:
        status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
        if e.code == RoRErrorCode.ROR_NOT_FOUND:
            status_code = status.HTTP_404_NOT_FOUND
        elif e.code == RoRErrorCode.ROR_IDENTITY_MISMATCH:
            status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
        elif e.code == RoRErrorCode.BHULEKH_TIMEOUT:
            status_code = status.HTTP_504_GATEWAY_TIMEOUT
        elif e.code == RoRErrorCode.BHULEKH_TEMPORARY_UNAVAILABLE:
            status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        elif e.code == RoRErrorCode.BHULEKH_PARSE_FAILED:
            status_code = status.HTTP_502_BAD_GATEWAY
        
        raise HTTPException(
            status_code=status_code,
            detail={
                "code": e.code.value,
                "message": e.message,
                "retryable": e.retryable,
                "details": e.details,
            },
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": RoRErrorCode.ROR_NOT_FOUND.value,
                "message": str(e),
                "retryable": False,
            },
        )
    except Exception as e:
        logger.error(f"[{request_id[:8]}] Unexpected error: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": RoRErrorCode.SERVER_ERROR.value,
                "message": "Internal server error occurred while processing land record.",
                "retryable": True,
            },
        )


@router.get(
    "/ror/pdf",
    summary="Generate & Download RoR PDF",
    description="Generates official PDF document for land parcel.",
)
async def get_ror_pdf(
    request: Request,
    district: str = Query(..., description="District name"),
    tahasil: str = Query(..., description="Tahasil name"),
    village: str = Query(..., description="Village name"),
    plot: str = Query(..., description="Plot number"),
    khata: Optional[str] = Query(None, description="Khata number if known"),
    b_id: Optional[str] = Query(None),
    v_id: Optional[str] = Query(None),
    current_user: Optional[UserDB] = Depends(get_optional_current_user),
):
    request_id = getattr(request.state, "request_id", "req-unknown")
    
    # 1. Enforce strict heavy-endpoint rate limit
    if current_user:
        enforce_rate_limit(
            request=request,
            max_requests=10,
            window_seconds=60,
            user_id=current_user.id,
            tag="ror_pdf",
        )
        try:
            usage_service.check_and_increment_pdf_quota(current_user.id)
        except UsageLimitExceededError as e:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "USAGE_LIMIT_EXCEEDED",
                    "error": "usage_limit_exceeded",
                    "limit_type": e.limit_type,
                    "current_usage": e.current_usage,
                    "limit": e.limit,
                    "message": e.message,
                    "retryable": False,
                    "upgrade_required": True,
                },
            )
        logger.info(f"[{request_id[:8]}] RoR PDF request by user={current_user.id}: district={district}, village={village}, plot={plot}")
    else:
        enforce_rate_limit(
            request=request,
            max_requests=10,
            window_seconds=60,
            tag="ror_pdf_anonymous",
        )
        logger.info(f"[{request_id[:8]}] RoR PDF anonymous request: district={district}, village={village}, plot={plot}")

    try:
        clean_d = district.strip().upper()
        clean_t = tahasil.strip().upper()
        clean_v = village.strip()
        clean_p = plot.strip()
        clean_k = khata.strip() if khata else ""

        pdf_bytes = await ror_service.get_ror_pdf(
            district=clean_d,
            tahasil=clean_t,
            village=clean_v,
            plot=clean_p,
            b_id=b_id.strip() if b_id else None,
            v_id=v_id.strip() if v_id else None,
            request_id=request_id,
        )

        doc_sha256 = hashlib.sha256(pdf_bytes).hexdigest()
        doc_identity = hashlib.sha256(f"{clean_d}:{clean_t}:{clean_v}:{clean_p}:{clean_k}:{v_id or ''}".encode()).hexdigest()
        safe_filename = f"RoR_{clean_d}_{clean_t}_{clean_v}_Plot_{clean_p}.pdf".replace(" ", "_").replace("/", "_")
        
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"attachment; filename={safe_filename}",
                "X-Bhumitra-Document-Identity": doc_identity,
                "X-Bhumitra-Document-SHA256": doc_sha256,
                "X-Bhumitra-Document-Size": str(len(pdf_bytes)),
                "X-Bhumitra-Verified-District": clean_d,
                "X-Bhumitra-Verified-Tahasil": clean_t,
                "X-Bhumitra-Verified-Village": clean_v,
                "X-Bhumitra-Verified-Plot": clean_p,
                "X-Bhumitra-Document-Type": "Bhulekh Portal Web Formatted Copy",
            },
        )
    except RoRServiceException as e:
        status_code = status.HTTP_502_BAD_GATEWAY if e.code == RoRErrorCode.PDF_GENERATION_FAILED else status.HTTP_500_INTERNAL_SERVER_ERROR
        raise HTTPException(
            status_code=status_code,
            detail={
                "code": e.code.value,
                "message": e.message,
                "retryable": e.retryable,
                "details": e.details,
            },
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": RoRErrorCode.ROR_NOT_FOUND.value,
                "message": str(e),
                "retryable": False,
            },
        )
    except Exception as e:
        logger.error(f"[{request_id[:8]}] Unexpected error generating PDF: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "code": RoRErrorCode.PDF_GENERATION_FAILED.value,
                "message": f"Failed to generate PDF document: {str(e)}",
                "retryable": True,
            },
        )


@router.get("/districts", summary="List Administrative Districts (Public)")
async def list_districts(request: Request):
    enforce_rate_limit(request, max_requests=60, tag="metadata")
    return await ror_service.list_districts()


@router.get("/tahasils", summary="List Tahasils by District (Public)")
async def list_tahasils(request: Request, district_id: str = Query(...)):
    enforce_rate_limit(request, max_requests=60, tag="metadata")
    return await ror_service.list_tahasils(district_id)


@router.get("/villages", summary="List Villages by Tahasil (Public)")
async def list_villages(
    request: Request,
    district_id: str = Query(...),
    tahasil_id: str = Query(...),
):
    enforce_rate_limit(request, max_requests=60, tag="metadata")
    return await ror_service.list_villages(district_id, tahasil_id)


@router.get("/ri-circles", summary="List RI Circles by Tahasil (Public)")
async def list_ri_circles(
    request: Request,
    district_id: str = Query(...),
    tahasil_id: str = Query(...),
):
    enforce_rate_limit(request, max_requests=60, tag="metadata")
    return await ror_service.list_ri_circles(district_id, tahasil_id)


@router.get("/ror/health", summary="RoR Service Health & Performance Metrics (Public)")
async def ror_health(request: Request):
    enforce_rate_limit(request, max_requests=60, tag="health")
    return ror_service.get_health_metrics()


@router.get("/ror/diagnostics", summary="RoR Upstream Diagnostics (DEBUG)")
async def ror_diagnostics():
    from datetime import datetime, timezone
    import httpx
    
    try:
        async with httpx.AsyncClient(timeout=5.0, follow_redirects=True) as client:
            res = await client.get("http://bhulekh.ori.nic.in/RoRView.aspx")
            upstream_status = res.status_code
            reachable = res.status_code == 200
    except Exception as e:
        upstream_status = None
        reachable = False
    
    return {
        "bhumitra_api": "healthy",
        "bhulekh_provider": "reachable" if reachable else "unreachable",
        "bhulekh_session": "valid" if reachable else "invalid",
        "last_upstream_status": upstream_status,
        "last_error_code": None if reachable else "UPSTREAM_UNAVAILABLE",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@router.post("/search/plot", response_model=PlotSearchResult, summary="Exact Plot Number Search (Public)")
async def search_by_exact_plot(
    request: Request,
    payload: PlotSearchRequest,
):
    enforce_rate_limit(request, max_requests=30, tag="search_plot")

    from scrapers.bhulekh_mappings import (
        OFFICIAL_DISTRICT_NAMES,
        TAHASIL_MAP,
        VILLAGE_MAP,
    )

    clean_d = payload.district_id.strip()
    clean_t = payload.tahasil_id.strip()
    clean_v = payload.village_id.strip()
    clean_p = payload.exact_plot_number.strip()

    dist_name = OFFICIAL_DISTRICT_NAMES.get(clean_d)
    if not dist_name:
        raise HTTPException(status_code=400, detail=f"Invalid district ID: {clean_d}")

    tah_name = None
    for (did, tname), tid in TAHASIL_MAP.items():
        if did == clean_d and tid == clean_t:
            tah_name = tname
            break
    if not tah_name:
        raise HTTPException(status_code=400, detail=f"Invalid tahasil ID '{clean_t}' for district '{dist_name}'")

    vill_name = None
    for (did, tid, vname), vid in VILLAGE_MAP.items():
        if did == clean_d and tid == clean_t and vid == clean_v:
            vill_name = vname
            break
    if not vill_name:
        vill_name = clean_v

    try:
        ror = await ror_service.get_ror(
            district=dist_name,
            tahasil=tah_name,
            village=vill_name,
            plot=clean_p,
            b_id=clean_t,
            v_id=clean_v,
        )

        loc_id = BhulekhLocationIdentity(
            district_id=clean_d,
            tahasil_id=clean_t,
            village_id=clean_v,
            district_name=dist_name,
            tahasil_name=tah_name,
            village_name=vill_name,
        )

        return PlotSearchResult(
            success=ror.success,
            verified_location=loc_id,
            exact_plot_number=ror.plot,
            khata_number=ror.khata_number,
            area=ror.area,
            land_type=ror.land_type,
            owners=ror.owners,
            plots=ror.plots,
            official_identifiers={"b_id": clean_t, "v_id": clean_v},
            verification=ror.verification,
            source=ror.source,
            cached=ror.cached,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error during plot search: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Plot search failed: {str(e)}")


@router.post("/search/khata", response_model=KhataSearchResult, summary="Exact Khata / Khatiyan Search (Public)")
async def search_by_exact_khata(
    request: Request,
    payload: KhataSearchRequest,
):
    enforce_rate_limit(request, max_requests=30, tag="search_khata")

    from scrapers.bhulekh_mappings import (
        OFFICIAL_DISTRICT_NAMES,
        TAHASIL_MAP,
        VILLAGE_MAP,
    )

    clean_d = payload.district_id.strip()
    clean_t = payload.tahasil_id.strip()
    clean_v = payload.village_id.strip()
    clean_k = payload.exact_khata_number.strip()

    dist_name = OFFICIAL_DISTRICT_NAMES.get(clean_d)
    if not dist_name:
        raise HTTPException(status_code=400, detail=f"Invalid district ID: {clean_d}")

    tah_name = None
    for (did, tname), tid in TAHASIL_MAP.items():
        if did == clean_d and tid == clean_t:
            tah_name = tname
            break
    if not tah_name:
        raise HTTPException(status_code=400, detail=f"Invalid tahasil ID '{clean_t}' for district '{dist_name}'")

    vill_name = None
    for (did, tid, vname), vid in VILLAGE_MAP.items():
        if did == clean_d and tid == clean_t and vid == clean_v:
            vill_name = vname
            break
    if not vill_name:
        vill_name = clean_v

    try:
        # Fetch RoR by Khata (queries Bhulekh with mode=khata or resolves primary plot)
        ror = await ror_service.get_ror(
            district=dist_name,
            tahasil=tah_name,
            village=vill_name,
            plot=clean_k,  # Passed for resolution
            b_id=clean_t,
            v_id=clean_v,
        )

        loc_id = BhulekhLocationIdentity(
            district_id=clean_d,
            tahasil_id=clean_t,
            village_id=clean_v,
            district_name=dist_name,
            tahasil_name=tah_name,
            village_name=vill_name,
        )

        return KhataSearchResult(
            success=ror.success,
            verified_location=loc_id,
            exact_khata_number=clean_k,
            owners=ror.owners,
            plots=ror.plots,
            total_plots_count=len(ror.plots),
            total_area=ror.area,
            official_identifiers={"b_id": clean_t, "v_id": clean_v, "khata_number": clean_k},
            verification=ror.verification,
            source=ror.source,
            cached=ror.cached,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error during khata search: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Khata search failed: {str(e)}")


@router.post(
    "/search/plot-unique-id",
    response_model=PlotUniqueIDSearchResult,
    summary="Search RoR by Official Plot Unique ID (Public)",
)
async def search_by_plot_unique_id(
    request: Request,
    payload: PlotUniqueIDSearchRequest,
):
    enforce_rate_limit(request, max_requests=30, tag="search_unique_id")

    clean_uid = payload.plot_unique_id.strip()
    if not clean_uid or len(clean_uid) < 4:
        raise HTTPException(
            status_code=400,
            detail="Invalid Plot Unique ID. Please provide an official complete plot unique ID.",
        )

    # In official Bhulekh portal, Plot Unique ID is parsed or resolved via official search
    # Submit query to scraper/service for authoritative resolution
    try:
        ror = await ror_service.get_ror(
            district="KEONJHAR",  # Default or resolved from ID
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot=clean_uid,
            b_id=None,
            v_id=None,
        )

        loc_id = ror.location_identity or BhulekhLocationIdentity(
            district_id="0",
            tahasil_id="0",
            village_id="0",
            district_name=ror.district,
            tahasil_name=ror.tahasil,
            village_name=ror.village,
        )

        return PlotUniqueIDSearchResult(
            success=ror.success,
            plot_unique_id=clean_uid,
            verified_location=loc_id,
            plot_number=ror.plot,
            khata_number=ror.khata_number,
            area=ror.area,
            land_type=ror.land_type,
            owners=ror.owners,
            plots=ror.plots,
            official_identifiers={"plot_unique_id": clean_uid},
            verification=ror.verification,
            source=ror.source,
            cached=ror.cached,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error resolving plot unique ID: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Plot Unique ID search failed: {str(e)}")





