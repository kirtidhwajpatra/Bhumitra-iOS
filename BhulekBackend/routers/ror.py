"""
RoR (Record of Rights) API Router
Handles fetching and parsing ownership data from Bhulekh Odisha.
"""
import logging
from fastapi import APIRouter, Query, HTTPException, Response
from typing import Optional, List, Dict
from services.ror_service import RoRService

logger = logging.getLogger(__name__)
router = APIRouter()
ror_service = RoRService()


@router.get("/ror")
async def get_ror(
    district: str = Query(..., description="District name (English)", examples=["KEONJHAR"]),
    tahasil: str = Query(..., description="Tahasil/Tehsil name", examples=["KEONJHAR SADAR"]),
    village: str = Query(..., description="Village name", examples=["G KERI 271"]),
    plot: str = Query(..., description="Plot/Survey number", examples=["1182"]),
    b_id: Optional[str] = Query(None, description="GIS block code (b_id from parcel data, improves tahasil lookup accuracy)"),
    v_id: Optional[str] = Query(None, description="GIS village code (v_id from parcel data, improves village lookup accuracy)"),
):
    """
    Retrieve Record of Rights (RoR) for a land parcel from Bhulekh Odisha.
    Returns owner names, khata number, area, and plot details.
    
    Pass `b_id` (the block/tahasil code from the GIS layer) for more accurate
    tahasil matching — especially for districts where the English transliteration
    is ambiguous.
    
    Responses are cached for 1 hour to reduce repeated portal requests.
    """
    logger.info(f"RoR request: district={district}, tahasil={tahasil}, village={village}, plot={plot}, b_id={b_id}")
    
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


@router.get("/ror/pdf")
async def get_ror_pdf(
    district: str = Query(..., description="District name"),
    tahasil: str = Query(..., description="Tahasil name"),
    village: str = Query(..., description="Village name"),
    plot: str = Query(..., description="Plot number"),
    b_id: Optional[str] = Query(None),
    v_id: Optional[str] = Query(None),
):
    """
    Generate and download the Record of Rights (RoR) as a PDF document.
    """
    logger.info(f"RoR PDF request: district={district}, village={village}, plot={plot}")
    
    try:
        pdf_bytes = await ror_service.get_ror_pdf(
            district=district.strip().upper(),
            tahasil=tahasil.strip().upper(),
            village=village.strip(),
            plot=plot.strip(),
            b_id=b_id.strip() if b_id else None,
            v_id=v_id.strip() if v_id else None,
        )
        
        filename = f"ROR_{district}_{village}_{plot}.pdf".replace(" ", "_")
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"attachment; filename={filename}"
            }
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error generating PDF: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to generate PDF document")
@router.get("/districts")
async def list_districts():
    return await ror_service.list_districts()


@router.get("/tahasils")
async def list_tahasils(district_id: str = Query(...)):
    return await ror_service.list_tahasils(district_id)


@router.get("/villages")
async def list_villages(district_id: str = Query(...), tahasil_id: str = Query(...)):
    return await ror_service.list_villages(district_id, tahasil_id)
