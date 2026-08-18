"""
App Store Subscription & Webhook Router
Handles StoreKit 2 transaction verification, live server status,
and App Store Server Notifications V2 (ASSN V2) webhooks.
"""

from fastapi import APIRouter, HTTPException, status
from models.subscription_models import (
    AppStoreNotificationRequest,
    SubscriptionVerifyRequest,
    SubscriptionStatusResponse,
)
from services.subscription_service import subscription_service
from services.apple_verification_service import AppleVerificationError

router = APIRouter()


@router.post(
    "/subscription/verify",
    response_model=SubscriptionStatusResponse,
    summary="Verify & Link StoreKit 2 Transaction",
    description="Called by iOS app after StoreKit 2 purchase to cryptographically verify and link the Apple transaction with the user's account.",
)
async def verify_transaction(request: SubscriptionVerifyRequest):
    if not request.user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="user_id is required"
        )
    if not request.signed_transaction_jws:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="signed_transaction_jws is required",
        )

    try:
        response = subscription_service.verify_and_link_transaction(request)
        return response
    except AppleVerificationError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.message,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Verification failed: {str(e)}",
        )


@router.get(
    "/subscription/status/{user_id}",
    response_model=SubscriptionStatusResponse,
    summary="Get Server-Authoritative Subscription Status",
    description="Returns the live subscription entitlement, auto-renewal status, expiration date, and billing retry status.",
)
async def get_subscription_status(user_id: str):
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="user_id is required"
        )

    response = subscription_service.get_user_status(user_id)
    return response


@router.post(
    "/webhook/app-store",
    summary="Apple App Store Server Notifications V2 Webhook",
    description="Webhook endpoint that receives real-time subscription lifecycle notifications from Apple (renewals, cancellations, refunds, billing retries).",
)
async def app_store_webhook(payload: AppStoreNotificationRequest):
    if not payload.signedPayload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="signedPayload is required",
        )

    try:
        result = subscription_service.process_app_store_notification(
            payload.signedPayload
        )
        return result
    except AppleVerificationError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.message,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Notification verification failed: {str(e)}",
        )
