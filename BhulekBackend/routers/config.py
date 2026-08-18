"""
Remote Application Configuration Router
Provides real-time feature flags, version compatibility, maintenance toggles,
and paywall configuration without requiring App Store binary updates.
"""

from fastapi import APIRouter
from models.config_models import AppConfigResponse, FeaturesConfig, PaywallConfig

router = APIRouter()


@router.get(
    "/app-config",
    response_model=AppConfigResponse,
    summary="Get Remote Application Configuration",
    description="Returns real-time app settings, supported client versions, maintenance status, feature flags, and paywall configurations.",
)
async def get_app_config() -> AppConfigResponse:
    # In production, these values can be read from environment variables or a Redis / Firestore DB
    return AppConfigResponse(
        min_supported_version="1.0.0",
        recommended_version="1.0.0",
        latest_version="1.0.0",
        maintenance_mode=False,
        maintenance_message=None,
        subscription_enabled=True,
        premium_enabled=True,
        map_data_version="2026-08-18",
        features=FeaturesConfig(
            advanced_search=True,
            property_history=False,
            valuation=False,
            pdf_download=True,
            satellite_view=True,
        ),
        paywall=PaywallConfig(
            headline="Upgrade to Bhumitra Premium",
            subheadline="Unlock complete GIS tools, legal ROR ownership records, and official PDF downloads",
            default_tier="bhumitra_premium_yearly",
            available_tiers=[
                "bhumitra_premium_monthly",
                "bhumitra_premium_yearly",
                "bhumitra_premium_lifetime",
            ],
        ),
    )
