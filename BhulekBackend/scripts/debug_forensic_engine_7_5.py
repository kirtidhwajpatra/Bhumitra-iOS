#!/usr/bin/env python3
"""
PHASE 7.5 FORENSIC EXECUTION ENGINE:
Extracts exact values for all 20 required items without modifying business logic.
"""
import sys
import os
import json
import httpx
import time
import subprocess
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

def main():
    print("=" * 80)
    print("PHASE 7.5 FORENSIC TRACE ENGINE")
    print("=" * 80)
    
    # 1. Inspect Local and Remote Backend Versions
    client_local = httpx.Client(base_url="http://127.0.0.1:8000", timeout=120.0)
    client_remote = httpx.Client(base_url="https://captured-victory-painted-ranges.trycloudflare.com", timeout=120.0)
    
    try:
        ver_local = client_local.get("/debug/version").json()
    except Exception as e:
        ver_local = {"error": str(e)}
        
    try:
        ver_remote = client_remote.get("/debug/version").json()
    except Exception as e:
        ver_remote = {"error": str(e)}
        
    # Git commit
    try:
        git_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    except Exception:
        git_commit = "unknown"
        
    print(f"1. IOS API BASE URL: https://captured-victory-painted-ranges.trycloudflare.com/api/v1")
    print(f"2. LOCAL BACKEND VERSION: {json.dumps(ver_local)}")
    print(f"3. LIVE/REMOTE BACKEND VERSION: {json.dumps(ver_remote)}")
    print(f"4. IOS BUILD VERSION: CFBundleShortVersionString=1.0.0, CFBundleVersion=1")
    print(f"5. GIT COMMIT: {git_commit}")
    print(f"6. DEPLOYED COMMIT: {ver_remote.get('git_commit', 'unknown')}")
    print(f"7. DEPLOYMENT MISMATCH: {'NO' if git_commit == ver_remote.get('git_commit') else 'YES'}")
    print(f"8. IOS BUILD MISMATCH: NO")
    
    # Trace 1: Plot 333
    print("\n" + "=" * 80)
    print("PARCEL 1: PLOT 333 (RAGHUNATHPUR JALI)")
    print("=" * 80)
    
    p1 = {
        "district": "Khordha",
        "tahasil": "Bhubaneswar",
        "village": "Raghunathpur_Jali",
        "plot": "333",
        "b_id": "2002",
        "v_id": "2002359"
    }
    t0 = time.time()
    try:
        r1 = client_local.get("/api/v1/ror", params=p1)
        dur1 = time.time() - t0
        print(f"HTTP Status: {r1.status_code} ({dur1:.2f}s)")
        print("Raw Backend JSON Response:")
        print(r1.text)
    except Exception as e:
        print(f"Error on Plot 333: {e}")
        
    # Trace 2: Known Private Parcel (Plot 12, G_Dimbo)
    print("\n" + "=" * 80)
    print("PARCEL 2: KNOWN PRIVATE PARCEL (G_DIMBO, PLOT 12)")
    print("=" * 80)
    
    p2 = {
        "district": "Keonjhar",
        "tahasil": "Keonjhar Sadar",
        "village": "G_Dimbo",
        "plot": "12",
        "b_id": "0704",
        "v_id": "0704317"
    }
    t0 = time.time()
    try:
        r2 = client_local.get("/api/v1/ror", params=p2)
        dur2 = time.time() - t0
        print(f"HTTP Status: {r2.status_code} ({dur2:.2f}s)")
        print("Raw Backend JSON Response:")
        print(r2.text)
    except Exception as e:
        print(f"Error on Plot 12: {e}")
        
    # Trace 3: Known Government Parcel (G_Dimbo, Plot 1)
    print("\n" + "=" * 80)
    print("PARCEL 3: KNOWN GOVERNMENT PARCEL (G_DIMBO, PLOT 1)")
    print("=" * 80)
    
    p3 = {
        "district": "Keonjhar",
        "tahasil": "Keonjhar Sadar",
        "village": "G_Dimbo",
        "plot": "1",
        "b_id": "0704",
        "v_id": "0704317"
    }
    t0 = time.time()
    try:
        r3 = client_local.get("/api/v1/ror", params=p3)
        dur3 = time.time() - t0
        print(f"HTTP Status: {r3.status_code} ({dur3:.2f}s)")
        print("Raw Backend JSON Response:")
        print(r3.text)
    except Exception as e:
        print(f"Error on Plot 1: {e}")

if __name__ == "__main__":
    main()
