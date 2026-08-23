"""
Pydantic Data Model for GIS to Official Bhulekh Village Identity Crosswalk.
Represents deterministic, auditable 1-to-1 administrative identity mappings.
"""
from datetime import datetime, timezone
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class CrosswalkMappingStatus(str, Enum):
    VERIFIED = "VERIFIED"
    AMBIGUOUS = "AMBIGUOUS"
    UNRESOLVED = "UNRESOLVED"


class GISBhulekhVillageCrosswalkRecord(BaseModel):
    """Explicit mapping record between GIS Cadastral identity and Official Bhulekh identity."""
    gis_district_id: str = Field(..., description="Official Odisha District ID (1-30)")
    gis_district_name: str = Field(..., description="Canonical English District Name")
    gis_tahasil_name: Optional[str] = Field(None, description="GIS Tahasil Container / Super-Region Label")
    gis_village_name: str = Field(..., description="GIS Village Name in English or Odia")
    gis_village_code: Optional[str] = Field(None, description="7-digit LGD / Census / Village Code if available")
    gis_feature_id: Optional[str] = Field(None, description="ORSAC / GeoJSON feature ID")

    bhulekh_district_id: str = Field(..., description="Official Bhulekh District ID")
    bhulekh_tahasil_id: str = Field(..., description="Official Bhulekh Tahasil ID")
    bhulekh_mouza_id: str = Field(..., description="Official Bhulekh Mouza / Village ID")
    bhulekh_village_name: str = Field(..., description="Official Bhulekh Mouza Odia Name")

    mapping_status: CrosswalkMappingStatus = Field(default=CrosswalkMappingStatus.VERIFIED)
    evidence_type: str = Field(default="OFFICIAL_SOAP_CATALOG")
    evidence: str = Field(..., description="Deterministic matching evidence")
    catalog_version: str = Field(default="ODISHA_BHULEKH_VILLAGE_CATALOG_V1")
    created_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class GISBhulekhCrosswalkCatalog(BaseModel):
    """Root container for verified crosswalk dataset."""
    catalog_version: str = "ODISHA_BHULEKH_VILLAGE_CROSSWALK_V1"
    generated_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    source: str = "OFFICIAL_BHULEKH_SOAP_STATEWIDE"
    checksum_sha256: Optional[str] = None
    records: list[GISBhulekhVillageCrosswalkRecord] = Field(default_factory=list)
