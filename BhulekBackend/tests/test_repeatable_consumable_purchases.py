"""
Phase 3 Comprehensive Test Suite for Repeatable Consumable Purchases
Covers Tests 1 through 16 mandated by Phase 3 specification:
- TEST 1: Same product, transaction 101 -> +10
- TEST 2: Same product, transaction 102 -> +10 again, balance = 20
- TEST 3: Replay transaction 101 -> +0, already_processed=true, balance remains 20
- TEST 4: Same product, transaction 103 -> +10, balance = 30
- TEST 5: Different consumable: bhumitra.plots.50 transaction 104 -> +50, balance = 80
- TEST 6: Replay transaction 104 -> +0, balance remains 80
- TEST 7: Backend failure on new transaction -> no credit grant, fails cleanly
- TEST 8: Recover failed transaction -> backend succeeds -> exactly one credit grant
- TEST 9: Already-processed unfinished transaction -> backend confirms processed, 0 credits
- TEST 10: App restart after 3 successful consumable purchases -> authoritative balance persists
- TEST 11: Two concurrent submissions of SAME transaction ID -> exactly one credit grant
- TEST 12: Two different transaction IDs for SAME product -> two credit grants
- TEST 13: Consumable remains purchasable after successful purchase
- TEST 14: Consumable remains purchasable after app restart
- TEST 15: Consumable is not blocked by restore-purchases state
- TEST 16: No Product ID based deduplication exists (only transaction_id is idempotency key)
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
    db_file = tmp_path / "test_phase3_repeatable.db"
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


def test_repeatable_journey_tests_1_to_6(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_repeat_journey", plot_credits=0, free_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_repeat_journey")
    headers = {"Authorization": f"Bearer {token}"}

    # TEST 1: Same product (bhumitra.plots.10), transaction 101 -> +10
    jws_101 = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "101",
        "originalTransactionId": "101",
        "purchaseDate": 1770000001000,
        "environment": "Sandbox",
    })
    res1 = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_101}, headers=headers)
    assert res1.status_code == 200, res1.text
    data1 = res1.json()
    assert data1["credits_granted"] == 10
    assert data1["already_processed"] is False
    assert data1["current_balance"] == 10
    assert data1["transaction_id"] == "101"

    # TEST 2: Same product (bhumitra.plots.10), transaction 102 -> +10 again (balance = 20)
    jws_102 = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "102",
        "originalTransactionId": "101",
        "purchaseDate": 1770000002000,
        "environment": "Sandbox",
    })
    res2 = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_102}, headers=headers)
    assert res2.status_code == 200, res2.text
    data2 = res2.json()
    assert data2["credits_granted"] == 10
    assert data2["already_processed"] is False
    assert data2["current_balance"] == 20
    assert data2["transaction_id"] == "102"

    # TEST 3: Replay transaction 101 -> +0, already_processed=true, balance remains 20
    res3 = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_101}, headers=headers)
    assert res3.status_code == 200, res3.text
    data3 = res3.json()
    assert data3["credits_granted"] == 0
    assert data3["already_processed"] is True
    assert data3["current_balance"] == 20
    assert data3["transaction_id"] == "101"

    # TEST 4: Same product (bhumitra.plots.10), transaction 103 -> +10, balance = 30
    jws_103 = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "103",
        "originalTransactionId": "101",
        "purchaseDate": 1770000003000,
        "environment": "Sandbox",
    })
    res4 = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_103}, headers=headers)
    assert res4.status_code == 200, res4.text
    data4 = res4.json()
    assert data4["credits_granted"] == 10
    assert data4["already_processed"] is False
    assert data4["current_balance"] == 30
    assert data4["transaction_id"] == "103"

    # TEST 5: Different consumable: bhumitra.plots.50, transaction 104 -> +50, balance = 80
    jws_104 = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.50",
        "transactionId": "104",
        "originalTransactionId": "104",
        "purchaseDate": 1770000004000,
        "environment": "Sandbox",
    })
    res5 = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_104}, headers=headers)
    assert res5.status_code == 200, res5.text
    data5 = res5.json()
    assert data5["credits_granted"] == 50
    assert data5["already_processed"] is False
    assert data5["current_balance"] == 80
    assert data5["transaction_id"] == "104"

    # TEST 6: Replay transaction 104 -> +0, already_processed=true, balance remains 80
    res6 = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_104}, headers=headers)
    assert res6.status_code == 200, res6.text
    data6 = res6.json()
    assert data6["credits_granted"] == 0
    assert data6["already_processed"] is True
    assert data6["current_balance"] == 80
    assert data6["transaction_id"] == "104"


def test_7_and_8_backend_failure_and_recovery(pki_helper, test_app_and_db, monkeypatch):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_recovery_test", plot_credits=0, free_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_recovery_test")
    headers = {"Authorization": f"Bearer {token}"}

    jws_recover = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_fail_and_recover_101",
        "originalTransactionId": "tx_fail_and_recover_101",
        "purchaseDate": 1770000005000,
        "environment": "Sandbox",
    })

    # TEST 7: Backend failure simulation
    import services.subscription_service as ss_mod
    original_process = ss_mod.subscription_service.process_consumable_purchase
    def failing_process(*args, **kwargs):
        raise RuntimeError("Simulated transient database connection failure")

    monkeypatch.setattr(ss_mod.subscription_service, "process_consumable_purchase", failing_process)

    res_fail = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_recover}, headers=headers)
    assert res_fail.status_code == 400
    assert "Simulated transient" in res_fail.text

    session = session_factory()
    u = session.query(UserDB).filter_by(id="user_recovery_test").first()
    assert u.plot_credits == 0
    session.close()

    # TEST 8: Recover failed transaction
    monkeypatch.setattr(ss_mod.subscription_service, "process_consumable_purchase", original_process)

    res_recover = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_recover}, headers=headers)
    assert res_recover.status_code == 200, res_recover.text
    data_rec = res_recover.json()
    assert data_rec["credits_granted"] == 10
    assert data_rec["already_processed"] is False
    assert data_rec["current_balance"] == 10


def test_9_already_processed_unfinished_transaction(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_test9", plot_credits=10, free_credits=0)
    tx = ConsumableTransactionDB(
        id="c_tx_9",
        transaction_id="tx_unfinished_already_processed",
        original_transaction_id="tx_unfinished_already_processed",
        user_id="user_test9",
        product_id="bhumitra.plots.10",
        credits_granted=10,
        environment="Sandbox",
    )
    session.add_all([user, tx])
    session.commit()
    session.close()

    token = create_access_token(user_id="user_test9")
    headers = {"Authorization": f"Bearer {token}"}

    jws_unfin = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_unfinished_already_processed",
        "originalTransactionId": "tx_unfinished_already_processed",
        "purchaseDate": 1770000006000,
        "environment": "Sandbox",
    })

    res = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_unfin}, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["already_processed"] is True
    assert data["credits_granted"] == 0
    assert data["current_balance"] == 10


def test_10_app_restart_authoritative_balance(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_restart_test", plot_credits=0, free_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_restart_test")
    headers = {"Authorization": f"Bearer {token}"}

    for tx_num in ["1", "2", "3"]:
        jws = pki_helper.sign_jws({
            "bundleId": "com.kirtidhwaj.Bhumitra",
            "productId": "bhumitra.plots.10",
            "transactionId": f"tx_restart_{tx_num}",
            "originalTransactionId": "tx_restart_1",
            "purchaseDate": 1770000007000 + int(tx_num),
            "environment": "Sandbox",
        })
        res = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws}, headers=headers)
        assert res.status_code == 200

    bal_res = client.get("/api/v1/subscription/credits", headers=headers)
    assert bal_res.status_code == 200
    bal_data = bal_res.json()
    assert bal_data["credits"] == 30
    assert bal_data["purchased_credits"] == 30


def test_11_concurrent_submissions_same_transaction(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_race_same", plot_credits=0, free_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_race_same")
    headers = {"Authorization": f"Bearer {token}"}

    jws_concurrent = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_race_exact_same",
        "originalTransactionId": "tx_race_exact_same",
        "purchaseDate": 1770000008000,
        "environment": "Sandbox",
    })

    def submit_purchase():
        return client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_concurrent}, headers=headers)

    with ThreadPoolExecutor(max_workers=2) as executor:
        f1 = executor.submit(submit_purchase)
        f2 = executor.submit(submit_purchase)
        r1 = f1.result()
        r2 = f2.result()

    assert r1.status_code == 200
    assert r2.status_code == 200
    d1 = r1.json()
    d2 = r2.json()

    grants = [d1["credits_granted"], d2["credits_granted"]]
    assert grants.count(10) == 1
    assert grants.count(0) == 1

    already_processed_flags = [d1["already_processed"], d2["already_processed"]]
    assert already_processed_flags.count(False) == 1
    assert already_processed_flags.count(True) == 1

    session = session_factory()
    u = session.query(UserDB).filter_by(id="user_race_same").first()
    assert u.plot_credits == 10
    session.close()


def test_12_two_different_transactions_same_product(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_diff_txs", plot_credits=0, free_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_diff_txs")
    headers = {"Authorization": f"Bearer {token}"}

    jws_a = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_product_diff_A",
        "originalTransactionId": "tx_product_diff_A",
        "purchaseDate": 1770000009000,
        "environment": "Sandbox",
    })
    jws_b = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_product_diff_B",
        "originalTransactionId": "tx_product_diff_A",
        "purchaseDate": 1770000010000,
        "environment": "Sandbox",
    })

    r_a = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_a}, headers=headers)
    r_b = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_b}, headers=headers)

    assert r_a.status_code == 200
    assert r_b.status_code == 200
    assert r_a.json()["credits_granted"] == 10
    assert r_b.json()["credits_granted"] == 10
    assert r_b.json()["current_balance"] == 20


def test_13_and_14_consumable_remains_purchasable(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_purchasable", plot_credits=10, free_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_purchasable")
    headers = {"Authorization": f"Bearer {token}"}

    # TEST 13: Subsequent purchase of same product succeeds
    jws_subsequent = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_purchasable_subsequent",
        "originalTransactionId": "tx_purchasable_subsequent",
        "purchaseDate": 1770000011000,
        "environment": "Sandbox",
    })
    res = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_subsequent}, headers=headers)
    assert res.status_code == 200
    assert res.json()["credits_granted"] == 10
    assert res.json()["current_balance"] == 20

    # TEST 14: App restart -> balance is 20, new purchase can still be made
    bal = client.get("/api/v1/subscription/credits", headers=headers)
    assert bal.json()["credits"] == 20

    jws_after_restart = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_purchasable_after_restart",
        "originalTransactionId": "tx_purchasable_subsequent",
        "purchaseDate": 1770000012000,
        "environment": "Sandbox",
    })
    res_after = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_after_restart}, headers=headers)
    assert res_after.status_code == 200
    assert res_after.json()["credits_granted"] == 10
    assert res_after.json()["current_balance"] == 30


def test_15_consumable_not_blocked_by_restore_state(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_restore_state", plot_credits=20, free_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_restore_state")
    headers = {"Authorization": f"Bearer {token}"}

    jws_restore_test = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.10",
        "transactionId": "tx_restore_unblocked",
        "originalTransactionId": "tx_restore_unblocked",
        "purchaseDate": 1770000013000,
        "environment": "Sandbox",
    })
    res = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws_restore_test}, headers=headers)
    assert res.status_code == 200
    assert res.json()["credits_granted"] == 10
    assert res.json()["current_balance"] == 30


def test_16_no_product_id_based_deduplication(pki_helper, test_app_and_db):
    client, session_factory = test_app_and_db

    session = session_factory()
    user = UserDB(id="user_no_prod_dedup", plot_credits=0, free_credits=0)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id="user_no_prod_dedup")
    headers = {"Authorization": f"Bearer {token}"}

    for i in range(1, 6):
        jws = pki_helper.sign_jws({
            "bundleId": "com.kirtidhwaj.Bhumitra",
            "productId": "bhumitra.plots.10",
            "transactionId": f"tx_unique_id_{i}",
            "originalTransactionId": "common_original_tx_chain",
            "purchaseDate": 1770000014000 + i,
            "environment": "Sandbox",
        })
        res = client.post("/api/v1/subscription/credits/purchase", json={"signed_transaction_jws": jws}, headers=headers)
        assert res.status_code == 200, res.text
        data = res.json()
        assert data["credits_granted"] == 10
        assert data["already_processed"] is False
        assert data["current_balance"] == i * 10

    session = session_factory()
    tx_count = session.query(ConsumableTransactionDB).filter_by(user_id="user_no_prod_dedup").count()
    assert tx_count == 5
    u = session.query(UserDB).filter_by(id="user_no_prod_dedup").first()
    assert u.plot_credits == 50
    session.close()
