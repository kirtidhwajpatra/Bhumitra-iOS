#!/usr/bin/env python3
"""
Find which Khata contains Plot 333 in Raghunathpur Jali (20, 2, 359).
"""
import httpx
from bs4 import BeautifulSoup

def find_plot_in_jali():
    url = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/KhatiyanUnicode"
    }
    body = """<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <KhatiyanUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>20</dCode>
      <tCode>2</tCode>
      <vCode>359</vCode>
    </KhatiyanUnicode>
  </soap:Body>
</soap:Envelope>"""

    print("Fetching all Khatas for Raghunathpur Jali (20, 2, 359)...")
    r = httpx.post(url, data=body, headers=headers, timeout=30.0, verify=False)
    soup = BeautifulSoup(r.text, "xml")
    khatas = [t.text.strip() for t in soup.find_all("okhata_no")]
    print(f"Total Khatas in Raghunathpur Jali: {len(khatas)}")
    
    # Check if Khata 333 exists or query plots in concurrent chunks
    headers_plot = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/PlotsUnicode"
    }
    
    # Let's test Khata 333 first if it exists
    if "333" in khatas:
        print("Khata '333' exists in village!")
        
    client = httpx.Client(timeout=10.0, verify=False)
    for i, k in enumerate(khatas):
        body_p = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <PlotsUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>20</dCode>
      <tCode>2</tCode>
      <vCode>359</vCode>
      <khata_no>{k}</khata_no>
    </PlotsUnicode>
  </soap:Body>
</soap:Envelope>"""
        try:
            r_p = client.post(url, data=body_p, headers=headers_plot)
            soup_p = BeautifulSoup(r_p.text, "xml")
            plots = [p.text.strip() for p in soup_p.find_all("oplot_no")]
            if "333" in plots:
                print(f"\n============================================================")
                print(f"  FOUND Plot '333' in Khata '{k}'! Plots in Khata {k}: {plots}")
                print(f"============================================================")
                break
        except Exception as e:
            pass
        if (i + 1) % 50 == 0:
            print(f"Scanned {i + 1}/{len(khatas)} Khatas...")

if __name__ == "__main__":
    find_plot_in_jali()
