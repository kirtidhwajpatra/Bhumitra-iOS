#!/usr/bin/env python3
"""
PHASE 7.7A: Baseline Failure Capture Script
Captures exact failure states for:
1. Chakuli_Mosaic Plot 647 (Atabira vs Attabira)
2. G_Dimbo Plot 12 and Plot 1 (Option Value vs Label Mismatch)
3. Raghunathpur Jali Plot 333 (Mega-village AJAX timeout)
"""
import sys
import os
import json
import httpx
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

def capture_baseline():
    print("=" * 80)
    print("PHASE 7.7A BASELINE FAILURE REPRODUCTION")
    print("=" * 80)
    
    client = httpx.Client(base_url="http://127.0.0.1:8000/api/v1", timeout=120.0)
    results = {}
    
    # 1. Case A: Chakuli_Mosaic Plot 647
    print("\n--- CASE A: Chakuli_Mosaic Plot 647 (Atabira) ---")
    p_a = {"district": "Bargarh", "tahasil": "Atabira", "village": "Chakuli_Mosaic", "plot": "647"}
    t0 = time.time()
    try:
        r_a = client.get("/ror", params=p_a)
        dur_a = time.time() - t0
        results["case_a"] = {
            "requested": p_a,
            "status_code": r_a.status_code,
            "duration": dur_a,
            "response": r_a.json() if r_a.headers.get("content-type", "").startswith("application/json") else r_a.text
        }
        print(f"Status: {r_a.status_code} ({dur_a:.2f}s)")
        print(json.dumps(results["case_a"]["response"], indent=2, ensure_ascii=False))
    except Exception as e:
        results["case_a"] = {"requested": p_a, "error": str(e), "duration": time.time() - t0}
        print(f"Error: {e}")

    # 2. Case B1: G_Dimbo Plot 12
    print("\n--- CASE B1: G_Dimbo Plot 12 ---")
    p_b1 = {"district": "Keonjhar", "tahasil": "Keonjhar Sadar", "village": "G_Dimbo", "plot": "12", "b_id": "0704", "v_id": "0704317"}
    t0 = time.time()
    try:
        r_b1 = client.get("/ror", params=p_b1)
        dur_b1 = time.time() - t0
        results["case_b1"] = {
            "requested": p_b1,
            "status_code": r_b1.status_code,
            "duration": dur_b1,
            "response": r_b1.json() if r_b1.headers.get("content-type", "").startswith("application/json") else r_b1.text
        }
        print(f"Status: {r_b1.status_code} ({dur_b1:.2f}s)")
        print(json.dumps(results["case_b1"]["response"], indent=2, ensure_ascii=False))
    except Exception as e:
        results["case_b1"] = {"requested": p_b1, "error": str(e), "duration": time.time() - t0}
        print(f"Error: {e}")

    # 3. Case B2: G_Dimbo Plot 1
    print("\n--- CASE B2: G_Dimbo Plot 1 ---")
    p_b2 = {"district": "Keonjhar", "tahasil": "Keonjhar Sadar", "village": "G_Dimbo", "plot": "1", "b_id": "0704", "v_id": "0704317"}
    t0 = time.time()
    try:
        r_b2 = client.get("/ror", params=p_b2)
        dur_b2 = time.time() - t0
        results["case_b2"] = {
            "requested": p_b2,
            "status_code": r_b2.status_code,
            "duration": dur_b2,
            "response": r_b2.json() if r_b2.headers.get("content-type", "").startswith("application/json") else r_b2.text
        }
        print(f"Status: {r_b2.status_code} ({dur_b2:.2f}s)")
        print(json.dumps(results["case_b2"]["response"], indent=2, ensure_ascii=False))
    except Exception as e:
        results["case_b2"] = {"requested": p_b2, "error": str(e), "duration": time.time() - t0}
        print(f"Error: {e}")

    # 4. Case C: Raghunathpur Jali Plot 333
    print("\n--- CASE C: Raghunathpur Jali Plot 333 ---")
    p_c = {"district": "Khordha", "tahasil": "Bhubaneswar", "village": "Raghunathpur_Jali", "plot": "333", "b_id": "2002", "v_id": "2002359"}
    t0 = time.time()
    try:
        r_c = client.get("/ror", params=p_c)
        dur_c = time.time() - t0
        results["case_c"] = {
            "requested": p_c,
            "status_code": r_c.status_code,
            "duration": dur_c,
            "response": r_c.json() if r_c.headers.get("content-type", "").startswith("application/json") else r_c.text
        }
        print(f"Status: {r_c.status_code} ({dur_c:.2f}s)")
        print(json.dumps(results["case_c"]["response"], indent=2, ensure_ascii=False))
    except Exception as e:
        results["case_c"] = {"requested": p_c, "error": str(e), "duration": time.time() - t0}
        print(f"Error: {e}")

    with open("/Users/uday/Documents/MyBhoomi/BhulekBackend/scratch_phase7_7_baseline.json", "w") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print("\nBaseline saved to scratch_phase7_7_baseline.json")

if __name__ == "__main__":
    capture_baseline()
