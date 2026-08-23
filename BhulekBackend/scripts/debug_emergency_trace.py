#!/usr/bin/env python3
"""
Emergency Diagnostic Trace:
1. Plot 647 (Bargarh / Atabira / Chakuli_Mosaic)
2. Second Private Parcel (Plot 12 / Keonjhar / G_Dimbo)
3. Known Government Parcel (Plot 1 / Keonjhar / G_Dimbo / Khata 1)
"""
import sys
import os
import json
import httpx
import uuid

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

def run_trace():
    print("=" * 80)
    print("EMERGENCY DIAGNOSTIC TRACE - RAW ROR PIPELINE")
    print("=" * 80)
    
    client = httpx.Client(base_url="http://127.0.0.1:8000/api/v1", timeout=60.0)
    
    # 1. PARCEL A: Plot 647 (Bargarh / Atabira / Chakuli_Mosaic)
    print("\n" + "=" * 80)
    print("PARCEL A: PLOT 647 (BARGARH / ATABIRA / CHAKULI_MOSAIC)")
    print("=" * 80)
    req_id_1 = str(uuid.uuid4())
    params_1 = {
        "district": "Bargarh",
        "tahasil": "Atabira",
        "village": "Chakuli_Mosaic",
        "plot": "647"
    }
    try:
        r1 = client.get("/ror", params=params_1, headers={"X-Request-ID": req_id_1})
        print(f"HTTP Status: {r1.status_code}")
        print("Raw Backend JSON Response:")
        try:
            print(json.dumps(r1.json(), indent=2, ensure_ascii=False))
        except Exception:
            print(r1.text)
    except Exception as e:
        print(f"Request Error: {e}")
        
    # 2. PARCEL B: Second Private Parcel (G_Dimbo / Plot 12)
    print("\n" + "=" * 80)
    print("PARCEL B: SECOND PRIVATE PARCEL (KEONJHAR / G_DIMBO / PLOT 12)")
    print("=" * 80)
    req_id_2 = str(uuid.uuid4())
    params_2 = {
        "district": "Keonjhar",
        "tahasil": "Keonjhar Sadar",
        "village": "G_Dimbo",
        "plot": "12",
        "b_id": "0704",
        "v_id": "0704317"
    }
    try:
        r2 = client.get("/ror", params=params_2, headers={"X-Request-ID": req_id_2})
        print(f"HTTP Status: {r2.status_code}")
        print("Raw Backend JSON Response:")
        try:
            print(json.dumps(r2.json(), indent=2, ensure_ascii=False))
        except Exception:
            print(r2.text)
    except Exception as e:
        print(f"Request Error: {e}")
        
    # 3. PARCEL C: Known Government Parcel (G_Dimbo / Plot 1)
    print("\n" + "=" * 80)
    print("PARCEL C: KNOWN GOVERNMENT PARCEL (KEONJHAR / G_DIMBO / PLOT 1)")
    print("=" * 80)
    req_id_3 = str(uuid.uuid4())
    params_3 = {
        "district": "Keonjhar",
        "tahasil": "Keonjhar Sadar",
        "village": "G_Dimbo",
        "plot": "1",
        "b_id": "0704",
        "v_id": "0704317"
    }
    try:
        r3 = client.get("/ror", params=params_3, headers={"X-Request-ID": req_id_3})
        print(f"HTTP Status: {r3.status_code}")
        print("Raw Backend JSON Response:")
        try:
            print(json.dumps(r3.json(), indent=2, ensure_ascii=False))
        except Exception:
            print(r3.text)
    except Exception as e:
        print(f"Request Error: {e}")

if __name__ == "__main__":
    run_trace()
