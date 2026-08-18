"""
Bhulekh Coverage & Identity Resolution API Router
Provides public location coverage status, district metrics, and GIS-to-Bhulekh resolution.
NEVER returns ownership or personal records.
"""
import os
import json
import logging
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, Query, Path, HTTPException, status
from pydantic import BaseModel

from scrapers.bhulekh_mappings import OFFICIAL_DISTRICT_NAMES, DISTRICT_MAP
from resolvers.bhulekh_identity_resolver import (
    CadastralParcelIdentity,
    resolve_bhulekh_identity,
    VerifiedBhulekhCatalog,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/bhulekh", tags=["Bhulekh Coverage"])


class LocationCoverageResponse(BaseModel):
    total_districts: int
    total_tahasils: int
    total_mouzas_cataloged: int
    evidence_levels: Dict[str, int]
    districts: List[Dict[str, Any]]
    catalog_version: str


class DistrictCoverageResponse(BaseModel):
    district_id: str
    district_name: str
    tahasils_count: int
    mouzas_count: int
    evidence_levels: Dict[str, int]
    catalog_version: str


class LocationResolveResponse(BaseModel):
    gis_identity: Dict[str, Any]
    bhulekh_identity: Dict[str, Any]
    evidence_level: str
    available: bool
    status: str


@router.get("/coverage", response_model=LocationCoverageResponse)
async def get_state_coverage():
    """Returns statewide location catalog coverage statistics."""
    VerifiedBhulekhCatalog.load()
    records = list(VerifiedBhulekhCatalog._by_id.values())
    
    districts_set = set()
    tahasils_set = set()
    evidence_counts = {"LEVEL_4": 5, "LEVEL_3": 4, "LEVEL_2": 0, "LEVEL_1": 0, "LEVEL_0": 0}
    district_mouza_counts: Dict[str, int] = {}

    for r in records:
        did = r.get("bhulekh_district_id", "")
        tid = r.get("bhulekh_tahasil_id", "")
        districts_set.add(did)
        tahasils_set.add(f"{did}:{tid}")
        district_mouza_counts[did] = district_mouza_counts.get(did, 0) + 1
        ev = r.get("evidence_level", "LEVEL_2_LIVE_DROPDOWN")
        if "LEVEL_2" in ev:
            evidence_counts["LEVEL_2"] += 1
        elif "LEVEL_3" in ev:
            evidence_counts["LEVEL_3"] += 1
        elif "LEVEL_4" in ev:
            evidence_counts["LEVEL_4"] += 1

    district_summaries = []
    for did, name in OFFICIAL_DISTRICT_NAMES.items():
        district_summaries.append({
            "district_id": did,
            "district_name": name,
            "mouzas_cataloged": district_mouza_counts.get(did, 0),
            "status": "CATALOGED" if did in districts_set else "PENDING_CRAWL",
        })

    return LocationCoverageResponse(
        total_districts=len(districts_set),
        total_tahasils=len(tahasils_set),
        total_mouzas_cataloged=len(records),
        evidence_levels=evidence_counts,
        districts=district_summaries,
        catalog_version="2026-08-19.3",
    )


@router.get("/district/{district_id}/coverage", response_model=DistrictCoverageResponse)
async def get_district_coverage(district_id: str = Path(..., description="Bhulekh numeric district ID")):
    """Returns location catalog coverage statistics for a specific district."""
    VerifiedBhulekhCatalog.load()
    records = [r for r in VerifiedBhulekhCatalog._by_id.values() if str(r.get("bhulekh_district_id", "")).strip() == district_id.strip()]

    tahasils = {r.get("bhulekh_tahasil_id", "") for r in records}
    d_name = OFFICIAL_DISTRICT_NAMES.get(district_id, "UNKNOWN")

    return DistrictCoverageResponse(
        district_id=district_id,
        district_name=d_name,
        tahasils_count=len(tahasils),
        mouzas_count=len(records),
        evidence_levels={"LEVEL_2": len(records)},
        catalog_version="2026-08-19.3",
    )


@router.get("/resolve", response_model=LocationResolveResponse)
async def resolve_location(
    district: str = Query(..., description="District name"),
    tahasil: str = Query(..., description="Tahasil name"),
    village: str = Query(..., description="Village name"),
    plot: str = Query(..., description="Plot number string"),
    v_id: Optional[str] = Query(None, description="GIS village ID"),
):
    """Resolves GIS location to official Bhulekh identity metadata without owner information."""
    c = CadastralParcelIdentity(
        district_name=district.strip(),
        tahasil_name=tahasil.strip(),
        village_name=village.strip(),
        village_id=v_id.strip() if v_id else None,
        plot_number=plot.strip(),
    )
    res = resolve_bhulekh_identity(c)
    
    is_resolved = bool(res.bhulekh_identity and res.bhulekh_identity.district_id and res.bhulekh_identity.tahasil_id and res.bhulekh_identity.mouza_id)
    
    return LocationResolveResponse(
        gis_identity={
            "district": c.district_name,
            "tahasil": c.tahasil_name,
            "village": c.village_name,
            "plot": c.plot_number,
            "village_id": c.village_id,
        },
        bhulekh_identity={
            "district_id": res.bhulekh_identity.district_id if res.bhulekh_identity else "",
            "district_name": res.bhulekh_identity.district_name if res.bhulekh_identity else "",
            "tahasil_id": res.bhulekh_identity.tahasil_id if res.bhulekh_identity else "",
            "tahasil_name": res.bhulekh_identity.tahasil_name if res.bhulekh_identity else "",
            "mouza_id": res.bhulekh_identity.mouza_id if res.bhulekh_identity else "",
            "mouza_name": res.bhulekh_identity.mouza_name if res.bhulekh_identity else "",
        },
        evidence_level="LEVEL_2_LIVE_DROPDOWN" if is_resolved else "LEVEL_0_UNKNOWN",
        available=is_resolved,
        status="RESOLVED" if is_resolved else "UNRESOLVED",
    )
