"""
Apple Identity Token Verification Service
Validates native Sign in with Apple JWT identity tokens against Apple's official JWKS endpoint.
"""

import os
from typing import Dict, Any, Optional, Set
import jwt
from jwt import PyJWKClient


class AppleAuthError(Exception):
    def __init__(self, message: str, status_code: int = 401, details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.details = details or {}


class AppleAuthService:
    APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
    APPLE_ISSUER = "https://appleid.apple.com"
    
    def __init__(self, bundle_id: Optional[str] = None, jwks_url: Optional[str] = None):
        self.bundle_id = bundle_id or os.environ.get("APPLE_BUNDLE_ID", "com.kirtidhwaj.Bhumitra")
        self.client_id = os.environ.get("APPLE_CLIENT_ID", self.bundle_id)
        
        self.allowed_audiences: Set[str] = {
            self.bundle_id,
            self.client_id,
            "com.kirtidhwaj.Bhumitra",
            "com.kirtidhwaj.MyBhoomi",
        }
        
        self.jwks_url = jwks_url or self.APPLE_JWKS_URL
        self._jwks_client: Optional[PyJWKClient] = None

    @property
    def jwks_client(self) -> PyJWKClient:
        if self._jwks_client is None:
            self._jwks_client = PyJWKClient(self.jwks_url, cache_jwk_set=True, lifespan=86400)
        return self._jwks_client

    def verify_identity_token(
        self,
        identity_token: str,
        signing_key_override: Optional[Any] = None,
        expected_nonce: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Cryptographically verifies an Apple identity token and extracts validated user claims.
        """
        if not identity_token or not identity_token.strip():
            raise AppleAuthError("Missing or empty Apple identity_token", status_code=400)

        token = identity_token.strip()

        try:
            # Get signing key from Apple JWKS endpoint (or test override)
            if signing_key_override:
                signing_key = signing_key_override
            else:
                signing_key = self.jwks_client.get_signing_key_from_jwt(token).key

            # Cryptographically decode & validate token
            payload = jwt.decode(
                token,
                signing_key,
                algorithms=["RS256"],
                audience=list(self.allowed_audiences),
                issuer=self.APPLE_ISSUER,
                options={
                    "require": ["sub", "exp", "iss", "aud"],
                    "verify_signature": True,
                    "verify_exp": True,
                    "verify_iss": True,
                    "verify_aud": True,
                },
            )

            # Validate nonce if provided
            if expected_nonce:
                token_nonce = payload.get("nonce")
                if token_nonce != expected_nonce:
                    raise AppleAuthError("Nonce mismatch in Apple identity token", status_code=401)

            return payload

        except jwt.ExpiredSignatureError:
            raise AppleAuthError("Apple identity token has expired", status_code=401)
        except jwt.InvalidIssuerError:
            raise AppleAuthError("Invalid Apple identity token issuer", status_code=401)
        except jwt.InvalidAudienceError:
            raise AppleAuthError("Invalid Apple identity token audience (bundle ID mismatch)", status_code=401)
        except jwt.InvalidSignatureError:
            raise AppleAuthError("Apple identity token signature verification failed", status_code=401)
        except AppleAuthError:
            raise
        except Exception as e:
            raise AppleAuthError(f"Apple identity token validation failed: {str(e)}", status_code=401)


# Shared singleton instance
apple_auth_service = AppleAuthService()
