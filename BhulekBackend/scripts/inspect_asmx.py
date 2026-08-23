#!/usr/bin/env python3
"""
Inspect BhulekhService.asmx operations and schemas.
"""
import httpx
import xml.etree.ElementTree as ET

def check_asmx():
    url = "https://bhulekh.ori.nic.in/BhulekhService.asmx"
    print(f"Fetching {url}...")
    headers = {"User-Agent": "Mozilla/5.0"}
    try:
        r = httpx.get(url, headers=headers, timeout=20.0, verify=False)
        print("Status:", r.status_code)
        print(r.text[:2000])
        
        # Also fetch WSDL
        wsdl_url = "https://bhulekh.ori.nic.in/BhulekhService.asmx?WSDL"
        print(f"\nFetching WSDL: {wsdl_url}...")
        r_wsdl = httpx.get(wsdl_url, headers=headers, timeout=20.0, verify=False)
        print("WSDL Status:", r_wsdl.status_code)
        with open("/Users/uday/Documents/MyBhoomi/BhulekBackend/bhulekh_service_wsdl.xml", "w") as f:
            f.write(r_wsdl.text)
        print("Saved WSDL to bhulekh_service_wsdl.xml")
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    check_asmx()
