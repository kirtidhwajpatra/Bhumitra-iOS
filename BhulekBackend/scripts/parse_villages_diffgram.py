#!/usr/bin/env python3
"""
Parse DiffGram from VillagesUnicode
"""
import httpx
from bs4 import BeautifulSoup

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
    soup = BeautifulSoup(r.text, "xml")
    tables = soup.find_all("Table")
    villages = []
    for t in tables:
        children = {child.name: child.text for child in t.find_all()}
        villages.append(children)
    return villages

print("--- District 15 (Bargarh), Tahasil 1 (Attabira) ---")
v_atabira = get_villages(15, 1)
print(f"Total villages: {len(v_atabira)}")
if v_atabira:
    print(f"Sample row: {v_atabira[0]}")
    for row in v_atabira:
        txt = str(row)
        if "ଚାକୁଲି" in txt or "CHAKULI" in txt.upper() or "30" in txt:
            print(f"  Match: {row}")

print("\n--- District 7 (Keonjhar), Tahasil 4 (Keonjhar Sadar) ---")
v_keonjhar = get_villages(7, 4)
print(f"Total villages: {len(v_keonjhar)}")
if v_keonjhar:
    print(f"Sample row: {v_keonjhar[0]}")
    for row in v_keonjhar:
        txt = str(row)
        if "ଡିମ୍ବୋ" in txt or "DIMBO" in txt.upper() or "317" in txt:
            print(f"  Match: {row}")

print("\n--- District 20 (Khordha), Tahasil 2 (Bhubaneswar) ---")
v_bhubaneswar = get_villages(20, 2)
print(f"Total villages: {len(v_bhubaneswar)}")
if v_bhubaneswar:
    print(f"Sample row: {v_bhubaneswar[0]}")
    for row in v_bhubaneswar:
        txt = str(row)
        if "ରଘୁନାଥପୁର" in txt or "RAGHUNATHPUR" in txt.upper() or "359" in txt:
            print(f"  Match: {row}")
