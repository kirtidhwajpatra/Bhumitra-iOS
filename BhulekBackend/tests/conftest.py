"""
Pytest configuration and global test fixtures.
Ensures cache isolation across all test runs.
"""
import pytest
from services.ror_service import _cache, _negative_cache, _pdf_cache


@pytest.fixture(autouse=True)
def reset_ror_caches():
    """Clears in-memory caches before and after each test."""
    _cache.clear()
    _negative_cache.clear()
    _pdf_cache.clear()
    yield
    _cache.clear()
    _negative_cache.clear()
    _pdf_cache.clear()
