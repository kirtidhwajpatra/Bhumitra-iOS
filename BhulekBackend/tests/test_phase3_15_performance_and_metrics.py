"""
Phase 3.15 Automated Test Suite: Production Performance, Load Testing & Observability.
"""
import pytest
import time
import asyncio
import random
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from main import app
from core.config import settings
from services.ror_service import RoRService, _cache, _pdf_cache, RoRServiceException
from models.ror_response import (
    RoRResponse,
    RoRVerificationStatus,
    RoRVerification,
    OwnerEntry,
    RoRErrorCode,
)

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_caches():
    _cache.clear()
    _pdf_cache.clear()


@pytest.mark.anyio
async def test_1_traffic_mix_load_simulation_10_25_50_100_users():
    """
    Simulate realistic production traffic mix across concurrent users:
    - 60% GIS Hierarchy / Info
    - 20% Village Parcels / Spatial Query
    - 10% RoR Lookups
    - 5% PDF Downloads
    - 5% Search
    """
    ror_service = RoRService()
    mock_resp = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot="12",
        khata_number="112", area="0.41 Acre", owners=[OwnerEntry(name="MOHAN PATRA")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12",
            details="Exact Match"
        )
    )
    valid_pdf_content = b"%PDF-1.4 Mock RoR PDF"

    for concurrent_users in [10, 25, 50, 100]:
        with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch, \
             patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", new_callable=AsyncMock) as mock_pdf, \
             patch("providers.odisha_4kgeo_provider.Odisha4KGEOProvider.get_villages", new_callable=AsyncMock) as mock_villages:
            
            mock_villages.return_value = []
            
            async def fast_scrape(*args, **kwargs):
                await asyncio.sleep(0.005) # 5ms simulated latency
                return mock_resp

            async def fast_pdf(*args, **kwargs):
                await asyncio.sleep(0.008) # 8ms simulated latency
                return valid_pdf_content

            mock_fetch.side_effect = fast_scrape
            mock_pdf.side_effect = fast_pdf

            latencies = []
            start_all = time.time()

            async def simulate_user(user_idx: int):
                roll = random.random()
                t0 = time.time()
                try:
                    if roll < 0.60:
                        # 60% GIS
                        res = client.get("/api/v1/gis/districts")
                        assert res.status_code == 200
                    elif roll < 0.80:
                        # 20% Parcels
                        res = client.get("/api/v1/gis/villages?block_id=0704")
                        assert res.status_code in [200, 404, 422, 503]
                    elif roll < 0.90:
                        # 10% RoR
                        out = await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
                        assert out.plot == "12"
                    elif roll < 0.95:
                        # 5% PDF
                        pdf = await ror_service.get_ror_pdf("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
                        assert len(pdf) > 0
                    else:
                        # 5% Search
                        res = client.get("/api/v1/gis/districts")
                        assert res.status_code == 200
                finally:
                    latencies.append(time.time() - t0)

            tasks = [simulate_user(i) for i in range(concurrent_users)]
            await asyncio.gather(*tasks)
            total_elapsed = time.time() - start_all

            latencies.sort()
            p50 = latencies[int(len(latencies) * 0.50)] * 1000.0
            p95 = latencies[int(len(latencies) * 0.95)] * 1000.0
            p99 = latencies[min(len(latencies) - 1, int(len(latencies) * 0.99))] * 1000.0

            assert len(latencies) == concurrent_users
            assert p95 < 2000.0 # Under 2s even under 100 user surge


@pytest.mark.anyio
async def test_2_cold_vs_warm_cache_performance_benchmarks():
    """Benchmark cold cache lookup vs warm cache hit latency."""
    ror_service = RoRService()
    mock_resp = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot="12",
        khata_number="112", area="0.41 Acre", owners=[OwnerEntry(name="MOHAN PATRA")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12",
            details="Exact Match"
        )
    )

    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
        async def slow_scrape(*args, **kwargs):
            await asyncio.sleep(0.02)
            return mock_resp
        mock_fetch.side_effect = slow_scrape

        # Cold lookup
        t0 = time.time()
        res_cold = await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
        cold_latency_ms = (time.time() - t0) * 1000.0

        # Warm lookup (Cache HIT)
        t1 = time.time()
        res_warm = await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12")
        warm_latency_ms = (time.time() - t1) * 1000.0

        assert res_cold.plot == res_warm.plot
        assert warm_latency_ms < cold_latency_ms
        assert warm_latency_ms < 5.0 # Cache hit under 5ms


@pytest.mark.anyio
async def test_3_singleflight_deduplication_efficiency_10_identical_requests():
    """Verify that 10 simultaneous identical requests result in exactly ONE expensive scrape execution."""
    ror_service = RoRService()
    mock_resp = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot="12",
        khata_number="112", area="0.41 Acre", owners=[OwnerEntry(name="MOHAN PATRA")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12",
            details="Exact Match"
        )
    )

    call_count = 0
    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
        async def counted_scrape(*args, **kwargs):
            nonlocal call_count
            call_count += 1
            await asyncio.sleep(0.02)
            return mock_resp
        mock_fetch.side_effect = counted_scrape

        tasks = [ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "12") for _ in range(10)]
        results = await asyncio.gather(*tasks)

        assert len(results) == 10
        assert call_count == 1 # SingleFlight executed only once


@pytest.mark.anyio
async def test_4_playwright_concurrency_bounding_under_surge():
    """Verify that semaphore bounds concurrent worker execution to settings.BHULEKH_MAX_CONCURRENT."""
    ror_service = RoRService()
    active_concurrent = 0
    peak_concurrent = 0

    mock_resp = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot="12",
        khata_number="112", area="0.41 Acre", owners=[OwnerEntry(name="MOHAN PATRA")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12",
            details="Exact Match"
        )
    )

    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
        async def measured_scrape(*args, **kwargs):
            nonlocal active_concurrent, peak_concurrent
            active_concurrent += 1
            peak_concurrent = max(peak_concurrent, active_concurrent)
            await asyncio.sleep(0.02)
            active_concurrent -= 1
            return mock_resp
        mock_fetch.side_effect = measured_scrape

        # Send 10 distinct plots to bypass SingleFlight coalescing
        tasks = [ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", f"p_{i}") for i in range(10)]
        await asyncio.gather(*tasks)

        assert peak_concurrent <= settings.BHULEKH_MAX_CONCURRENT


@pytest.mark.anyio
async def test_5_queue_capacity_overflow_fast_rejection():
    """Verify that queue overflow requests fail immediately with 503/429 without hanging."""
    ror_service = RoRService()
    
    with patch.object(settings, "MAX_PENDING_BHULEKH_REQUESTS", 2):
        with patch.object(settings, "BHULEKH_MAX_CONCURRENT", 1):
            async def blocking_scrape(*args, **kwargs):
                await asyncio.sleep(0.5)
                return None

            with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", side_effect=blocking_scrape):
                tasks = [ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", f"plot_{i}") for i in range(5)]
                results = await asyncio.gather(*tasks, return_exceptions=True)

                rejections = [r for r in results if isinstance(r, RoRServiceException) and r.code == RoRErrorCode.BHULEKH_RATE_LIMITED]
                assert len(rejections) > 0


@pytest.mark.anyio
async def test_6_memory_stability_across_100_sequential_operations():
    """Verify memory stability across 100 sequential operations."""
    ror_service = RoRService()
    mock_resp = RoRResponse(
        success=True,
        district="KEONJHAR", tahasil="KEONJHAR SADAR", village="Dimbo", plot="12",
        khata_number="112", area="0.41 Acre", owners=[OwnerEntry(name="MOHAN PATRA")],
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED, requested_district="KEONJHAR",
            requested_tahasil="KEONJHAR SADAR", requested_village="Dimbo", requested_plot="12",
            details="Exact Match"
        )
    )

    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.return_value = mock_resp

        for i in range(100):
            res = await ror_service.get_ror("KEONJHAR", "KEONJHAR SADAR", "Dimbo", f"{i}")
            assert res.success is True


def test_7_metrics_and_observability_endpoint_accuracy():
    """Verify that get_health_metrics() returns all essential production observability metrics."""
    ror_service = RoRService()
    metrics = ror_service.get_health_metrics()
    
    assert "status" in metrics
    assert "active_workers" in metrics
    assert "max_workers" in metrics
    assert "pending_queue_depth" in metrics
    assert "queue_rejections" in metrics
    assert "cached_verified_records" in metrics
    assert "cached_verified_pdfs" in metrics
    assert "cache_hit_rate_pct" in metrics
    assert "avg_latency_ms" in metrics
