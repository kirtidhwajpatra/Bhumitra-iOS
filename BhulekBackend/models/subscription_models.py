from typing import Optional, Any, Dict
from pydantic import BaseModel, Field


class AppStoreNotificationRequest(BaseModel):
    """Payload received from Apple App Store Server Notifications V2."""
    signedPayload: str = Field(..., description="JWS signed payload containing the notification details.")


class SubscriptionVerifyRequest(BaseModel):
    """Request from iOS client to register and link a verified StoreKit 2 transaction."""
    user_id: str = Field(..., description="Stable User Identifier (e.g. Apple User ID)")
    signed_transaction_jws: str = Field(..., description="JWS signed transaction from StoreKit 2")
    original_transaction_id: Optional[str] = Field(None, description="Original transaction ID")
    app_account_token: Optional[str] = Field(None, description="Permanent UUID appAccountToken associated with the purchase")


class SubscriptionStatusResponse(BaseModel):
    """Server-authoritative subscription status response."""
    user_id: str
    is_premium: bool
    status: str  # "active", "expired", "revoked", "in_billing_retry", "none"
    plan: Optional[str] = "monthly"
    product_id: Optional[str] = "bhumitra_premium_monthly"
    original_transaction_id: Optional[str] = None
    app_account_token: Optional[str] = None
    purchase_date: Optional[str] = None
    expires_date: Optional[str] = None
    auto_renew_status: bool = False
    is_in_billing_retry: bool = False
    cancellation_date: Optional[str] = None
    revocation_reason: Optional[int] = None
    message: Optional[str] = None

