"""
Short-lived signed tokens for the UP exact-plot selection tile route.

The official PLOT_SELECTION WMS style needs an upstream plot_id. Rather than
expose a proxy that accepts any caller-chosen plot_id, the backend mints a
token only after it has itself resolved a plot (identify / plot-by-number).
The token binds gis_code + plot_id + expiry with HMAC-SHA256.

Format: v1.{exp}.{gis_code}.{plot_id}.{sig}
  exp      unix seconds
  gis_code digits
  plot_id  [0-9A-Za-z_-]
  sig      base64url(HMAC-SHA256(key, "v1.{exp}.{gis_code}.{plot_id}")) without padding

The key is UP_SELECTION_TOKEN_SECRET when set, otherwise derived from
JWT_SECRET_KEY with a domain-separation prefix, so the two never share a key.
"""
import base64
import hashlib
import hmac
import os
import re
import time
from dataclasses import dataclass
from typing import Optional

TOKEN_VERSION = "v1"
DEFAULT_TTL_SECONDS = 2 * 60 * 60
# Tokens are only ever minted by this server; reject anything claiming to be
# valid far beyond the TTL (clock or key misuse).
_MAX_FUTURE_SECONDS = DEFAULT_TTL_SECONDS + 300

_GIS_RE = re.compile(r"^[0-9]{6,20}$")
_PLOT_ID_RE = re.compile(r"^[0-9A-Za-z_\-]{1,128}$")
_EXP_RE = re.compile(r"^[0-9]{9,11}$")
_SIG_RE = re.compile(r"^[A-Za-z0-9_\-]{43}$")
MAX_TOKEN_LENGTH = 220


class SelectionTokenError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass(frozen=True)
class SelectionClaim:
    gis_code: str
    plot_id: str
    expires_at: int


def _key() -> bytes:
    explicit = os.environ.get("UP_SELECTION_TOKEN_SECRET", "").strip()
    if explicit:
        return explicit.encode("utf-8")
    from core.config import settings
    return hashlib.sha256(b"up-selection:" + settings.JWT_SECRET_KEY.encode("utf-8")).digest()


def _sign(payload: str) -> str:
    digest = hmac.new(_key(), payload.encode("ascii"), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")


def mint_selection_token(gis_code: str, plot_id: Optional[str], *,
                         ttl_seconds: int = DEFAULT_TTL_SECONDS,
                         now: Optional[float] = None) -> Optional[str]:
    """Returns None when the plot has no usable upstream id."""
    if not plot_id or not _GIS_RE.fullmatch(gis_code or "") or not _PLOT_ID_RE.fullmatch(plot_id):
        return None
    exp = int((time.time() if now is None else now) + ttl_seconds)
    payload = f"{TOKEN_VERSION}.{exp}.{gis_code}.{plot_id}"
    return f"{payload}.{_sign(payload)}"


def verify_selection_token(token: str, *, now: Optional[float] = None) -> SelectionClaim:
    if not token or len(token) > MAX_TOKEN_LENGTH:
        raise SelectionTokenError("UP_SELECTION_TOKEN_INVALID", "Selection link is invalid.")
    parts = token.split(".")
    if len(parts) != 5 or parts[0] != TOKEN_VERSION:
        raise SelectionTokenError("UP_SELECTION_TOKEN_INVALID", "Selection link is invalid.")
    _, exp_s, gis_code, plot_id, sig = parts
    if not (_EXP_RE.fullmatch(exp_s) and _GIS_RE.fullmatch(gis_code)
            and _PLOT_ID_RE.fullmatch(plot_id) and _SIG_RE.fullmatch(sig)):
        raise SelectionTokenError("UP_SELECTION_TOKEN_INVALID", "Selection link is invalid.")
    expected = _sign(f"{TOKEN_VERSION}.{exp_s}.{gis_code}.{plot_id}")
    if not hmac.compare_digest(expected, sig):
        raise SelectionTokenError("UP_SELECTION_TOKEN_INVALID", "Selection link is invalid.")
    exp = int(exp_s)
    current = time.time() if now is None else now
    if exp <= current:
        raise SelectionTokenError("UP_SELECTION_TOKEN_EXPIRED", "Selection expired. Tap the plot again.")
    if exp > current + _MAX_FUTURE_SECONDS:
        raise SelectionTokenError("UP_SELECTION_TOKEN_INVALID", "Selection link is invalid.")
    return SelectionClaim(gis_code=gis_code, plot_id=plot_id, expires_at=exp)
