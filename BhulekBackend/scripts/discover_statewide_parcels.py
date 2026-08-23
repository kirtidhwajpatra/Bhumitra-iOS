#!/usr/bin/env python3
"""
Statewide Real Parcel Discovery Engine
Builds a curated dataset of 50+ real parcels across 30+ villages across all 5 zones in Odisha.
"""
import asyncio
import json
import httpx
from bs4 import BeautifulSoup

ZONES = {
    "North": [
        {"dist_name": "Keonjhar", "dCode": "7", "tCode": "4", "tah_name": "Keonjhar Sadar"},
        {"dist_name": "Mayurbhanj", "dCode": "9", "tCode": "1", "tah_name": "Baripada"},
        {"dist_name": "Sundargarh", "dCode": "13", "tCode": "1", "tah_name": "Sundargarh"},
    ],
    "Central": [
        {"dist_name": "Cuttack", "dCode": "3", "tCode": "1", "tah_name": "Cuttack Sadar"},
        {"dist_name": "Dhenkanal", "dCode": "4", "tCode": "1", "tah_name": "Dhenkanal"},
        {"dist_name": "Angul", "dCode": "14", "tCode": "1", "tah_name": "Angul"},
        {"dist_name": "Jajpur", "dCode": "18", "tCode": "1", "tah_name": "Jajpur"},
    ],
    "Coastal": [
        {"dist_name": "Khordha", "dCode": "20", "tCode": "2", "tah_name": "Bhubaneswar"},
        {"dist_name": "Puri", "dCode": "11", "tCode": "1", "tah_name": "Puri"},
        {"dist_name": "Bhadrak", "dCode": "16", "tCode": "1", "tah_name": "Bhadrak"},
        {"dist_name": "Balasore", "dCode": "1", "tCode": "1", "tah_name": "Balasore"},
        {"dist_name": "Kendrapara", "dCode": "19", "tCode": "1", "tah_name": "Kendrapara"},
        {"dist_name": "Jagatsinghpur", "dCode": "17", "tCode": "1", "tah_name": "Jagatsinghpur"},
    ],
    "Western": [
        {"dist_name": "Bargarh", "dCode": "15", "tCode": "1", "tah_name": "Atabira"},
        {"dist_name": "Sambalpur", "dCode": "12", "tCode": "1", "tah_name": "Sambalpur"},
        {"dist_name": "Bolangir", "dCode": "2", "tCode": "1", "tah_name": "Bolangir"},
        {"dist_name": "Jharsuguda", "dCode": "30", "tCode": "1", "tah_name": "Jharsuguda"},
    ],
    "Southern": [
        {"dist_name": "Ganjam", "dCode": "5", "tCode": "1", "tah_name": "Berhampur"},
        {"dist_name": "Koraput", "dCode": "8", "tCode": "1", "tah_name": "Koraput"},
        {"dist_name": "Rayagada", "dCode": "27", "tCode": "1", "tah_name": "Rayagada"},
        {"dist_name": "Kalahandi", "dCode": "6", "tCode": "1", "tah_name": "Bhawanipatna"},
        {"dist_name": "Gajapati", "dCode": "24", "tCode": "1", "tah_name": "Paralakhemundi"},
    ]
}

SOAP_URL = "https://bhulekh.ori.nic.in/BhulekhService.asmx"

async def get_villages_for_tahasil(client, dCode, tCode):
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
    try:
        r = await client.post(SOAP_URL, data=body, headers=headers)
        if r.status_code == 200:
            soup = BeautifulSoup(r.text, "xml")
            villages = []
            for v in soup.find_all("Table"):
                v_code = v.find("code")
                v_name = v.find("oname")
                if v_code and v_name:
                    villages.append({"code": v_code.text.strip(), "name": v_name.text.strip()})
            return villages
    except Exception as e:
        print(f"Error fetching villages for dCode={dCode}, tCode={tCode}: {e}")
    return []

async def get_khatas_and_plots(client, dCode, tCode, vCode):
    headers_k = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/KhatiyanUnicode"
    }
    body_k = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <KhatiyanUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{dCode}</dCode>
      <tCode>{tCode}</tCode>
      <vCode>{vCode}</vCode>
    </KhatiyanUnicode>
  </soap:Body>
</soap:Envelope>"""
    try:
        r_k = await client.post(SOAP_URL, data=body_k, headers=headers_k)
        if r_k.status_code != 200:
            return []
        soup_k = BeautifulSoup(r_k.text, "xml")
        khatas = [k.text.strip() for k in soup_k.find_all("okhata_no")]
        if not khatas:
            return []
            
        headers_p = {
            "Content-Type": "text/xml; charset=utf-8",
            "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/PlotsUnicode"
        }
        plots_info = []
        for k in khatas[:3]:
            body_p = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <PlotsUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{dCode}</dCode>
      <tCode>{tCode}</tCode>
      <vCode>{vCode}</vCode>
      <khata_no>{k}</khata_no>
    </PlotsUnicode>
  </soap:Body>
</soap:Envelope>"""
            r_p = await client.post(SOAP_URL, data=body_p, headers=headers_p)
            if r_p.status_code == 200:
                soup_p = BeautifulSoup(r_p.text, "xml")
                plots = [p.text.strip() for p in soup_p.find_all("oplot_no")]
                for p in plots[:2]:
                    plots_info.append({"khata": k, "plot": p})
            if len(plots_info) >= 2:
                break
        return plots_info
    except Exception as e:
        print(f"Error fetching khatas/plots: {e}")
    return []

async def main():
    async with httpx.AsyncClient(timeout=20.0, verify=False) as client:
        selected_dataset = []
        village_count = 0
        
        # Include our core villages first
        selected_dataset.extend([
            {"zone": "Western", "district": "Bargarh", "dCode": "15", "tahasil": "Atabira", "tCode": "1", "village_name": "ଚକୁଳି", "vCode": "61", "khata": "277", "plot": "647"},
            {"zone": "Western", "district": "Bargarh", "dCode": "15", "tahasil": "Atabira", "tCode": "1", "village_name": "ଚକୁଳି", "vCode": "61", "khata": "277", "plot": "614"},
            {"zone": "Coastal", "district": "Khordha", "dCode": "20", "tahasil": "Bhubaneswar", "tCode": "2", "village_name": "ରଘୁନାଥପୁର ଜଳି", "vCode": "359", "khata": "538", "plot": "333"},
            {"zone": "Coastal", "district": "Khordha", "dCode": "20", "tahasil": "Bhubaneswar", "tCode": "2", "village_name": "ରଘୁନାଥପୁର ଜଳି", "vCode": "359", "khata": "538", "plot": "555"},
            {"zone": "North", "district": "Keonjhar", "dCode": "7", "tahasil": "Keonjhar Sadar", "tCode": "4", "village_name": "ଡ଼ିମ୍ବୋ", "vCode": "317", "khata": "112", "plot": "12"},
            {"zone": "North", "district": "Keonjhar", "dCode": "7", "tahasil": "Keonjhar Sadar", "tCode": "4", "village_name": "ଡ଼ିମ୍ବୋ", "vCode": "317", "khata": "230", "plot": "1"},
        ])
        village_count += 3

        for zone, entries in ZONES.items():
            print(f"\n--- Gathering Zone: {zone} ---")
            for entry in entries:
                v_list = await get_villages_for_tahasil(client, entry["dCode"], entry["tCode"])
                print(f"  District: {entry['dist_name']} ({entry['tah_name']}) -> {len(v_list)} villages found")
                
                # Pick 2-3 villages per district
                added_for_dist = 0
                for v in v_list[:10]:
                    if added_for_dist >= 2:
                        break
                    # Avoid duplicate core villages
                    if v["name"] in ["ଚକୁଳି", "ରଘୁନାଥପୁର ଜଳି", "ଡ଼ିମ୍ବୋ"]:
                        continue
                    kp = await get_khatas_and_plots(client, entry["dCode"], entry["tCode"], v["code"])
                    if kp:
                        added_for_dist += 1
                        village_count += 1
                        for item in kp[:2]:
                            selected_dataset.append({
                                "zone": zone,
                                "district": entry["dist_name"],
                                "dCode": entry["dCode"],
                                "tahasil": entry["tah_name"],
                                "tCode": entry["tCode"],
                                "village_name": v["name"],
                                "vCode": v["code"],
                                "khata": item["khata"],
                                "plot": item["plot"],
                            })
                            print(f"    Village: {v['name']} ({v['code']}) | Khata: {item['khata']} | Plot: {item['plot']}")
                            
        print(f"\nTotal Selected: {len(selected_dataset)} parcels across {village_count} villages from {len(ZONES)} zones.")
        with open("/Users/uday/Documents/MyBhoomi/BhulekBackend/scripts/discovered_statewide_parcels.json", "w") as f:
            json.dump(selected_dataset, f, indent=2, ensure_ascii=False)

if __name__ == "__main__":
    asyncio.run(main())
