#!/usr/bin/env python3
"""
Phase 7.7 Comprehensive Verification & Benchmark Runner
Tests:
- Phase 7.7F: Verified Cache Performance
- Phase 7.7G: Concurrency & SingleFlight Coalescing
- Phase 7.7J: 20-Parcel Official Benchmark across multiple Odisha districts
- Phase 7.7K: False Owner Rate Evaluation (0% Target)
"""
import asyncio
import time
import httpx
from typing import List, Dict, Any

API_BASE = "http://127.0.0.1:8000/api/v1/ror"

BENCHMARK_PARCELS = [
    # 1-4: Baseline Test Set
    {"dist": "Bargarh", "tah": "Atabira", "vil": "Chakuli_Mosaic", "plot": "647", "bid": "1501", "vid": "1501061", "expected_type": "PRIVATE", "expected_khata": "277"},
    {"dist": "Khordha", "tah": "Bhubaneswar", "vil": "Raghunathpur_Jali", "plot": "333", "bid": "2002", "vid": "2002359", "expected_type": "PRIVATE", "expected_khata": "538"},
    {"dist": "Keonjhar", "tah": "Keonjhar Sadar", "vil": "G_Dimbo", "plot": "12", "bid": "0704", "vid": "0704317", "expected_type": "PRIVATE", "expected_khata": "112"},
    {"dist": "Keonjhar", "tah": "Keonjhar Sadar", "vil": "G_Dimbo", "plot": "1", "bid": "0704", "vid": "0704317", "expected_type": "GOV", "expected_khata": "230"},
    # 5-8: Additional Keonjhar Plots (Multi-plot Khata 112 & 230)
    {"dist": "Keonjhar", "tah": "Keonjhar Sadar", "vil": "G_Dimbo", "plot": "168", "bid": "0704", "vid": "0704317", "expected_type": "PRIVATE", "expected_khata": "112"},
    {"dist": "Keonjhar", "tah": "Keonjhar Sadar", "vil": "G_Dimbo", "plot": "174", "bid": "0704", "vid": "0704317", "expected_type": "PRIVATE", "expected_khata": "112"},
    {"dist": "Keonjhar", "tah": "Keonjhar Sadar", "vil": "G_Dimbo", "plot": "341", "bid": "0704", "vid": "0704317", "expected_type": "PRIVATE", "expected_khata": "112"},
    {"dist": "Keonjhar", "tah": "Keonjhar Sadar", "vil": "G_Dimbo", "plot": "3", "bid": "0704", "vid": "0704317", "expected_type": "GOV", "expected_khata": "230"},
    # 9-12: Additional Chakuli Plots (Khata 277)
    {"dist": "Bargarh", "tah": "Atabira", "vil": "Chakuli_Mosaic", "plot": "614", "bid": "1501", "vid": "1501061", "expected_type": "PRIVATE", "expected_khata": "277"},
    {"dist": "Bargarh", "tah": "Atabira", "vil": "Chakuli_Mosaic", "plot": "652", "bid": "1501", "vid": "1501061", "expected_type": "PRIVATE", "expected_khata": "277"},
    {"dist": "Bargarh", "tah": "Atabira", "vil": "Chakuli_Mosaic", "plot": "654", "bid": "1501", "vid": "1501061", "expected_type": "PRIVATE", "expected_khata": "277"},
    {"dist": "Bargarh", "tah": "Atabira", "vil": "Chakuli_Mosaic", "plot": "656", "bid": "1501", "vid": "1501061", "expected_type": "PRIVATE", "expected_khata": "277"},
    # 13-16: Additional Raghunathpur Jali Plots (Khata 538)
    {"dist": "Khordha", "tah": "Bhubaneswar", "vil": "Raghunathpur_Jali", "plot": "555", "bid": "2002", "vid": "2002359", "expected_type": "PRIVATE", "expected_khata": "538"},
    {"dist": "Khordha", "tah": "Bhubaneswar", "vil": "Raghunathpur_Jali", "plot": "1465", "bid": "2002", "vid": "2002359", "expected_type": "PRIVATE", "expected_khata": "538"},
    {"dist": "Khordha", "tah": "Bhubaneswar", "vil": "Raghunathpur_Jali", "plot": "718/3372", "bid": "2002", "vid": "2002359", "expected_type": "PRIVATE", "expected_khata": "538"},
    {"dist": "Khordha", "tah": "Bhubaneswar", "vil": "Raghunathpur_Jali", "plot": "333/3370", "bid": "2002", "vid": "2002359", "expected_type": "PRIVATE", "expected_khata": "538"},
    # 17-20: Negative and Boundary Test Cases (Fail-Closed verification)
    {"dist": "Keonjhar", "tah": "Keonjhar Sadar", "vil": "G_Dimbo", "plot": "99999", "bid": "0704", "vid": "0704317", "expected_type": "NOT_FOUND"},
    {"dist": "Bargarh", "tah": "Atabira", "vil": "Chakuli_Mosaic", "plot": "88888", "bid": "1501", "vid": "1501061", "expected_type": "NOT_FOUND"},
    {"dist": "Khordha", "tah": "Bhubaneswar", "vil": "Raghunathpur_Jali", "plot": "77777", "bid": "2002", "vid": "2002359", "expected_type": "NOT_FOUND"},
    {"dist": "Keonjhar", "tah": "Keonjhar Sadar", "vil": "G_Dimbo", "plot": "684", "bid": "0704", "vid": "0704317", "expected_type": "PRIVATE"},
]

async def test_cache():
    print("\n" + "="*60)
    print("PHASE 7.7F: CACHE PERFORMANCE & HIT RATIO TEST")
    print("="*60)
    async with httpx.AsyncClient(timeout=30.0) as client:
        # Request 1 (Cold / Cache Miss)
        t0 = time.time()
        r1 = await client.get(API_BASE, params={"district": "Keonjhar", "tahasil": "Keonjhar Sadar", "village": "G_Dimbo", "plot": "12", "b_id": "0704", "v_id": "0704317"})
        lat1 = (time.time() - t0) * 1000
        d1 = r1.json()
        print(f"Request 1 (Cold): status={r1.status_code}, cached={d1.get('cached')}, latency={lat1:.2f}ms")

        # Request 2 (Warm / Cache Hit)
        t0 = time.time()
        r2 = await client.get(API_BASE, params={"district": "Keonjhar", "tahasil": "Keonjhar Sadar", "village": "G_Dimbo", "plot": "12", "b_id": "0704", "v_id": "0704317"})
        lat2 = (time.time() - t0) * 1000
        d2 = r2.json()
        print(f"Request 2 (Warm): status={r2.status_code}, cached={d2.get('cached')}, latency={lat2:.2f}ms")

        assert r2.status_code == 200, f"Expected 200, got {r2.status_code}"
        assert d2.get("cached") == True, "Expected cached=True on 2nd request"
        assert lat2 < 50, f"Cache latency should be <50ms, got {lat2:.2f}ms"
        print("✅ PHASE 7.7F PASSED: Cache hit verified with sub-50ms latency.")

async def test_concurrency():
    print("\n" + "="*60)
    print("PHASE 7.7G: CONCURRENCY & IN-FLIGHT COALESCING TEST")
    print("="*60)
    async with httpx.AsyncClient(timeout=60.0) as client:
        # Send 5 simultaneous requests for the exact same uncached parcel
        target_plot = "342"
        params = {"district": "Keonjhar", "tahasil": "Keonjhar Sadar", "village": "G_Dimbo", "plot": target_plot, "b_id": "0704", "v_id": "0704317"}
        
        t0 = time.time()
        responses = await asyncio.gather(*[client.get(API_BASE, params=params) for _ in range(5)])
        total_time = (time.time() - t0) * 1000
        
        statuses = [r.status_code for r in responses]
        print(f"5 Concurrent Requests Completed in {total_time:.2f}ms. Statuses: {statuses}")
        
        for r in responses:
            assert r.status_code == 200, f"Concurrent request returned {r.status_code}"
            data = r.json()
            assert data["plot"] == target_plot, f"Expected plot {target_plot}, got {data.get('plot')}"
            assert data["verification"]["status"] == "VERIFIED"
            
        print("✅ PHASE 7.7G PASSED: 5/5 concurrent requests succeeded with verified responses.")

async def run_benchmark():
    print("\n" + "="*60)
    print("PHASE 7.7J & 7.7K: 20-PARCEL OFFICIAL BENCHMARK & FALSE-OWNER AUDIT")
    print("="*60)
    
    results = []
    false_owner_count = 0
    passed_count = 0
    
    async with httpx.AsyncClient(timeout=90.0) as client:
        for idx, p in enumerate(BENCHMARK_PARCELS, 1):
            t0 = time.time()
            try:
                r = await client.get(API_BASE, params={
                    "district": p["dist"],
                    "tahasil": p["tah"],
                    "village": p["vil"],
                    "plot": p["plot"],
                    "b_id": p.get("bid"),
                    "v_id": p.get("vid"),
                })
                lat = (time.time() - t0) * 1000
                status_code = r.status_code
                data = r.json()
                
                expected = p["expected_type"]
                if expected == "NOT_FOUND":
                    if status_code in (404, 422):
                        verdict = "PASS (Correctly Failed Closed)"
                        passed_count += 1
                    else:
                        verdict = f"FAIL (Expected 404/422, got {status_code})"
                        false_owner_count += 1
                    results.append({
                        "idx": idx, "parcel": f"{p['dist']} / {p['tah']} / {p['vil']} Plot {p['plot']}",
                        "status": status_code, "khata": "-", "owners": 0, "verdict": verdict, "latency_ms": lat
                    })
                else:
                    if status_code == 200:
                        returned_plot = data.get("plot")
                        returned_khata = data.get("khata_number")
                        owners = data.get("owners", [])
                        verif_status = data.get("verification", {}).get("status")
                        
                        # Strict invariant checks
                        plot_matches = (returned_plot == p["plot"])
                        khata_matches = (p.get("expected_khata") is None or returned_khata == p.get("expected_khata"))
                        is_verified = (verif_status == "VERIFIED")
                        
                        if plot_matches and khata_matches and is_verified:
                            verdict = f"PASS ({len(owners)} owners, Khata {returned_khata})"
                            passed_count += 1
                        else:
                            verdict = f"FAIL (Plot Match: {plot_matches}, Khata Match: {khata_matches})"
                            false_owner_count += 1
                            
                        results.append({
                            "idx": idx, "parcel": f"{p['dist']} / {p['tah']} / {p['vil']} Plot {p['plot']}",
                            "status": status_code, "khata": returned_khata, "owners": len(owners), "verdict": verdict, "latency_ms": lat
                        })
                    else:
                        verdict = f"FAIL (HTTP {status_code}: {data.get('detail')})"
                        false_owner_count += 1
                        results.append({
                            "idx": idx, "parcel": f"{p['dist']} / {p['tah']} / {p['vil']} Plot {p['plot']}",
                            "status": status_code, "khata": "-", "owners": 0, "verdict": verdict, "latency_ms": lat
                        })
            except Exception as e:
                lat = (time.time() - t0) * 1000
                verdict = f"ERROR: {e}"
                false_owner_count += 1
                results.append({
                    "idx": idx, "parcel": f"{p['dist']} / {p['tah']} / {p['vil']} Plot {p['plot']}",
                    "status": "ERR", "khata": "-", "owners": 0, "verdict": verdict, "latency_ms": lat
                })
                
            print(f"[{idx:02d}/20] {results[-1]['parcel']:<55} -> {results[-1]['verdict']} ({results[-1]['latency_ms']:.1f}ms)")

    total = len(BENCHMARK_PARCELS)
    false_owner_rate = (false_owner_count / total) * 100.0
    
    print("\n" + "="*60)
    print("BENCHMARK SUMMARY")
    print("="*60)
    print(f"Total Parcels Tested: {total}")
    print(f"Passed: {passed_count}/{total} ({(passed_count/total)*100:.1f}%)")
    print(f"False Owner Count: {false_owner_count}")
    print(f"False Owner Rate: {false_owner_rate:.2f}% (Target: 0.00%)")
    
    assert false_owner_rate == 0.0, f"False Owner Rate must be 0.0%, found {false_owner_rate}%"
    print("\n✅ PHASE 7.7K PASSED: 0.00% FALSE OWNER RATE VERIFIED.")

async def main():
    await test_cache()
    await test_concurrency()
    await run_benchmark()

if __name__ == "__main__":
    asyncio.run(main())
