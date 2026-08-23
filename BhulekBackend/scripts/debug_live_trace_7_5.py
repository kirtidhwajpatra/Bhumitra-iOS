#!/usr/bin/env python3
"""
PHASE 7.5: Live Production Trace Diagnostic Script
Traces:
1. Plot 333 (Golden Parcel - Raghunathpur Jali)
2. Second Private Parcel (Plot 12 - G_Dimbo, Keonjhar)
3. Known Government Parcel (Khata 1 Rakhita Sarkari)
"""
import sys
import os
import json
import httpx
import uuid
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

def run_trace():
    print("=" * 80)
    print("PHASE 7.5 LIVE PRODUCTION TRACE DIAGNOSTIC")
    print("=" * 80)
    
    client = httpx.Client(base_url="http://127.0.0.1:8000/api/v1", timeout=60.0)
    
    # 1. Check version endpoint
    r_ver = client.get("/debug/version")
    print("\n--- SERVER VERSION METADATA ---")
    print(json.dumps(r_ver.json(), indent=2))
    
    # 2. Trace 1: Golden Parcel (Khordha / Bhubaneswar / Raghunathpur_Jali / Plot 333)
    print("\n" + "=" * 80)
    print("TRACE 1: GOLDEN PARCEL (Raghunathpur Jali / Plot 333)")
    print("=" * 80)
    
    req_id_1 = str(uuid.uuid4())
    params_1 = {
        "district": "Khordha",
        "tahasil": "Bhubaneswar",
        "village": "Raghunathpur_Jali",
        "plot": "333",
        "b_id": "2002",
        "v_id": "2002359"
    }
    headers_1 = {"X-Request-ID": req_id_1}
    
    print(f"Request ID: {req_id_1}")
    print(f"Request URL: http://127.0.0.1:8000/api/v1/ror")
    print(f"Request Params: {params_1}")
    
    t0 = datetime.now(timezone.utc)
    try:
        r1 = client.get("/ror", params=params_1, headers=headers_1)
        duration_1 = (datetime.now(timezone.utc) - t0).total_seconds()
        print(f"Response Status: HTTP {r1.status_code} ({duration_1:.2f}s)")
        print("Raw Backend JSON Response:")
        try:
            resp_json_1 = r1.json()
            print(json.dumps(resp_json_1, indent=2))
        except Exception:
            print(r1.text)
    except Exception as e:
        print(f"HTTP Request Exception: {e}")

    # 3. Trace 2: Second Private Parcel (Keonjhar / Keonjhar Sadar / G_Dimbo / Plot 12)
    print("\n" + "=" * 80)
    print("TRACE 2: SECOND PRIVATE PARCEL (Dimbo / Plot 12)")
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
    headers_2 = {"X-Request-ID": req_id_2}
    print(f"Request ID: {req_id_2}")
    print(f"Request Params: {params_2}")
    
    t0 = datetime.now(timezone.utc)
    try:
        r2 = client.get("/ror", params=params_2, headers=headers_2)
        duration_2 = (datetime.now(timezone.utc) - t0).total_seconds()
        print(f"Response Status: HTTP {r2.status_code} ({duration_2:.2f}s)")
        print("Raw Backend JSON Response:")
        try:
            resp_json_2 = r2.json()
            print(json.dumps(resp_json_2, indent=2))
        except Exception:
            print(r2.text)
    except Exception as e:
        print(f"HTTP Request Exception: {e}")

    # 4. Trace 3: Known Government Parcel (Khata 1 in Dimbo or Sadar)
    print("\n" + "=" * 80)
    print("TRACE 3: KNOWN GOVERNMENT PARCEL (Dimbo / Plot 1 - Khata 1)")
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
    headers_3 = {"X-Request-ID": req_id_3}
    print(f"Request ID: {req_id_3}")
    print(f"Request Params: {params_3}")
    
    t0 = datetime.now(timezone.utc)
    try:
        r3 = client.get("/ror", params=params_3, headers=headers_3)
        duration_3 = (datetime.now(timezone.utc) - t0).total_seconds()
        print(f"Response Status: HTTP {r3.status_code} ({duration_3:.2f}s)")
        print("Raw Backend JSON Response:")
        try:
            resp_json_3 = r3.json()
            print(json.dumps(resp_json_3, indent=2))
        except Exception:
            print(r3.text)
    except Exception as e:
        print(f"HTTP Request Exception: {e}")

if __name__ == "__main__":
    run_trace()
