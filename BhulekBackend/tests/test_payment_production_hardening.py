"""
Automated Test Suite for Payment System Production Hardening
Covers:
  1. Successful consumable purchase with CreditLedgerDB and hardened ConsumableTransactionDB
  2. Idempotent duplicate purchase processing (0 additional credits, already_processed=True)
  3. Credit ledger integrity & mathematical balance reconstruction
  4. Credit consumption hierarchy & ledger audit records
  5. Admin support user search & purchase inspection
  6. Admin audited credit adjustments (positive & negative, non-negative balance enforcement)
  7. Admin transaction repair / re-sync
  8. Admin and ASSN V2 refund / revocation handling with REFUND_REVERSAL
  9. ASSN V2 duplicate notification idempotency
 10. Security: X-Admin-Key protection enforcement
"""

import os
import time
import pytest

# Must match whatever routers.admin_support loaded at import time.
TEST_ADMIN_KEY = os.environ.get("ADMIN_API_KEY", "bhumitra_admin_secret_key_2026")
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import create_app
from db.base import Base
from db.session import get_db
from models.db_models import (
    UserDB,
    SubscriptionDB,
    TransactionDB,
    ConsumableTransactionDB,
    CreditLedgerDB,
    SubscriptionEventDB,
)
from services.subscription_service import subscription_service
from services.apple_verification_service import apple_verification_service, AppleVerificationError
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import JWSTransactionDecodedPayload
from appstoreserverlibrary.models.Environment import Environment


from contextlib import contextmanager

# In-memory SQLite for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def setup_db(monkeypatch):
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    @contextmanager
    def override_get_db_session():
        session = TestingSessionLocal()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    import db.session
    import services.subscription_service
    import services.usage_service

    monkeypatch.setattr(db.session, "get_db_session", override_get_db_session)
    monkeypatch.setattr(services.subscription_service, "get_db_session", override_get_db_session)
    monkeypatch.setattr(services.usage_service, "get_db_session", override_get_db_session)

    yield

    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(monkeypatch):
    from core.security import create_access_token

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db

    c = TestClient(app)
    return c


def create_fake_jws(tx_id: str, product_id: str, orig_tx_id: str = None, app_account_token: str = None, env: Environment = Environment.PRODUCTION):
    """Helper to mock verified Apple transaction payload."""
    payload = JWSTransactionDecodedPayload(
        transactionId=tx_id,
        originalTransactionId=orig_tx_id or tx_id,
        productId=product_id,
        purchaseDate=int(time.time() * 1000),
        environment=env,
        appAccountToken=app_account_token,
    )
    return payload


# MARK: - 1. Consumable Purchase & Ledger Invariants

def test_successful_consumable_purchase_creates_transaction_and_ledger_entry(monkeypatch):
    user_id = "user_harden_01"
    tx_id = "apple_tx_1001"
    prod_id = "bhumitra.plots.50"

    # Setup user
    with TestingSessionLocal() as db:
        user = UserDB(id=user_id, plot_credits=0, free_credits=5)
        db.add(user)
        db.commit()

    # Mock Apple verification
    mock_decoded = create_fake_jws(tx_id, prod_id, app_account_token="bhumitra-token-1")
    monkeypatch.setattr(apple_verification_service, "verify_and_decode_transaction", lambda **kw: mock_decoded)

    response = subscription_service.process_consumable_purchase(
        user_id=user_id,
        signed_transaction_jws="mock_jws",
        expected_app_account_token=None,
    )

    assert response.credits_granted == 50
    assert response.current_balance == 55  # 5 free + 50 purchased
    assert response.already_processed is False

    with TestingSessionLocal() as db:
        # Check hardened ConsumableTransactionDB
        cons_tx = db.query(ConsumableTransactionDB).filter(ConsumableTransactionDB.transaction_id == tx_id).first()
        assert cons_tx is not None
        assert cons_tx.credits_granted == 50
        assert cons_tx.delivery_state == "delivered"
        assert cons_tx.verification_state == "verified"
        assert cons_tx.app_account_token == "bhumitra-token-1"

        # Check CreditLedgerDB
        ledger = db.query(CreditLedgerDB).filter(CreditLedgerDB.user_id == user_id).first()
        assert ledger is not None
        assert ledger.entry_type == "PURCHASE"
        assert ledger.amount == 50
        assert ledger.balance_after == 55
        assert ledger.reference_id == tx_id


def test_duplicate_consumable_purchase_is_strictly_idempotent(monkeypatch):
    user_id = "user_harden_02"
    tx_id = "apple_tx_1002"
    prod_id = "bhumitra.plots.10"

    with TestingSessionLocal() as db:
        user = UserDB(id=user_id, plot_credits=0, free_credits=0)
        db.add(user)
        db.commit()

    mock_decoded = create_fake_jws(tx_id, prod_id)
    monkeypatch.setattr(apple_verification_service, "verify_and_decode_transaction", lambda **kw: mock_decoded)

    # First delivery
    res1 = subscription_service.process_consumable_purchase(user_id=user_id, signed_transaction_jws="jws")
    assert res1.credits_granted == 10
    assert res1.current_balance == 10
    assert res1.already_processed is False

    # Second delivery (retry / replayed callback)
    res2 = subscription_service.process_consumable_purchase(user_id=user_id, signed_transaction_jws="jws")
    assert res2.credits_granted == 0
    assert res2.current_balance == 10
    assert res2.already_processed is True

    # Third delivery
    res3 = subscription_service.process_consumable_purchase(user_id=user_id, signed_transaction_jws="jws")
    assert res3.credits_granted == 0
    assert res3.current_balance == 10
    assert res3.already_processed is True

    with TestingSessionLocal() as db:
        ledger_count = db.query(CreditLedgerDB).filter(CreditLedgerDB.user_id == user_id).count()
        assert ledger_count == 1  # Exactly one credit ledger entry ever created!


def test_consumable_already_processed_for_different_user_is_rejected(monkeypatch):
    """Cross-user guard: a transaction already credited to user A must NOT be
    silently returned as a 0-credit success to user B (the "balance up to date
    (0)" bug). It must raise a 409 conflict so credits can't be double-claimed
    and the tapping user gets a real error instead of a false success."""
    user_a = "user_cross_A"
    user_b = "user_cross_B"
    tx_id = "apple_tx_cross_user_1"
    prod_id = "bhumitra.plots.50"

    with TestingSessionLocal() as db:
        db.add(UserDB(id=user_a, plot_credits=0, free_credits=0))
        db.add(UserDB(id=user_b, plot_credits=0, free_credits=0))
        db.commit()

    mock_decoded = create_fake_jws(tx_id, prod_id)
    monkeypatch.setattr(apple_verification_service, "verify_and_decode_transaction", lambda **kw: mock_decoded)

    # User A legitimately gets the credits.
    res_a = subscription_service.process_consumable_purchase(user_id=user_a, signed_transaction_jws="jws")
    assert res_a.credits_granted == 50
    assert res_a.already_processed is False

    # User B submits the SAME transaction → must be rejected with 409, NOT a
    # silent 0-credit "already processed" success.
    with pytest.raises(AppleVerificationError) as exc:
        subscription_service.process_consumable_purchase(user_id=user_b, signed_transaction_jws="jws")
    assert exc.value.status_code == 409

    # User B's balance is untouched; User A keeps exactly one credit grant.
    with TestingSessionLocal() as db:
        b = db.query(UserDB).filter(UserDB.id == user_b).first()
        assert (b.plot_credits or 0) == 0
        a_ledger = db.query(CreditLedgerDB).filter(CreditLedgerDB.user_id == user_a).count()
        assert a_ledger == 1
        b_ledger = db.query(CreditLedgerDB).filter(CreditLedgerDB.user_id == user_b).count()
        assert b_ledger == 0


def test_same_user_replay_still_idempotent_after_cross_user_guard(monkeypatch):
    """The cross-user guard must not break same-user idempotent replay."""
    user_id = "user_same_replay"
    tx_id = "apple_tx_same_replay_1"
    prod_id = "bhumitra.plots.10"

    with TestingSessionLocal() as db:
        db.add(UserDB(id=user_id, plot_credits=0, free_credits=0))
        db.commit()

    mock_decoded = create_fake_jws(tx_id, prod_id)
    monkeypatch.setattr(apple_verification_service, "verify_and_decode_transaction", lambda **kw: mock_decoded)

    res1 = subscription_service.process_consumable_purchase(user_id=user_id, signed_transaction_jws="jws")
    assert res1.credits_granted == 10 and res1.already_processed is False

    res2 = subscription_service.process_consumable_purchase(user_id=user_id, signed_transaction_jws="jws")
    assert res2.credits_granted == 0 and res2.already_processed is True
    assert res2.current_balance == 10


def test_credit_ledger_mathematical_balance_reconstruction(monkeypatch):
    user_id = "user_harden_reconstruct"

    with TestingSessionLocal() as db:
        user = UserDB(id=user_id, plot_credits=0, free_credits=0)
        db.add(user)
        db.commit()

    # Perform 3 distinct purchases: +10, +50, +200
    for i, (prod, amt) in enumerate([("bhumitra.plots.10", 10), ("bhumitra.plots.50", 50), ("bhumitra.plots.200", 200)]):
        tx_id = f"recon_tx_{i}"
        mock_decoded = create_fake_jws(tx_id, prod)
        monkeypatch.setattr(apple_verification_service, "verify_and_decode_transaction", lambda **kw: mock_decoded)
        res = subscription_service.process_consumable_purchase(user_id=user_id, signed_transaction_jws="jws")
        assert res.credits_granted == amt

    # Consume 3 credits
    from services.usage_service import usage_service
    for _ in range(3):
        usage_service.deduct_ror_search(user_id=user_id)

    # Reconstruct balance from ledger
    recon = subscription_service.reconstruct_user_balance_from_ledger(user_id)
    assert recon["reconstructed_balance"] == 257  # 10 + 50 + 200 - 3 = 257
    assert recon["actual_balance"] == 257
    assert recon["is_balanced"] is True
    assert recon["total_entries"] == 6  # 3 purchases + 3 consumptions


# MARK: - 2. Admin Support Capabilities

def test_admin_requires_secret_key(client):
    res = client.get("/api/v1/admin/users/search?query=test")
    assert res.status_code == 403


def test_admin_user_search_and_purchase_history(client, monkeypatch):
    admin_key = TEST_ADMIN_KEY
    headers = {"X-Admin-Key": admin_key}

    user_id = "user_admin_searchable"
    with TestingSessionLocal() as db:
        user = UserDB(id=user_id, email="customer@example.com", name="Ramesh Sahoo", plot_credits=20, free_credits=0)
        db.add(user)
        db.commit()

    # Search user
    search_res = client.get(f"/api/v1/admin/users/search?query=Ramesh", headers=headers)
    assert search_res.status_code == 200
    data = search_res.json()
    assert len(data) == 1
    assert data[0]["id"] == user_id
    assert data[0]["email"] == "customer@example.com"
    assert data[0]["total_balance"] == 20


def test_admin_audited_credit_adjustment(client):
    admin_key = TEST_ADMIN_KEY
    headers = {"X-Admin-Key": admin_key}

    user_id = "user_admin_adjust"
    with TestingSessionLocal() as db:
        user = UserDB(id=user_id, plot_credits=5, free_credits=0)
        db.add(user)
        db.commit()

    # 1. Manual positive credit grant
    adjust_payload = {
        "amount": 10,
        "reason": "Customer paid successfully but automatic delivery timed out.",
        "admin_id": "support_agent_rahul",
    }
    res = client.post(f"/api/v1/admin/users/{user_id}/credits/adjust", json=adjust_payload, headers=headers)
    assert res.status_code == 200
    res_data = res.json()
    assert res_data["status"] == "success"
    assert res_data["adjustment"] == 10
    assert res_data["new_balance"] == 15
    assert res_data["admin_id"] == "support_agent_rahul"

    # 2. Verify ledger audit row
    with TestingSessionLocal() as db:
        user = db.query(UserDB).filter(UserDB.id == user_id).first()
        assert user.plot_credits == 15

        ledger = (
            db.query(CreditLedgerDB)
            .filter(CreditLedgerDB.user_id == user_id)
            .order_by(CreditLedgerDB.created_at.desc())
            .first()
        )
        assert ledger.entry_type == "ADMIN_ADJUSTMENT"
        assert ledger.amount == 10
        assert ledger.admin_id == "support_agent_rahul"
        assert ledger.reason == "Customer paid successfully but automatic delivery timed out."

    # 3. Disallow negative balance adjustment
    invalid_neg = {
        "amount": -20,
        "reason": "Excessive deduction attempt",
        "admin_id": "support_agent_rahul",
    }
    res_neg = client.post(f"/api/v1/admin/users/{user_id}/credits/adjust", json=invalid_neg, headers=headers)
    assert res_neg.status_code == 400
    assert "negative balance" in res_neg.json()["detail"]


def test_refund_unused_credits(client):
    """Unused credits refund: 50 granted, 0 consumed -> deducts 50, balance becomes 0."""
    admin_key = TEST_ADMIN_KEY
    headers = {"X-Admin-Key": admin_key}
    user_id = "user_unused_refund"
    tx_id = "tx_unused_50"

    with TestingSessionLocal() as db:
        user = UserDB(id=user_id, plot_credits=50, free_credits=0)
        db.add(user)
        cons = ConsumableTransactionDB(
            id="c_tx_unused",
            transaction_id=tx_id,
            original_transaction_id=tx_id,
            user_id=user_id,
            product_id="bhumitra.plots.50",
            credits_granted=50,
            environment="Production",
            delivery_state="delivered",
            verification_state="verified",
        )
        db.add(cons)
        db.commit()

    refund_payload = {
        "original_transaction_id": tx_id,
        "reason": "Customer requested refund before using credits",
        "admin_id": "admin_sarah",
    }
    res = client.post("/api/v1/admin/refunds/record", json=refund_payload, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "refund_recorded"
    assert data["credits_deducted"] == 50
    assert data["credits_consumed"] == 0

    with TestingSessionLocal() as db:
        u = db.query(UserDB).filter(UserDB.id == user_id).first()
        assert u.plot_credits == 0
        ledger = (
            db.query(CreditLedgerDB)
            .filter(CreditLedgerDB.user_id == user_id, CreditLedgerDB.entry_type == "REFUND_REVERSAL")
            .first()
        )
        assert ledger is not None
        assert ledger.amount == -50
        assert ledger.balance_after == 0
        assert "granted=50, clawed_back=50, consumed=0" in ledger.reason


def test_refund_partially_consumed_credits(client):
    """Partially consumed refund: 50 granted, 20 consumed (30 remain) -> deducts 30, balance 0, audits 20 consumed."""
    admin_key = TEST_ADMIN_KEY
    headers = {"X-Admin-Key": admin_key}
    user_id = "user_partial_refund"
    tx_id = "tx_partial_50"

    with TestingSessionLocal() as db:
        # User spent 20, 30 credits left
        user = UserDB(id=user_id, plot_credits=30, free_credits=0)
        db.add(user)
        cons = ConsumableTransactionDB(
            id="c_tx_partial",
            transaction_id=tx_id,
            original_transaction_id=tx_id,
            user_id=user_id,
            product_id="bhumitra.plots.50",
            credits_granted=50,
            environment="Production",
            delivery_state="delivered",
            verification_state="verified",
        )
        db.add(cons)
        db.commit()

    refund_payload = {
        "original_transaction_id": tx_id,
        "reason": "Customer requested partial refund",
        "admin_id": "admin_sarah",
    }
    res = client.post("/api/v1/admin/refunds/record", json=refund_payload, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "refund_recorded"
    assert data["credits_deducted"] == 30
    assert data["credits_consumed"] == 20

    with TestingSessionLocal() as db:
        u = db.query(UserDB).filter(UserDB.id == user_id).first()
        assert u.plot_credits == 0
        ledger = (
            db.query(CreditLedgerDB)
            .filter(CreditLedgerDB.user_id == user_id, CreditLedgerDB.entry_type == "REFUND_REVERSAL")
            .first()
        )
        assert ledger is not None
        assert ledger.amount == -30
        assert ledger.balance_after == 0
        assert "granted=50, clawed_back=30, consumed=20" in ledger.reason


def test_refund_fully_consumed_credits(client):
    """Fully consumed refund: 50 granted, all 50 consumed (0 remain) -> deducts 0, balance 0, audits 50 consumed, never negative."""
    admin_key = TEST_ADMIN_KEY
    headers = {"X-Admin-Key": admin_key}
    user_id = "user_fully_consumed_refund"
    tx_id = "tx_fully_consumed_50"

    with TestingSessionLocal() as db:
        user = UserDB(id=user_id, plot_credits=0, free_credits=0)
        db.add(user)
        cons = ConsumableTransactionDB(
            id="c_tx_full",
            transaction_id=tx_id,
            original_transaction_id=tx_id,
            user_id=user_id,
            product_id="bhumitra.plots.50",
            credits_granted=50,
            environment="Production",
            delivery_state="delivered",
            verification_state="verified",
        )
        db.add(cons)
        db.commit()

    refund_payload = {
        "original_transaction_id": tx_id,
        "reason": "Apple approved refund on fully used credits",
        "admin_id": "admin_sarah",
    }
    res = client.post("/api/v1/admin/refunds/record", json=refund_payload, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "refund_recorded"
    assert data["credits_deducted"] == 0
    assert data["credits_consumed"] == 50

    with TestingSessionLocal() as db:
        u = db.query(UserDB).filter(UserDB.id == user_id).first()
        assert u.plot_credits == 0  # Guarantees balance never negative
        ledger = (
            db.query(CreditLedgerDB)
            .filter(CreditLedgerDB.user_id == user_id, CreditLedgerDB.entry_type == "REFUND_REVERSAL")
            .first()
        )
        assert ledger is not None
        assert ledger.amount == 0
        assert ledger.balance_after == 0
        assert "granted=50, clawed_back=0, consumed=50" in ledger.reason


def test_duplicate_refund_notification_idempotency(client):
    """Duplicate refund notifications/requests are idempotent and do not double-reverse credits."""
    admin_key = TEST_ADMIN_KEY
    headers = {"X-Admin-Key": admin_key}
    user_id = "user_dup_refund"
    tx_id = "tx_dup_refund_10"

    with TestingSessionLocal() as db:
        user = UserDB(id=user_id, plot_credits=10, free_credits=0)
        db.add(user)
        cons = ConsumableTransactionDB(
            id="c_tx_dup",
            transaction_id=tx_id,
            original_transaction_id=tx_id,
            user_id=user_id,
            product_id="bhumitra.plots.10",
            credits_granted=10,
            environment="Production",
            delivery_state="delivered",
            verification_state="verified",
        )
        db.add(cons)
        db.commit()

    refund_payload = {
        "original_transaction_id": tx_id,
        "reason": "Customer refund",
        "admin_id": "admin_sarah",
    }
    # First refund call
    res1 = client.post("/api/v1/admin/refunds/record", json=refund_payload, headers=headers)
    assert res1.status_code == 200
    assert res1.json()["status"] == "refund_recorded"
    assert res1.json()["credits_deducted"] == 10

    # User subsequently earns 5 new credits
    with TestingSessionLocal() as db:
        u = db.query(UserDB).filter(UserDB.id == user_id).first()
        u.plot_credits = 5
        db.commit()

    # Second (duplicate) refund call for same transaction
    res2 = client.post("/api/v1/admin/refunds/record", json=refund_payload, headers=headers)
    assert res2.status_code == 200
    assert res2.json()["status"] == "already_refunded"
    assert res2.json()["credits_deducted"] == 0

    # Verify user's new 5 credits were NOT double-reversed
    with TestingSessionLocal() as db:
        u = db.query(UserDB).filter(UserDB.id == user_id).first()
        assert u.plot_credits == 5

        # Verify only 1 REFUND_REVERSAL row exists in ledger
        ledger_count = (
            db.query(CreditLedgerDB)
            .filter(CreditLedgerDB.user_id == user_id, CreditLedgerDB.entry_type == "REFUND_REVERSAL")
            .count()
        )
        assert ledger_count == 1


def test_refund_after_previous_admin_correction(client):
    """Refund works correctly even if an admin adjustment previously occurred."""
    admin_key = TEST_ADMIN_KEY
    headers = {"X-Admin-Key": admin_key}
    user_id = "user_admin_corr"
    tx_id = "tx_corr_25"

    with TestingSessionLocal() as db:
        user = UserDB(id=user_id, plot_credits=20, free_credits=0)
        db.add(user)
        cons = ConsumableTransactionDB(
            id="c_tx_corr",
            transaction_id=tx_id,
            original_transaction_id=tx_id,
            user_id=user_id,
            product_id="bhumitra.plots.50",
            credits_granted=50,
            environment="Production",
            delivery_state="delivered",
            verification_state="verified",
        )
        db.add(cons)
        db.commit()

    # User receives an admin promotional grant of +10
    adjust_payload = {
        "amount": 10,
        "reason": "Goodwill grant",
        "admin_id": "support_agent",
    }
    res_adj = client.post(f"/api/v1/admin/users/{user_id}/credits/adjust", json=adjust_payload, headers=headers)
    assert res_adj.status_code == 200
    assert res_adj.json()["new_balance"] == 30

    # Now refund for the original 50-credit transaction occurs
    refund_payload = {
        "original_transaction_id": tx_id,
        "reason": "Apple refund processed",
        "admin_id": "admin_sarah",
    }
    res_ref = client.post("/api/v1/admin/refunds/record", json=refund_payload, headers=headers)
    assert res_ref.status_code == 200
    assert res_ref.json()["credits_deducted"] == 30  # Caps at user's current 30 balance
    assert res_ref.json()["credits_consumed"] == 20

    with TestingSessionLocal() as db:
        u = db.query(UserDB).filter(UserDB.id == user_id).first()
        assert u.plot_credits == 0
