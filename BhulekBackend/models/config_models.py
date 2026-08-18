from typing import Dict, List, Optional
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
    min_supported_version: str = "1.0.0"
    recommended_version: str = "1.0.0"
    latest_version: str = "1.0.0"
    maintenance_mode: bool = False
    maintenance_message: Optional[str] = None
    subscription_enabled: bool = True
    premium_enabled: bool = True
    map_data_version: str = "2026-08-18"
    features: FeaturesConfig = Field(default_factory=FeaturesConfig)
    paywall: PaywallConfig = Field(default_factory=PaywallConfig)
