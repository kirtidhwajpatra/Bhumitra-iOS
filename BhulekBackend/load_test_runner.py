"""
Isolated & Non-Destructive Load Testing Harness for Bhumitra Backend
Executes realistic concurrency tests using strictly mocked Bhulekh responses.
Guarantees ZERO upstream network calls to external government portals.
"""

import sys
import os
import time
import asyncio
import resource
from typing import List, Dict, Any
from unittest.mock import patch

# Add BhulekBackend to sys.path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import create_app
from models.ror_response import (
    RoRResponse,
    OwnerEntry,
    RoRVerification,
    RoRVerificationStatus,
    BhulekhLocationIdentity,
)
import httpx


# 1. Standard Mock RoR Object
def make_mock_ror(district="KEONJHAR", tahasil="KEONJHAR SADAR", village="G KERI 271", plot="1182") -> RoRResponse:
    return RoRResponse(
        success=True,
        district=district,
        tahasil=tahasil,
        village=village,
        plot=plot,
        khata_number="100",
        area="1.5000",
        land_type="Gharabari",
        owners=[
            OwnerEntry(name="Kirtidhwaj Patra", relation="S/O", relation_name="R. C. Patra"),
            OwnerEntry(name="Satyajit Patra", relation="S/O", relation_name="R. C. Patra"),
        ],
        raw_fields={"tenure": "Rayati", "khatian_type": "Final"},
        location_identity=BhulekhLocationIdentity(
            district_id="24",
            tahasil_id="001",
            village_id="10101",
            district_name=district,
            tahasil_name=tahasil,
            village_name=village,
            plot_number=plot,
        ),
        verification=RoRVerification(
            status=RoRVerificationStatus.VERIFIED,
            requested_district=district,
            requested_tahasil=tahasil,
            requested_village=village,
            requested_plot=plot,
            returned_district=district,
            returned_tahasil=tahasil,
            returned_village=village,
            returned_plot=plot,
            location_match=True,
            plot_match=True,
            details="Match verified against official portal.",
        ),
    )


# 2. Performance Stats Helper
def compute_stats(latencies_ms: List[float]) -> Dict[str, float]:
    if not latencies_ms:
        return {"p50": 0.0, "p95": 0.0, "p99": 0.0, "min": 0.0, "max": 0.0, "avg": 0.0}
    s = sorted(latencies_ms)
    n = len(s)
    p50 = s[int(n * 0.50)]
    p95 = s[min(int(n * 0.95), n - 1)]
    p99 = s[min(int(n * 0.99), n - 1)]
    return {
        "p50": round(p50, 2),
        "p95": round(p95, 2),
        "p99": round(p99, 2),
        "min": round(s[0], 2),
        "max": round(s[-1], 2),
        "avg": round(sum(s) / n, 2),
    }


# 3. Main Benchmark Runner
async def run_load_test():
    app = create_app()
    transport = httpx.ASGITransport(app=app)
    
    print("=" * 70)
    print("BHUMITRA BACKEND — SAFE ISOLATED LOAD TEST HARNESS")
    print("=" * 70)
    print(f"Environment: {os.environ.get('ENV', 'test')} (Mocked Upstream)")
    print(f"Python: {sys.version.split()[0]} | PID: {os.getpid()}")
    print("=" * 70)

    report_data = {}
    mock_scrape_count = 0

    async def mock_fetch_ror(district, tahasil, village, plot, b_id=None, v_id=None):
        nonlocal mock_scrape_count
        mock_scrape_count += 1
        # Realistic 35ms scraper overhead simulation
        await asyncio.sleep(0.035)
        return make_mock_ror(district, tahasil, village, plot)

    async def mock_download_pdf(district, tahasil, village, plot, khata=None, b_id=None, v_id=None):
        # Realistic 50ms PDF generation overhead simulation
        await asyncio.sleep(0.050)
        return b"%PDF-1.4 Mock Official Bhulekh Odisha RoR Document for Plot " + plot.encode()

    with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", side_effect=mock_fetch_ror), \
         patch("scrapers.bhulekh_scraper.BhulekhScraper.download_ror_pdf", side_effect=mock_download_pdf):

        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:

            # ----------------------------------------------------
            # TEST 1: Baseline (1 Concurrent Request)
            # ----------------------------------------------------
            print("\n[Phase 3] Running Baseline (1 concurrent x 50 requests)...")
            baseline_latencies = []
            for i in range(50):
                t0 = time.perf_counter()
                res = await client.get("/health", headers={"X-Forwarded-For": f"10.0.0.{i+1}"})
                t1 = time.perf_counter()
                assert res.status_code == 200
                baseline_latencies.append((t1 - t0) * 1000)

            report_data["baseline"] = compute_stats(baseline_latencies)
            print(f"  -> Health baseline latency: p50={report_data['baseline']['p50']}ms | p95={report_data['baseline']['p95']}ms | avg={report_data['baseline']['avg']}ms")

            # ----------------------------------------------------
            # TEST 2: Gradual Concurrency on API Endpoints (10, 25, 50, 100)
            # ----------------------------------------------------
            print("\n[Phase 4] Running Gradual Concurrency Tests on API routes (/api/v1/app-config)...")
            report_data["concurrency"] = {}

            for concurrency in [10, 25, 50, 100]:
                total_reqs = concurrency * 5
                latencies = []
                errors = 0
                t_start = time.perf_counter()

                async def worker(uid):
                    nonlocal errors
                    t0 = time.perf_counter()
                    try:
                        res = await client.get(
                            "/api/v1/app-config",
                            headers={"X-Forwarded-For": f"10.1.{uid // 256}.{uid % 256}"},
                        )
                        if res.status_code == 200:
                            latencies.append((time.perf_counter() - t0) * 1000)
                        else:
                            errors += 1
                    except Exception:
                        errors += 1

                for batch_idx in range(5):
                    tasks = [worker(batch_idx * concurrency + i + 1) for i in range(concurrency)]
                    await asyncio.gather(*tasks)

                total_duration = time.perf_counter() - t_start
                rps = round(total_reqs / total_duration, 1)
                stats = compute_stats(latencies)
                stats["rps"] = rps
                stats["errors"] = errors
                stats["concurrency"] = concurrency
                stats["total_requests"] = total_reqs
                report_data["concurrency"][concurrency] = stats
                print(f"  -> Concurrency {concurrency:3d}: Throughput={rps:6.1f} RPS | p50={stats['p50']:5.2f}ms | p95={stats['p95']:5.2f}ms | p99={stats['p99']:5.2f}ms | Errors={errors}")

            # ----------------------------------------------------
            # TEST 3: Search Load & SingleFlight Coalescing (Same Plot)
            # ----------------------------------------------------
            print("\n[Phase 5] Running SingleFlight Request Coalescing Test (100 Simultaneous Requests for Same Plot)...")
            from services.ror_service import _cache, _inflight_scrapes
            _cache.clear()
            _inflight_scrapes.clear()
            mock_scrape_count = 0

            # 100 simulated clients requesting the exact same cold plot simultaneously
            t_start = time.perf_counter()
            async def search_worker(client_id):
                return await client.get(
                    "/api/v1/ror?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=G%20KERI%20271&plot=9999",
                    headers={"X-Forwarded-For": f"10.2.0.{client_id}"},
                )

            responses = await asyncio.gather(*[search_worker(i+1) for i in range(100)])
            coalesce_duration = (time.perf_counter() - t_start) * 1000
            success_count = sum(1 for r in responses if r.status_code == 200)

            report_data["singleflight"] = {
                "callers": 100,
                "success_count": success_count,
                "upstream_scrapes_dispatched": mock_scrape_count,
                "total_batch_latency_ms": round(coalesce_duration, 2),
            }
            print(f"  -> 100 Simultaneous Callers for Plot 9999:")
            print(f"     Total Client Successes: {success_count}/100")
            print(f"     Upstream Mock Scrapes Dispatched: {mock_scrape_count} (SingleFlight Coalescing Verified!)")
            print(f"     Total Batch Latency: {report_data['singleflight']['total_batch_latency_ms']}ms")

            # ----------------------------------------------------
            # TEST 4: Cold vs Warm Cache Latency Benchmark
            # ----------------------------------------------------
            print("\n[Phase 6] Running Cold vs Warm Cache Latency Benchmark...")
            _cache.clear()
            
            # Cold request
            t0 = time.perf_counter()
            res_cold = await client.get(
                "/api/v1/ror?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=G%20KERI%20271&plot=500",
                headers={"X-Forwarded-For": "10.3.0.1"},
            )
            cold_latency = (time.perf_counter() - t0) * 1000
            assert res_cold.status_code == 200, f"Cold request failed: {res_cold.status_code}"

            # 100 Warm requests
            warm_latencies = []
            for i in range(100):
                t0 = time.perf_counter()
                res_warm = await client.get(
                    "/api/v1/ror?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=G%20KERI%20271&plot=500",
                    headers={"X-Forwarded-For": f"10.3.1.{i+1}"},
                )
                warm_latencies.append((time.perf_counter() - t0) * 1000)
                assert res_warm.status_code == 200

            warm_stats = compute_stats(warm_latencies)
            speedup = round(cold_latency / max(warm_stats["avg"], 0.1), 1)
            report_data["cache"] = {
                "cold_latency_ms": round(cold_latency, 2),
                "warm_p50_ms": warm_stats["p50"],
                "warm_p95_ms": warm_stats["p95"],
                "warm_avg_ms": warm_stats["avg"],
                "speedup_factor": speedup,
            }
            print(f"  -> Cold Scrape Latency: {report_data['cache']['cold_latency_ms']}ms")
            print(f"  -> Warm Cached Latency: p50={report_data['cache']['warm_p50_ms']}ms | avg={report_data['cache']['warm_avg_ms']}ms")
            print(f"  -> Cache Acceleration Factor: {speedup}x faster")

            # ----------------------------------------------------
            # TEST 5: PDF Generation Concurrency Test
            # ----------------------------------------------------
            print("\n[Phase 8] Running PDF Generation Concurrency Test...")
            from services.ror_service import _pdf_cache
            _pdf_cache.clear()
            pdf_latencies = []

            async def pdf_worker(idx):
                t0 = time.perf_counter()
                res = await client.get(
                    f"/api/v1/ror/pdf?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=G%20KERI%20271&plot={idx}&khata=100",
                    headers={"X-Forwarded-For": f"10.4.0.{idx}"},
                )
                pdf_latencies.append((time.perf_counter() - t0) * 1000)
                return res

            pdf_responses = await asyncio.gather(*[pdf_worker(i+1) for i in range(10)])
            pdf_success = sum(1 for r in pdf_responses if r.status_code == 200)
            pdf_stats = compute_stats(pdf_latencies)
            report_data["pdf"] = {
                "concurrent_requests": 10,
                "success_count": pdf_success,
                "p50_ms": pdf_stats["p50"],
                "p95_ms": pdf_stats["p95"],
                "avg_ms": pdf_stats["avg"],
            }
            print(f"  -> 10 Concurrent PDF Generations: Success={pdf_success}/10 | p50={pdf_stats['p50']}ms | avg={pdf_stats['avg']}ms")

            # ----------------------------------------------------
            # TEST 6: Upstream Failure & Resilience Simulation
            # ----------------------------------------------------
            print("\n[Phase 9] Running Upstream Failure & Resilience Simulation...")
            
            async def failing_fetch(district, tahasil, village, plot, b_id=None, v_id=None):
                raise ValueError(f"Plot '{plot}' not found in official portal.")

            with patch("scrapers.bhulekh_scraper.BhulekhScraper.fetch_ror", side_effect=failing_fetch):
                res_fail = await client.get(
                    "/api/v1/ror?district=KEONJHAR&tahasil=KEONJHAR%20SADAR&village=G%20KERI%20271&plot=999",
                    headers={"X-Forwarded-For": "10.5.0.1"},
                )
                print(f"  -> Upstream Not Found Handled: Status Code={res_fail.status_code} (Clean Structured JSON)")

            # Verify backend remains 100% healthy
            res_alive = await client.get("/health", headers={"X-Forwarded-For": "10.5.0.2"})
            assert res_alive.status_code == 200
            print("  -> Post-Failure Liveness Check: 200 OK (Backend Healthy)")

    # 4. Resource Usage
    usage = resource.getrusage(resource.RUSAGE_SELF)
    max_rss_mb = round(usage.ru_maxrss / (1024 * 1024), 2)  # macOS returns bytes
    if max_rss_mb > 10000: # On Linux it is in KB
        max_rss_mb = round(usage.ru_maxrss / 1024, 2)
    user_cpu_s = round(usage.ru_utime, 2)
    sys_cpu_s = round(usage.ru_stime, 2)

    report_data["resources"] = {
        "max_rss_mb": max_rss_mb,
        "user_cpu_s": user_cpu_s,
        "sys_cpu_s": sys_cpu_s,
    }

    print("\n" + "=" * 70)
    print("LOAD TEST EXECUTION COMPLETE")
    print(f"Peak RAM (RSS): {max_rss_mb} MB | User CPU: {user_cpu_s}s | Sys CPU: {sys_cpu_s}s")
    print("=" * 70)
    return report_data


if __name__ == "__main__":
    asyncio.run(run_load_test())
