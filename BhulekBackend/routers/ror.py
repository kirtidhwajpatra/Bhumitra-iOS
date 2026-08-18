"""
RoR (Record of Rights) API Router
Handles fetching and parsing ownership data from Bhulekh Odisha.
Enforces Bearer authentication, rate limiting, and server-authoritative monthly usage quotas.
"""
import logging
from typing import Optional, List, Dict
from fastapi import APIRouter, Query, HTTPException, Response, Depends, Request, status

from services.ror_service import RoRService
from services.usage_service import usage_service, UsageLimitExceededError
from core.security import get_current_user
from core.rate_limiter import enforce_rate_limit
from models.db_models import UserDB

logger = logging.getLogger(__name__)
router = APIRouter()
ror_service = RoRService()


@router.get(
    "/ror",
    summary="Retrieve Record of Rights (Protected & Quota Enforced)",
    description="Fetches RoR parcel details. Enforces Bearer authentication and server-side monthly quota limits.",
)
async def get_ror(
    request: Request,
    district: str = Query(..., description="District name (English)", examples=["KEONJHAR"]),
    tahasil: str = Query(..., description="Tahasil/Tehsil name", examples=["KEONJHAR SADAR"]),
    village: str = Query(..., description="Village name", examples=["G KERI 271"]),
    plot: str = Query(..., description="Plot/Survey number", examples=["1182"]),
    b_id: Optional[str] = Query(None, description="GIS block code"),
    v_id: Optional[str] = Query(None, description="GIS village code"),
    current_user: UserDB = Depends(get_current_user),
):
    # 1. Enforce tiered rate limiting
    enforce_rate_limit(
        request=request,
        max_requests=60,
        window_seconds=60,
        user_id=current_user.id,
        tag="ror_lookup",
    )

    # 2. Check and atomically increment monthly server quota
    try:
        quota_result = usage_service.check_and_increment_ror_quota(current_user.id)
    except UsageLimitExceededError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "usage_limit_exceeded",
                "limit_type": e.limit_type,
                "current_usage": e.current_usage,
                "limit": e.limit,
                "message": e.message,
                "upgrade_required": True,
            },
        )

    logger.info(f"RoR request by user={current_user.id}: district={district}, tahasil={tahasil}, village={village}, plot={plot}, is_premium={quota_result['is_premium']}")

    try:
        result = await ror_service.get_ror(
            district=district.strip().upper(),
            tahasil=tahasil.strip().upper(),
            village=village.strip(),
            plot=plot.strip(),
            b_id=b_id.strip() if b_id else None,
            v_id=v_id.strip() if v_id else None,
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ConnectionError as e:
        raise HTTPException(status_code=503, detail=f"Bhulekh portal unavailable: {str(e)}")
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get(
    "/ror/pdf",
    summary="Generate & Download RoR PDF (Protected & Quota Enforced)",
    description="Generates official PDF document for land parcel. Rate-limited and quota-enforced.",
)
async def get_ror_pdf(
    request: Request,
    district: str = Query(..., description="District name"),
    tahasil: str = Query(..., description="Tahasil name"),
    village: str = Query(..., description="Village name"),
    plot: str = Query(..., description="Plot number"),
    b_id: Optional[str] = Query(None),
    v_id: Optional[str] = Query(None),
    current_user: UserDB = Depends(get_current_user),
):
    # 1. Enforce strict heavy-endpoint rate limit
    enforce_rate_limit(
        request=request,
        max_requests=10,
        window_seconds=60,
        user_id=current_user.id,
        tag="ror_pdf",
    )

    # 2. Check and atomically increment monthly PDF download quota
    try:
        usage_service.check_and_increment_pdf_quota(current_user.id)
    except UsageLimitExceededError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "usage_limit_exceeded",
                "limit_type": e.limit_type,
                "current_usage": e.current_usage,
                "limit": e.limit,
                "message": e.message,
                "upgrade_required": True,
            },
        )

    logger.info(f"RoR PDF request by user={current_user.id}: district={district}, village={village}, plot={plot}")

    try:
        clean_d = district.strip().upper()
        clean_t = tahasil.strip().upper()
        clean_v = village.strip()
        clean_p = plot.strip()

        pdf_bytes = await ror_service.get_ror_pdf(
            district=clean_d,
            tahasil=clean_t,
            village=clean_v,
            plot=clean_p,
            b_id=b_id.strip() if b_id else None,
            v_id=v_id.strip() if v_id else None,
        )

        safe_filename = f"RoR_{clean_d}_{clean_t}_{clean_v}_Plot_{clean_p}.pdf".replace(" ", "_").replace("/", "_")
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"attachment; filename={safe_filename}",
                "X-Bhumitra-Verified-District": clean_d,
                "X-Bhumitra-Verified-Tahasil": clean_t,
                "X-Bhumitra-Verified-Village": clean_v,
                "X-Bhumitra-Verified-Plot": clean_p,
                "X-Bhumitra-Document-Type": "Bhulekh Portal Web Formatted Copy",
            },
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error generating PDF: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to generate PDF document: {str(e)}")


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
