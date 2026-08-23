#!/usr/bin/env python3
"""
Test SOAP requests to BhulekhService.asmx using exact SOAPAction namespace.
"""
import httpx
import xml.etree.ElementTree as ET

def test_soap():
    url = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/KhatiyanUnicode"
    }
    
    # Keonjhar: dCode=7, tCode=4, vCode=317
    body = """<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <KhatiyanUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>7</dCode>
      <tCode>4</tCode>
      <vCode>317</vCode>
    </KhatiyanUnicode>
  </soap:Body>
</soap:Envelope>"""

    print("Sending KhatiyanUnicode SOAP request for G_Dimbo (7, 4, 317)...")
    r = httpx.post(url, data=body, headers=headers, timeout=30.0, verify=False)
    print("Status:", r.status_code)
    print("Response text:\n", r.text[:2000])

if __name__ == "__main__":
    test_soap()
