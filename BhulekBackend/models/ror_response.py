"""
Pydantic response, verification, and identity models for the RoR API.
"""
from enum import Enum
from pydantic import BaseModel
from typing import List, Optional, Dict, Any


class RoRVerificationStatus(str, Enum):
    VERIFIED = "VERIFIED"
    MISMATCH = "MISMATCH"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"
    SOURCE_ERROR = "SOURCE_ERROR"


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


class RoRVerification(BaseModel):
    status: RoRVerificationStatus
    requested_district: str
    requested_tahasil: str
    requested_village: str
    requested_plot: str
    returned_district: Optional[str] = None
    returned_tahasil: Optional[str] = None
    returned_village: Optional[str] = None
    returned_plot: Optional[str] = None
    location_match: bool = False
    plot_match: bool = False
    details: str


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
    verification: Optional[RoRVerification] = None
    source: str = "bhulekh.ori.nic.in"
    cached: bool = False
