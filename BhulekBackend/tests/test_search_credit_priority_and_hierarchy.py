"""
Comprehensive Test Suite for Search Credit Priority & Hierarchy
Tests exact business rules:
1. Unlimited Subscriber Priority (Bypasses all quotas and credit pools)
2. Free Monthly Quota Priority (Deducts free quota first while available, never touches purchased credits)
3. Purchased Plot Credits Priority (Deducts purchased credits only when free quota is exhausted)
4. Full Exhaustion Gating (Returns HTTP 403 when both free quota and purchased credits are 0)
5. Success-Only Charging (No deductions on upstream 404, 500, 502, 503, 504 timeouts)
6. Concurrency & Atomicity (Thread-safe atomic conditional SQL updates, zero negative balance risk)
7. Customer Journey (0/0 -> Blocked -> Purchase 50 pack -> 49 -> 48)
"""

import os
import pytest
from datetime import datetime, timezone, timedelta
from concurrent.futures import ThreadPoolExecutor
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import create_app
from db.base import Base
from db.session import get_db
from models.db_models import UserDB, SubscriptionDB, UserUsageDB, ConsumableTransactionDB
from core.security import create_access_token
from services.usage_service import usage_service
from tests.test_apple_verification import PKITestHelper, AppleVerificationService


@pytest.fixture
def pki_helper():
    return PKITestHelper()


@pytest.fixture
def test_env(pki_helper, tmp_path, monkeypatch):
    db_file = tmp_path / "test_credit_hierarchy.db"
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

    certs_dir = str(tmp_path / "certs")
    os.makedirs(certs_dir, exist_ok=True)
    with open(os.path.join(certs_dir, "test_root.cer"), "wb") as f:
        f.write(pki_helper.root_der)

    verifier = AppleVerificationService(certs_dir=certs_dir)

    import db.session as session_mod
    import services.usage_service as us_mod
    import services.subscription_service as ss_mod
    import routers.ror as ror_mod

    monkeypatch.setattr(session_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "SessionLocal", TestingSessionLocal)
    monkeypatch.setattr(us_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(ss_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(ss_mod, "apple_verification_service", verifier)

    # Scraper mock controller
    mock_state = {"mode": "success"}

    async def mock_get_ror(*args, **kwargs):
        mode = mock_state.get("mode", "success")
        if mode == "success":
            return {
                "success": True,
                "district": "KEONJHAR",
                "tahasil": "SADAR",
                "village": "KERI",
                "plot": "1182",
                "khata_number": "142",
                "owners": [{"name": "Purna Chandra Mohanta"}],
                "area": "0.15",
                "land_type": "Gharabari",
                "verification": {"status": "VERIFIED"}
            }
        elif mode == "not_found":
            from services.ror_service import RoRServiceException
            from models.ror_response import RoRErrorCode
            raise RoRServiceException(RoRErrorCode.ROR_NOT_FOUND, "No official record found")
        elif mode == "timeout":
            from services.ror_service import RoRServiceException
            from models.ror_response import RoRErrorCode
            raise RoRServiceException(RoRErrorCode.BHULEKH_TIMEOUT, "Government portal timeout")
        elif mode == "server_error":
            from services.ror_service import RoRServiceException
            from models.ror_response import RoRErrorCode
            raise RoRServiceException(RoRErrorCode.BHULEKH_TEMPORARY_UNAVAILABLE, "Government portal unavailable")

    monkeypatch.setattr(ror_mod.ror_service, "get_ror", mock_get_ror)

    # Free limit = 10 for standard tests
    monkeypatch.setattr(usage_service, "free_ror_limit", 10)

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    return client, TestingSessionLocal, mock_state


# ==============================================================================
# TESTS
# ==============================================================================

def test_1_new_user_consumes_free_quota_first(test_env):
    """1. New user (10 free / 0 purchased): first search succeeds -> 9 free / 0 purchased."""
    client, session_factory, _ = test_env
    user_id = "user_hierarchy_1"

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=0))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200

    session = session_factory()
    usage = session.query(UserUsageDB).filter_by(user_id=user_id).first()
    user = session.query(UserDB).filter_by(id=user_id).first()

    assert usage.ror_lookup_count == 1  # 1 used out of 10 -> 9 remaining
    assert user.plot_credits == 0
    session.close()


def test_2_partially_available_free_quota_preserves_purchased_credits(test_env):
    """2. User with 5 free remaining / 50 purchased: search consumes free quota, purchased stays at 50."""
    client, session_factory, _ = test_env
    user_id = "user_hierarchy_2"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=50))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=5))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200

    session = session_factory()
    usage = session.query(UserUsageDB).filter_by(user_id=user_id).first()
    user = session.query(UserDB).filter_by(id=user_id).first()

    assert usage.ror_lookup_count == 6  # 5 -> 6 (4 remaining)
    assert user.plot_credits == 50     # UNTOUCHED!
    session.close()


def test_3_exhausted_free_quota_consumes_purchased_credits(test_env):
    """3. Free quota exhausted (0 free / 50 purchased): search succeeds -> 0 free / 49 purchased."""
    client, session_factory, _ = test_env
    user_id = "user_hierarchy_3"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=50))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200

    session = session_factory()
    usage = session.query(UserUsageDB).filter_by(user_id=user_id).first()
    user = session.query(UserDB).filter_by(id=user_id).first()

    assert usage.ror_lookup_count == 10  # Stays at 10 (not incremented further)
    assert user.plot_credits == 49       # 50 -> 49!
    session.close()


def test_4_both_exhausted_returns_403_and_leaves_balances_unchanged(test_env):
    """4. Both exhausted (0 free / 0 purchased): returns 403 Forbidden, balances unchanged."""
    client, session_factory, _ = test_env
    user_id = "user_hierarchy_4"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=0))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 403
    assert res.json()["detail"]["code"] == "USAGE_LIMIT_EXCEEDED"
    assert res.json()["detail"]["upgrade_required"] is True

    session = session_factory()
    usage = session.query(UserUsageDB).filter_by(user_id=user_id).first()
    user = session.query(UserDB).filter_by(id=user_id).first()

    assert usage.ror_lookup_count == 10
    assert user.plot_credits == 0
    session.close()


def test_5_free_quota_exhausted_plus_single_purchased_credit(test_env):
    """5. User has 0 free + 1 purchased credit: search succeeds and drops purchased balance to 0."""
    client, session_factory, _ = test_env
    user_id = "user_hierarchy_5"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=1))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200

    session = session_factory()
    user = session.query(UserDB).filter_by(id=user_id).first()
    assert user.plot_credits == 0
    session.close()

    # Next search must now be blocked
    res2 = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res2.status_code == 403


def test_6_multiple_successful_searches_with_purchased_credits(test_env):
    """6. User has 0 free + 5 purchased credits: 3 searches succeed and reduce balance to 2."""
    client, session_factory, _ = test_env
    user_id = "user_hierarchy_6"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=5))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    for _ in range(3):
        res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
        assert res.status_code == 200

    session = session_factory()
    user = session.query(UserDB).filter_by(id=user_id).first()
    assert user.plot_credits == 2
    session.close()


def test_7_upstream_timeout_does_not_consume_purchased_credits(test_env):
    """7. Upstream timeout (504): returns 504 and does NOT consume purchased credits."""
    client, session_factory, mock_state = test_env
    user_id = "user_hierarchy_7"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=10))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    mock_state["mode"] = "timeout"

    res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 504

    session = session_factory()
    user = session.query(UserDB).filter_by(id=user_id).first()
    assert user.plot_credits == 10  # UNTOUCHED!
    session.close()


def test_8_upstream_404_does_not_consume_purchased_credits(test_env):
    """8. Upstream 404 Not Found: returns 404 and does NOT consume purchased credits."""
    client, session_factory, mock_state = test_env
    user_id = "user_hierarchy_8"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=10))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    mock_state["mode"] = "not_found"

    res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=9999", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 404

    session = session_factory()
    user = session.query(UserDB).filter_by(id=user_id).first()
    assert user.plot_credits == 10  # UNTOUCHED!
    session.close()


def test_9_upstream_portal_unavailable_does_not_consume_purchased_credits(test_env):
    """9. Upstream 503 Service Unavailable: returns 503 and does NOT consume purchased credits."""
    client, session_factory, mock_state = test_env
    user_id = "user_hierarchy_9"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=10))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    mock_state["mode"] = "server_error"

    res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 503

    session = session_factory()
    user = session.query(UserDB).filter_by(id=user_id).first()
    assert user.plot_credits == 10
    session.close()


def test_10_unlimited_subscriber_bypasses_all_deductions(test_env):
    """10. Unlimited subscriber with purchased credits: search succeeds, credits and quota untouched."""
    client, session_factory, _ = test_env
    user_id = "user_hierarchy_10"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=20))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=3))
    session.add(SubscriptionDB(
        user_id=user_id,
        product_id="bhumitra.unlimited.monthly",
        original_transaction_id="tx_unlimited_hierarchy_01",
        status="active",
        expires_at=datetime.now(timezone.utc) + timedelta(days=30),
    ))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    for _ in range(5):
        res = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
        assert res.status_code == 200

    session = session_factory()
    usage = session.query(UserUsageDB).filter_by(user_id=user_id).first()
    user = session.query(UserDB).filter_by(id=user_id).first()

    assert usage.ror_lookup_count == 3  # UNTOUCHED
    assert user.plot_credits == 20       # UNTOUCHED
    session.close()


def test_11_expired_subscription_falls_back_to_credit_hierarchy(test_env):
    """11. Expired subscription: falls back to free/purchased hierarchy correctly."""
    client, session_factory, _ = test_env
    user_id = "user_hierarchy_11"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=2))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.add(SubscriptionDB(
        user_id=user_id,
        product_id="bhumitra.unlimited.monthly",
        original_transaction_id="tx_expired_hierarchy_01",
        status="expired",
        expires_at=datetime.now(timezone.utc) - timedelta(days=1),
    ))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)

    # 1st search consumes 1 purchased credit -> 1 remaining
    res1 = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res1.status_code == 200

    # 2nd search consumes 1 purchased credit -> 0 remaining
    res2 = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res2.status_code == 200

    # 3rd search blocked with 403
    res3 = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert res3.status_code == 403


def test_12_concurrent_single_purchased_credit_safety(test_env):
    """12. Concurrency: exactly 1 purchased credit available + 10 simultaneous searches -> exactly 1 succeeds."""
    client, session_factory, _ = test_env
    user_id = "user_concurrent_1"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=1))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)

    def do_search():
        return client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(do_search) for _ in range(10)]
        responses = [f.result() for f in futures]

    status_codes = [r.status_code for r in responses]
    assert status_codes.count(200) == 1
    assert status_codes.count(403) == 9

    session = session_factory()
    user = session.query(UserDB).filter_by(id=user_id).first()
    assert user.plot_credits == 0
    session.close()


def test_13_mixed_concurrency_5_credits_20_requests(test_env):
    """13. Mixed concurrency: 0 free / 5 purchased credits + 20 simultaneous searches -> exactly 5 succeed, 15 blocked."""
    client, session_factory, _ = test_env
    user_id = "user_concurrent_5"
    period = usage_service.get_current_period()

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=5))
    session.add(UserUsageDB(user_id=user_id, period=period, ror_lookup_count=10))
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)

    def do_search():
        return client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(do_search) for _ in range(20)]
        responses = [f.result() for f in futures]

    status_codes = [r.status_code for r in responses]
    assert status_codes.count(200) == 5
    assert status_codes.count(403) == 15

    session = session_factory()
    user = session.query(UserDB).filter_by(id=user_id).first()
    assert user.plot_credits == 0
    session.close()


def test_14_complete_customer_journey_purchase_to_search(pki_helper, test_env):
    """
    14. Customer Journey Test:
    1. User starts with 0 purchased credits and exhausts 10 free searches.
    2. User attempts 11th search -> blocked (403).
    3. User purchases the 50-credit pack -> backend records +50 credits.
    4. User performs search -> succeeds -> balance = 49.
    5. User performs another search -> succeeds -> balance = 48.
    """
    client, session_factory, _ = test_env
    user_id = "user_journey_cust"
    token = create_access_token(user_id=user_id, app_account_token="TOKEN-JOURNEY")

    session = session_factory()
    session.add(UserDB(id=user_id, plot_credits=0, app_account_token="TOKEN-JOURNEY"))
    session.commit()
    session.close()

    # Step 1: Perform 10 free searches
    for i in range(10):
        r = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200, f"Search {i+1} failed"

    # Step 2: 11th search blocked
    r11 = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert r11.status_code == 403

    # Step 3: Purchase 50 plot credits pack
    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.plots.50",
        "transactionId": "tx_journey_50_pack",
        "originalTransactionId": "tx_journey_50_pack",
        "purchaseDate": 1770000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-JOURNEY",
    })

    r_buy = client.post(
        "/api/v1/subscription/credits/purchase",
        headers={"Authorization": f"Bearer {token}"},
        json={"signed_transaction_jws": tx_jws},
    )
    assert r_buy.status_code == 200
    assert r_buy.json()["current_balance"] == 50

    # Step 4: Perform search with purchased credits
    r_search1 = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert r_search1.status_code == 200

    r_bal1 = client.get("/api/v1/subscription/credits", headers={"Authorization": f"Bearer {token}"})
    assert r_bal1.status_code == 200
    assert r_bal1.json()["credits"] == 49

    # Step 5: Perform second search
    r_search2 = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers={"Authorization": f"Bearer {token}"})
    assert r_search2.status_code == 200

    r_bal2 = client.get("/api/v1/subscription/credits", headers={"Authorization": f"Bearer {token}"})
    assert r_bal2.status_code == 200
    assert r_bal2.json()["credits"] == 48
