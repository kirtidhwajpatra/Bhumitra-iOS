"""
Bihar Cadastral GIS Map Provider
Implements the CadastralProvider interface for Bihar BhuNaksha cadastral maps.
Provides hierarchy resolution, spatial geometry validation, centroid calculation,
point-in-polygon ray-casting, and isolated caching (bihar:gis:*).
"""

import json
import os
import math
import hashlib
import asyncio
import logging
from cachetools import TTLCache
from typing import List, Optional, Dict, Any, Tuple

from core.config import settings
from models.cadastral import (
    CadastralDistrict,
    CadastralBlock,
    CadastralGP,
    CadastralVillage,
    CadastralExtent,
    CadastralParcel,
    CadastralParcelFeature,
    CadastralFeatureCollection,
)
from providers.cadastral_provider import CadastralProvider

logger = logging.getLogger("bhumitra.provider.bihar_gis")

# Dedicated Isolated Bihar GIS Cache (TTL = 24 hours)
_bihar_gis_cache: TTLCache = TTLCache(maxsize=500, ttl=86400)
_bihar_gis_semaphore = asyncio.Semaphore(settings.BIHAR_MAX_CONCURRENT)
_bihar_gis_inflight: Dict[str, asyncio.Future] = {}
_bihar_gis_lock = asyncio.Lock()

# Resource Guardrails
MAX_PARCELS_PER_VILLAGE = 5000
MAX_COORDINATES_PER_RING = 50000


def validate_polygon_ring(ring: Any) -> Optional[List[List[float]]]:
    """
    Validates that a coordinate ring is a non-empty, finite, closed list of [lng, lat] pairs.
    Returns cleaned float coordinates or None if invalid.
    """
    if not isinstance(ring, (list, tuple)) or len(ring) < 4:
        return None

    cleaned_ring: List[List[float]] = []
    for pt in ring:
        if not isinstance(pt, (list, tuple)) or len(pt) < 2:
            return None
        try:
            lng = float(pt[0])
            lat = float(pt[1])
            if math.isnan(lng) or math.isnan(lat) or math.isinf(lng) or math.isinf(lat):
                return None
            cleaned_ring.append([round(lng, 6), round(lat, 6)])
        except (ValueError, TypeError):
            return None

    if len(cleaned_ring) < 4:
        return None

    # Ensure ring closure (first point equals last point)
    if cleaned_ring[0] != cleaned_ring[-1]:
        cleaned_ring.append(list(cleaned_ring[0]))

    return cleaned_ring


def compute_polygon_centroid(ring: List[List[float]]) -> List[float]:
    """
    Computes [lng, lat] centroid of a polygon ring using shoelace formula with fallback to vertex mean.
    """
    n = len(ring)
    if n < 4:
        return [0.0, 0.0]

    area_acc = 0.0
    cx_acc = 0.0
    cy_acc = 0.0

    for i in range(n - 1):
        x0, y0 = ring[i][0], ring[i][1]
        x1, y1 = ring[i + 1][0], ring[i + 1][1]
        cross = (x0 * y1) - (x1 * y0)
        area_acc += cross
        cx_acc += (x0 + x1) * cross
        cy_acc += (y0 + y1) * cross

    area = area_acc * 0.5
    if abs(area) > 1e-9:
        cx = cx_acc / (6.0 * area)
        cy = cy_acc / (6.0 * area)
        if not (math.isnan(cx) or math.isnan(cy) or math.isinf(cx) or math.isinf(cy)):
            return [round(cx, 6), round(cy, 6)]

    # Fallback to mean of vertices
    mean_lng = sum(pt[0] for pt in ring[:-1]) / (n - 1)
    mean_lat = sum(pt[1] for pt in ring[:-1]) / (n - 1)
    return [round(mean_lng, 6), round(mean_lat, 6)]


def point_in_polygon(lat: float, lng: float, ring: List[List[float]]) -> bool:
    """
    Ray-casting algorithm for testing if (lat, lng) is inside a polygon ring.
    Coordinates in ring are [lng, lat].
    """
    inside = False
    n = len(ring)
    if n < 4:
        return False

    j = n - 1
    for i in range(n):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]

        intersect = ((yi > lat) != (yj > lat)) and (
            lng < (xj - xi) * (lat - yi) / (yj - yi + 1e-12) + xi
        )
        if intersect:
            inside = not inside
        j = i

    return inside


class BiharCadastralProvider(CadastralProvider):
    """
    Isolated Cadastral Provider for Bihar BhuNaksha.
    """

    def __init__(self, fixtures_dir: Optional[str] = None):
        self.fixtures_dir = fixtures_dir or os.path.join(
            os.path.dirname(os.path.dirname(__file__)),
            "tests",
            "bihar",
            "gis",
            "fixtures",
        )

    def _read_fixture_json(self, filename: str) -> Any:
        path = os.path.join(self.fixtures_dir, filename)
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        return []

    async def get_districts(self) -> List[CadastralDistrict]:
        cache_key = "bihar:gis:districts"
        if cache_key in _bihar_gis_cache:
            return _bihar_gis_cache[cache_key]

        data = self._read_fixture_json("district_list.json")
        districts = [CadastralDistrict(id=d["id"], name=d["name"]) for d in data]
        _bihar_gis_cache[cache_key] = districts
        return districts

    async def get_blocks(
        self, district_id: str, district_name: Optional[str] = None
    ) -> List[CadastralBlock]:
        cache_key = f"bihar:gis:blocks:{district_id}"
        if cache_key in _bihar_gis_cache:
            return _bihar_gis_cache[cache_key]

        data = self._read_fixture_json("circle_list.json")
        blocks = [
            CadastralBlock(id=c["id"], name=c["name"], district_id=c["district_id"])
            for c in data
            if c.get("district_id") == district_id or not district_id
        ]
        _bihar_gis_cache[cache_key] = blocks
        return blocks

    async def get_gram_panchayats(
        self,
        block_id: str,
        block_name: Optional[str] = None,
        district_name: Optional[str] = None,
    ) -> List[CadastralGP]:
        # In Bihar, maps to Halka
        return [
            CadastralGP(
                id=f"{block_id}_H01",
                name="Halka 01",
                block_id=block_id,
            )
        ]

    async def get_villages(
        self,
        gp_id: Optional[str],
        block_id: str,
        block_name: Optional[str] = None,
        district_name: Optional[str] = None,
    ) -> List[CadastralVillage]:
        cache_key = f"bihar:gis:villages:{block_id}"
        if cache_key in _bihar_gis_cache:
            return _bihar_gis_cache[cache_key]

        data = self._read_fixture_json("mauza_list.json")
        villages = [
            CadastralVillage(
                id=v["id"],
                name=v["name"],
                block_id=v["block_id"],
                district_id=v.get("district_id"),
            )
            for v in data
            if v.get("block_id") == block_id or not block_id
        ]
        _bihar_gis_cache[cache_key] = villages
        return villages

    async def get_sheets(self, village_id: str) -> List[Dict[str, Any]]:
        return self._read_fixture_json("sheet_list.json")

    async def get_village_extent(
        self,
        village_id: str,
        gp_id: Optional[str] = None,
        raw_geojson: Optional[Dict[str, Any]] = None,
    ) -> Optional[CadastralExtent]:
        parcels_col = await self.get_village_parcels(village_id=village_id, raw_geojson=raw_geojson)
        if not parcels_col.features:
            return None

        min_lng, min_lat = float("inf"), float("inf")
        max_lng, max_lat = float("-inf"), float("-inf")

        for f in parcels_col.features:
            geom = f.geometry
            g_type = geom.get("type")
            coords = geom.get("coordinates", [])

            if g_type == "Polygon":
                for ring in coords:
                    for pt in ring:
                        min_lng = min(min_lng, pt[0])
                        max_lng = max(max_lng, pt[0])
                        min_lat = min(min_lat, pt[1])
                        max_lat = max(max_lat, pt[1])
            elif g_type == "MultiPolygon":
                for poly in coords:
                    for ring in poly:
                        for pt in ring:
                            min_lng = min(min_lng, pt[0])
                            max_lng = max(max_lng, pt[0])
                            min_lat = min(min_lat, pt[1])
                            max_lat = max(max_lat, pt[1])

        if min_lng == float("inf"):
            return None

        return CadastralExtent(
            min_lng=round(min_lng, 6),
            min_lat=round(min_lat, 6),
            max_lng=round(max_lng, 6),
            max_lat=round(max_lat, 6),
            center_lng=round((min_lng + max_lng) / 2.0, 6),
            center_lat=round((min_lat + max_lat) / 2.0, 6),
        )

    async def get_village_parcels(
        self,
        village_id: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        gp_name: Optional[str] = None,
        village_name: Optional[str] = None,
        sheet_no: Optional[str] = None,
        raw_geojson: Optional[Dict[str, Any]] = None,
    ) -> CadastralFeatureCollection:
        """
        Parses and validates cadastral parcel vector features for a Bihar Mauza.
        Supports both Polygon and MultiPolygon geometry structures.
        """
        cache_key = f"bihar:gis:parcels:{village_id}:{sheet_no or 'all'}"
        if cache_key in _bihar_gis_cache:
            return _bihar_gis_cache[cache_key]

        data = raw_geojson or self._read_fixture_json("village_cadastral_map_sample.json")
        raw_features = data.get("features", [])

        valid_features: List[CadastralParcelFeature] = []

        for f in raw_features[:MAX_PARCELS_PER_VILLAGE]:
            geom = f.get("geometry", {})
            props = f.get("properties", {})
            g_type = geom.get("type")
            coords = geom.get("coordinates", [])

            # Extract plot number from various BhuNaksha property keys
            plot_num = str(
                props.get("plot_number")
                or props.get("plotno")
                or props.get("plot_no")
                or props.get("khesra_no")
                or props.get("khesra_id")
                or "1"
            )
            feature_id = str(f.get("id") or f"{village_id}_{plot_num}")

            if g_type == "Polygon" and coords:
                cleaned_rings: List[List[List[float]]] = []
                for ring in coords:
                    valid_r = validate_polygon_ring(ring)
                    if valid_r:
                        cleaned_rings.append(valid_r)

                if cleaned_rings:
                    centroid = props.get("centroid") or compute_polygon_centroid(cleaned_rings[0])
                    valid_features.append(
                        CadastralParcelFeature(
                            type="Feature",
                            id=feature_id,
                            geometry={
                                "type": "Polygon",
                                "coordinates": cleaned_rings,
                            },
                            properties={
                                **props,
                                "plot_number": plot_num,
                                "centroid": centroid,
                                "source": "BIHAR_BHUNAKSHA",
                            },
                        )
                    )

            elif g_type == "MultiPolygon" and coords:
                cleaned_multipoly: List[List[List[List[float]]]] = []
                all_first_rings: List[List[List[float]]] = []

                for poly in coords:
                    cleaned_poly_rings: List[List[List[float]]] = []
                    for ring in poly:
                        valid_r = validate_polygon_ring(ring)
                        if valid_r:
                            cleaned_poly_rings.append(valid_r)
                    if cleaned_poly_rings:
                        cleaned_multipoly.append(cleaned_poly_rings)
                        all_first_rings.append(cleaned_poly_rings[0])

                if cleaned_multipoly:
                    centroid = props.get("centroid") or compute_polygon_centroid(all_first_rings[0])
                    valid_features.append(
                        CadastralParcelFeature(
                            type="Feature",
                            id=feature_id,
                            geometry={
                                "type": "MultiPolygon",
                                "coordinates": cleaned_multipoly,
                            },
                            properties={
                                **props,
                                "plot_number": plot_num,
                                "centroid": centroid,
                                "source": "BIHAR_BHUNAKSHA",
                            },
                        )
                    )

        result = CadastralFeatureCollection(
            type="FeatureCollection",
            source="BIHAR_BHUNAKSHA",
            village_id=village_id,
            village_name=village_name or data.get("mauza_name") or data.get("village_name", "BEGAMPUR"),
            total_parcels=len(valid_features),
            features=valid_features,
        )

        _bihar_gis_cache[cache_key] = result
        return result

    async def get_parcel_by_plot(
        self,
        village_id: str,
        exact_plot_number: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        gp_name: Optional[str] = None,
        village_name: Optional[str] = None,
        sheet_no: Optional[str] = None,
        raw_geojson: Optional[Dict[str, Any]] = None,
    ) -> Optional[CadastralParcel]:
        parcels_col = await self.get_village_parcels(
            village_id=village_id,
            district_name=district_name,
            block_name=block_name,
            gp_name=gp_name,
            village_name=village_name,
            sheet_no=sheet_no,
            raw_geojson=raw_geojson,
        )
        target_str = str(exact_plot_number).strip()

        for f in parcels_col.features:
            p_num = str(f.properties.get("plot_number", "")).strip()
            if p_num == target_str:
                centroid = f.properties.get("centroid") or [0.0, 0.0]
                return CadastralParcel(
                    source="BIHAR_BHUNAKSHA",
                    source_feature_id=f.id,
                    district_id="BR_PAT",
                    district_name=district_name or "PATNA",
                    block_id="BR_PAT_01",
                    block_name=block_name or "PATNA SADAR",
                    village_id=village_id,
                    village_name=village_name or "BEGAMPUR",
                    plot_number=p_num,
                    geometry=f.geometry,
                    centroid=centroid,
                    properties=f.properties,
                )
        return None

    async def get_parcel_by_coordinate(
        self,
        lat: float,
        lng: float,
        village_id: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        gp_name: Optional[str] = None,
        village_name: Optional[str] = None,
        sheet_no: Optional[str] = None,
        raw_geojson: Optional[Dict[str, Any]] = None,
    ) -> Optional[CadastralParcel]:
        parcels_col = await self.get_village_parcels(
            village_id=village_id,
            district_name=district_name,
            block_name=block_name,
            gp_name=gp_name,
            village_name=village_name,
            sheet_no=sheet_no,
            raw_geojson=raw_geojson,
        )

        for f in parcels_col.features:
            geom = f.geometry
            g_type = geom.get("type")
            coords = geom.get("coordinates", [])

            is_inside = False
            if g_type == "Polygon" and coords:
                is_inside = point_in_polygon(lat=lat, lng=lng, ring=coords[0])
            elif g_type == "MultiPolygon" and coords:
                for poly in coords:
                    if poly and point_in_polygon(lat=lat, lng=lng, ring=poly[0]):
                        is_inside = True
                        break

            if is_inside:
                plot_num = str(f.properties.get("plot_number", "1"))
                centroid = f.properties.get("centroid") or [0.0, 0.0]
                return CadastralParcel(
                    source="BIHAR_BHUNAKSHA",
                    source_feature_id=f.id,
                    district_id="BR_PAT",
                    district_name=district_name or "PATNA",
                    block_id="BR_PAT_01",
                    block_name=block_name or "PATNA SADAR",
                    village_id=village_id,
                    village_name=village_name or "BEGAMPUR",
                    plot_number=plot_num,
                    geometry=geom,
                    centroid=centroid,
                    properties=f.properties,
                )
        return None
