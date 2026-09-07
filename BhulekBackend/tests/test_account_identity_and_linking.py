"""
Test Suite for Canonical Account Identity & Provider Linking Architecture
Validates:
- Unified canonical user identity across Google, Apple, and Guest device authentication
- No duplicate free-quota exploit across provider switch
- Shared purchased credits across linked providers
- Shared unlimited subscription entitlement across linked providers
- Safe automatic email linking for verified non-relay emails
- Private relay isolation
- Explicit authenticated account linking (POST /auth/link/apple, POST /auth/link/google)
- 409 Conflict rejection when attempting to link an identity already claimed by another user
- Provider identity audit via GET /auth/identities
"""

import os
import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from db.base import Base
from models.db_models import UserDB, AuthIdentityDB, SubscriptionDB, UserUsageDB
from core.security import create_access_token
from tests.test_apple_verification import PKITestHelper, AppleVerificationService
from app import create_app


@pytest.fixture
def pki_helper():
    return PKITestHelper()


@pytest.fixture
def test_app_and_db(pki_helper, tmp_path, monkeypatch):
    # 1. Isolated SQLite test DB
    db_file = tmp_path / "test_identities.db"
    engine = create_engine(f"sqlite:///{db_file}", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    session_factory = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    from contextlib import contextmanager

    @contextmanager
    def test_get_db_session():
        session = session_factory()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    # 2. Mock Apple JWKS Verifier
    from services.apple_auth_service import AppleAuthService
    class MockAppleAuthService:
        def verify_identity_token(self, identity_token, signing_key_override=None, expected_nonce=None):
            if "invalid" in identity_token:
                from services.apple_auth_service import AppleAuthError
                raise AppleAuthError("Invalid Apple identity token")
            import json
            import base64
            # Decode payload
            parts = identity_token.split(".")
            if len(parts) >= 2:
                padded = parts[1] + "=" * ((4 - len(parts[1]) % 4) % 4)
                data = json.loads(base64.urlsafe_b64decode(padded))
                return data
            return {"sub": "apple_default_sub", "email": "apple_default@example.com"}

    # 3. Mock Google JWKS Verifier
    class MockGoogleAuthService:
        def verify_identity_token(self, id_token, signing_key_override=None):
            if "invalid" in id_token:
                from services.google_auth_service import GoogleAuthError
                raise GoogleAuthError("Invalid Google ID token")
            import json
            import base64
            parts = id_token.split(".")
            if len(parts) >= 2:
                padded = parts[1] + "=" * ((4 - len(parts[1]) % 4) % 4)
                data = json.loads(base64.urlsafe_b64decode(padded))
                return data
            return {"sub": "google_default_sub", "email": "google_default@example.com", "email_verified": True}

    import routers.auth as auth_mod
    import services.subscription_service as ss_mod
    import services.usage_service as us_mod
    import db.session as session_mod
    from db.session import get_db

    monkeypatch.setattr(auth_mod, "apple_auth_service", MockAppleAuthService())
    monkeypatch.setattr(auth_mod, "google_auth_service", MockGoogleAuthService())
    monkeypatch.setattr(ss_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(us_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "SessionLocal", session_factory)

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    return client, session_factory


def _make_dummy_jwt(payload: dict) -> str:
    import json
    import base64
    header = base64.urlsafe_b64encode(json.dumps({"alg": "RS256"}).encode()).decode().rstrip("=")
    body = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    return f"{header}.{body}.mock_signature"


# ==============================================================================
# TESTS
# ==============================================================================

def test_1_google_login_creates_canonical_user_and_identity(test_app_and_db):
    """1. Google login creates canonical user and links Google identity."""
    client, session_factory = test_app_and_db

    google_token = _make_dummy_jwt({
        "sub": "google_sub_1001",
        "email": "user1@example.com",
        "email_verified": True,
        "name": "User One",
    })

    res = client.post("/api/v1/auth/google", json={"id_token": google_token})
    assert res.status_code == 200
    data = res.json()
    canonical_id = data["user"]["id"]
    assert canonical_id.startswith("usr_")
    assert data["user"]["email"] == "user1@example.com"
    assert "google" in data["user"]["linked_providers"]

    # Verify in DB
    session = session_factory()
    ident = session.query(AuthIdentityDB).filter_by(provider="google", provider_subject="google_sub_1001").first()
    assert ident is not None
    assert ident.user_id == canonical_id
    session.close()


def test_2_apple_login_with_same_verified_email_links_to_same_canonical_user(test_app_and_db):
    """2. Apple login with same verified email automatically links to the existing canonical user."""
    client, session_factory = test_app_and_db

    # 1. Login with Google first
    g_token = _make_dummy_jwt({
        "sub": "google_sub_2001",
        "email": "shared_user@example.com",
        "email_verified": True,
        "name": "Shared User",
    })
    g_res = client.post("/api/v1/auth/google", json={"id_token": g_token})
    assert g_res.status_code == 200
    canonical_id = g_res.json()["user"]["id"]

    # 2. Login with Apple presenting the same real email
    a_token = _make_dummy_jwt({
        "sub": "apple_sub_2001",
        "email": "shared_user@example.com",
    })
    a_res = client.post("/api/v1/auth/apple", json={"identity_token": a_token})
    assert a_res.status_code == 200
    apple_data = a_res.json()

    # Must resolve to the EXACT same canonical user ID!
    assert apple_data["user"]["id"] == canonical_id
    assert set(apple_data["user"]["linked_providers"]) == {"google", "apple"}


def test_3_free_quota_shared_across_google_and_apple_provider_switch(test_app_and_db):
    """
    3. CRITICAL BUG REGRESSION TEST:
    Google login -> consume 10 free searches -> remaining free quota = 0
    Logout -> Apple login -> SAME canonical account -> remaining free quota = 0 (NOT fresh 10!).
    """
    client, session_factory = test_app_and_db

    # 1. Google sign-in
    g_token = _make_dummy_jwt({
        "sub": "google_sub_3001",
        "email": "quota_test@example.com",
        "email_verified": True,
    })
    g_res = client.post("/api/v1/auth/google", json={"id_token": g_token})
    canonical_user_id = g_res.json()["user"]["id"]
    g_bearer = g_res.json()["access_token"]

    # Verify initial quota is 5
    credits_res = client.get(
        "/api/v1/subscription/credits",
        headers={"Authorization": f"Bearer {g_bearer}"},
    )
    assert credits_res.status_code == 200
    assert credits_res.json()["free_remaining"] == 5

    # 2. Simulate consuming all 5 free RoR lookups on this canonical user
    session = session_factory()
    u = session.query(UserDB).filter_by(id=canonical_user_id).first()
    u.free_credits = 0
    session.commit()
    session.close()

    # Verify Google sees 0 free quota
    credits_res2 = client.get(
        "/api/v1/subscription/credits",
        headers={"Authorization": f"Bearer {g_bearer}"},
    )
    assert credits_res2.status_code == 200
    assert credits_res2.json()["free_remaining"] == 0

    # 3. User signs out and signs in with Apple (same email)
    a_token = _make_dummy_jwt({
        "sub": "apple_sub_3001",
        "email": "quota_test@example.com",
    })
    a_res = client.post("/api/v1/auth/apple", json={"identity_token": a_token})
    assert a_res.status_code == 200
    assert a_res.json()["user"]["id"] == canonical_user_id
    a_bearer = a_res.json()["access_token"]

    # 4. Check credit balance on Apple session -> MUST BE 0 (NO fresh free quota granted!)
    apple_credits_res = client.get(
        "/api/v1/subscription/credits",
        headers={"Authorization": f"Bearer {a_bearer}"},
    )
    assert apple_credits_res.status_code == 200
    assert apple_credits_res.json()["free_remaining"] == 0
    assert apple_credits_res.json()["purchased_credits"] == 0
    assert apple_credits_res.json()["credits"] == 0


def test_4_purchased_credits_shared_across_linked_providers(test_app_and_db):
    """4. Purchased credits belong to canonical user and are identical across Google & Apple."""
    client, session_factory = test_app_and_db

    # 1. Google sign-in
    g_token = _make_dummy_jwt({
        "sub": "google_sub_4001",
        "email": "purchased_credits@example.com",
        "email_verified": True,
    })
    g_res = client.post("/api/v1/auth/google", json={"id_token": g_token})
    canonical_id = g_res.json()["user"]["id"]
    g_bearer = g_res.json()["access_token"]

    # Grant 15 purchased credits to canonical user
    session = session_factory()
    u = session.query(UserDB).filter_by(id=canonical_id).first()
    u.plot_credits = 15
    session.commit()
    session.close()

    # Check Google sees 15 purchased credits
    res_g = client.get("/api/v1/subscription/credits", headers={"Authorization": f"Bearer {g_bearer}"})
    assert res_g.json()["purchased_credits"] == 15

    # 2. Apple login with same email
    a_token = _make_dummy_jwt({
        "sub": "apple_sub_4001",
        "email": "purchased_credits@example.com",
    })
    a_res = client.post("/api/v1/auth/apple", json={"identity_token": a_token})
    a_bearer = a_res.json()["access_token"]

    # Check Apple sees exact same 15 purchased credits
    res_a = client.get("/api/v1/subscription/credits", headers={"Authorization": f"Bearer {a_bearer}"})
    assert res_a.json()["purchased_credits"] == 15

    # 3. Deduct 1 credit from canonical user
    session = session_factory()
    u = session.query(UserDB).filter_by(id=canonical_id).first()
    u.plot_credits = 14
    session.commit()
    session.close()

    # Verify both Google and Apple see 14
    res_g2 = client.get("/api/v1/subscription/credits", headers={"Authorization": f"Bearer {g_bearer}"})
    res_a2 = client.get("/api/v1/subscription/credits", headers={"Authorization": f"Bearer {a_bearer}"})
    assert res_g2.json()["purchased_credits"] == 14
    assert res_a2.json()["purchased_credits"] == 14


def test_5_unlimited_subscription_shared_across_linked_providers(test_app_and_db):
    """5. Active subscription entitlement belongs to canonical user and is active on both providers."""
    client, session_factory = test_app_and_db

    # 1. Google sign-in
    g_token = _make_dummy_jwt({
        "sub": "google_sub_5001",
        "email": "sub_shared@example.com",
        "email_verified": True,
    })
    g_res = client.post("/api/v1/auth/google", json={"id_token": g_token})
    canonical_id = g_res.json()["user"]["id"]
    g_bearer = g_res.json()["access_token"]

    # 2. Add active subscription in DB for canonical user
    session = session_factory()
    sub = SubscriptionDB(
        user_id=canonical_id,
        product_id="bhumitra.unlimited.monthly",
        plan="monthly",
        original_transaction_id="tx_sub_5001",
        status="active",
        auto_renew_status=True,
    )
    session.add(sub)
    session.commit()
    session.close()

    # Google sees active subscription
    sub_g = client.get("/api/v1/subscription/status", headers={"Authorization": f"Bearer {g_bearer}"})
    assert sub_g.json()["is_premium"] is True
    assert sub_g.json()["status"] == "active"

    # 3. Apple sign-in
    a_token = _make_dummy_jwt({
        "sub": "apple_sub_5001",
        "email": "sub_shared@example.com",
    })
    a_res = client.post("/api/v1/auth/apple", json={"identity_token": a_token})
    a_bearer = a_res.json()["access_token"]

    # Apple sees same active subscription
    sub_a = client.get("/api/v1/subscription/status", headers={"Authorization": f"Bearer {a_bearer}"})
    assert sub_a.json()["is_premium"] is True
    assert sub_a.json()["status"] == "active"
    assert sub_a.json()["user_id"] == canonical_id


def test_6_explicit_account_linking_authenticated(test_app_and_db):
    """6. Explicit linking via POST /auth/link/apple and POST /auth/link/google."""
    client, session_factory = test_app_and_db

    # 1. User signs in with Google (using private email)
    g_token = _make_dummy_jwt({
        "sub": "google_sub_6001",
        "email": "explicit_user@gmail.com",
        "email_verified": True,
    })
    g_res = client.post("/api/v1/auth/google", json={"id_token": g_token})
    canonical_id = g_res.json()["user"]["id"]
    g_bearer = g_res.json()["access_token"]

    # 2. User links their Apple account with an Apple private relay email
    a_token = _make_dummy_jwt({
        "sub": "apple_sub_6001",
        "email": "relay123@privaterelay.appleid.com",
    })
    link_res = client.post(
        "/api/v1/auth/link/apple",
        headers={"Authorization": f"Bearer {g_bearer}"},
        json={"identity_token": a_token},
    )
    assert link_res.status_code == 200
    assert link_res.json()["success"] is True
    assert link_res.json()["linked_provider"] == "apple"
    assert set(link_res.json()["user"]["linked_providers"]) == {"google", "apple"}

    # 3. Query GET /auth/identities
    ident_res = client.get("/api/v1/auth/identities", headers={"Authorization": f"Bearer {g_bearer}"})
    assert ident_res.status_code == 200
    providers = [i["provider"] for i in ident_res.json()]
    assert set(providers) == {"google", "apple"}

    # 4. Now user can log in via Apple directly and get the SAME canonical account
    a_login = client.post("/api/v1/auth/apple", json={"identity_token": a_token})
    assert a_login.status_code == 200
    assert a_login.json()["user"]["id"] == canonical_id


def test_7_duplicate_account_linking_rejected_with_409(test_app_and_db):
    """7. Attempting to link an already-linked Apple/Google identity to a second user returns HTTP 409 Conflict."""
    client, session_factory = test_app_and_db

    # Create User A with Apple Identity
    a_token = _make_dummy_jwt({"sub": "apple_exclusive_sub", "email": "userA@example.com"})
    res_a = client.post("/api/v1/auth/apple", json={"identity_token": a_token})
    assert res_a.status_code == 200

    # Create User B with Google Identity
    g_token = _make_dummy_jwt({"sub": "google_exclusive_sub", "email": "userB@gmail.com", "email_verified": True})
    res_b = client.post("/api/v1/auth/google", json={"id_token": g_token})
    bearer_b = res_b.json()["access_token"]

    # User B tries to link User A's Apple identity -> Must return 409 Conflict!
    link_fail = client.post(
        "/api/v1/auth/link/apple",
        headers={"Authorization": f"Bearer {bearer_b}"},
        json={"identity_token": a_token},
    )
    assert link_fail.status_code == 409
    assert "already linked to a different Bhumitra account" in link_fail.json()["detail"]


def test_8_apple_private_relay_creates_separate_account_unless_explicitly_linked(test_app_and_db):
    """8. Apple private relay email does NOT automatically merge into an existing account."""
    client, session_factory = test_app_and_db

    # User 1 has a Google account
    g_token = _make_dummy_jwt({"sub": "google_relay_test", "email": "real_user@gmail.com", "email_verified": True})
    res_g = client.post("/api/v1/auth/google", json={"id_token": g_token})
    canonical_g_id = res_g.json()["user"]["id"]

    # User 2 logs in with Apple Private Relay
    a_token = _make_dummy_jwt({"sub": "apple_relay_test", "email": "xyz@privaterelay.appleid.com"})
    res_a = client.post("/api/v1/auth/apple", json={"identity_token": a_token})
    canonical_a_id = res_a.json()["user"]["id"]

    # Must be separate accounts to avoid hijacking
    assert canonical_a_id != canonical_g_id
