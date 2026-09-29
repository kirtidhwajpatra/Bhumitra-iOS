"""
Sign in with Apple token revocation on account deletion (App Store Review
Guideline 5.1.1(v): apps using Sign in with Apple must revoke the user's tokens
when the account is deleted).

Flow: the app gets a fresh authorization code from Sign in with Apple right
before deletion and sends it with DELETE /auth/me. The backend exchanges it at
appleid.apple.com/auth/token and revokes the resulting refresh token.

Requires a Sign in with Apple key from the Apple Developer portal:
  APPLE_TEAM_ID              10-character Team ID
  APPLE_SIGNIN_KEY_ID        Key ID of the .p8 key (Sign in with Apple enabled)
  APPLE_SIGNIN_PRIVATE_KEY   Contents of the .p8 file (PEM; "\\n" escapes allowed)
  APPLE_CLIENT_ID            optional, defaults to the app bundle id
Without these, revocation is skipped (logged) and deletion still completes.
"""
import logging
import os
import time
from typing import Optional

import httpx
import jwt

logger = logging.getLogger(__name__)

APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token"
APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke"


class AppleRevocationService:
    def __init__(self, transport: Optional[httpx.BaseTransport] = None):
        self._transport = transport

    @staticmethod
    def _config():
        team = os.environ.get("APPLE_TEAM_ID", "").strip()
        key_id = os.environ.get("APPLE_SIGNIN_KEY_ID", "").strip()
        key = os.environ.get("APPLE_SIGNIN_PRIVATE_KEY", "").strip().replace("\\n", "\n")
        client_id = (os.environ.get("APPLE_CLIENT_ID") or os.environ.get("APPLE_BUNDLE_ID")
                     or "com.kirtidhwaj.Bhumitra").strip()
        return team, key_id, key, client_id

    def is_configured(self) -> bool:
        team, key_id, key, _ = self._config()
        return bool(team and key_id and key)

    def _client_secret(self) -> str:
        team, key_id, key, client_id = self._config()
        now = int(time.time())
        return jwt.encode(
            {"iss": team, "iat": now, "exp": now + 300, "aud": "https://appleid.apple.com", "sub": client_id},
            key, algorithm="ES256", headers={"kid": key_id},
        )

    def revoke_with_authorization_code(self, authorization_code: Optional[str]) -> str:
        """Returns 'revoked', 'skipped_not_configured', 'skipped_no_code' or 'failed'.
        Never raises: account deletion must not be blocked by Apple's endpoint."""
        if not authorization_code or not authorization_code.strip():
            return "skipped_no_code"
        if not self.is_configured():
            logger.warning("APPLE_REVOKE_SKIPPED: Sign in with Apple key not configured")
            return "skipped_not_configured"
        _, _, _, client_id = self._config()
        try:
            secret = self._client_secret()
            with httpx.Client(timeout=10, transport=self._transport) as client:
                tok = client.post(APPLE_TOKEN_URL, data={
                    "client_id": client_id, "client_secret": secret,
                    "code": authorization_code.strip(), "grant_type": "authorization_code",
                })
                if tok.status_code != 200:
                    logger.warning("APPLE_REVOKE_TOKEN_EXCHANGE_FAILED status=%s", tok.status_code)
                    return "failed"
                body = tok.json()
                token = body.get("refresh_token") or body.get("access_token")
                hint = "refresh_token" if body.get("refresh_token") else "access_token"
                if not token:
                    return "failed"
                rev = client.post(APPLE_REVOKE_URL, data={
                    "client_id": client_id, "client_secret": secret,
                    "token": token, "token_type_hint": hint,
                })
                if rev.status_code == 200:
                    return "revoked"
                logger.warning("APPLE_REVOKE_FAILED status=%s", rev.status_code)
                return "failed"
        except Exception as e:  # network, bad key, etc.
            logger.warning("APPLE_REVOKE_ERROR err=%s", type(e).__name__)
            return "failed"


apple_revocation_service = AppleRevocationService()
