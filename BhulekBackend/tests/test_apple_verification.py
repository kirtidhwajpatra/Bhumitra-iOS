"""
Automated Test Suite for Apple StoreKit 2 & ASSN V2 Cryptographic Verification
Tests certificate chain validation, signature checks, claim validations,
and webhook lifecycle processing against Apple's official SignedDataVerifier.
"""

import os
import shutil
import base64
import datetime
import pytest
import jwt
from cryptography import x509
from cryptography.x509.oid import NameOID, ObjectIdentifier
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

from services.apple_verification_service import (
    AppleVerificationService,
    AppleVerificationError,
)
from services.subscription_service import SubscriptionService
from models.subscription_models import SubscriptionVerifyRequest
from appstoreserverlibrary.models.Environment import Environment


class PKITestHelper:
    """Helper to generate valid Apple 3-tier certificate chains for testing."""

    def __init__(self):
        # 1. Root CA
        self.root_key = ec.generate_private_key(ec.SECP256R1())
        root_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Apple Root CA - G3")])
        root_ski = x509.SubjectKeyIdentifier.from_public_key(self.root_key.public_key())
        self.root_cert = (
            x509.CertificateBuilder()
            .subject_name(root_name)
            .issuer_name(root_name)
            .public_key(self.root_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1))
            .not_valid_after(datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=365))
            .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
            .add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False, key_encipherment=False, data_encipherment=False, key_agreement=False, key_cert_sign=True, crl_sign=True, encipher_only=False, decipher_only=False), critical=True)
            .add_extension(root_ski, critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(self.root_key.public_key()), critical=False)
            .sign(self.root_key, hashes.SHA256())
        )

        # 2. Intermediate CA (WWDR) with OID 1.2.840.113635.100.6.2.1
        self.inter_key = ec.generate_private_key(ec.SECP256R1())
        inter_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Apple Worldwide Developer Relations CA - G6")])
        inter_ski = x509.SubjectKeyIdentifier.from_public_key(self.inter_key.public_key())
        self.inter_cert = (
            x509.CertificateBuilder()
            .subject_name(inter_name)
            .issuer_name(root_name)
            .public_key(self.inter_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1))
            .not_valid_after(datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=365))
            .add_extension(x509.BasicConstraints(ca=True, path_length=0), critical=True)
            .add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False, key_encipherment=False, data_encipherment=False, key_agreement=False, key_cert_sign=True, crl_sign=True, encipher_only=False, decipher_only=False), critical=True)
            .add_extension(inter_ski, critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(self.root_key.public_key()), critical=False)
            .add_extension(x509.UnrecognizedExtension(ObjectIdentifier("1.2.840.113635.100.6.2.1"), b""), critical=False)
            .sign(self.root_key, hashes.SHA256())
        )

        # 3. Leaf Certificate with OID 1.2.840.113635.100.6.11.1
        self.leaf_key = ec.generate_private_key(ec.SECP256R1())
        leaf_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Mac App Store and iTunes Store Receipt Signing")])
        leaf_ski = x509.SubjectKeyIdentifier.from_public_key(self.leaf_key.public_key())
        self.leaf_cert = (
            x509.CertificateBuilder()
            .subject_name(leaf_name)
            .issuer_name(inter_name)
            .public_key(self.leaf_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1))
            .not_valid_after(datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=365))
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
            .add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False, key_encipherment=False, data_encipherment=False, key_agreement=False, key_cert_sign=False, crl_sign=False, encipher_only=False, decipher_only=False), critical=True)
            .add_extension(leaf_ski, critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(self.inter_key.public_key()), critical=False)
            .add_extension(x509.UnrecognizedExtension(ObjectIdentifier("1.2.840.113635.100.6.11.1"), b""), critical=False)
            .sign(self.inter_key, hashes.SHA256())
        )

        self.root_der = self.root_cert.public_bytes(serialization.Encoding.DER)
        self.inter_der = self.inter_cert.public_bytes(serialization.Encoding.DER)
        self.leaf_der = self.leaf_cert.public_bytes(serialization.Encoding.DER)

        self.x5c_header = [
            base64.b64encode(self.leaf_der).decode("utf-8"),
            base64.b64encode(self.inter_der).decode("utf-8"),
            base64.b64encode(self.root_der).decode("utf-8"),
        ]

    def sign_jws(self, payload: dict) -> str:
        headers = {"alg": "ES256", "x5c": self.x5c_header}
        return jwt.encode(payload, self.leaf_key, algorithm="ES256", headers=headers)


@pytest.fixture
def pki():
    return PKITestHelper()


@pytest.fixture
def test_verifier_service(pki, tmp_path):
    certs_dir = str(tmp_path / "test_certs")
    os.makedirs(certs_dir, exist_ok=True)
    with open(os.path.join(certs_dir, "test_root.cer"), "wb") as f:
        f.write(pki.root_der)

    service = AppleVerificationService(certs_dir=certs_dir)
    return service


@pytest.fixture
def test_subscription_service(test_verifier_service, monkeypatch, tmp_path):
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from db.base import Base
    import models.db_models
    import db.session as session_mod
    import services.subscription_service as ss_mod

    # Create temporary in-memory database for testing
    test_db_url = f"sqlite:///{tmp_path}/test_bhumitra.db"
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

    monkeypatch.setattr(ss_mod, "apple_verification_service", test_verifier_service)
    monkeypatch.setattr(ss_mod, "get_db_session", test_get_db_session)
    monkeypatch.setattr(session_mod, "get_db_session", test_get_db_session)

    sub_service = SubscriptionService()
    return sub_service


# ==============================================================================
# TESTS
# ==============================================================================

def test_1_valid_signed_transaction(pki, test_subscription_service):
    """1. Valid signed StoreKit 2 transaction with proper x5c chain."""
    signed_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000001",
        "transactionId": "2000000001",
        "purchaseDate": 1770000000000,
        "expiresDate": 1999999999000,
        "environment": "Sandbox",
        "appAccountToken": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
    })

    req = SubscriptionVerifyRequest(
        user_id="apple_user_123",
        signed_transaction_jws=signed_jws,
        original_transaction_id="1000000001",
        app_account_token="E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
    )

    res = test_subscription_service.verify_and_link_transaction(req)
    assert res.is_premium is True
    assert res.status == "active"
    assert res.product_id == "bhumitra.unlimited.monthly"
    assert res.original_transaction_id == "1000000001"
    assert res.app_account_token == "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"


def test_2_invalid_signature_rejected(pki, test_verifier_service):
    """2. Tampered signature is rejected."""
    signed_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000001",
        "environment": "Sandbox",
    })

    parts = signed_jws.split(".")
    tampered_jws = f"{parts[0]}.{parts[1]}.bad_signature_here"

    with pytest.raises(AppleVerificationError) as exc:
        test_verifier_service.verify_and_decode_transaction(tampered_jws)
    assert exc.value.status_code == 400


def test_3_malformed_jws_rejected(test_verifier_service):
    """3. Malformed JWS string is rejected."""
    with pytest.raises(AppleVerificationError) as exc:
        test_verifier_service.verify_and_decode_transaction("not.a.valid.jws.payload")
    assert exc.value.status_code == 400


def test_4_wrong_bundle_id_rejected(pki, test_verifier_service):
    """4. Token with wrong bundleId (intended for another app) is rejected."""
    signed_jws = pki.sign_jws({
        "bundleId": "com.unauthorized.otherapp",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000001",
        "environment": "Sandbox",
    })

    with pytest.raises(AppleVerificationError) as exc:
        test_verifier_service.verify_and_decode_transaction(signed_jws)
    assert exc.value.status_code == 400


def test_5_wrong_environment_rejected(pki, test_verifier_service):
    """5. Sandbox token sent when expecting Production is rejected."""
    signed_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000001",
        "environment": "Production",
    })

    # Test against Sandbox-only verifier
    with pytest.raises(AppleVerificationError) as exc:
        test_verifier_service.verify_and_decode_transaction(
            signed_jws, target_environment=Environment.SANDBOX
        )
    assert exc.value.status_code == 400


def test_6_wrong_product_id_rejected(pki, test_verifier_service):
    """6. Token with unauthorized product ID is rejected with 422."""
    signed_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "fake_free_unlimited_pass",
        "originalTransactionId": "1000000001",
        "environment": "Sandbox",
    })

    with pytest.raises(AppleVerificationError) as exc:
        test_verifier_service.verify_and_decode_transaction(signed_jws)
    assert exc.value.status_code == 422


def test_7_mismatched_app_account_token_rejected(pki, test_verifier_service):
    """7. Token associated with User B's token presented by User A is rejected with 403."""
    signed_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000001",
        "environment": "Sandbox",
        "appAccountToken": "11111111-1111-1111-1111-111111111111",
    })

    with pytest.raises(AppleVerificationError) as exc:
        test_verifier_service.verify_and_decode_transaction(
            signed_jws, expected_app_account_token="22222222-2222-2222-2222-222222222222"
        )
    assert exc.value.status_code == 403


def test_8_valid_renewal_assn_v2(pki, test_subscription_service):
    """8. Cryptographically verified ASSN V2 DID_RENEW webhook."""
    # First link a transaction
    tx_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000001",
        "expiresDate": 1770000000000,
        "environment": "Sandbox",
        "appAccountToken": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
    })
    test_subscription_service.verify_and_link_transaction(
        SubscriptionVerifyRequest(
            user_id="user_renew_test",
            signed_transaction_jws=tx_jws,
            original_transaction_id="1000000001",
            app_account_token="E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
        )
    )

    # Webhook renewal notification
    renew_tx_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000001",
        "expiresDate": 2100000000000,
        "environment": "Sandbox",
        "appAccountToken": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
    })
    renew_info_jws = pki.sign_jws({
        "originalTransactionId": "1000000001",
        "autoRenewStatus": 1,
        "environment": "Sandbox",
    })
    notification_jws = pki.sign_jws({
        "notificationType": "DID_RENEW",
        "subtype": "AUTO_RENEW",
        "notificationUUID": "uuid-renew-101",
        "data": {
            "bundleId": "com.kirtidhwaj.Bhumitra",
            "environment": "Sandbox",
            "signedTransactionInfo": renew_tx_jws,
            "signedRenewalInfo": renew_info_jws,
        },
    })

    result = test_subscription_service.process_app_store_notification(notification_jws)
    assert result["status"] == "processed"
    assert result["notification_type"] == "DID_RENEW"
    assert result["is_premium"] is True

    # Verify status
    status = test_subscription_service.get_user_status("user_renew_test")
    assert status.is_premium is True
    assert status.status == "active"


def test_9_expired_subscription_assn_v2(pki, test_subscription_service):
    """9. Cryptographically verified ASSN V2 EXPIRED notification."""
    # Link user
    tx_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000002",
        "expiresDate": 1770000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-EXPIRE",
    })
    test_subscription_service.verify_and_link_transaction(
        SubscriptionVerifyRequest(
            user_id="user_expire_test",
            signed_transaction_jws=tx_jws,
            original_transaction_id="1000000002",
            app_account_token="TOKEN-EXPIRE",
        )
    )

    # Send EXPIRED notification
    notification_jws = pki.sign_jws({
        "notificationType": "EXPIRED",
        "notificationUUID": "uuid-expire-102",
        "data": {
            "bundleId": "com.kirtidhwaj.Bhumitra",
            "environment": "Sandbox",
            "signedTransactionInfo": tx_jws,
        },
    })

    result = test_subscription_service.process_app_store_notification(notification_jws)
    assert result["status"] == "processed"
    assert result["is_premium"] is False

    status = test_subscription_service.get_user_status("user_expire_test")
    assert status.is_premium is False
    assert status.status == "expired"


def test_10_revoked_refunded_subscription(pki, test_subscription_service):
    """10. Cryptographically verified REFUND / REVOKE notification."""
    tx_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000003",
        "expiresDate": 2100000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-REFUND",
    })
    test_subscription_service.verify_and_link_transaction(
        SubscriptionVerifyRequest(
            user_id="user_refund_test",
            signed_transaction_jws=tx_jws,
            original_transaction_id="1000000003",
            app_account_token="TOKEN-REFUND",
        )
    )

    # Send REFUND notification
    refund_tx_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000003",
        "revocationDate": 1770500000000,
        "revocationReason": 1,
        "environment": "Sandbox",
    })
    notification_jws = pki.sign_jws({
        "notificationType": "REFUND",
        "subtype": "VOLUNTARY",
        "notificationUUID": "uuid-refund-103",
        "data": {
            "bundleId": "com.kirtidhwaj.Bhumitra",
            "environment": "Sandbox",
            "signedTransactionInfo": refund_tx_jws,
        },
    })

    result = test_subscription_service.process_app_store_notification(notification_jws)
    assert result["status"] == "processed"
    assert result["is_premium"] is False

    status = test_subscription_service.get_user_status("user_refund_test")
    assert status.is_premium is False
    assert status.status == "revoked"


def test_11_invalid_assn_notification_rejected(test_subscription_service):
    """11. Tampered / invalid ASSN webhook notification is rejected."""
    with pytest.raises(AppleVerificationError) as exc:
        test_subscription_service.process_app_store_notification("tampered.signed.payload")
    assert exc.value.status_code == 400


def test_12_duplicate_notification_idempotency(pki, test_subscription_service):
    """12. Apple notification retries with identical UUID are handled idempotently."""
    tx_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000004",
        "expiresDate": 2100000000000,
        "environment": "Sandbox",
    })
    notification_jws = pki.sign_jws({
        "notificationType": "DID_RENEW",
        "notificationUUID": "uuid-idempotent-104",
        "data": {
            "bundleId": "com.kirtidhwaj.Bhumitra",
            "environment": "Sandbox",
            "signedTransactionInfo": tx_jws,
        },
    })

    # First delivery
    res1 = test_subscription_service.process_app_store_notification(notification_jws)
    assert res1["status"] == "processed"

    # Second delivery (Apple retry)
    res2 = test_subscription_service.process_app_store_notification(notification_jws)
    assert res2["status"] == "already_processed"
    assert res2["notification_uuid"] == "uuid-idempotent-104"


def test_13_valid_monthly_subscription_transaction(pki, test_subscription_service):
    """13. Verified monthly subscription with valid expiration is active."""
    signed_jws = pki.sign_jws({
        "bundleId": "com.kirtidhwaj.Bhumitra",
        "productId": "bhumitra.unlimited.monthly",
        "originalTransactionId": "1000000005",
        "transactionId": "2000000005",
        "purchaseDate": 1770000000000,
        "expiresDate": 2100000000000,
        "environment": "Sandbox",
        "appAccountToken": "TOKEN-MONTHLY",
    })

    req = SubscriptionVerifyRequest(
        user_id="user_monthly_test",
        signed_transaction_jws=signed_jws,
        original_transaction_id="1000000005",
        app_account_token="TOKEN-MONTHLY",
    )

    res = test_subscription_service.verify_and_link_transaction(req)
    assert res.is_premium is True
    assert res.status == "active"
    assert res.plan == "monthly"
    assert res.expires_date is not None
