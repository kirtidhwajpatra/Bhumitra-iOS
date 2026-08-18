"""
Database Engine & Session Management
Handles PostgreSQL connections via DATABASE_URL with seamless local SQLite fallback,
connection pooling, and transactional context managers.
"""

import os
from contextlib import contextmanager
from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

# Load database URL from environment
DATABASE_URL = os.environ.get("DATABASE_URL")

if DATABASE_URL:
    # Handle older 'postgres://' scheme compatibility
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)
    
    # PostgreSQL engine with robust connection pooling
    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,
        pool_size=10,
        max_overflow=20,
    )
else:
    # Local fallback for tests/development
    DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
    os.makedirs(DATA_DIR, exist_ok=True)
    local_db_path = os.path.join(DATA_DIR, "bhumitra_local.db")
    DATABASE_URL = f"sqlite:///{local_db_path}"
    
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@contextmanager
def get_db_session() -> Generator[Session, None, None]:
    """Transactional context manager for database operations."""
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def get_db() -> Generator[Session, None, None]:
    """FastAPI route dependency yielding a database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
