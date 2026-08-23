#!/usr/bin/env python3
"""
Inspect exact input/output element schemas for PlotsUnicode, KhatiyanUnicode, etc.
"""
import xml.etree.ElementTree as ET

def inspect_elements():
    tree = ET.parse("/Users/uday/Documents/MyBhoomi/BhulekBackend/bhulekh_service_wsdl.xml")
    root = tree.getroot()
    
    ns = {
        "s": "http://www.w3.org/2001/XMLSchema"
    }
    
    for complex_type in root.findall(".//s:element", ns):
        name = complex_type.get("name")
        if name in ["PlotsUnicode", "PlotsUnicodeResponse", "KhatiyanUnicode", "KhatiyanUnicodeResponse", "VillagesUnicode", "VillagesUnicodeResponse"]:
            print(f"\n--- Element: {name} ---")
            for elem in complex_type.findall(".//s:element", ns):
                print(f"  Field: {elem.get('name')} (type: {elem.get('type')})")

if __name__ == "__main__":
    inspect_elements()
