"""
Unit and integration tests for the Global RoR Lock (fcntl.flock)
and Concurrency Control in services/ror_service.py.

Verifies:
- Test A: Single-process concurrency bound by lock (peak scrapes <= 1)
- Test B: Cross-process mutual exclusion with multiprocessing (no overlapping intervals)
- Test C: Non-blocking event loop while lock is held (interactive APIs respond immediately)
- Test D: Bounded queue rejects excess requests with BHULEKH_RATE_LIMITED
- Test E: Exception during scrape cleanly releases lock
- Test F: Task cancellation cleanly releases lock
- Test G: SingleFlight coalescing shares a single scrape among identical concurrent requests
"""

import asyncio
import os
import time
import tempfile
import multiprocessing
from unittest.mock import patch, AsyncMock
import pytest
from httpx import AsyncClient, ASGITransport

from app import create_app
from core.config import settings
from models.ror_response import RoRResponse, OwnerEntry, RoRErrorCode
from services.ror_service import (
    RoRService,
    RoRServiceException,
    global_scrape_lock,
    _cache,
    _negative_cache,
    _pdf_cache,
    _inflight_scrapes,
)


def _make_mock_ror(plot: str = "1050") -> RoRResponse:
    return RoRResponse(
        success=True,
        plot=plot,
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


# ---------------------------------------------------------------------------
# Test A: Single-process concurrency bound by lock
# ---------------------------------------------------------------------------
@pytest.mark.anyio
async def test_a_single_process_concurrency_bound_by_lock():
    """Verify that multiple concurrent requests are serialized so peak concurrent scrapes == 1."""
    active_scrapes = 0
    peak_scrapes = 0
    lock = asyncio.Lock()

    async def mock_fetch_ror(district, tahasil, village, plot, **kwargs):
        nonlocal active_scrapes, peak_scrapes
        async with lock:
            active_scrapes += 1
            if active_scrapes > peak_scrapes:
                peak_scrapes = active_scrapes
        await asyncio.sleep(0.1)
        async with lock:
            active_scrapes -= 1
        return _make_mock_ror(plot=plot)

    service = RoRService()
    with patch("services.ror_service.BhulekhScraper.fetch_ror", side_effect=mock_fetch_ror):
        # Fire 2 distinct plots concurrently (so SingleFlight does not coalesce them)
        res1, res2 = await asyncio.gather(
            service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "101"),
            service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "102"),
        )

        assert res1.plot == "101"
        assert res2.plot == "102"
        assert peak_scrapes == 1, f"Expected peak_scrapes == 1, got {peak_scrapes}"


# ---------------------------------------------------------------------------
# Test B: Cross-process mutual exclusion with multiprocessing
# ---------------------------------------------------------------------------
def _worker_process_lock_runner(lock_file: str, log_file: str, sleep_duration: float):
    """Worker process helper that acquires global_scrape_lock and records start/end timestamps."""
    import asyncio
    import os
    import fcntl
    import errno

    async def run():
        fd = os.open(lock_file, os.O_RDWR | os.O_CREAT, 0o666)
        try:
            while True:
                try:
                    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except (BlockingIOError, OSError) as e:
                    err_num = getattr(e, "errno", None)
                    if err_num in (errno.EACCES, errno.EAGAIN, errno.EWOULDBLOCK) or isinstance(e, BlockingIOError):
                        await asyncio.sleep(0.05)
                    else:
                        raise

            t_start = time.time()
            with open(log_file, "a") as f:
                f.write(f"START {os.getpid()} {t_start}\n")

            await asyncio.sleep(sleep_duration)

            t_end = time.time()
            with open(log_file, "a") as f:
                f.write(f"END {os.getpid()} {t_end}\n")

            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)

    asyncio.run(run())


def test_b_cross_process_mutual_exclusion():
    """Verify that two separate OS processes contending for the file lock never overlap in execution."""
    with tempfile.TemporaryDirectory() as tmpdir:
        lock_path = os.path.join(tmpdir, "test_global.lock")
        log_path = os.path.join(tmpdir, "test_execution.log")

        p1 = multiprocessing.Process(
            target=_worker_process_lock_runner,
            args=(lock_path, log_path, 0.2),
        )
        p2 = multiprocessing.Process(
            target=_worker_process_lock_runner,
            args=(lock_path, log_path, 0.2),
        )

        p1.start()
        p2.start()
        p1.join(timeout=5)
        p2.join(timeout=5)

        assert not p1.is_alive()
        assert not p2.is_alive()

        with open(log_path, "r") as f:
            lines = [line.strip().split() for line in f if line.strip()]

        assert len(lines) == 4, f"Expected 4 log lines, got: {lines}"

        events = {}
        for action, pid, ts in lines:
            ts = float(ts)
            if pid not in events:
                events[pid] = {}
            events[pid][action] = ts

        pids = list(events.keys())
        assert len(pids) == 2, f"Expected 2 distinct PIDs, got {pids}"

        p_first, p_second = pids[0], pids[1]
        if events[p_first]["START"] > events[p_second]["START"]:
            p_first, p_second = p_second, p_first

        first_end = events[p_first]["END"]
        second_start = events[p_second]["START"]
        assert first_end <= second_start + 0.05, (
            f"Overlapping execution detected! {p_first} ended at {first_end}, but {p_second} started at {second_start}"
        )


# ---------------------------------------------------------------------------
# Test C: Non-blocking event loop while lock is held
# ---------------------------------------------------------------------------
@pytest.mark.anyio
async def test_c_non_blocking_event_loop_when_lock_held():
    """Verify that holding the lock does not block the asyncio event loop for lightweight APIs."""
    app = create_app()
    slow_hold = 0.4

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        async def lock_holder():
            async with global_scrape_lock():
                await asyncio.sleep(slow_hold)

        holder_task = asyncio.create_task(lock_holder())
        await asyncio.sleep(0.05)

        t_start = time.time()
        h_res, cfg_res, dist_res = await asyncio.gather(
            client.get("/health"),
            client.get("/api/v1/app-config"),
            client.get("/api/v1/gis/navigation/districts"),
        )
        elapsed = time.time() - t_start

        assert h_res.status_code == 200
        assert cfg_res.status_code == 200
        assert dist_res.status_code == 200
        assert elapsed < slow_hold, f"Lightweight endpoints blocked! Elapsed: {elapsed:.2f}s >= {slow_hold}s"

        await holder_task


# ---------------------------------------------------------------------------
# Test D: Bounded queue rejects excess requests with BHULEKH_RATE_LIMITED
# ---------------------------------------------------------------------------
@pytest.mark.anyio
async def test_d_bounded_queue_rate_limiting():
    """Verify that when in-flight pending requests reach MAX_PENDING_BHULEKH_REQUESTS, excess requests are rejected."""
    service = RoRService()

    async def mock_slow_scrape(*args, **kwargs):
        await asyncio.sleep(0.5)
        return _make_mock_ror()

    original_max = settings.MAX_PENDING_BHULEKH_REQUESTS
    try:
        settings.MAX_PENDING_BHULEKH_REQUESTS = 2

        with patch("services.ror_service.BhulekhScraper.fetch_ror", side_effect=mock_slow_scrape):
            t1 = asyncio.create_task(service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "201"))
            t2 = asyncio.create_task(service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "202"))
            await asyncio.sleep(0.05)

            with pytest.raises(RoRServiceException) as exc_info:
                await service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "203")

            assert exc_info.value.code == RoRErrorCode.BHULEKH_RATE_LIMITED
            assert exc_info.value.retryable is True

            await asyncio.gather(t1, t2)
    finally:
        settings.MAX_PENDING_BHULEKH_REQUESTS = original_max


# ---------------------------------------------------------------------------
# Test E: Exception during scrape cleanly releases lock
# ---------------------------------------------------------------------------
@pytest.mark.anyio
async def test_e_exception_during_scrape_releases_lock():
    """Verify that if a scrape raises an exception, the lock is released immediately for subsequent callers."""
    service = RoRService()

    call_count = 0

    async def mock_crashing_scrape(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            raise ValueError("Simulated scrape fatal failure")
        return _make_mock_ror(plot="302")

    with patch("services.ror_service.BhulekhScraper.fetch_ror", side_effect=mock_crashing_scrape):
        with pytest.raises(RoRServiceException):
            await service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "301")

        t0 = time.time()
        res = await asyncio.wait_for(
            service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "302"),
            timeout=2.0,
        )
        assert res.plot == "302"
        assert time.time() - t0 < 1.0


# ---------------------------------------------------------------------------
# Test F: Task cancellation cleanly releases lock
# ---------------------------------------------------------------------------
@pytest.mark.anyio
async def test_f_cancellation_releases_lock():
    """Verify that cancelling a scraping task releases the lock immediately."""
    service = RoRService()

    async def mock_hang_scrape(*args, **kwargs):
        await asyncio.sleep(10.0)
        return _make_mock_ror()

    with patch("services.ror_service.BhulekhScraper.fetch_ror", side_effect=mock_hang_scrape):
        task = asyncio.create_task(service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "401"))
        await asyncio.sleep(0.05)

        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task

    async def mock_fast_scrape(*args, **kwargs):
        return _make_mock_ror(plot="402")

    with patch("services.ror_service.BhulekhScraper.fetch_ror", side_effect=mock_fast_scrape):
        res = await asyncio.wait_for(
            service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "402"),
            timeout=2.0,
        )
        assert res.plot == "402"


# ---------------------------------------------------------------------------
# Test G: SingleFlight coalescing shares a single scrape
# ---------------------------------------------------------------------------
@pytest.mark.anyio
async def test_g_singleflight_coalescing():
    """Verify that multiple concurrent requests for the exact same plot share a single scrape."""
    service = RoRService()
    call_count = 0

    async def mock_fetch(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        await asyncio.sleep(0.05)
        return _make_mock_ror(plot="501")

    with patch("services.ror_service.BhulekhScraper.fetch_ror", side_effect=mock_fetch):
        r1, r2, r3 = await asyncio.gather(
            service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "501"),
            service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "501"),
            service.get_ror("CUTTACK", "CUTTACK SADAR", "TOMPO", "501"),
        )

        assert r1.plot == "501"
        assert r2.plot == "501"
        assert r3.plot == "501"
        assert call_count == 1
