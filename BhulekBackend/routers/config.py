"""
Remote Application Configuration Router
Provides real-time feature flags, version compatibility, maintenance toggles,
and dynamic paywall configurations without requiring App Store binary updates.
Includes secure admin mutation endpoint protected by X-Admin-Key header.
"""

import os
from typing import Optional
from fastapi import APIRouter, Header, HTTPException, Request, status

from models.config_models import AppConfigResponse, AppConfigUpdateRequest
from services.config_service import config_service
from core.rate_limiter import enforce_rate_limit

router = APIRouter()

ADMIN_API_KEY = os.environ.get("ADMIN_API_KEY", "bhumitra_admin_secret_key_2026")


@router.get(
    "/app-config",
    response_model=AppConfigResponse,
    summary="Get Remote Application Configuration (Public)",
    description="Returns real-time app settings, supported client versions, maintenance status, feature flags, and paywall configurations.",
)
async def get_app_config(request: Request) -> AppConfigResponse:
    enforce_rate_limit(request, max_requests=60, tag="config")
    return config_service.get_active_config()


@router.put(
    "/app-config",
    response_model=AppConfigResponse,
    summary="Update Remote Application Configuration (Admin Protected)",
    description="Allows administrators to dynamically update feature flags, minimum supported versions, and maintenance mode.",
)
async def update_app_config(
    update_request: AppConfigUpdateRequest,
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
) -> AppConfigResponse:
    if not x_admin_key or x_admin_key != ADMIN_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Invalid or missing X-Admin-Key header.",
        )

    updated_config = config_service.update_config(update_request)
    return updated_config
