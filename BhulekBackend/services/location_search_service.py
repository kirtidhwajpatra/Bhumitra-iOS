"""
Bhumitra Location Search Service & Provider Adapter
===================================================
Authoritative backend search layer with provider abstraction and intent routing.

Architectural Principles:
  1. Provider Abstraction: GeocoderProvider interface decoupling search from concrete geocoders.
     - Concrete providers: PhotonGeocoderProvider, LocationIQGeocoderProvider, GeoapifyGeocoderProvider, MockGeocoderProvider.
     - Configuration via GEOSPATIAL_SEARCH_PROVIDER environment variable.
     - The iOS app only interacts with Bhumitra's unified API; provider secrets remain 100% server-side.
  2. Local Bhumitra Village Search First:
     - 51k+ official revenue villages loaded from odisha_village_catalog_v1.json.
     - Ultra-fast in-memory index (<1ms query latency, zero external API costs, works 100% offline).
     - Full transliteration and phonetic matching (Odia <-> English) + alias normalisation.
     - Distinguishes duplicate village names with parent GP, Tahasil, and District context.
  3. Strict Intent Routing:
     - COORDINATE: Directly returns parsed GPS coordinates without geocoder calls.
     - PLOT_ONLY: Returns structured PLOT_ONLY asking for village context; never calls geocoder.
     - COMPOUND_PLOT: Extracts plot number and resolves location part separately.
     - REVENUE_VILLAGE: Queries local 51k catalog first.
     - LANDMARK / POI: Uses external geocoder for discovery. Landmark name is discovery metadata ONLY.
     - PIN_CODE: Resolves 6-digit postal code to locality.
     - BROAD_CITY / BROAD_DISTRICT: Returns broad region without arbitrarily guessing a revenue village.
  4. Failure Resilience:
     - Provider outages, timeouts, and HTTP errors are caught gracefully.
     - Local village search remains fully functional even during total external provider failure.
"""

import os
import re
import time
import json
import asyncio
import logging
import hashlib
from abc import ABC, abstractmethod
from enum import Enum
from pathlib import Path
from typing import List, Optional, Dict, Any, Tuple, Set
from pydantic import BaseModel, Field

import httpx
from cachetools import TTLCache

from scrapers.bhulekh_mappings import (
    DISTRICT_MAP,
    TAHASIL_MAP,
    OFFICIAL_DISTRICT_NAMES,
    normalize,
)

# Canonical English tahasil lookup map: (district_id, tahasil_id) -> english_name
_TAHASIL_ENGLISH_MAP: Dict[Tuple[str, str], str] = {}
for (_did, _name), _tid in TAHASIL_MAP.items():
    if _name.isascii() and (_did, _tid) not in _TAHASIL_ENGLISH_MAP:
        _TAHASIL_ENGLISH_MAP[(_did, _tid)] = _name.title()
from resolvers.bhulekh_identity_resolver import (
    odia_to_phonetic,
    normalize_phonetic,
    consonant_skeleton,
    SCOPED_VILLAGE_ALIASES,
    BILINGUAL_VILLAGE_MAP,
    clean_gis_village_name,
)
from resolvers.village_identity_normalizer import (
    normalize_village_name,
    normalize_odia_village_key,
)
from services.gis_navigation_service import gis_navigation_service

logger = logging.getLogger("bhumitra.services.location_search")

# 2-digit Bhulekh/GIS district prefix → 4K GEO district id (e.g. "07" → "224").
# Bhulekh district/tahasil/mouza numbering is the same numbering 4K GEO uses in
# its 7-digit revenue_village_code, so a catalog record maps to a loadable map id.
try:
    from providers.odisha_4kgeo_provider import ODISHA_DISTRICT_CODE_MAP as _GIS_DISTRICT_CODE_MAP
except Exception as _e:  # pragma: no cover - defensive: search must work without the provider
    logger.warning(f"4K GEO district code map unavailable: {_e}")
    _GIS_DISTRICT_CODE_MAP = {}


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    from math import radians, sin, cos, asin, sqrt
    dlat, dlng = radians(lat2 - lat1), radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return 6371.0 * 2 * asin(sqrt(a))

# Odisha Geographic Boundary Envelope [min_lng, min_lat, max_lng, max_lat]
ODISHA_BBOX: List[float] = [81.38, 17.78, 87.53, 22.57]
ODISHA_MIN_LAT: float = 17.70
ODISHA_MAX_LAT: float = 22.65
ODISHA_MIN_LNG: float = 81.30
ODISHA_MAX_LNG: float = 87.60

# Exhaustive list of non-Odisha Indian states/territories to guard against boundary leakage
NON_ODISHA_INDIAN_STATES = {
    "rajasthan", "delhi", "maharashtra", "karnataka", "tamil nadu", "gujarat",
    "uttar pradesh", "bihar", "west bengal", "madhya pradesh", "punjab",
    "haryana", "kerala", "telangana", "andhra pradesh", "jharkhand",
    "chhattisgarh", "assam", "uttarakhand", "himachal pradesh", "goa",
    "tripura", "manipur", "meghalaya", "mizoram", "nagaland", "sikkim",
    "jammu and kashmir", "ladakh", "puducherry", "chandigarh"
}


def is_within_odisha_coordinates(lat: Optional[float], lng: Optional[float]) -> bool:
    """Hard geographic coordinate gate for the state of Odisha."""
    if lat is None or lng is None:
        return False
    return (ODISHA_MIN_LAT <= lat <= ODISHA_MAX_LAT) and (ODISHA_MIN_LNG <= lng <= ODISHA_MAX_LNG)


def is_odisha_candidate(
    lat: Optional[float],
    lng: Optional[float],
    metadata: Optional[Dict[str, Any]] = None,
    display_name: str = ""
) -> bool:
    """
    Hard multi-signal safety gate enforcing ODISHA-ONLY search results.
    Evaluates:
      1. Coordinate boundary validation (must fall within Odisha bbox).
      2. Administrative state metadata (if present, must be Odisha/Orissa).
      3. Administrative country metadata (if present, must be India).
      4. Textual display string safety (rejects explicit non-Odisha state references like 'Jaipur, Rajasthan').
    """
    # 1. Coordinate check
    if not is_within_odisha_coordinates(lat, lng):
        return False

    meta = metadata or {}

    # 2. Administrative state metadata check
    state_raw = str(meta.get("state") or meta.get("state_district") or "").strip().lower()
    if state_raw:
        if state_raw in NON_ODISHA_INDIAN_STATES:
            return False
        # If it has a state value and it's not Odisha/Orissa, reject
        if state_raw not in ("odisha", "orissa") and "odisha" not in state_raw and "orissa" not in state_raw:
            return False

    # 3. Country check
    country_raw = str(meta.get("country") or meta.get("country_code") or "").strip().lower()
    if country_raw and country_raw not in ("india", "in"):
        return False

    # 4. Textual display_name check (e.g. 'Jaipur, Rajasthan, India')
    if display_name:
        low_disp = display_name.lower()
        if "odisha" not in low_disp and "orissa" not in low_disp:
            for non_state in NON_ODISHA_INDIAN_STATES:
                pattern = r'(?:^|[,\s])' + re.escape(non_state) + r'(?:[,\s]|$)'
                if re.search(pattern, low_disp):
                    return False

    return True


# Default provider timeout in seconds
PROVIDER_TIMEOUT_SECONDS = float(os.environ.get("GEOSPATIAL_PROVIDER_TIMEOUT", "4.0"))


# ==============================================================================
# Domain Models & Types
# ==============================================================================

class LocationSearchResultType(str, Enum):
    REVENUE_VILLAGE = "REVENUE_VILLAGE"
    LANDMARK = "LANDMARK"
    LOCALITY = "LOCALITY"
    COORDINATE = "COORDINATE"
    BROAD_DISTRICT = "BROAD_DISTRICT"
    BROAD_CITY = "BROAD_CITY"
    PLOT_ONLY = "PLOT_ONLY"
    COMPOUND_PLOT = "COMPOUND_PLOT"


class SearchIntentType(str, Enum):
    COORDINATE = "COORDINATE"
    PLOT_ONLY = "PLOT_ONLY"
    COMPOUND_PLOT = "COMPOUND_PLOT"
    REVENUE_VILLAGE = "REVENUE_VILLAGE"
    LANDMARK = "LANDMARK"
    PIN_CODE = "PIN_CODE"
    BROAD_DISTRICT = "BROAD_DISTRICT"
    BROAD_CITY = "BROAD_CITY"
    GENERAL = "GENERAL"


class LocationSearchResult(BaseModel):
    id: str = Field(..., description="Stable, deterministic unique identifier")
    title: str = Field(..., description="Primary title (e.g. 'Patia' or 'Plot 547 in Patia')")
    subtitle: str = Field(..., description="Contextual subtitle (e.g. 'Bhubaneswar Tahasil, Khurda District')")
    type: LocationSearchResultType = Field(..., description="Structured type classification")
    latitude: Optional[float] = Field(None, description="WGS84 latitude")
    longitude: Optional[float] = Field(None, description="WGS84 longitude")
    boundingBox: Optional[List[float]] = Field(None, description="[min_lng, min_lat, max_lng, max_lat]")
    source: str = Field(..., description="Originating authority or provider (e.g. 'BHUMITRA_CANONICAL_CATALOG')")
    parsedPlotNumber: Optional[str] = Field(None, description="Extracted plot number if applicable")
    revenueVillageId: Optional[str] = Field(None, description="Canonical 7-digit village ID if applicable")
    extraMetadata: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Supplementary discovery metadata")

    # ── Full village identity (REVENUE_VILLAGE results from the canonical catalog) ──
    # Lets clients open the village directly (no coordinate re-resolution) with the
    # same identity the manual District → Tahasil → Village picker produces.
    district: Optional[str] = Field(None, description="District English name (Bhulekh vocabulary)")
    districtId: Optional[str] = Field(None, description="Bhulekh district ID")
    tahasil: Optional[str] = Field(None, description="Tahasil English name")
    tahasilId: Optional[str] = Field(None, description="Bhulekh tahasil ID")
    revenueVillage: Optional[str] = Field(None, description="Village display name (English transliteration)")
    villageNameOdia: Optional[str] = Field(None, description="Official Odia village name")
    bhulekhMouzaId: Optional[str] = Field(None, description="Bhulekh mouza ID")
    gisDistrictId: Optional[str] = Field(None, description="4K GEO district ID (e.g. '224')")
    gisBlockId: Optional[str] = Field(None, description="4K GEO block code DDTT (e.g. '0704')")
    directLoad: bool = Field(False, description="True when revenueVillageId can load cadastral parcels directly")


class GeocodedPlace(BaseModel):
    id: str
    name: str
    display_name: str
    place_type: str
    latitude: float
    longitude: float
    bounding_box: Optional[List[float]] = None
    source: str
    metadata: Dict[str, Any] = Field(default_factory=dict)


class LocationSearchResponse(BaseModel):
    query: str
    intent: SearchIntentType
    results: List[LocationSearchResult]
    totalResults: int
    provider: str
    executionTimeMs: float


# ==============================================================================
# 1. Geocoder Provider Abstraction & Implementations
# ==============================================================================

class GeocoderProvider(ABC):
    """
    Abstract Geocoder Provider Interface.
    Decouples the search layer from third-party geospatial providers.
    """
    @property
    @abstractmethod
    def provider_name(self) -> str:
        pass

    @abstractmethod
    async def search(
        self,
        query: str,
        bbox: Optional[List[float]] = None,
        limit: int = 10,
    ) -> List[GeocodedPlace]:
        pass


class MockGeocoderProvider(GeocoderProvider):
    """
    In-Memory Mock Geocoder Provider for offline testing, CI, and error simulation.
    """
    def __init__(self):
        self.simulate_timeout: bool = False
        self.simulate_http_error: bool = False
        self.simulate_malformed: bool = False
        self.call_count: int = 0

        # Fixture landmarks and POIs
        self._mock_data: List[Dict[str, Any]] = [
            {
                "id": "mock:kiit_university",
                "name": "KIIT University",
                "display_name": "KIIT University, Patia, Bhubaneswar, Khordha, Odisha",
                "place_type": "landmark",
                "latitude": 20.3533,
                "longitude": 85.8193,
                "bounding_box": [85.8100, 20.3480, 85.8280, 20.3580],
                "keywords": ["kiit", "kiit university", "kalinga institute of industrial technology"],
            },
            {
                "id": "mock:biju_patnaik_airport",
                "name": "Biju Patnaik International Airport",
                "display_name": "Biju Patnaik International Airport, Airport Road, Bhubaneswar, Odisha",
                "place_type": "landmark",
                "latitude": 20.2525,
                "longitude": 85.8178,
                "bounding_box": [85.8050, 20.2450, 85.8300, 20.2600],
                "keywords": ["airport", "biju patnaik airport", "bhubaneswar airport"],
            },
            {
                "id": "mock:bhubaneswar_railway_station",
                "name": "Bhubaneswar Railway Station",
                "display_name": "Bhubaneswar Railway Station, Master Canteen, Bhubaneswar, Odisha",
                "place_type": "landmark",
                "latitude": 20.2667,
                "longitude": 85.8436,
                "bounding_box": [85.8350, 20.2600, 85.8500, 20.2720],
                "keywords": ["railway station", "bhubaneswar railway station", "station"],
            },
            {
                "id": "mock:lingaraj_temple",
                "name": "Lingaraj Temple",
                "display_name": "Lingaraj Temple, Old Town, Bhubaneswar, Khordha, Odisha",
                "place_type": "landmark",
                "latitude": 20.2382,
                "longitude": 85.8336,
                "bounding_box": [85.8300, 20.2340, 85.8380, 20.2420],
                "keywords": ["lingaraj", "lingaraj temple", "temple"],
            },
            {
                "id": "mock:aiims_bhubaneswar",
                "name": "AIIMS Bhubaneswar",
                "display_name": "AIIMS Bhubaneswar, Sijua, Patrapada, Bhubaneswar, Odisha",
                "place_type": "landmark",
                "latitude": 20.2312,
                "longitude": 85.7761,
                "bounding_box": [85.7680, 20.2240, 85.7840, 20.2380],
                "keywords": ["aiims", "aiims hospital", "hospital"],
            },
            {
                "id": "mock:esplanade_one_mall",
                "name": "Esplanade One Mall",
                "display_name": "Esplanade One Mall, Rasulgarh, Bhubaneswar, Odisha",
                "place_type": "landmark",
                "latitude": 20.3015,
                "longitude": 85.8672,
                "bounding_box": [85.8620, 20.2970, 85.8720, 20.3060],
                "keywords": ["esplanade", "shopping mall", "mall"],
            },
            {
                "id": "mock:pin_751024",
                "name": "751024 (KIIT / Patia Area)",
                "display_name": "751024, Patia / Chandrasekharpur, Bhubaneswar, Khordha, Odisha",
                "place_type": "locality",
                "latitude": 20.3540,
                "longitude": 85.8190,
                "bounding_box": [85.8000, 20.3400, 85.8400, 20.3700],
                "keywords": ["751024"],
            },
            {
                "id": "mock:pin_754001",
                "name": "754001 (Athagarh Area)",
                "display_name": "754001, Athagarh, Cuttack, Odisha",
                "place_type": "locality",
                "latitude": 20.5284,
                "longitude": 85.7335,
                "bounding_box": [85.6500, 20.4800, 85.8000, 20.5800],
                "keywords": ["754001"],
            },
            # Non-Odisha test fixtures for hard safety gate regression testing
            {
                "id": "mock:jaipur_rajasthan",
                "name": "Jaipur",
                "display_name": "Jaipur, Jaipur District, Rajasthan, India",
                "place_type": "city",
                "latitude": 26.9124,
                "longitude": 75.7873,
                "bounding_box": [75.7000, 26.8000, 75.9000, 27.0000],
                "keywords": ["jaipur", "jaipur rajasthan"],
                "metadata": {"state": "Rajasthan", "country": "India"},
            },
            {
                "id": "mock:connaught_place_delhi",
                "name": "Connaught Place",
                "display_name": "Connaught Place, New Delhi, Delhi, India",
                "place_type": "locality",
                "latitude": 28.6139,
                "longitude": 77.2090,
                "bounding_box": [77.1000, 28.5000, 77.3000, 28.7000],
                "keywords": ["connaught place", "delhi"],
                "metadata": {"state": "Delhi", "country": "India"},
            },
            {
                "id": "mock:mg_road_bangalore",
                "name": "MG Road",
                "display_name": "MG Road, Bangalore, Karnataka, India",
                "place_type": "locality",
                "latitude": 12.9716,
                "longitude": 77.5946,
                "bounding_box": [77.5000, 12.9000, 77.6500, 13.0500],
                "keywords": ["mg road", "bangalore"],
                "metadata": {"state": "Karnataka", "country": "India"},
            },
        ]

    @property
    def provider_name(self) -> str:
        return "MOCK"

    async def search(
        self,
        query: str,
        bbox: Optional[List[float]] = None,
        limit: int = 10,
    ) -> List[GeocodedPlace]:
        self.call_count += 1

        if self.simulate_timeout:
            await asyncio.sleep(0.01)
            raise asyncio.TimeoutError("Mock provider simulated timeout")

        if self.simulate_http_error:
            raise httpx.HTTPStatusError("500 Internal Server Error", request=None, response=None)

        if self.simulate_malformed:
            # Simulate corrupted response returning invalid data
            raise ValueError("Malformed geocoder payload: missing coordinate fields")

        clean_q = query.strip().lower()
        results: List[GeocodedPlace] = []

        for item in self._mock_data:
            match = False
            for kw in item["keywords"]:
                if kw in clean_q or clean_q in kw:
                    match = True
                    break
            if not match and clean_q in item["name"].lower():
                match = True

            if match:
                results.append(
                    GeocodedPlace(
                        id=item["id"],
                        name=item["name"],
                        display_name=item["display_name"],
                        place_type=item["place_type"],
                        latitude=item["latitude"],
                        longitude=item["longitude"],
                        bounding_box=item["bounding_box"],
                        source="MOCK_GEOCODER",
                        metadata={"keywords": item["keywords"]},
                    )
                )
                if len(results) >= limit:
                    break

        return results


class PhotonGeocoderProvider(GeocoderProvider):
    """
    OpenStreetMap Photon Geocoder Provider (Komoot / Self-Hosted Photon).
    Provides fast, API-key-free OSM geocoding with bounding box biasing.
    """
    def __init__(self, base_url: Optional[str] = None):
        self.base_url = (base_url or os.environ.get("PHOTON_API_URL", "https://photon.komoot.io")).rstrip("/")
        self.timeout = PROVIDER_TIMEOUT_SECONDS

    @property
    def provider_name(self) -> str:
        return "PHOTON"

    async def search(
        self,
        query: str,
        bbox: Optional[List[float]] = None,
        limit: int = 10,
    ) -> List[GeocodedPlace]:
        effective_bbox = bbox or ODISHA_BBOX
        # Photon expects bbox in format: minLon,minLat,maxLon,maxLat
        bbox_str = f"{effective_bbox[0]},{effective_bbox[1]},{effective_bbox[2]},{effective_bbox[3]}"
        url = f"{self.base_url}/api/?q={httpx.URL(query).raw_path.decode() if False else query}&bbox={bbox_str}&limit={limit}"

        headers = {"User-Agent": "Bhumitra-Backend/1.0 (Odisha Cadastral Search)"}

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                res = await client.get(url, headers=headers)
                res.raise_for_status()
                data = res.json()

            places: List[GeocodedPlace] = []
            features = data.get("features", [])

            for feat in features:
                props = feat.get("properties", {})
                geom = feat.get("geometry", {})
                coords = geom.get("coordinates", [])
                if len(coords) < 2:
                    continue

                lng, lat = float(coords[0]), float(coords[1])
                name = props.get("name") or props.get("city") or props.get("district") or query
                city = props.get("city") or props.get("district") or props.get("state") or ""
                country = props.get("country", "")

                display_parts = [name]
                if city and city.lower() != name.lower():
                    display_parts.append(city)
                if "Odisha" not in display_parts and props.get("state") == "Odisha":
                    display_parts.append("Odisha")
                display_name = ", ".join(display_parts)

                # Hard safety gate: candidate must be strictly within Odisha bounds and metadata
                if not is_odisha_candidate(lat, lng, props, display_name):
                    continue

                osm_id = str(props.get("osm_id", ""))
                stable_id = f"photon:{props.get('osm_type', 'N')}:{osm_id}" if osm_id else f"photon:{hashlib.md5(f'{lat}:{lng}:{name}'.encode()).hexdigest()[:12]}"

                # Compute bbox if extent is provided
                ext = props.get("extent")
                bbox_result = [float(ext[0]), float(ext[1]), float(ext[2]), float(ext[3])] if (ext and len(ext) >= 4) else None

                place_type = props.get("type", "landmark")
                if place_type in ("city", "town", "administrative"):
                    pt = "city"
                elif place_type in ("suburb", "neighbourhood", "locality", "postcode"):
                    pt = "locality"
                else:
                    pt = "landmark"

                places.append(
                    GeocodedPlace(
                        id=stable_id,
                        name=name,
                        display_name=display_name,
                        place_type=pt,
                        latitude=lat,
                        longitude=lng,
                        bounding_box=bbox_result,
                        source="PHOTON_OSM",
                        metadata=props,
                    )
                )

            if not places and len(query.split()) > 1:
                tokens = [w for w in query.split() if w.lower() not in ("university", "campus", "temple", "mandir", "hospital", "station", "railway", "airport")]
                if tokens:
                    fallback_q = " ".join(tokens)
                    try:
                        return await self.search(fallback_q, bbox=bbox, limit=limit)
                    except Exception:
                        pass

            return places

        except httpx.TimeoutException as e:
            logger.warning(f"PHOTON_TIMEOUT: Query '{query}' timed out after {self.timeout}s: {e}")
            raise
        except httpx.HTTPStatusError as e:
            logger.warning(f"PHOTON_HTTP_ERROR: Status {e.response.status_code} for query '{query}': {e}")
            raise
        except Exception as e:
            logger.warning(f"PHOTON_ERROR: Query '{query}' failed: {e}")
            raise


class LocationIQGeocoderProvider(GeocoderProvider):
    """
    LocationIQ Geocoder Provider (Commercial OSM-derived API).
    Requires LOCATIONIQ_API_KEY environment variable.
    """
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("LOCATIONIQ_API_KEY", "")
        self.timeout = PROVIDER_TIMEOUT_SECONDS

    @property
    def provider_name(self) -> str:
        return "LOCATIONIQ"

    async def search(
        self,
        query: str,
        bbox: Optional[List[float]] = None,
        limit: int = 10,
    ) -> List[GeocodedPlace]:
        if not self.api_key:
            raise ValueError("LOCATIONIQ_API_KEY is not configured")

        effective_bbox = bbox or ODISHA_BBOX
        # LocationIQ viewbox format: minLon,maxLat,maxLon,minLat
        viewbox_str = f"{effective_bbox[0]},{effective_bbox[3]},{effective_bbox[2]},{effective_bbox[1]}"

        url = "https://us1.locationiq.com/v1/search"
        params = {
            "key": self.api_key,
            "q": query,
            "format": "json",
            "viewbox": viewbox_str,
            "bounded": 1,
            "limit": limit,
        }

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            res = await client.get(url, params=params)
            res.raise_for_status()
            data = res.json()

        places: List[GeocodedPlace] = []
        for item in data:
            lat = float(item.get("lat", 0.0))
            lng = float(item.get("lon", 0.0))
            if lat == 0.0 and lng == 0.0:
                continue

            display_name = item.get("display_name", query)
            name = display_name.split(",")[0].strip()

            # Hard safety gate: candidate must be strictly within Odisha bounds and metadata
            if not is_odisha_candidate(lat, lng, item, display_name):
                continue

            osm_id = str(item.get("osm_id", item.get("place_id", "")))
            stable_id = f"locationiq:{osm_id}"

            bb = item.get("boundingbox")
            bbox_out = [float(bb[2]), float(bb[0]), float(bb[3]), float(bb[1])] if (bb and len(bb) >= 4) else None

            places.append(
                GeocodedPlace(
                    id=stable_id,
                    name=name,
                    display_name=display_name,
                    place_type=item.get("type", "landmark"),
                    latitude=lat,
                    longitude=lng,
                    bounding_box=bbox_out,
                    source="LOCATIONIQ",
                    metadata=item,
                )
            )

        return places


class GeoapifyGeocoderProvider(GeocoderProvider):
    """
    Geoapify Geocoder Provider.
    Requires GEOAPIFY_API_KEY environment variable.
    """
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("GEOAPIFY_API_KEY", "")
        self.timeout = PROVIDER_TIMEOUT_SECONDS

    @property
    def provider_name(self) -> str:
        return "GEOAPIFY"

    async def search(
        self,
        query: str,
        bbox: Optional[List[float]] = None,
        limit: int = 10,
    ) -> List[GeocodedPlace]:
        if not self.api_key:
            raise ValueError("GEOAPIFY_API_KEY is not configured")

        effective_bbox = bbox or ODISHA_BBOX
        rect_filter = f"rect:{effective_bbox[0]},{effective_bbox[1]},{effective_bbox[2]},{effective_bbox[3]}"

        url = "https://api.geoapify.com/v1/geocode/autocomplete"
        params = {
            "apiKey": self.api_key,
            "text": query,
            "filter": rect_filter,
            "limit": limit,
        }

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            res = await client.get(url, params=params)
            res.raise_for_status()
            data = res.json()

        places: List[GeocodedPlace] = []
        for feat in data.get("features", []):
            geom = feat.get("geometry", {})
            coords = geom.get("coordinates", [])
            if len(coords) < 2:
                continue

            lng, lat = float(coords[0]), float(coords[1])
            props = feat.get("properties", {})
            name = props.get("name") or props.get("formatted", query)
            display_name = props.get("formatted", name)

            # Hard safety gate: candidate must be strictly within Odisha bounds and metadata
            if not is_odisha_candidate(lat, lng, props, display_name):
                continue

            stable_id = f"geoapify:{props.get('place_id', hashlib.md5(name.encode()).hexdigest()[:12])}"

            places.append(
                GeocodedPlace(
                    id=stable_id,
                    name=name,
                    display_name=display_name,
                    place_type=props.get("result_type", "landmark"),
                    latitude=lat,
                    longitude=lng,
                    bounding_box=props.get("bbox"),
                    source="GEOAPIFY",
                    metadata=props,
                )
            )

        return places


def create_geocoder_provider(provider_type: Optional[str] = None) -> GeocoderProvider:
    """
    Factory creating the configured GeocoderProvider instance.
    Provider is selected via environment variable GEOSPATIAL_SEARCH_PROVIDER.
    Defaults to PHOTON with seamless fallback to MOCK if offline or specified.
    """
    pt = (provider_type or os.environ.get("GEOSPATIAL_SEARCH_PROVIDER", "PHOTON")).upper().strip()

    if pt == "MOCK":
        return MockGeocoderProvider()
    elif pt == "LOCATIONIQ":
        return LocationIQGeocoderProvider()
    elif pt == "GEOAPIFY":
        return GeoapifyGeocoderProvider()
    elif pt == "PHOTON":
        return PhotonGeocoderProvider()
    else:
        logger.warning(f"Unknown GEOSPATIAL_SEARCH_PROVIDER '{pt}'. Defaulting to PHOTON.")
        return PhotonGeocoderProvider()


# ==============================================================================
# 2. Local 51k+ Odisha Canonical Village Catalog Indexer
# ==============================================================================

CATALOG_PATH = Path(__file__).resolve().parent.parent / "data" / "bhulekh_catalog" / "odisha_village_catalog_v1.json"

# Known representative coordinates for prominent cadastral villages
KNOWN_VILLAGE_COORDINATES: Dict[Tuple[str, str, str], Tuple[float, float]] = {
    ("20", "2", "60"): (20.35410, 85.81930),   # Patia, Bhubaneswar, Khurda (1,616 parcels)
    ("20", "2", "359"): (20.37219, 85.82703),  # Raghunathpur Jali, Bhubaneswar, Khurda
    ("7", "4", "317"): (21.63597, 85.65038),   # Dimbo / G_Dimbo, Keonjhar Sadar (966 parcels)
    ("7", "4", "330"): (21.68432, 85.71789),   # Keri, Keonjhar Sadar (1,832 parcels)
    ("7", "4", "329"): (21.66430, 85.71056),   # Maidankela, Keonjhar Sadar (1,638 parcels)
    ("20", "1", "100"): (19.76857, 85.17131),  # Gobindapur, Banapur, Khurda (1,407 parcels)
    ("7", "6", "17"): (21.39223, 85.88849),    # Ghatagan / Ghatagaon, Keonjhar (2,051 parcels)
    ("20", "8", "8"): (20.29749, 85.90114),    # Balianta, Khurda (1,932 parcels)
    ("18", "8", "216"): (20.92120, 86.20093),  # Oupad, Rasulpur, Jajpur (496 parcels)
    ("1", "10", "49"): (21.36550, 86.58230),   # Aghasula, Oupada, Balasore
    ("3", "1", "88"): (20.52840, 85.73350),    # Anantapur, Athagarh, Cuttack
    ("11", "8", "50"): (19.98250, 86.26500),   # Alangpur, Astarang, Puri
    ("3", "9", "92"): (20.59358, 86.00392),    # Naranapur, Tangichaudwar, Cuttack (718 parcels)
    ("7", "4", "38"): (21.65834, 85.47113),    # Naranpur, Keonjhar Sadar (826 parcels)
}

# Major Odisha Cities with broad coordinates (NOT mapped to revenue villages)
MAJOR_ODISHA_CITIES: Dict[str, Dict[str, Any]] = {
    "bhubaneswar": {
        "name": "Bhubaneswar",
        "subtitle": "State Capital, Khordha District, Odisha",
        "lat": 20.2961,
        "lng": 85.8245,
        "bbox": [85.73, 20.20, 85.90, 20.38],
    },
    "cuttack": {
        "name": "Cuttack",
        "subtitle": "Judicial Capital, Cuttack District, Odisha",
        "lat": 20.4625,
        "lng": 85.8830,
        "bbox": [85.80, 20.40, 85.96, 20.53],
    },
    "rourkela": {
        "name": "Rourkela",
        "subtitle": "Steel City, Sundargarh District, Odisha",
        "lat": 22.2604,
        "lng": 84.8536,
        "bbox": [84.78, 22.20, 84.93, 22.32],
    },
    "puri": {
        "name": "Puri",
        "subtitle": "Holy City, Puri District, Odisha",
        "lat": 19.8135,
        "lng": 85.8312,
        "bbox": [85.76, 19.76, 85.89, 19.86],
    },
    "sambalpur": {
        "name": "Sambalpur",
        "subtitle": "Western Odisha Hub, Sambalpur District, Odisha",
        "lat": 21.4669,
        "lng": 83.9812,
        "bbox": [83.90, 21.40, 84.05, 21.54],
    },
    "berhampur": {
        "name": "Berhampur",
        "subtitle": "Silk City, Ganjam District, Odisha",
        "lat": 19.3150,
        "lng": 84.7941,
        "bbox": [84.72, 19.25, 84.87, 19.38],
    },
    "balasore": {
        "name": "Balasore",
        "subtitle": "Coastal City, Balasore District, Odisha",
        "lat": 21.4934,
        "lng": 86.9135,
        "bbox": [86.85, 21.43, 86.98, 21.56],
    },
    "baripada": {
        "name": "Baripada",
        "subtitle": "Cultural City, Mayurbhanj District, Odisha",
        "lat": 21.9347,
        "lng": 86.7329,
        "bbox": [86.68, 21.88, 86.79, 21.99],
    },
    "jharsuguda": {
        "name": "Jharsuguda",
        "subtitle": "Industrial City, Jharsuguda District, Odisha",
        "lat": 21.8554,
        "lng": 84.0062,
        "bbox": [83.95, 21.80, 84.06, 21.91],
    },
}


def normalize_search_token(token: str) -> str:
    """
    Normalizes an English, Romanized, or Odia search token for consistent matching.
    Preserves Odia Unicode codepoints (\u0b00-\u0b7f) alongside Latin alphanumeric characters.
    """
    s = token.lower().strip()
    # Normalize common revenue suffixes & schwa deletions
    s = re.sub(r'pura\b', 'pur', s)
    s = re.sub(r'nagara\b', 'nagar', s)
    s = re.sub(r'sasana\b', 'sasan', s)
    s = re.sub(r'pada\b', 'pad', s)
    s = re.sub(r'pali\b', 'pali', s)
    s = re.sub(r'kela\b', 'kel', s)
    # Medial schwa normalization (e.g. raghunathapur -> raghunathpur, maidanakela -> maidankel)
    s = re.sub(r'athap', 'athp', s)
    # Preserve lowercase Latin, digits, and Odia Unicode codepoints (\u0b00-\u0b7f)
    s = re.sub(r'[^a-z0-9\u0b00-\u0b7f]', '', s)
    return s


def generate_phonetic_variants(phon: str) -> Set[str]:
    """
    Generates common English transliteration variations for an Odia village phonetic string.
    Handles terminal schwa/vowel reductions (-ela -> -el, -pura -> -pur, -kela -> -kel)
    and medial schwa drops (e.g. maidanakela -> maidankela, maidankel).
    """
    if not phon:
        return set()
    p = phon.lower().strip()
    variants = {p}

    # 1. Terminal reductions
    if p.endswith("a") and len(p) > 2:
        variants.add(p[:-1])
    if p.endswith("ela"):
        variants.add(p[:-3] + "el")
    if p.endswith("kela"):
        variants.add(p[:-4] + "kel")
    if p.endswith("pura"):
        variants.add(p[:-4] + "pur")
    if p.endswith("nagara"):
        variants.add(p[:-6] + "nagar")
    if p.endswith("pada"):
        variants.add(p[:-4] + "pad")
    if p.endswith("sasana"):
        variants.add(p[:-6] + "sasan")

    # 2. Medial schwa reduction (e.g. "anake" -> "anke", "anaka" -> "anka")
    reduced = re.sub(r"([nrlm])a([kgcjtdpb])", r"\1\2", p)
    if reduced != p:
        variants.add(reduced)
        if reduced.endswith("a") and len(reduced) > 2:
            variants.add(reduced[:-1])
        if reduced.endswith("ela"):
            variants.add(reduced[:-3] + "el")
        if reduced.endswith("kela"):
            variants.add(reduced[:-4] + "kel")

    return variants


def levenshtein_distance(s1: str, s2: str) -> int:
    """Computes Levenshtein edit distance between two strings with early termination."""
    if s1 == s2:
        return 0
    if len(s1) < len(s2):
        s1, s2 = s2, s1
    if not s2:
        return len(s1)
    prev = list(range(len(s2) + 1))
    for i, c1 in enumerate(s1):
        curr = [i + 1]
        for j, c2 in enumerate(s2):
            curr.append(min(prev[j + 1] + 1, curr[j] + 1, prev[j] + (c1 != c2)))
        prev = curr
    return prev[-1]


NON_ODISHA_MAJOR_ENTITIES: Set[str] = {
    "jaipur", "rajasthan", "delhi", "new delhi", "mumbai", "bombay",
    "bangalore", "bengaluru", "kolkata", "calcutta", "chennai", "madras",
    "hyderabad", "pune", "ahmedabad", "gurgaon", "gurugram", "noida",
    "lucknow", "patna", "bhopal", "chandigarh", "kochi", "cochin",
    "thiruvananthapuram", "trivandrum", "agra", "varanasi", "kanpur",
    "surat", "indore", "nagpur", "vadodara", "ghaziabad", "ludhiana",
    "amritsar", "mysore", "mysuru", "kozhikode", "calicut"
}


class LocalVillageCatalogIndex:
    """
    High-Performance In-Memory Index for 51k+ Official Odisha Revenue Villages.
    Supports multi-tier matching: Odia Unicode, canonical phonetic, transliteration variants
    (schwa-reduced and vowel-truncated), consonant skeletons, and official aliases.
    """
    _instance: Optional["LocalVillageCatalogIndex"] = None

    def __init__(self):
        self.is_loaded: bool = False
        self.records: List[Dict[str, Any]] = []

        # Multi-tier index structures
        self.by_exact_norm: Dict[str, List[int]] = {}
        self.by_variants: Dict[str, List[int]] = {}
        self.by_odia_key: Dict[str, List[int]] = {}
        self.by_skeleton: Dict[str, List[int]] = {}
        self.by_alias: Dict[str, List[int]] = {}
        self.tahasil_centers: Dict[Tuple[str, str], Tuple[float, float, List[float]]] = {}

        # Precomputed lookup structures (built once in load()) so a keystroke never
        # scans all ~50k keys: sorted keys for prefix search via bisect, and
        # (first letter, length) buckets for bounded typo matching.
        self._sorted_norm_keys: List[str] = []
        self._typo_buckets: Dict[Tuple[str, int], List[str]] = {}

    def _build_fast_lookups(self):
        self._sorted_norm_keys = sorted(k for k in self.by_exact_norm.keys() if k)
        buckets: Dict[Tuple[str, int], List[str]] = {}
        for k in self._sorted_norm_keys:
            buckets.setdefault((k[0], len(k)), []).append(k)
        self._typo_buckets = buckets

    def _prefix_keys(self, prefix: str, max_keys: int) -> List[str]:
        """Keys starting with `prefix` (excluding the exact key), shortest first."""
        import bisect
        keys = self._sorted_norm_keys
        i = bisect.bisect_left(keys, prefix)
        out: List[str] = []
        # Collect a generous window, then prefer shorter (closer) completions.
        while i < len(keys) and keys[i].startswith(prefix) and len(out) < max_keys * 4:
            if keys[i] != prefix:
                out.append(keys[i])
            i += 1
        out.sort(key=lambda k: (len(k), k))
        return out[:max_keys]

    def _typo_keys(self, query: str, max_d: int) -> List[str]:
        out: List[str] = []
        for length in range(len(query) - max_d, len(query) + max_d + 1):
            out.extend(self._typo_buckets.get((query[0], length), []))
        return out

    def village_location(self, did: str, tid: str, mid: str) -> Tuple[Optional[float], Optional[float], Optional[List[float]], bool]:
        """Best known location for a village: (lat, lng, bbox, is_precise)."""
        if (did, tid, mid) in KNOWN_VILLAGE_COORDINATES:
            lat, lng = KNOWN_VILLAGE_COORDINATES[(did, tid, mid)]
            return lat, lng, [lng - 0.015, lat - 0.015, lng + 0.015, lat + 0.015], True
        if (did, tid) in self.tahasil_centers:
            t_lat, t_lng, t_bbox = self.tahasil_centers[(did, tid)]
            return t_lat, t_lng, t_bbox, False
        d_id_clean = f"{int(did):02d}" if did.isdigit() else did
        dist_summary = gis_navigation_service.get_district_by_id(did) or gis_navigation_service.get_district_by_id(d_id_clean)
        if dist_summary:
            return dist_summary.center_lat, dist_summary.center_lng, dist_summary.bbox, False
        return None, None, None, False

    @classmethod
    def get_instance(cls) -> "LocalVillageCatalogIndex":
        if cls._instance is None:
            cls._instance = LocalVillageCatalogIndex()
            cls._instance.load()
        return cls._instance

    def load(self):
        if self.is_loaded:
            return

        t0 = time.time()
        if not CATALOG_PATH.exists():
            logger.error(f"Village catalog not found at: {CATALOG_PATH}")
            return

        with open(CATALOG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            self.records = data.get("records", [])

        # Build index lookups and fast (did, tid, mid) map
        record_map: Dict[Tuple[str, str, str], int] = {}
        for idx, r in enumerate(self.records):
            did = str(r.get("bhulekh_district_id") or r.get("district_id", "")).strip()
            tid = str(r.get("bhulekh_tahasil_id") or r.get("tahasil_id", "")).strip()
            mid = str(r.get("bhulekh_mouza_id") or r.get("bhulekh_village_id", "")).strip()
            if did and tid and mid:
                record_map[(did, tid, mid)] = idx

            odia_name = (r.get("bhulekh_mouza_odia_name") or r.get("bhulekh_village_name") or "").strip()
            eng_name = (r.get("bhulekh_mouza_name") or "").strip()

            # 1. Odia Key Index
            if odia_name:
                o_key = normalize_odia_village_key(odia_name)
                self.by_odia_key.setdefault(o_key, []).append(idx)

            # 2. Phonetic English Representation + Variants + Skeleton
            phon = odia_to_phonetic(odia_name)
            if phon:
                norm_phon = normalize_search_token(phon)
                if norm_phon:
                    self.by_exact_norm.setdefault(norm_phon, []).append(idx)

                    # Index phonetic variants (schwa-reduced and terminal vowel variants)
                    variants = generate_phonetic_variants(norm_phon)
                    for v in variants:
                        if v != norm_phon:
                            self.by_variants.setdefault(v, []).append(idx)

                    # Consonant outline for vowel-tolerant matching
                    skel = consonant_skeleton(norm_phon)
                    if skel:
                        self.by_skeleton.setdefault(skel, []).append(idx)

            # 3. Direct English Name if present
            if eng_name:
                norm_eng = normalize_search_token(eng_name)
                if norm_eng:
                    self.by_exact_norm.setdefault(norm_eng, []).append(idx)
                    for v in generate_phonetic_variants(norm_eng):
                        if v != norm_eng:
                            self.by_variants.setdefault(v, []).append(idx)

            # 4. Scoped Aliases & Bilingual mappings
            if odia_name in BILINGUAL_VILLAGE_MAP:
                bil_eng = normalize_search_token(BILINGUAL_VILLAGE_MAP[odia_name])
                self.by_alias.setdefault(bil_eng, []).append(idx)

        # Index known canonical scoped aliases (e.g. ("7", "4", "G_Dimbo") -> "Dimbo")
        for (a_did, a_tid, raw_alias), target_name in SCOPED_VILLAGE_ALIASES.items():
            clean_target = normalize_search_token(target_name)
            alias_tok = normalize_search_token(raw_alias)
            if clean_target in self.by_exact_norm:
                target_indices = self.by_exact_norm[clean_target]
                scoped = [i for i in target_indices if str(self.records[i].get("bhulekh_district_id")) == a_did]
                if scoped:
                    self.by_alias.setdefault(alias_tok, []).extend(scoped)
                else:
                    self.by_alias.setdefault(alias_tok, []).extend(target_indices)

        # Index official English mappings from VILLAGE_MAP
        from scrapers.bhulekh_mappings import VILLAGE_MAP
        for (v_did, v_tid, v_raw_name), v_mid in VILLAGE_MAP.items():
            k_trip = (str(v_did), str(v_tid), str(v_mid))
            if k_trip in record_map:
                r_idx = record_map[k_trip]
                clean_v = clean_gis_village_name(v_raw_name)
                norm_v = normalize_search_token(clean_v)
                norm_raw = normalize_search_token(v_raw_name)
                if norm_v:
                    self.by_alias.setdefault(norm_v, []).append(r_idx)
                if norm_raw and norm_raw != norm_v:
                    self.by_alias.setdefault(norm_raw, []).append(r_idx)

        # Precompute Tahasil centroids and bounding boxes from GIS Navigation Service
        try:
            districts = gis_navigation_service.get_districts_summary()
            for d in districts:
                did = str(d.bhulekh_id or d.code_2digit)
                fc = gis_navigation_service.get_tahasils_geojson_for_district(did)
                for feat in fc.get("features", []):
                    props = feat.get("properties", {})
                    tid = str(props.get("bhulekh_tahasil_id") or props.get("tahasil_id", ""))
                    center = props.get("center", [d.center_lng, d.center_lat])
                    bbox = props.get("bbox", d.bbox)
                    if tid and len(center) >= 2:
                        self.tahasil_centers[(did, tid)] = (float(center[1]), float(center[0]), [float(b) for b in bbox])
        except Exception as e:
            logger.warning(f"Could not precompute tahasil centroids: {e}")

        self._build_fast_lookups()
        self.is_loaded = True
        logger.info(
            f"VILLAGE_CATALOG_INDEX_LOADED: {len(self.records)} records indexed in {time.time() - t0:.3f}s. "
            f"Unique phonetic keys: {len(self.by_exact_norm)}, Variants: {len(self.by_variants)}, Skeletons: {len(self.by_skeleton)}"
        )

    def search_villages(
        self,
        query: str,
        district_id: Optional[str] = None,
        tahasil_id: Optional[str] = None,
        limit: int = 10,
        near: Optional[Tuple[float, float]] = None,
    ) -> List[LocationSearchResult]:
        """
        Executes multi-tier deterministic search over the 51k canonical village catalog.
        `near` (lat, lng) ranks matches within each tier by distance, so the user's
        own area wins among the many same-named villages.
        Tier 1: Odia Unicode exact match, exact canonical English name, exact alias
        Tier 2: Prefix match on exact phonetic and token-level match
        Tier 3: Phonetic variant match (schwa-reduced) and consonant-skeleton match
        """
        if not self.is_loaded:
            self.load()

        clean_q = query.strip()
        norm_q = normalize_search_token(clean_q)

        # Non-Odisha Major Entities Guard: If user query targets a prominent national entity
        # (e.g. Jaipur, Delhi, Mumbai), fail closed rather than surfacing obscure rural phonetic homophones.
        if norm_q in NON_ODISHA_MAJOR_ENTITIES:
            return []

        tier1_exact: List[int] = []
        tier2_prefix: List[int] = []
        tier3_approx: List[int] = []
        seen_indices = set()

        def add_tier_matches(indices: List[int], target_tier: List[int], max_items: Optional[int] = None):
            count = 0
            for idx in indices:
                if idx not in seen_indices:
                    r = self.records[idx]
                    # Filter by district/tahasil if supplied
                    if district_id and str(r.get("bhulekh_district_id")) != str(district_id):
                        continue
                    if tahasil_id and str(r.get("bhulekh_tahasil_id")) != str(tahasil_id):
                        continue
                    seen_indices.add(idx)
                    target_tier.append(idx)
                    count += 1
                    if max_items and count >= max_items:
                        break

        # Tier 1A: Odia Unicode Direct Match
        o_key = normalize_odia_village_key(clean_q)
        if o_key in self.by_odia_key:
            add_tier_matches(self.by_odia_key[o_key], tier1_exact)

        # If query contains Odia characters, also check phonetically
        odia_phon = odia_to_phonetic(clean_q)
        if odia_phon:
            norm_odia_phon = normalize_search_token(odia_phon)
            if norm_odia_phon in self.by_exact_norm:
                add_tier_matches(self.by_exact_norm[norm_odia_phon], tier1_exact)

        # Tier 1B: Alias / Clean Name Match (e.g. "G_Dimbo" -> "Dimbo", "G Dimbo")
        clean_gis = clean_gis_village_name(clean_q)
        norm_gis = normalize_search_token(clean_gis)
        if norm_gis in self.by_alias:
            add_tier_matches(self.by_alias[norm_gis], tier1_exact)

        if norm_q in self.by_alias:
            add_tier_matches(self.by_alias[norm_q], tier1_exact)

        # Tier 1C: Phonetic Normalized Exact Match
        if norm_q in self.by_exact_norm:
            add_tier_matches(self.by_exact_norm[norm_q], tier1_exact)

        # Tier 1D: Clean GIS name in exact phonetic
        if norm_gis and norm_gis != norm_q and norm_gis in self.by_exact_norm:
            add_tier_matches(self.by_exact_norm[norm_gis], tier1_exact)

        # With a proximity hint we gather a wider candidate pool per tier so the
        # nearest matches can be surfaced; without one, keep the original bound.
        pool = 200 if near else limit * 2

        # Tier 2: Prefix matches on exact phonetic (query length >= 3), via bisect
        if len(norm_q) >= 3 and (len(tier1_exact) + len(tier2_prefix)) < pool:
            for k in self._prefix_keys(norm_q, max_keys=pool):
                add_tier_matches(self.by_exact_norm[k], tier2_prefix)
                if len(tier2_prefix) >= pool:
                    break

        # Tier 3A: Transliteration / Schwa-Reduced Variants (e.g. "Maidankel" -> "Maidankela")
        if (len(tier1_exact) + len(tier2_prefix)) < limit * 2:
            if norm_q in self.by_variants:
                add_tier_matches(self.by_variants[norm_q], tier3_approx, max_items=5)

            # Check variants of the query itself
            for q_var in generate_phonetic_variants(norm_q):
                if q_var != norm_q and q_var in self.by_exact_norm:
                    add_tier_matches(self.by_exact_norm[q_var], tier3_approx, max_items=5)

        # Tier 3B: Consonant-Skeleton Matching (vowel-tolerant outline match, length >= 4)
        if len(norm_q) >= 4 and (len(tier1_exact) + len(tier2_prefix) + len(tier3_approx)) < limit * 2:
            skel_q = consonant_skeleton(norm_q)
            if skel_q and skel_q in self.by_skeleton:
                # Add up to 5 best consonant matches
                add_tier_matches(self.by_skeleton[skel_q], tier3_approx, max_items=5)

        # Tier 4: Controlled Typo Matching (Bounded Edit-Distance, length >= 4)
        tier4_typo: List[int] = []
        if len(norm_q) >= 4 and (len(tier1_exact) + len(tier2_prefix) + len(tier3_approx)) < limit * 2:
            max_d = 1 if len(norm_q) <= 5 else 2
            min_sim = 0.80 if len(norm_q) <= 5 else 0.78
            typo_candidates: List[Tuple[int, float, str]] = []
            for k in self._typo_keys(norm_q, max_d):
                if k:
                    d = levenshtein_distance(norm_q, k)
                    if d <= max_d:
                        sim = 1.0 - (d / max(len(norm_q), len(k)))
                        if sim >= min_sim:
                            typo_candidates.append((d, -sim, k))
            typo_candidates.sort(key=lambda x: (x[0], x[1]))
            for _, _, k in typo_candidates[:8]:
                add_tier_matches(self.by_exact_norm[k], tier4_typo, max_items=5)
                if len(tier4_typo) >= limit * 2:
                    break

        # Disambiguate and sort matches:
        # 1. Prioritize known coordinate villages (e.g. Patia, Keri, Maidankela, Dimbo, Naranapur)
        # 2. Prioritize prominent districts (Khurda, Cuttack, Keonjhar, Balasore, Puri)
        prominent_districts = {"20": 0, "3": 1, "11": 2, "7": 3, "1": 4, "12": 5}

        def _sort_indices(indices: List[int]) -> List[int]:
            def _score(idx: int) -> Tuple[float, float, int]:
                r = self.records[idx]
                did = str(r.get("bhulekh_district_id") or r.get("district_id", ""))
                tid = str(r.get("bhulekh_tahasil_id") or r.get("tahasil_id", ""))
                mid = str(r.get("bhulekh_mouza_id") or r.get("bhulekh_village_id", ""))
                if near:
                    # Proximity: distance to the village (or its tahasil centre).
                    v_lat, v_lng, _, _ = self.village_location(did, tid, mid)
                    dist_km = _haversine_km(near[0], near[1], v_lat, v_lng) if v_lat is not None else 9999.0
                    return (0, round(dist_km, 1), idx)
                # Known coordinate village gets top priority
                is_known = 0 if (did, tid, mid) in KNOWN_VILLAGE_COORDINATES else 1
                dist_prio = prominent_districts.get(did, 10)
                return (is_known, dist_prio, idx)
            return sorted(indices, key=_score)

        sorted_tier1 = _sort_indices(tier1_exact)
        sorted_tier2 = _sort_indices(tier2_prefix)
        sorted_tier3 = _sort_indices(tier3_approx)
        sorted_tier4 = _sort_indices(tier4_typo)

        ranked_indices = (sorted_tier1 + sorted_tier2 + sorted_tier3 + sorted_tier4)[:limit]

        # Transform matched records into structured LocationSearchResult items
        results: List[LocationSearchResult] = []
        for idx in ranked_indices[:limit]:
            r = self.records[idx]
            did = str(r.get("bhulekh_district_id") or r.get("district_id", "")).strip()
            tid = str(r.get("bhulekh_tahasil_id") or r.get("tahasil_id", "")).strip()
            mid = str(r.get("bhulekh_mouza_id") or r.get("bhulekh_village_id", "")).strip()

            odia_name = (r.get("bhulekh_mouza_odia_name") or r.get("bhulekh_village_name") or "").strip()
            eng_mouza = (r.get("bhulekh_mouza_name") or "").strip()

            # Format primary title
            phon_title = odia_to_phonetic(odia_name).capitalize() if odia_name else eng_mouza
            # Check for specific clean title aliases strictly by exact (did, tid, mid) tuple
            if (did, tid, mid) == ("20", "2", "60"):
                primary_title = "Patia"
            elif (did, tid, mid) == ("20", "2", "359"):
                primary_title = "Raghunathpur Jali"
            elif (did, tid, mid) == ("7", "4", "317"):
                primary_title = "Dimbo"
            elif (did, tid, mid) == ("7", "4", "330"):
                primary_title = "Keri"
            elif (did, tid, mid) == ("7", "4", "329"):
                primary_title = "Maidankela"
            elif (did, tid, mid) == ("3", "9", "92"):
                primary_title = "Naranapur"
            elif (did, tid, mid) == ("7", "4", "38"):
                primary_title = "Naranpur"
            elif phon_title:
                primary_title = phon_title
            else:
                primary_title = eng_mouza or "Revenue Village"

            # Disambiguating Subtitle (GP, Tahasil, District) - Critical for Duplicate Names
            tahasil_eng = _TAHASIL_ENGLISH_MAP.get((did, tid))
            if not tahasil_eng:
                raw_t = r.get("tahasil_name_english") or r.get("tahasil_name_odia") or ""
                if raw_t:
                    tahasil_eng = odia_to_phonetic(raw_t).title()
                else:
                    tahasil_eng = f"Tahasil {tid}"

            # Official Bhulekh name first: the catalog's district_name_english is
            # wrong for districts 21/22/23/25/26 (e.g. Fategarh tahasil of Nayagarh
            # is labelled "Nawarangpur"), which misleads users and RoR lookup.
            dist_eng = OFFICIAL_DISTRICT_NAMES.get(did) or r.get("district_name_english") or f"District {did}"
            dist_canonical = dist_eng.title()

            # Specific context disambiguation for duplicates (e.g. Raghunathpur)
            if primary_title == "Raghunathpur Jali" or (did == "20" and tid == "2" and mid == "359"):
                subtitle = f"Near Nandankanan, {tahasil_eng} Tahasil, {dist_canonical} District"
            elif did == "20" and tid == "1" and mid == "218":
                subtitle = f"Banapur Tahasil, {dist_canonical} District"
            elif did == "20" and tid == "5" and mid == "92":
                subtitle = f"Bolagarh Tahasil, {dist_canonical} District"
            else:
                subtitle = f"{tahasil_eng} Tahasil, {dist_canonical} District"

            # Resolve coordinates: Specific known village -> Tahasil centroid -> District centroid
            lat, lng, bbox, _is_precise = self.village_location(did, tid, mid)

            stable_id = f"bhumitra:village:{did}:{tid}:{mid}"
            rv_7digit = f"{int(did):02d}{int(tid):02d}{int(mid):03d}" if did.isdigit() and tid.isdigit() and mid.isdigit() else None

            # Direct-load identity. The 7-digit code is DD TT VVV, so it only
            # represents mouza ids up to 999; larger ids fall back to resolution.
            is_direct = bool(rv_7digit) and len(rv_7digit) == 7 and did.isdigit() and int(mid) <= 999
            dd = f"{int(did):02d}" if did.isdigit() else did
            gis_district_id = (_GIS_DISTRICT_CODE_MAP.get(dd) or {}).get("id")
            gis_block_id = f"{int(did):02d}{int(tid):02d}" if did.isdigit() and tid.isdigit() else None

            # Compute keyword and variant set for relevance matching
            norm_phon_token = normalize_search_token(phon_title)
            v_set = list(generate_phonetic_variants(norm_phon_token))
            skel_token = consonant_skeleton(norm_phon_token)

            results.append(
                LocationSearchResult(
                    id=stable_id,
                    title=f"{primary_title} ({odia_name})" if odia_name and odia_name != primary_title else primary_title,
                    subtitle=subtitle,
                    type=LocationSearchResultType.REVENUE_VILLAGE,
                    latitude=lat,
                    longitude=lng,
                    boundingBox=bbox,
                    source="BHUMITRA_CANONICAL_CATALOG",
                    revenueVillageId=rv_7digit,
                    district=dist_canonical,
                    districtId=did,
                    tahasil=tahasil_eng,
                    tahasilId=tid,
                    revenueVillage=primary_title,
                    villageNameOdia=odia_name or None,
                    bhulekhMouzaId=mid,
                    gisDistrictId=gis_district_id,
                    gisBlockId=gis_block_id,
                    directLoad=is_direct,
                    extraMetadata={
                        "district_id": did,
                        "tahasil_id": tid,
                        "mouza_id": mid,
                        "revenue_village_id": rv_7digit,
                        "mouza_name_odia": odia_name,
                        "tahasil_name": tahasil_eng,
                        "district_name": dist_canonical,
                        "keywords": [primary_title.lower(), phon_title.lower()],
                        "variants": v_set,
                        "skeleton": skel_token,
                    },
                )
            )

        return results


# ==============================================================================
# 3. Search Intent Router
# ==============================================================================

COORDINATE_PATTERN = re.compile(
    r"^[-+]?([1-8]?\d(?:\.\d+)?|90(?:\.0+)?)[,\s]+[-+]?(180(?:\.0+)?|(?:(?:1[0-7]\d)|(?:[1-9]?\d))(?:\.\d+)?)$"
)

PIN_CODE_PATTERN = re.compile(r"^(?:pin\s*(?:code\.?)?\s*[-–—:]*\s*)?(7[56]\d{4})$", re.IGNORECASE)

# Bare plot regex: "547", "Plot 547", "plot no 547", "plot-547"
PLOT_ONLY_PATTERN = re.compile(
    r"^(?:plot\s*(?:no\.?)?\s*[-–—:]*\s*)?([0-9]+[a-zA-Z0-9/\-]*)$",
    re.IGNORECASE,
)

# Compound plot regex: "Plot 547 Patia", "547 Patia", "Plot 318 KIIT", "Patia Plot 547"
COMPOUND_PLOT_PREFIX_PATTERN = re.compile(
    r"^(?:plot\s*(?:no\.?)?\s*[-–—:]*\s*)?([0-9]+[a-zA-Z0-9/\-]*)\s+(.+)$",
    re.IGNORECASE,
)
COMPOUND_PLOT_SUFFIX_PATTERN = re.compile(
    r"^(.+?)\s+(?:plot\s*(?:no\.?)?\s*[-–—:]*\s*)([0-9]+[a-zA-Z0-9/\-]*)$",
    re.IGNORECASE,
)
# Bare trailing number after a village name: "Patia 547", "Keri 1182/2"
COMPOUND_PLOT_BARE_SUFFIX_PATTERN = re.compile(
    r"^([^\d]{3,}?)\s+([0-9]+[a-zA-Z0-9/\-]*)$",
    re.IGNORECASE,
)

# Landmark keywords indicating high probability of POI intent
LANDMARK_KEYWORDS = {
    "university", "campus", "airport", "railway", "station", "temple", "mandir",
    "hospital", "mall", "market", "hotel", "resort", "park", "square", "chowk",
    "stadium", "college", "school", "office", "lake", "dam", "waterfall",
    "kiit", "soa", "iter", "aiims", "iit", "nit", "xaviers", "xub", "silicon", "cvraman",
}


def detect_search_intent(query: str) -> Tuple[SearchIntentType, Dict[str, Any]]:
    """
    Classifies search intent strictly and extracts structured parameters.
    """
    raw = query.strip()
    norm_q = raw.lower()

    # 1. COORDINATE Intent
    coord_match = COORDINATE_PATTERN.match(raw)
    if coord_match:
        try:
            parts = re.split(r"[,\s]+", raw)
            if len(parts) >= 2:
                lat = float(parts[0])
                lng = float(parts[1])
                # Check latitude and longitude reasonable bounds
                if -90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0:
                    return SearchIntentType.COORDINATE, {"latitude": lat, "longitude": lng}
        except Exception:
            pass

    # 2. PIN CODE Intent
    pin_match = PIN_CODE_PATTERN.match(raw)
    if pin_match:
        return SearchIntentType.PIN_CODE, {"pin_code": pin_match.group(1)}

    # 3. PLOT_ONLY Intent (e.g. "547", "Plot 547")
    # Must precede compound and general checks
    if re.match(r"^plot\s*(?:no\.?)?\s*[-–—:]*\s*[0-9]+[a-zA-Z0-9/\-]*$", raw, re.IGNORECASE) or (
        raw.isdigit() and len(raw) <= 6
    ):
        plot_m = PLOT_ONLY_PATTERN.match(raw)
        if plot_m:
            return SearchIntentType.PLOT_ONLY, {"plot_number": plot_m.group(1)}

    # 4. COMPOUND_PLOT Intent (e.g. "Plot 547 Patia", "547 Patia", "Plot 318 KIIT")
    c_match = COMPOUND_PLOT_PREFIX_PATTERN.match(raw)
    if c_match:
        plot_num = c_match.group(1)
        loc_part = c_match.group(2).strip()
        # Verify that plot_num looks like a valid plot number (not a word)
        if any(c.isdigit() for c in plot_num):
            return SearchIntentType.COMPOUND_PLOT, {"plot_number": plot_num, "location_query": loc_part}

    c_suf_match = COMPOUND_PLOT_SUFFIX_PATTERN.match(raw)
    if c_suf_match:
        loc_part = c_suf_match.group(1).strip()
        plot_num = c_suf_match.group(2).strip()
        return SearchIntentType.COMPOUND_PLOT, {"plot_number": plot_num, "location_query": loc_part}

    # "Patia 547": village name followed by a bare plot number. Only when the
    # name part has real letters (so coordinates / PINs are unaffected above).
    c_bare = COMPOUND_PLOT_BARE_SUFFIX_PATTERN.match(raw)
    if c_bare and re.search(r"[a-zA-Z\u0B00-\u0B7F]{3,}", c_bare.group(1)):
        loc_part = c_bare.group(1).strip()
        plot_num = c_bare.group(2).strip()
        return SearchIntentType.COMPOUND_PLOT, {"plot_number": plot_num, "location_query": loc_part}

    # 5. BROAD_CITY Intent (Major Odisha cities - checked before district)
    if norm_q in MAJOR_ODISHA_CITIES:
        return SearchIntentType.BROAD_CITY, {"city_key": norm_q, "city_data": MAJOR_ODISHA_CITIES[norm_q]}

    # 6. BROAD_DISTRICT Intent (Official 30 districts)
    norm_dist = normalize(raw)
    if norm_dist in DISTRICT_MAP:
        did = DISTRICT_MAP[norm_dist]
        return SearchIntentType.BROAD_DISTRICT, {"district_id": did, "district_name": OFFICIAL_DISTRICT_NAMES.get(did, norm_dist)}

    # 7. LANDMARK Intent: Query contains explicit POI indicator tokens
    tokens = set(re.findall(r'[a-z]+', norm_q))
    if tokens.intersection(LANDMARK_KEYWORDS):
        return SearchIntentType.LANDMARK, {"tokens": list(tokens)}

    # 8. Default to GENERAL (will probe local village catalog first, then external geocoder)
    return SearchIntentType.GENERAL, {}


# ==============================================================================
# 4. Location Search Service (Orchestrator)
# ==============================================================================

class LocationSearchService:
    """
    Primary Location Search Service for Bhumitra.
    Coordinates intent routing, local village indexing, provider discovery, and result caching.
    """
    def __init__(self, provider: Optional[GeocoderProvider] = None):
        self.provider = provider or create_geocoder_provider()
        self.village_index = LocalVillageCatalogIndex.get_instance()
        # In-Memory TTL Cache (500 items, 1 hour TTL)
        self._cache: TTLCache = TTLCache(maxsize=500, ttl=3600)
        self._lock = asyncio.Lock()

    def set_provider(self, provider: GeocoderProvider):
        """Allows dynamic swapping of the underlying GeocoderProvider."""
        self.provider = provider

    async def _search_villages_off_loop(
        self,
        query: str,
        district_id: Optional[str],
        tahasil_id: Optional[str],
        limit: int,
        near: Optional[Tuple[float, float]],
    ) -> List[LocationSearchResult]:
        """
        Catalog matching is pure CPU work over a read-only index. Running it in a
        worker thread keeps the event loop free, so a keystroke is never stuck
        behind slow work (e.g. an in-flight RoR scrape) on the same worker.
        """
        return await asyncio.to_thread(
            self.village_index.search_villages,
            query=query,
            district_id=district_id,
            tahasil_id=tahasil_id,
            limit=limit,
            near=near,
        )

    async def search(
        self,
        query: str,
        limit: int = 10,
        bbox: Optional[List[float]] = None,
        district_id: Optional[str] = None,
        tahasil_id: Optional[str] = None,
        near: Optional[Tuple[float, float]] = None,
    ) -> LocationSearchResponse:
        """
        Executes search across the Bhumitra multi-tier pipeline.
        `near` (lat, lng) is an optional proximity hint for ranking villages.
        """
        t0 = time.time()
        raw_query = query.strip()
        if not raw_query:
            return LocationSearchResponse(
                query=query,
                intent=SearchIntentType.GENERAL,
                results=[],
                totalResults=0,
                provider=self.provider.provider_name,
                executionTimeMs=0.0,
            )

        # Proximity is bucketed to ~10 km so nearby users share cache entries.
        near_key = f"{round(near[0], 1)},{round(near[1], 1)}" if near else "-"
        cache_key = f"{raw_query.lower()}:{limit}:{district_id}:{tahasil_id}:{near_key}"
        if cache_key in self._cache:
            cached_res = self._cache[cache_key]
            return cached_res

        intent, intent_params = detect_search_intent(raw_query)
        norm_q = normalize_search_token(raw_query)
        if norm_q in NON_ODISHA_MAJOR_ENTITIES:
            # Query explicitly targets a major non-Odisha city/state (e.g. Jaipur, Delhi, Mumbai, Bangalore).
            # Bhumitra search is strictly Odisha-only: fail closed with zero results.
            return LocationSearchResponse(
                query=raw_query,
                intent=intent,
                results=[],
                totalResults=0,
                provider=self.provider.provider_name,
                executionTimeMs=round((time.time() - t0) * 1000, 2),
            )

        results: List[LocationSearchResult] = []

        # ----------------------------------------------------------------------
        # A. COORDINATE Intent
        # ----------------------------------------------------------------------
        if intent == SearchIntentType.COORDINATE:
            lat = intent_params["latitude"]
            lng = intent_params["longitude"]
            coord_id = f"bhumitra:coord:{round(lat, 5)}:{round(lng, 5)}"
            results.append(
                LocationSearchResult(
                    id=coord_id,
                    title=f"{lat:.5f}, {lng:.5f}",
                    subtitle="GPS Coordinate (Direct Spatial Input)",
                    type=LocationSearchResultType.COORDINATE,
                    latitude=lat,
                    longitude=lng,
                    boundingBox=[lng - 0.005, lat - 0.005, lng + 0.005, lat + 0.005],
                    source="COORDINATE_INPUT",
                    extraMetadata={"latitude": lat, "longitude": lng},
                )
            )

        # ----------------------------------------------------------------------
        # B. PLOT_ONLY Intent
        # ----------------------------------------------------------------------
        elif intent == SearchIntentType.PLOT_ONLY:
            plot_num = intent_params["plot_number"]
            plot_id = f"bhumitra:plot:{plot_num}"
            results.append(
                LocationSearchResult(
                    id=plot_id,
                    title=f"Plot {plot_num}",
                    subtitle="Plot Intent: Please specify village (e.g. 'Plot 547 Patia') or select village first",
                    type=LocationSearchResultType.PLOT_ONLY,
                    latitude=None,
                    longitude=None,
                    boundingBox=None,
                    source="INTENT_ROUTER",
                    parsedPlotNumber=plot_num,
                    extraMetadata={"plot_number": plot_num, "requires_village_context": True},
                )
            )

        # ----------------------------------------------------------------------
        # C. COMPOUND_PLOT Intent
        # ----------------------------------------------------------------------
        elif intent == SearchIntentType.COMPOUND_PLOT:
            plot_num = intent_params["plot_number"]
            loc_query = intent_params["location_query"]

            # Recursively resolve location portion (village first, then geocoder)
            sub_res = await self.search(query=loc_query, limit=limit, bbox=bbox, district_id=district_id, tahasil_id=tahasil_id, near=near)

            for item in sub_res.results:
                compound_id = f"bhumitra:compound:{plot_num}:{item.id}"
                # Carry the full village identity so "Plot 547 Patia" can also
                # open the village directly and then select the plot.
                results.append(
                    item.model_copy(update={
                        "id": compound_id,
                        "title": f"Plot {plot_num} in {item.title}",
                        "type": LocationSearchResultType.COMPOUND_PLOT,
                        "parsedPlotNumber": plot_num,
                        "extraMetadata": {**dict(item.extraMetadata or {}), "plot_number": plot_num, "resolved_place": item.title},
                    })
                )

        # ----------------------------------------------------------------------
        # D. BROAD_DISTRICT Intent
        # ----------------------------------------------------------------------
        elif intent == SearchIntentType.BROAD_DISTRICT:
            did = intent_params["district_id"]
            d_name = intent_params["district_name"]
            dist_summary = gis_navigation_service.get_district_by_id(did)
            lat = dist_summary.center_lat if dist_summary else 20.5
            lng = dist_summary.center_lng if dist_summary else 85.0
            d_bbox = dist_summary.bbox if dist_summary else ODISHA_BBOX

            results.append(
                LocationSearchResult(
                    id=f"bhumitra:district:{did}",
                    title=f"{d_name.title()} District",
                    subtitle="Official Administrative District Center, Odisha",
                    type=LocationSearchResultType.BROAD_DISTRICT,
                    latitude=lat,
                    longitude=lng,
                    boundingBox=d_bbox,
                    source="ODISHA_ADMIN_CATALOG",
                    extraMetadata={"district_id": did, "district_name": d_name},
                )
            )

        # ----------------------------------------------------------------------
        # E. BROAD_CITY Intent
        # ----------------------------------------------------------------------
        elif intent == SearchIntentType.BROAD_CITY:
            c_data = intent_params["city_data"]
            results.append(
                LocationSearchResult(
                    id=f"bhumitra:city:{intent_params['city_key']}",
                    title=c_data["name"],
                    subtitle=c_data["subtitle"],
                    type=LocationSearchResultType.BROAD_CITY,
                    latitude=c_data["lat"],
                    longitude=c_data["lng"],
                    boundingBox=c_data["bbox"],
                    source="ODISHA_CITY_CATALOG",
                    extraMetadata=c_data,
                )
            )

        # ----------------------------------------------------------------------
        # F. PIN_CODE Intent
        # ----------------------------------------------------------------------
        elif intent == SearchIntentType.PIN_CODE:
            pin = intent_params["pin_code"]
            # Query external provider for PIN locality
            try:
                places = await self.provider.search(query=pin, bbox=bbox, limit=limit)
                for p in places:
                    if not is_odisha_candidate(p.latitude, p.longitude, getattr(p, "metadata", None), p.display_name):
                        continue
                    results.append(
                        LocationSearchResult(
                            id=f"bhumitra:pin:{pin}:{p.id}",
                            title=p.name,
                            subtitle=p.display_name,
                            type=LocationSearchResultType.LOCALITY,
                            latitude=p.latitude,
                            longitude=p.longitude,
                            boundingBox=p.bounding_box,
                            source=p.source,
                            extraMetadata={"pin_code": pin},
                        )
                    )
            except Exception as e:
                logger.warning(f"External geocoder failed for PIN {pin}: {e}")

            if not results:
                # Default Odisha PIN centroid fallback
                results.append(
                    LocationSearchResult(
                        id=f"bhumitra:pin:{pin}",
                        title=f"PIN {pin}",
                        subtitle="Postal Area Locality, Odisha",
                        type=LocationSearchResultType.LOCALITY,
                        latitude=20.30,
                        longitude=85.82,
                        boundingBox=ODISHA_BBOX,
                        source="POSTAL_INDEX_FALLBACK",
                        extraMetadata={"pin_code": pin},
                    )
                )

        # ----------------------------------------------------------------------
        # G. LANDMARK Intent
        # ----------------------------------------------------------------------
        elif intent == SearchIntentType.LANDMARK:
            # Query external geocoder first for genuine POI/landmark matches
            try:
                places = await self.provider.search(query=raw_query, bbox=bbox, limit=limit)
                for p in places:
                    if not is_odisha_candidate(p.latitude, p.longitude, p.metadata, p.display_name):
                        continue
                    # Gate 2: For landmark queries, verify name relevance
                    name_sub = f"{p.name} {p.display_name}".lower()
                    query_tokens = [t for t in re.findall(r'[a-z0-9]+', raw_query.lower()) if len(t) >= 2]
                    if not any(token in name_sub for token in query_tokens):
                        continue
                    p_type = LocationSearchResultType.LANDMARK if p.place_type == "landmark" else LocationSearchResultType.LOCALITY
                    results.append(
                        LocationSearchResult(
                            id=f"bhumitra:place:{p.id}",
                            title=p.name,
                            subtitle=p.display_name,
                            type=p_type,
                            latitude=p.latitude,
                            longitude=p.longitude,
                            boundingBox=p.bounding_box,
                            source=p.source,
                            extraMetadata=p.metadata,
                        )
                    )
            except Exception as e:
                logger.warning(f"External geocoder failed for landmark '{raw_query}': {e}")

            # For local villages during landmark search, only keep villages that explicitly contain the query token
            village_results = await self._search_villages_off_loop(raw_query, district_id, tahasil_id, limit, near)
            query_tokens = [t for t in re.findall(r'[a-z0-9]+', raw_query.lower()) if len(t) >= 2]
            for vr in village_results:
                clean_vt = vr.title.lower()
                clean_vs = vr.subtitle.lower()
                if any(t in clean_vt or t in clean_vs for t in query_tokens):
                    results.append(vr)

        # ----------------------------------------------------------------------
        # H. REVENUE_VILLAGE or GENERAL Intent
        # ----------------------------------------------------------------------
        else:
            # 1. Always query local 51k village catalog first
            village_results = await self._search_villages_off_loop(raw_query, district_id, tahasil_id, limit, near)
            results.extend(village_results)

            # 2. If no local village matched, probe geocoder
            if len(results) == 0:
                try:
                    places = await self.provider.search(query=raw_query, bbox=bbox, limit=limit)
                    for p in places:
                        if not is_odisha_candidate(p.latitude, p.longitude, p.metadata, p.display_name):
                            continue
                        p_type = LocationSearchResultType.LANDMARK if p.place_type == "landmark" else LocationSearchResultType.LOCALITY
                        results.append(
                            LocationSearchResult(
                                id=f"bhumitra:place:{p.id}",
                                title=p.name,
                                subtitle=p.display_name,
                                type=p_type,
                                latitude=p.latitude,
                                longitude=p.longitude,
                                boundingBox=p.bounding_box,
                                source=p.source,
                                extraMetadata=p.metadata,
                            )
                        )
                except Exception as e:
                    logger.warning(f"EXTERNAL_GEOCODER_DISCOVERY_FAILED: {e}. Preserving local village results.")

        # ======================================================================
        # HARD SAFETY GATE & FINAL SANITIZATION: Strictly enforce ODISHA-ONLY
        # ======================================================================
        odisha_only_results: List[LocationSearchResult] = []
        for r in results:
            if r.type == LocationSearchResultType.PLOT_ONLY:
                odisha_only_results.append(r)
            elif is_odisha_candidate(r.latitude, r.longitude, r.extraMetadata, r.subtitle):
                odisha_only_results.append(r)
            else:
                logger.warning(f"FINAL_ODISHA_GATE_DISCARDED: Dropped '{r.title}' ({r.subtitle}) at ({r.latitude}, {r.longitude})")

        # Deduplicate equivalent results (by coordinate proximity and title)
        deduped: List[LocationSearchResult] = []
        seen_coords: List[Tuple[float, float]] = []
        seen_ids = set()

        for item in odisha_only_results:
            if item.id in seen_ids:
                continue
            # Catalog villages have unique ids and often share a tahasil-centre
            # coordinate with a same-named neighbour; never merge them by coords.
            is_catalog_village = item.source == "BHUMITRA_CANONICAL_CATALOG" and item.bhulekhMouzaId is not None
            if not is_catalog_village and item.latitude is not None and item.longitude is not None:
                is_coord_dup = False
                for lat, lng in seen_coords:
                    if abs(item.latitude - lat) < 0.0008 and abs(item.longitude - lng) < 0.0008 and item.title.lower() in [d.title.lower() for d in deduped]:
                        is_coord_dup = True
                        break
                if is_coord_dup:
                    continue
                seen_coords.append((item.latitude, item.longitude))
            seen_ids.add(item.id)
            deduped.append(item)

        results = deduped

        # Multi-Tier Relevance Filtering & Ranking:
        # Candidate must pass BOTH:
        # Gate 1: Odisha Boundary & State Filter (already satisfied in odisha_only_results)
        # Gate 2: Strict Relevance Tiers 1, 2, 3, or 4 (Tier 5 / weak fuzzy / unrelated matches are DISCARDED)
        def _evaluate_candidate_relevance(item: LocationSearchResult) -> Optional[Tuple[int, int, int]]:
            q_raw = raw_query.strip().lower()
            q = normalize_search_token(q_raw)
            if not q:
                return None

            # Special routed intents
            if item.type == LocationSearchResultType.COORDINATE:
                return (1, 0, 0)
            if item.type == LocationSearchResultType.PLOT_ONLY:
                return (1, 1, 0)
            if item.type == LocationSearchResultType.COMPOUND_PLOT:
                return (1 if q_raw in item.title.lower() else 2, 0, len(item.title))

            t = item.title.lower().strip()
            norm_t = normalize_search_token(t)
            clean_title = re.sub(r'\s*\([^)]*\)', '', t).strip()
            norm_clean = normalize_search_token(clean_title)
            extra = item.extraMetadata or {}
            odia_name = str(extra.get("odia_name") or extra.get("mouza_name_odia") or extra.get("bhulekh_mouza_odia_name") or "").strip()
            odia_q = normalize_odia_village_key(raw_query)
            odia_phon = normalize_search_token(odia_to_phonetic(raw_query))

            has_coords = 0 if (item.latitude is not None and item.longitude is not None) else 1
            length_penalty = len(clean_title)

            # Tier 1: Exact Name Match
            if norm_clean == q or norm_t == q or clean_title == q_raw or t == q_raw:
                return (1, has_coords, length_penalty)

            clean_gis = clean_gis_village_name(clean_title)
            if clean_gis and normalize_search_token(clean_gis) == q:
                return (1, has_coords, length_penalty)

            if odia_q and odia_name and odia_q == normalize_odia_village_key(odia_name):
                return (1, has_coords, length_penalty)

            if odia_phon and (norm_clean == odia_phon or clean_title.lower() == odia_phon):
                return (1, has_coords, length_penalty)

            if item.type == LocationSearchResultType.BROAD_CITY and (norm_t == q or norm_clean == q):
                return (1, has_coords, length_penalty)

            if item.type == LocationSearchResultType.BROAD_DISTRICT and (norm_t == f"{q} district" or norm_t == q):
                return (1, has_coords, length_penalty)

            # Tier 2: Strong Prefix / Complete Word Match
            if norm_clean.startswith(q) or norm_t.startswith(q) or clean_title.startswith(q_raw):
                return (2, has_coords, length_penalty)

            if odia_q and odia_name and normalize_odia_village_key(odia_name).startswith(odia_q):
                return (2, has_coords, length_penalty)

            if odia_phon and (norm_clean.startswith(odia_phon) or norm_t.startswith(odia_phon)):
                return (2, has_coords, length_penalty)

            title_tokens = [tok for tok in re.split(r'[^a-z0-9\u0b00-\u0b7f]+', norm_clean) if tok]
            if len(q) >= 2 and any(tok.startswith(q) for tok in title_tokens):
                return (2, has_coords, length_penalty)

            q_tokens = [tok for tok in re.split(r'[^a-z0-9\u0b00-\u0b7f]+', q) if tok]
            if len(q_tokens) > 1 and all(any(t_tok.startswith(q_tok) for t_tok in title_tokens) for q_tok in q_tokens):
                return (2, has_coords, length_penalty)

            # Tier 3: Strong Normalized / Transliteration / Phonetic Variant Match
            # 3A. Phonetic Variants (e.g. "Maidankel" -> "Maidankela")
            cand_variants = set(extra.get("variants", []))
            q_variants = generate_phonetic_variants(q)
            if cand_variants and (q in cand_variants or cand_variants.intersection(q_variants)):
                return (3, has_coords, length_penalty)

            # 3B. Consonant-Skeleton Match (vowel-tolerant outline match, length >= 4)
            if len(q) >= 4:
                skel_q = consonant_skeleton(q)
                skel_cand = extra.get("skeleton") or consonant_skeleton(norm_clean)
                if skel_q and skel_cand and skel_q == skel_cand:
                    return (3, has_coords, length_penalty)

            keywords = [normalize_search_token(str(k)) for k in extra.get("keywords", []) if k]
            if any(k == q or k.startswith(q) or q in k for k in keywords):
                return (3, has_coords, length_penalty)

            alias_val = extra.get("alias")
            if alias_val and normalize_search_token(str(alias_val)) == q:
                return (3, has_coords, length_penalty)

            if odia_name:
                phon = odia_to_phonetic(odia_name)
                if phon and normalize_search_token(phon) == q:
                    return (3, has_coords, length_penalty)

            if any(tok == q for tok in title_tokens if len(q) >= 3):
                return (3, has_coords, length_penalty)

            # Tier 4: Controlled Typo Match (Small Edit-Distance / Bounded Similarity for catalog items)
            if item.source == "BHUMITRA_CANONICAL_CATALOG" and len(q) >= 4:
                max_d = 1 if len(q) <= 5 else 2
                min_sim = 0.80 if len(q) <= 5 else 0.78
                candidates_to_check = [norm_clean, norm_t] + [normalize_search_token(str(k)) for k in extra.get("keywords", []) if k]
                for cand_str in candidates_to_check:
                    if cand_str and cand_str[0] == q[0] and abs(len(cand_str) - len(q)) <= max_d:
                        d = levenshtein_distance(q, cand_str)
                        if d <= max_d:
                            sim = 1.0 - (d / max(len(q), len(cand_str)))
                            if sim >= min_sim:
                                return (4, has_coords, length_penalty)

            # Tier 5: External Geocoder result with strong Odisha locality evidence
            if item.source != "BHUMITRA_CANONICAL_CATALOG":
                ext_tokens = [tok for tok in re.split(r'[^a-z0-9]+', norm_t) if tok]
                if any(tok.startswith(q) for tok in ext_tokens) or q in norm_t:
                    return (5, has_coords, length_penalty)

            # Unrelated / Weak Fuzzy: STRICTLY DISCARDED!
            return None

        # Filter strictly by Gate 2 relevance
        strictly_relevant_results: List[Tuple[Tuple[int, int, int], LocationSearchResult]] = []
        for item in results:
            rel_score = _evaluate_candidate_relevance(item)
            if rel_score is not None:
                strictly_relevant_results.append((rel_score, item))
            else:
                logger.info(f"STRICT_RELEVANCE_GATE: Discarded unrelated candidate '{item.title}' ({item.subtitle}) for query '{raw_query}'")

        # Sort by relevance tier, coordinate presence, and length penalty.
        # With a proximity hint, the catalog already ordered villages nearest-first
        # within each tier, so keep that order instead of re-sorting by name length.
        if near:
            strictly_relevant_results.sort(key=lambda x: (x[0][0], x[0][1]))  # stable
        else:
            strictly_relevant_results.sort(key=lambda x: x[0])
        results = [x[1] for x in strictly_relevant_results]

        exec_time_ms = round((time.time() - t0) * 1000, 2)
        response = LocationSearchResponse(
            query=raw_query,
            intent=intent,
            results=results[:limit],
            totalResults=len(results),
            provider=self.provider.provider_name,
            executionTimeMs=exec_time_ms,
        )

        # Cache valid responses
        self._cache[cache_key] = response
        return response


# Global singleton instance
location_search_service = LocationSearchService()
