"""
Pydantic response and identity models for the RoR API.
"""
from pydantic import BaseModel
from typing import List, Optional, Dict, Any


class BhulekhLocationIdentity(BaseModel):
    district_id: str
    tahasil_id: str
    village_id: str
    district_name: str
    tahasil_name: str
    village_name: str


class BhulekhPlotIdentity(BaseModel):
    location: BhulekhLocationIdentity
    plot_number: str


class OwnerEntry(BaseModel):
    name: str
    share: Optional[str] = None           # Fractional share of plot (if available)
    khata_number: Optional[str] = None    # Khata linked to this owner


class RoRResponse(BaseModel):
    success: bool
    plot: str
    village: str
    district: str
    tahasil: str
    khata_number: Optional[str] = None
    area: Optional[str] = None            # e.g. "0.450 Acre"
    land_type: Optional[str] = None       # e.g. "Govt", "Ryoti"
    owners: List[OwnerEntry] = []
    raw_fields: dict = {}                 # Scraped key-value pairs
    location_identity: Optional[BhulekhLocationIdentity] = None
    source: str = "bhulekh.ori.nic.in"
    cached: bool = False
