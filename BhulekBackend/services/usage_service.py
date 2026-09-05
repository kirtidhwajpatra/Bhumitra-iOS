"""
Usage Enforcement Service
Authoritative backend quota tracking and atomic concurrency-safe incrementing
for Record of Rights (RoR) lookups and PDF generations.
"""

import os
from datetime import datetime, timezone
from typing import Dict, Any, Optional

from sqlalchemy.orm import Session
from db.session import get_db_session
from models.db_models import UserDB, SubscriptionDB, UserUsageDB


class UsageLimitExceededError(Exception):
    def __init__(self, message: str, limit_type: str, current_usage: int, limit: int):
        super().__init__(message)
        self.message = message
        self.limit_type = limit_type
        self.current_usage = current_usage
        self.limit = limit


class UsageService:
    def __init__(self):
        self.free_ror_limit = int(os.environ.get("FREE_MONTHLY_ROR_LIMIT", "10"))
        self.free_pdf_limit = int(os.environ.get("FREE_MONTHLY_PDF_LIMIT", "1"))

    def get_current_period(self) -> str:
        """Returns the current billing period key in 'YYYY-MM' format."""
        return datetime.now(timezone.utc).strftime("%Y-%m")

    def is_user_premium(self, user_id: str, session: Session) -> bool:
        """Determines if a user has an active, valid entitlement from PostgreSQL."""
        sub = (
            session.query(SubscriptionDB)
            .filter(SubscriptionDB.user_id == user_id)
            .first()
        )
        if not sub:
            return False

        if sub.status != "active":
            return False

        # Lifetime subscription has no expiration date
        if sub.expires_at is None:
            return True

        now = datetime.now(timezone.utc)
        sub_exp = sub.expires_at
        if sub_exp.tzinfo is None:
            sub_exp = sub_exp.replace(tzinfo=timezone.utc)

        return sub_exp > now

    def _ensure_usage_row(self, session: Session, user_id: str, period: str) -> UserUsageDB:
        """Ensures a usage record exists for the user and period, recovering gracefully from concurrent inserts."""
        usage_row = (
            session.query(UserUsageDB)
            .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
            .first()
        )
        if usage_row:
            return usage_row

        try:
            with session.begin_nested():
                usage_row = UserUsageDB(
                    user_id=user_id,
                    period=period,
                    ror_lookup_count=0,
                    pdf_download_count=0,
                )
                session.add(usage_row)
                session.flush()
                return usage_row
        except Exception:
            # Another concurrent transaction inserted the row; query it
            return (
                session.query(UserUsageDB)
                .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                .first()
            )

    def check_ror_quota(self, user_id: str) -> Dict[str, Any]:
        """
        Validates if the user has remaining RoR lookups without incrementing.
        Hierarchy:
          1. Priority 1 (Unlimited Subscriber): Bypasses all limits.
          2. Priority 2 (Free Monthly Quota): ror_lookup_count < free_ror_limit.
          3. Priority 3 (Purchased Plot Credits): UserDB.plot_credits > 0.
          4. Priority 4 (Nothing Available): Raises UsageLimitExceededError (HTTP 403).
        """
        period = self.get_current_period()
        limit = self.free_ror_limit

        with get_db_session() as session:
            # 1. Priority 1: Unlimited Subscriber
            if self.is_user_premium(user_id, session):
                return {
                    "allowed": True,
                    "entitlement": "unlimited",
                    "is_premium": True,
                    "current_usage": -1,
                    "limit": -1,
                    "remaining": -1,
                    "plot_credits": 0,
                    "period": period,
                }

            # 2. Priority 2: Free Monthly Quota
            self._ensure_usage_row(session, user_id, period)
            current_row = (
                session.query(UserUsageDB)
                .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                .first()
            )
            current_count = current_row.ror_lookup_count if current_row else 0

            user = session.query(UserDB).filter(UserDB.id == user_id).first()
            purchased_credits = user.plot_credits if user else 0

            if current_count < limit:
                return {
                    "allowed": True,
                    "entitlement": "free_quota",
                    "is_premium": False,
                    "current_usage": current_count,
                    "limit": limit,
                    "remaining": max(0, limit - current_count),
                    "plot_credits": purchased_credits,
                    "period": period,
                }

            # 3. Priority 3: Purchased Plot Credits
            if purchased_credits > 0:
                return {
                    "allowed": True,
                    "entitlement": "purchased_credits",
                    "is_premium": False,
                    "current_usage": current_count,
                    "limit": limit,
                    "remaining": 0,
                    "plot_credits": purchased_credits,
                    "period": period,
                }

            # 4. Priority 4: Nothing Available
            raise UsageLimitExceededError(
                message=f"You have reached your free monthly limit of {limit} RoR lookups and have 0 available plot credits. Purchase a plot credit pack or upgrade to Bhumitra Premium for unlimited lookups.",
                limit_type="ror_lookup",
                current_usage=current_count,
                limit=limit,
            )

    def deduct_ror_search(self, user_id: str, preferred_entitlement: Optional[str] = None) -> Dict[str, Any]:
        """
        Atomically decrements / increments the appropriate balance AFTER successful upstream verification.
        Hierarchy:
          1. Priority 1 (Unlimited Subscriber): No deduction.
          2. Priority 2 (Free Monthly Quota): Atomically increment UserUsageDB.ror_lookup_count where count < limit.
          3. Priority 3 (Purchased Plot Credits): Atomically decrement UserDB.plot_credits where plot_credits > 0.
        """
        period = self.get_current_period()
        now = datetime.now(timezone.utc)
        limit = self.free_ror_limit

        with get_db_session() as session:
            # 1. Priority 1: Unlimited Subscriber
            if self.is_user_premium(user_id, session):
                return {
                    "deducted": False,
                    "entitlement_used": "unlimited",
                    "period": period,
                }

            # Ensure usage row exists
            self._ensure_usage_row(session, user_id, period)

            # 2. Priority 2: Free Monthly Quota (Atomic conditional update)
            rows_updated = (
                session.query(UserUsageDB)
                .filter(
                    UserUsageDB.user_id == user_id,
                    UserUsageDB.period == period,
                    UserUsageDB.ror_lookup_count < limit,
                )
                .update(
                    {
                        UserUsageDB.ror_lookup_count: UserUsageDB.ror_lookup_count + 1,
                        UserUsageDB.updated_at: now,
                    },
                    synchronize_session=False,
                )
            )

            if rows_updated > 0:
                current_row = (
                    session.query(UserUsageDB)
                    .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                    .first()
                )
                used = current_row.ror_lookup_count if current_row else 1
                return {
                    "deducted": True,
                    "entitlement_used": "free_quota",
                    "free_used": used,
                    "free_remaining": max(0, limit - used),
                    "period": period,
                }

            # 3. Priority 3: Purchased Plot Credits (Atomic conditional decrement)
            credits_updated = (
                session.query(UserDB)
                .filter(
                    UserDB.id == user_id,
                    UserDB.plot_credits > 0,
                )
                .update(
                    {
                        UserDB.plot_credits: UserDB.plot_credits - 1,
                        UserDB.updated_at: now,
                    },
                    synchronize_session=False,
                )
            )

            if credits_updated > 0:
                user = session.query(UserDB).filter(UserDB.id == user_id).first()
                remaining_credits = user.plot_credits if user else 0
                return {
                    "deducted": True,
                    "entitlement_used": "purchased_credits",
                    "plot_credits_remaining": remaining_credits,
                    "period": period,
                }

            # If both were exhausted during concurrent races
            current_row = (
                session.query(UserUsageDB)
                .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                .first()
            )
            used = current_row.ror_lookup_count if current_row else limit
            raise UsageLimitExceededError(
                message=f"You have reached your free monthly limit of {limit} RoR lookups and have 0 available plot credits. Purchase a plot credit pack or upgrade to Bhumitra Premium for unlimited lookups.",
                limit_type="ror_lookup",
                current_usage=used,
                limit=limit,
            )

    def increment_ror_quota(self, user_id: str) -> None:
        """
        Backwards-compatible alias for deduct_ror_search.
        """
        self.deduct_ror_search(user_id)

    def check_and_increment_ror_quota(self, user_id: str) -> Dict[str, Any]:
        """
        Atomically validates and deducts one search entitlement for the given user.
        Hierarchy:
          1. Unlimited subscriber: Bypasses limits.
          2. Free monthly quota: Increments UserUsageDB.ror_lookup_count where count < limit.
          3. Purchased plot credits: Decrements UserDB.plot_credits where plot_credits > 0.
          4. Otherwise: Raises UsageLimitExceededError.
        """
        return self.deduct_ror_search(user_id)

    def check_and_increment_pdf_quota(self, user_id: str) -> Dict[str, Any]:
        """
        Atomically validates and increments the monthly PDF download quota.
        """
        period = self.get_current_period()
        now = datetime.now(timezone.utc)
        limit = self.free_pdf_limit

        with get_db_session() as session:
            if self.is_user_premium(user_id, session):
                return {
                    "allowed": True,
                    "is_premium": True,
                    "current_usage": -1,
                    "limit": -1,
                    "remaining": -1,
                    "period": period,
                }

            self._ensure_usage_row(session, user_id, period)

            rows_updated = (
                session.query(UserUsageDB)
                .filter(
                    UserUsageDB.user_id == user_id,
                    UserUsageDB.period == period,
                    UserUsageDB.pdf_download_count < limit,
                )
                .update(
                    {
                        UserUsageDB.pdf_download_count: UserUsageDB.pdf_download_count + 1,
                        UserUsageDB.updated_at: now,
                    },
                    synchronize_session=False,
                )
            )

            if rows_updated == 0:
                current_row = (
                    session.query(UserUsageDB)
                    .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                    .first()
                )
                current_count = current_row.pdf_download_count if current_row else limit
                raise UsageLimitExceededError(
                    message=f"You have reached your free monthly limit of {limit} PDF downloads. Upgrade to Bhumitra Premium for unlimited downloads.",
                    limit_type="pdf_download",
                    current_usage=current_count,
                    limit=limit,
                )

            current_row = (
                session.query(UserUsageDB)
                .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                .first()
            )
            current_count = current_row.pdf_download_count if current_row else 1

            return {
                "allowed": True,
                "is_premium": False,
                "current_usage": current_count,
                "limit": limit,
                "remaining": max(0, limit - current_count),
                "period": period,
            }

    def get_user_usage_summary(self, user_id: str) -> Dict[str, Any]:
        """Returns the current user's usage counts, limits, purchased credits, and subscription status."""
        period = self.get_current_period()

        with get_db_session() as session:
            is_premium = self.is_user_premium(user_id, session)
            usage_row = (
                session.query(UserUsageDB)
                .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                .first()
            )
            user = session.query(UserDB).filter(UserDB.id == user_id).first()
            plot_credits = user.plot_credits if user else 0

            ror_count = usage_row.ror_lookup_count if usage_row else 0
            pdf_count = usage_row.pdf_download_count if usage_row else 0

            return {
                "user_id": user_id,
                "period": period,
                "is_premium": is_premium,
                "plot_credits": plot_credits,
                "ror_lookups": {
                    "used": ror_count,
                    "limit": -1 if is_premium else self.free_ror_limit,
                    "remaining": -1 if is_premium else max(0, self.free_ror_limit - ror_count),
                },
                "pdf_downloads": {
                    "used": pdf_count,
                    "limit": -1 if is_premium else self.free_pdf_limit,
                    "remaining": -1 if is_premium else max(0, self.free_pdf_limit - pdf_count),
                },
            }


usage_service = UsageService()
