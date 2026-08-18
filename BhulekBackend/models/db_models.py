"""
SQLAlchemy PostgreSQL Database Models
Defines User, Subscription, Transaction, SubscriptionEvent, and AppConfig tables.
"""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    String,
    Boolean,
    Integer,
    DateTime,
    ForeignKey,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship
from db.base import Base


def generate_uuid() -> str:
    return str(uuid.uuid4())


class UserDB(Base):
    __tablename__ = "users"

    id = Column(String(255), primary_key=True)  # Bhumitra user identifier / Apple user ID
    app_account_token = Column(String(64), index=True, nullable=True)  # StoreKit 2 UUID
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    subscriptions = relationship("SubscriptionDB", back_populates="user", cascade="all, delete-orphan")
    transactions = relationship("TransactionDB", back_populates="user")
    usage_records = relationship("UserUsageDB", back_populates="user", cascade="all, delete-orphan")


class SubscriptionDB(Base):
    __tablename__ = "subscriptions"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    user_id = Column(String(255), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    product_id = Column(String(100), nullable=False)
    plan = Column(String(50), default="monthly", nullable=False)  # monthly, yearly, lifetime
    original_transaction_id = Column(String(100), unique=True, index=True, nullable=False)
    latest_transaction_id = Column(String(100), nullable=True)
    app_account_token = Column(String(64), index=True, nullable=True)
    status = Column(String(50), default="active", nullable=False)  # active, expired, revoked, in_billing_retry, none
    environment = Column(String(50), default="Sandbox", nullable=False)
    purchase_date = Column(DateTime(timezone=True), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=True)  # NULL for lifetime
    auto_renew_status = Column(Boolean, default=True, nullable=False)
    is_in_billing_retry = Column(Boolean, default=False, nullable=False)
    revocation_date = Column(DateTime(timezone=True), nullable=True)
    revocation_reason = Column(String(100), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    user = relationship("UserDB", back_populates="subscriptions")
    transactions = relationship("TransactionDB", back_populates="subscription", cascade="all, delete-orphan")


class TransactionDB(Base):
    __tablename__ = "transactions"

    id = Column(String(100), primary_key=True)  # Apple's transactionId
    original_transaction_id = Column(String(100), index=True, nullable=False)
    user_id = Column(String(255), ForeignKey("users.id", ondelete="SET NULL"), index=True, nullable=True)
    subscription_id = Column(String(64), ForeignKey("subscriptions.id", ondelete="CASCADE"), index=True, nullable=True)
    product_id = Column(String(100), nullable=False)
    environment = Column(String(50), nullable=False)
    transaction_type = Column(String(50), nullable=True)
    purchase_date = Column(DateTime(timezone=True), nullable=True)
    expiration_date = Column(DateTime(timezone=True), nullable=True)
    revocation_date = Column(DateTime(timezone=True), nullable=True)
    raw_data = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    user = relationship("UserDB", back_populates="transactions")
    subscription = relationship("SubscriptionDB", back_populates="transactions")


class SubscriptionEventDB(Base):
    __tablename__ = "subscription_events"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    notification_uuid = Column(String(100), unique=True, index=True, nullable=False)  # Enforces ASSN V2 idempotency
    notification_type = Column(String(100), nullable=False)
    subtype = Column(String(100), nullable=True)
    environment = Column(String(50), nullable=True)
    original_transaction_id = Column(String(100), index=True, nullable=True)
    received_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    processed_at = Column(DateTime(timezone=True), nullable=True)
    status = Column(String(50), default="processed", nullable=False)  # processed, already_processed, failed, ignored
    error_message = Column(Text, nullable=True)
    payload_summary = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)


class AppConfigDB(Base):
    __tablename__ = "app_configs"

    key = Column(String(100), primary_key=True)
    value = Column(Text, nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class UserUsageDB(Base):
    __tablename__ = "user_usage"

    id = Column(String(64), primary_key=True, default=generate_uuid)
    user_id = Column(String(255), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    period = Column(String(7), index=True, nullable=False)  # "YYYY-MM" e.g. "2026-08"
    ror_lookup_count = Column(Integer, default=0, nullable=False)
    pdf_download_count = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint("user_id", "period", name="uq_user_usage_period"),
    )

    # Relationships
    user = relationship("UserDB", back_populates="usage_records")
