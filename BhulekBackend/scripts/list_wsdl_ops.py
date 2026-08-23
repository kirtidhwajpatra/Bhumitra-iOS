#!/usr/bin/env python3
"""
Parse bhulekh_service_wsdl.xml to list all methods and schemas.
"""
import xml.etree.ElementTree as ET

def parse_wsdl():
    tree = ET.parse("/Users/uday/Documents/MyBhoomi/BhulekBackend/bhulekh_service_wsdl.xml")
    root = tree.getroot()
    
    # Namespaces
    ns = {
        "wsdl": "http://schemas.xmlsoap.org/wsdl/",
        "s": "http://www.w3.org/2001/XMLSchema"
    }
    
    operations = []
    for elem in root.findall(".//wsdl:portType/wsdl:operation", ns):
        name = elem.get("name")
        operations.append(name)
        
    print("Available Operations in BhulekhService.asmx:")
    for op in sorted(operations):
        print(f"  - {op}")

if __name__ == "__main__":
    parse_wsdl()
