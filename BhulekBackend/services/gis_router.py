"""
State-Aware Cadastral GIS Routing Layer
Dispatches GIS requests to state providers (Odisha 4K GEO or Bihar BhuNaksha)
with complete isolation, fail-closed feature gating, and zero fallback.
"""

import logging
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status

from core.config import settings
from models.cadastral import (
    CadastralDistrict,
    CadastralBlock,
    CadastralGP,
    CadastralVillage,
    CadastralExtent,
    CadastralParcel,
    CadastralFeatureCollection,
)
from providers.odisha_4kgeo_provider import Odisha4KGEOProvider
from providers.bihar_cadastral_provider import BiharCadastralProvider, MAX_PARCELS_PER_VILLAGE

logger = logging.getLogger("bhumitra.services.gis_router")


class GISRouter:
    """
    State-aware dispatcher routing cadastral queries to isolated providers.
    """

    def __init__(
        self,
        odisha_provider: Optional[Odisha4KGEOProvider] = None,
        bihar_provider: Optional[BiharCadastralProvider] = None,
    ):
        self.odisha_provider = odisha_provider or Odisha4KGEOProvider()
        self.bihar_provider = bihar_provider or BiharCadastralProvider()

    def _resolve_provider(self, state: Optional[str] = "ODISHA"):
        norm_state = (state or "ODISHA").strip().upper()
        if norm_state == "BIHAR":
            if not settings.BIHAR_GIS_PROVIDER_ENABLED:
                logger.warning("Bihar GIS lookup attempted while BIHAR_GIS_PROVIDER_ENABLED is False.")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail={
                        "error_code": "BIHAR_GIS_DISABLED",
                        "message": "Bihar cadastral GIS provider is currently disabled by administrative configuration.",
                        "retryable": False,
                    },
                )
            return self.bihar_provider, "BIHAR"
        elif norm_state == "ODISHA":
            return self.odisha_provider, "ODISHA"
        else:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    "error_code": "UNSUPPORTED_STATE",
                    "message": f"Unsupported state '{norm_state}'. Valid supported states: ODISHA, BIHAR.",
                },
            )

    async def get_districts(self, state: Optional[str] = "ODISHA") -> List[CadastralDistrict]:
        prov, _ = self._resolve_provider(state)
        return await prov.get_districts()

    async def get_blocks(
        self, district_id: str, district_name: Optional[str] = None, state: Optional[str] = "ODISHA"
    ) -> List[CadastralBlock]:
        prov, _ = self._resolve_provider(state)
        return await prov.get_blocks(district_id=district_id, district_name=district_name)

    async def get_gram_panchayats(
        self,
        block_id: str,
        block_name: Optional[str] = None,
        district_name: Optional[str] = None,
        state: Optional[str] = "ODISHA",
    ) -> List[CadastralGP]:
        prov, _ = self._resolve_provider(state)
        return await prov.get_gram_panchayats(
            block_id=block_id, block_name=block_name, district_name=district_name
        )

    async def get_villages(
        self,
        block_id: str,
        gp_id: Optional[str] = None,
        block_name: Optional[str] = None,
        district_name: Optional[str] = None,
        state: Optional[str] = "ODISHA",
    ) -> List[CadastralVillage]:
        prov, _ = self._resolve_provider(state)
        return await prov.get_villages(
            gp_id=gp_id,
            block_id=block_id,
            block_name=block_name,
            district_name=district_name,
        )

    async def get_village_extent(
        self, village_id: str, gp_id: Optional[str] = None, state: Optional[str] = "ODISHA"
    ) -> Optional[CadastralExtent]:
        prov, _ = self._resolve_provider(state)
        return await prov.get_village_extent(village_id=village_id, gp_id=gp_id)

    async def get_village_parcels(
        self,
        village_id: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        gp_name: Optional[str] = None,
        village_name: Optional[str] = None,
        sheet_no: Optional[str] = None,
        state: Optional[str] = "ODISHA",
        raw_geojson: Optional[Dict[str, Any]] = None,
    ) -> CadastralFeatureCollection:
        prov, norm_state = self._resolve_provider(state)
        if norm_state == "BIHAR":
            res = await prov.get_village_parcels(
                village_id=village_id,
                district_name=district_name,
                block_name=block_name,
                gp_name=gp_name,
                village_name=village_name,
                sheet_no=sheet_no,
                raw_geojson=raw_geojson,
            )
        else:
            res = await prov.get_village_parcels(
                village_id=village_id,
                district_name=district_name,
                block_name=block_name,
                gp_name=gp_name,
                village_name=village_name,
            )

        if res and res.total_parcels > MAX_PARCELS_PER_VILLAGE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail={
                    "error_code": "GIS_MAP_TOO_LARGE",
                    "message": f"Cadastral village contains {res.total_parcels} parcels, exceeding safe display limit of {MAX_PARCELS_PER_VILLAGE}.",
                },
            )
        return res

    async def get_parcel_by_plot(
        self,
        village_id: str,
        plot_number: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        gp_name: Optional[str] = None,
        village_name: Optional[str] = None,
        sheet_no: Optional[str] = None,
        state: Optional[str] = "ODISHA",
        raw_geojson: Optional[Dict[str, Any]] = None,
    ) -> Optional[CadastralParcel]:
        prov, norm_state = self._resolve_provider(state)
        if norm_state == "BIHAR":
            return await prov.get_parcel_by_plot(
                village_id=village_id,
                exact_plot_number=plot_number,
                district_name=district_name,
                block_name=block_name,
                gp_name=gp_name,
                village_name=village_name,
                sheet_no=sheet_no,
                raw_geojson=raw_geojson,
            )
        else:
            return await prov.get_parcel_by_plot(
                village_id=village_id,
                exact_plot_number=plot_number,
                district_name=district_name,
                block_name=block_name,
                gp_name=gp_name,
                village_name=village_name,
            )

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
        state: Optional[str] = "ODISHA",
        raw_geojson: Optional[Dict[str, Any]] = None,
    ) -> Optional[CadastralParcel]:
        prov, norm_state = self._resolve_provider(state)
        if norm_state == "BIHAR":
            return await prov.get_parcel_by_coordinate(
                lat=lat,
                lng=lng,
                village_id=village_id,
                district_name=district_name,
                block_name=block_name,
                gp_name=gp_name,
                village_name=village_name,
                sheet_no=sheet_no,
                raw_geojson=raw_geojson,
            )
        else:
            return await prov.get_parcel_by_coordinate(
                lat=lat,
                lng=lng,
                village_id=village_id,
                district_name=district_name,
                block_name=block_name,
                gp_name=gp_name,
                village_name=village_name,
            )


# Global Singleton
gis_router = GISRouter()
