"""add user_usage table for server-side quota tracking

Revision ID: 2bfa89c01d4e
Revises: 1eda6ee3e97c
Create Date: 2026-08-18 15:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '2bfa89c01d4e'
down_revision: Union[str, None] = '1eda6ee3e97c'
branch_labels: Union[Sequence[str], None] = None
depends_on: Union[Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'user_usage',
        sa.Column('id', sa.String(length=64), nullable=False),
        sa.Column('user_id', sa.String(length=255), nullable=False),
        sa.Column('period', sa.String(length=7), nullable=False),
        sa.Column('ror_lookup_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('pdf_download_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'period', name='uq_user_usage_period'),
    )
    op.create_index(op.f('ix_user_usage_user_id'), 'user_usage', ['user_id'], unique=False)
    op.create_index(op.f('ix_user_usage_period'), 'user_usage', ['period'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_user_usage_period'), table_name='user_usage')
    op.drop_index(op.f('ix_user_usage_user_id'), table_name='user_usage')
    op.drop_table('user_usage')
