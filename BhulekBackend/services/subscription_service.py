import json
import os
import time
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from models.subscription_models import (
    SubscriptionStatusResponse,
    SubscriptionVerifyRequest,
)
from services.apple_verification_service import (
    apple_verification_service,
    AppleVerificationError,
)

# Persistent file storage for subscription records in the backend
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
SUBSCRIPTIONS_FILE = os.path.join(DATA_DIR, "server_subscriptions.json")


def _ensure_data_dir():
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR, exist_ok=True)
    if not os.path.exists(SUBSCRIPTIONS_FILE):
        with open(SUBSCRIPTIONS_FILE, "w") as f:
            json.dump({}, f)


class SubscriptionService:
    def __init__(self):
        _ensure_data_dir()

    def _load_database(self) -> Dict[str, Any]:
        try:
            with open(SUBSCRIPTIONS_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return {}

    def _save_database(self, data: Dict[str, Any]):
        with open(SUBSCRIPTIONS_FILE, "w") as f:
            json.dump(data, f, indent=2)

    # MARK: - Client Verification & Linking

    def verify_and_link_transaction(
        self, request: SubscriptionVerifyRequest
    ) -> SubscriptionStatusResponse:
        """
        Cryptographically verifies a StoreKit 2 transaction submitted by the iOS client
        against Apple's Root CA, validates bundleId, productId, and appAccountToken,
        and persists the server-authoritative entitlement.
        """
        # Cryptographic verification against Apple Root CA & strict claim validation
        decoded_transaction = apple_verification_service.verify_and_decode_transaction(
            signed_transaction_jws=request.signed_transaction_jws,
            expected_app_account_token=request.app_account_token,
        )

        original_transaction_id = str(decoded_transaction.originalTransactionId or "")
        product_id = str(decoded_transaction.productId or "bhumitra_premium_monthly")
        purchase_date_ms = decoded_transaction.purchaseDate or 0
        expires_date_ms = decoded_transaction.expiresDate or 0
        revocation_date_ms = decoded_transaction.revocationDate
        revocation_reason = (
            decoded_transaction.revocationReason.value
            if hasattr(decoded_transaction.revocationReason, "value")
            else decoded_transaction.revocationReason
        )
        app_account_token = str(
            decoded_transaction.appAccountToken or request.app_account_token or ""
        )
        environment_str = (
            decoded_transaction.environment.value
            if hasattr(decoded_transaction.environment, "value")
            else str(decoded_transaction.environment)
        )

        # Evaluate validity
        now_ms = int(time.time() * 1000)
        is_revoked = revocation_date_ms is not None and revocation_date_ms > 0
        
        # Check expiration: for lifetime purchases, expires_date_ms is None/0 (never expires)
        is_lifetime = "lifetime" in product_id.lower()
        if is_lifetime:
            is_expired = False
        else:
            is_expired = expires_date_ms > 0 and expires_date_ms < now_ms
            
        is_active = (not is_revoked) and (not is_expired)

        status_str = "active"
        if is_revoked:
            status_str = "revoked"
        elif is_expired:
            status_str = "expired"

        # Format dates
        expires_iso = (
            datetime.fromtimestamp(expires_date_ms / 1000, tz=timezone.utc).isoformat()
            if expires_date_ms and not is_lifetime
            else None
        )
        purchase_iso = (
            datetime.fromtimestamp(purchase_date_ms / 1000, tz=timezone.utc).isoformat()
            if purchase_date_ms
            else None
        )

        # Plan name
        plan_name = "monthly"
        if "yearly" in product_id.lower():
            plan_name = "yearly"
        elif "lifetime" in product_id.lower():
            plan_name = "lifetime"

        db = self._load_database()
        record = {
            "user_id": request.user_id,
            "original_transaction_id": original_transaction_id,
            "app_account_token": app_account_token,
            "product_id": product_id,
            "plan": plan_name,
            "status": status_str,
            "is_premium": is_active,
            "purchase_date": purchase_iso,
            "expires_date": expires_iso,
            "auto_renew_status": not is_lifetime,
            "is_in_billing_retry": False,
            "revocation_reason": revocation_reason,
            "environment": environment_str,
            "verified_at": datetime.now(timezone.utc).isoformat(),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }

        # Store by original_transaction_id
        db[original_transaction_id] = record
        # Link user_id directly
        db[f"user:{request.user_id}"] = original_transaction_id
        # Link app_account_token directly to user_id
        if app_account_token:
            db[f"token:{app_account_token.lower()}"] = request.user_id
            db[f"token:{app_account_token}"] = request.user_id

        self._save_database(db)

        print(
            f"DEBUG: 🔒 Verified Apple Transaction {original_transaction_id} for User '{request.user_id}' (Product: {product_id}, Active: {is_active}, Env: {environment_str})"
        )

        return SubscriptionStatusResponse(
            user_id=request.user_id,
            is_premium=is_active,
            status=status_str,
            plan=plan_name,
            product_id=product_id,
            original_transaction_id=original_transaction_id,
            app_account_token=app_account_token,
            purchase_date=purchase_iso,
            expires_date=expires_iso,
            auto_renew_status=not is_lifetime,
            is_in_billing_retry=False,
            revocation_reason=revocation_reason,
            message="Apple transaction cryptographically verified and linked to user account.",
        )

    # MARK: - App Store Server Notifications V2 Webhook

    def process_app_store_notification(
        self, signed_payload: str
    ) -> Dict[str, Any]:
        """
        Cryptographically verifies and processes Apple App Store Server Notifications V2.
        Handles: SUBSCRIBED, DID_RENEW, DID_FAIL_TO_RENEW, EXPIRED,
        DID_CHANGE_RENEWAL_STATUS, REVOKE, REFUND, GRACE_PERIOD_EXPIRED, TEST.
        """
        # Cryptographically verify top-level notification JWS
        decoded_notification = apple_verification_service.verify_and_decode_notification(
            signed_payload
        )

        notification_type = (
            decoded_notification.notificationType.value
            if hasattr(decoded_notification.notificationType, "value")
            else str(decoded_notification.notificationType or "")
        )
        subtype = (
            decoded_notification.subtype.value
            if hasattr(decoded_notification.subtype, "value")
            else str(decoded_notification.subtype or "")
        )
        notification_uuid = decoded_notification.notificationUUID

        print(
            f"DEBUG: 🍏 [ASSN V2] Received Verified Notification: Type={notification_type}, Subtype={subtype}, UUID={notification_uuid}"
        )

        # Idempotency check: Reject duplicate notification retries from modifying state repeatedly
        if apple_verification_service.is_notification_processed(notification_uuid):
            print(f"DEBUG: 🔁 [ASSN V2] Notification {notification_uuid} already processed. Skipping duplicate.")
            return {
                "status": "already_processed",
                "notification_type": notification_type,
                "notification_uuid": notification_uuid,
            }

        data = decoded_notification.data
        if not data:
            apple_verification_service.mark_notification_processed(notification_uuid)
            return {
                "status": "processed",
                "notification_type": notification_type,
                "message": "Notification processed (no data body)",
            }

        # Cryptographically verify inner signedTransactionInfo if present
        transaction_info = None
        if data.signedTransactionInfo:
            transaction_info = apple_verification_service.verify_and_decode_transaction(
                data.signedTransactionInfo
            )

        # Cryptographically verify inner signedRenewalInfo if present
        renewal_info = None
        if data.signedRenewalInfo:
            renewal_info = apple_verification_service.verify_and_decode_renewal_info(
                data.signedRenewalInfo
            )

        original_transaction_id = ""
        if transaction_info:
            original_transaction_id = str(transaction_info.originalTransactionId or "")
        elif renewal_info:
            original_transaction_id = str(renewal_info.originalTransactionId or "")

        if not original_transaction_id:
            print("DEBUG: ⚠️ No originalTransactionId found in verified notification.")
            apple_verification_service.mark_notification_processed(notification_uuid)
            return {
                "status": "ignored",
                "reason": "Missing originalTransactionId",
            }

        db = self._load_database()
        record = db.get(original_transaction_id, {})
        
        # Look up user via verified appAccountToken or existing transaction record
        app_account_token = None
        if transaction_info and transaction_info.appAccountToken:
            app_account_token = str(transaction_info.appAccountToken)
        elif "app_account_token" in record:
            app_account_token = record.get("app_account_token")

        user_id = "unknown"
        if app_account_token:
            matched_user = (
                db.get(f"token:{app_account_token.lower()}")
                or db.get(f"token:{app_account_token}")
            )
            if matched_user:
                user_id = matched_user
                print(
                    f"DEBUG: 🎯 [ASSN V2] Matched Apple Transaction to Bhumitra User: '{user_id}' via verified appAccountToken: '{app_account_token}'"
                )
            else:
                user_id = record.get("user_id", app_account_token)
        else:
            user_id = record.get("user_id", "unknown")

        product_id = (
            str(transaction_info.productId)
            if transaction_info and transaction_info.productId
            else record.get("product_id", "bhumitra_premium_monthly")
        )
        expires_date_ms = (
            transaction_info.expiresDate
            if transaction_info and transaction_info.expiresDate
            else 0
        )
        
        auto_renew_status = True
        is_in_billing_retry = False
        if renewal_info:
            auto_renew_status = (
                renewal_info.autoRenewStatus.value == 1
                if hasattr(renewal_info.autoRenewStatus, "value")
                else renewal_info.autoRenewStatus == 1
            )
            is_in_billing_retry = bool(renewal_info.isInBillingRetryPeriod)

        expires_iso = (
            datetime.fromtimestamp(expires_date_ms / 1000, tz=timezone.utc).isoformat()
            if expires_date_ms
            else record.get("expires_date")
        )

        # Update status based on verified notification type
        if notification_type in ["SUBSCRIBED", "DID_RENEW"]:
            # Initial subscription or successful monthly/yearly renewal
            record["status"] = "active"
            record["is_premium"] = True
            record["expires_date"] = expires_iso
            record["auto_renew_status"] = True
            record["is_in_billing_retry"] = False
            print(
                f"DEBUG: 🟢 [ASSN V2] Subscription ACTIVE/RENEWED for {original_transaction_id} until {expires_iso}"
            )

        elif notification_type == "DID_FAIL_TO_RENEW":
            # Billing failure (e.g. card declined). Enter billing retry state.
            record["status"] = "in_billing_retry"
            record["is_in_billing_retry"] = True
            print(
                f"DEBUG: 🟡 [ASSN V2] Billing failure/retry for {original_transaction_id}"
            )

        elif notification_type == "DID_CHANGE_RENEWAL_STATUS":
            # User turned off auto-renew in Apple ID settings
            record["auto_renew_status"] = auto_renew_status
            print(
                f"DEBUG: ℹ️ [ASSN V2] Auto-renew updated for {original_transaction_id}: {auto_renew_status}"
            )

        elif notification_type in ["REVOKE", "REFUND"]:
            # Apple granted a refund or revoked Family Sharing access
            record["status"] = "revoked"
            record["is_premium"] = False
            record["revocation_reason"] = (
                transaction_info.revocationReason.value
                if transaction_info and hasattr(transaction_info.revocationReason, "value")
                else 1
            )
            print(
                f"DEBUG: ⛔ [ASSN V2] Subscription REFUNDED/REVOKED for {original_transaction_id}"
            )

        elif notification_type in ["EXPIRED", "GRACE_PERIOD_EXPIRED"]:
            # Subscription reached the end of billing period without renewal
            record["status"] = "expired"
            record["is_premium"] = False
            print(
                f"DEBUG: ⌛ [ASSN V2] Subscription EXPIRED for {original_transaction_id}"
            )

        elif notification_type == "TEST":
            print("DEBUG: 🧪 [ASSN V2] Received Apple Test Notification. Server is operational.")

        else:
            print(f"DEBUG: ℹ️ [ASSN V2] Unhandled notification type '{notification_type}'. Record preserved.")

        # Persist updated subscription record
        record["user_id"] = user_id
        record["original_transaction_id"] = original_transaction_id
        record["product_id"] = product_id
        record["updated_at"] = datetime.now(timezone.utc).isoformat()
        
        db[original_transaction_id] = record
        if user_id != "unknown":
            db[f"user:{user_id}"] = original_transaction_id
        if app_account_token:
            db[f"token:{app_account_token.lower()}"] = user_id
            db[f"token:{app_account_token}"] = user_id

        self._save_database(db)

        # Mark notification UUID as processed
        apple_verification_service.mark_notification_processed(notification_uuid)

        return {
            "status": "processed",
            "notification_type": notification_type,
            "original_transaction_id": original_transaction_id,
            "user_id": user_id,
            "is_premium": record.get("is_premium", False),
        }

    # MARK: - User Status Query

    def get_user_status(self, user_id: str) -> SubscriptionStatusResponse:
        """
        Retrieves the server-authoritative subscription state for a user.
        """
        db = self._load_database()
        original_tx_id = db.get(f"user:{user_id}")

        if not original_tx_id or original_tx_id not in db:
            return SubscriptionStatusResponse(
                user_id=user_id,
                is_premium=False,
                status="none",
                message="No active subscription found for user.",
            )

        record = db[original_tx_id]
        
        # Re-evaluate live expiry
        expires_date_str = record.get("expires_date")
        is_premium = record.get("is_premium", False)
        status_str = record.get("status", "none")
        product_id = record.get("product_id", "bhumitra_premium_monthly")
        
        is_lifetime = "lifetime" in product_id.lower()
        if not is_lifetime and expires_date_str and is_premium:
            try:
                expires_dt = datetime.fromisoformat(expires_date_str)
                if datetime.now(timezone.utc) > expires_dt:
                    is_premium = False
                    status_str = "expired"
                    record["is_premium"] = False
                    record["status"] = "expired"
                    db[original_tx_id] = record
                    self._save_database(db)
            except Exception:
                pass

        plan_name = "monthly"
        if "yearly" in product_id.lower():
            plan_name = "yearly"
        elif "lifetime" in product_id.lower():
            plan_name = "lifetime"

        return SubscriptionStatusResponse(
            user_id=user_id,
            is_premium=is_premium,
            status=status_str,
            plan=plan_name,
            product_id=product_id,
            original_transaction_id=original_tx_id,
            app_account_token=record.get("app_account_token"),
            purchase_date=record.get("purchase_date"),
            expires_date=expires_date_str,
            auto_renew_status=record.get("auto_renew_status", not is_lifetime),
            is_in_billing_retry=record.get("is_in_billing_retry", False),
            revocation_reason=record.get("revocation_reason"),
            message="Active subscription status verified.",
        )


subscription_service = SubscriptionService()
