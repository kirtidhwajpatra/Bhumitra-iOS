"""
Canonical Cadastral Models for Bhumitra GIS Layer
Source of Truth for Geometry: Odisha 4K GEO (ORSAC)
Ownership details are strictly excluded to preserve single responsibility.
"""

from typing import List, Optional, Dict, Any, Union
from pydantic import BaseModel, Field
from datetime import datetime, timezone


class CadastralDistrict(BaseModel):
    id: str = Field(..., description="Unique District identifier (e.g. '224' or '07')")
    name: str = Field(..., description="Official District Name (e.g. 'Keonjhar')")


class CadastralBlock(BaseModel):
    id: str = Field(..., description="Unique Block/Tahasil identifier (e.g. '0704')")
    name: str = Field(..., description="Official Block/Tahasil Name (e.g. 'Keonjhar Sadar')")
    district_id: str = Field(..., description="Parent District identifier")


class CadastralGP(BaseModel):
    id: str = Field(..., description="Unique Gram Panchayat code (e.g. '07040001')")
    name: str = Field(..., description="Official Gram Panchayat Name (e.g. 'Dimbo')")
    block_id: str = Field(..., description="Parent Block/Tahasil identifier")


class CadastralVillage(BaseModel):
    id: str = Field(..., description="Unique Revenue Village code (e.g. '0704317')")
    name: str = Field(..., description="Official Revenue Village Name (e.g. 'G_Dimbo')")
    gp_id: Optional[str] = Field(None, description="Parent Gram Panchayat identifier if applicable")
    block_id: str = Field(..., description="Parent Block identifier")
    district_id: Optional[str] = Field(None, description="Parent District identifier")


class CadastralExtent(BaseModel):
    min_lng: float
    min_lat: float
    max_lng: float
    max_lat: float
    center_lng: float
    center_lat: float


class CadastralParcel(BaseModel):
    source: str = Field(default="ODISHA_4K_GEO", description="Originating cadastral provider")
    source_feature_id: Optional[str] = Field(None, description="Feature ID from provider if available")
    district_id: str
    district_name: Optional[str] = None
    block_id: str
    block_name: Optional[str] = None
    gp_id: Optional[str] = None
    village_id: str
    village_name: Optional[str] = None
    plot_number: str = Field(..., description="Exact verbatim plot number string (e.g. '1182', '12/1')")
    geometry: Dict[str, Any] = Field(..., description="GeoJSON geometry object in WGS84 EPSG:4326")
    centroid: List[float] = Field(..., description="[lng, lat] coordinate array in EPSG:4326")
    properties: Dict[str, Any] = Field(default_factory=dict, description="Raw provider properties")
    retrieved_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat(),
        description="ISO timestamp when parcel geometry was retrieved",
    )


class CadastralParcelFeature(BaseModel):
    type: str = "Feature"
    id: Optional[str] = None
    geometry: Dict[str, Any]
    properties: Dict[str, Any]


class CadastralFeatureCollection(BaseModel):
    type: str = "FeatureCollection"
    source: str = "ODISHA_4K_GEO"
    village_id: str
    village_name: Optional[str] = None
    total_parcels: int
    retrieved_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    features: List[CadastralParcelFeature]


class CadastralErrorResponse(BaseModel):
    success: bool = False
    error_code: str = "CADASTRAL_SOURCE_UNAVAILABLE"
    message: str
    details: Optional[str] = None
