#!/usr/bin/env python3
"""
Test PlotsUnicode on BhulekhService.asmx for G_Dimbo and Raghunathpur Jali.
"""
import httpx
import xml.etree.ElementTree as ET

def test_plots_unicode(d_code, t_code, v_code, khata_no):
    url = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/PlotsUnicode"
    }
    
    body = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <PlotsUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>{d_code}</dCode>
      <tCode>{t_code}</tCode>
      <vCode>{v_code}</vCode>
      <khata_no>{khata_no}</khata_no>
    </PlotsUnicode>
  </soap:Body>
</soap:Envelope>"""

    print(f"Sending PlotsUnicode SOAP request (d={d_code}, t={t_code}, v={v_code}, khata={khata_no})...")
    r = httpx.post(url, data=body, headers=headers, timeout=30.0, verify=False)
    print("Status:", r.status_code)
    print("Response text:\n", r.text[:2000])

if __name__ == "__main__":
    test_plots_unicode(7, 4, 317, "1")
    test_plots_unicode(7, 4, 317, "12")
    test_plots_unicode(7, 4, 317, "152")
