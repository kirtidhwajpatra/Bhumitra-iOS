"""
Unit & Integration Test Suite for BiharRoRService
Validates isolated caching, SingleFlight request coalescing, bounded semaphores,
feature flag fail-closed controls, and total namespace separation from Odisha.
"""

import pytest
import asyncio
from unittest.mock import patch

from models.ror_response import RoRErrorCode
from services.bihar_ror_service import (
    BiharRoRService,
    BiharRoRServiceException,
    get_bihar_cache_key,
    _bihar_cache,
    _bihar_negative_cache,
)
from services.ror_service import _cache as odisha_cache
from core.config import settings


@pytest.fixture(autouse=True)
def clean_bihar_caches():
    service = BiharRoRService()
    service.clear_caches()
    odisha_cache.clear()
    yield
    service.clear_caches()
    odisha_cache.clear()


@pytest.mark.anyio
async def test_feature_flag_fail_closed():
    """Verify BiharRoRService rejects requests when BIHAR_PROVIDER_ENABLED is False."""
    service = BiharRoRService()

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", False):
        with pytest.raises(BiharRoRServiceException) as exc_info:
            await service.get_ror(
                district="PATNA",
                anchal="PATNA SADAR",
                village="BEGAMPUR",
                plot="245",
            )

        assert exc_info.value.code == RoRErrorCode.BHULEKH_TEMPORARILY_UNAVAILABLE
        assert "disabled by administrative feature flag" in exc_info.value.message


@pytest.mark.anyio
async def test_bihar_positive_caching():
    """Verify that successful RoR lookups are cached and returned on subsequent calls."""
    service = BiharRoRService()

    sample_payload = {
        "location": {"district": "PATNA", "anchal": "PATNA SADAR", "mauza": "BEGAMPUR"},
        "register_identifiers": {"khata_number": "78", "khesra_number": "245"},
        "raiyat_details": [{"raiyat_name": "राम प्रसाद"}],
        "land_schedule": [{"khesra_no": "245", "area_acre": "0.375", "land_type": "भीठ-2"}]
    }

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        # First call: executes parse
        res1 = await service.get_ror(
            district="PATNA",
            anchal="PATNA SADAR",
            village="BEGAMPUR",
            plot="245",
            raw_payload=sample_payload,
        )
        assert res1.success is True
        assert res1.plot == "245"
        assert res1.cached is False

        # Second call: served from L1 TTLCache
        res2 = await service.get_ror(
            district="PATNA",
            anchal="PATNA SADAR",
            village="BEGAMPUR",
            plot="245",
            raw_payload=sample_payload,
        )
        assert res2.success is True
        assert res2.plot == "245"
        assert res2.cached is True
        assert service.metrics["cache_hits"] == 1


@pytest.mark.anyio
async def test_bihar_negative_caching():
    """Verify that confirmed PLOT_NOT_FOUND is cached in negative cache."""
    service = BiharRoRService()

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        # First lookup: returns plot not found (offline mock default)
        res1 = await service.get_ror(
            district="PATNA",
            anchal="PATNA SADAR",
            village="BEGAMPUR",
            plot="99999",
        )
        assert res1.success is False
        assert res1.error.code == RoRErrorCode.PLOT_NOT_FOUND

        # Second lookup: served immediately from negative cache
        with pytest.raises(BiharRoRServiceException) as exc_info:
            await service.get_ror(
                district="PATNA",
                anchal="PATNA SADAR",
                village="BEGAMPUR",
                plot="99999",
            )
        assert exc_info.value.code == RoRErrorCode.PLOT_NOT_FOUND
        assert service.metrics["negative_cache_hits"] == 1


@pytest.mark.anyio
async def test_bihar_singleflight_coalescing():
    """Verify that 10 concurrent requests for the same parcel coalesce into 1 execution."""
    service = BiharRoRService()

    sample_payload = {
        "location": {"district": "GAYA", "anchal": "BODHGAYA", "mauza": "BAKRAUR"},
        "register_identifiers": {"khata_number": "115", "khesra_number": "89"},
        "raiyat_details": [{"raiyat_name": "सुरेश कुमार"}],
        "land_schedule": [{"khesra_no": "89", "area_decimal": "50", "land_type": "धनहर-1"}]
    }

    parse_call_count = 0
    original_execute_parse = service._execute_parse

    async def slow_execute_parse(*args, **kwargs):
        nonlocal parse_call_count
        parse_call_count += 1
        await asyncio.sleep(0.05)  # Simulate network latency
        return await original_execute_parse(*args, **kwargs)

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        with patch.object(service, "_execute_parse", side_effect=slow_execute_parse):
            tasks = [
                service.get_ror(
                    district="GAYA",
                    anchal="BODHGAYA",
                    village="BAKRAUR",
                    plot="89",
                    raw_payload=sample_payload,
                )
                for _ in range(10)
            ]

            results = await asyncio.gather(*tasks)

            assert len(results) == 10
            for r in results:
                assert r.success is True
                assert r.plot == "89"

            # Must have executed exactly once
            assert parse_call_count == 1
            # 9 requests coalesced
            assert service.metrics["coalesced_requests"] == 9


@pytest.mark.anyio
async def test_cache_namespace_isolation_odisha_protected():
    """Verify that Bihar cache operations never touch or pollute the Odisha cache."""
    service = BiharRoRService()

    sample_payload = {
        "location": {"district": "PATNA", "anchal": "PATNA SADAR", "mauza": "BEGAMPUR"},
        "register_identifiers": {"khata_number": "78", "khesra_number": "245"},
        "raiyat_details": [{"raiyat_name": "राम प्रसाद"}],
        "land_schedule": [{"khesra_no": "245", "area_acre": "0.375", "land_type": "भीठ-2"}]
    }

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        await service.get_ror(
            district="PATNA",
            anchal="PATNA SADAR",
            village="BEGAMPUR",
            plot="245",
            raw_payload=sample_payload,
        )

        # Assert Bihar cache has 1 entry
        assert len(_bihar_cache) == 1

        # Assert Odisha cache has ZERO entries (100% Isolated)
        assert len(odisha_cache) == 0


@pytest.mark.anyio
async def test_bihar_queue_rejection_on_capacity_exceeded():
    """Verify that Bihar service rejects lookups when pending queue capacity is exceeded."""
    service = BiharRoRService()

    with patch.object(settings, "BIHAR_PROVIDER_ENABLED", True):
        with patch.object(settings, "BIHAR_MAX_PENDING_REQUESTS", 0):
            with pytest.raises(BiharRoRServiceException) as exc_info:
                await service.get_ror(
                    district="PATNA",
                    anchal="PATNA SADAR",
                    village="BEGAMPUR",
                    plot="245",
                )
            assert exc_info.value.code == RoRErrorCode.BHULEKH_RATE_LIMITED
            assert service.metrics["queue_rejections"] == 1

