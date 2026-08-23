#!/usr/bin/env python3
import httpx
from bs4 import BeautifulSoup

def inspect_wsdl():
    r = httpx.get("https://bhulekh.ori.nic.in/BhulekhService.asmx?WSDL", verify=False)
    soup = BeautifulSoup(r.text, "xml")
    operations = [op.get("name") for op in soup.find_all("wsdl:operation")]
    print("Available WSDL operations:", set(operations))

if __name__ == "__main__":
    inspect_wsdl()
