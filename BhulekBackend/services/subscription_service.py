"""
Subscription Service - PostgreSQL Database Source of Truth
Replaces file-based JSON persistence with transactional database operations,
Apple StoreKit 2 verification, audit logging, and ASSN V2 durable webhook idempotency.
"""

import os
from datetime import datetime, timezone
from typing import Dict, Any, Optional

from sqlalchemy import func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from db.session import get_db_session
from models.db_models import (
    UserDB,
    SubscriptionDB,
    TransactionDB,
    SubscriptionEventDB,
    ConsumableTransactionDB,
    CreditLedgerDB,
    generate_uuid,
)
from models.subscription_models import (
    SubscriptionStatusResponse,
    SubscriptionVerifyRequest,
    ConsumablePurchaseResponse,
    UserCreditsResponse,
)
from services.apple_verification_service import (
    apple_verification_service,
    AppleVerificationError,
)

# Product Mappings
CONSUMABLE_PRODUCT_CREDITS: Dict[str, int] = {
    "bhumitra.plots.10": 10,
    "bhumitra.plots.50": 50,
    "bhumitra.plots.200": 200,
}

SUBSCRIPTION_PRODUCT_PLANS: Dict[str, str] = {
    "bhumitra.unlimited.monthly": "monthly",
}


def _ensure_utc(dt: Optional[datetime]) -> Optional[datetime]:
    """Ensures datetime is timezone-aware UTC for database compatibility."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


class SubscriptionService:
    def __init__(self):
        pass

    # MARK: - StoreKit 2 Client Verification & Linking

    def verify_and_link_transaction(
        self, request: SubscriptionVerifyRequest
    ) -> SubscriptionStatusResponse:
        """
        Cryptographically verifies a StoreKit 2 transaction submitted by the iOS client,
        validates claims, and atomically upserts User, Subscription, and Transaction in PostgreSQL.
        """
        # Cryptographic verification against Apple Root CA & strict claim validation
        decoded = apple_verification_service.verify_and_decode_transaction(
            signed_transaction_jws=request.signed_transaction_jws,
            expected_app_account_token=request.app_account_token,
        )

        original_transaction_id = str(decoded.originalTransactionId or "")
        transaction_id = str(decoded.transactionId or original_transaction_id)
        product_id = str(decoded.productId or "bhumitra.unlimited.monthly")
        purchase_date_ms = decoded.purchaseDate or 0
        expires_date_ms = decoded.expiresDate or 0
        revocation_date_ms = decoded.revocationDate
        revocation_reason_val = (
            decoded.revocationReason.value
            if hasattr(decoded.revocationReason, "value")
            else decoded.revocationReason
        )
        revocation_reason_str = str(revocation_reason_val) if revocation_reason_val is not None else None
        app_account_token = str(
            decoded.appAccountToken or request.app_account_token or ""
        )
        environment_str = (
            decoded.environment.value
            if hasattr(decoded.environment, "value")
            else str(decoded.environment)
        )
        transaction_type_str = (
            decoded.type.value
            if hasattr(decoded.type, "value")
            else str(decoded.type)
        )

        # Check if product is a consumable pack
        if product_id in CONSUMABLE_PRODUCT_CREDITS:
            raise AppleVerificationError(
                f"Product '{product_id}' is a consumable credit pack. Please use the /subscription/credits/purchase endpoint.",
                status_code=400,
                details={"product_id": product_id},
            )

        if product_id not in SUBSCRIPTION_PRODUCT_PLANS:
            raise AppleVerificationError(
                f"Unauthorized or unknown subscription product ID: '{product_id}'",
                status_code=422,
                details={"product_id": product_id},
            )

        # Plan evaluation
        plan_name = SUBSCRIPTION_PRODUCT_PLANS[product_id]
        is_lifetime = plan_name == "lifetime"

        # Datetime conversions (UTC)
        purchase_dt = (
            datetime.fromtimestamp(purchase_date_ms / 1000, tz=timezone.utc)
            if purchase_date_ms
            else None
        )
        expires_dt = (
            datetime.fromtimestamp(expires_date_ms / 1000, tz=timezone.utc)
            if expires_date_ms and not is_lifetime
            else None
        )
        revocation_dt = (
            datetime.fromtimestamp(revocation_date_ms / 1000, tz=timezone.utc)
            if revocation_date_ms
            else None
        )

        # Evaluate live validity
        now = datetime.now(timezone.utc)
        is_revoked = revocation_dt is not None
        is_expired = (expires_dt is not None) and (expires_dt < now)
        is_active = (not is_revoked) and (not is_expired)

        status_str = "active"
        if is_revoked:
            status_str = "revoked"
        elif is_expired:
            status_str = "expired"

        # Atomic PostgreSQL Transaction
        with get_db_session() as db:
            # 1. Upsert User
            user = db.query(UserDB).filter(UserDB.id == request.user_id).first()
            if not user:
                user = UserDB(
                    id=request.user_id,
                    app_account_token=app_account_token if app_account_token else None,
                )
                db.add(user)
                db.flush()
            elif app_account_token and not user.app_account_token:
                user.app_account_token = app_account_token
                user.updated_at = now

            # 2. Upsert Subscription (keyed by original_transaction_id)
            subscription = (
                db.query(SubscriptionDB)
                .filter(SubscriptionDB.original_transaction_id == original_transaction_id)
                .first()
            )

            if not subscription:
                subscription = SubscriptionDB(
                    user_id=user.id,
                    product_id=product_id,
                    plan=plan_name,
                    original_transaction_id=original_transaction_id,
                    latest_transaction_id=transaction_id,
                    app_account_token=app_account_token,
                    status=status_str,
                    environment=environment_str,
                    purchase_date=purchase_dt,
                    expires_at=expires_dt,
                    auto_renew_status=not is_lifetime,
                    is_in_billing_retry=False,
                    revocation_date=revocation_dt,
                    revocation_reason=revocation_reason_str,
                )
                db.add(subscription)
                db.flush()
            else:
                # Rebind user if appAccountToken links to this user
                subscription.user_id = user.id
                subscription.latest_transaction_id = transaction_id
                subscription.product_id = product_id
                subscription.plan = plan_name
                subscription.app_account_token = app_account_token or subscription.app_account_token
                subscription.status = status_str
                subscription.environment = environment_str
                subscription.purchase_date = purchase_dt or subscription.purchase_date
                subscription.expires_at = expires_dt
                subscription.auto_renew_status = not is_lifetime
                subscription.revocation_date = revocation_dt
                subscription.revocation_reason = revocation_reason_str
                subscription.updated_at = now

            # 3. Insert / Audit Transaction
            existing_tx = db.query(TransactionDB).filter(TransactionDB.id == transaction_id).first()
            if not existing_tx:
                tx_record = TransactionDB(
                    id=transaction_id,
                    original_transaction_id=original_transaction_id,
                    user_id=user.id,
                    subscription_id=subscription.id,
                    product_id=product_id,
                    environment=environment_str,
                    transaction_type=transaction_type_str,
                    app_account_token=app_account_token if app_account_token else None,
                    verification_state="verified",
                    delivery_state="delivered",
                    credits_granted=0,
                    purchase_date=purchase_dt,
                    expiration_date=expires_dt,
                    revocation_date=revocation_dt,
                    revocation_reason=revocation_reason_str,
                    updated_at=now,
                )
                db.add(tx_record)
            else:
                existing_tx.verification_state = "verified"
                existing_tx.delivery_state = "delivered"
                existing_tx.expiration_date = expires_dt
                existing_tx.revocation_date = revocation_dt
                existing_tx.revocation_reason = revocation_reason_str
                existing_tx.updated_at = now

        print(
            f"DEBUG: 🐘 [PostgreSQL] Stored Apple Subscription for user '{request.user_id}' (Tx: {original_transaction_id}, Plan: {plan_name}, Status: {status_str})"
        )

        return SubscriptionStatusResponse(
            user_id=request.user_id,
            is_premium=is_active,
            status=status_str,
            plan=plan_name,
            product_id=product_id,
            original_transaction_id=original_transaction_id,
            app_account_token=app_account_token,
            purchase_date=purchase_dt.isoformat() if purchase_dt else None,
            expires_date=expires_dt.isoformat() if expires_dt else None,
            auto_renew_status=not is_lifetime,
            is_in_billing_retry=False,
            revocation_reason=revocation_reason_val if isinstance(revocation_reason_val, int) else None,
            message="Apple transaction verified and persisted in PostgreSQL database.",
        )

    # MARK: - App Store Server Notifications V2 Webhook

    def process_app_store_notification(
        self, signed_payload: str
    ) -> Dict[str, Any]:
        """
        Cryptographically verifies ASSN V2 notification and enforces durable idempotency
        via SubscriptionEventDB unique constraint on notification_uuid in PostgreSQL.
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
        now = datetime.now(timezone.utc)

        print(
            f"DEBUG: 🍏 [ASSN V2 Webhook] Received Verified Event: Type={notification_type}, Subtype={subtype}, UUID={notification_uuid}"
        )

        # 1. Check Durable Idempotency in PostgreSQL
        with get_db_session() as db:
            existing_event = (
                db.query(SubscriptionEventDB)
                .filter(SubscriptionEventDB.notification_uuid == notification_uuid)
                .first()
            )
            if existing_event:
                print(f"DEBUG: 🔁 [ASSN V2] Duplicate webhook {notification_uuid} detected in PostgreSQL. Returning idempotent response.")
                return {
                    "status": "already_processed",
                    "notification_type": notification_type,
                    "notification_uuid": notification_uuid,
                }

        data = decoded_notification.data
        if not data:
            with get_db_session() as db:
                event_log = SubscriptionEventDB(
                    notification_uuid=notification_uuid,
                    notification_type=notification_type,
                    subtype=subtype,
                    environment=str(decoded_notification.summary.environment) if decoded_notification.summary else None,
                    status="processed",
                    processed_at=now,
                )
                db.add(event_log)
            return {
                "status": "processed",
                "notification_type": notification_type,
                "message": "Notification logged (no data payload)",
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
            with get_db_session() as db:
                event_log = SubscriptionEventDB(
                    notification_uuid=notification_uuid,
                    notification_type=notification_type,
                    subtype=subtype,
                    status="ignored",
                    error_message="Missing originalTransactionId",
                    processed_at=now,
                )
                db.add(event_log)
            return {
                "status": "ignored",
                "reason": "Missing originalTransactionId",
            }

        # Atomic PostgreSQL Update
        with get_db_session() as db:
            subscription = (
                db.query(SubscriptionDB)
                .filter(SubscriptionDB.original_transaction_id == original_transaction_id)
                .first()
            )

            # Resolve user from appAccountToken if subscription not yet created
            app_account_token = None
            if transaction_info and transaction_info.appAccountToken:
                app_account_token = str(transaction_info.appAccountToken)

            # Process dates & fields
            product_id = (
                str(transaction_info.productId)
                if transaction_info and transaction_info.productId
                else (subscription.product_id if subscription else "bhumitra.unlimited.monthly")
            )
            # Credit packs also send notifications (ONE_TIME_CHARGE, REFUND...).
            # They must never create or change a subscription.
            is_subscription_product = product_id in SUBSCRIPTION_PRODUCT_PLANS

            user = None
            if subscription:
                user = db.query(UserDB).filter(UserDB.id == subscription.user_id).first()
            elif app_account_token and is_subscription_product:
                # Only link to a real, existing account. Never invent a user from a
                # token: that made ghost "Unlimited" accounts. If the token is a
                # guest wallet merged into an account, the subscription belongs to
                # that account. Unknown tokens wait for the app's /verify call.
                token_owner = (
                    db.query(UserDB)
                    .filter(func.lower(UserDB.app_account_token) == app_account_token.strip().lower())
                    .first()
                )
                if token_owner and token_owner.merged_into_user_id:
                    token_owner = db.query(UserDB).filter(UserDB.id == token_owner.merged_into_user_id).first() or token_owner
                user = token_owner
            expires_date_ms = transaction_info.expiresDate if transaction_info and transaction_info.expiresDate else 0
            expires_dt = (
                datetime.fromtimestamp(expires_date_ms / 1000, tz=timezone.utc)
                if expires_date_ms
                else (subscription.expires_at if subscription else None)
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

            env_value = getattr(data.environment, "value", None) or str(data.environment or "")
            if not subscription and user and is_subscription_product and expires_dt is not None:
                subscription = SubscriptionDB(
                    user_id=user.id,
                    product_id=product_id,
                    plan="monthly" if "monthly" in product_id else ("yearly" if "yearly" in product_id else "lifetime"),
                    original_transaction_id=original_transaction_id,
                    latest_transaction_id=str(transaction_info.transactionId) if transaction_info else original_transaction_id,
                    app_account_token=app_account_token,
                    status="active",
                    environment=env_value,
                    expires_at=expires_dt,
                    auto_renew_status=auto_renew_status,
                    is_in_billing_retry=is_in_billing_retry,
                )
                db.add(subscription)
                db.flush()

            # Apply state machine transitions based on notificationType
            if subscription and subscription.product_id in SUBSCRIPTION_PRODUCT_PLANS:
                if notification_type in ["SUBSCRIBED", "DID_RENEW"]:
                    subscription.status = "active"
                    subscription.expires_at = expires_dt
                    subscription.auto_renew_status = True
                    subscription.is_in_billing_retry = False
                    subscription.updated_at = now
                    print(f"DEBUG: 🟢 [ASSN V2] DB Subscription ACTIVE/RENEWED for {original_transaction_id}")

                elif notification_type == "DID_FAIL_TO_RENEW":
                    subscription.status = "in_billing_retry"
                    subscription.is_in_billing_retry = True
                    subscription.updated_at = now
                    print(f"DEBUG: 🟡 [ASSN V2] DB Subscription in billing retry for {original_transaction_id}")

                elif notification_type == "DID_CHANGE_RENEWAL_STATUS":
                    subscription.auto_renew_status = auto_renew_status
                    subscription.updated_at = now
                    print(f"DEBUG: ℹ️ [ASSN V2] DB Auto-renew updated for {original_transaction_id}: {auto_renew_status}")

                elif notification_type in ["REVOKE", "REFUND"]:
                    subscription.status = "revoked"
                    subscription.revocation_date = now
                    subscription.revocation_reason = (
                        str(transaction_info.revocationReason.value)
                        if transaction_info and hasattr(transaction_info.revocationReason, "value")
                        else "1"
                    )
                    subscription.updated_at = now
                    print(f"DEBUG: ⛔ [ASSN V2] DB Subscription REFUNDED/REVOKED for {original_transaction_id}")

                elif notification_type in ["EXPIRED", "GRACE_PERIOD_EXPIRED"]:
                    subscription.status = "expired"
                    subscription.updated_at = now
                    print(f"DEBUG: ⌛ [ASSN V2] DB Subscription EXPIRED for {original_transaction_id}")

                elif notification_type == "TEST":
                    print("DEBUG: 🧪 [ASSN V2] Received Apple Test Webhook.")

            # Check consumable transaction effects if applicable
            cons = db.query(ConsumableTransactionDB).filter(
                or_(
                    ConsumableTransactionDB.original_transaction_id == original_transaction_id,
                    ConsumableTransactionDB.transaction_id == original_transaction_id,
                )
            ).first()
            if cons:
                if notification_type in ["REVOKE", "REFUND"]:
                    if cons.delivery_state != "revoked":
                        cons.delivery_state = "revoked"
                        cons.revocation_date = now
                        cons.revocation_reason = (
                            str(transaction_info.revocationReason.value)
                            if transaction_info and hasattr(transaction_info.revocationReason, "value")
                            else "apple_webhook_refund"
                        )
                        cons.updated_at = now
                        # Deduct unconsumed credits from user, never going below zero
                        user_rec = db.query(UserDB).filter(UserDB.id == cons.user_id).first()
                        if user_rec:
                            deducted = min(user_rec.plot_credits or 0, cons.credits_granted)
                            user_rec.plot_credits = max(0, (user_rec.plot_credits or 0) - deducted)
                            user_rec.updated_at = now
                            new_bal = (user_rec.free_credits or 0) + (user_rec.plot_credits or 0)
                            consumed = cons.credits_granted - deducted
                            ledger_entry = CreditLedgerDB(
                                id=generate_uuid(),
                                user_id=user_rec.id,
                                entry_type="REFUND_REVERSAL",
                                amount=-deducted,
                                balance_after=new_bal,
                                reference_id=cons.transaction_id,
                                reason=f"Apple ASSN V2 {notification_type} (granted={cons.credits_granted}, clawed_back={deducted}, consumed={consumed})",
                                admin_id="apple_assn_v2",
                                created_at=now,
                            )
                            db.add(ledger_entry)
                        print(f"DEBUG: ⛔ [ASSN V2] DB Consumable REFUNDED/REVOKED for {cons.transaction_id}")
                elif notification_type == "CONSUMPTION_REQUEST":
                    # Apple is requesting customer consumption data prior to deciding on a refund.
                    # This does NOT indicate a refund has been granted. No credits are deducted.
                    print(f"DEBUG: ℹ️ [ASSN V2] DB Consumable CONSUMPTION_REQUEST received for {cons.transaction_id}. No refund executed.")

            # Record Transaction Audit row if transaction_info is present
            if transaction_info and subscription:
                tx_id = str(transaction_info.transactionId or original_transaction_id)
                existing_tx = db.query(TransactionDB).filter(TransactionDB.id == tx_id).first()
                if not existing_tx:
                    purchase_date_ms = transaction_info.purchaseDate or 0
                    purchase_dt = (
                        datetime.fromtimestamp(purchase_date_ms / 1000, tz=timezone.utc)
                        if purchase_date_ms
                        else None
                    )
                    db.add(
                        TransactionDB(
                            id=tx_id,
                            original_transaction_id=original_transaction_id,
                            user_id=subscription.user_id,
                            subscription_id=subscription.id,
                            product_id=product_id,
                            environment=env_value,
                            purchase_date=purchase_dt,
                            expiration_date=expires_dt,
                        )
                    )

            # Insert Durable Event Record into SubscriptionEventDB (enforces unique notification_uuid)
            event_log = SubscriptionEventDB(
                notification_uuid=notification_uuid,
                notification_type=notification_type,
                subtype=subtype,
                environment=(getattr(data.environment, "value", None) or str(data.environment)) if data else None,
                original_transaction_id=original_transaction_id,
                status="processed",
                processed_at=now,
            )
            db.add(event_log)

            # Extract fields inside session context
            result_user_id = subscription.user_id if subscription else (cons.user_id if cons else "unknown")
            result_is_premium = (subscription.status == "active") if subscription else False

            return {
                "status": "processed",
                "notification_type": notification_type,
                "original_transaction_id": original_transaction_id,
                "user_id": result_user_id,
                "is_premium": result_is_premium,
            }

    # MARK: - User Status Query

    def get_user_status(self, user_id: str) -> SubscriptionStatusResponse:
        """
        Retrieves live server-authoritative subscription status from PostgreSQL.
        """
        with get_db_session() as db:
            # Query user
            user = db.query(UserDB).filter(UserDB.id == user_id).first()
            subscription = None

            if user:
                subscription = (
                    db.query(SubscriptionDB)
                    .filter(SubscriptionDB.user_id == user.id)
                    .order_by(SubscriptionDB.updated_at.desc())
                    .first()
                )

            if not subscription and user and user.app_account_token:
                # Search by appAccountToken in case user reinstalled
                subscription = (
                    db.query(SubscriptionDB)
                    .filter(SubscriptionDB.app_account_token == user.app_account_token)
                    .order_by(SubscriptionDB.updated_at.desc())
                    .first()
                )

            if not subscription:
                return SubscriptionStatusResponse(
                    user_id=user_id,
                    is_premium=False,
                    status="none",
                    message="No subscription found for user in database.",
                )

            # Re-evaluate live expiry against current timestamp
            now = datetime.now(timezone.utc)
            is_lifetime = subscription.plan == "lifetime"
            is_revoked = subscription.status == "revoked" or (subscription.revocation_date is not None)
            
            sub_expires_at = _ensure_utc(subscription.expires_at)
            is_expired = (not is_lifetime) and (sub_expires_at is not None) and (sub_expires_at < now)
            
            if is_revoked:
                status_str = "revoked"
                is_active = False
            elif is_expired:
                status_str = "expired"
                is_active = False
                if subscription.status != "expired":
                    subscription.status = "expired"
                    subscription.updated_at = now
            else:
                status_str = subscription.status
                is_active = (status_str == "active")

            rev_reason_int = None
            if subscription.revocation_reason:
                try:
                    rev_reason_int = int(subscription.revocation_reason)
                except ValueError:
                    pass

            # Extract fields safely before session closes
            plan_val = subscription.plan
            product_id_val = subscription.product_id
            orig_tx_val = subscription.original_transaction_id
            token_val = subscription.app_account_token
            purchase_iso = subscription.purchase_date.isoformat() if subscription.purchase_date else None
            expires_iso = subscription.expires_at.isoformat() if subscription.expires_at else None
            auto_renew_val = subscription.auto_renew_status
            billing_retry_val = subscription.is_in_billing_retry

            return SubscriptionStatusResponse(
                user_id=user_id,
                is_premium=is_active,
                status=status_str,
                plan=plan_val,
                product_id=product_id_val,
                original_transaction_id=orig_tx_val,
                app_account_token=token_val,
                purchase_date=purchase_iso,
                expires_date=expires_iso,
                auto_renew_status=auto_renew_val,
                is_in_billing_retry=billing_retry_val,
                revocation_reason=rev_reason_int,
                message="Server-authoritative subscription status retrieved from PostgreSQL.",
            )

    # MARK: - Consumable Purchases (Plot Credits)

    def process_consumable_purchase(
        self,
        user_id: str,
        signed_transaction_jws: str,
        expected_app_account_token: Optional[str] = None,
    ) -> ConsumablePurchaseResponse:
        """
        Cryptographically verifies an Apple StoreKit 2 consumable transaction,
        validates the product ID against exact consumable mappings (bhumitra.plots.10 -> 10, etc.),
        and atomically credits the user balance with strict idempotency.
        """
        decoded = apple_verification_service.verify_and_decode_transaction(
            signed_transaction_jws=signed_transaction_jws,
            expected_app_account_token=expected_app_account_token,
        )

        product_id = str(decoded.productId or "")

        # Check if transaction is for a subscription product
        if product_id in SUBSCRIPTION_PRODUCT_PLANS:
            raise AppleVerificationError(
                f"Product '{product_id}' is a subscription. Use the /subscription/verify endpoint for subscription entitlements.",
                status_code=400,
                details={"product_id": product_id},
            )

        # Check if product is an allowed consumable
        if product_id not in CONSUMABLE_PRODUCT_CREDITS:
            raise AppleVerificationError(
                f"Unauthorized or unknown consumable product ID: '{product_id}'",
                status_code=422,
                details={"product_id": product_id},
            )

        credits_to_grant = CONSUMABLE_PRODUCT_CREDITS[product_id]
        transaction_id = str(decoded.transactionId or "").strip()
        if not transaction_id:
            raise AppleVerificationError(
                "Missing transactionId in verified Apple transaction payload. Original transaction ID cannot be used as consumable idempotency key.",
                status_code=400,
            )
        original_transaction_id = str(decoded.originalTransactionId or transaction_id).strip()

        purchase_date_ms = decoded.purchaseDate or 0
        purchase_dt = (
            datetime.fromtimestamp(purchase_date_ms / 1000, tz=timezone.utc)
            if purchase_date_ms
            else None
        )
        environment_str = (
            decoded.environment.value
            if hasattr(decoded.environment, "value")
            else str(decoded.environment)
        )
        app_account_token = str(
            decoded.appAccountToken or expected_app_account_token or ""
        )
        now = datetime.now(timezone.utc)

        if not user_id or user_id.startswith("anon_") or user_id == "anonymous_device":
            raise AppleVerificationError(
                "An authenticated user session is strictly required for consumable purchases.",
                status_code=401,
            )

        # Atomic PostgreSQL Transaction with strict idempotency.
        #
        # Production/Sandbox: Apple guarantees a globally-unique transactionId per
        # purchase, so it is used directly as the idempotency key.
        #
        # Xcode/LocalTesting: the local StoreKit test environment reuses low
        # transaction IDs (0, 1, 2, ...) across sessions AND may report a zero /
        # missing purchaseDate. The previous implementation only appended the
        # purchase-date suffix when purchase_date_ms was truthy, so a second local
        # test purchase with a repeated transactionId and a zero purchaseDate
        # collapsed to a bare, already-seen key and was wrongly rejected as
        # "already processed" (crediting 0). To make every local test purchase
        # unique we always append a disambiguating suffix, preferring stable Apple
        # fields (webOrderLineItemId, signedDate, purchaseDate) and finally a random
        # UUID so two purchases can never collide. This path never runs in
        # Production/Sandbox, so real idempotency is unaffected.
        if environment_str in ["Xcode", "LocalTesting"] and os.environ.get("ENV", "development").strip().lower() == "production":
            # Defense in depth: unsigned local StoreKit transactions never credit in production.
            raise AppleVerificationError(
                "Local StoreKit test transactions are not accepted in production.",
                status_code=400,
            )
        if environment_str in ["Xcode", "LocalTesting"]:
            local_suffix = (
                str(getattr(decoded, "webOrderLineItemId", None) or "")
                or (str(int(decoded.signedDate)) if getattr(decoded, "signedDate", None) else "")
                or (str(int(purchase_date_ms)) if purchase_date_ms else "")
                or generate_uuid()
            )
            db_tx_key = f"{transaction_id}_{local_suffix}"
        else:
            db_tx_key = transaction_id

        with get_db_session() as db:
            # 1. Check if transaction was already processed
            existing_tx = (
                db.query(ConsumableTransactionDB)
                .filter(ConsumableTransactionDB.transaction_id == db_tx_key)
                .first()
            )
            if existing_tx:
                # Cross-user guard: this exact Apple transaction was already
                # processed. If it was credited to a DIFFERENT user, we must NOT
                # silently return a 0-credit "success" — that leaves the tapping
                # user with nothing while looking like it worked (the "balance up
                # to date (0)" symptom). Surface an explicit conflict instead so
                # the client can show a real error and the credits can't be
                # double-claimed by two accounts. A guest wallet merged into this
                # account counts as the same wallet.
                from services.wallet_service import wallet_member_ids
                if existing_tx.user_id and existing_tx.user_id not in wallet_member_ids(db, user_id):
                    raise AppleVerificationError(
                        "This purchase is already linked to a different Bhumitra account and cannot be credited here.",
                        status_code=409,
                        details={
                            "transaction_id": transaction_id,
                            "reason": "cross_user_transaction",
                        },
                    )

                # Same-user replay → idempotent no-op (unchanged behavior).
                user = db.query(UserDB).filter(UserDB.id == user_id).first()
                current_balance = ((user.free_credits or 0) + (user.plot_credits or 0)) if user else 0
                return ConsumablePurchaseResponse(
                    user_id=user_id,
                    product_id=product_id,
                    credits_granted=0,
                    current_balance=current_balance,
                    transaction_id=transaction_id,
                    original_transaction_id=original_transaction_id,
                    already_processed=True,
                    purchase_date=purchase_dt.isoformat() if purchase_dt else None,
                    message="Transaction has already been processed.",
                )

            # 2. Lock User Row & Increment Balance
            user = db.query(UserDB).filter(UserDB.id == user_id).with_for_update().first()
            if not user:
                user = UserDB(
                    id=user_id,
                    app_account_token=app_account_token if app_account_token else None,
                    plot_credits=credits_to_grant,
                )
                db.add(user)
                db.flush()
            else:
                user.plot_credits += credits_to_grant
                if app_account_token and not user.app_account_token:
                    user.app_account_token = app_account_token
                user.updated_at = now

            # 3. Record immutable consumable transaction
            tx_record = ConsumableTransactionDB(
                id=generate_uuid(),
                transaction_id=db_tx_key,
                original_transaction_id=original_transaction_id,
                user_id=user.id,
                product_id=product_id,
                credits_granted=credits_to_grant,
                environment=environment_str,
                app_account_token=app_account_token if app_account_token else None,
                verification_state="verified",
                delivery_state="delivered",
                purchase_date=purchase_dt,
                created_at=now,
                updated_at=now,
            )
            db.add(tx_record)

            new_balance = (user.free_credits or 0) + (user.plot_credits or 0)

            # 4. Record immutable credit ledger entry
            ledger_entry = CreditLedgerDB(
                id=generate_uuid(),
                user_id=user.id,
                entry_type="PURCHASE",
                amount=credits_to_grant,
                balance_after=new_balance,
                reference_id=transaction_id,
                reason=f"StoreKit purchase: {product_id} (+{credits_to_grant} plot searches)",
                admin_id=None,
                created_at=now,
            )
            db.add(ledger_entry)

            try:
                db.flush()
            except IntegrityError:
                # Handle concurrent duplicate submission race condition. The unique
                # constraint fired because another request inserted the same
                # transaction first. Re-read the winning row and apply the same
                # cross-user guard as the pre-check.
                db.rollback()
                winning_tx = (
                    db.query(ConsumableTransactionDB)
                    .filter(ConsumableTransactionDB.transaction_id == db_tx_key)
                    .first()
                )
                from services.wallet_service import wallet_member_ids
                if winning_tx and winning_tx.user_id and winning_tx.user_id not in wallet_member_ids(db, user_id):
                    raise AppleVerificationError(
                        "This purchase is already linked to a different Bhumitra account and cannot be credited here.",
                        status_code=409,
                        details={
                            "transaction_id": transaction_id,
                            "reason": "cross_user_transaction",
                        },
                    )
                user = db.query(UserDB).filter(UserDB.id == user_id).first()
                current_balance = ((user.free_credits or 0) + (user.plot_credits or 0)) if user else 0
                return ConsumablePurchaseResponse(
                    user_id=user_id,
                    product_id=product_id,
                    credits_granted=0,
                    current_balance=current_balance,
                    transaction_id=transaction_id,
                    original_transaction_id=original_transaction_id,
                    already_processed=True,
                    purchase_date=purchase_dt.isoformat() if purchase_dt else None,
                    message="Transaction has already been processed.",
                )

        print(
            f"DEBUG: 💎 [PostgreSQL] Credited {credits_to_grant} plot credits to user '{user_id}' (Tx: {transaction_id}, New Balance: {new_balance})"
        )

        return ConsumablePurchaseResponse(
            user_id=user_id,
            product_id=product_id,
            credits_granted=credits_to_grant,
            current_balance=new_balance,
            transaction_id=transaction_id,
            original_transaction_id=original_transaction_id,
            already_processed=False,
            purchase_date=purchase_dt.isoformat() if purchase_dt else None,
            message=f"Successfully credited {credits_to_grant} plot searches.",
        )

    def get_user_credits(self, user_id: str, db: Optional[Session] = None) -> UserCreditsResponse:
        """
        Returns the server-authoritative plot search credit balance for the user.
        Calculates total available searches (one-time free grant remaining + purchased consumable credits).
        If user is an active unlimited subscriber, returns -1 with is_unlimited=True.
        """
        from services.usage_service import usage_service
        if db is not None:
            is_premium = usage_service.is_user_premium(user_id, db)
            user = db.query(UserDB).filter(UserDB.id == user_id).first()
            purchased_credits = (user.plot_credits or 0) if user else 0
            free_remaining = (user.free_credits or 0) if user else 0
            
            if is_premium:
                total_available = -1
                free_remaining = -1
            else:
                total_available = free_remaining + purchased_credits
            
            return UserCreditsResponse(
                user_id=user_id,
                credits=total_available,
                purchased_credits=purchased_credits,
                free_remaining=free_remaining,
                is_unlimited=is_premium,
            )

        with get_db_session() as session:
            is_premium = usage_service.is_user_premium(user_id, session)
            user = session.query(UserDB).filter(UserDB.id == user_id).first()
            purchased_credits = (user.plot_credits or 0) if user else 0
            free_remaining = (user.free_credits or 0) if user else 0
            
            if is_premium:
                total_available = -1
                free_remaining = -1
            else:
                total_available = free_remaining + purchased_credits
            
            return UserCreditsResponse(
                user_id=user_id,
                credits=total_available,
                purchased_credits=purchased_credits,
                free_remaining=free_remaining,
                is_unlimited=is_premium,
            )

    def reconstruct_user_balance_from_ledger(self, user_id: str, db: Optional[Session] = None) -> Dict[str, Any]:
        """
        Reconstructs the user's credit balance strictly by aggregating immutable CreditLedgerDB records.
        Returns total ledger balance, actual user balance, and balance integrity status.
        """
        def _compute(session: Session):
            entries = (
                session.query(CreditLedgerDB)
                .filter(CreditLedgerDB.user_id == user_id)
                .order_by(CreditLedgerDB.created_at.asc())
                .all()
            )
            reconstructed_balance = sum(e.amount for e in entries)
            user = session.query(UserDB).filter(UserDB.id == user_id).first()
            actual_balance = ((user.free_credits or 0) + (user.plot_credits or 0)) if user else 0
            return {
                "user_id": user_id,
                "reconstructed_balance": reconstructed_balance,
                "actual_balance": actual_balance,
                "is_balanced": reconstructed_balance == actual_balance,
                "total_entries": len(entries),
            }

        if db is not None:
            return _compute(db)
        with get_db_session() as session:
            return _compute(session)


# Shared singleton instance
subscription_service = SubscriptionService()
