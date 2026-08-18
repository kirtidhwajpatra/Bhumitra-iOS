"""
Phase 10 Concurrency, Stability, & Cache Resilience Test Suite
Validates request coalescing (SingleFlight), cache key collision resistance across mouzas,
semaphore throttling, and health metric tracking under concurrent load.
"""

import asyncio
import pytest
from unittest.mock import AsyncMock, patch
from services.ror_service import RoRService, get_canonical_cache_key, _cache
from models.ror_response import (
    RoRResponse, OwnerEntry, BhulekhLocationIdentity,
    RoRVerification, RoRVerificationStatus
)


@pytest.fixture(autouse=True)
def clear_cache():
    _cache.clear()
    yield
    _cache.clear()


def test_canonical_cache_key_isolation():
    """Validates that identical plot numbers in different villages produce completely distinct cache keys."""
    key_village_a = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "KANTAPALI 1", "100")
    key_village_b = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "KANTAPALI 2", "100")
    key_village_c = get_canonical_cache_key("KEONJHAR", "CHAMPUA", "KANTAPALI 1", "100")

    assert key_village_a != key_village_b
    assert key_village_a != key_village_c
    assert key_village_b != key_village_c


@pytest.mark.anyio
async def test_concurrent_request_coalescing():
    """Validates that 10 concurrent requests for the exact same parcel coalesce into a single scrape call."""
    service = RoRService()
    
    mock_response = RoRResponse(
        success=True,
        plot="1182",
        village="G KERI 271",
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        khata_number="142",
        area="1.45 Acre",
        land_type="Sarada-1",
        owners=[OwnerEntry(name="Dillip Kumar Mahanta", share="1.000")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED,
            requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR",
            requested_village="G KERI 271",
            requested_plot="1182",
            returned_district="KEONJHAR",
            returned_tahasil="KEONJHAR SADAR",
            returned_village="G KERI 271",
            returned_plot="1182",
            location_match=True,
            plot_match=True,
            details="Verified from mock portal.",
        ),
    )

    scrape_calls = 0

    async def mock_fetch_ror(*args, **kwargs):
        nonlocal scrape_calls
        scrape_calls += 1
        await asyncio.sleep(0.05)  # Simulate browser execution
        return mock_response

    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", side_effect=mock_fetch_ror):
        tasks = [
            service.get_ror(
                district="KEONJHAR",
                tahasil="KEONJHAR SADAR",
                village="G KERI 271",
                plot="1182",
            )
            for _ in range(10)
        ]
        results = await asyncio.gather(*tasks)

        # Assert all 10 callers received verified response
        assert len(results) == 10
        for r in results:
            assert r.plot == "1182"
            assert r.owners[0].name == "Dillip Kumar Mahanta"

        # Assert only ONE actual scrape call occurred due to request coalescing!
        assert scrape_calls == 1
        assert service.metrics["coalesced_requests"] == 9
        assert service.metrics["successful_scrapes"] == 1


@pytest.mark.anyio
async def test_unverified_responses_are_never_cached():
    """Validates that a mismatched or failed lookup is NEVER stored in the cache."""
    service = RoRService()

    mismatched_response = RoRResponse(
        success=True,
        plot="101",  # Mismatched plot
        village="G KERI 271",
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        owners=[OwnerEntry(name="Wrong Person")],
        verification=RoRVerification(
            status=RoRVerificationStatus.MISMATCH,
            requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR",
            requested_village="G KERI 271",
            requested_plot="100",
            location_match=True,
            plot_match=False,
            details="Plot mismatch",
        ),
    )

    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", AsyncMock(return_value=mismatched_response)):
        result = await service.get_ror(
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot="100",
        )
        assert result.plot == "101"
        key = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "G KERI 271", "100")
        assert key not in _cache  # MUST NOT BE CACHED!


def test_health_metrics_reporting():
    """Validates that get_health_metrics tracks hit rates and latency without errors."""
    service = RoRService()
    metrics = service.get_health_metrics()
    assert metrics["status"] == "healthy"
    assert "cache_hit_rate_pct" in metrics
    assert "coalesced_rate_pct" in metrics
    assert "avg_latency_ms" in metrics
