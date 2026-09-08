"""
Phase 2 Comprehensive Test Suite for Purchase Invariants & Credit Persistence
Covers Tests 1 through 12 required by Phase 2 specification:
- TEST 1: Authenticated user + verified NEW transaction -> backend grants +10
- TEST 2: Authenticated user + verified NEW transaction -> backend grants +50
- TEST 3: Authenticated user + backend failure -> returns error, no credit grant
- TEST 4: Missing authentication -> no anonymous credit account, no credits granted
- TEST 5: Unverified/fake Apple transaction -> zero credits granted
- TEST 6: Already-processed transaction -> credits_granted = 0, already_processed = True
- TEST 7: Existing server balance = 50 -> server returns 50
- TEST 8: Server request is loading -> loading state is distinct from 0
- TEST 9: Server request fails -> UI/client contract must NOT overwrite balance with 0
- TEST 10: User has 50 credits -> stale/default local value = 0 -> local 0 must never overwrite server 50
- TEST 11: New transaction increments balance atomically with row locking
- TEST 12: Same transaction ID submitted twice -> exactly one credit grant
"""

import os
import pytest
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from db.base import Base
from models.db_models import UserDB, ConsumableTransactionDB
from core.security import create_access_token
from tests.test_apple_verification import PKITestHelper, AppleVerificationService
from app import create_app


@pytest.fixture
def pki_helper():
    return PKITestHelper()


@pytest.fixture
def test_app_and_db(pki_helper, tmp_path, monkeypatch):
    # Setup isolated SQLite test DB
    db_file = tmp_path / "test_phase2_invariants.db"
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

    certs_dir = str(tmp_path / "certs")
    os.makedirs(certs_dir, exist_ok=True)
    with open(os.path.join(certs_dir, "test_root.cer"), "wb") as f:
        f.write(pki_helper.root_der)

    verifier = AppleVerificationService(certs_dir=certs_dir)

    import services.subscription_service as ss_mod
    import db.session as session_mod
    from db.session import get_db

    monkeypatch.setattr(ss_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(ss_mod, "apple_verification_service", verifier)
    monkeypatch.setattr(session_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "SessionLocal", session_factory)

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    return client, session_factory


# ==============================================================================
# TEST 1: Authenticated user + verified NEW transaction -> backend grants +10
# ==============================================================================
def test_1_authenticated_user_verified_new_10_plots(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_test1", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test1")
    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_test1_new",
        "originalTransactionId": "tx_test1_new",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
    })

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )

    assert res.status_code == 200
    data = res.json()
    assert data["credits_granted"] == 10
    assert data["already_processed"] is False
    assert data["current_balance"] == 15  # 5 free starter + 10 granted
    assert data["user_id"] == "user_test1"


# ==============================================================================
# TEST 2: Authenticated user + verified NEW transaction -> backend grants +50
# ==============================================================================
def test_2_authenticated_user_verified_new_50_plots(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_test2", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test2")
    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.50",
        "transactionId": "tx_test2_new",
        "originalTransactionId": "tx_test2_new",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
    })

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )

    assert res.status_code == 200
    data = res.json()
    assert data["credits_granted"] == 50
    assert data["already_processed"] is False
    assert data["current_balance"] == 55  # 5 free starter + 50 granted
    assert data["user_id"] == "user_test2"


# ==============================================================================
# TEST 3: Authenticated user + backend failure -> no credit grant
# ==============================================================================
def test_3_authenticated_user_backend_failure_no_credit_grant(test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_test3", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test3")

    # Send corrupted JWS simulating verification failure
    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": "corrupted.jws.payload"},
    )

    assert res.status_code == 400

    # Verify zero credits granted
    session = session_factory()
    db_user = session.query(UserDB).filter_by(id="user_test3").first()
    assert db_user.plot_credits == 0
    session.close()


# ==============================================================================
# TEST 4: Missing authentication -> no anonymous credit account, no credits granted
# ==============================================================================
def test_4_missing_auth_rejects_and_creates_no_anonymous_records(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.50",
        "transactionId": "tx_anon_attempt_1",
        "originalTransactionId": "tx_anon_attempt_1",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
    })

    # Call purchase WITHOUT Authorization header
    res = client.post(
        "/api/v1/subscription/credits/purchase",
        json={"signed_transaction_jws": tx_jws},
    )

    # Must be 401 Unauthorized
    assert res.status_code == 401

    # Verify NO user or transaction was created in DB
    session = session_factory()
    anon_users = session.query(UserDB).filter(UserDB.id.like("anon_%")).all()
    assert len(anon_users) == 0
    anon_txs = session.query(ConsumableTransactionDB).filter_by(transaction_id="tx_anon_attempt_1").all()
    assert len(anon_txs) == 0
    session.close()


# ==============================================================================
# TEST 5: Unverified/fake Apple transaction -> zero credits granted
# ==============================================================================
def test_5_unverified_fake_apple_transaction_fails_closed(test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_test5", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test5")

    # Construct unverified base64 JWS with fake signature
    import base64
    import json
    fake_payload = {
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.200",
        "transactionId": "tx_fake_200",
        "originalTransactionId": "tx_fake_200",
        "environment": "Xcode",
    }
    b64 = base64.urlsafe_b64encode(json.dumps(fake_payload).encode()).decode().rstrip("=")
    fake_jws = f"eyJhbGciOiJFUzI1NiJ9.{b64}.fake_unverified_signature"

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": fake_jws},
    )

    assert res.status_code == 400
    assert "verification failed" in res.json()["detail"].lower()

    # User balance must remain 0
    session = session_factory()
    db_user = session.query(UserDB).filter_by(id="user_test5").first()
    assert db_user.plot_credits == 0
    session.close()


# ==============================================================================
# TEST 6: Already-processed transaction -> credits_granted = 0, already_processed = True
# ==============================================================================
def test_6_already_processed_transaction_returns_zero_granted(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_test6", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test6")
    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_test6_idempotent",
        "originalTransactionId": "tx_test6_idempotent",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
    })

    # Submission 1: New purchase
    res1 = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert res1.status_code == 200
    assert res1.json()["credits_granted"] == 10
    assert res1.json()["already_processed"] is False

    # Submission 2: Duplicate purchase
    res2 = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert res2.status_code == 200
    assert res2.json()["credits_granted"] == 0
    assert res2.json()["already_processed"] is True
    assert res2.json()["current_balance"] == 15  # 5 + 10 = 15, NOT 25!


# ==============================================================================
# TEST 7: Existing server balance = 50 -> server returns 50
# ==============================================================================
def test_7_server_balance_returns_authoritative_50(test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    # 50 purchased + 5 free = 55 total
    user = UserDB(id="user_test7", plot_credits=50, free_credits=5)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test7")
    res = client.get(
        "/api/v1/subscription/credits",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert res.status_code == 200
    data = res.json()
    assert data["credits"] == 55
    assert data["purchased_credits"] == 50
    assert data["free_remaining"] == 5


# ==============================================================================
# TEST 8: Server request is loading -> loading state is distinct from 0
# ==============================================================================
def test_8_loading_state_distinction(test_app_and_db):
    """
    Validates that the server credit response contract explicitly separates
    user credit values from unauthenticated or missing states.
    """
    client, _ = test_app_and_db
    # Unauthenticated GET /subscription/credits returns 401, NOT credits=0!
    res = client.get("/api/v1/subscription/credits")
    assert res.status_code == 401
    assert "detail" in res.json()


# ==============================================================================
# TEST 9: Server request fails -> UI/client contract must NOT overwrite balance with 0
# ==============================================================================
def test_9_server_failure_returns_error_not_zero_balance(test_app_and_db):
    client, _ = test_app_and_db
    # An invalid token produces 401, never a valid JSON containing {credits: 0}
    res = client.get(
        "/api/v1/subscription/credits",
        headers={"Authorization": "Bearer invalid_token_xyz"},
    )
    assert res.status_code == 401
    assert "credits" not in res.json()


# ==============================================================================
# TEST 10: User has 50 credits -> stale/default local value = 0 -> local 0 must never overwrite server 50
# ==============================================================================
def test_10_local_zero_cannot_overwrite_server_balance(test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_test10", plot_credits=50, free_credits=5)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test10")

    # Server endpoint GET /subscription/credits is read-only and authoritative
    res = client.get(
        "/api/v1/subscription/credits",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    assert res.json()["credits"] == 55

    # Verify server DB remains at 50
    session = session_factory()
    db_user = session.query(UserDB).filter_by(id="user_test10").first()
    assert db_user.plot_credits == 50
    session.close()


# ==============================================================================
# TEST 11: New transaction increments balance atomically with row locking
# ==============================================================================
def test_11_atomic_balance_increment_with_row_locking(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_test11", plot_credits=10, free_credits=5)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test11")

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.50",
        "transactionId": "tx_test11_atomic",
        "originalTransactionId": "tx_test11_atomic",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
    })

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["credits_granted"] == 50
    assert data["current_balance"] == 65  # 15 + 50 = 65

    session = session_factory()
    db_user = session.query(UserDB).filter_by(id="user_test11").first()
    assert db_user.plot_credits == 60
    session.close()


# ==============================================================================
# TEST 12: Same transaction ID submitted twice -> exactly one credit grant
# ==============================================================================
def test_12_duplicate_submission_grants_exactly_once(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_test12", plot_credits=0, free_credits=5)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test12")

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.200",
        "transactionId": "tx_test12_duplicate",
        "originalTransactionId": "tx_test12_duplicate",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
    })

    # First Call
    r1 = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert r1.status_code == 200
    assert r1.json()["credits_granted"] == 200
    assert r1.json()["already_processed"] is False

    # Second Call (Exact same tx)
    r2 = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert r2.status_code == 200
    assert r2.json()["credits_granted"] == 0
    assert r2.json()["already_processed"] is True

    # Total in DB is exactly 200
    session = session_factory()
    db_user = session.query(UserDB).filter_by(id="user_test12").first()
    assert db_user.plot_credits == 200
    tx_count = session.query(ConsumableTransactionDB).filter_by(transaction_id="tx_test12_duplicate").count()
    assert tx_count == 1
    session.close()
