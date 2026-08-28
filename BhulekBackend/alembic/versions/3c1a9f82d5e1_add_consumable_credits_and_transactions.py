"""add consumable_transactions table and plot_credits column on users

Revision ID: 3c1a9f82d5e1
Revises: 2bfa89c01d4e
Create Date: 2026-08-27 22:50:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3c1a9f82d5e1'
down_revision: Union[str, None] = '2bfa89c01d4e'
branch_labels: Union[Sequence[str], None] = None
depends_on: Union[Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add plot_credits column to users table with default 0
    op.add_column(
        'users',
        sa.Column('plot_credits', sa.Integer(), nullable=False, server_default='0')
    )

    # 2. Create consumable_transactions table for immutable idempotency tracking
    op.create_table(
        'consumable_transactions',
        sa.Column('id', sa.String(length=64), nullable=False),
        sa.Column('transaction_id', sa.String(length=100), nullable=False),
        sa.Column('original_transaction_id', sa.String(length=100), nullable=False),
        sa.Column('user_id', sa.String(length=255), nullable=False),
        sa.Column('product_id', sa.String(length=100), nullable=False),
        sa.Column('credits_granted', sa.Integer(), nullable=False),
        sa.Column('environment', sa.String(length=50), nullable=False),
        sa.Column('purchase_date', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('raw_data', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_consumable_transactions_transaction_id'), 'consumable_transactions', ['transaction_id'], unique=True)
    op.create_index(op.f('ix_consumable_transactions_original_transaction_id'), 'consumable_transactions', ['original_transaction_id'], unique=False)
    op.create_index(op.f('ix_consumable_transactions_user_id'), 'consumable_transactions', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_consumable_transactions_user_id'), table_name='consumable_transactions')
    op.drop_index(op.f('ix_consumable_transactions_original_transaction_id'), table_name='consumable_transactions')
    op.drop_index(op.f('ix_consumable_transactions_transaction_id'), table_name='consumable_transactions')
    op.drop_table('consumable_transactions')
    op.drop_column('users', 'plot_credits')
