#!/usr/bin/env python3
"""
Find Plot 647 in Chakuli (d=15, t=1, v=61) using ASMX KhatiyanUnicode and PlotsUnicode
"""
import httpx
from bs4 import BeautifulSoup

def find_plot_in_village(d_code, t_code, v_code, target_plot):
    url = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/KhatiyanUnicode"
    }
    body = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <KhatiyanUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{d_code}</dCode>
      <tCode>{t_code}</tCode>
      <vCode>{v_code}</vCode>
    </KhatiyanUnicode>
  </soap:Body>
</soap:Envelope>"""

    print(f"Fetching Khatiyans for village {v_code} (d={d_code}, t={t_code})...")
    r = httpx.post(url, data=body, headers=headers, timeout=20.0, verify=False)
    soup = BeautifulSoup(r.text, "xml")
    khatas = [t.text.strip() for t in soup.find_all("okhata_no")]
    print(f"Total Khatas in village: {len(khatas)}")
    
    # Check Plots in Khatas or query plot
    headers_plot = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/PlotsUnicode"
    }
    
    found = []
    for k in khatas:
        body_p = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <PlotsUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{d_code}</dCode>
      <tCode>{t_code}</tCode>
      <vCode>{v_code}</vCode>
      <khata_no>{k}</khata_no>
    </PlotsUnicode>
  </soap:Body>
</soap:Envelope>"""
        r_p = httpx.post(url, data=body_p, headers=headers_plot, timeout=10.0, verify=False)
        soup_p = BeautifulSoup(r_p.text, "xml")
        plots = [p.text.strip() for p in soup_p.find_all("oplot_no")]
        if target_plot in plots:
            print(f"  FOUND Plot '{target_plot}' in Khata '{k}'! All plots in Khata {k}: {plots}")
            found.append((k, plots))
            break
            
    if not found:
        print(f"Plot {target_plot} not found in first scanned Khatas.")

if __name__ == "__main__":
    find_plot_in_village(15, 1, 61, "647")
