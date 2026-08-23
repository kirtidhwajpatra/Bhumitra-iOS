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


class ResolutionStatusEnum(str, Enum):
    RESOLVED = "RESOLVED"
    NOT_FOUND = "NOT_FOUND"
    AMBIGUOUS = "AMBIGUOUS"
    UNSUPPORTED = "UNSUPPORTED"


class BhulekhResolutionResult(BaseModel):
    """Explicit structured result of GIS-to-Bhulekh identity resolution."""
    status: ResolutionStatusEnum
    gis_identity: Dict[str, Any]
    bhulekh_identity: Optional[BhulekhLocationIdentity] = None
    resolution_method: str = "EXACT_CATALOG_MATCH"
    evidence_level: str = "LEVEL_2_LIVE_DROPDOWN"
    confidence_reason: str = "Live dropdown option verified in catalog_v3."


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
    identity_match_method: Optional[str] = None
    name_match_status: Optional[str] = None
    canonical_identity: Optional[str] = None


class OwnerEntry(BaseModel):
    name: str
    relation: Optional[str] = None        # e.g., "Father", "Husband", "ପି:"
    relation_name: Optional[str] = None   # Name of relation
    share: Optional[str] = None           # Fractional share of plot (if available)
    khata_number: Optional[str] = None    # Khata linked to this owner
    ownership_details: Optional[str] = None


class AssociatedPlot(BaseModel):
    plot_number: str
    area: Optional[str] = None
    land_type: Optional[str] = None
    rent_cess: Optional[str] = None
    remarks: Optional[str] = None


class RoRErrorCode(str, Enum):
    ROR_NOT_FOUND = "ROR_NOT_FOUND"
    ROR_IDENTITY_MISMATCH = "ROR_IDENTITY_MISMATCH"
    CATALOG_NOT_FOUND = "CATALOG_NOT_FOUND"
    VILLAGE_NOT_MAPPED = "VILLAGE_NOT_MAPPED"
    MOUZA_NOT_FOUND = "MOUZA_NOT_FOUND"
    AMBIGUOUS_LOCATION = "AMBIGUOUS_LOCATION"
    BHULEKH_CATALOG_NOT_FOUND = "BHULEKH_CATALOG_NOT_FOUND"
    BHULEKH_LOCATION_AMBIGUOUS = "BHULEKH_LOCATION_AMBIGUOUS"
    BHULEKH_LOCATION_STATE_MISMATCH = "BHULEKH_LOCATION_STATE_MISMATCH"
    BHULEKH_PLOT_NOT_FOUND = "BHULEKH_PLOT_NOT_FOUND"
    BHULEKH_PLOT_MISMATCH = "BHULEKH_PLOT_MISMATCH"
    BHULEKH_IDENTITY_VERIFICATION_FAILED = "BHULEKH_IDENTITY_VERIFICATION_FAILED"
    BHULEKH_OWNER_DATA_NOT_FOUND = "BHULEKH_OWNER_DATA_NOT_FOUND"
    BHULEKH_UNAVAILABLE = "BHULEKH_UNAVAILABLE"
    BHULEKH_TEMPORARILY_UNAVAILABLE = "BHULEKH_TEMPORARILY_UNAVAILABLE"
    BHULEKH_TEMPORARY_UNAVAILABLE = "BHULEKH_TEMPORARY_UNAVAILABLE"
    BHULEKH_TIMEOUT = "BHULEKH_TIMEOUT"
    BHULEKH_RATE_LIMITED = "BHULEKH_RATE_LIMITED"
    BHULEKH_AUTH_SESSION_FAILED = "BHULEKH_AUTH_SESSION_FAILED"
    BHULEKH_PARSE_FAILED = "BHULEKH_PARSE_FAILED"
    PLOT_NOT_FOUND = "PLOT_NOT_FOUND"
    PLOT_MISMATCH = "PLOT_MISMATCH"
    IDENTITY_MISMATCH = "IDENTITY_MISMATCH"
    VERIFICATION_FAILED = "VERIFICATION_FAILED"
    PARSE_FAILED = "PARSE_FAILED"
    PDF_FAILED = "PDF_FAILED"
    PDF_GENERATION_FAILED = "PDF_GENERATION_FAILED"
    PDF_DOWNLOAD_FAILED = "PDF_DOWNLOAD_FAILED"
    NETWORK_ERROR = "NETWORK_ERROR"
    SERVER_ERROR = "SERVER_ERROR"


class RoRErrorDetail(BaseModel):
    code: RoRErrorCode
    message: str
    retryable: bool = False
    details: Optional[str] = None


class VerifiedRoRIdentity(BaseModel):
    """Canonical immutable parcel identity mapping GIS to official Bhulekh Odisha."""
    district_id: str
    tahasil_id: str
    mouza_id: str
    district_name: str
    tahasil_name: str
    mouza_name: str
    plot_number: str
    gp_name: Optional[str] = None
    gp_id: Optional[str] = None
    gis_village_name: Optional[str] = None
    gis_village_id: Optional[str] = None
    source_feature_id: Optional[str] = None
    identity_evidence_level: str = "LEVEL_2_LIVE_DROPDOWN"
    catalog_version: str = "2026-08-19.2"
    verification_status: str = "VERIFIED"


class VerifiedRoRRecord(BaseModel):
    """Canonical ownership and parcel record extracted exclusively from official Bhulekh portal."""
    district: str
    tahasil: str
    mouza: str
    plot_number: str
    khata_number: Optional[str] = None
    area: Optional[str] = None
    area_unit: Optional[str] = "Acre"
    land_classification: Optional[str] = None
    rent: Optional[str] = None
    cess: Optional[str] = None
    owners: List[OwnerEntry] = []
    tenant_name: Optional[str] = None
    source: str = "ODISHA_BHULEKH"
    verification_status: str = "VERIFIED"


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
    forensic_debug: Optional[Dict[str, Any]] = None
    error: Optional[RoRErrorDetail] = None
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



