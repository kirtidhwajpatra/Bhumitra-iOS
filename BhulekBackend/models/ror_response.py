"""
Pydantic response models for the RoR API.
"""
from pydantic import BaseModel
from typing import List, Optional


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
    raw_fields: dict = {}                 # All scraped key-value pairs for debugging
    source: str = "bhulekh.ori.nic.in"
    cached: bool = False
