#!/usr/bin/env python3
from bs4 import BeautifulSoup
from scrapers.bhulekh_scraper import verify_ror_result
from resolvers.bhulekh_identity_resolver import (
    SCOPED_VILLAGE_ALIASES, BILINGUAL_VILLAGE_MAP, normalize, clean_gis_village_name,
    normalize_phonetic, odia_to_phonetic, consonant_skeleton
)
from scrapers.bhulekh_mappings import get_district_id, get_tahasil_id

req_dist = "Bargarh"
req_tah = "Atabira"
req_vill = "Chakuli_Mosaic"
req_plot = "647"

req_did = get_district_id(req_dist)
req_tid = get_tahasil_id(req_did, req_tah)
print(f"req_did={req_did}, req_tid={req_tid}")

clean_req_v = clean_gis_village_name(req_vill)
norm_req_v = normalize(clean_req_v)
print(f"clean_req_v={clean_req_v}, norm_req_v={norm_req_v}")

alias_target = SCOPED_VILLAGE_ALIASES.get((req_did, req_tid, normalize(req_vill)))
print(f"alias_target with norm(req_vill)={alias_target}")

alias_target_2 = SCOPED_VILLAGE_ALIASES.get((req_did, req_tid, norm_req_v))
print(f"alias_target with norm_req_v={alias_target_2}")

returned_vill = "ଚକୁଳି"
clean_ret_v = clean_gis_village_name(returned_vill)
norm_ret_v = normalize(clean_ret_v)
ret_bilingual_en = BILINGUAL_VILLAGE_MAP.get(returned_vill)
norm_ret_en = normalize(ret_bilingual_en) if ret_bilingual_en else ""

print(f"returned_vill={returned_vill}, norm_ret_v={norm_ret_v}, ret_bilingual_en={ret_bilingual_en}, norm_ret_en={norm_ret_en}")

print("Check conditions:")
print("1. norm_ret_v == norm_req_v:", norm_ret_v == norm_req_v)
print("2. norm_ret_en == normalize(alias_target):", norm_ret_en == normalize(alias_target or ""))
print("3. norm_ret_en == norm_req_v:", norm_ret_en == norm_req_v)
print("4. norm_ret_en == normalize(req_vill):", norm_ret_en == normalize(req_vill))
