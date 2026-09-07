"""add auth_identities table and user profile columns

Revision ID: 4d2b8e91f0a2
Revises: 3c1a9f82d5e1
Create Date: 2026-09-07 11:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4d2b8e91f0a2'
down_revision: Union[str, None] = '3c1a9f82d5e1'
branch_labels: Union[Sequence[str], None] = None
depends_on: Union[Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    
    # 1. Add email and name columns to users table (if not exists)
    user_columns = [col['name'] for col in inspector.get_columns('users')]
    if 'email' not in user_columns:
        op.add_column('users', sa.Column('email', sa.String(length=255), nullable=True))
        op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=False)
    if 'name' not in user_columns:
        op.add_column('users', sa.Column('name', sa.String(length=255), nullable=True))

    # 2. Create auth_identities table (if not exists)
    tables = inspector.get_table_names()
    if 'auth_identities' not in tables:
        op.create_table(
            'auth_identities',
            sa.Column('id', sa.String(length=64), nullable=False),
            sa.Column('user_id', sa.String(length=255), nullable=False),
            sa.Column('provider', sa.String(length=50), nullable=False),
            sa.Column('provider_subject', sa.String(length=255), nullable=False),
            sa.Column('provider_email', sa.String(length=255), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('provider', 'provider_subject', name='uq_auth_identity_provider_subject'),
        )
        op.create_index(op.f('ix_auth_identities_user_id'), 'auth_identities', ['user_id'], unique=False)

    # 3. Python-level backfill (Dialect-agnostic for both SQLite and Postgres)
    import uuid
    users_table = sa.table('users',
        sa.column('id', sa.String),
        sa.column('email', sa.String),
        sa.column('created_at', sa.DateTime)
    )
    auth_identities_table = sa.table('auth_identities',
        sa.column('id', sa.String),
        sa.column('user_id', sa.String),
        sa.column('provider', sa.String),
        sa.column('provider_subject', sa.String),
        sa.column('provider_email', sa.String),
        sa.column('created_at', sa.DateTime)
    )
    
    users = bind.execute(sa.select(users_table)).fetchall()
    existing_identities = set()
    try:
        ident_rows = bind.execute(sa.select(auth_identities_table.c.provider, auth_identities_table.c.provider_subject)).fetchall()
        for r in ident_rows:
            existing_identities.add((r[0], r[1]))
    except Exception:
        pass
    
    records_to_insert = []
    for u in users:
        uid = u[0]
        email = u[1]
        created = u[2]
        
        if uid.startswith('google_'):
            provider = 'google'
            provider_sub = uid[7:]
        elif uid.startswith('dev_'):
            provider = 'device'
            provider_sub = uid[4:]
        else:
            provider = 'apple'
            provider_sub = uid
            
        if (provider, provider_sub) not in existing_identities:
            records_to_insert.append({
                'id': f"ident_{uuid.uuid4().hex[:16]}",
                'user_id': uid,
                'provider': provider,
                'provider_subject': provider_sub,
                'provider_email': email,
                'created_at': created
            })
            existing_identities.add((provider, provider_sub))
            
    if records_to_insert:
        bind.execute(sa.insert(auth_identities_table).values(records_to_insert))


def downgrade() -> None:
    op.drop_index(op.f('ix_auth_identities_user_id'), table_name='auth_identities')
    op.drop_table('auth_identities')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_column('users', 'name')
    op.drop_column('users', 'email')
