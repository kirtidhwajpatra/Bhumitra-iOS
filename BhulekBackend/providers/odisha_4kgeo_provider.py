"""
Odisha 4K GEO (ORSAC) Concrete Cadastral Provider Implementation
Communicates directly with official 4K GEO endpoints, performs EPSG:3857 -> EPSG:4326
transformations, normalizes GeoJSON collections, and provides in-memory TTL caching.
"""

import json
import logging
import httpx
from typing import List, Optional, Dict, Any
from cachetools import TTLCache
from datetime import datetime, timezone

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
from utils.crs_converter import (
    transform_geojson_geometry,
    calculate_polygon_centroid,
    point_in_polygon,
    epsg3857_to_epsg4326,
    is_likely_epsg3857,
)

logger = logging.getLogger("bhumitra.cadastral.4kgeo")

OFFICIAL_4KGEO_DISTRICTS: List[Dict[str, str]] = [
    {"id": "161", "name": "Anugul"},
    {"id": "218", "name": "Baleswar"},
    {"id": "171", "name": "Baragarh"},
    {"id": "178", "name": "Bhadrak"},
    {"id": "162", "name": "Bolangir"},
    {"id": "177", "name": "Boudh"},
    {"id": "306", "name": "Cuttack"},
    {"id": "150", "name": "Deogarh"},
    {"id": "107", "name": "Dhenkanal"},
    {"id": "133", "name": "Gajapati"},
    {"id": "104", "name": "Ganjam"},
    {"id": "202", "name": "Jagatsingpur"},
    {"id": "73", "name": "Jajpur"},
    {"id": "51", "name": "Jharsuguda"},
    {"id": "52", "name": "Kalahandi"},
    {"id": "278", "name": "Kandhamal"},
    {"id": "200", "name": "Kendrapada"},
    {"id": "224", "name": "Keonjhar"},
    {"id": "234", "name": "Khurda"},
    {"id": "120", "name": "Koraput"},
    {"id": "116", "name": "Malkanagiri"},
    {"id": "282", "name": "Mayurbhanj"},
    {"id": "300", "name": "Nawarangpur"},
    {"id": "111", "name": "Nayagarh"},
    {"id": "130", "name": "Nuapada"},
    {"id": "60", "name": "Puri"},
    {"id": "22", "name": "Rayagada"},
    {"id": "47", "name": "Sambalpur"},
    {"id": "238", "name": "Sonepur"},
    {"id": "72", "name": "Sundargarh"},
]


class Odisha4KGEOProvider(CadastralProvider):
    """
    Official Provider communicating with Odisha 4K GEO REST/AJAX backend.
    """

    def __init__(
        self,
        base_url: str = "https://odisha4kgeo.in/index.php/mapview",
        admin_base_url: str = "https://odisha4kgeo.in/admin",
        timeout_seconds: float = 15.0,
    ):
        self.base_url = base_url.rstrip("/")
        self.admin_base_url = admin_base_url.rstrip("/")
        self.timeout = timeout_seconds

        # Configurable TTL Caches
        self._districts_cache: TTLCache = TTLCache(maxsize=10, ttl=86400)  # 24 hours
        self._blocks_cache: TTLCache = TTLCache(maxsize=100, ttl=86400)    # 24 hours
        self._gps_cache: TTLCache = TTLCache(maxsize=1000, ttl=86400)      # 24 hours
        self._villages_cache: TTLCache = TTLCache(maxsize=5000, ttl=86400) # 24 hours
        self._parcels_cache: TTLCache = TTLCache(maxsize=500, ttl=43200)   # 12 hours
        self._extents_cache: TTLCache = TTLCache(maxsize=5000, ttl=86400)  # 24 hours

    def _get_client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(
            timeout=self.timeout,
            headers={
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept": "application/json, text/javascript, */*; q=0.01",
                "X-Requested-With": "XMLHttpRequest",
            },
            verify=False,  # Government state portal cert chain tolerance
        )

    # ==========================================================================
    # Hierarchy Navigation
    # ==========================================================================

    async def get_districts(self) -> List[CadastralDistrict]:
        """Returns the 30 official administrative districts."""
        if "districts" in self._districts_cache:
            return self._districts_cache["districts"]

        districts = [
            CadastralDistrict(id=item["id"], name=item["name"])
            for item in OFFICIAL_4KGEO_DISTRICTS
        ]
        self._districts_cache["districts"] = districts
        return districts

    async def get_blocks(self, district_id: str, district_name: Optional[str] = None) -> List[CadastralBlock]:
        """Fetch all blocks for a district from 4K GEO."""
        clean_dist_id = str(district_id).strip()
        cache_key = f"blocks:{clean_dist_id}"
        if cache_key in self._blocks_cache:
            return self._blocks_cache[cache_key]

        url = f"{self.base_url}/getBlocks"
        async with self._get_client() as client:
            try:
                res = await client.post(url, data={"district": clean_dist_id})
                if res.status_code != 200:
                    logger.error(f"4KGEO_GET_BLOCKS_ERROR: HTTP {res.status_code} for district={clean_dist_id}")
                    raise ConnectionError(f"4K GEO getBlocks returned status {res.status_code}")

                raw_data = res.json()
                if isinstance(raw_data, dict) and not raw_data.get("succ", True):
                    logger.warning(f"4KGEO_GET_BLOCKS_FAIL: {raw_data.get('msg')}")
                    return []

                blocks: List[CadastralBlock] = []
                for item in raw_data:
                    b_code = str(item.get("block_code", "")).strip()
                    b_name = str(item.get("block_name", "")).strip()
                    if b_code and b_name:
                        blocks.append(CadastralBlock(id=b_code, name=b_name, district_id=clean_dist_id))

                self._blocks_cache[cache_key] = blocks
                return blocks
            except httpx.TimeoutException:
                logger.error(f"4KGEO_GET_BLOCKS_TIMEOUT for district={clean_dist_id}")
                raise TimeoutError("4K GEO request timed out while fetching blocks.")
            except Exception as e:
                logger.error(f"4KGEO_GET_BLOCKS_EXCEPTION: {e}")
                raise

    async def get_gram_panchayats(
        self, block_id: str, block_name: Optional[str] = None, district_name: Optional[str] = None
    ) -> List[CadastralGP]:
        """Fetch all Gram Panchayats for a given block."""
        clean_block_id = str(block_id).strip()
        cache_key = f"gps:{clean_block_id}"
        if cache_key in self._gps_cache:
            return self._gps_cache[cache_key]

        url = f"{self.base_url}/getRevenueGP"
        async with self._get_client() as client:
            try:
                res = await client.post(url, data={"blocks": clean_block_id})
                if res.status_code != 200:
                    logger.error(f"4KGEO_GET_GPS_ERROR: HTTP {res.status_code} for block={clean_block_id}")
                    raise ConnectionError(f"4K GEO getRevenueGP returned status {res.status_code}")

                raw_data = res.json()
                if isinstance(raw_data, dict) and not raw_data.get("succ", True):
                    return []

                gps: List[CadastralGP] = []
                for item in raw_data:
                    gp_code = str(item.get("grampanchayat_code") or item.get("gp_code") or item.get("code") or "").strip()
                    gp_name = str(item.get("grampanchayat_name") or item.get("gp_name") or item.get("name") or "").strip()
                    if gp_code and gp_name:
                        gps.append(CadastralGP(id=gp_code, name=gp_name, block_id=clean_block_id))

                self._gps_cache[cache_key] = gps
                return gps
            except httpx.TimeoutException:
                logger.error(f"4KGEO_GET_GPS_TIMEOUT for block={clean_block_id}")
                raise TimeoutError("4K GEO request timed out while fetching Gram Panchayats.")
            except Exception as e:
                logger.error(f"4KGEO_GET_GPS_EXCEPTION: {e}")
                raise

    async def get_villages(
        self,
        gp_id: Optional[str],
        block_id: str,
        block_name: Optional[str] = None,
        district_name: Optional[str] = None,
    ) -> List[CadastralVillage]:
        """Fetch all revenue villages for a given GP / Block."""
        clean_block_id = str(block_id).strip()
        clean_gp_id = str(gp_id).strip() if gp_id else ""
        cache_key = f"villages:{clean_block_id}:{clean_gp_id}"
        if cache_key in self._villages_cache:
            return self._villages_cache[cache_key]

        url = f"{self.base_url}/getVillage"
        payload = {"blocks": clean_block_id}
        if clean_gp_id:
            payload["lulcgp"] = clean_gp_id

        async with self._get_client() as client:
            try:
                res = await client.post(url, data=payload)
                if res.status_code != 200:
                    logger.error(f"4KGEO_GET_VILLAGES_ERROR: HTTP {res.status_code} for block={clean_block_id}, gp={clean_gp_id}")
                    raise ConnectionError(f"4K GEO getVillage returned status {res.status_code}")

                raw_data = res.json()
                if isinstance(raw_data, dict) and not raw_data.get("succ", True):
                    return []

                villages: List[CadastralVillage] = []
                for item in raw_data:
                    v_code = str(item.get("revenue_village_code", "")).strip()
                    v_name = str(item.get("revenue_village_name", "")).strip()
                    if v_code and v_name:
                        villages.append(
                            CadastralVillage(
                                id=v_code,
                                name=v_name,
                                gp_id=clean_gp_id if clean_gp_id else None,
                                block_id=clean_block_id,
                            )
                        )

                self._villages_cache[cache_key] = villages
                return villages
            except httpx.TimeoutException:
                logger.error(f"4KGEO_GET_VILLAGES_TIMEOUT for block={clean_block_id}")
                raise TimeoutError("4K GEO request timed out while fetching Villages.")
            except Exception as e:
                logger.error(f"4KGEO_GET_VILLAGES_EXCEPTION: {e}")
                raise

    # ==========================================================================
    # Extent Queries
    # ==========================================================================

    async def get_village_extent(self, village_id: str, gp_id: Optional[str] = None) -> Optional[CadastralExtent]:
        """Fetches the bounding box extent for a revenue village with parcel fallback."""
        clean_v_id = str(village_id).strip()
        clean_gp_id = str(gp_id).strip() if gp_id else ""
        cache_key = f"extent:{clean_v_id}:{clean_gp_id}"
        if cache_key in self._extents_cache:
            return self._extents_cache[cache_key]

        # 1. Try official endpoint if GP is provided
        if clean_gp_id:
            url = f"{self.base_url}/getVillageExtent"
            payload = {"lulcvillage": clean_v_id, "lulcgp": clean_gp_id}

            async with self._get_client() as client:
                try:
                    res = await client.post(url, data=payload)
                    if res.status_code == 200:
                        data = res.json()
                        if isinstance(data, dict) and data.get("succ", True) and "extent" in data:
                            ext_str = data["extent"]
                            parts = [float(p.strip()) for p in ext_str.split(",")]
                            if len(parts) >= 4:
                                min_x, min_y, max_x, max_y = parts[0], parts[1], parts[2], parts[3]
                                if is_likely_epsg3857(min_x, min_y):
                                    min_lng, min_lat = epsg3857_to_epsg4326(min_x, min_y)
                                    max_lng, max_lat = epsg3857_to_epsg4326(max_x, max_y)
                                else:
                                    min_lng, min_lat, max_lng, max_lat = min_x, min_y, max_x, max_y

                                extent_obj = CadastralExtent(
                                    min_lng=min_lng,
                                    min_lat=min_lat,
                                    max_lng=max_lng,
                                    max_lat=max_lat,
                                    center_lng=round((min_lng + max_lng) / 2.0, 7),
                                    center_lat=round((min_lat + max_lat) / 2.0, 7),
                                )
                                self._extents_cache[cache_key] = extent_obj
                                return extent_obj
                except Exception as e:
                    logger.warning(f"4KGEO_GET_EXTENT_EXCEPTION: {e}")

        # 2. Reliable Fallback: Calculate bounding extent directly from village parcels collection
        try:
            fc = await self.get_village_parcels(village_id=clean_v_id)
            if fc.total_parcels > 0:
                all_lngs: List[float] = []
                all_lats: List[float] = []
                for feat in fc.features:
                    c = feat.properties.get("centroid", [])
                    if len(c) >= 2 and (c[0] != 0.0 or c[1] != 0.0):
                        all_lngs.append(float(c[0]))
                        all_lats.append(float(c[1]))
                
                if all_lngs and all_lats:
                    min_lng = min(all_lngs)
                    max_lng = max(all_lngs)
                    min_lat = min(all_lats)
                    max_lat = max(all_lats)
                    extent_obj = CadastralExtent(
                        min_lng=min_lng,
                        min_lat=min_lat,
                        max_lng=max_lng,
                        max_lat=max_lat,
                        center_lng=round((min_lng + max_lng) / 2.0, 7),
                        center_lat=round((min_lat + max_lat) / 2.0, 7),
                    )
                    self._extents_cache[cache_key] = extent_obj
                    return extent_obj
        except Exception as e:
            logger.warning(f"4KGEO_EXTENT_FROM_PARCELS_EXCEPTION: {e}")

        return None

    # ==========================================================================
    # Cadastral Parcels & Geometry
    # ==========================================================================

    async def get_village_parcels(
        self,
        village_id: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        gp_name: Optional[str] = None,
        village_name: Optional[str] = None,
    ) -> CadastralFeatureCollection:
        """
        Fetches official cadastral parcel polygons from 4K GEO, normalizes CRS from
        EPSG:3857 to WGS84 EPSG:4326, preserves verbatim plot strings, and returns
        a normalized FeatureCollection.
        """
        clean_v_id = str(village_id).strip()
        cache_key = f"parcels:{clean_v_id}"
        if cache_key in self._parcels_cache:
            return self._parcels_cache[cache_key]

        url = f"{self.base_url}/viewCadistrialResult"
        payload = {
            "district": district_name or "",
            "block": block_name or "",
            "value": clean_v_id,
            "field": "revenue_village_code",
        }

        async with self._get_client() as client:
            try:
                res = await client.post(url, data=payload)
                if res.status_code != 200:
                    logger.error(f"4KGEO_GET_PARCELS_ERROR: HTTP {res.status_code} for village={clean_v_id}")
                    raise ConnectionError(f"4K GEO viewCadistrialResult returned status {res.status_code}")

                raw_text = res.text.strip()
                if not raw_text or raw_text.startswith("<"):
                    # HTML error page or empty response
                    logger.warning(f"4KGEO_NON_JSON_RESPONSE for village={clean_v_id}: {raw_text[:200]}")
                    fc = CadastralFeatureCollection(
                        source="ODISHA_4K_GEO",
                        village_id=clean_v_id,
                        village_name=village_name,
                        total_parcels=0,
                        features=[],
                    )
                    self._parcels_cache[cache_key] = fc
                    return fc

                geo_data = json.loads(raw_text)
                features_raw = geo_data.get("features", []) if isinstance(geo_data, dict) else []

                normalized_features: List[CadastralParcelFeature] = []

                for idx, feat in enumerate(features_raw):
                    if not isinstance(feat, dict):
                        continue

                    raw_props = feat.get("properties", {}) or {}
                    raw_geom = feat.get("geometry", {}) or {}

                    # Extract exact verbatim plot number
                    plot_str = str(raw_props.get("revenue_plot", "")).strip()
                    if not plot_str or not raw_geom or "coordinates" not in raw_geom:
                        continue

                    # Explicit CRS Conversion: EPSG:3857 -> EPSG:4326
                    wgs84_geom = transform_geojson_geometry(raw_geom)
                    centroid = calculate_polygon_centroid(wgs84_geom)

                    feature_id = f"{clean_v_id}_{plot_str}"

                    # Clean normalized properties
                    props = {
                        "plot_number": plot_str,
                        "revenue_plot": plot_str,
                        "village_id": clean_v_id,
                        "village_name": village_name or raw_props.get("village", ""),
                        "block_name": block_name or raw_props.get("block", ""),
                        "district_name": district_name or raw_props.get("district", ""),
                        "centroid": centroid,
                        "source": "ODISHA_4K_GEO",
                    }

                    normalized_features.append(
                        CadastralParcelFeature(
                            type="Feature",
                            id=feature_id,
                            geometry=wgs84_geom,
                            properties=props,
                        )
                    )

                fc = CadastralFeatureCollection(
                    source="ODISHA_4K_GEO",
                    village_id=clean_v_id,
                    village_name=village_name,
                    total_parcels=len(normalized_features),
                    features=normalized_features,
                )

                self._parcels_cache[cache_key] = fc
                return fc

            except httpx.TimeoutException:
                logger.error(f"4KGEO_GET_PARCELS_TIMEOUT for village={clean_v_id}")
                raise TimeoutError("4K GEO request timed out while fetching village parcels.")
            except Exception as e:
                logger.error(f"4KGEO_GET_PARCELS_EXCEPTION: {e}")
                raise

    async def get_parcel_by_plot(
        self,
        village_id: str,
        exact_plot_number: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        gp_name: Optional[str] = None,
        village_name: Optional[str] = None,
    ) -> Optional[CadastralParcel]:
        """
        Retrieves a single parcel by exact verbatim plot number match.
        Zero substring, prefix, or fuzzy matching.
        """
        clean_plot = str(exact_plot_number).strip()
        fc = await self.get_village_parcels(
            village_id=village_id,
            district_name=district_name,
            block_name=block_name,
            gp_name=gp_name,
            village_name=village_name,
        )

        for feat in fc.features:
            if feat.properties.get("plot_number") == clean_plot or feat.properties.get("revenue_plot") == clean_plot:
                return CadastralParcel(
                    source="ODISHA_4K_GEO",
                    source_feature_id=feat.id,
                    district_id=feat.properties.get("district_id") or (village_id[:2] if len(village_id) >= 2 else ""),
                    district_name=district_name or feat.properties.get("district"),
                    block_id=feat.properties.get("block_id") or (village_id[:4] if len(village_id) >= 4 else ""),
                    block_name=block_name or feat.properties.get("block"),
                    gp_id=feat.properties.get("gp_id"),
                    village_id=village_id,
                    village_name=village_name or feat.properties.get("village"),
                    plot_number=clean_plot,
                    geometry=feat.geometry,
                    centroid=feat.properties.get("centroid", [0.0, 0.0]),
                    properties=feat.properties,
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
    ) -> Optional[CadastralParcel]:
        """
        Spatial point-in-polygon resolution within the village parcel FeatureCollection.
        """
        fc = await self.get_village_parcels(
            village_id=village_id,
            district_name=district_name,
            block_name=block_name,
            gp_name=gp_name,
            village_name=village_name,
        )

        for feat in fc.features:
            geom = feat.geometry
            if geom.get("type") == "Polygon":
                coords = geom.get("coordinates", [])
                if point_in_polygon(lng, lat, coords):
                    plot_no = feat.properties.get("plot_number", "")
                    return CadastralParcel(
                        source="ODISHA_4K_GEO",
                        source_feature_id=feat.id,
                        district_id="07",
                        district_name=district_name,
                        block_id=village_id[:4] if len(village_id) >= 4 else "0704",
                        block_name=block_name,
                        gp_id=None,
                        village_id=village_id,
                        village_name=village_name,
                        plot_number=plot_no,
                        geometry=feat.geometry,
                        centroid=feat.properties.get("centroid", [0.0, 0.0]),
                        properties=feat.properties,
                    )
            elif geom.get("type") == "MultiPolygon":
                for poly_coords in geom.get("coordinates", []):
                    if point_in_polygon(lng, lat, poly_coords):
                        plot_no = feat.properties.get("plot_number", "")
                        return CadastralParcel(
                            source="ODISHA_4K_GEO",
                            source_feature_id=feat.id,
                            district_id="07",
                            district_name=district_name,
                            block_id=village_id[:4] if len(village_id) >= 4 else "0704",
                            block_name=block_name,
                            gp_id=None,
                            village_id=village_id,
                            village_name=village_name,
                            plot_number=plot_no,
                            geometry=feat.geometry,
                            centroid=feat.properties.get("centroid", [0.0, 0.0]),
                            properties=feat.properties,
                        )

        return None
