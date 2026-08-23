#!/usr/bin/env python3
"""
Find exact Khata for Plot 647 in Chakuli (15, 1, 61)
"""
import httpx
from bs4 import BeautifulSoup

def find_chakuli_647():
    url = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
    headers_k = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/KhatiyanUnicode"
    }
    body_k = """<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <KhatiyanUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>15</dCode>
      <tCode>1</tCode>
      <vCode>61</vCode>
    </KhatiyanUnicode>
  </soap:Body>
</soap:Envelope>"""

    r_k = httpx.post(url, data=body_k, headers=headers_k, timeout=20.0, verify=False)
    soup_k = BeautifulSoup(r_k.text, "xml")
    khatas = [t.text.strip() for t in soup_k.find_all("okhata_no")]
    print(f"Total Khatas in Chakuli: {len(khatas)}")
    
    headers_p = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/PlotsUnicode"
    }
    
    client = httpx.Client(timeout=10.0, verify=False)
    for i, k in enumerate(khatas):
        body_p = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <PlotsUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>15</dCode>
      <tCode>1</tCode>
      <vCode>61</vCode>
      <khata_no>{k}</khata_no>
    </PlotsUnicode>
  </soap:Body>
</soap:Envelope>"""
        try:
            r_p = client.post(url, data=body_p, headers=headers_p)
            soup_p = BeautifulSoup(r_p.text, "xml")
            plots = [p.text.strip() for p in soup_p.find_all("oplot_no")]
            if "647" in plots:
                print(f"\n============================================================")
                print(f"  FOUND Plot '647' in Khata '{k}'! Plots in Khata {k}: {plots}")
                print(f"============================================================")
                break
        except Exception:
            pass
        if (i + 1) % 50 == 0:
            print(f"Scanned {i + 1}/{len(khatas)} Khatas...")

if __name__ == "__main__":
    find_chakuli_647()
