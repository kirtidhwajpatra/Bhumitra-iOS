"""
Test Suite for StoreKit 2 Consumable Purchases (Plot Search Credits)
Validates:
- Exact product-to-credit mapping (10, 50, 200 credits)
- Cryptographic Apple JWS verification
- Server-authoritative credit balances
- Strict transaction deduplication & idempotency
- Concurrent duplicate transaction race conditions
- Subscription vs consumable product endpoint isolation
- Unauthenticated / unauthorized rejection
- Multiple accumulated purchases
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
    # 1. Setup isolated SQLite test DB with all models
    db_file = tmp_path / "test_consumables.db"
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

    # 2. Setup PKI Certificate Verifier with Root CA
    certs_dir = str(tmp_path / "certs")
    os.makedirs(certs_dir, exist_ok=True)
    with open(os.path.join(certs_dir, "test_root.cer"), "wb") as f:
        f.write(pki_helper.root_der)

    verifier = AppleVerificationService(certs_dir=certs_dir)

    # 3. Monkeypatch session and verification service
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
# TESTS
# ==============================================================================

def test_1_valid_10_plot_purchase(pki_helper, test_app_and_db):
    """1. Valid bhumitra.plots.10 transaction grants exactly 10 credits."""
    client, session_factory = test_app_and_db

    # Create User
    session = session_factory()
    user = UserDB(id="user_plot_10", app_account_token="TOKEN-10", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_plot_10", app_account_token="TOKEN-10")

    # Sign Apple JWS for 10 plots pack
    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_apple_1001",
        "originalTransactionId": "tx_apple_1001",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-10",
    })

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )

    assert res.status_code == 200
    data = res.json()
    assert data["user_id"] == "user_plot_10"
    assert data["product_id"] == "bhumitra.plots.10"
    assert data["credits_granted"] == 10
    assert data["current_balance"] == 10
    assert data["transaction_id"] == "tx_apple_1001"
    assert data["already_processed"] is False

    # Check DB transaction record
    session = session_factory()
    tx_record = session.query(ConsumableTransactionDB).filter_by(transaction_id="tx_apple_1001").first()
    assert tx_record is not None
    assert tx_record.credits_granted == 10
    assert tx_record.user_id == "user_plot_10"

    # Check User DB balance
    db_user = session.query(UserDB).filter_by(id="user_plot_10").first()
    assert db_user.plot_credits == 10
    session.close()


def test_2_valid_50_plot_purchase(pki_helper, test_app_and_db):
    """2. Valid bhumitra.plots.50 transaction grants exactly 50 credits."""
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_plot_50", app_account_token="TOKEN-50", plot_credits=5)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_plot_50", app_account_token="TOKEN-50")

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.50",
        "transactionId": "tx_apple_5001",
        "originalTransactionId": "tx_apple_5001",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-50",
    })

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )

    assert res.status_code == 200
    data = res.json()
    assert data["product_id"] == "bhumitra.plots.50"
    assert data["credits_granted"] == 50
    assert data["current_balance"] == 55  # 5 initial + 50 granted


def test_3_valid_200_plot_purchase(pki_helper, test_app_and_db):
    """3. Valid bhumitra.plots.200 transaction grants exactly 200 credits."""
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_plot_200", app_account_token="TOKEN-200", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_plot_200", app_account_token="TOKEN-200")

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.200",
        "transactionId": "tx_apple_20001",
        "originalTransactionId": "tx_apple_20001",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-200",
    })

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )

    assert res.status_code == 200
    data = res.json()
    assert data["product_id"] == "bhumitra.plots.200"
    assert data["credits_granted"] == 200
    assert data["current_balance"] == 200


def test_4_duplicate_transaction_is_idempotent(pki_helper, test_app_and_db):
    """4. Submitting the exact same transaction ID twice does not grant duplicate credits."""
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_idem_1", app_account_token="TOKEN-IDEM", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_idem_1", app_account_token="TOKEN-IDEM")

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.50",
        "transactionId": "tx_apple_unique_999",
        "originalTransactionId": "tx_apple_unique_999",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-IDEM",
    })

    # First Submission
    res1 = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["credits_granted"] == 50
    assert data1["current_balance"] == 50
    assert data1["already_processed"] is False

    # Second Submission (Exact duplicate transaction)
    res2 = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["credits_granted"] == 0
    assert data2["current_balance"] == 50  # Balance remains 50, NOT 100!
    assert data2["already_processed"] is True
    assert "already been processed" in data2["message"].lower()

    # Verify only ONE transaction record in DB
    session = session_factory()
    tx_count = session.query(ConsumableTransactionDB).filter_by(transaction_id="tx_apple_unique_999").count()
    assert tx_count == 1
    session.close()


def test_5_concurrent_duplicate_transactions(pki_helper, test_app_and_db):
    """5. Concurrent submissions of the same transaction ID safely credit only once without race conditions."""
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_concurrent", app_account_token="TOKEN-CONC", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_concurrent", app_account_token="TOKEN-CONC")

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.100" if "bhumitra.plots.100" in [] else "bhumitra.plots.50",
        "transactionId": "tx_apple_race_123",
        "originalTransactionId": "tx_apple_race_123",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-CONC",
    })

    def send_purchase():
        return client.post(
            "/api/v1/subscription/credits/purchase",
            headers={"Authorization": f"Bearer {token}"},
            json={"signed_transaction_jws": tx_jws},
        )

    # Fire 5 concurrent requests with the identical transaction JWS
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(send_purchase) for _ in range(5)]
        responses = [f.result() for f in futures]

    for r in responses:
        assert r.status_code == 200

    granted_counts = [r.json()["credits_granted"] for r in responses]
    # Exactly ONE response must have granted credits, others must be 0
    assert granted_counts.count(50) == 1
    assert granted_counts.count(0) == 4

    # Final DB balance must be exactly 50
    session = session_factory()
    db_user = session.query(UserDB).filter_by(id="user_concurrent").first()
    assert db_user.plot_credits == 50
    session.close()


def test_6_invalid_jws_rejected(test_app_and_db):
    """6. Invalid or malformed JWS is rejected with HTTP 400."""
    client, session_factory = test_app_and_db

    token = create_access_token(user_id="user_inv_jws")

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": "invalid.malformed.jws.signature"},
    )
    assert res.status_code == 400
    assert "verification failed" in res.json()["detail"].lower()


def test_7_unknown_product_id_rejected(pki_helper, test_app_and_db):
    """7. Transaction with unknown/unauthorized product ID is rejected with HTTP 422."""
    client, session_factory = test_app_and_db

    token = create_access_token(user_id="user_unknown_prod")

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.9999_fake",
        "transactionId": "tx_fake_999",
        "originalTransactionId": "tx_fake_999",
        "environment": "Sandbox",
    })

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert res.status_code == 422
    assert "unknown product id" in res.json()["detail"].lower()


def test_8_subscription_product_submitted_to_consumable_endpoint_rejected(pki_helper, test_app_and_db):
    """8. Submitting a subscription product (bhumitra.unlimited.monthly) to consumable endpoint is rejected with HTTP 400."""
    client, session_factory = test_app_and_db

    token = create_access_token(user_id="user_sub_to_cons")

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "transactionId": "tx_sub_1001",
        "originalTransactionId": "tx_sub_1001",
        "expiresDate": 2100000000000,
        "environment": "Sandbox",
    })

    res = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert res.status_code == 400
    assert "is a subscription" in res.json()["detail"].lower()


def test_9_consumable_product_submitted_to_subscription_endpoint_rejected(pki_helper, test_app_and_db):
    """9. Submitting a consumable pack (bhumitra.plots.10) to subscription endpoint is rejected with HTTP 400."""
    client, session_factory = test_app_and_db

    token = create_access_token(user_id="user_cons_to_sub")

    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_cons_1001",
        "originalTransactionId": "tx_cons_1001",
        "environment": "Sandbox",
    })

    res = client.post(
        "/api/v1/subscription/verify",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "signed_transaction_jws": tx_jws,
            "original_transaction_id": "tx_cons_1001",
        },
    )
    assert res.status_code == 400
    assert "consumable credit pack" in res.json()["detail"].lower()


def test_10_unauthenticated_requests_rejected(test_app_and_db):
    """10. Unauthenticated requests to consumable endpoints return HTTP 401."""
    client, _ = test_app_and_db

    # Purchase endpoint without token
    res1 = client.post(
        "/api/v1/subscription/credits/purchase",
        json={"signed_transaction_jws": "some_jws"},
    )
    assert res1.status_code == 401

    # Balance endpoint without token
    res2 = client.get("/api/v1/subscription/credits")
    assert res2.status_code == 401


def test_11_multiple_accumulated_purchases_and_balance_query(pki_helper, test_app_and_db):
    """11. Successive purchases of 10 + 50 + 200 correctly accumulate to 260 credits."""
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_accumulate", app_account_token="TOKEN-ACCUM", plot_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_accumulate", app_account_token="TOKEN-ACCUM")

    # 1. Buy 10 plots
    tx1 = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_accum_1",
        "originalTransactionId": "tx_accum_1",
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-ACCUM",
    })
    r1 = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx1},
    )
    assert r1.status_code == 200
    assert r1.json()["current_balance"] == 10

    # 2. Buy 50 plots
    tx2 = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.50",
        "transactionId": "tx_accum_2",
        "originalTransactionId": "tx_accum_2",
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-ACCUM",
    })
    r2 = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx2},
    )
    assert r2.status_code == 200
    assert r2.json()["current_balance"] == 60

    # 3. Buy 200 plots
    tx3 = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.200",
        "transactionId": "tx_accum_3",
        "originalTransactionId": "tx_accum_3",
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-ACCUM",
    })
    r3 = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx3},
    )
    assert r3.status_code == 200
    assert r3.json()["current_balance"] == 260

    # 4. Check GET /subscription/credits balance query endpoint
    balance_res = client.get(
        "/api/v1/subscription/credits",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert balance_res.status_code == 200
    balance_data = balance_res.json()
    assert balance_data["user_id"] == "user_accumulate"
    assert balance_data["credits"] == 260
