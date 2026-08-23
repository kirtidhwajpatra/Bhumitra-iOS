#!/usr/bin/env python3
from scrapers.bhulekh_mappings import get_district_id, get_tahasil_id, normalize

req_did = get_district_id("Bargarh")
ret_did = get_district_id("ବରଗଡ଼")
print(f"req_did={req_did}, ret_did={ret_did}")

req_tid = get_tahasil_id("15", "Atabira")
ret_tid = get_tahasil_id("15", "ଅତାବିରା")
print(f"req_tid={req_tid}, ret_tid={ret_tid}")
