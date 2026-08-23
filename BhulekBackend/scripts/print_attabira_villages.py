#!/usr/bin/env python3
"""
Print all villages in District 15 (Bargarh), Tahasil 1 (Attabira)
"""
from parse_villages_diffgram import get_villages

v_atabira = get_villages(15, 1)
print(f"Total villages in Attabira: {len(v_atabira)}")
for v in v_atabira:
    print(f"  Code: {v.get('code')} -> Name: {v.get('oname')}")
