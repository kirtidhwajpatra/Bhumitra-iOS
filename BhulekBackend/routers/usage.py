"""
Usage & Quota Status API Router
Provides authenticated users with live insights into their monthly usage quotas,
remaining lookups, and subscription tier allowances.
"""

from fastapi import APIRouter, Depends
from models.db_models import UserDB
from core.security import get_current_user
from services.usage_service import usage_service

router = APIRouter()


@router.get(
    "/usage/status",
    summary="Get User Monthly Usage and Entitlement Quota",
    description="Returns the authenticated user's current billing period usage counts, limits, and remaining RoR lookups/PDF downloads.",
)
async def get_my_usage_status(
    current_user: UserDB = Depends(get_current_user),
):
    summary = usage_service.get_user_usage_summary(current_user.id)
    return summary
