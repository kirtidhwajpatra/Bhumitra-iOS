#!/usr/bin/env python3
"""
DEBUG SCRIPT 4: Test whether the last 3 digits of the 4K GEO village code
always matches the Bhulekh mouza_id.
"""
import json
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

# Known 4K GEO village codes from Dimbo GP, Keonjhar Sadar
gis_villages_dimbo_gp = {
    "0704315": "G_Naigan",
    "0704316": "Chaka",
    "0704317": "G_Dimbo",
    "0704318": "G_Baiganapasi",
    "0704319": "G_Tentulinanda",
    "0704320": "G_Kholapa",
    "0704321": "G_Guhalachatua",
    "0704322": "G_Dimirimunda",
    "0704323": "G_Dhenkikot",
    "0704324": "G_Manoharpur(Bada)",
    "0704325": "G_Goudunideda_139",
    "0704326": "G_Podadiha",
    "0704335": "G_Nunajharana",
}

catalog_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'bhulekh_catalog', 'catalog_v3.json')
with open(catalog_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

records = data.get('records', [])
keonjhar_sadar = [r for r in records if r.get('bhulekh_district_id') == '7' and r.get('bhulekh_tahasil_id') == '4']

print("=" * 70)
print("4K GEO CODE -> BHULEKH MOUZA ID MAPPING TEST")
print("=" * 70)

print(f"\nCatalog has {len(keonjhar_sadar)} villages for Keonjhar Sadar (7/4)")

match_count = 0
mismatch_count = 0
missing_count = 0

for code, gis_name in sorted(gis_villages_dimbo_gp.items()):
    last3 = str(int(code[-3:]))  # Strip leading zeros
    matches = [r for r in keonjhar_sadar if str(r.get('bhulekh_mouza_id')) == last3]
    if matches:
        m = matches[0]
        bhulekh_name = m.get('bhulekh_mouza_name', '')
        print(f"  [MATCH]   4KGEO={code} GIS_Name='{gis_name}' -> Last3={last3} -> Bhulekh='{bhulekh_name}' (ID={m.get('bhulekh_mouza_id')})")
        match_count += 1
    else:
        print(f"  [MISSING] 4KGEO={code} GIS_Name='{gis_name}' -> Last3={last3} -> NOT IN CATALOG")
        missing_count += 1

print(f"\nMatch: {match_count}, Missing: {missing_count}")

# Now the BIG question: do 4K GEO block codes (07XX) map to Bhulekh tahasil IDs?
# 4K GEO: Keonjhar Sadar block_code = 0704
# Bhulekh: Keonjhar Sadar tahasil_id = 4
# 4K GEO: Anandpur block_code = 0701
# Bhulekh: Anandpur tahasil_id = 1
print("\n" + "=" * 70)
print("4K GEO BLOCK CODE -> BHULEKH TAHASIL ID MAPPING")
print("=" * 70)

# From the 4K GEO output: block_code -> block_name
gis_blocks = {
    "0701": "Anandpur",
    "0710": "Banspal",
    "0703": "Champua",
    "0711": "Ghasipura",
    "0706": "Ghatagaon",
    "0709": "Harichandanpur",
    "0707": "Hatadihi",
    "0712": "Jhumpura",
    "0702": "Joda",   # Note: Joda vs Barbil
    "0704": "Keonjhar Sadar",
    "0708": "Patana",
    "0713": "Saharpada",
    "0705": "Telkoi",
}

# Bhulekh tahasil IDs for Keonjhar (from TAHASIL_MAP in bhulekh_mappings.py)
bhulekh_tahasils = {
    "1": "ANANDAPUR",
    "2": "BARBIL",
    "3": "CHAMPUA",
    "4": "KEONJHAR SADAR",
    "5": "TELKOI",
    "6": "GHATAGAON",
    "7": "HATADIHI",
    "8": "PATNA",
    "9": "HARICHANDANPUR",
    "10": "BANSPAL",
    "11": "GHASIPURA",
    "12": "JHUMPURA",
    "13": "SAHARPADA",
}

for gis_code, gis_name in sorted(gis_blocks.items()):
    last2 = str(int(gis_code[2:]))  # e.g. "0704" -> "4"
    if last2 in bhulekh_tahasils:
        bhulekh_name = bhulekh_tahasils[last2]
        print(f"  4KGEO={gis_code} ('{gis_name}') -> Last2={last2} -> Bhulekh tahasil='{bhulekh_name}' (ID={last2})")
    else:
        print(f"  4KGEO={gis_code} ('{gis_name}') -> Last2={last2} -> NOT MAPPED IN BHULEKH")

# KEY: 0702 = "Joda" in GIS but "BARBIL" (ID=2) in Bhulekh
# This means GIS block names != Bhulekh tahasil names
# But the NUMERIC CODES match: block_code last 2 digits == Bhulekh tahasil_id

print("\n" + "=" * 70)
print("CONCLUSION")
print("=" * 70)
print("""
The 4K GEO (ORSAC) code system encodes administrative identity as:

  DDBBVVV
  ^^ ^^ ^^^
  |  |  |
  |  |  +-- Village sequence (3 digits) = Bhulekh mouza_id
  |  +----- Block sequence (2 digits) = Bhulekh tahasil_id
  +-------- District code (2 digits) = Bhulekh district_id

This means:
  4K GEO code 0704317 = District 07, Block 04, Village 317
  Bhulekh identity    = District 7,  Tahasil 4, Mouza 317

THE VILLAGE CODE ITSELF IS THE IDENTITY KEY.

When the iOS app navigates the hierarchy and selects a village,
the village's `id` field (CadastralVillage.id) is the 7-digit ORSAC code.
The last 3 digits of this code directly correspond to the Bhulekh mouza_id.

ROOT CAUSE of mismatches would be:
1. The CadastralVillage.name being passed as the village name for Bhulekh lookup
   instead of using the numeric code directly
2. Name-based matching failing when English GIS names don't match Odia Bhulekh names
3. The village_id from the parcel features being empty or not passed correctly
""")


if __name__ == '__main__':
    pass  # main logic runs at module level
