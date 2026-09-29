"""add users.merged_into_user_id (guest wallet merged into a signed-in account)

Revision ID: 7a1b2c3d4e50
Revises: 6f4d9c8e1a20
Create Date: 2026-09-30 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '7a1b2c3d4e50'
down_revision: Union[str, None] = '6f4d9c8e1a20'
branch_labels: Union[Sequence[str], None] = None
depends_on: Union[Sequence[str], None] = None


def upgrade() -> None:
    # Nullable, no default: safe ADD COLUMN on SQLite tables that have rows.
    op.add_column('users', sa.Column('merged_into_user_id', sa.String(length=255), nullable=True))
    op.create_index('ix_users_merged_into_user_id', 'users', ['merged_into_user_id'])


def downgrade() -> None:
    op.drop_index('ix_users_merged_into_user_id', table_name='users')
    with op.batch_alter_table('users') as batch:
        batch.drop_column('merged_into_user_id')
