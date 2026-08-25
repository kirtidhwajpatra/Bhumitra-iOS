"""
Remote Configuration Pydantic Models
Defines schema for feature flags, version compatibility, maintenance toggles,
dynamic paywalls, and admin update requests.
"""

from typing import List, Optional
from datetime import datetime, timezone
from pydantic import BaseModel, Field


class FeaturesConfig(BaseModel):
    advanced_search: bool = True
    property_history: bool = False
    valuation: bool = False
    pdf_download: bool = True
    satellite_view: bool = True


class PaywallConfig(BaseModel):
    headline: str = "Upgrade to Bhumitra Premium"
    subheadline: str = (
        "Unlock complete GIS tools, legal ROR ownership records, and official PDF downloads"
    )
    default_tier: str = "bhumitra_premium_yearly"
    available_tiers: List[str] = [
        "bhumitra_premium_monthly",
        "bhumitra_premium_yearly",
        "bhumitra_premium_lifetime",
    ]


class AppConfigResponse(BaseModel):
    config_version: int = 1
    server_time: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    ttl_seconds: int = 3600  # Client cache TTL in seconds (1 hour)
    min_supported_version: str = "1.0.0"
    recommended_version: str = "1.0.0"
    latest_version: str = "1.0.0"
    force_update: bool = False
    maintenance_mode: bool = False
    maintenance_message: Optional[str] = None
    app_store_id: str = "6742337788"
    app_store_url: str = "https://apps.apple.com/app/bhumitra-odisha-land-records/id6742337788"
    ror_enabled: bool = True
    gis_enabled: bool = True
    subscription_enabled: bool = True
    premium_enabled: bool = True
    map_data_version: str = "2026-08-18"
    features: FeaturesConfig = Field(default_factory=FeaturesConfig)
    paywall: PaywallConfig = Field(default_factory=PaywallConfig)


class AppConfigUpdateRequest(BaseModel):
    min_supported_version: Optional[str] = None
    recommended_version: Optional[str] = None
    latest_version: Optional[str] = None
    force_update: Optional[bool] = None
    app_store_id: Optional[str] = None
    app_store_url: Optional[str] = None
    maintenance_mode: Optional[bool] = None
    maintenance_message: Optional[str] = None
    ror_enabled: Optional[bool] = None
    gis_enabled: Optional[bool] = None
    subscription_enabled: Optional[bool] = None
    premium_enabled: Optional[bool] = None
    map_data_version: Optional[str] = None
    features: Optional[FeaturesConfig] = None
    paywall: Optional[PaywallConfig] = None
    ttl_seconds: Optional[int] = None
