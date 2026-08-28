"""
App Store Subscription & Webhook Router
Handles StoreKit 2 transaction verification, live server status,
and App Store Server Notifications V2 (ASSN V2) webhooks.
Enforces Bearer authentication to prevent user spoofing and cross-account access.
"""

from typing import Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from models.subscription_models import (
    AppStoreNotificationRequest,
    SubscriptionVerifyRequest,
    SubscriptionStatusResponse,
    ConsumablePurchaseRequest,
    ConsumablePurchaseResponse,
    UserCreditsResponse,
)
from models.db_models import UserDB
from core.security import get_current_user, get_optional_current_user
from services.subscription_service import subscription_service
from services.apple_verification_service import AppleVerificationError

router = APIRouter()


@router.post(
    "/subscription/credits/purchase",
    response_model=ConsumablePurchaseResponse,
    summary="Process & Credit Apple Consumable Purchase",
    description="Called by iOS app after StoreKit 2 consumable purchase. Cryptographically verifies Apple transaction and credits user balance authoritatively with strict idempotency.",
)
async def purchase_credits(
    request: ConsumablePurchaseRequest,
    current_user: Optional[UserDB] = Depends(get_optional_current_user),
):
    if not request.signed_transaction_jws or not request.signed_transaction_jws.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="signed_transaction_jws is required",
        )

    try:
        user_id = current_user.id if current_user else "anonymous_device"
        expected_token = current_user.app_account_token if current_user else None

        response = subscription_service.process_consumable_purchase(
            user_id=user_id,
            signed_transaction_jws=request.signed_transaction_jws,
            expected_app_account_token=expected_token,
        )
        return response
    except AppleVerificationError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.message,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Consumable purchase verification failed: {str(e)}",
        )


@router.get(
    "/subscription/credits",
    response_model=UserCreditsResponse,
    summary="Get Authenticated User's Plot Search Credit Balance",
    description="Returns the server-authoritative plot search credit balance for the currently authenticated user.",
)
async def get_user_credits(
    current_user: UserDB = Depends(get_current_user),
):
    return subscription_service.get_user_credits(current_user.id)



@router.post(
    "/subscription/verify",
    response_model=SubscriptionStatusResponse,
    summary="Verify & Link StoreKit 2 Transaction (Authenticated)",
    description="Called by iOS app after StoreKit 2 purchase. Binds verified Apple transaction strictly to the authenticated user derived from Bearer token.",
)
async def verify_transaction(
    request: SubscriptionVerifyRequest,
    current_user: UserDB = Depends(get_current_user),
):
    if not request.signed_transaction_jws:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="signed_transaction_jws is required",
        )

    # Derive user_id strictly from verified session token (Never trust client user_id)
    request.user_id = current_user.id

    # Check appAccountToken consistency
    if current_user.app_account_token:
        if request.app_account_token and request.app_account_token.lower() != current_user.app_account_token.lower():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Transaction appAccountToken does not match authenticated user account.",
            )
        request.app_account_token = current_user.app_account_token

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
    "/subscription/status",
    response_model=SubscriptionStatusResponse,
    summary="Get Authenticated User's Subscription Status",
    description="Returns the live subscription entitlement, auto-renewal status, and expiration for the currently authenticated user.",
)
async def get_my_subscription_status(
    current_user: UserDB = Depends(get_current_user),
):
    response = subscription_service.get_user_status(current_user.id)
    return response


@router.get(
    "/subscription/status/{user_id}",
    response_model=SubscriptionStatusResponse,
    summary="Get User Subscription Status (Authenticated with Isolation)",
    description="Legacy endpoint protected against IDOR/cross-user snooping. Users can only query their own subscription status.",
)
async def get_subscription_status_by_id(
    user_id: str,
    current_user: UserDB = Depends(get_current_user),
):
    if current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: You cannot access or query another user's subscription status.",
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
