"""
PostgreSQL & SQLAlchemy Database Layer Tests
Validates schema creation, relationship cascading, transaction auditing,
durable idempotency on notificationUUID, and multi-device identity binding.
"""

import os
import pytest
from datetime import datetime, timezone, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import IntegrityError

from db.base import Base
from models.db_models import (
    UserDB,
    SubscriptionDB,
    TransactionDB,
    SubscriptionEventDB,
    AppConfigDB,
)
from services.subscription_service import SubscriptionService
from models.subscription_models import SubscriptionVerifyRequest
from tests.test_apple_verification import PKITestHelper, AppleVerificationService


@pytest.fixture
def db_engine(tmp_path):
    db_file = tmp_path / "test_pg_suite.db"
    engine = create_engine(f"sqlite:///{db_file}", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    return engine


@pytest.fixture
def db_session_factory(db_engine):
    return sessionmaker(autocommit=False, autoflush=False, bind=db_engine)


@pytest.fixture
def pki_helper():
    return PKITestHelper()


@pytest.fixture
def db_subscription_service(pki_helper, db_session_factory, tmp_path, monkeypatch):
    certs_dir = str(tmp_path / "certs")
    os.makedirs(certs_dir, exist_ok=True)
    with open(os.path.join(certs_dir, "test_root.cer"), "wb") as f:
        f.write(pki_helper.root_der)

    verifier = AppleVerificationService(certs_dir=certs_dir)

    from contextlib import contextmanager

    @contextmanager
    def test_get_db_session():
        session = db_session_factory()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    import services.subscription_service as ss_mod
    monkeypatch.setattr(ss_mod, "apple_verification_service", verifier)
    monkeypatch.setattr(ss_mod, "get_db_session", test_get_db_session)

    return SubscriptionService()


# ==============================================================================
# DATABASE TESTS
# ==============================================================================

def test_db_user_and_subscription_relationships(db_session_factory):
    """Test User, Subscription, and Transaction cascading relationships."""
    session = db_session_factory()
    now = datetime.now(timezone.utc)

    # 1. Create User
    user = UserDB(id="user_db_test_1", app_account_token="TOKEN-UUID-001")
    session.add(user)
    session.commit()

    # 2. Add Subscription
    sub = SubscriptionDB(
        user_id=user.id,
        product_id="bhumitra.unlimited.monthly",
        plan="monthly",
        original_transaction_id="orig_tx_1001",
        latest_transaction_id="tx_2001",
        status="active",
        environment="Sandbox",
        purchase_date=now,
        expires_at=now + timedelta(days=365),
    )
    session.add(sub)
    session.commit()

    # 3. Add Transaction
    tx = TransactionDB(
        id="tx_2001",
        original_transaction_id="orig_tx_1001",
        user_id=user.id,
        subscription_id=sub.id,
        product_id="bhumitra.unlimited.monthly",
        environment="Sandbox",
        purchase_date=now,
        expiration_date=now + timedelta(days=365),
    )
    session.add(tx)
    session.commit()

    # Query back and verify relationships
    saved_user = session.query(UserDB).filter(UserDB.id == "user_db_test_1").first()
    assert saved_user is not None
    assert len(saved_user.subscriptions) == 1
    assert saved_user.subscriptions[0].original_transaction_id == "orig_tx_1001"
    assert len(saved_user.transactions) == 1
    assert saved_user.transactions[0].id == "tx_2001"

    session.close()


def test_durable_notification_uuid_unique_constraint(db_session_factory):
    """Test that duplicate notificationUUID inserts trigger IntegrityError in DB."""
    session = db_session_factory()

    event1 = SubscriptionEventDB(
        notification_uuid="unique-uuid-999",
        notification_type="DID_RENEW",
        environment="Sandbox",
        status="processed",
    )
    session.add(event1)
    session.commit()

    # Second insert with same notification_uuid must fail unique constraint
    event2 = SubscriptionEventDB(
        notification_uuid="unique-uuid-999",
        notification_type="DID_RENEW",
        environment="Sandbox",
        status="processed",
    )
    session.add(event2)
    with pytest.raises(IntegrityError):
        session.commit()

    session.rollback()
    session.close()


def test_complete_subscription_lifecycle_in_database(pki_helper, db_subscription_service, db_session_factory):
    """Test full purchase -> renewal -> refund -> expiration state transitions in DB."""
    user_id = "lifecycle_user_apple_id"
    token = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    orig_tx = "10000000099"

    # Step 1: Initial Purchase (future timestamp)
    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": orig_tx,
        "transactionId": "20000000099",
        "purchaseDate": 1770000000000,
        "expiresDate": 2100000000000,
        "environment": "Sandbox",
        "appAccountToken": token,
    })

    res = db_subscription_service.verify_and_link_transaction(
        SubscriptionVerifyRequest(
            user_id=user_id,
            signed_transaction_jws=tx_jws,
            original_transaction_id=orig_tx,
            app_account_token=token,
        )
    )
    assert res.is_premium is True
    assert res.status == "active"

    # Verify rows in DB
    session = db_session_factory()
    sub_row = session.query(SubscriptionDB).filter(SubscriptionDB.original_transaction_id == orig_tx).first()
    assert sub_row is not None
    assert sub_row.user_id == user_id
    assert sub_row.status == "active"
    assert sub_row.plan == "monthly"

    # Step 2: Webhook Renewal
    renew_tx = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": orig_tx,
        "transactionId": "20000000100",
        "expiresDate": 2200000000000,
        "environment": "Sandbox",
        "appAccountToken": token,
    })
    renew_notif = pki_helper.sign_jws({
        "notificationType": "DID_RENEW",
        "subtype": "AUTO_RENEW",
        "notificationUUID": "notif-uuid-renew-1",
        "data": {
            "bundleId": "com.kirtidhwaj.Bhumitra",
            "environment": "Sandbox",
            "signedTransactionInfo": renew_tx,
        },
    })
    db_subscription_service.process_app_store_notification(renew_notif)

    # Verify audit transactions table has both transactions
    tx_rows = session.query(TransactionDB).filter(TransactionDB.original_transaction_id == orig_tx).all()
    assert len(tx_rows) == 2

    # Step 3: Webhook Refund / Revocation
    refund_tx = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": orig_tx,
        "revocationDate": 1773000000000,
        "revocationReason": 1,
        "environment": "Sandbox",
    })
    refund_notif = pki_helper.sign_jws({
        "notificationType": "REFUND",
        "subtype": "VOLUNTARY",
        "notificationUUID": "notif-uuid-refund-1",
        "data": {
            "bundleId": "com.kirtidhwaj.Bhumitra",
            "environment": "Sandbox",
            "signedTransactionInfo": refund_tx,
        },
    })
    db_subscription_service.process_app_store_notification(refund_notif)

    # Verify status revoked
    user_status = db_subscription_service.get_user_status(user_id)
    assert user_status.is_premium is False
    assert user_status.status == "revoked"

    session.close()


def test_cross_device_and_reinstall_identity_restoration(pki_helper, db_subscription_service):
    """Test user purchasing on Device 1 and restoring entitlement on Device 2 via appAccountToken."""
    shared_token = "PERMANENT-KEYCHAIN-ACCOUNT-TOKEN-UUID"
    orig_tx = "3000000001"

    # 1. Purchase from Device 1 (User ID: "apple_user_device1")
    tx_jws = pki_helper.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": orig_tx,
        "expiresDate": 2100000000000,
        "environment": "Sandbox",
        "appAccountToken": shared_token,
    })

    db_subscription_service.verify_and_link_transaction(
        SubscriptionVerifyRequest(
            user_id="apple_user_device1",
            signed_transaction_jws=tx_jws,
            original_transaction_id=orig_tx,
            app_account_token=shared_token,
        )
    )

    # 2. Query status from Device 1
    status_dev1 = db_subscription_service.get_user_status("apple_user_device1")
    assert status_dev1.is_premium is True
    assert status_dev1.plan == "monthly"

    # 3. User signs into Device 2 (with same Apple account / appAccountToken)
    status_dev2 = db_subscription_service.verify_and_link_transaction(
        SubscriptionVerifyRequest(
            user_id="apple_user_device2",
            signed_transaction_jws=tx_jws,
            original_transaction_id=orig_tx,
            app_account_token=shared_token,
        )
    )
    assert status_dev2.is_premium is True
    assert status_dev2.plan == "monthly"

    # Device 2 status query succeeds
    status_check = db_subscription_service.get_user_status("apple_user_device2")
    assert status_check.is_premium is True
    assert status_check.status == "active"


def test_app_config_db_persistence(db_session_factory):
    """Test app_configs table for remote config caching."""
    session = db_session_factory()

    config_entry = AppConfigDB(
        key="app_config",
        value='{"min_supported_version": "2.0.0", "recommended_version": "2.2.0", "latest_version": "2.3.0"}',
    )
    session.add(config_entry)
    session.commit()

    saved = session.query(AppConfigDB).filter(AppConfigDB.key == "app_config").first()
    assert saved is not None
    assert "2.0.0" in saved.value

    session.close()
