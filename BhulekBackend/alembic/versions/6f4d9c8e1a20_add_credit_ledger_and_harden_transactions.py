"""add credit_ledger and harden transaction ledgers

Revision ID: 6f4d9c8e1a20
Revises: 5e3c8d7b9a10
Create Date: 2026-09-10 20:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '6f4d9c8e1a20'
down_revision: Union[str, None] = '5e3c8d7b9a10'
branch_labels: Union[Sequence[str], None] = None
depends_on: Union[Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    # 1. Create credit_ledger table
    tables = inspector.get_table_names()
    if 'credit_ledger' not in tables:
        op.create_table(
            'credit_ledger',
            sa.Column('id', sa.String(length=64), nullable=False),
            sa.Column('user_id', sa.String(length=255), nullable=False),
            sa.Column('entry_type', sa.String(length=50), nullable=False),
            sa.Column('amount', sa.Integer(), nullable=False),
            sa.Column('balance_after', sa.Integer(), nullable=False),
            sa.Column('reference_id', sa.String(length=255), nullable=True),
            sa.Column('reason', sa.String(length=255), nullable=True),
            sa.Column('admin_id', sa.String(length=255), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
        )
        op.create_index(op.f('ix_credit_ledger_user_id'), 'credit_ledger', ['user_id'], unique=False)
        op.create_index(op.f('ix_credit_ledger_entry_type'), 'credit_ledger', ['entry_type'], unique=False)
        op.create_index(op.f('ix_credit_ledger_reference_id'), 'credit_ledger', ['reference_id'], unique=False)

    # 2. Harden consumable_transactions
    if 'consumable_transactions' in tables:
        cons_cols = [c['name'] for c in inspector.get_columns('consumable_transactions')]
        if 'app_account_token' not in cons_cols:
            op.add_column('consumable_transactions', sa.Column('app_account_token', sa.String(length=64), nullable=True))
            op.create_index(op.f('ix_consumable_transactions_app_account_token'), 'consumable_transactions', ['app_account_token'], unique=False)
        if 'verification_state' not in cons_cols:
            op.add_column('consumable_transactions', sa.Column('verification_state', sa.String(length=50), nullable=False, server_default='verified'))
        if 'delivery_state' not in cons_cols:
            op.add_column('consumable_transactions', sa.Column('delivery_state', sa.String(length=50), nullable=False, server_default='delivered'))
        if 'revocation_date' not in cons_cols:
            op.add_column('consumable_transactions', sa.Column('revocation_date', sa.DateTime(timezone=True), nullable=True))
        if 'revocation_reason' not in cons_cols:
            op.add_column('consumable_transactions', sa.Column('revocation_reason', sa.String(length=100), nullable=True))
        if 'updated_at' not in cons_cols:
            op.add_column('consumable_transactions', sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()))

    # 3. Harden transactions
    if 'transactions' in tables:
        tx_cols = [c['name'] for c in inspector.get_columns('transactions')]
        if 'app_account_token' not in tx_cols:
            op.add_column('transactions', sa.Column('app_account_token', sa.String(length=64), nullable=True))
            op.create_index(op.f('ix_transactions_app_account_token'), 'transactions', ['app_account_token'], unique=False)
        if 'verification_state' not in tx_cols:
            op.add_column('transactions', sa.Column('verification_state', sa.String(length=50), nullable=False, server_default='verified'))
        if 'delivery_state' not in tx_cols:
            op.add_column('transactions', sa.Column('delivery_state', sa.String(length=50), nullable=False, server_default='delivered'))
        if 'credits_granted' not in tx_cols:
            op.add_column('transactions', sa.Column('credits_granted', sa.Integer(), nullable=False, server_default='0'))
        if 'revocation_reason' not in tx_cols:
            op.add_column('transactions', sa.Column('revocation_reason', sa.String(length=100), nullable=True))
        if 'updated_at' not in tx_cols:
            op.add_column('transactions', sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()))


def downgrade() -> None:
    op.drop_table('credit_ledger')
