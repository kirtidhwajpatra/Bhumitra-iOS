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
from sqlalchemy.orm import Session
from db.session import get_db
from models.db_models import UserDB
from pydantic import BaseModel, Field
from core.security import get_current_user, get_optional_current_user, decode_access_token
from services.subscription_service import subscription_service
from services.apple_verification_service import AppleVerificationError
from services.wallet_service import WalletMergeError, merge_guest_into, wallet_app_account_tokens

router = APIRouter()


class WalletMergeRequest(BaseModel):
    guest_token: str = Field(..., min_length=10, max_length=4096,
                             description="The device's guest session token, proving it owns the guest wallet")


@router.post(
    "/wallet/merge-guest",
    summary="Move a guest wallet into the signed-in account",
    description="Called by the app after sign-in (and on launch) with the device's guest session token. "
                "Moves purchased credits, credit-pack purchases and Unlimited+ to the account. Idempotent.",
)
def merge_guest_wallet(
    body: WalletMergeRequest,
    current_user: UserDB = Depends(get_current_user),
):
    try:
        payload = decode_access_token(body.guest_token)
    except HTTPException:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Guest session is invalid or expired.")
    guest_id = str(payload.get("sub") or "")
    if guest_id == current_user.id:
        return {"merged": False, "credits_moved": 0, "purchases_moved": 0, "subscriptions_moved": 0,
                "current_balance": (current_user.free_credits or 0) + (current_user.plot_credits or 0)}
    try:
        return merge_guest_into(guest_id, current_user.id)
    except WalletMergeError as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)


@router.post(
    "/subscription/credits/purchase",
    response_model=ConsumablePurchaseResponse,
    summary="Process & Credit Apple Consumable Purchase",
    description="Called by iOS app after StoreKit 2 consumable purchase. Cryptographically verifies Apple transaction and credits user balance authoritatively with strict idempotency.",
)
def purchase_credits(
    request: ConsumablePurchaseRequest,
    current_user: UserDB = Depends(get_current_user),
):
    if not request.signed_transaction_jws or not request.signed_transaction_jws.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="signed_transaction_jws is required",
        )

    try:
        user_id = current_user.id

        # Consumable transactions signed by Apple for this bundle ID are credited
        # strictly to the authenticated session user (current_user.id). Anonymous purchases are rejected.
        response = subscription_service.process_consumable_purchase(
            user_id=user_id,
            signed_transaction_jws=request.signed_transaction_jws,
            expected_app_account_token=None,
        )
        return response
    except AppleVerificationError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.message,
        )
    except HTTPException:
        raise
    except Exception as e:
        # Unexpected server-side error (DB failure, unhandled exception).
        # Return 500 so iOS auto-retry and Apple ASSN can retry appropriately.
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal server error occurred while processing your purchase. Please try again.",
        )


@router.get(
    "/subscription/credits",
    response_model=UserCreditsResponse,
    summary="Get Authenticated User's Plot Search Credit Balance",
    description="Returns the server-authoritative plot search credit balance for the currently authenticated user.",
)
def get_user_credits(
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return subscription_service.get_user_credits(current_user.id, db=db)



@router.post(
    "/subscription/verify",
    response_model=SubscriptionStatusResponse,
    summary="Verify & Link StoreKit 2 Transaction (Authenticated)",
    description="Called by iOS app after StoreKit 2 purchase. Binds verified Apple transaction strictly to the authenticated user derived from Bearer token.",
)
def verify_transaction(
    request: SubscriptionVerifyRequest,
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not request.signed_transaction_jws:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="signed_transaction_jws is required",
        )

    # Derive user_id strictly from verified session token (Never trust client user_id)
    request.user_id = current_user.id

    # Check appAccountToken consistency. Tokens of guest wallets merged into this
    # account count as the account's own (subscription bought before sign-in).
    if current_user.app_account_token:
        wallet_tokens = wallet_app_account_tokens(db, current_user.id)
        requested = (request.app_account_token or "").strip().lower()
        if requested and requested not in wallet_tokens:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Transaction appAccountToken does not match authenticated user account.",
            )
        if not requested:
            request.app_account_token = current_user.app_account_token

    try:
        response = subscription_service.verify_and_link_transaction(request)
        return response
    except AppleVerificationError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.message,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal server error occurred while verifying your subscription. Please try again.",
        )


@router.get(
    "/subscription/status",
    response_model=SubscriptionStatusResponse,
    summary="Get Authenticated User's Subscription Status",
    description="Returns the live subscription entitlement, auto-renewal status, and expiration for the currently authenticated user.",
)
def get_my_subscription_status(
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
def get_subscription_status_by_id(
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
def app_store_webhook(payload: AppStoreNotificationRequest):
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
    except HTTPException:
        raise
    except Exception as e:
        # Apple ASSN retries on 4xx/5xx — return 500 so Apple will retry transient failures.
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal server error occurred while processing the App Store notification.",
        )
