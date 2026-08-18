"""
Authentication and Cryptographic Security Core
Manages JWT session tokens, secret keys from environment variables,
and FastAPI dependency injection for authenticated user identification.
"""

import os
import secrets
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from db.session import get_db
from models.db_models import UserDB

# Load secrets from environment variables (Never hardcoded)
JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY")
if not JWT_SECRET_KEY:
    # Generate persistent random key for local process lifecycle if not provided
    JWT_SECRET_KEY = os.environ.get("SESSION_SECRET", "bhumitra_prod_secret_key_" + secrets.token_hex(32))

JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = int(os.environ.get("ACCESS_TOKEN_EXPIRE_DAYS", "30"))

# HTTP Bearer authentication scheme
security_scheme = HTTPBearer(auto_error=True)
optional_security_scheme = HTTPBearer(auto_error=False)


def create_access_token(
    user_id: str,
    app_account_token: Optional[str] = None,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Creates a signed JWT access token for an authenticated Bhumitra user.
    """
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)

    payload: Dict[str, Any] = {
        "sub": user_id,
        "app_account_token": app_account_token,
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "iss": "https://api.bhumitra.in",
    }

    encoded_jwt = jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> Dict[str, Any]:
    """
    Decodes and cryptographically validates a Bhumitra JWT access token.
    """
    try:
        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=[JWT_ALGORITHM],
            issuer="https://api.bhumitra.in",
            options={"require": ["sub", "exp", "iat"]},
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has expired. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: Session = Depends(get_db),
) -> UserDB:
    """
    FastAPI dependency that enforces authentication and returns the verified UserDB entity.
    """
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization Bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(credentials.credentials)
    user_id: str = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Malformed token: missing subject claim",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.query(UserDB).filter(UserDB.id == user_id).first()
    if not user:
        # Create user record if token is valid but user record not yet synced in DB
        user = UserDB(id=user_id, app_account_token=payload.get("app_account_token"))
        db.add(user)
        db.commit()
        db.refresh(user)

    return user


async def get_optional_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(optional_security_scheme),
    db: Session = Depends(get_db),
) -> Optional[UserDB]:
    """
    FastAPI dependency that returns authenticated UserDB if present, or None if anonymous.
    """
    if not credentials or not credentials.credentials:
        return None

    try:
        payload = decode_access_token(credentials.credentials)
        user_id = payload.get("sub")
        if user_id:
            return db.query(UserDB).filter(UserDB.id == user_id).first()
    except Exception:
        return None
    return None
