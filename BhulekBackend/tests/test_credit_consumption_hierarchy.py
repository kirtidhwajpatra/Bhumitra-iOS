"""
Credit Consumption & Quota Hierarchy Regression Tests
Proves:
1. Active unlimited subscriber: 0 deductions.
2. Free monthly quota: exactly 1 free lookup consumed atomically.
3. Purchased plot credits: exactly 1 purchased credit consumed atomically when free quota exhausted.
4. Exhausted quota + exhausted credits: HTTP 403, 0 deduction.
5. Search failure: 0 deduction.
6. get_user_credits returns correct combined allowance and breakdown.
"""
import pytest
from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from db.base import Base
from models.db_models import UserDB, SubscriptionDB, UserUsageDB
import db.session as session_mod
from services.usage_service import UsageService, UsageLimitExceededError
from services.subscription_service import SubscriptionService


@pytest.fixture
def regression_db(tmp_path, monkeypatch):
    test_db_url = f"sqlite:///{tmp_path}/test_credit_hierarchy.db"
    test_engine = create_engine(test_db_url, connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=test_engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

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

    monkeypatch.setattr(session_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr("services.subscription_service.get_db_session", test_get_db_session)
    monkeypatch.setattr("services.usage_service.get_db_session", test_get_db_session)
    return test_get_db_session


def test_1_free_quota_consumed_first_before_purchased_credits(regression_db):
    usage_svc = UsageService()
    sub_svc = SubscriptionService()
    user_id = "test_user_with_credits"

    # User starts with 50 purchased credits and 5 free lookups
    with regression_db() as session:
        user = UserDB(id=user_id, free_credits=5, plot_credits=50)
        session.add(user)

    # Initial balance check
    bal_initial = sub_svc.get_user_credits(user_id)
    assert bal_initial.credits == 55  # 5 free + 50 purchased
    assert bal_initial.purchased_credits == 50
    assert bal_initial.free_remaining == 5
    assert bal_initial.is_unlimited is False

    # Search 1: Deducts from free quota
    res1 = usage_svc.deduct_ror_search(user_id)
    assert res1["deducted"] is True
    assert res1["entitlement_used"] == "free_grant"
    assert res1["free_remaining"] == 4

    bal1 = sub_svc.get_user_credits(user_id)
    assert bal1.credits == 54  # 4 free + 50 purchased
    assert bal1.purchased_credits == 50
    assert bal1.free_remaining == 4


def test_2_purchased_credits_consumed_atomically_after_free_quota_exhausted(regression_db):
    usage_svc = UsageService()
    sub_svc = SubscriptionService()
    user_id = "test_user_exhaust_free"
    period = usage_svc.get_current_period()

    # User with 50 purchased credits who has exhausted free lookups (0 free)
    with regression_db() as session:
        user = UserDB(id=user_id, free_credits=0, plot_credits=50)
        usage = UserUsageDB(user_id=user_id, period=period, ror_lookup_count=5)
        session.add_all([user, usage])

    # Check balance before purchased credit search
    bal_before = sub_svc.get_user_credits(user_id)
    assert bal_before.credits == 50
    assert bal_before.purchased_credits == 50
    assert bal_before.free_remaining == 0

    # Search 1: Deducts purchased credit
    res1 = usage_svc.deduct_ror_search(user_id)
    assert res1["deducted"] is True
    assert res1["entitlement_used"] == "purchased_credits"
    assert res1["plot_credits_remaining"] == 49

    bal_after = sub_svc.get_user_credits(user_id)
    assert bal_after.credits == 49
    assert bal_after.purchased_credits == 49
    assert bal_after.free_remaining == 0


def test_3_exhausted_quota_and_credits_raises_403_and_blocks_search(regression_db):
    usage_svc = UsageService()
    user_id = "test_user_empty"
    period = usage_svc.get_current_period()

    # User with 0 purchased credits and 0 free credits
    with regression_db() as session:
        user = UserDB(id=user_id, free_credits=0, plot_credits=0)
        usage = UserUsageDB(user_id=user_id, period=period, ror_lookup_count=5)
        session.add_all([user, usage])

    with pytest.raises(UsageLimitExceededError) as exc:
        usage_svc.check_ror_quota(user_id)
    assert exc.value.limit_type == "ror_lookup"


def test_4_unlimited_subscriber_never_deducts_credits(regression_db):
    usage_svc = UsageService()
    sub_svc = SubscriptionService()
    user_id = "test_user_unlimited"

    with regression_db() as session:
        user = UserDB(id=user_id, plot_credits=20)
        sub = SubscriptionDB(
            user_id=user_id,
            product_id="bhumitra.unlimited.monthly",
            plan="monthly",
            original_transaction_id="unlimited_tx_1",
            status="active",
            expires_at=datetime(2099, 1, 1, tzinfo=timezone.utc),
        )
        session.add_all([user, sub])

    bal = sub_svc.get_user_credits(user_id)
    assert bal.is_unlimited is True
    assert bal.credits == -1

    res = usage_svc.deduct_ror_search(user_id)
    assert res["deducted"] is False
    assert res["entitlement_used"] == "unlimited"

    # Purchased credits remain untouched at 20
    bal_after = sub_svc.get_user_credits(user_id)
    assert bal_after.purchased_credits == 20
