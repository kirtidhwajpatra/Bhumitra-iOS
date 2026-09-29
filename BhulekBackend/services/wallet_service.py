"""
Wallet: one balance per person, not per login.

A purchase made while signed out lands on the device's guest account
(dev_<device_id>). When that person signs in, their guest wallet is merged into
the account exactly once and keeps following it: purchased credits, credit-pack
transactions, Unlimited+ subscriptions and unlocked plots all move. The guest
row itself stays (marked merged) so the device can't claim free starter
searches again, and so Apple transactions still carrying the guest's
appAccountToken are recognised as belonging to the account.

Free starter searches are never moved: each account and device keeps its own
one-time grant, so merging can't double them.
"""
import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional, Set

from sqlalchemy.orm import Session

from db.session import get_db_session
from models.db_models import (
    AuthIdentityDB,
    ConsumableTransactionDB,
    CreditLedgerDB,
    SubscriptionDB,
    TransactionDB,
    UserDB,
    generate_uuid,
)

logger = logging.getLogger(__name__)

SIGNED_IN_PROVIDERS = ("apple", "google")


class WalletMergeError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def wallet_member_ids(session: Session, user_id: str) -> List[str]:
    """The account plus every guest wallet merged into it."""
    merged = session.query(UserDB.id).filter(UserDB.merged_into_user_id == user_id).all()
    return [user_id] + [row[0] for row in merged]


def wallet_app_account_tokens(session: Session, user_id: str) -> Set[str]:
    ids = wallet_member_ids(session, user_id)
    rows = session.query(UserDB.app_account_token).filter(UserDB.id.in_(ids)).all()
    return {str(r[0]).strip().lower() for r in rows if r[0]}


def is_signed_in_account(session: Session, user_id: str) -> bool:
    return (
        session.query(AuthIdentityDB.id)
        .filter(AuthIdentityDB.user_id == user_id, AuthIdentityDB.provider.in_(SIGNED_IN_PROVIDERS))
        .first()
        is not None
    )


def merge_guest_into(guest_user_id: str, target_user_id: str) -> Dict:
    """Moves everything purchased on a guest wallet to a signed-in account.
    Idempotent: re-running moves only what was bought since the last merge."""
    if not guest_user_id or not target_user_id or guest_user_id == target_user_id:
        raise WalletMergeError("Nothing to merge.", 400)
    now = datetime.now(timezone.utc)
    with get_db_session() as db:
        target = db.query(UserDB).filter(UserDB.id == target_user_id).with_for_update().first()
        guest = db.query(UserDB).filter(UserDB.id == guest_user_id).with_for_update().first()
        if not target or not guest:
            raise WalletMergeError("Account not found.", 404)
        if not is_signed_in_account(db, target.id):
            raise WalletMergeError("Sign in with Apple or Google to keep your purchases.", 403)
        if is_signed_in_account(db, guest.id):
            # Two real accounts are never merged automatically.
            raise WalletMergeError("That wallet belongs to another signed-in account.", 409)

        credits = int(guest.plot_credits or 0)
        consumables = (
            db.query(ConsumableTransactionDB)
            .filter(ConsumableTransactionDB.user_id == guest.id)
            .update({ConsumableTransactionDB.user_id: target.id}, synchronize_session=False)
        )
        subscriptions = (
            db.query(SubscriptionDB)
            .filter(SubscriptionDB.user_id == guest.id)
            .update({SubscriptionDB.user_id: target.id}, synchronize_session=False)
        )
        db.query(TransactionDB).filter(TransactionDB.user_id == guest.id).update(
            {TransactionDB.user_id: target.id}, synchronize_session=False)

        if credits > 0:
            guest.plot_credits = 0
            target.plot_credits = int(target.plot_credits or 0) + credits
            guest_balance = int(guest.free_credits or 0)
            target_balance = int(target.free_credits or 0) + int(target.plot_credits or 0)
            db.add(CreditLedgerDB(
                id=generate_uuid(), user_id=guest.id, entry_type="MERGE_OUT", amount=-credits,
                balance_after=guest_balance, reference_id=f"merge:{target.id}",
                reason=f"Guest wallet moved to signed-in account ({credits} purchased searches)",
                admin_id=None, created_at=now,
            ))
            db.add(CreditLedgerDB(
                id=generate_uuid(), user_id=target.id, entry_type="MERGE_IN", amount=credits,
                balance_after=target_balance, reference_id=f"merge:{guest.id}",
                reason=f"Guest wallet merged ({credits} purchased searches)",
                admin_id=None, created_at=now,
            ))
        if target.app_account_token is None and guest.app_account_token:
            target.app_account_token = guest.app_account_token
        guest.merged_into_user_id = target.id
        guest.updated_at = now
        target.updated_at = now
        balance = int(target.free_credits or 0) + int(target.plot_credits or 0)

    logger.info("WALLET_MERGED credits=%s consumables=%s subscriptions=%s", credits, consumables, subscriptions)
    return {
        "merged": True,
        "credits_moved": credits,
        "purchases_moved": int(consumables or 0),
        "subscriptions_moved": int(subscriptions or 0),
        "current_balance": balance,
    }
