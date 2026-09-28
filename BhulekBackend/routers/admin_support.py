"""
Admin Support Router for Bhumitra Payment & Entitlement Subsystem.
Strictly protected by X-Admin-Key authentication.
Enables support engineers to:
  - Search users
  - Inspect purchase history and Apple transaction IDs
  - Inspect live credit balances and immutable credit ledger audit trail
  - View subscription status
  - Perform audited manual credit adjustments with mandatory reason, amount, and admin identity
  - Re-sync / repair stuck Apple transactions
  - Record Apple-approved refunds and reversions
"""

import os
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from sqlalchemy import or_

from db.session import get_db
from models.db_models import (
    UserDB,
    SubscriptionDB,
    TransactionDB,
    ConsumableTransactionDB,
    CreditLedgerDB,
    generate_uuid,
)
from services.subscription_service import subscription_service

router = APIRouter(prefix="/admin", tags=["Admin Support"])

ADMIN_API_KEY = os.environ.get("ADMIN_API_KEY", "bhumitra_admin_secret_key_2026")


def require_admin(x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key")):
    """Validates X-Admin-Key header for sensitive operations."""
    if not x_admin_key or x_admin_key != ADMIN_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: Invalid or missing X-Admin-Key header.",
        )
    return True


# MARK: - Request / Response Models

class AdminUserSearchItem(BaseModel):
    id: str
    email: Optional[str]
    name: Optional[str]
    app_account_token: Optional[str]
    plot_credits: int
    free_credits: int
    total_balance: int
    is_premium: bool
    created_at: str


class CreditLedgerItem(BaseModel):
    id: str
    entry_type: str
    amount: int
    balance_after: int
    reference_id: Optional[str]
    reason: Optional[str]
    admin_id: Optional[str]
    created_at: str


class AdminUserCreditsResponse(BaseModel):
    user_id: str
    current_balance: int
    plot_credits: int
    free_credits: int
    is_unlimited: bool
    reconstructed_balance: int
    is_balanced: bool
    total_ledger_entries: int
    ledger_entries: List[CreditLedgerItem]


class AdminPurchaseItem(BaseModel):
    transaction_id: str
    original_transaction_id: str
    product_id: str
    product_type: str
    environment: str
    credits_granted: int
    verification_state: str
    delivery_state: str
    purchase_date: Optional[str]
    revocation_date: Optional[str]
    revocation_reason: Optional[str]
    created_at: str


class AdminCreditAdjustmentRequest(BaseModel):
    amount: int = Field(..., description="Signed credit adjustment delta (e.g. +10, -5)")
    reason: str = Field(..., min_length=5, description="Documented justification for adjustment")
    admin_id: str = Field(..., min_length=2, description="Identity/username of the performing administrator")
    entry_type: Optional[str] = Field("ADMIN_ADJUSTMENT", description="ADMIN_ADJUSTMENT or CORRECTION")


class AdminCreditAdjustmentResponse(BaseModel):
    status: str
    user_id: str
    adjustment: int
    new_balance: int
    ledger_entry_id: str
    reason: str
    admin_id: str
    timestamp: str


class AdminResyncRequest(BaseModel):
    transaction_id: str = Field(..., description="Apple transaction ID to repair")
    user_id: Optional[str] = Field(None, description="Bhumitra user ID if known")
    admin_id: str = Field(..., min_length=2)
    reason: str = Field(..., min_length=5)


class AdminRefundRecordRequest(BaseModel):
    original_transaction_id: str = Field(..., description="Apple originalTransactionId")
    transaction_id: Optional[str] = Field(None, description="Specific Apple transaction ID")
    reason: str = Field(..., min_length=5, description="Refund justification/Apple ticket reference")
    admin_id: str = Field(..., min_length=2)


# MARK: - Endpoints

@router.get(
    "/users/search",
    response_model=List[AdminUserSearchItem],
    summary="Admin: Search Users",
)
def admin_search_users(
    query: str,
    db: Session = Depends(get_db),
    _: bool = Depends(require_admin),
):
    """Searches users by ID, email, name, or app_account_token."""
    clean_q = query.strip()
    if not clean_q:
        return []

    users = (
        db.query(UserDB)
        .filter(
            or_(
                UserDB.id.ilike(f"%{clean_q}%"),
                UserDB.email.ilike(f"%{clean_q}%"),
                UserDB.name.ilike(f"%{clean_q}%"),
                UserDB.app_account_token.ilike(f"%{clean_q}%"),
            )
        )
        .limit(20)
        .all()
    )

    from services.usage_service import usage_service
    results = []
    for u in users:
        is_prem = usage_service.is_user_premium(u.id, db)
        tot = (u.free_credits or 0) + (u.plot_credits or 0)
        results.append(
            AdminUserSearchItem(
                id=u.id,
                email=u.email,
                name=u.name,
                app_account_token=u.app_account_token,
                plot_credits=u.plot_credits or 0,
                free_credits=u.free_credits or 0,
                total_balance=tot,
                is_premium=is_prem,
                created_at=u.created_at.isoformat() if u.created_at else "",
            )
        )
    return results


@router.get(
    "/users/{user_id}/purchases",
    response_model=List[AdminPurchaseItem],
    summary="Admin: View User Purchase History",
)
def admin_get_user_purchases(
    user_id: str,
    db: Session = Depends(get_db),
    _: bool = Depends(require_admin),
):
    """Retrieves all Apple transactions (consumable & subscription) associated with user."""
    user = db.query(UserDB).filter(UserDB.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"User '{user_id}' not found.")

    items = []

    # 1. Consumable transactions
    consumables = (
        db.query(ConsumableTransactionDB)
        .filter(ConsumableTransactionDB.user_id == user_id)
        .order_by(ConsumableTransactionDB.created_at.desc())
        .all()
    )
    for c in consumables:
        items.append(
            AdminPurchaseItem(
                transaction_id=c.transaction_id,
                original_transaction_id=c.original_transaction_id,
                product_id=c.product_id,
                product_type="consumable",
                environment=c.environment,
                credits_granted=c.credits_granted,
                verification_state=getattr(c, "verification_state", "verified"),
                delivery_state=getattr(c, "delivery_state", "delivered"),
                purchase_date=c.purchase_date.isoformat() if c.purchase_date else None,
                revocation_date=c.revocation_date.isoformat() if getattr(c, "revocation_date", None) else None,
                revocation_reason=getattr(c, "revocation_reason", None),
                created_at=c.created_at.isoformat(),
            )
        )

    # 2. Subscription transactions
    subs_txs = (
        db.query(TransactionDB)
        .filter(TransactionDB.user_id == user_id)
        .order_by(TransactionDB.created_at.desc())
        .all()
    )
    for s in subs_txs:
        items.append(
            AdminPurchaseItem(
                transaction_id=s.id,
                original_transaction_id=s.original_transaction_id,
                product_id=s.product_id,
                product_type="subscription",
                environment=s.environment,
                credits_granted=getattr(s, "credits_granted", 0),
                verification_state=getattr(s, "verification_state", "verified"),
                delivery_state=getattr(s, "delivery_state", "delivered"),
                purchase_date=s.purchase_date.isoformat() if s.purchase_date else None,
                revocation_date=s.revocation_date.isoformat() if s.revocation_date else None,
                revocation_reason=getattr(s, "revocation_reason", None),
                created_at=s.created_at.isoformat(),
            )
        )

    return items


@router.get(
    "/users/{user_id}/credits",
    response_model=AdminUserCreditsResponse,
    summary="Admin: View Credit Balance and Ledger Audit",
)
def admin_get_user_credits_ledger(
    user_id: str,
    db: Session = Depends(get_db),
    _: bool = Depends(require_admin),
):
    """Retrieves authoritative credit balance and full immutable credit ledger history."""
    user = db.query(UserDB).filter(UserDB.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"User '{user_id}' not found.")

    from services.usage_service import usage_service
    is_prem = usage_service.is_user_premium(user_id, db)
    tot = (user.free_credits or 0) + (user.plot_credits or 0)

    # Fetch ledger records
    ledger_rows = (
        db.query(CreditLedgerDB)
        .filter(CreditLedgerDB.user_id == user_id)
        .order_by(CreditLedgerDB.created_at.desc())
        .all()
    )

    reconstruction = subscription_service.reconstruct_user_balance_from_ledger(user_id, db=db)

    ledger_items = [
        CreditLedgerItem(
            id=r.id,
            entry_type=r.entry_type,
            amount=r.amount,
            balance_after=r.balance_after,
            reference_id=r.reference_id,
            reason=r.reason,
            admin_id=r.admin_id,
            created_at=r.created_at.isoformat(),
        )
        for r in ledger_rows
    ]

    return AdminUserCreditsResponse(
        user_id=user_id,
        current_balance=tot,
        plot_credits=user.plot_credits or 0,
        free_credits=user.free_credits or 0,
        is_unlimited=is_prem,
        reconstructed_balance=reconstruction["reconstructed_balance"],
        is_balanced=reconstruction["is_balanced"],
        total_ledger_entries=len(ledger_items),
        ledger_entries=ledger_items,
    )


@router.get(
    "/users/{user_id}/subscription",
    summary="Admin: View User Subscription Status",
)
def admin_get_user_subscription(
    user_id: str,
    db: Session = Depends(get_db),
    _: bool = Depends(require_admin),
):
    """Retrieves live server-authoritative subscription status."""
    return subscription_service.get_user_status(user_id)


@router.post(
    "/users/{user_id}/credits/adjust",
    response_model=AdminCreditAdjustmentResponse,
    summary="Admin: Manual Credit Grant or Correction",
)
def admin_adjust_user_credits(
    user_id: str,
    request: AdminCreditAdjustmentRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(require_admin),
):
    """
    Performs an audited manual credit adjustment for a user.
    Requires: amount, reason, admin_id, and records an immutable CreditLedgerDB entry.
    Prevents resulting in a negative balance.
    """
    now = datetime.now(timezone.utc)
    user = db.query(UserDB).filter(UserDB.id == user_id).with_for_update().first()
    if not user:
        raise HTTPException(status_code=404, detail=f"User '{user_id}' not found.")

    current_plot = user.plot_credits or 0
    current_free = user.free_credits or 0
    current_tot = current_plot + current_free
    new_tot = current_tot + request.amount

    if new_tot < 0:
        raise HTTPException(
            status_code=400,
            detail=f"Adjustment of {request.amount} would result in negative balance ({new_tot}). Minimum allowed is 0.",
        )

    # Apply adjustment to plot_credits
    user.plot_credits = max(0, current_plot + request.amount)
    user.updated_at = now

    entry_type = request.entry_type or "ADMIN_ADJUSTMENT"
    ledger_id = generate_uuid()

    ledger_entry = CreditLedgerDB(
        id=ledger_id,
        user_id=user.id,
        entry_type=entry_type,
        amount=request.amount,
        balance_after=(user.free_credits or 0) + (user.plot_credits or 0),
        reference_id=f"admin_{request.admin_id}_{int(now.timestamp())}",
        reason=request.reason,
        admin_id=request.admin_id,
        created_at=now,
    )
    db.add(ledger_entry)
    db.commit()

    print(
        f"[ADMIN_AUDIT] 🛡️ Credit adjustment: User='{user_id}', Delta={request.amount:+d}, NewBalance={ledger_entry.balance_after}, Admin='{request.admin_id}', Reason='{request.reason}'"
    )

    return AdminCreditAdjustmentResponse(
        status="success",
        user_id=user_id,
        adjustment=request.amount,
        new_balance=ledger_entry.balance_after,
        ledger_entry_id=ledger_id,
        reason=request.reason,
        admin_id=request.admin_id,
        timestamp=now.isoformat(),
    )


@router.post(
    "/transactions/resync",
    summary="Admin: Re-sync / Repair Apple Transaction",
)
def admin_resync_transaction(
    request: AdminResyncRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(require_admin),
):
    """
    Allows admin to inspect and force re-synchronization of an Apple transaction.
    """
    tx_id = request.transaction_id.strip()

    # Search in consumable transactions
    cons = db.query(ConsumableTransactionDB).filter(ConsumableTransactionDB.transaction_id == tx_id).first()
    if cons:
        cons.delivery_state = "delivered"
        cons.updated_at = datetime.now(timezone.utc)
        db.commit()
        return {
            "status": "repaired",
            "transaction_type": "consumable",
            "transaction_id": tx_id,
            "user_id": cons.user_id,
            "credits_granted": cons.credits_granted,
            "delivery_state": cons.delivery_state,
        }

    # Search in subscription transactions
    sub_tx = db.query(TransactionDB).filter(TransactionDB.id == tx_id).first()
    if sub_tx:
        sub_tx.delivery_state = "delivered"
        sub_tx.updated_at = datetime.now(timezone.utc)
        db.commit()
        return {
            "status": "repaired",
            "transaction_type": "subscription",
            "transaction_id": tx_id,
            "user_id": sub_tx.user_id,
            "delivery_state": sub_tx.delivery_state,
        }

    raise HTTPException(status_code=404, detail=f"Transaction '{tx_id}' not found in database.")


@router.post(
    "/refunds/record",
    summary="Admin: Record Apple Refund or Revocation",
)
def admin_record_refund(
    request: AdminRefundRecordRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(require_admin),
):
    """
    Records an Apple-approved refund or revocation, revoking subscription
    or deducting consumable credits with an immutable REFUND_REVERSAL ledger entry.
    """
    now = datetime.now(timezone.utc)
    orig_id = request.original_transaction_id.strip()

    # 1. Check subscriptions
    sub = db.query(SubscriptionDB).filter(SubscriptionDB.original_transaction_id == orig_id).first()
    if sub:
        if sub.status == "revoked":
            return {
                "status": "already_refunded",
                "type": "subscription",
                "original_transaction_id": orig_id,
                "user_id": sub.user_id,
                "subscription_status": "revoked",
            }
        sub.status = "revoked"
        sub.revocation_date = now
        sub.revocation_reason = "admin_refund_processed"
        sub.updated_at = now
        db.commit()
        return {
            "status": "refund_recorded",
            "type": "subscription",
            "original_transaction_id": orig_id,
            "user_id": sub.user_id,
            "subscription_status": "revoked",
        }

    # 2. Check consumables
    cons = db.query(ConsumableTransactionDB).filter(
        or_(
            ConsumableTransactionDB.original_transaction_id == orig_id,
            ConsumableTransactionDB.transaction_id == orig_id,
        )
    ).first()

    if cons:
        if cons.delivery_state == "revoked":
            return {
                "status": "already_refunded",
                "type": "consumable",
                "original_transaction_id": orig_id,
                "transaction_id": cons.transaction_id,
                "user_id": cons.user_id,
                "credits_deducted": 0,
                "delivery_state": "revoked",
            }

        cons.delivery_state = "revoked"
        cons.revocation_date = now
        cons.revocation_reason = request.reason
        cons.updated_at = now

        # Deduct unconsumed credits from user, never going below zero
        user = db.query(UserDB).filter(UserDB.id == cons.user_id).first()
        deducted = 0
        if user:
            deducted = min(user.plot_credits or 0, cons.credits_granted)
            user.plot_credits = max(0, (user.plot_credits or 0) - deducted)
            user.updated_at = now

            new_bal = (user.free_credits or 0) + (user.plot_credits or 0)
            consumed = cons.credits_granted - deducted
            ledger_entry = CreditLedgerDB(
                id=generate_uuid(),
                user_id=user.id,
                entry_type="REFUND_REVERSAL",
                amount=-deducted,
                balance_after=new_bal,
                reference_id=cons.transaction_id,
                reason=f"Apple refund: {request.reason} (granted={cons.credits_granted}, clawed_back={deducted}, consumed={consumed})",
                admin_id=request.admin_id,
                created_at=now,
            )
            db.add(ledger_entry)

        db.commit()
        return {
            "status": "refund_recorded",
            "type": "consumable",
            "original_transaction_id": orig_id,
            "transaction_id": cons.transaction_id,
            "user_id": cons.user_id,
            "credits_deducted": deducted,
            "credits_consumed": cons.credits_granted - deducted,
            "delivery_state": "revoked",
        }

    raise HTTPException(status_code=404, detail=f"No transaction found matching '{orig_id}'.")
