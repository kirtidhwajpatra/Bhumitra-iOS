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
        self.free_ror_limit = int(os.environ.get("FREE_MONTHLY_ROR_LIMIT", "5"))
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

    def check_and_increment_ror_quota(self, user_id: str) -> Dict[str, Any]:
        """
        Atomically validates and increments the monthly RoR lookup quota for the given user.
        Premium users bypass limits. Free users are atomically capped at FREE_MONTHLY_ROR_LIMIT.
        """
        period = self.get_current_period()
        now = datetime.now(timezone.utc)
        limit = self.free_ror_limit

        with get_db_session() as session:
            # 1. Check if user is premium
            if self.is_user_premium(user_id, session):
                return {
                    "allowed": True,
                    "is_premium": True,
                    "current_usage": -1,
                    "limit": -1,
                    "remaining": -1,
                    "period": period,
                }

            # 2. Ensure row exists
            self._ensure_usage_row(session, user_id, period)

            # 3. Perform atomic update where ror_lookup_count < limit
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

            if rows_updated == 0:
                current_row = (
                    session.query(UserUsageDB)
                    .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                    .first()
                )
                current_count = current_row.ror_lookup_count if current_row else limit
                raise UsageLimitExceededError(
                    message=f"You have reached your free monthly limit of {limit} RoR lookups. Upgrade to Bhumitra Premium for unlimited lookups.",
                    limit_type="ror_lookup",
                    current_usage=current_count,
                    limit=limit,
                )

            # Query updated count
            current_row = (
                session.query(UserUsageDB)
                .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                .first()
            )
            current_count = current_row.ror_lookup_count if current_row else 1

            return {
                "allowed": True,
                "is_premium": False,
                "current_usage": current_count,
                "limit": limit,
                "remaining": max(0, limit - current_count),
                "period": period,
            }

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
        """Returns the current user's usage counts, limits, and subscription status."""
        period = self.get_current_period()

        with get_db_session() as session:
            is_premium = self.is_user_premium(user_id, session)
            usage_row = (
                session.query(UserUsageDB)
                .filter(UserUsageDB.user_id == user_id, UserUsageDB.period == period)
                .first()
            )

            ror_count = usage_row.ror_lookup_count if usage_row else 0
            pdf_count = usage_row.pdf_download_count if usage_row else 0

            return {
                "user_id": user_id,
                "period": period,
                "is_premium": is_premium,
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
