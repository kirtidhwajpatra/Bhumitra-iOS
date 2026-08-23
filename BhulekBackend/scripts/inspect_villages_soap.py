#!/usr/bin/env python3
import httpx

SOAP_URL = "https://bhulekh.ori.nic.in/BhulekhService.asmx"

headers = {
    "Content-Type": "text/xml; charset=utf-8",
    "SOAPAction": "Microsoft.Samples.XmlMessaging.WebServices/VillagesUnicode"
}
body = """<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <VillagesUnicode xmlns="Microsoft.Samples.XmlMessaging.WebServices">
      <dCode>7</dCode>
      <tCode>4</tCode>
    </VillagesUnicode>
  </soap:Body>
</soap:Envelope>"""

r = httpx.post(SOAP_URL, data=body, headers=headers, verify=False)
print("Status:", r.status_code)
print("Response preview:", r.text[:500])
