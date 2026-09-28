"""
Bhumitra GIS Navigation Service
Provides isolated, high-performance geospatial data access for the map-based Odisha GIS Explorer.
Serves authoritative 30-district boundary geometries, tahasils/blocks, and delegates parcel queries to the official provider.
"""

import asyncio
import json
import logging
import math
import os
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple
from pydantic import BaseModel

from providers.odisha_4kgeo_provider import Odisha4KGEOProvider
from models.cadastral import (
    CadastralBlock,
    CadastralVillage,
    CadastralExtent,
    CadastralFeatureCollection,
)

logger = logging.getLogger("bhumitra.services.gis_navigation")

DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "gis"
DISTRICTS_GEOJSON_PATH = DATA_DIR / "odisha_districts.geojson"
SUBDIVISIONS_CACHE_DIR = DATA_DIR / "cache" / "subdivisions"
CUTTACK_TAHASILS_GEOJSON_PATH = DATA_DIR / "cuttack_tahasils_visualization.geojson"
KEONJHAR_TAHASILS_GEOJSON_PATH = DATA_DIR / "keonjhar_tahasils_visualization.geojson"
CENSUS_SUBDISTRICTS_GEOJSON_PATH = DATA_DIR / "odisha_subdistricts_census.geojson"

# ---------------------------------------------------------------------------
# CENSUS NAME BRIDGE
# Maps 4K GEO district names (from odisha_districts.geojson) to Census dtname
# values (from odisha_subdistricts_census.geojson). Handles spelling variants.
# Entries with None = district genuinely absent from census dataset.
# ---------------------------------------------------------------------------
CENSUS_NAME_BRIDGE: Dict[str, Optional[str]] = {
    # 4K GEO name       : Census dtname
    "Anugul":           "Anugul",
    "Baleswar":         "Baleshwar",
    "Baragarh":         "Bargarh",
    "Bhadrak":          "Bhadrak",
    "Bolangir":         "Balangir",
    "Boudh":            "Baudh",
    "Cuttack":          "Cuttack",       # served by custom file; bridge kept for completeness
    "Deogarh":          "Debagarh",
    "Dhenkanal":        "Dhenkanal",
    "Gajapati":         "Gajapati",
    "Ganjam":           "Ganjam",
    "Jagatsingpur":     "Jagatsinghapur",
    "Jajpur":           "Jajapur",
    "Jharsuguda":       "Jharsuguda",
    "Kalahandi":        "Kalahandi",
    "Kandhamal":        "Kandhamal",
    "Kendrapada":       "Kendrapara",
    "Keonjhar":         "Kendujhar",    # served by custom file; bridge kept for completeness
    "Khurda":           "Khordha",
    "Koraput":          None,           # absent from census dataset
    "Malkanagiri":      None,           # absent from census dataset
    "Mayurbhanj":       "Mayurbhanj",
    "Nawarangpur":      None,           # absent from census dataset
    "Nayagarh":         "Nayagarh",
    "Nuapada":          "Nuapada",
    "Puri":             "Puri",
    "Rayagada":         None,           # absent from census dataset
    "Sambalpur":        "Sambalpur",
    "Sonepur":          "Subarnapur",
    "Sundargarh":       "Sundargarh",
}

# Provenance declaration applied to all census-derived features.
_CENSUS_CLASSIFICATION = "Census/Survey-derived administrative visualization boundary"
_CENSUS_PROVENANCE_NOTE = (
    "Subdistrict polygons from Census of India 2011 administrative dataset. "
    "Visualization boundary only — not official cadastral or revenue tahasil limits. "
    "Census subdistrict structure may not map 1:1 to current Odisha revenue tahasil structure."
)


class GISDistrictSummary(BaseModel):
    id: str
    name: str
    code_2digit: str
    bhulekh_id: Optional[str] = None
    center_lat: float
    center_lng: float
    bbox: List[float]  # [min_lng, min_lat, max_lng, max_lat]


class GISNavigationService:
    def __init__(self, provider: Optional[Odisha4KGEOProvider] = None):
        self.provider = provider or Odisha4KGEOProvider()
        self._districts_geojson_cache: Optional[Dict[str, Any]] = None
        self._districts_summary_cache: Optional[List[GISDistrictSummary]] = None
        self._subdivision_villages_cache: Dict[str, List[CadastralVillage]] = {}
        # Census index: {census_dtname: [raw_feature, ...]} — loaded once on first use
        self._census_index: Optional[Dict[str, List[Dict[str, Any]]]] = None
        # Per-district tahasil GeoJSON cache keyed by district_id string
        self._tahasil_geojson_cache: Dict[str, Dict[str, Any]] = {}

    # ------------------------------------------------------------------
    # DISTRICT BOUNDARIES
    # ------------------------------------------------------------------

    def get_districts_geojson(self) -> Dict[str, Any]:
        """Loads and returns the 30 Odisha district boundary FeatureCollection GeoJSON."""
        if self._districts_geojson_cache is not None:
            return self._districts_geojson_cache

        if not DISTRICTS_GEOJSON_PATH.exists():
            logger.error(f"Districts GeoJSON not found at: {DISTRICTS_GEOJSON_PATH}")
            raise FileNotFoundError(f"District boundaries file not found at {DISTRICTS_GEOJSON_PATH}")

        with open(DISTRICTS_GEOJSON_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)

        self._districts_geojson_cache = data
        return data

    # ------------------------------------------------------------------
    # TAHASIL GEOMETRY — STATEWIDE
    # ------------------------------------------------------------------

    def get_tahasils_geojson_for_district(self, district_id: str) -> Dict[str, Any]:
        """
        Returns a GeoJSON FeatureCollection of Tahasil visualization boundaries for
        the given district. Features are classified as:
            'Census/Survey-derived administrative visualization boundary'
        and must NEVER be described as official cadastral or legal boundaries.

        Priority:
          1. Custom pre-built file (Keonjhar = 13 revenue-aligned tahasils, Cuttack)
          2. Census 2011 subdistrict polygons from odisha_subdistricts_census.geojson
             (covers 26 of 30 districts — transformed to match iOS schema)
          3. geometry_available=false for the 4 districts absent from census dataset
             (Koraput, Malkangiri, Nabarangpur, Rayagada)
        """
        # Normalise input
        dist_summary = self.get_district_by_id(district_id)
        four_k_name = dist_summary.name if dist_summary else ""
        four_k_id = dist_summary.id if dist_summary else district_id.strip()

        # Cache hit
        if four_k_id in self._tahasil_geojson_cache:
            return self._tahasil_geojson_cache[four_k_id]

        result = self._load_tahasils_for_district(four_k_name, four_k_id)
        self._tahasil_geojson_cache[four_k_id] = result
        return result

    def _load_tahasils_for_district(
        self, four_k_name: str, four_k_id: str
    ) -> Dict[str, Any]:
        """Internal: loads and transforms tahasil geometry for one district."""
        name_lc = four_k_name.lower()

        # ── Priority 1: custom file for Keonjhar (13 revenue-aligned tahasils)
        if "keonjhar" in name_lc or "kendujhar" in name_lc or four_k_id in ("224", "07", "7"):
            if KEONJHAR_TAHASILS_GEOJSON_PATH.exists():
                with open(KEONJHAR_TAHASILS_GEOJSON_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
                logger.info(f"GIS_TAHASIL: Keonjhar served from custom visualization file ({len(data.get('features', []))} features)")
                return data

        # ── Priority 1b: custom file for Cuttack
        if "cuttack" in name_lc or four_k_id in ("306", "03", "3"):
            if CUTTACK_TAHASILS_GEOJSON_PATH.exists():
                with open(CUTTACK_TAHASILS_GEOJSON_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
                logger.info(f"GIS_TAHASIL: Cuttack served from custom visualization file ({len(data.get('features', []))} features)")
                return data

        # ── Priority 2: Census 2011 subdistrict polygons
        census_dtname = CENSUS_NAME_BRIDGE.get(four_k_name)

        if census_dtname is not None:
            census_features = self._load_census_index().get(census_dtname, [])
            if census_features:
                transformed = [
                    self._census_feature_to_tahasil_geojson(feat, four_k_id)
                    for feat in census_features
                ]
                fc = {
                    "type": "FeatureCollection",
                    "name": f"tahasils_{four_k_id}_census",
                    "geometry_available": True,
                    "provenance": {
                        "source": "Census of India 2011 subdistrict administrative dataset",
                        "classification": _CENSUS_CLASSIFICATION,
                        "notes": _CENSUS_PROVENANCE_NOTE,
                    },
                    "features": transformed,
                }
                logger.info(
                    f"GIS_TAHASIL: {four_k_name} (id={four_k_id}) served from census "
                    f"({len(transformed)} subdistricts, census dtname='{census_dtname}')"
                )
                return fc

        # ── Priority 3: genuinely absent from census dataset
        logger.warning(
            f"GIS_TAHASIL: {four_k_name} (id={four_k_id}) has no geometry in census dataset. "
            f"Returning geometry_available=false."
        )
        return {
            "type": "FeatureCollection",
            "name": f"tahasils_{four_k_id}",
            "geometry_available": False,
            "provenance": {
                "classification": _CENSUS_CLASSIFICATION,
                "notes": "Tahasil visualization geometry unavailable for this district in the current dataset.",
            },
            "features": [],
        }

    # ------------------------------------------------------------------
    # CENSUS INDEX — loaded once, keyed by Census dtname
    # ------------------------------------------------------------------

    def _load_census_index(self) -> Dict[str, List[Dict[str, Any]]]:
        """Loads odisha_subdistricts_census.geojson and indexes by Census dtname."""
        if self._census_index is not None:
            return self._census_index

        if not CENSUS_SUBDISTRICTS_GEOJSON_PATH.exists():
            logger.error(f"Census subdistricts GeoJSON not found at: {CENSUS_SUBDISTRICTS_GEOJSON_PATH}")
            self._census_index = {}
            return {}

        with open(CENSUS_SUBDISTRICTS_GEOJSON_PATH, "r", encoding="utf-8") as f:
            raw = json.load(f)

        index: Dict[str, List[Dict[str, Any]]] = {}
        for feat in raw.get("features", []):
            dtname = feat.get("properties", {}).get("dtname", "")
            if dtname:
                index.setdefault(dtname, []).append(feat)

        self._census_index = index
        total_features = sum(len(v) for v in index.values())
        logger.info(
            f"GIS_TAHASIL: Census index built — {len(index)} districts, {total_features} subdistricts"
        )
        return index

    # ------------------------------------------------------------------
    # GEOMETRY HELPERS — pure Python, no external dependencies
    # ------------------------------------------------------------------

    @staticmethod
    def _extract_rings(geometry: Dict[str, Any]) -> List[List[List[float]]]:
        """Returns a flat list of coordinate rings from Polygon or MultiPolygon geometry."""
        gtype = geometry.get("type", "")
        coords = geometry.get("coordinates", [])
        if gtype == "Polygon":
            return [ring for ring in coords if ring]
        elif gtype == "MultiPolygon":
            rings = []
            for polygon in coords:
                for ring in polygon:
                    if ring:
                        rings.append(ring)
            return rings
        return []

    @staticmethod
    def _bbox_and_centroid(
        geometry: Dict[str, Any],
    ) -> Tuple[List[float], List[float]]:
        """
        Computes [min_lng, min_lat, max_lng, max_lat] bounding box and [lng, lat]
        centroid from a GeoJSON Polygon or MultiPolygon geometry.
        Returns ([0,0,0,0], [0,0]) on empty/invalid geometry.
        """
        all_pts: List[Tuple[float, float]] = []
        for ring in GISNavigationService._extract_rings(geometry):
            for pt in ring:
                if len(pt) >= 2:
                    all_pts.append((float(pt[0]), float(pt[1])))

        if not all_pts:
            return [0.0, 0.0, 0.0, 0.0], [0.0, 0.0]

        lngs = [p[0] for p in all_pts]
        lats = [p[1] for p in all_pts]
        bbox = [min(lngs), min(lats), max(lngs), max(lats)]
        center = [
            round((bbox[0] + bbox[2]) / 2, 6),
            round((bbox[1] + bbox[3]) / 2, 6),
        ]
        return bbox, center

    # ------------------------------------------------------------------
    # CENSUS FEATURE TRANSFORM
    # ------------------------------------------------------------------

    def _census_feature_to_tahasil_geojson(
        self, feature: Dict[str, Any], four_k_dist_id: str
    ) -> Dict[str, Any]:
        """
        Transforms one raw Census subdistrict feature into a GeoJSON Feature
        with the iOS-expected property schema.

        Census fields used:
          sdtname    -> tahasil_name
          Subdt_LGD  -> tahasil_id (stable LGD code, unique nationwide)
          sdtcode11  -> census_sdtcode11 (preserved as provenance)
          Dist_LGD   -> census_dist_lgd (preserved as provenance)
          dtcode11   -> census_dtcode11 (preserved as provenance)
          dtname     -> census_dtname (preserved as provenance)

        Classification: VISUALIZATION ONLY — not official cadastral limits.
        """
        props = feature.get("properties", {})
        geometry = feature.get("geometry", {})

        subdt_lgd = props.get("Subdt_LGD", 0)
        tahasil_id = str(subdt_lgd)
        tahasil_name = str(props.get("sdtname", "")).strip()

        bbox, center = self._bbox_and_centroid(geometry)

        out_props = {
            # iOS-expected fields
            "tahasil_id": tahasil_id,
            "tahasil_name": tahasil_name,
            "tahasil_name_odia": None,          # not available in census dataset
            "bhulekh_tahasil_id": None,         # requires separate revenue crosswalk
            "district_id": four_k_dist_id,
            "center": center,                   # [lng, lat]
            "bbox": bbox,                       # [min_lng, min_lat, max_lng, max_lat]
            "is_visualization_boundary": True,
            "classification": _CENSUS_CLASSIFICATION,
            # Provenance — preserved from census source for traceability
            "census_subdt_lgd": subdt_lgd,
            "census_sdtcode11": props.get("sdtcode11", ""),
            "census_dist_lgd": props.get("Dist_LGD", ""),
            "census_dtcode11": props.get("dtcode11", ""),
            "census_dtname": props.get("dtname", ""),
        }

        return {
            "type": "Feature",
            "properties": out_props,
            "geometry": geometry,
        }

    def get_districts_summary(self) -> List[GISDistrictSummary]:
        """Returns structured metadata list of all 30 districts with centers and bboxes."""
        if self._districts_summary_cache is not None:
            return self._districts_summary_cache

        fc = self.get_districts_geojson()
        summaries: List[GISDistrictSummary] = []

        for feat in fc.get("features", []):
            props = feat.get("properties", {})
            center = props.get("center", [85.0, 20.5])
            bbox = props.get("bbox", [81.0, 17.0, 88.0, 23.0])
            summaries.append(
                GISDistrictSummary(
                    id=str(props.get("district_id", "")),
                    name=str(props.get("district_name", "")),
                    code_2digit=str(props.get("code_2digit", "")),
                    bhulekh_id=str(props.get("bhulekh_id", "")) if props.get("bhulekh_id") else None,
                    center_lat=float(center[1]),
                    center_lng=float(center[0]),
                    bbox=[float(b) for b in bbox],
                )
            )

        summaries.sort(key=lambda d: d.name)
        self._districts_summary_cache = summaries
        return summaries

    def get_district_by_id(self, district_id: str) -> Optional[GISDistrictSummary]:
        """
        Returns district metadata for a given district ID.
        Lookup priority (to avoid ambiguity where code_2digit == another district's id):
          1. Exact 4K GEO district_id match
          2. code_2digit match
          3. name (case-insensitive)
        """
        districts = self.get_districts_summary()
        clean_id = district_id.strip().lower()
        # Pass 1: exact 4K GEO district_id
        for d in districts:
            if d.id.lower() == clean_id:
                return d
        # Pass 1B: bhulekh_id match (critical for 1- or 2-digit Bhulekh IDs like '1', '2', '3')
        for d in districts:
            if d.bhulekh_id and str(d.bhulekh_id).lower() == clean_id:
                return d
        # Pass 2: code_2digit (fallback, including zero-padded 2-digit representation)
        clean_2digit = f"{int(clean_id):02d}" if clean_id.isdigit() else clean_id
        for d in districts:
            if d.code_2digit.lower() == clean_id or d.code_2digit.lower() == clean_2digit:
                return d
        # Pass 3: district name (case-insensitive)
        for d in districts:
            if d.name.lower() == clean_id:
                return d
        return None

    async def get_subdivisions_for_district(
        self, district_id: str, district_name: Optional[str] = None
    ) -> List[CadastralBlock]:
        """Fetches tahasils / blocks for a district."""
        dist_summary = self.get_district_by_id(district_id)
        effective_id = dist_summary.id if dist_summary else district_id
        effective_name = dist_summary.name if dist_summary else district_name
        return await self.provider.get_blocks(district_id=effective_id, district_name=effective_name)

    async def get_villages_for_subdivision(
        self,
        subdivision_id: str,
        gp_id: Optional[str] = None,
        block_name: Optional[str] = None,
        district_name: Optional[str] = None,
    ) -> List[CadastralVillage]:
        """Fetches revenue villages for a tahasil/block."""
        clean_sub_id = str(subdivision_id).strip()
        if gp_id:
            return await self.provider.get_villages(
                gp_id=gp_id,
                block_id=clean_sub_id,
                block_name=block_name,
                district_name=district_name,
            )

        # Check in-memory cache for entire subdivision aggregation
        if clean_sub_id in self._subdivision_villages_cache:
            return self._subdivision_villages_cache[clean_sub_id]

        # Check local persistent disk cache
        cache_file = SUBDIVISIONS_CACHE_DIR / f"{clean_sub_id}_villages.json"
        if cache_file.exists():
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    cached_raw = json.load(f)
                villages = [CadastralVillage(**v) for v in cached_raw]
                self._subdivision_villages_cache[clean_sub_id] = villages
                return villages
            except Exception as e:
                logger.warning(f"Failed to read disk cache for subdivision {clean_sub_id}: {e}")

        # Fetch all Gram Panchayats under this block/subdivision
        gps = await self.provider.get_gps(
            block_id=clean_sub_id,
            block_name=block_name,
            district_name=district_name,
        )

        if not gps:
            # Fallback to direct call if no GPs are returned
            return await self.provider.get_villages(
                gp_id=None,
                block_id=clean_sub_id,
                block_name=block_name,
                district_name=district_name,
            )

        # Query villages for each GP concurrently using bounded concurrency
        sem = asyncio.Semaphore(10)

        async def _fetch_gp(g_code: str) -> List[CadastralVillage]:
            async with sem:
                for attempt in range(2):
                    try:
                        return await self.provider.get_villages(
                            gp_id=g_code,
                            block_id=clean_sub_id,
                            block_name=block_name,
                            district_name=district_name,
                        )
                    except Exception as e:
                        if attempt == 0:
                            await asyncio.sleep(0.4)
                            continue
                        logger.warning(f"Error fetching villages for GP {g_code} in subdivision {clean_sub_id}: {e}")
                        return []
                return []

        results = await asyncio.gather(*(_fetch_gp(gp.id) for gp in gps), return_exceptions=False)

        seen_ids = set()
        deduped: List[CadastralVillage] = []
        for vlist in results:
            for v in vlist:
                if v.id not in seen_ids:
                    seen_ids.add(v.id)
                    deduped.append(v)

        deduped.sort(key=lambda v: (v.id, v.name))
        self._subdivision_villages_cache[clean_sub_id] = deduped
        try:
            SUBDIVISIONS_CACHE_DIR.mkdir(parents=True, exist_ok=True)
            with open(cache_file, "w", encoding="utf-8") as f:
                json.dump([v.model_dump() for v in deduped], f, indent=2, ensure_ascii=False)
        except Exception as e:
            logger.warning(f"Failed to write disk cache for subdivision {clean_sub_id}: {e}")

        return deduped

    async def get_village_extent(self, village_id: str, gp_id: Optional[str] = None) -> Optional[CadastralExtent]:
        """Fetches bounding extent for a revenue village."""
        return await self.provider.get_village_extent(village_id=village_id, gp_id=gp_id)

    async def get_village_parcels(
        self,
        village_id: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        village_name: Optional[str] = None,
    ) -> CadastralFeatureCollection:
        """Fetches normalized WGS84 parcel polygons for a village."""
        return await self.provider.get_village_parcels(
            village_id=village_id,
            district_name=district_name,
            block_name=block_name,
            village_name=village_name,
        )


gis_navigation_service = GISNavigationService()
