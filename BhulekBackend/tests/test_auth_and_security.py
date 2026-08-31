"""
Authentication & Security Test Suite
Tests Sign in with Apple identity token verification, JWT session tokens,
FastAPI security dependencies, user isolation, and IDOR prevention.
"""

import os
import datetime
import pytest
import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import create_app
from db.base import Base
from db.session import get_db
from models.db_models import UserDB, SubscriptionDB
from services.apple_auth_service import apple_auth_service
from services.apple_verification_service import AppleVerificationService
from core.security import create_access_token
from tests.test_apple_verification import PKITestHelper


class ApplePKIHelper:
    """Helper to generate RSA keys for testing Sign in with Apple Identity Tokens."""

    def __init__(self):
        self.private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
        )
        self.public_key = self.private_key.public_key()
        self.key_id = "apple-test-key-id-1"

    def sign_identity_token(
        self,
        sub: str = "apple_user_0001",
        aud: str = "com.kirtidhwaj.Bhumitra",
        iss: str = "https://appleid.apple.com",
        exp_delta: datetime.timedelta = datetime.timedelta(hours=1),
        email: str = "test@bhumitra.in",
        nonce: str = None,
    ) -> str:
        now = datetime.datetime.now(datetime.timezone.utc)
        payload = {
            "iss": iss,
            "aud": aud,
            "exp": int((now + exp_delta).timestamp()),
            "iat": int(now.timestamp()),
            "sub": sub,
            "email": email,
            "email_verified": "true",
            "is_private_email": "false",
        }
        if nonce:
            payload["nonce"] = nonce

        headers = {"kid": self.key_id, "alg": "RS256"}
        return jwt.encode(payload, self.private_key, algorithm="RS256", headers=headers)


@pytest.fixture
def apple_pki():
    return ApplePKIHelper()


@pytest.fixture
def storekit_pki():
    return PKITestHelper()


@pytest.fixture
def test_app_and_db(tmp_path, apple_pki, storekit_pki, monkeypatch):
    # Setup test database
    db_file = tmp_path / "test_auth_suite.db"
    engine = create_engine(f"sqlite:///{db_file}", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    from contextlib import contextmanager

    @contextmanager
    def test_get_db_session():
        session = TestingSessionLocal()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    def override_get_db():
        session = TestingSessionLocal()
        try:
            yield session
        finally:
            session.close()

    # Setup Apple verifiers
    certs_dir = str(tmp_path / "test_certs")
    os.makedirs(certs_dir, exist_ok=True)
    with open(os.path.join(certs_dir, "test_root.cer"), "wb") as f:
        f.write(storekit_pki.root_der)

    storekit_verifier = AppleVerificationService(certs_dir=certs_dir)

    # Monkeypatch
    import services.subscription_service as ss_mod
    import db.session as session_mod
    import core.security as sec_mod

    monkeypatch.setattr(ss_mod, "apple_verification_service", storekit_verifier)
    monkeypatch.setattr(ss_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "SessionLocal", TestingSessionLocal)

    # Patch apple_auth_service to use test RSA public key
    orig_verify = apple_auth_service.verify_identity_token

    def mock_verify_identity_token(identity_token, signing_key_override=None, expected_nonce=None):
        return orig_verify(
            identity_token=identity_token,
            signing_key_override=apple_pki.public_key,
            expected_nonce=expected_nonce,
        )

    monkeypatch.setattr(apple_auth_service, "verify_identity_token", mock_verify_identity_token)

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    return client, TestingSessionLocal


# ==============================================================================
# TESTS
# ==============================================================================

def test_1_valid_apple_login_and_token_issuance(apple_pki, test_app_and_db):
    """1. Valid Sign in with Apple identity token generates user and issues Bearer access token."""
    client, _ = test_app_and_db
    id_token = apple_pki.sign_identity_token(
        sub="apple_user_alpha_1",
        email="alpha@bhumitra.in",
    )

    res = client.post(
        "/api/v1/auth/apple",
        json={
            "identity_token": id_token,
            "app_account_token": "TOKEN-ALPHA-UUID",
            "full_name": "Alpha Tester",
            "email": "alpha@bhumitra.in",
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["id"] == "apple_user_alpha_1"
    assert data["user"]["app_account_token"] == "TOKEN-ALPHA-UUID"


def test_2_invalid_token_signature_rejected(apple_pki, test_app_and_db):
    """2. Tampered Apple identity token signature is rejected with HTTP 401."""
    client, _ = test_app_and_db
    id_token = apple_pki.sign_identity_token(sub="apple_user_tampered")
    parts = id_token.split(".")
    tampered = f"{parts[0]}.{parts[1]}.tampered_signature"

    res = client.post(
        "/api/v1/auth/apple",
        json={"identity_token": tampered},
    )
    assert res.status_code == 401


def test_3_expired_identity_token_rejected(apple_pki, test_app_and_db):
    """3. Expired Apple identity token is rejected with HTTP 401."""
    client, _ = test_app_and_db
    expired_token = apple_pki.sign_identity_token(
        sub="apple_user_expired",
        exp_delta=datetime.timedelta(hours=-2),
    )

    res = client.post(
        "/api/v1/auth/apple",
        json={"identity_token": expired_token},
    )
    assert res.status_code == 401
    assert "expired" in res.json()["detail"].lower()


def test_4_wrong_audience_rejected(apple_pki, test_app_and_db):
    """4. Token issued for another application bundle ID is rejected with HTTP 401."""
    client, _ = test_app_and_db
    wrong_aud_token = apple_pki.sign_identity_token(
        sub="apple_user_wrong_app",
        aud="com.unauthorized.otherapp",
    )

    res = client.post(
        "/api/v1/auth/apple",
        json={"identity_token": wrong_aud_token},
    )
    assert res.status_code == 401


def test_5_wrong_issuer_rejected(apple_pki, test_app_and_db):
    """5. Token from an untrusted issuer is rejected with HTTP 401."""
    client, _ = test_app_and_db
    wrong_iss_token = apple_pki.sign_identity_token(
        sub="apple_user_fake_issuer",
        iss="https://fake-issuer.com",
    )

    res = client.post(
        "/api/v1/auth/apple",
        json={"identity_token": wrong_iss_token},
    )
    assert res.status_code == 401


def test_6_unauthenticated_request_rejected(test_app_and_db):
    """6. Accessing protected endpoint without Bearer token returns HTTP 401."""
    client, _ = test_app_and_db
    res = client.get("/api/v1/subscription/status")
    assert res.status_code == 401


def test_7_invalid_bearer_token_rejected(test_app_and_db):
    """7. Accessing protected endpoint with invalid Bearer token returns HTTP 401."""
    client, _ = test_app_and_db
    res = client.get(
        "/api/v1/subscription/status",
        headers={"Authorization": "Bearer invalid_forged_session_token"},
    )
    assert res.status_code == 401


def test_8_user_isolation_idor_prevention(test_app_and_db):
    """8. User A cannot access User B's subscription status via IDOR path (returns HTTP 403)."""
    client, session_factory = test_app_and_db

    # Create User A & User B
    session = session_factory()
    user_a = UserDB(id="user_A_id", app_account_token="TOKEN-A")
    user_b = UserDB(id="user_B_id", app_account_token="TOKEN-B")
    session.add_all([user_a, user_b])
    session.commit()
    session.close()

    # User A obtains session token
    token_a = create_access_token(user_id="user_A_id", app_account_token="TOKEN-A")

    # User A attempts to access User B's subscription
    res = client.get(
        "/api/v1/subscription/status/user_B_id",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert res.status_code == 403
    assert "cannot access or query another user" in res.json()["detail"].lower()


def test_9_secure_subscription_verification_ignores_client_user_id(storekit_pki, test_app_and_db):
    """9. Subscription verification derives identity strictly from Bearer token, ignoring spoofed user_id in body."""
    client, session_factory = test_app_and_db

    # Create User A & User B
    session = session_factory()
    user_a = UserDB(id="user_legit_A", app_account_token="TOKEN-USER-A")
    user_b = UserDB(id="victim_user_B", app_account_token="TOKEN-USER-B")
    session.add_all([user_a, user_b])
    session.commit()
    session.close()

    # User A session token
    token_a = create_access_token(user_id="user_legit_A", app_account_token="TOKEN-USER-A")

    tx_jws = storekit_pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "8000000001",
        "expiresDate": 2100000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-USER-A",
    })

    # User A sends request maliciously claiming user_id="victim_user_B" in JSON body
    res = client.post(
        "/api/v1/subscription/verify",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "user_id": "victim_user_B",  # Malicious spoof attempt
            "signed_transaction_jws": tx_jws,
            "original_transaction_id": "8000000001",
            "app_account_token": "TOKEN-USER-A",
        },
    )
    assert res.status_code == 200
    data = res.json()
    # Entitlement must be granted to authenticated User A, NOT victim User B
    assert data["user_id"] == "user_legit_A"

    # Query User A subscription status
    status_res = client.get(
        "/api/v1/subscription/status",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert status_res.status_code == 200
    assert status_res.json()["is_premium"] is True
    assert status_res.json()["user_id"] == "user_legit_A"


def test_10_app_account_token_mismatch_rejected(storekit_pki, test_app_and_db):
    """10. Transaction with mismatched appAccountToken is rejected with HTTP 403."""
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_bound_1", app_account_token="CORRECT-TOKEN-UUID")
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_bound_1", app_account_token="CORRECT-TOKEN-UUID")

    tx_jws = storekit_pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "8000000002",
        "environment": "Sandbox",
        "appAccountToken": "WRONG-TOKEN-UUID",
    })

    res = client.post(
        "/api/v1/subscription/verify",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "signed_transaction_jws": tx_jws,
            "original_transaction_id": "8000000002",
            "app_account_token": "WRONG-TOKEN-UUID",
        },
    )
    assert res.status_code == 403


def test_11_get_authenticated_user_profile(apple_pki, test_app_and_db):
    """11. GET /api/v1/auth/me returns profile of currently authenticated user."""
    client, _ = test_app_and_db
    id_token = apple_pki.sign_identity_token(sub="apple_user_me_test")

    login_res = client.post(
        "/api/v1/auth/apple",
        json={"identity_token": id_token, "app_account_token": "TOKEN-ME"},
    )
    access_token = login_res.json()["access_token"]

    me_res = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert me_res.status_code == 200
    assert me_res.json()["id"] == "apple_user_me_test"
    assert me_res.json()["app_account_token"] == "TOKEN-ME"
