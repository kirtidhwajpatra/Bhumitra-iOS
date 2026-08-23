#!/usr/bin/env python3
"""
Fetch exact official villages from BhulekhService.asmx VillagesUnicode
"""
import httpx
import xml.etree.ElementTree as ET

def get_villages(d_code, t_code):
    url = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/VillagesUnicode"
    }
    body = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <VillagesUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{d_code}</dCode>
      <tCode>{t_code}</tCode>
    </VillagesUnicode>
  </soap:Body>
</soap:Envelope>"""

    r = httpx.post(url, data=body, headers=headers, timeout=20.0, verify=False)
    print("Status:", r.status_code)
    print("Response snippet:", r.text[:500])
    return []

print("--- District 15 (Bargarh), Tahasil 1 (Attabira) ---")
v_atabira = get_villages(15, 1)
print(f"Total villages: {len(v_atabira)}")
for code, name in v_atabira:
    if "ଚାକୁଲି" in name or "CHAKULI" in name.upper() or "30" in code:
        print(f"  Village Code: {code} -> {name}")

print("\n--- District 7 (Keonjhar), Tahasil 4 (Keonjhar Sadar) ---")
v_keonjhar = get_villages(7, 4)
print(f"Total villages: {len(v_keonjhar)}")
for code, name in v_keonjhar:
    if "ଡିମ୍ବୋ" in name or "DIMBO" in name.upper() or "317" in code:
        print(f"  Village Code: {code} -> {name}")

print("\n--- District 20 (Khordha), Tahasil 2 (Bhubaneswar) ---")
v_bhubaneswar = get_villages(20, 2)
print(f"Total villages: {len(v_bhubaneswar)}")
for code, name in v_bhubaneswar:
    if "ରଘୁନାଥପୁର" in name or "RAGHUNATHPUR" in name.upper() or "359" in code:
        print(f"  Village Code: {code} -> {name}")
