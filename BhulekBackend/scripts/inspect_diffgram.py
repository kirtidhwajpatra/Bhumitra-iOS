#!/usr/bin/env python3
import httpx
from bs4 import BeautifulSoup

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
soup = BeautifulSoup(r.text, "xml")
diff = soup.find("diffgr:diffgram")
if diff:
    for child in diff.find_all(recursive=False):
        print("Child in diffgram:", child.name)
        for t in child.find_all(recursive=False)[:3]:
            print("  Item tag:", t.name)
            for f in t.find_all():
                print(f"    Field: {f.name} = {repr(f.text)}")
