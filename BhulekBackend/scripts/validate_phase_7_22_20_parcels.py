"""
Phase 7.22 20-Parcel Live Matrix & Forensic Trace Script
"""
import asyncio
import time
import httpx

API_BASE = "http://127.0.0.1:8000/api/v1/ror"

PARCELS_TO_TEST = [
    # Primary Target
    {"id": "P01", "name": "Chandakuda Plot 241", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Chandakuda", "plot": "241", "b_id": "1603", "v_id": "1603022", "exp_khata": "54"},
    
    # Associated Plots in Chandakuda Khata 54
    {"id": "P02", "name": "Chandakuda Plot 228", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Chandakuda", "plot": "228", "b_id": "1603", "v_id": "1603022", "exp_khata": "54"},
    {"id": "P03", "name": "Chandakuda Plot 238", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Chandakuda", "plot": "238", "b_id": "1603", "v_id": "1603022", "exp_khata": "54"},
    {"id": "P04", "name": "Chandakuda Plot 240", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Chandakuda", "plot": "240", "b_id": "1603", "v_id": "1603022", "exp_khata": "54"},
    {"id": "P05", "name": "Chandakuda Plot 273", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Chandakuda", "plot": "273", "b_id": "1603", "v_id": "1603022", "exp_khata": "54"},
    {"id": "P06", "name": "Chandakuda Plot 274", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Chandakuda", "plot": "274", "b_id": "1603", "v_id": "1603022", "exp_khata": "54"},
    
    # Phase 7.21 Benchmarks
    {"id": "P07", "name": "Rajgurupur Plot 188", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Rajgurupur", "plot": "188", "b_id": "1603", "v_id": "1603144", "exp_khata": "88"},
    {"id": "P08", "name": "Bhagabanpur Plot 104", "district": "Bhadrak", "tahasil": "Bhadrak", "village": "Bhagabanpur-147", "plot": "104", "b_id": "1602", "v_id": "1602038", "exp_khata": "210"},
    {"id": "P09", "name": "Bajarpur Plot 775", "district": "Kendrapara", "tahasil": "Rajkanika", "village": "Bajarapur", "plot": "775", "b_id": "2", "v_id": "168", "exp_khata": "94"},
    
    # Multi-owner / Area Formatting Benchmarks
    {"id": "P10", "name": "Dimbo Plot 12", "district": "Keonjhar", "tahasil": "Keonjhar Sadar", "village": "Dimbo", "plot": "12", "b_id": "0704", "v_id": "0704317", "exp_khata": "112"},
    {"id": "P11", "name": "Chakuli Plot 614", "district": "Bargarh", "tahasil": "Atabira", "village": "Chakuli", "plot": "614", "b_id": "1501", "v_id": "1501242", "exp_khata": "277"},
    {"id": "P12", "name": "G_Keri Plot 501", "district": "Keonjhar", "tahasil": "Keonjhar Sadar", "village": "G_Keri_271", "plot": "501", "b_id": "0704", "v_id": "0704271", "exp_khata": "104"},
    
    # Government & Diverse Holdings
    {"id": "P13", "name": "Garadapur Plot 50 (Govt)", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Garadapur", "plot": "50", "b_id": "1603", "v_id": "1603147", "exp_khata": "133"},
    {"id": "P14", "name": "Andiapata Plot 20", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Andiapata", "plot": "20", "b_id": "1603", "v_id": "1603121", "exp_khata": "62/51"},
    
    # Negative / Fail-Closed Tests
    {"id": "P15", "name": "Non-existent Plot 99999", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Chandakuda", "plot": "99999", "b_id": "1603", "v_id": "1603022", "exp_khata": None},
    {"id": "P16", "name": "Invalid Plot 0", "district": "Bhadrak", "tahasil": "Chandbali", "village": "Chandakuda", "plot": "0", "b_id": "1603", "v_id": "1603022", "exp_khata": None}
]

async def main():
    print("=" * 80)
    print("PHASE 7.22 LIVE FORENSIC MATRIX: 16 REAL PARCEL TEST SUITE")
    print("=" * 80)
    
    async with httpx.AsyncClient(timeout=45.0) as client:
        for p in PARCELS_TO_TEST:
            pid = p["id"]
            pname = p["name"]
            url = f"{API_BASE}?district={p['district']}&tahasil={p['tahasil']}&village={p['village']}&plot={p['plot']}&b_id={p['b_id']}&v_id={p['v_id']}"
            t0 = time.time()
            try:
                r = await client.get(url)
                elapsed = time.time() - t0
                if r.status_code == 200:
                    data = r.json()
                    khata = data.get("khata_number")
                    area = data.get("area")
                    owners = [o.get("name") for o in data.get("owners", [])]
                    v_status = data.get("verification", {}).get("status")
                    print(f"[{pid}] {pname} -> 200 OK in {elapsed:.2f}s | Verified: {v_status} | Khata: {khata} | Area: {area} | Owners ({len(owners)}): {owners[:2]}")
                else:
                    detail = r.json().get("detail", {})
                    msg = detail.get("message") or detail.get("details") or str(detail)
                    print(f"[{pid}] {pname} -> {r.status_code} in {elapsed:.2f}s | Fail-Closed: {msg[:60]}...")
            except Exception as e:
                elapsed = time.time() - t0
                print(f"[{pid}] {pname} -> TIMEOUT/ERR in {elapsed:.2f}s: {e}")

if __name__ == "__main__":
    asyncio.run(main())
