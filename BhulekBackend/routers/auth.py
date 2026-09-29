"""
Authentication API Router
Handles native Sign in with Apple, Google Sign-In, and Guest Device server-side verification,
canonical user creation, identity linking, and Bhumitra session access token issuance.
"""

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Body, Depends, HTTPException, status
from fastapi.concurrency import run_in_threadpool
from sqlalchemy.orm import Session

from db.session import get_db
from models.db_models import UserDB, AuthIdentityDB, DevicePromotionDB
from models.auth_models import (
    AppleAuthRequest,
    GoogleAuthRequest,
    DeviceAuthRequest,
    AuthResponse,
    UserProfileResponse,
    AuthIdentityResponse,
    AccountLinkingResponse,
    AccountDeletionRequest,
    AccountDeletionResponse,
)
from services.apple_revocation_service import apple_revocation_service
from core.security import (
    create_access_token,
    get_current_user,
    ACCESS_TOKEN_EXPIRE_DAYS,
)
from services.apple_auth_service import apple_auth_service, AppleAuthError
from services.google_auth_service import google_auth_service, GoogleAuthError

router = APIRouter()
logger = logging.getLogger(__name__)


def _generate_canonical_user_id() -> str:
    """Generates a stable, canonical Bhumitra user identifier."""
    return f"usr_{uuid.uuid4().hex[:16]}"


def _evaluate_and_grant_promotional_credits(db: Session, user: UserDB, device_id: Optional[str]) -> None:
    """
    Evaluates eligibility for the one-time 5-search promotional signup grant:
    - If device_id is provided, checks if device has already claimed promotion.
    - If device has claimed promotion, user receives 0 free credits.
    - If clean (or no device_id provided), user receives 5 free credits and device promotion is recorded.
    """
    if user.promotional_grant_claimed:
        return

    PROMOTIONAL_FREE_CREDITS = 5

    if device_id:
        clean_dev = device_id.strip()
        existing_claim = db.query(DevicePromotionDB).filter(DevicePromotionDB.device_id == clean_dev).first()
        if existing_claim:
            user.free_credits = 0
            user.promotional_grant_claimed = True
            print(f"DEBUG: 🛡️ [Anti-Abuse] Device '{clean_dev[:8]}...' already claimed promotion. User '{user.id}' granted 0 free searches.")
            return
        else:
            claim = DevicePromotionDB(
                device_id=clean_dev,
                first_claimed_user_id=user.id,
            )
            db.add(claim)

    user.free_credits = PROMOTIONAL_FREE_CREDITS
    user.promotional_grant_claimed = True
    print(f"DEBUG: 🎁 [Promo] User '{user.id}' granted {PROMOTIONAL_FREE_CREDITS} one-time free plot searches.")


def _build_user_profile(user: UserDB) -> UserProfileResponse:
    """Builds a rich UserProfileResponse with all linked auth providers."""
    linked = [ident.provider for ident in user.identities] if user.identities else []
    return UserProfileResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        app_account_token=user.app_account_token,
        plot_credits=user.plot_credits or 0,
        free_credits=user.free_credits or 0,
        created_at=user.created_at.isoformat() if user.created_at else None,
        linked_providers=linked,
    )


# MARK: - Apple Authentication

@router.post(
    "/auth/apple",
    response_model=AuthResponse,
    summary="Sign in with Apple Verification & Token Issuance",
    description="Validates native Apple ID identityToken, maps to canonical Bhumitra user via AuthIdentityDB, and issues a signed Bearer session token.",
)
async def authenticate_apple(
    request: AppleAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    try:
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

    apple_sub = str(payload.get("sub") or "")
    if not apple_sub:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Apple identity token missing 'sub' claim.",
        )

    # Extract verified email if provided
    raw_email = (payload.get("email") or request.email or "").strip().lower()
    email = raw_email if raw_email else None
    name = request.full_name.strip() if request.full_name else None
    app_account_token = request.app_account_token.strip() if request.app_account_token else None
    now = datetime.now(timezone.utc)

    # 1. Look up existing identity
    identity = (
        db.query(AuthIdentityDB)
        .filter(AuthIdentityDB.provider == "apple", AuthIdentityDB.provider_subject == apple_sub)
        .first()
    )

    if identity:
        user = db.query(UserDB).filter(UserDB.id == identity.user_id).first()
        if not user:
            # Recreate user if orphaned
            user = UserDB(
                id=identity.user_id,
                email=email or identity.provider_email,
                name=name,
                app_account_token=app_account_token,
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            if app_account_token and not user.app_account_token:
                user.app_account_token = app_account_token
                user.updated_at = now
            if email and not user.email:
                user.email = email
                user.updated_at = now
            if name and not user.name:
                user.name = name
                user.updated_at = now
            db.commit()
            db.refresh(user)
    else:
        # 2. Check legacy user table for backwards compatibility
        legacy_user = db.query(UserDB).filter(UserDB.id == apple_sub).first()
        if legacy_user:
            user = legacy_user
            if app_account_token and not user.app_account_token:
                user.app_account_token = app_account_token
                user.updated_at = now
            if email and not user.email:
                user.email = email
                user.updated_at = now
            identity = AuthIdentityDB(
                user_id=user.id,
                provider="apple",
                provider_subject=apple_sub,
                provider_email=email,
            )
            db.add(identity)
            db.commit()
            db.refresh(user)
        else:
            # 3. Safe Unambiguous Automatic Linking on Verified Real Email
            # (Only if non-relay, verified, and existing account does not already have an Apple identity)
            is_relay = email and ("privaterelay.appleid.com" in email)
            existing_user = None
            if email and not is_relay:
                existing_user = db.query(UserDB).filter(UserDB.email == email).first()

            if existing_user:
                has_apple_identity = any(i.provider == "apple" for i in existing_user.identities)
                if not has_apple_identity:
                    user = existing_user
                    identity = AuthIdentityDB(
                        user_id=user.id,
                        provider="apple",
                        provider_subject=apple_sub,
                        provider_email=email,
                    )
                    db.add(identity)
                    if app_account_token and not user.app_account_token:
                        user.app_account_token = app_account_token
                    db.commit()
                    db.refresh(user)
                    print(f"DEBUG: 🔗 [Auth] Automatically linked Apple identity to existing canonical user '{user.id}' via verified email '{email}'")
                else:
                    # Account already has a different Apple identity; create separate account to avoid hijacking
                    user = UserDB(
                        id=_generate_canonical_user_id(),
                        email=email,
                        name=name,
                        app_account_token=app_account_token,
                    )
                    db.add(user)
                    db.flush()
                    identity = AuthIdentityDB(
                        user_id=user.id,
                        provider="apple",
                        provider_subject=apple_sub,
                        provider_email=email,
                    )
                    db.add(identity)
                    db.commit()
                    db.refresh(user)
            else:
                # 4. Create new canonical user
                user = UserDB(
                    id=_generate_canonical_user_id(),
                    email=email,
                    name=name,
                    app_account_token=app_account_token,
                )
                db.add(user)
                db.flush()
                _evaluate_and_grant_promotional_credits(db, user, request.device_id)
                identity = AuthIdentityDB(
                    user_id=user.id,
                    provider="apple",
                    provider_subject=apple_sub,
                    provider_email=email,
                )
                db.add(identity)
                db.commit()
                db.refresh(user)
                print(f"DEBUG: 👤 [Auth] Created new canonical user record: '{user.id}' for Apple sub '{apple_sub}' (free_credits={user.free_credits})")

    access_token = create_access_token(
        user_id=user.id,
        app_account_token=user.app_account_token,
    )

    return AuthResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_DAYS * 86400,
        user=_build_user_profile(user),
        message="Sign in with Apple verified successfully.",
    )


# MARK: - Google Authentication

@router.post(
    "/auth/google",
    response_model=AuthResponse,
    summary="Sign in with Google Verification & Token Issuance",
    description="Validates Google ID Token, maps to canonical Bhumitra user via AuthIdentityDB, and issues a signed Bearer session token.",
)
async def authenticate_google(
    request: GoogleAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    try:
        payload = google_auth_service.verify_identity_token(id_token=request.id_token)
    except GoogleAuthError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.message,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Google authentication failed: {str(e)}",
        )

    google_sub = str(payload.get("sub") or "")
    if not google_sub:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Google ID token missing 'sub' claim.",
        )

    raw_email = (payload.get("email") or request.email or "").strip().lower()
    email = raw_email if raw_email else None
    email_verified = payload.get("email_verified") in [True, "true", "True", 1]
    name = (request.full_name or payload.get("name") or "").strip() or None
    app_account_token = request.app_account_token.strip() if request.app_account_token else None
    now = datetime.now(timezone.utc)

    # 1. Look up existing identity
    identity = (
        db.query(AuthIdentityDB)
        .filter(AuthIdentityDB.provider == "google", AuthIdentityDB.provider_subject == google_sub)
        .first()
    )

    if identity:
        user = db.query(UserDB).filter(UserDB.id == identity.user_id).first()
        if not user:
            user = UserDB(
                id=identity.user_id,
                email=email or identity.provider_email,
                name=name,
                app_account_token=app_account_token,
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            if app_account_token and not user.app_account_token:
                user.app_account_token = app_account_token
                user.updated_at = now
            if email and not user.email:
                user.email = email
                user.updated_at = now
            if name and not user.name:
                user.name = name
                user.updated_at = now
            db.commit()
            db.refresh(user)
    else:
        # 2. Check legacy user table for backwards compatibility
        legacy_id = f"google_{google_sub}"
        legacy_user = db.query(UserDB).filter(UserDB.id == legacy_id).first()
        if legacy_user:
            user = legacy_user
            if app_account_token and not user.app_account_token:
                user.app_account_token = app_account_token
                user.updated_at = now
            if email and not user.email:
                user.email = email
                user.updated_at = now
            identity = AuthIdentityDB(
                user_id=user.id,
                provider="google",
                provider_subject=google_sub,
                provider_email=email,
            )
            db.add(identity)
            db.commit()
            db.refresh(user)
        else:
            # 3. Safe Unambiguous Automatic Linking on Verified Real Email
            # (Only if email is verified by Google and existing account does not already have a Google identity)
            existing_user = None
            if email and email_verified:
                existing_user = db.query(UserDB).filter(UserDB.email == email).first()

            if existing_user:
                has_google_identity = any(i.provider == "google" for i in existing_user.identities)
                if not has_google_identity:
                    user = existing_user
                    identity = AuthIdentityDB(
                        user_id=user.id,
                        provider="google",
                        provider_subject=google_sub,
                        provider_email=email,
                    )
                    db.add(identity)
                    if app_account_token and not user.app_account_token:
                        user.app_account_token = app_account_token
                    db.commit()
                    db.refresh(user)
                    print(f"DEBUG: 🔗 [Auth] Automatically linked Google identity to existing canonical user '{user.id}' via verified email '{email}'")
                else:
                    user = UserDB(
                        id=_generate_canonical_user_id(),
                        email=email,
                        name=name,
                        app_account_token=app_account_token,
                    )
                    db.add(user)
                    db.flush()
                    identity = AuthIdentityDB(
                        user_id=user.id,
                        provider="google",
                        provider_subject=google_sub,
                        provider_email=email,
                    )
                    db.add(identity)
                    db.commit()
                    db.refresh(user)
            else:
                # 4. Create new canonical user
                user = UserDB(
                    id=_generate_canonical_user_id(),
                    email=email,
                    name=name,
                    app_account_token=app_account_token,
                )
                db.add(user)
                db.flush()
                _evaluate_and_grant_promotional_credits(db, user, request.device_id)
                identity = AuthIdentityDB(
                    user_id=user.id,
                    provider="google",
                    provider_subject=google_sub,
                    provider_email=email,
                )
                db.add(identity)
                db.commit()
                db.refresh(user)
                print(f"DEBUG: 👤 [Auth] Created new canonical user record: '{user.id}' for Google sub '{google_sub}' (free_credits={user.free_credits})")

    access_token = create_access_token(
        user_id=user.id,
        app_account_token=user.app_account_token,
    )

    return AuthResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_DAYS * 86400,
        user=_build_user_profile(user),
        message="Sign in with Google verified successfully.",
    )


# MARK: - Device Guest Authentication

@router.post(
    "/auth/device",
    response_model=AuthResponse,
    summary="Guest Device Registration & Token Issuance",
    description="Registers or finds a guest device identity in PostgreSQL and issues a signed Bhumitra Bearer session token to enforce server-authoritative quotas.",
)
async def authenticate_device(
    request: DeviceAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    device_id = request.device_id.strip()
    if not device_id or len(device_id) < 8 or len(device_id) > 128:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid device_id format.",
        )

    app_account_token = request.app_account_token.strip() if request.app_account_token else None
    now = datetime.now(timezone.utc)

    # 1. Check AuthIdentityDB
    identity = (
        db.query(AuthIdentityDB)
        .filter(AuthIdentityDB.provider == "device", AuthIdentityDB.provider_subject == device_id)
        .first()
    )

    if identity:
        user = db.query(UserDB).filter(UserDB.id == identity.user_id).first()
        if not user:
            user = UserDB(id=identity.user_id, app_account_token=app_account_token)
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            if app_account_token and not user.app_account_token:
                user.app_account_token = app_account_token
                user.updated_at = now
                db.commit()
                db.refresh(user)
    else:
        # 2. Check legacy device user ID
        legacy_id = f"dev_{device_id}"
        user = db.query(UserDB).filter(UserDB.id == legacy_id).first()
        if not user:
            user = UserDB(
                id=legacy_id,
                app_account_token=app_account_token,
            )
            db.add(user)
            db.flush()
            _evaluate_and_grant_promotional_credits(db, user, device_id)

        identity = AuthIdentityDB(
            user_id=user.id,
            provider="device",
            provider_subject=device_id,
        )
        db.add(identity)
        db.commit()
        db.refresh(user)
        print(f"DEBUG: 📱 [Auth] Registered device user identity: '{user.id}' (Device: {device_id}, free_credits={user.free_credits})")

    access_token = create_access_token(
        user_id=user.id,
        app_account_token=user.app_account_token,
    )

    return AuthResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_DAYS * 86400,
        user=_build_user_profile(user),
        message="Device session established successfully.",
    )


# MARK: - Explicit Account Linking (Authenticated)

@router.post(
    "/auth/link/apple",
    response_model=AccountLinkingResponse,
    summary="Link Apple Identity to Existing Authenticated Bhumitra Account",
    description="Explicitly attaches a verified Apple ID credential to the currently authenticated canonical user account.",
)
async def link_apple_account(
    request: AppleAuthRequest,
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AccountLinkingResponse:
    try:
        payload = apple_auth_service.verify_identity_token(
            identity_token=request.identity_token,
            expected_nonce=request.nonce,
        )
    except AppleAuthError as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Apple authentication failed: {str(e)}",
        )

    apple_sub = str(payload.get("sub") or "")
    if not apple_sub:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Apple identity token missing 'sub' claim.")

    raw_email = (payload.get("email") or request.email or "").strip().lower()
    email = raw_email if raw_email else None

    # Check if this Apple identity is already bound
    existing_identity = (
        db.query(AuthIdentityDB)
        .filter(AuthIdentityDB.provider == "apple", AuthIdentityDB.provider_subject == apple_sub)
        .first()
    )

    if existing_identity:
        if existing_identity.user_id == current_user.id:
            return AccountLinkingResponse(
                success=True,
                user=_build_user_profile(current_user),
                linked_provider="apple",
                message="Apple account is already linked to this Bhumitra account.",
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This Apple account is already linked to a different Bhumitra account.",
            )

    # Attach identity to current authenticated user
    identity = AuthIdentityDB(
        user_id=current_user.id,
        provider="apple",
        provider_subject=apple_sub,
        provider_email=email,
    )
    db.add(identity)
    if email and not current_user.email:
        current_user.email = email
    if request.app_account_token and not current_user.app_account_token:
        current_user.app_account_token = request.app_account_token.strip()

    db.commit()
    db.refresh(current_user)

    print(f"DEBUG: 🔗 [Auth] Successfully linked Apple identity '{apple_sub}' to user '{current_user.id}'")
    return AccountLinkingResponse(
        success=True,
        user=_build_user_profile(current_user),
        linked_provider="apple",
        message="Apple account linked successfully.",
    )


@router.post(
    "/auth/link/google",
    response_model=AccountLinkingResponse,
    summary="Link Google Identity to Existing Authenticated Bhumitra Account",
    description="Explicitly attaches a verified Google ID credential to the currently authenticated canonical user account.",
)
async def link_google_account(
    request: GoogleAuthRequest,
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AccountLinkingResponse:
    try:
        payload = google_auth_service.verify_identity_token(id_token=request.id_token)
    except GoogleAuthError as e:
        raise HTTPException(status_code=e.status_code, detail=e.message)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Google authentication failed: {str(e)}",
        )

    google_sub = str(payload.get("sub") or "")
    if not google_sub:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Google ID token missing 'sub' claim.")

    raw_email = (payload.get("email") or request.email or "").strip().lower()
    email = raw_email if raw_email else None

    # Check if this Google identity is already bound
    existing_identity = (
        db.query(AuthIdentityDB)
        .filter(AuthIdentityDB.provider == "google", AuthIdentityDB.provider_subject == google_sub)
        .first()
    )

    if existing_identity:
        if existing_identity.user_id == current_user.id:
            return AccountLinkingResponse(
                success=True,
                user=_build_user_profile(current_user),
                linked_provider="google",
                message="Google account is already linked to this Bhumitra account.",
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This Google account is already linked to a different Bhumitra account.",
            )

    # Attach identity to current authenticated user
    identity = AuthIdentityDB(
        user_id=current_user.id,
        provider="google",
        provider_subject=google_sub,
        provider_email=email,
    )
    db.add(identity)
    if email and not current_user.email:
        current_user.email = email
    if request.app_account_token and not current_user.app_account_token:
        current_user.app_account_token = request.app_account_token.strip()

    db.commit()
    db.refresh(current_user)

    print(f"DEBUG: 🔗 [Auth] Successfully linked Google identity '{google_sub}' to user '{current_user.id}'")
    return AccountLinkingResponse(
        success=True,
        user=_build_user_profile(current_user),
        linked_provider="google",
        message="Google account linked successfully.",
    )


@router.get(
    "/auth/identities",
    response_model=List[AuthIdentityResponse],
    summary="Get Current User's Linked Identities",
    description="Returns the list of all authentication providers (Apple, Google, Device) linked to the current canonical account.",
)
async def get_user_identities(
    current_user: UserDB = Depends(get_current_user),
) -> List[AuthIdentityResponse]:
    identities = current_user.identities or []
    return [
        AuthIdentityResponse(
            provider=i.provider,
            provider_subject=i.provider_subject,
            provider_email=i.provider_email,
            created_at=i.created_at.isoformat() if i.created_at else None,
        )
        for i in identities
    ]


@router.get(
    "/auth/me",
    response_model=UserProfileResponse,
    summary="Get Current Authenticated User Profile",
    description="Returns the profile information and linked providers of the currently authenticated user based on the verified Bearer token.",
)
async def get_me(
    current_user: UserDB = Depends(get_current_user),
) -> UserProfileResponse:
    return _build_user_profile(current_user)


@router.post(
    "/auth/refresh",
    response_model=AuthResponse,
    summary="Refresh Session Token",
    description="Exchanges a still-valid Bhumitra session token for a fresh one (sliding 30-day session).",
)
async def refresh_session(
    current_user: UserDB = Depends(get_current_user),
) -> AuthResponse:
    access_token = create_access_token(
        user_id=current_user.id,
        app_account_token=current_user.app_account_token,
    )
    return AuthResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_DAYS * 86400,
        user=_build_user_profile(current_user),
        message="Session refreshed.",
    )


@router.delete(
    "/auth/me",
    response_model=AccountDeletionResponse,
    summary="Delete Current Authenticated Account & Data (App Store Guideline 5.1.1(v))",
    description="Permanently deletes the authenticated user account, associated identities, and personal data from PostgreSQL. Preserves anonymous device anti-abuse state so deleted accounts cannot reclaim starter grants.",
)
async def delete_me(
    body: Optional[AccountDeletionRequest] = Body(None),
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AccountDeletionResponse:
    user_id = current_user.id

    # 0. Revoke Sign in with Apple tokens (best effort; never blocks deletion).
    has_apple_identity = any(
        getattr(i, "provider", None) == "apple"
        for i in db.query(AuthIdentityDB).filter(AuthIdentityDB.user_id == user_id).all()
    )
    revocation = None
    if has_apple_identity:
        revocation = await run_in_threadpool(
            apple_revocation_service.revoke_with_authorization_code,
            body.apple_authorization_code if body else None,
        )

    # 1. Check if user has an active Apple subscription
    has_active_sub = False
    if current_user.subscriptions:
        has_active_sub = any(s.status == "active" for s in current_user.subscriptions)

    # 2. Preserve device promotional anti-abuse mapping:
    # Set first_claimed_user_id to None so foreign key constraint is cleared,
    # but retain the device_id row in device_promotions table so the device
    # cannot claim another 5 free searches!
    try:
        db.query(DevicePromotionDB).filter(
            DevicePromotionDB.first_claimed_user_id == user_id
        ).update(
            {DevicePromotionDB.first_claimed_user_id: None},
            synchronize_session=False,
        )
    except Exception as e:
        print(f"DEBUG: ⚠️ Could not decouple device promotion on account deletion: {e}")

    # 3. Delete canonical user (cascades to auth_identities, user_usage, subscriptions per schema)
    db.delete(current_user)
    db.commit()

    notice = (
        "Note: Apple auto-renewable subscriptions are billed and managed directly by Apple. "
        "To prevent future billing, please cancel your active subscription in iOS Settings > Apple ID > Subscriptions."
        if has_active_sub
        else None
    )

    logger.info("ACCOUNT_DELETED apple_revocation=%s", revocation or "n/a")
    return AccountDeletionResponse(
        success=True,
        apple_token_revocation=revocation,
        message="Account and associated personal data successfully deleted.",
        deleted_user_id=user_id,
        has_active_subscription=has_active_sub,
        apple_subscription_notice=notice,
    )

