"""
Parcel Truth Record Model for Phase 3 Accuracy & Regression Framework
Defines typed schemas for ground-truth land records across Odisha.
"""
from typing import List, Dict, Optional, Any
from enum import Enum
from pydantic import BaseModel, Field


class ValidationLevel(int, Enum):
    LEVEL_0_HTTP_SUCCESS = 0
    LEVEL_1_GIS_IDENTITY = 1
    LEVEL_2_BHULEKH_IDENTITY = 2
    LEVEL_3_EXACT_PLOT = 3
    LEVEL_4_RECORD_ASSOCIATION = 4
    LEVEL_5_MANUAL_OFFICIAL_VERIFICATION = 5


class AccuracyCategory(str, Enum):
    PASS = "PASS"
    PARTIAL = "PARTIAL"
    FAIL = "FAIL"
    UNRESOLVED = "UNRESOLVED"
    ERROR = "ERROR"


class TruthSourceType(str, Enum):
    INDEPENDENT_OFFICIAL = "INDEPENDENT_OFFICIAL"
    CATALOG_DERIVED = "CATALOG_DERIVED"
    APPLICATION_DERIVED = "APPLICATION_DERIVED"
    SYNTHETIC = "SYNTHETIC"
    UNKNOWN = "UNKNOWN"


class ParcelTruthOwner(BaseModel):
    name: str
    relation: Optional[str] = "UNKNOWN"
    relation_name: Optional[str] = "UNKNOWN"
    share: Optional[str] = "1.000"
    khata_number: Optional[str] = "UNKNOWN"


class ParcelTruthRecord(BaseModel):
    test_id: str
    category: str  # PRIVATE_LAND, GOVT_LAND, MULTI_OWNER, MULTI_PLOT_KHATA, FRACTIONAL_PLOT, NEGATIVE_TEST, HISTORICAL_REGRESSION
    truth_source_type: TruthSourceType = TruthSourceType.INDEPENDENT_OFFICIAL
    validation_level_target: int = 4
    district: str
    district_id: str
    tahasil: str
    tahasil_id: str
    village_name: str
    village_id: Optional[str] = "UNKNOWN"
    mouza_name: Optional[str] = "UNKNOWN"
    mouza_id: Optional[str] = "UNKNOWN"
    gis_parcel_id: Optional[str] = "UNKNOWN"
    gis_plot_number: str
    official_plot_number: str
    official_khata_number: Optional[str] = "UNKNOWN"
    official_owners: List[ParcelTruthOwner] = Field(default_factory=list)
    official_land_classification: Optional[str] = "UNKNOWN"
    official_acreage: Optional[str] = "UNKNOWN"
    source: str = "OFFICIAL_BHULEKH_PORTAL"
    verification_date: str = "2026-08-22"
    verification_method: str = "OFFICIAL_PORTAL_CROSS_AUDIT"
    expected_status: AccuracyCategory = AccuracyCategory.PASS
    is_negative_test: bool = False
    historical_failure_type: Optional[str] = "NONE"
    notes: Optional[str] = ""
