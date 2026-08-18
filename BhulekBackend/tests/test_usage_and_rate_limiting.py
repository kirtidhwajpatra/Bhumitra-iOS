"""
Usage Enforcement & Rate Limiting Test Suite
Tests server-side atomic usage quotas, concurrency safety, billing period resets,
tier-based rate limiting, and free-to-premium entitlement enforcement.
"""

import os
import datetime
import threading
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import create_app
from db.base import Base
from db.session import get_db
from models.db_models import UserDB, SubscriptionDB, UserUsageDB
from core.security import create_access_token
from services.usage_service import usage_service
from core.rate_limiter import limiter


@pytest.fixture
def test_env(tmp_path, monkeypatch):
    # Setup test database
    db_file = tmp_path / "test_usage_suite.db"
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

    # Monkeypatch
    import db.session as session_mod
    import services.usage_service as us_mod
    import routers.ror as ror_mod

    monkeypatch.setattr(session_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "SessionLocal", TestingSessionLocal)
    monkeypatch.setattr(us_mod, "get_db_session", test_get_db_session)

    # Mock RoRService to return dummy data without hitting external portal
    async def mock_get_ror(*args, **kwargs):
        return {"district": "TEST", "tahasil": "TEST", "village": "TEST", "plot": "100", "owners": [{"name": "Test Owner"}]}

    async def mock_get_ror_pdf(*args, **kwargs):
        return b"%PDF-1.4 Mock PDF Content"

    monkeypatch.setattr(ror_mod.ror_service, "get_ror", mock_get_ror)
    monkeypatch.setattr(ror_mod.ror_service, "get_ror_pdf", mock_get_ror_pdf)

    # Set limits for test
    monkeypatch.setattr(usage_service, "free_ror_limit", 5)
    monkeypatch.setattr(usage_service, "free_pdf_limit", 1)

    # Clear rate limiter state
    limiter._requests.clear()

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    return client, TestingSessionLocal


# ==============================================================================
# TESTS
# ==============================================================================

def test_1_free_user_quota_increments_and_blocks_at_limit(test_env):
    """1. Free user allowed up to 5 lookups, 6th lookup blocked with 403 and upgrade_required."""
    client, session_factory = test_env
    user_id = "free_user_quota_1"

    # Create user
    session = session_factory()
    user = UserDB(id=user_id)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    headers = {"Authorization": f"Bearer {token}"}

    # First 5 lookups succeed
    for i in range(1, 6):
        res = client.get(
            "/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182",
            headers=headers,
        )
        assert res.status_code == 200, f"Lookup {i} failed"

    # Verify DB usage count
    session = session_factory()
    usage = session.query(UserUsageDB).filter(UserUsageDB.user_id == user_id).first()
    assert usage is not None
    assert usage.ror_lookup_count == 5
    session.close()

    # 6th lookup must be rejected with 403
    res6 = client.get(
        "/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182",
        headers=headers,
    )
    assert res6.status_code == 403
    data = res6.json()["detail"]
    assert data["error"] == "usage_limit_exceeded"
    assert data["current_usage"] == 5
    assert data["limit"] == 5
    assert data["upgrade_required"] is True


def test_2_premium_user_bypasses_usage_limits(test_env):
    """2. Premium user can perform more than 5 lookups without being capped."""
    client, session_factory = test_env
    user_id = "premium_user_active_1"

    session = session_factory()
    user = UserDB(id=user_id)
    sub = SubscriptionDB(
        user_id=user_id,
        product_id="bhumitra_premium_monthly",
        original_transaction_id="premium_tx_001",
        status="active",
        expires_at=datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=30),
    )
    session.add_all([user, sub])
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    headers = {"Authorization": f"Bearer {token}"}

    # Perform 8 lookups
    for i in range(8):
        res = client.get(
            "/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182",
            headers=headers,
        )
        assert res.status_code == 200


def test_3_expired_premium_user_blocked_once_free_quota_reached(test_env):
    """3. Expired premium user falls back to free tier rules and gets capped at 5."""
    client, session_factory = test_env
    user_id = "expired_user_001"

    session = session_factory()
    user = UserDB(id=user_id)
    sub = SubscriptionDB(
        user_id=user_id,
        product_id="bhumitra_premium_monthly",
        original_transaction_id="expired_tx_001",
        status="expired",
        expires_at=datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1),
    )
    session.add_all([user, sub])
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    headers = {"Authorization": f"Bearer {token}"}

    for i in range(5):
        res = client.get(
            "/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182",
            headers=headers,
        )
        assert res.status_code == 200

    res_overflow = client.get(
        "/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182",
        headers=headers,
    )
    assert res_overflow.status_code == 403


def test_4_pdf_quota_enforcement(test_env):
    """4. Free user can download 1 PDF; second attempt returns 403."""
    client, session_factory = test_env
    user_id = "pdf_free_user"

    session = session_factory()
    user = UserDB(id=user_id)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    headers = {"Authorization": f"Bearer {token}"}

    # 1st PDF download allowed
    res1 = client.get(
        "/api/v1/ror/pdf?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182",
        headers=headers,
    )
    assert res1.status_code == 200

    # 2nd PDF download rejected
    res2 = client.get(
        "/api/v1/ror/pdf?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182",
        headers=headers,
    )
    assert res2.status_code == 403
    assert res2.json()["detail"]["limit_type"] == "pdf_download"


def test_5_billing_period_reset(test_env, monkeypatch):
    """5. When the billing period changes, the user receives a fresh quota of 5 lookups."""
    client, session_factory = test_env
    user_id = "period_reset_user"

    session = session_factory()
    user = UserDB(id=user_id)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    headers = {"Authorization": f"Bearer {token}"}

    # In period 2026-07, user used 5 lookups
    monkeypatch.setattr(usage_service, "get_current_period", lambda: "2026-07")
    for _ in range(5):
        client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers=headers)

    res_blocked_july = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers=headers)
    assert res_blocked_july.status_code == 403

    # Fast forward to 2026-08
    monkeypatch.setattr(usage_service, "get_current_period", lambda: "2026-08")
    res_allowed_august = client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers=headers)
    assert res_allowed_august.status_code == 200


def test_6_rate_limiter_triggers_429(test_env):
    """6. Exceeding endpoint rate limit triggers HTTP 429 Too Many Requests."""
    client, session_factory = test_env
    user_id = "rate_limited_user"

    session = session_factory()
    user = UserDB(id=user_id)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    headers = {"Authorization": f"Bearer {token}"}

    # Fill up rate limit threshold for PDF (max 10)
    for _ in range(10):
        limiter.is_allowed(key=f"ror_pdf:{user_id}", max_requests=10, window_seconds=60)

    res = client.get(
        "/api/v1/ror/pdf?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182",
        headers=headers,
    )
    assert res.status_code == 429
    assert "Retry-After" in res.headers


def test_7_get_usage_status_endpoint(test_env):
    """7. GET /api/v1/usage/status accurately returns current usage breakdown."""
    client, session_factory = test_env
    user_id = "summary_user_01"

    session = session_factory()
    user = UserDB(id=user_id)
    session.add(user)
    session.commit()
    session.close()

    token = create_access_token(user_id=user_id)
    headers = {"Authorization": f"Bearer {token}"}

    # Perform 2 RoR lookups
    client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers=headers)
    client.get("/api/v1/ror?district=KEONJHAR&tahasil=SADAR&village=KERI&plot=1182", headers=headers)

    res = client.get("/api/v1/usage/status", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["user_id"] == user_id
    assert data["is_premium"] is False
    assert data["ror_lookups"]["used"] == 2
    assert data["ror_lookups"]["limit"] == 5
    assert data["ror_lookups"]["remaining"] == 3
    assert data["pdf_downloads"]["used"] == 0
    assert data["pdf_downloads"]["remaining"] == 1


def test_8_concurrent_requests_atomic_safety(test_env):
    """8. 10 Concurrent simultaneous requests against limit=5 allows exactly 5 and rejects 5."""
    from concurrent.futures import ThreadPoolExecutor
    client, session_factory = test_env
    user_id = "concurrent_race_user"

    session = session_factory()
    user = UserDB(id=user_id)
    session.add(user)
    session.commit()
    session.close()

    results = []

    def perform_quota_check():
        try:
            res = usage_service.check_and_increment_ror_quota(user_id)
            return ("SUCCESS", res)
        except Exception as e:
            return ("REJECTED", str(e))

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(perform_quota_check) for _ in range(10)]
        for f in futures:
            results.append(f.result())

    successes = [r for r in results if r[0] == "SUCCESS"]
    rejections = [r for r in results if r[0] == "REJECTED"]

    assert len(successes) == 5, f"Expected 5 successes, got {len(successes)}. Rejections: {rejections}"
    assert len(rejections) == 5, f"Expected 5 rejections, got {len(rejections)}"
