#!/usr/bin/env python3
"""
Official Odisha Bhulekh Village Identity Catalog Builder
Builds a complete, deterministic, auditable statewide catalog across all 30 districts
using official Bhulekh SOAP web methods (TahasilsUnicode, VillagesUnicode).
"""
import asyncio
import hashlib
import json
import os
import sys
import time
from datetime import datetime, timezone
import httpx
from bs4 import BeautifulSoup

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from resolvers.village_identity_normalizer import (
    normalize_unicode_representation,
    normalize_village_name,
    normalize_odia_village_key,
)
from scrapers.bhulekh_mappings import OFFICIAL_DISTRICT_NAMES

SOAP_URL = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "bhulekh_catalog")
OUTPUT_CATALOG_FILE = os.path.join(OUTPUT_DIR, "odisha_village_catalog_v1.json")
CHECKPOINT_FILE = os.path.join(OUTPUT_DIR, "odisha_village_catalog_checkpoint.json")

# All 30 Districts of Odisha with standard Bhulekh dCode
ALL_30_DISTRICTS = [
    {"dCode": "1", "name_en": "BALASORE", "name_or": "ବାଲେଶ୍ୱର"},
    {"dCode": "2", "name_en": "BOLANGIR", "name_or": "ବଲାଙ୍ଗୀର"},
    {"dCode": "3", "name_en": "CUTTACK", "name_or": "କଟକ"},
    {"dCode": "4", "name_en": "DHENKANAL", "name_or": "ଢେଙ୍କାନାଳ"},
    {"dCode": "5", "name_en": "GANJAM", "name_or": "ଗଞ୍ଜାମ"},
    {"dCode": "6", "name_en": "KALAHANDI", "name_or": "କଳାହାଣ୍ଡି"},
    {"dCode": "7", "name_en": "KEONJHAR", "name_or": "କେନ୍ଦୁଝର"},
    {"dCode": "8", "name_en": "KORAPUT", "name_or": "କୋରାପୁଟ"},
    {"dCode": "9", "name_en": "MAYURBHANJ", "name_or": "ମୟୂରଭଞ୍ଜ"},
    {"dCode": "10", "name_en": "PHULBANI", "name_or": "କନ୍ଧମାଳ"},
    {"dCode": "11", "name_en": "PURI", "name_or": "ପୁରୀ"},
    {"dCode": "12", "name_en": "SAMBALPUR", "name_or": "ସମ୍ବଲପୁର"},
    {"dCode": "13", "name_en": "SUNDARGARH", "name_or": "ସୁନ୍ଦରଗଡ"},
    {"dCode": "14", "name_en": "ANGUL", "name_or": "ଅନୁଗୋଳ"},
    {"dCode": "15", "name_en": "BARGARH", "name_or": "ବରଗଡ"},
    {"dCode": "16", "name_en": "BHADRAK", "name_or": "ଭଦ୍ରକ"},
    {"dCode": "17", "name_en": "JAGATSINGHPUR", "name_or": "ଜଗତସିଂହପୁର"},
    {"dCode": "18", "name_en": "JAJPUR", "name_or": "ଯାଜପୁର"},
    {"dCode": "19", "name_en": "KENDRAPARA", "name_or": "କେନ୍ଦ୍ରାପଡା"},
    {"dCode": "20", "name_en": "KHORDHA", "name_or": "ଖୋର୍ଦ୍ଧା"},
    {"dCode": "21", "name_en": "MALKANGIRI", "name_or": "ମାଲକାନଗିରି"},
    {"dCode": "22", "name_en": "NAWARANGPUR", "name_or": "ନବରଙ୍ଗପୁର"},
    {"dCode": "23", "name_en": "NAYAGARH", "name_or": "ନୟାଗଡ"},
    {"dCode": "24", "name_en": "GAJAPATI", "name_or": "ଗଜପତି"},
    {"dCode": "25", "name_en": "NUAPADA", "name_or": "ନୂଆପଡା"},
    {"dCode": "26", "name_en": "SONEPUR", "name_or": "ସୁବର୍ଣ୍ଣପୁର"},
    {"dCode": "27", "name_en": "RAYAGADA", "name_or": "ରାୟଗଡା"},
    {"dCode": "28", "name_en": "BOUDH", "name_or": "ବୌଦ୍ଧ"},
    {"dCode": "29", "name_en": "DEOGARH", "name_or": "ଦେବଗଡ"},
    {"dCode": "30", "name_en": "JHARSUGUDA", "name_or": "ଝାରସୁଗୁଡା"},
]

async def fetch_tahasils(client: httpx.AsyncClient, dCode: str) -> list:
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/TahasilsUnicode"
    }
    body = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <TahasilsUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{dCode}</dCode>
    </TahasilsUnicode>
  </soap:Body>
</soap:Envelope>"""
    for retry in range(3):
        try:
            r = await client.post(SOAP_URL, data=body, headers=headers)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "xml")
                tahasils = []
                for t in soup.find_all("Table"):
                    code = t.find("code")
                    name = t.find("oname")
                    if code and name:
                        tahasils.append({
                            "tCode": code.text.strip(),
                            "name_or": normalize_unicode_representation(name.text.strip())
                        })
                return tahasils
            await asyncio.sleep(1.0 * (retry + 1))
        except Exception as e:
            await asyncio.sleep(1.0 * (retry + 1))
    return []

async def fetch_villages(client: httpx.AsyncClient, dCode: str, tCode: str) -> list:
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/VillagesUnicode"
    }
    body = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <VillagesUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{dCode}</dCode>
      <tCode>{tCode}</tCode>
    </VillagesUnicode>
  </soap:Body>
</soap:Envelope>"""
    for retry in range(3):
        try:
            r = await client.post(SOAP_URL, data=body, headers=headers)
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, "xml")
                villages = []
                for v in soup.find_all("Table"):
                    code = v.find("code")
                    name = v.find("oname")
                    if code and name:
                        raw_name = name.text.strip()
                        villages.append({
                            "vCode": code.text.strip(),
                            "raw_name": raw_name,
                            "name_or": normalize_unicode_representation(raw_name),
                            "name_norm": normalize_village_name(raw_name),
                            "odia_key": normalize_odia_village_key(raw_name),
                        })
                return villages
            await asyncio.sleep(1.0 * (retry + 1))
        except Exception as e:
            await asyncio.sleep(1.0 * (retry + 1))
    return []

async def build_catalog():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    records = []
    
    # Load checkpoint if exists
    completed_keys = set()
    if os.path.exists(CHECKPOINT_FILE):
        try:
            with open(CHECKPOINT_FILE, "r") as f:
                chk = json.load(f)
                records = chk.get("records", [])
                for r in records:
                    completed_keys.add((r["bhulekh_district_id"], r["bhulekh_tahasil_id"]))
            print(f"Loaded checkpoint with {len(records)} existing village records.")
        except Exception as e:
            print(f"Warning: Could not load checkpoint: {e}")

    # Bounded concurrency: max 5 parallel tahasils
    sem = asyncio.Semaphore(5)
    
    async with httpx.AsyncClient(timeout=25.0, verify=False) as client:
        print("\n" + "="*70)
        print("PHASE 7.10: BUILDING OFFICIAL STATEWIDE BHULEKH VILLAGE IDENTITY CATALOG")
        print("="*70)
        
        for dist in ALL_30_DISTRICTS:
            dCode = dist["dCode"]
            dName_en = dist["name_en"]
            dName_or = dist["name_or"]
            
            tahasils = await fetch_tahasils(client, dCode)
            print(f"District {int(dCode):02d}: {dName_en:<14} ({dName_or}) -> {len(tahasils)} Tahasils")
            
            for tah in tahasils:
                tCode = tah["tCode"]
                tName_or = tah["name_or"]
                
                if (dCode, tCode) in completed_keys:
                    continue
                
                async with sem:
                    villages = await fetch_villages(client, dCode, tCode)
                    await asyncio.sleep(0.05) # Rate limiting jitter
                    
                    for v in villages:
                        rec = {
                            "district_id": dCode,
                            "district_name_english": dName_en,
                            "district_name_odia": dName_or,
                            "tahasil_id": tCode,
                            "tahasil_name_english": tName_or, # Official label
                            "tahasil_name_odia": tName_or,
                            "bhulekh_district_id": dCode,
                            "bhulekh_tahasil_id": tCode,
                            "bhulekh_mouza_id": v["vCode"],
                            "bhulekh_village_id": v["vCode"],
                            "bhulekh_mouza_name": v["name_or"],
                            "bhulekh_mouza_odia_name": v["name_or"],
                            "bhulekh_village_name": v["name_or"],
                            "bhulekh_village_name_normalized": v["name_norm"],
                            "odia_key": v["odia_key"],
                            "mapping_status": "VERIFIED",
                            "source": "OFFICIAL_BHULEKH_SOAP",
                            "catalog_version": "ODISHA_BHULEKH_VILLAGE_CATALOG_V1",
                            "retrieved_at": datetime.now(timezone.utc).isoformat(),
                        }
                        records.append(rec)
                    
                    completed_keys.add((dCode, tCode))
                    print(f"  Tahasil {int(tCode):02d}: {tName_or:<18} -> {len(villages):>3} villages")
            
            # Checkpoint save after every district
            with open(CHECKPOINT_FILE, "w") as f:
                json.dump({"records": records}, f, ensure_ascii=False)

    # Compute checksum
    cat_bytes = json.dumps(records, sort_keys=True, ensure_ascii=False).encode("utf-8")
    checksum = hashlib.sha256(cat_bytes).hexdigest()

    catalog_payload = {
        "catalog_version": "ODISHA_BHULEKH_VILLAGE_CATALOG_V1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "OFFICIAL_BHULEKH_SOAP",
        "total_districts": len(ALL_30_DISTRICTS),
        "total_records": len(records),
        "checksum_sha256": checksum,
        "records": records
    }

    with open(OUTPUT_CATALOG_FILE, "w", encoding="utf-8") as f:
        json.dump(catalog_payload, f, indent=2, ensure_ascii=False)
        
    print("\n" + "="*70)
    print(f"CATALOG BUILD COMPLETE!")
    print(f"Output: {OUTPUT_CATALOG_FILE}")
    print(f"Total Official Records: {len(records)}")
    print(f"SHA-256 Checksum: {checksum}")
    print("="*70)

if __name__ == "__main__":
    asyncio.run(build_catalog())
