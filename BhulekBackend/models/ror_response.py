"""
Pydantic response, verification, location hierarchy, and identity models for the RoR API.
"""
from enum import Enum
from pydantic import BaseModel
from typing import List, Optional, Dict, Any


class RoRVerificationStatus(str, Enum):
    VERIFIED = "VERIFIED"
    MISMATCH = "MISMATCH"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"
    SOURCE_ERROR = "SOURCE_ERROR"


class BhulekhDistrict(BaseModel):
    id: str
    official_name: str


class BhulekhTahasil(BaseModel):
    id: str
    district_id: str
    official_name: str


class BhulekhVillage(BaseModel):
    id: str
    tahasil_id: str
    district_id: str
    official_name: str


class BhulekhRICircle(BaseModel):
    id: str
    tahasil_id: str
    district_id: str
    village_id: Optional[str] = None
    official_name: str


class BhulekhPlot(BaseModel):
    plot_number: str
    plot_id: Optional[str] = None
    village_id: str
    tahasil_id: str
    district_id: str


class BhulekhKhata(BaseModel):
    khata_number: str
    village_id: str
    tahasil_id: str
    district_id: str


class BhulekhTenant(BaseModel):
    tenant_name: str
    khata_number: Optional[str] = None
    village_id: str
    tahasil_id: str
    district_id: str


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


class AssociatedPlot(BaseModel):
    plot_number: str
    area: Optional[str] = None
    land_type: Optional[str] = None
    rent_cess: Optional[str] = None
    remarks: Optional[str] = None


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
    plots: List[AssociatedPlot] = []      # All associated plots in this Khata
    raw_fields: dict = {}                 # Scraped key-value pairs
    location_identity: Optional[BhulekhLocationIdentity] = None
    verification: Optional[RoRVerification] = None
    source: str = "bhulekh.ori.nic.in"
    cached: bool = False


class PlotSearchRequest(BaseModel):
    district_id: str
    tahasil_id: str
    village_id: str
    exact_plot_number: str


class PlotSearchResult(BaseModel):
    success: bool
    verified_location: BhulekhLocationIdentity
    exact_plot_number: str
    khata_number: Optional[str] = None
    area: Optional[str] = None
    land_type: Optional[str] = None
    owners: List[OwnerEntry] = []
    plots: List[AssociatedPlot] = []
    official_identifiers: Dict[str, str] = {}
    verification: RoRVerification
    source: str = "bhulekh.ori.nic.in"
    cached: bool = False


class KhataSearchRequest(BaseModel):
    district_id: str
    tahasil_id: str
    village_id: str
    exact_khata_number: str


class KhataSearchResult(BaseModel):
    success: bool
    verified_location: BhulekhLocationIdentity
    exact_khata_number: str
    owners: List[OwnerEntry] = []
    plots: List[AssociatedPlot] = []
    total_plots_count: int = 0
    total_area: Optional[str] = None
    official_identifiers: Dict[str, str] = {}
    verification: RoRVerification
    source: str = "bhulekh.ori.nic.in"
    cached: bool = False


class PlotUniqueIDSearchRequest(BaseModel):
    plot_unique_id: str


class PlotUniqueIDSearchResult(BaseModel):
    success: bool
    plot_unique_id: str
    verified_location: BhulekhLocationIdentity
    plot_number: str
    khata_number: Optional[str] = None
    area: Optional[str] = None
    land_type: Optional[str] = None
    owners: List[OwnerEntry] = []
    plots: List[AssociatedPlot] = []
    official_identifiers: Dict[str, str] = {}
    verification: RoRVerification
    source: str = "bhulekh.ori.nic.in"
    cached: bool = False



