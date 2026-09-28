"""
Real Concurrency Benchmark:
Spawns local Gunicorn with 2 Uvicorn workers and tests:
1. One real RoR request + 5 concurrent lightweight requests.
2. Two simultaneous real uncached RoR requests + 5 concurrent lightweight requests.
Measures HTTP status, TTFB, and total latency.
"""
import sys
import os
import time
import subprocess
import signal
import json
import urllib.request
import urllib.error
import concurrent.futures

PORT = 8099
BASE_URL = f"http://127.0.0.1:{PORT}"

LIGHTWEIGHT_ENDPOINTS = [
    ("HEALTH", f"{BASE_URL}/health"),
    ("APP_CONFIG", f"{BASE_URL}/api/v1/app-config"),
    ("LOCATION_SEARCH", f"{BASE_URL}/api/v1/location/search?q=tompo&limit=10"),
    ("CREDITS", f"{BASE_URL}/api/v1/subscription/credits?user_id=test_user"),
    ("DISTRICTS", f"{BASE_URL}/api/v1/gis/navigation/districts"),
]

# Use timestamp-based plot numbers to ensure zero cache hits
ts = int(time.time())
ROR_URL_1 = f"{BASE_URL}/api/v1/ror?district=CUTTACK&tahasil=BARANGA&village=NANDANKANAN&plot={ts % 10000 + 1}"
ROR_URL_2A = f"{BASE_URL}/api/v1/ror?district=CUTTACK&tahasil=BARANGA&village=NANDANKANAN&plot={ts % 10000 + 2}"
ROR_URL_2B = f"{BASE_URL}/api/v1/ror?district=JAJPUR&tahasil=JAJPUR&village=TOMPO&plot={ts % 10000 + 3}"


def fetch_timing(name: str, url: str, timeout: float = 35.0):
    t_start = time.perf_counter()
    ttfb = 0.0
    status_code = 0
    err = None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ConcurrencyBenchmark/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            ttfb = time.perf_counter() - t_start
            status_code = resp.status
            _ = resp.read()
            total_dur = time.perf_counter() - t_start
    except urllib.error.HTTPError as e:
        ttfb = time.perf_counter() - t_start
        status_code = e.code
        _ = e.read()
        total_dur = time.perf_counter() - t_start
    except Exception as e:
        total_dur = time.perf_counter() - t_start
        err = str(e)
    
    return {
        "name": name,
        "url": url,
        "status": status_code,
        "ttfb_ms": round(ttfb * 1000, 2),
        "total_ms": round(total_dur * 1000, 2),
        "error": err
    }


def wait_for_server(timeout=15.0):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            with urllib.request.urlopen(f"{BASE_URL}/health", timeout=1.0) as resp:
                if resp.status == 200:
                    return True
        except Exception:
            time.sleep(0.3)
    return False


def main():
    print("=" * 60)
    print(f"STARTING GUNICORN ON PORT {PORT} WITH 2 WORKERS...")
    print("=" * 60)

    gunicorn_bin = os.path.abspath(os.path.join(os.path.dirname(__file__), "../venv/bin/gunicorn"))
    cwd = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    env["WORKERS"] = "2"
    env["BHULEKH_MAX_CONCURRENT"] = "1"

    proc = subprocess.Popen(
        [
            gunicorn_bin,
            "main:app",
            "--workers", "2",
            "--worker-class", "uvicorn.workers.UvicornWorker",
            "--bind", f"127.0.0.1:{PORT}",
            "--timeout", "120"
        ],
        cwd=cwd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    try:
        if not wait_for_server():
            print("ERROR: Server did not become healthy in time.")
            stdout, stderr = proc.communicate(timeout=2)
            print("STDOUT:", stdout)
            print("STDERR:", stderr)
            sys.exit(1)

        print("Gunicorn master + 2 workers successfully booted!")

        # -------------------------------------------------------------
        # TEST 1: ONE REAL RoR REQUEST + 5 LIGHTWEIGHT CONCURRENT REQUESTS
        # -------------------------------------------------------------
        print("\n" + "=" * 60)
        print("TEST 1: ONE REAL RoR SCRAPE + 5 CONCURRENT LIGHTWEIGHT REQUESTS")
        print("=" * 60)

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            # 1. Dispatch RoR scrape
            print(f"Dispatching RoR request 1 to Worker 1: {ROR_URL_1}")
            ror_future = executor.submit(fetch_timing, "ROR_1", ROR_URL_1, 45.0)
            
            # Wait 300ms to ensure RoR is actively executing in Worker 1
            time.sleep(0.3)

            # 2. Dispatch lightweight endpoints concurrently while RoR is active
            print("Dispatching 5 interactive requests concurrently while RoR is running...")
            lw_futures = [executor.submit(fetch_timing, name, url) for name, url in LIGHTWEIGHT_ENDPOINTS]

            # Collect lightweight results
            lw_results_1 = [f.result() for f in lw_futures]

            for r in lw_results_1:
                status_str = f"HTTP {r['status']}" if r['status'] else f"ERROR: {r['error']}"
                print(f"  [{r['name']}] {status_str} | TTFB: {r['ttfb_ms']}ms | Total: {r['total_ms']}ms")

            ror_res_1 = ror_future.result()
            print(f"  [ROR_1 Finished] HTTP {ror_res_1['status']} | Total: {ror_res_1['total_ms']}ms")

        # -------------------------------------------------------------
        # TEST 2: TWO SIMULTANEOUS REAL UNCACHED RoR REQUESTS + 5 LIGHTWEIGHT REQUESTS
        # -------------------------------------------------------------
        print("\n" + "=" * 60)
        print("TEST 2: TWO SIMULTANEOUS REAL RoR SCRAPES + 5 CONCURRENT LIGHTWEIGHT REQUESTS")
        print("=" * 60)

        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            # 1. Dispatch RoR scrape 2A & RoR scrape 2B simultaneously
            print(f"Dispatching RoR 2A: {ROR_URL_2A}")
            print(f"Dispatching RoR 2B: {ROR_URL_2B}")
            ror1_future = executor.submit(fetch_timing, "ROR_2A", ROR_URL_2A, 45.0)
            ror2_future = executor.submit(fetch_timing, "ROR_2B", ROR_URL_2B, 45.0)

            # Wait 400ms to ensure BOTH workers are actively running RoR
            time.sleep(0.4)

            # 2. Dispatch lightweight endpoints
            print("Dispatching 5 interactive requests while BOTH workers are occupied...")
            lw_futures_2 = [executor.submit(fetch_timing, name, url) for name, url in LIGHTWEIGHT_ENDPOINTS]

            lw_results_2 = [f.result() for f in lw_futures_2]

            for r in lw_results_2:
                status_str = f"HTTP {r['status']}" if r['status'] else f"ERROR: {r['error']}"
                print(f"  [{r['name']}] {status_str} | TTFB: {r['ttfb_ms']}ms | Total: {r['total_ms']}ms")

            r1 = ror1_future.result()
            r2 = ror2_future.result()
            print(f"  [ROR_2A Finished] HTTP {r1['status']} | Total: {r1['total_ms']}ms")
            print(f"  [ROR_2B Finished] HTTP {r2['status']} | Total: {r2['total_ms']}ms")

        print("\n" + "=" * 60)
        print("BENCHMARK COMPLETED SUCCESSFULLY")
        print("=" * 60)

    finally:
        print("Stopping Gunicorn server...")
        proc.send_signal(signal.SIGTERM)
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        print("Gunicorn server stopped.")


if __name__ == "__main__":
    main()
