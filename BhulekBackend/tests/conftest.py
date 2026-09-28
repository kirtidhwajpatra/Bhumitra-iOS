"""
Pytest configuration and global test fixtures.
Ensures cache isolation across all test runs.
"""
import pytest
from services.ror_service import _cache, _negative_cache, _pdf_cache, _inflight_scrapes
import services.ror_service as ror_module


@pytest.fixture(autouse=True)
def reset_ror_caches():
    """Clears in-memory caches, in-flight queue, and resets event-loop bound primitives before and after each test."""
    _cache.clear()
    _negative_cache.clear()
    _pdf_cache.clear()
    _inflight_scrapes.clear()
    ror_module._pending_ror_count = 0
    ror_module._scrape_semaphore = ror_module.asyncio.Semaphore(ror_module.settings.BHULEKH_MAX_CONCURRENT)
    ror_module._pdf_semaphore = ror_module.asyncio.Semaphore(ror_module.settings.BHULEKH_MAX_CONCURRENT)
    ror_module._inflight_lock = ror_module.asyncio.Lock()
    yield
    _cache.clear()
    _negative_cache.clear()
    _pdf_cache.clear()
    _inflight_scrapes.clear()
    ror_module._pending_ror_count = 0
    ror_module._scrape_semaphore = ror_module.asyncio.Semaphore(ror_module.settings.BHULEKH_MAX_CONCURRENT)
    ror_module._pdf_semaphore = ror_module.asyncio.Semaphore(ror_module.settings.BHULEKH_MAX_CONCURRENT)
    ror_module._inflight_lock = ror_module.asyncio.Lock()
