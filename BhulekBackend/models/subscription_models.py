from typing import Optional, Any, Dict
from pydantic import BaseModel, Field


class AppStoreNotificationRequest(BaseModel):
    """Payload received from Apple App Store Server Notifications V2."""
    signedPayload: str = Field(..., description="JWS signed payload containing the notification details.")


class SubscriptionVerifyRequest(BaseModel):
    """Request from iOS client to register and link a verified StoreKit 2 transaction."""
    user_id: Optional[str] = Field(None, description="Optional legacy user identifier; derived from authenticated session")
    signed_transaction_jws: str = Field(..., description="JWS signed transaction from StoreKit 2")
    original_transaction_id: Optional[str] = Field(None, description="Original transaction ID")
    app_account_token: Optional[str] = Field(None, description="Permanent UUID appAccountToken associated with the purchase")


class SubscriptionStatusResponse(BaseModel):
    """Server-authoritative subscription status response."""
    user_id: str
    is_premium: bool
    status: str  # "active", "expired", "revoked", "in_billing_retry", "none"
    plan: Optional[str] = "monthly"
    product_id: Optional[str] = "bhumitra.unlimited.monthly"
    original_transaction_id: Optional[str] = None
    app_account_token: Optional[str] = None
    purchase_date: Optional[str] = None
    expires_date: Optional[str] = None
    auto_renew_status: bool = False
    is_in_billing_retry: bool = False
    cancellation_date: Optional[str] = None
    revocation_reason: Optional[int] = None
    message: Optional[str] = None


class ConsumablePurchaseRequest(BaseModel):
    """Request from iOS client to register and credit a verified StoreKit 2 consumable transaction."""
    signed_transaction_jws: str = Field(..., description="JWS signed transaction from StoreKit 2 for a consumable purchase")


class ConsumablePurchaseResponse(BaseModel):
    """Server-authoritative consumable purchase verification and credit granting response."""
    user_id: str
    product_id: str
    credits_granted: int
    current_balance: int
    transaction_id: str
    original_transaction_id: Optional[str] = None
    already_processed: bool = False
    purchase_date: Optional[str] = None
    message: Optional[str] = None


class UserCreditsResponse(BaseModel):
    """Server-authoritative plot credit balance response."""
    user_id: str
    credits: int


