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


class GoogleAuthRequest(BaseModel):
    id_token: str = Field(..., description="Google ID Token (JWT) returned by Google OAuth / OpenID Connect")
    app_account_token: Optional[str] = Field(None, description="Client-generated permanent UUID for StoreKit 2 appAccountToken binding")
    full_name: Optional[str] = Field(None, description="User's full name from Google Profile")
    email: Optional[str] = Field(None, description="User's email address from Google Profile")


class UserProfileResponse(BaseModel):
    id: str
    app_account_token: Optional[str] = None
    created_at: Optional[str] = None


class AuthResponse(BaseModel):
    access_token: str = Field(..., description="Bhumitra signed JWT session token")
    token_type: str = Field("bearer", description="Token type")
    expires_in: int = Field(..., description="Seconds until expiration (e.g. 30 days)")
    user: UserProfileResponse
    message: str = "Authentication verified successfully."
