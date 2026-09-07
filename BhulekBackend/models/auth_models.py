"""
Authentication Pydantic Request & Response Models
"""

from typing import Optional
from pydantic import BaseModel, Field


class AppleAuthRequest(BaseModel):
    identity_token: str = Field(..., description="Raw Apple identity token (JWT) returned by ASAuthorizationAppleIDCredential")
    app_account_token: Optional[str] = Field(None, description="Client-generated permanent UUID for StoreKit 2 appAccountToken binding")
    full_name: Optional[str] = Field(None, description="User's full name (provided on first Sign in with Apple)")
    email: Optional[str] = Field(None, description="User's email address (provided on first Sign in with Apple)")
    nonce: Optional[str] = Field(None, description="Cryptographic nonce if generated during sign-in")
    device_id: Optional[str] = Field(None, description="Client device identifier for anti-abuse validation")


class GoogleAuthRequest(BaseModel):
    id_token: str = Field(..., description="Google ID Token (JWT) returned by Google OAuth / OpenID Connect")
    app_account_token: Optional[str] = Field(None, description="Client-generated permanent UUID for StoreKit 2 appAccountToken binding")
    full_name: Optional[str] = Field(None, description="User's full name from Google Profile")
    email: Optional[str] = Field(None, description="User's email address from Google Profile")
    device_id: Optional[str] = Field(None, description="Client device identifier for anti-abuse validation")


class DeviceAuthRequest(BaseModel):
    device_id: str = Field(..., description="Unique client device identifier (UUID)")
    app_account_token: Optional[str] = Field(None, description="Optional UUID for StoreKit 2 appAccountToken binding")


class AuthIdentityResponse(BaseModel):
    provider: str = Field(..., description="Provider name: apple, google, or device")
    provider_subject: str = Field(..., description="Provider subject identifier")
    provider_email: Optional[str] = Field(None, description="Email associated with provider")
    created_at: Optional[str] = None


class UserProfileResponse(BaseModel):
    id: str
    email: Optional[str] = None
    name: Optional[str] = None
    app_account_token: Optional[str] = None
    plot_credits: int = 0
    free_credits: int = 0
    created_at: Optional[str] = None
    linked_providers: list[str] = Field(default_factory=list)


class AuthResponse(BaseModel):
    access_token: str = Field(..., description="Bhumitra signed JWT session token")
    token_type: str = Field("bearer", description="Token type")
    expires_in: int = Field(..., description="Seconds until expiration (e.g. 30 days)")
    user: UserProfileResponse
    message: str = "Authentication verified successfully."


class AccountLinkingResponse(BaseModel):
    success: bool
    user: UserProfileResponse
    linked_provider: str
    message: str

