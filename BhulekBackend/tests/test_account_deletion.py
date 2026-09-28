"""
Account Deletion Test Suite (App Store Guideline 5.1.1(v))
Verifies DELETE /api/v1/auth/me:
- Requires authentication (401 without Bearer token)
- Deletes UserDB and cascades auth identities
- Preserves DevicePromotionDB record with first_claimed_user_id set to None to prevent re-grant abuse
- Informs user if they have an active subscription that needs cancellation via Apple ID Settings
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import create_app
from db.base import Base
from db.session import get_db
from models.db_models import UserDB, AuthIdentityDB, DevicePromotionDB, SubscriptionDB
from core.security import create_access_token


@pytest.fixture
def test_db_and_client(tmp_path, monkeypatch):
    db_file = tmp_path / "test_account_deletion.db"
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

    import db.session as session_mod
    monkeypatch.setattr(session_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "SessionLocal", TestingSessionLocal)

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db

    client = TestClient(app)
    return client, TestingSessionLocal


def test_delete_account_unauthorized(test_db_and_client):
    client, _ = test_db_and_client
    response = client.delete("/api/v1/auth/me")
    assert response.status_code == 401


def test_delete_account_success(test_db_and_client):
    client, session_factory = test_db_and_client

    # 1. Create a user with identities and a device promotion
    user_id = "user_del_test_123"
    device_id = "device_test_xyz"
    token = create_access_token(user_id=user_id)

    with session_factory() as db:
        user = UserDB(
            id=user_id,
            email="delete_me@example.com",
            name="Delete Tester",
            free_credits=5,
            plot_credits=10,
            promotional_grant_claimed=True,
        )
        db.add(user)
        db.flush()

        identity = AuthIdentityDB(
            user_id=user_id,
            provider="apple",
            provider_subject="apple_sub_del_123",
            provider_email="delete_me@example.com",
        )
        db.add(identity)

        dev_promo = DevicePromotionDB(
            device_id=device_id,
            first_claimed_user_id=user_id,
        )
        db.add(dev_promo)
        db.commit()

    # 2. Call DELETE /api/v1/auth/me
    headers = {"Authorization": f"Bearer {token}"}
    response = client.delete("/api/v1/auth/me", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["deleted_user_id"] == user_id
    assert data["has_active_subscription"] is False
    assert data["apple_subscription_notice"] is None

    # 3. Verify user and identities are deleted from DB
    with session_factory() as db:
        deleted_user = db.query(UserDB).filter(UserDB.id == user_id).first()
        assert deleted_user is None

        identities = db.query(AuthIdentityDB).filter(AuthIdentityDB.user_id == user_id).all()
        assert len(identities) == 0

        # Device promotion record must still exist with first_claimed_user_id = None
        promo = db.query(DevicePromotionDB).filter(DevicePromotionDB.device_id == device_id).first()
        assert promo is not None
        assert promo.first_claimed_user_id is None


def test_delete_account_with_active_subscription(test_db_and_client):
    client, session_factory = test_db_and_client

    user_id = "user_del_sub_456"
    token = create_access_token(user_id=user_id)

    with session_factory() as db:
        user = UserDB(
            id=user_id,
            email="sub_user@example.com",
            name="Sub Tester",
        )
        db.add(user)
        db.flush()

        sub = SubscriptionDB(
            id="sub_test_123",
            user_id=user_id,
            product_id="bhumitra.unlimited.monthly",
            original_transaction_id="orig_tx_123",
            status="active",
        )
        db.add(sub)
        db.commit()

    headers = {"Authorization": f"Bearer {token}"}
    response = client.delete("/api/v1/auth/me", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["has_active_subscription"] is True
    assert data["apple_subscription_notice"] is not None
    assert "iOS Settings > Apple ID > Subscriptions" in data["apple_subscription_notice"]
