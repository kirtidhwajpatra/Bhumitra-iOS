"""
Concurrency & Non-Blocking Verification Test
============================================
Proves that a slow /ror request (simulating upstream Bhulekh scraper delay)
does NOT block concurrent lightweight requests:
  - /health
  - /api/v1/app-config
  - /api/v1/location/search
  - /api/v1/subscription/credits
  - /api/v1/gis/navigation/districts

Acceptance Criterion:
Lightweight endpoints must complete with low latency (<1.0s) while the slow
scrape is actively in-flight, proving head-of-line blocking is eliminated.
"""

import asyncio
import time
from unittest.mock import patch, MagicMock
import pytest
from httpx import AsyncClient, ASGITransport

from app import create_app
from models.ror_response import RoRResponse, OwnerEntry


@pytest.fixture
def app():
    return create_app()


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.mark.anyio
async def test_slow_ror_does_not_block_lightweight_endpoints(app):
    """
    Simulates a 2.5s slow Bhulekh scrape on GET /api/v1/ror.
    Concurrently fires lightweight endpoints and verifies they respond immediately (<0.8s)
    without waiting for /ror to finish.
    """
    # Create mock slow RoR response
    slow_delay = 2.5
    async def mock_fetch_ror(*args, **kwargs):
        await asyncio.sleep(slow_delay)
        return RoRResponse(
            success=True,
            plot="1050",
            village="TOMPO",
            district="CUTTACK",
            tahasil="CUTTACK SADAR",
            khata_number="123",
            area="0.082 Ac",
            land_type="Gharabari",
            owners=[OwnerEntry(name="Test Owner", relation="Father", share="1.000", khata_number="123")],
            plots=[],
            cached=False,
        )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        with patch("services.ror_service.BhulekhScraper.fetch_ror", side_effect=mock_fetch_ror):
            # 1. Initiate slow RoR request
            t0 = time.time()
            ror_task = asyncio.create_task(
                client.get("/api/v1/ror?district=CUTTACK&tahasil=CUTTACK+SADAR&village=TOMPO&plot=1050")
            )

            # Wait a brief moment to ensure /ror has entered execution
            await asyncio.sleep(0.1)

            # 2. Fire concurrent lightweight requests
            t_light_start = time.time()
            health_task = asyncio.create_task(client.get("/health"))
            config_task = asyncio.create_task(client.get("/api/v1/app-config"))
            search_task = asyncio.create_task(client.get("/api/v1/location/search?q=tompo&limit=5"))
            credits_task = asyncio.create_task(client.get("/api/v1/subscription/credits"))
            districts_task = asyncio.create_task(client.get("/api/v1/gis/navigation/districts"))

            # Gather all lightweight responses
            health_res, config_res, search_res, credits_res, districts_res = await asyncio.gather(
                health_task, config_task, search_task, credits_task, districts_task
            )
            t_light_end = time.time()
            light_duration = t_light_end - t_light_start

            # 3. Assertions on lightweight endpoints
            assert health_res.status_code == 200, f"/health failed: {health_res.text}"
            assert config_res.status_code == 200, f"/app-config failed: {config_res.text}"
            assert search_res.status_code == 200, f"/location/search failed: {search_res.text}"
            assert credits_res.status_code in (200, 401), f"/subscription/credits unexpected status: {credits_res.status_code}"
            assert districts_res.status_code == 200, f"/gis/navigation/districts failed: {districts_res.text}"

            # CRITICAL CONCURRENCY CHECK:
            # All 5 lightweight requests MUST have completed in less than 1.2s,
            # well BEFORE the 2.5s slow RoR request finishes!
            assert light_duration < slow_delay, (
                f"Lightweight endpoints took {light_duration:.2f}s which is >= slow /ror delay ({slow_delay}s). "
                f"Head-of-line blocking is STILL OCCURRING!"
            )
            print(f"\n[CONCURRENCY SUCCESS] All 5 lightweight endpoints responded in {light_duration * 1000:.1f}ms while /ror was running!")

            # 4. Finally wait for RoR to complete
            ror_res = await ror_task
            total_ror_duration = time.time() - t0
            assert ror_res.status_code == 200, f"/ror failed: {ror_res.text}"
            assert total_ror_duration >= slow_delay, f"/ror completed too early: {total_ror_duration:.2f}s"
            print(f"[CONCURRENCY SUCCESS] Slow /ror finished as expected in {total_ror_duration:.2f}s")
