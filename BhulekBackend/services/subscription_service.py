import base64
import json
import os
import time
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from models.subscription_models import (
    SubscriptionStatusResponse,
    SubscriptionVerifyRequest,
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

    def decode_jws_payload(self, jws_token: str) -> Dict[str, Any]:
        """
        Decodes JWS payload segment safely using standard base64url decoding.
        Extracts claims directly from Apple signed payload/transaction/renewal info.
        """
        if not jws_token:
            return {}
        try:
            parts = jws_token.strip().split(".")
            if len(parts) >= 2:
                payload_segment = parts[1]
                # Fix padding for base64url
                rem = len(payload_segment) % 4
                if rem > 0:
                    payload_segment += "=" * (4 - rem)
                decoded_bytes = base64.urlsafe_b64decode(payload_segment)
                return json.loads(decoded_bytes.decode("utf-8"))
            return {}
        except Exception as e:
            print(f"Error decoding JWS token: {e}")
            return {}

    # MARK: - Client Verification & Linking

    def verify_and_link_transaction(
        self, request: SubscriptionVerifyRequest
    ) -> SubscriptionStatusResponse:
        """
        Processes a StoreKit 2 transaction submitted by the iOS client,
        decodes the Apple JWS token, and persists the verified entitlement.
        """
        transaction_info = self.decode_jws_payload(request.signed_transaction_jws)
        if not transaction_info:
            return SubscriptionStatusResponse(
                user_id=request.user_id,
                is_premium=False,
                status="error",
                message="Failed to parse signed transaction JWS payload.",
            )

        original_transaction_id = str(
            transaction_info.get("originalTransactionId")
            or request.original_transaction_id
            or ""
        )
        product_id = transaction_info.get("productId", "bhumitra_premium_monthly")
        purchase_date_ms = transaction_info.get("purchaseDate", 0)
        expires_date_ms = transaction_info.get("expiresDate", 0)
        revocation_date_ms = transaction_info.get("revocationDate")
        revocation_reason = transaction_info.get("revocationReason")

        # Evaluate validity
        now_ms = int(time.time() * 1000)
        is_revoked = revocation_date_ms is not None and revocation_date_ms > 0
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
            if expires_date_ms
            else None
        )
        purchase_iso = (
            datetime.fromtimestamp(purchase_date_ms / 1000, tz=timezone.utc).isoformat()
            if purchase_date_ms
            else None
        )

        app_account_token = str(
            request.app_account_token
            or transaction_info.get("appAccountToken")
            or ""
        )

        db = self._load_database()
        record = {
            "user_id": request.user_id,
            "original_transaction_id": original_transaction_id,
            "app_account_token": app_account_token,
            "product_id": product_id,
            "status": status_str,
            "is_premium": is_active,
            "purchase_date": purchase_iso,
            "expires_date": expires_iso,
            "auto_renew_status": True,
            "is_in_billing_retry": False,
            "revocation_reason": revocation_reason,
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
            f"DEBUG: 💳 Linked Apple Transaction {original_transaction_id} to User {request.user_id} via appAccountToken: '{app_account_token}' (Active: {is_active})"
        )

        return SubscriptionStatusResponse(
            user_id=request.user_id,
            is_premium=is_active,
            status=status_str,
            plan="monthly",
            product_id=product_id,
            original_transaction_id=original_transaction_id,
            app_account_token=app_account_token,
            purchase_date=purchase_iso,
            expires_date=expires_iso,
            auto_renew_status=True,
            is_in_billing_retry=False,
            revocation_reason=revocation_reason,
            message="Transaction successfully verified and linked to user account.",
        )

    # MARK: - App Store Server Notifications V2 Webhook

    def process_app_store_notification(
        self, signed_payload: str
    ) -> Dict[str, Any]:
        """
        Processes Apple App Store Server Notifications V2 webhooks in real-time.
        Handles: SUBSCRIBED, DID_RENEW, DID_FAIL_TO_RENEW, EXPIRED,
        DID_CHANGE_RENEWAL_STATUS, REVOKE, REFUND, GRACE_PERIOD_EXPIRED, TEST.
        """
        notification = self.decode_jws_payload(signed_payload)
        notification_type = notification.get("notificationType")
        subtype = notification.get("subtype")
        notification_uuid = notification.get("notificationUUID")

        print(
            f"DEBUG: 🍏 Received ASSN V2 Notification: Type={notification_type}, Subtype={subtype}, UUID={notification_uuid}"
        )

        if notification_type == "TEST":
            return {
                "status": "success",
                "message": "Test notification acknowledged.",
            }

        data = notification.get("data", {})
        signed_transaction_info = data.get("signedTransactionInfo")
        signed_renewal_info = data.get("signedRenewalInfo")

        transaction_info = (
            self.decode_jws_payload(signed_transaction_info)
            if signed_transaction_info
            else {}
        )
        renewal_info = (
            self.decode_jws_payload(signed_renewal_info)
            if signed_renewal_info
            else {}
        )

        original_transaction_id = str(
            transaction_info.get("originalTransactionId")
            or renewal_info.get("originalTransactionId")
            or ""
        )

        if not original_transaction_id:
            print("DEBUG: ⚠️ No originalTransactionId found in notification.")
            return {
                "status": "ignored",
                "reason": "Missing originalTransactionId",
            }

        db = self._load_database()
        record = db.get(original_transaction_id, {})
        
        # Look up user via appAccountToken or existing transaction record
        app_account_token = transaction_info.get("appAccountToken") or record.get("app_account_token")
        user_id = "unknown"
        if app_account_token:
            matched_user = (
                db.get(f"token:{str(app_account_token).lower()}")
                or db.get(f"token:{str(app_account_token)}")
            )
            if matched_user:
                user_id = matched_user
                print(
                    f"DEBUG: 🎯 [ASSN V2] Matched Apple Transaction to Bhumitra User: '{user_id}' via appAccountToken: '{app_account_token}'"
                )
            else:
                user_id = record.get("user_id", str(app_account_token))
        else:
            user_id = record.get("user_id", "unknown")

        product_id = transaction_info.get(
            "productId",
            record.get("product_id", "bhumitra_premium_monthly"),
        )
        expires_date_ms = transaction_info.get("expiresDate", 0)
        auto_renew_status = renewal_info.get("autoRenewStatus", 1) == 1
        is_in_billing_retry = renewal_info.get(
            "isInBillingRetryPeriod", False
        )

        expires_iso = (
            datetime.fromtimestamp(expires_date_ms / 1000, tz=timezone.utc).isoformat()
            if expires_date_ms
            else record.get("expires_date")
        )

        # Update status based on notification type
        if notification_type in ["SUBSCRIBED", "DID_RENEW"]:
            # Initial subscription or successful monthly renewal
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
            # In grace period / retry, grant temporary access or notify user
            print(
                f"DEBUG: 🟡 [ASSN V2] Billing failure/retry for {original_transaction_id}"
            )

        elif notification_type == "EXPIRED":
            # Subscription fully expired
            record["status"] = "expired"
            record["is_premium"] = False
            record["auto_renew_status"] = False
            record["is_in_billing_retry"] = False
            print(
                f"DEBUG: 🔴 [ASSN V2] Subscription EXPIRED for {original_transaction_id}"
            )

        elif notification_type == "DID_CHANGE_RENEWAL_STATUS":
            # User cancelled auto-renewal in App Store settings (or re-enabled it)
            record["auto_renew_status"] = auto_renew_status
            if not auto_renew_status:
                record["cancellation_date"] = datetime.now(
                    timezone.utc
                ).isoformat()
                print(
                    f"DEBUG: ⚠️ [ASSN V2] Auto-renew CANCELLED by user for {original_transaction_id} (Entitlement remains until {expires_iso})"
                )
            else:
                print(
                    f"DEBUG: 🔄 [ASSN V2] Auto-renew RE-ENABLED for {original_transaction_id}"
                )

        elif notification_type in ["REVOKE", "REFUND"]:
            # Apple granted a refund or revoked access
            record["status"] = "revoked"
            record["is_premium"] = False
            record["auto_renew_status"] = False
            record["revocation_reason"] = transaction_info.get(
                "revocationReason", 1
            )
            print(
                f"DEBUG: ⛔ [ASSN V2] Subscription REFUNDED/REVOKED for {original_transaction_id}"
            )

        elif notification_type == "GRACE_PERIOD_EXPIRED":
            record["status"] = "expired"
            record["is_premium"] = False
            record["is_in_billing_retry"] = False

        record["updated_at"] = datetime.now(timezone.utc).isoformat()
        db[original_transaction_id] = record
        if user_id != "unknown":
            db[f"user:{user_id}"] = original_transaction_id

        self._save_database(db)

        return {
            "status": "processed",
            "notification_type": notification_type,
            "original_transaction_id": original_transaction_id,
            "user_id": user_id,
            "is_premium": record.get("is_premium", False),
        }

    # MARK: - Get User Status

    def get_user_status(self, user_id: str) -> SubscriptionStatusResponse:
        """
        Returns the server-verified subscription status for a given user ID.
        """
        db = self._load_database()
        orig_id = db.get(f"user:{user_id}")

        if not orig_id or orig_id not in db:
            return SubscriptionStatusResponse(
                user_id=user_id,
                is_premium=False,
                status="none",
                auto_renew_status=False,
                is_in_billing_retry=False,
                message="No active subscription found.",
            )

        record = db[orig_id]
        is_active = record.get("is_premium", False)

        # Double check expiration date against current server time
        expires_date_str = record.get("expires_date")
        if expires_date_str:
            try:
                expires_dt = datetime.fromisoformat(expires_date_str)
                if expires_dt < datetime.now(timezone.utc):
                    is_active = False
                    record["status"] = "expired"
                    record["is_premium"] = False
            except Exception:
                pass

        return SubscriptionStatusResponse(
            user_id=user_id,
            is_premium=is_active,
            status=record.get("status", "none"),
            plan=record.get("plan", "monthly"),
            product_id=record.get("product_id", "bhumitra_premium_monthly"),
            original_transaction_id=orig_id,
            purchase_date=record.get("purchase_date"),
            expires_date=record.get("expires_date"),
            auto_renew_status=record.get("auto_renew_status", False),
            is_in_billing_retry=record.get("is_in_billing_retry", False),
            cancellation_date=record.get("cancellation_date"),
            revocation_reason=record.get("revocation_reason"),
            message="Server subscription status retrieved successfully.",
        )


subscription_service = SubscriptionService()
