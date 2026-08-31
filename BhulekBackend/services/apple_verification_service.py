"""
Apple Cryptographic Verification Service
Implements official Apple StoreKit 2 and App Store Server Notifications V2
cryptographic JWS signature verification, x5c X.509 certificate chain validation,
and strict claim validation (bundle ID, environment, product IDs, appAccountToken).
"""

import os
import glob
from typing import List, Optional, Set, Dict, Any
from appstoreserverlibrary.signed_data_verifier import (
    SignedDataVerifier,
    VerificationException,
    VerificationStatus,
)
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import JWSTransactionDecodedPayload
from appstoreserverlibrary.models.JWSRenewalInfoDecodedPayload import JWSRenewalInfoDecodedPayload
from appstoreserverlibrary.models.ResponseBodyV2DecodedPayload import ResponseBodyV2DecodedPayload


class AppleVerificationError(Exception):
    """Raised when Apple cryptographic verification or claim validation fails."""

    def __init__(self, message: str, status_code: int = 400, details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.details = details or {}


class AppleVerificationService:
    BUNDLE_ID: str = os.environ.get("APPLE_BUNDLE_ID", "com.kirtidhwaj.Bhumitra")
    APP_APPLE_ID: int = int(os.environ.get("APPLE_APP_ID", "6740000000"))
    
    ALLOWED_PRODUCT_IDS: Set[str] = {
        # Consumables
        "bhumitra.plots.10",
        "bhumitra.plots.50",
        "bhumitra.plots.200",
        # Auto-renewable Subscription
        "bhumitra.unlimited.monthly",
    }

    def __init__(self, certs_dir: Optional[str] = None):
        if certs_dir is None:
            certs_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "certs")
        self.certs_dir = certs_dir
        self.root_certificates: List[bytes] = self._load_root_certificates()
        
        # Initialize verifiers for all supported environments
        self.verifiers: Dict[Environment, SignedDataVerifier] = {}
        self._init_verifiers()
        
        # Idempotency cache for App Store Server Notifications
        self._processed_notification_uuids: Set[str] = set()

    def _load_root_certificates(self) -> List[bytes]:
        certs = []
        if os.path.exists(self.certs_dir):
            for cert_file in glob.glob(os.path.join(self.certs_dir, "*.cer")):
                try:
                    with open(cert_file, "rb") as f:
                        certs.append(f.read())
                except Exception as e:
                    print(f"Warning: Failed to load Apple root cert {cert_file}: {e}")
        
        if not certs:
            print("Warning: No Apple root certificates found in certs directory.")
        else:
            print(f"Loaded {len(certs)} Apple Root CA certificates for JWS verification.")
        return certs

    def _init_verifiers(self):
        if not self.root_certificates:
            return

        # Sandbox Verifier
        self.verifiers[Environment.SANDBOX] = SignedDataVerifier(
            root_certificates=self.root_certificates,
            enable_online_checks=False,
            environment=Environment.SANDBOX,
            bundle_id=self.BUNDLE_ID,
        )

        # Production Verifier
        self.verifiers[Environment.PRODUCTION] = SignedDataVerifier(
            root_certificates=self.root_certificates,
            enable_online_checks=False,
            environment=Environment.PRODUCTION,
            bundle_id=self.BUNDLE_ID,
            app_apple_id=self.APP_APPLE_ID,
        )

        # Xcode Local Testing Verifier
        self.verifiers[Environment.XCODE] = SignedDataVerifier(
            root_certificates=self.root_certificates,
            enable_online_checks=False,
            environment=Environment.XCODE,
            bundle_id=self.BUNDLE_ID,
        )

        # LocalTesting Verifier
        self.verifiers[Environment.LOCAL_TESTING] = SignedDataVerifier(
            root_certificates=self.root_certificates,
            enable_online_checks=False,
            environment=Environment.LOCAL_TESTING,
            bundle_id=self.BUNDLE_ID,
        )

    # MARK: - Transaction Verification

    def verify_and_decode_transaction(
        self,
        signed_transaction_jws: str,
        expected_app_account_token: Optional[str] = None,
        target_environment: Optional[Environment] = None,
    ) -> JWSTransactionDecodedPayload:
        """
        Cryptographically verifies an Apple StoreKit 2 transaction JWS against Apple Root CA,
        and validates bundleId, productId, and appAccountToken.
        """
        if not signed_transaction_jws or not signed_transaction_jws.strip():
            raise AppleVerificationError("Missing or empty signed_transaction_jws", status_code=400)

        # Determine verifiers to test against
        candidate_verifiers = []
        if target_environment and target_environment in self.verifiers:
            candidate_verifiers.append(self.verifiers[target_environment])
        else:
            # Order: Sandbox, Production, Xcode, LocalTesting
            for env in [Environment.SANDBOX, Environment.PRODUCTION, Environment.XCODE, Environment.LOCAL_TESTING]:
                if env in self.verifiers:
                    candidate_verifiers.append(self.verifiers[env])

        last_error = None
        for verifier in candidate_verifiers:
            try:
                decoded: JWSTransactionDecodedPayload = verifier.verify_and_decode_signed_transaction(
                    signed_transaction_jws.strip()
                )
                
                # Validate Product ID
                if decoded.productId not in self.ALLOWED_PRODUCT_IDS:
                    raise AppleVerificationError(
                        f"Unauthorized or unknown product ID: '{decoded.productId}'",
                        status_code=422,
                        details={"product_id": decoded.productId},
                    )

                # Validate appAccountToken if provided
                if expected_app_account_token and decoded.appAccountToken:
                    clean_expected = expected_app_account_token.strip().lower()
                    clean_actual = str(decoded.appAccountToken).strip().lower()
                    if clean_expected != clean_actual:
                        raise AppleVerificationError(
                            "appAccountToken mismatch between user account and Apple transaction",
                            status_code=403,
                            details={"expected": clean_expected, "actual": clean_actual},
                        )

                return decoded
            except VerificationException as ve:
                last_error = ve
            except AppleVerificationError:
                raise
            except Exception as e:
                last_error = e

        error_msg = f"Cryptographic verification failed: {last_error}" if last_error else "Verification failed"
        raise AppleVerificationError(error_msg, status_code=400, details={"error": str(last_error)})

    # MARK: - Renewal Info Verification

    def verify_and_decode_renewal_info(
        self,
        signed_renewal_info_jws: str,
        target_environment: Optional[Environment] = None,
    ) -> JWSRenewalInfoDecodedPayload:
        """
        Cryptographically verifies an Apple StoreKit 2 signedRenewalInfo JWS.
        """
        if not signed_renewal_info_jws or not signed_renewal_info_jws.strip():
            raise AppleVerificationError("Missing or empty signed_renewal_info_jws", status_code=400)

        candidate_verifiers = []
        if target_environment and target_environment in self.verifiers:
            candidate_verifiers.append(self.verifiers[target_environment])
        else:
            for env in [Environment.SANDBOX, Environment.PRODUCTION, Environment.XCODE, Environment.LOCAL_TESTING]:
                if env in self.verifiers:
                    candidate_verifiers.append(self.verifiers[env])

        last_error = None
        for verifier in candidate_verifiers:
            try:
                decoded: JWSRenewalInfoDecodedPayload = verifier.verify_and_decode_renewal_info(
                    signed_renewal_info_jws.strip()
                )
                return decoded
            except Exception as e:
                last_error = e

        error_msg = f"Renewal info verification failed: {last_error}" if last_error else "Verification failed"
        raise AppleVerificationError(error_msg, status_code=400, details={"error": str(last_error)})

    # MARK: - Notification (ASSN V2) Verification

    def verify_and_decode_notification(
        self,
        signed_payload_jws: str,
        target_environment: Optional[Environment] = None,
    ) -> ResponseBodyV2DecodedPayload:
        """
        Cryptographically verifies an App Store Server Notifications V2 signedPayload JWS.
        """
        if not signed_payload_jws or not signed_payload_jws.strip():
            raise AppleVerificationError("Missing or empty signedPayload", status_code=400)

        candidate_verifiers = []
        if target_environment and target_environment in self.verifiers:
            candidate_verifiers.append(self.verifiers[target_environment])
        else:
            for env in [Environment.SANDBOX, Environment.PRODUCTION, Environment.XCODE, Environment.LOCAL_TESTING]:
                if env in self.verifiers:
                    candidate_verifiers.append(self.verifiers[env])

        last_error = None
        for verifier in candidate_verifiers:
            try:
                decoded: ResponseBodyV2DecodedPayload = verifier.verify_and_decode_notification(
                    signed_payload_jws.strip()
                )
                return decoded
            except Exception as e:
                last_error = e

        error_msg = f"App Store notification verification failed: {last_error}" if last_error else "Verification failed"
        raise AppleVerificationError(error_msg, status_code=400, details={"error": str(last_error)})

    # MARK: - Idempotency

    def is_notification_processed(self, notification_uuid: Optional[str]) -> bool:
        if not notification_uuid:
            return False
        return notification_uuid in self._processed_notification_uuids

    def mark_notification_processed(self, notification_uuid: Optional[str]):
        if notification_uuid:
            self._processed_notification_uuids.add(notification_uuid)


# Shared singleton instance
apple_verification_service = AppleVerificationService()
