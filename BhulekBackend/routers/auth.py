"""
Authentication API Router
Handles native Sign in with Apple server-side identity verification,
user creation/linking in PostgreSQL, and Bhumitra session access token issuance.
"""

from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from db.session import get_db
from models.db_models import UserDB
from models.auth_models import (
    AppleAuthRequest,
    AuthResponse,
    UserProfileResponse,
)
from core.security import (
    create_access_token,
    get_current_user,
    ACCESS_TOKEN_EXPIRE_DAYS,
)
from services.apple_auth_service import apple_auth_service, AppleAuthError

router = APIRouter()


@router.post(
    "/auth/apple",
    response_model=AuthResponse,
    summary="Sign in with Apple Verification & Token Issuance",
    description="Validates native Apple ID identityToken, finds or creates the user in PostgreSQL, and issues a signed Bhumitra Bearer session token.",
)
async def authenticate_apple(
    request: AppleAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    try:
        # Cryptographically verify Apple Identity Token against Apple JWKS
        payload = apple_auth_service.verify_identity_token(
            identity_token=request.identity_token,
            expected_nonce=request.nonce,
        )
    except AppleAuthError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.message,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Apple authentication failed: {str(e)}",
        )

    apple_user_id = str(payload.get("sub"))
    if not apple_user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Apple identity token missing 'sub' claim.",
        )

    app_account_token = request.app_account_token.strip() if request.app_account_token else None
    now = datetime.now(timezone.utc)

    # Find or create user in PostgreSQL
    user = db.query(UserDB).filter(UserDB.id == apple_user_id).first()
    if not user:
        user = UserDB(
            id=apple_user_id,
            app_account_token=app_account_token,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        print(f"DEBUG: 👤 [Auth] Created new user record in DB: '{apple_user_id}' with appAccountToken: '{app_account_token}'")
    else:
        # Update appAccountToken if newly provided
        if app_account_token and user.app_account_token != app_account_token:
            user.app_account_token = app_account_token
            user.updated_at = now
            db.commit()
            db.refresh(user)
            print(f"DEBUG: 👤 [Auth] Updated existing user '{apple_user_id}' with appAccountToken: '{app_account_token}'")

    # Issue Bhumitra JWT Access Token
    access_token = create_access_token(
        user_id=user.id,
        app_account_token=user.app_account_token,
    )

    return AuthResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_DAYS * 86400,
        user=UserProfileResponse(
            id=user.id,
            app_account_token=user.app_account_token,
            created_at=user.created_at.isoformat() if user.created_at else None,
        ),
        message="Sign in with Apple verified successfully.",
    )


@router.get(
    "/auth/me",
    response_model=UserProfileResponse,
    summary="Get Current Authenticated User Profile",
    description="Returns the profile information of the currently authenticated user based on the verified Bearer token.",
)
async def get_me(
    current_user: UserDB = Depends(get_current_user),
) -> UserProfileResponse:
    return UserProfileResponse(
        id=current_user.id,
        app_account_token=current_user.app_account_token,
        created_at=current_user.created_at.isoformat() if current_user.created_at else None,
    )
