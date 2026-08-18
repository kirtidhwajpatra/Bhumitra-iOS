"""
PDF Generation & Cache Isolation Unit Tests
Validates that PDF responses are strictly isolated by canonical parcel identity,
preventing cross-parcel or cross-user mixing.
"""

import pytest
from unittest.mock import AsyncMock, patch
from services.ror_service import RoRService, get_canonical_cache_key, _pdf_cache


@pytest.fixture(autouse=True)
def clear_pdf_cache():
    _pdf_cache.clear()
    yield
    _pdf_cache.clear()


def test_1_parcel_a_vs_parcel_b_pdf_cache_isolation():
    """1. Ensures Parcel A (Plot 12) and Parcel B (Plot 120) produce distinct PDF cache entries."""
    key_a = f"pdf:{get_canonical_cache_key('KEONJHAR', 'KEONJHAR SADAR', 'G KERI 271', '12')}"
    key_b = f"pdf:{get_canonical_cache_key('KEONJHAR', 'KEONJHAR SADAR', 'G KERI 271', '120')}"
    
    assert key_a != key_b


def test_2_same_plot_different_villages_pdf_cache_isolation():
    """2. Ensures Plot 100 in Village A vs Plot 100 in Village B produce distinct PDF cache entries."""
    key_v1 = f"pdf:{get_canonical_cache_key('KEONJHAR', 'KEONJHAR SADAR', 'VILLAGE_ALPHA', '100')}"
    key_v2 = f"pdf:{get_canonical_cache_key('KEONJHAR', 'KEONJHAR SADAR', 'VILLAGE_BETA', '100')}"
    
    assert key_v1 != key_v2


@pytest.mark.anyio
async def test_3_pdf_service_returns_cached_bytes_on_hit():
    """3. Verifies that valid PDF generation caches bytes and returns on second call."""
    service = RoRService()
    mock_pdf_bytes = b"%PDF-1.4 Mock PDF Content For Test Parcel 1182"
    
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", AsyncMock(return_value=mock_pdf_bytes)) as mock_scrape:
        res1 = await service.get_ror_pdf("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "1182")
        assert res1 == mock_pdf_bytes
        assert mock_scrape.call_count == 1
        
        # Second call should hit _pdf_cache
        res2 = await service.get_ror_pdf("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "1182")
        assert res2 == mock_pdf_bytes
        assert mock_scrape.call_count == 1  # Not called again
