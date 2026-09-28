"""
Response models for the Uttar Pradesh map-layer prototype (UP BhuNaksha).

Deliberately minimal: plot number, khata number and area only. Owner names are
public on the upstream portal but are never parsed into, stored in, or returned
from these models.
"""
from typing import List, Optional
from pydantic import BaseModel, Field


class UPLevelItem(BaseModel):
    code: str
    name: str


class UPLevelResponse(BaseModel):
    level: int
    parent_codes: List[str] = Field(default_factory=list)
    items: List[UPLevelItem]
    label: Optional[str] = None


class UPVillageExtent(BaseModel):
    gis_code: str
    district_code: str
    tehsil_code: str
    village_code: str
    crs: str
    # Native UTM extent (as returned by UP BhuNaksha)
    utm_bbox: List[float]  # [minx, miny, maxx, maxy]
    # WGS84 extent for the app camera: [min_lng, min_lat, max_lng, max_lat]
    bbox: List[float]
    center_lat: float
    center_lng: float


class UPPlotRecord(BaseModel):
    khata_no: str
    plot_no: str
    area: Optional[float] = None
    area_unit: Optional[str] = None


class UPPlotResult(BaseModel):
    gis_code: str
    plot_no: str
    plot_id: Optional[str] = None
    # WGS84 bounding box of the plot: [min_lng, min_lat, max_lng, max_lat]
    bbox: List[float]
    records: List[UPPlotRecord] = Field(default_factory=list)
    # Short-lived signed token for /wms/selection/{token}. Minted per response
    # by the router (never cached with the plot) so it is always fresh.
    selection_token: Optional[str] = None
    source: str = "UP_BHUNAKSHA"
    official_record_url: str = "https://upbhulekh.gov.in/"
    note: str = "Map view (beta). Official plot outline; not an official record."
