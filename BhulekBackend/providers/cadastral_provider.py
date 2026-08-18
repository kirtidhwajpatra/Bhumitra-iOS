"""
Abstract Cadastral Provider Interface
Defines standard contract for fetching official administrative hierarchies,
village extents, parcel geometries, and spatial lookups.
"""

from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any
from models.cadastral import (
    CadastralDistrict,
    CadastralBlock,
    CadastralGP,
    CadastralVillage,
    CadastralExtent,
    CadastralParcel,
    CadastralFeatureCollection,
)


class CadastralProvider(ABC):
    """
    Abstract Cadastral GIS Provider interface.
    """

    @abstractmethod
    async def get_districts(self) -> List[CadastralDistrict]:
        """Fetch all official districts in the state."""
        pass

    @abstractmethod
    async def get_blocks(self, district_id: str, district_name: Optional[str] = None) -> List[CadastralBlock]:
        """Fetch all blocks/tahasils for a given district."""
        pass

    @abstractmethod
    async def get_gram_panchayats(
        self, block_id: str, block_name: Optional[str] = None, district_name: Optional[str] = None
    ) -> List[CadastralGP]:
        """Fetch all Gram Panchayats for a given block/tahasil."""
        pass

    @abstractmethod
    async def get_villages(
        self,
        gp_id: Optional[str],
        block_id: str,
        block_name: Optional[str] = None,
        district_name: Optional[str] = None,
    ) -> List[CadastralVillage]:
        """Fetch all revenue villages for a given GP / Block."""
        pass

    @abstractmethod
    async def get_village_extent(self, village_id: str, gp_id: Optional[str] = None) -> Optional[CadastralExtent]:
        """Fetch the bounding extent and center coordinate for a revenue village."""
        pass

    @abstractmethod
    async def get_village_parcels(
        self,
        village_id: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        gp_name: Optional[str] = None,
        village_name: Optional[str] = None,
    ) -> CadastralFeatureCollection:
        """Fetch full normalized cadastral parcel FeatureCollection for a revenue village."""
        pass

    @abstractmethod
    async def get_parcel_by_plot(
        self,
        village_id: str,
        exact_plot_number: str,
        district_name: Optional[str] = None,
        block_name: Optional[str] = None,
        gp_name: Optional[str] = None,
        village_name: Optional[str] = None,
    ) -> Optional[CadastralParcel]:
        """Retrieve a specific single parcel by exact verbatim plot number."""
        pass

    @abstractmethod
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
        """Resolve a parcel from spatial (lat, lng) within a revenue village via ray-casting."""
        pass
