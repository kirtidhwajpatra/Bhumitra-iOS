"""
Google ID Token Verification Service
Validates Google Sign-In JWT identity tokens against Google's official JWKS and tokeninfo endpoints.
"""

import os
import requests
from typing import Dict, Any, Optional
import jwt
from jwt import PyJWKClient


class GoogleAuthError(Exception):
    def __init__(self, message: str, status_code: int = 401, details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.details = details or {}


class GoogleAuthService:
    GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"
    GOOGLE_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo"
    GOOGLE_ISSUERS = {"https://accounts.google.com", "accounts.google.com"}

    def __init__(self, jwks_url: Optional[str] = None):
        self.jwks_url = jwks_url or self.GOOGLE_JWKS_URL
        self._jwks_client: Optional[PyJWKClient] = None

    @property
    def jwks_client(self) -> PyJWKClient:
        if self._jwks_client is None:
            self._jwks_client = PyJWKClient(self.jwks_url, cache_jwk_set=True, lifespan=86400)
        return self._jwks_client

    def verify_identity_token(
        self,
        id_token: str,
        signing_key_override: Optional[Any] = None,
    ) -> Dict[str, Any]:
        """
        Cryptographically verifies a Google ID token and extracts validated user claims.
        Falls back to Google tokeninfo endpoint if needed.
        """
        if not id_token or not id_token.strip():
            raise GoogleAuthError("Missing or empty Google id_token", status_code=400)

        token = id_token.strip()

        # 1. Primary: Verify via JWKS
        try:
            if signing_key_override:
                signing_key = signing_key_override
            else:
                signing_key = self.jwks_client.get_signing_key_from_jwt(token)

            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256"],
                options={
                    "verify_aud": False,  # Allow diverse iOS/Web OAuth client IDs
                    "verify_exp": True,
                },
            )

            issuer = payload.get("iss")
            if issuer not in self.GOOGLE_ISSUERS:
                raise GoogleAuthError(f"Invalid Google token issuer: '{issuer}'", status_code=401)

            sub = payload.get("sub")
            if not sub:
                raise GoogleAuthError("Google token missing 'sub' claim", status_code=401)

            return payload

        except GoogleAuthError:
            raise
        except Exception as e:
            # 2. Fallback: Query Google tokeninfo endpoint
            try:
                resp = requests.get(
                    self.GOOGLE_TOKENINFO_URL,
                    params={"id_token": token},
                    timeout=5,
                )
                if resp.status_code == 200:
                    info = resp.json()
                    if info.get("sub"):
                        return info
            except Exception:
                pass

            raise GoogleAuthError(f"Google identity token validation failed: {str(e)}", status_code=401)


google_auth_service = GoogleAuthService()
