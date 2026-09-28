"""add device_promotions table and promotional_grant_claimed column

Revision ID: 5e3c8d7b9a10
Revises: 4d2b8e91f0a2
Create Date: 2026-09-09 11:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5e3c8d7b9a10'
down_revision: Union[str, None] = '4d2b8e91f0a2'
branch_labels: Union[Sequence[str], None] = None
depends_on: Union[Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    # 1. Add promotional_grant_claimed column to users table (if not exists)
    user_columns = [col['name'] for col in inspector.get_columns('users')]
    if 'promotional_grant_claimed' not in user_columns:
        op.add_column(
            'users',
            sa.Column('promotional_grant_claimed', sa.Boolean(), nullable=False, server_default=sa.false()),
        )

    # 2. Ensure ix_users_email index exists
    user_indexes = [idx['name'] for idx in inspector.get_indexes('users')]
    if 'ix_users_email' not in user_indexes:
        op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=False)

    # 3. Create device_promotions table (if not exists)
    tables = inspector.get_table_names()
    if 'device_promotions' not in tables:
        op.create_table(
            'device_promotions',
            sa.Column('id', sa.String(length=64), nullable=False),
            sa.Column('device_id', sa.String(length=255), nullable=False),
            sa.Column('first_claimed_user_id', sa.String(length=255), nullable=True),
            sa.Column('claimed_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.ForeignKeyConstraint(['first_claimed_user_id'], ['users.id'], ondelete='SET NULL'),
            sa.PrimaryKeyConstraint('id'),
        )
        op.create_index(op.f('ix_device_promotions_device_id'), 'device_promotions', ['device_id'], unique=True)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    tables = inspector.get_table_names()
    if 'device_promotions' in tables:
        op.drop_index(op.f('ix_device_promotions_device_id'), table_name='device_promotions')
        op.drop_table('device_promotions')

    user_columns = [col['name'] for col in inspector.get_columns('users')]
    if 'promotional_grant_claimed' in user_columns:
        op.drop_column('users', 'promotional_grant_claimed')
