"""
Authoritative Canonical Village Identity Model
Defines structured, auditable village/mouza identities connecting ORSAC 4K GEO GIS with Odisha Bhulekh.
"""
from enum import Enum
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field


class VillageVerificationStatus(str, Enum):
    VERIFIED = "VERIFIED"
    UNVERIFIED = "UNVERIFIED"
    AMBIGUOUS = "AMBIGUOUS"
    UNRESOLVED = "UNRESOLVED"


class CanonicalVillageIdentity(BaseModel):
    """
    Canonical representation of a village/mouza bridging GIS and Bhulekh.
    """
    # District Level
    district_id: str = Field(..., description="Official Bhulekh District ID (e.g. '7' for Keonjhar)")
    district_name: str = Field(..., description="English District Name (e.g. 'KEONJHAR')")
    district_name_odia: Optional[str] = Field(None, description="Odia District Name (e.g. 'କେନ୍ଦୁଝର')")

    # Tahasil Level
    tahasil_id: str = Field(..., description="Official Bhulekh Tahasil ID (e.g. '4' for Keonjhar Sadar)")
    tahasil_name: str = Field(..., description="English Tahasil Name (e.g. 'KEONJHAR SADAR')")
    tahasil_name_odia: Optional[str] = Field(None, description="Odia Tahasil Name (e.g. 'ସଦର')")

    # GIS Village Identifiers
    gis_village_name: str = Field(..., description="Raw or normalized GIS village name from ORSAC 4K GEO")
    gis_village_code: Optional[str] = Field(None, description="7-digit census or administrative code if present")
    gis_block_id: Optional[str] = Field(None, description="4-digit GIS block ID if present")

    # Bhulekh Official Location Identifiers
    bhulekh_mouza_id: Optional[str] = Field(None, description="Official Bhulekh Mouza/Village form index ID")
    bhulekh_village_name_odia: Optional[str] = Field(None, description="Official Odia Mouza name on portal")
    bhulekh_village_name_normalized: Optional[str] = Field(None, description="Phonetically normalized Mouza name")

    # Provenance & Audit Metadata
    source: str = Field("catalog_v3", description="Provenance source (catalog_v3, live_dropdown, exact_id)")
    confidence: float = Field(1.0, ge=0.0, le=1.0, description="Resolution confidence score")
    verification_status: VillageVerificationStatus = Field(
        VillageVerificationStatus.UNRESOLVED,
        description="Strict verification status"
    )
    details: Optional[str] = Field(None, description="Audit notes explaining resolution path")
