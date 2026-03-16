"""
Bhulekh Odisha Static Mappings
Maps English names and GIS layer codes to Bhulekh dropdown numeric IDs.

GIS layer attributes available in the parcel data:
  d_id / d_namc = district code/name (Odia)
  b_id / b_namc = block/tahasil code/name (Odia)  
  v_id / v_namc = village code/name (Odia)
  revenue_plot  = plot number

Strategy: Use the GIS block ID (b_id) directly to look up Bhulekh tahasil dropdown values.
The GIS codes don't directly match Bhulekh IDs, so we maintain a mapping.
"""

# ── District Map: English name / alternate spellings → Bhulekh numeric ID ───────
DISTRICT_MAP = {
    "ANGUL": "14", "ANUGUL": "14",
    "CUTTACK": "3",
    "KANDHAMAL": "10", "PHULBANI": "10", "KANDHMAL": "10",
    "KALAHANDI": "6",
    "KEONJHAR": "7", "KENDUJHAR": "7", "KENJHAR": "7", "KEUNJHAR": "7",
    "KENDRAPARA": "19", "KENDRAPAR": "19",
    "KORAPUT": "8",
    "KHORDHA": "20", "KHURDA": "20", "BHUBANESWAR": "20",
    "GANJAM": "5",
    "GAJAPATI": "24",
    "JAGATSINGHPUR": "17", "JAGATSINGHPUR": "17",
    "JHARSUGUDA": "30",
    "DHENKANAL": "4",
    "DEOGARH": "29", "DEBAGARH": "29",
    "NUAPADA": "21",
    "NABARANGPUR": "26", "NABARANGAPUR": "26",
    "NAYAGARH": "22",
    "PURI": "11",
    "BARGARH": "15", "BARAGARH": "15",
    "BOLANGIR": "2", "BALANGIR": "2",
    "BALASORE": "1", "BALESHWAR": "1", "BALESWAR": "1",
    "BOUDH": "28", "BAUDH": "28",
    "BHADRAK": "16",
    "MAYURBHANJ": "9", "MAYURBHANJA": "9",
    "MALKANGIRI": "25", "MALKANAGIRI": "25",
    "JAJPUR": "18",
    "RAYAGADA": "27", "RAYAGAD": "27",
    "SUNDARGARH": "13", "SUNDERGARH": "13", "SUNDERGARH": "13",
    "SUBARNAPUR": "23", "SONEPUR": "23", "SUBARNAPUR": "23",
    "SAMBALPUR": "12",
}

# ── Tahasil Map: (district_bhulekh_id, tahasil_english) → tahasil bhulekh ID ────
# Exhaustive mapping for all districts x tahasils
# Format: (district_id_str, tahasil_name_upper) → tahasil_id_str
TAHASIL_MAP = {
    # KEONJHAR (district 7)
    ("7", "ANANDAPUR"): "1",   ("7", "ANANDPUR"): "1",
    ("7", "GHATAGAON"): "6",   ("7", "GHATAGANG"): "6",
    ("7", "GHASIPURA"): "11",
    ("7", "CHAMPUA"): "3",     ("7", "CHAMPA"): "3",
    ("7", "JHUMPURA"): "12",
    ("7", "TELKOI"): "5",
    ("7", "PATNA"): "8",
    ("7", "BARBIL"): "2",      ("7", "BADBIL"): "2",
    ("7", "BANSPAL"): "10",    ("7", "BAMSHPAL"): "10",
    ("7", "SADAR"): "4",       ("7", "KEONJHAR SADAR"): "4",  ("7", "KENDUJHAR SADAR"): "4",
    ("7", "SAHARPADA"): "13",
    ("7", "HARICHANDANPUR"): "9",
    ("7", "HATADIHI"): "7",    ("7", "HATADIH"): "7",

    # CUTTACK (district 3)
    ("3", "ATHAGARH"): "1",
    ("3", "BANKI"): "2",
    ("3", "BADAMBA"): "3",
    ("3", "CUTTACK SADAR"): "4",  ("3", "CUTTACK"): "4",
    ("3", "NARASINGHPUR"): "5",
    ("3", "NIALI"): "6",
    ("3", "SALIPUR"): "7", ("3", "SALEPU"): "7",
    ("3", "TIGIRIA"): "8",
    ("3", "TANGICHAUDWAR"): "9", ("3", "TANGICHDWR"): "9", ("3", "TANGI CHOUDWAR"): "9",
    ("3", "KISHANNAGAR"): "10",
    ("3", "MAHANGA"): "11",
    ("3", "BARANG"): "12",
    ("3", "DAMPADA"): "13", ("3", "DOMPADA"): "13",
    ("3", "KANTAPADA"): "14",
    ("3", "NISCHINTAKOILI"): "15",

    # ANGUL (district 14)  
    ("14", "ANGUL"): "1",
    ("14", "ATHAMALIK"): "2",
    ("14", "BANARPAL"): "3",
    ("14", "CHHENDIPADA"): "4",
    ("14", "KANIHA"): "5",
    ("14", "KISHORENAGAR"): "6",
    ("14", "PALLAHARA"): "7",
    ("14", "RENGALI"): "8",
    ("14", "TALCHER"): "9",

    # BALASORE (district 1)
    ("1", "BALASORE"): "1",    ("1", "BALESHWAR"): "1",  ("1", "BALESWAR"): "1",
    ("1", "BALASOREMUNICIPAL"): "2",
    ("1", "BHOGRAI"): "3",
    ("1", "BHOGARAI"): "3",
    ("1", "JALESWAR"): "4",
    ("1", "NILGIRI"): "5",
    ("1", "OUPADA"): "6",
    ("1", "REMUNA"): "7",
    ("1", "SADAR"): "8",       ("1", "BALASORE SADAR"): "8",
    ("1", "SIMULIA"): "9",
    ("1", "SORO"): "10",

    # KHORDHA (district 20)
    ("20", "BEGUNIA"): "1",
    ("20", "BHUBANESWAR"): "2",
    ("20", "BOLAGARH"): "3",
    ("20", "CHILIKA"): "4",
    ("20", "JATNI"): "5",
    ("20", "KHORDHA"): "6",    ("20", "KHURDA"): "6",
    ("20", "KHANDAPADA"): "7",
    ("20", "TANGI"): "8",

    # PURI (district 11)
    ("11", "ASTARANGA"): "1",
    ("11", "BRAHMAGIRI"): "2",
    ("11", "DELANGA"): "3",
    ("11", "GOP"): "4",
    ("11", "KAKATPUR"): "5",
    ("11", "KANAS"): "6",
    ("11", "NIMAPADA"): "7",
    ("11", "PIPILI"): "8",
    ("11", "PURI"): "9",       ("11", "SADAR"): "9",
    ("11", "SATYABADI"): "10",

    # SAMBALPUR (district 12)
    ("12", "BAMRA"): "1",
    ("12", "JUJUMURA"): "2",
    ("12", "KUCHINDA"): "3",
    ("12", "NAKTIDEUL"): "4",
    ("12", "RAIRAKHOL"): "5",
    ("12", "RENGALI"): "6",
    ("12", "SADAR"): "7",      ("12", "SAMBALPUR SADAR"): "7",

    # SUNDARGARH (district 13)
    ("13", "BARGAON"): "1",
    ("13", "BISRA"): "2",
    ("13", "BONAIGARH"): "3",
    ("13", "GURUNDIA"): "4",
    ("13", "HEMGIR"): "5",
    ("13", "KOIRA"): "6",
    ("13", "KUARMUNDA"): "7",   ("13", "KUANRMUNDA"): "7",
    ("13", "LAHUNIPADA"): "8",
    ("13", "LEPHRIPARA"): "9",
    ("13", "RAJGANGPUR"): "10",
    ("13", "SADAR"): "11",     ("13", "SUNDARGARH SADAR"): "11",
    ("13", "SUBDEGA"): "12",
    ("13", "TANGARPALI"): "13",

    # GANJAM (district 5)
    ("5", "ASKA"): "1",
    ("5", "BHANJANAGAR"): "2",
    ("5", "BERHAMPUR"): "3",
    ("5", "CHHATRAPUR"): "4",
    ("5", "DIGAPAHANDI"): "5",
    ("5", "GANJAM"): "6",
    ("5", "HINJILICUT"): "7",
    ("5", "KABISURYANAGAR"): "8",
    ("5", "KHALLIKOTE"): "9",
    ("5", "KODALA"): "10",
    ("5", "PATRAPUR"): "11",
    ("5", "POLASARA"): "12",
    ("5", "PURUSOTTAMPUR"): "13",
    ("5", "SANAKHEMUNDI"): "14",
    ("5", "SORADA"): "15",
    ("5", "SURADA"): "15",

    # MAYURBHANJ (district 9)
    ("9", "BAHALDA"): "1",
    ("9", "BARIPADA"): "2",
    ("9", "BARIPADA SADAR"): "2",  ("9", "SADAR"): "2",
    ("9", "BARSAHI"): "3",
    ("9", "BISOI"): "4",
    ("9", "JASHIPUR"): "5",
    ("9", "KHUNTA"): "6",
    ("9", "RAIRANGPUR"): "7",
    ("9", "SARASKANA"): "8",
    ("9", "SHAMAKHUNTA"): "9",
    ("9", "TIRING"): "10",
    ("9", "UDALA"): "11",

    # JAJPUR (district 18)
    ("18", "BARI"): "1",
    ("18", "BINJHARPUR"): "2",
    ("18", "DANAGADI"): "3",
    ("18", "DHARMASALA"): "4",
    ("18", "JAJPUR"): "5",
    ("18", "JAJPUR SADAR"): "5",   ("18", "SADAR"): "5",
    ("18", "KOREI"): "6",
    ("18", "SUKINDA"): "7",
    ("18", "RASULPUR"): "8",

    # DHENKANAL (district 4)
    ("4", "BHUBAN"): "1",
    ("4", "DHENKANAL"): "2",  ("4", "SADAR"): "2",
    ("4", "GANDIA"): "3",
    ("4", "HINDOL"): "4",
    ("4", "KAMAKHYANAGAR"): "5",
    ("4", "ODAPADA"): "6",
    ("4", "PARJANG"): "7",
}

# ── Village Map: (district_id, tahasil_id, roman_name) → bhulekh_village_id ──
VILLAGE_MAP = {
    # Cuttack (3), Cuttack Sadar (4) - Major City Units
    ("3", "4", "RANIHAT"): "199",
    ("3", "4", "BUXI BAZAR"): "196",
    ("3", "4", "BAXI BAZAR"): "196",
    ("3", "4", "MANGALABAG"): "198",
    ("3", "4", "MANGALABAGH"): "198",
    ("3", "4", "BADAMBADI"): "211",
    ("3", "4", "CHAULIAGANJ"): "205",
    ("3", "4", "DOLAMUNDAI"): "210",
    ("3", "4", "SUTAHAT"): "217",
    ("3", "4", "JOBRA"): "201",
    ("3", "4", "UN25 JOBRA"): "201",
    ("3", "4", "NAYASADAK"): "215",
    ("3", "4", "CANTONMENT"): "216",
    ("3", "4", "CHANDINI CHOUK"): "194",
    ("3", "4", "CHANDINICHOUK"): "194",
    ("3", "4", "SHIKHARPUR"): "202",
    ("3", "4", "GANDARPUR"): "203",
    ("3", "4", "ODIYA BAZAR"): "193",
    ("3", "4", "ODIABAZAR"): "193",
    ("3", "4", "MADHUPATNA"): "208",
    ("3", "4", "UN32 MADHUPATNA"): "208",
    ("3", "4", "BIDANASI"): "173",
    ("3", "4", "TULASIPUR"): "177",
    ("3", "4", "TULSIPUR"): "177",
    ("3", "4", "MAHANADI"): "174",
    ("3", "4", "JHANJIRI MANGALA"): "184",
    ("3", "4", "CHOUDHRY BAZAR"): "195",
    ("3", "4", "CHOUDHURY BAZAR"): "195",
    ("3", "4", "KATHAGADASHI"): "180",
    ("3", "4", "MACHHUABAZAR"): "218",
    ("3", "4", "COLLEGE CHHAK"): "200",
    ("3", "4", "COLLEGECHHAK"): "200",

    # Cuttack (3), Tangi Choudwar (9)
    ("3", "9", "JENIPUNURSINGHPUR"): "139",

    # Keonjhar (7), Sadar (4)
    ("7", "4", "G KERI"): "330",
    ("7", "4", "KERI"): "330",
    ("7", "4", "GHUTU KESARI"): "39",
    ("7", "4", "GHUTURU"): "55",
    ("7", "4", "KEONJHARNIJIGARH"): "137", # Keonjhar Town
    ("7", "4", "KENDUJHARNIJIGARH"): "137",
    ("7", "4", "KEONJHAR TOWN"): "137",
    
    # Keonjhar (7), Patana (8)
    ("7", "8", "DABARCHUAN"): "385", # Fuzzy-match priority
    ("7", "8", "DABARCHUA"): "385", 
}

# ── GIS b_id → Bhulekh tahasil ID (from actual data observation) ─────────────
# The GIS layer's b_id doesn't directly map to Bhulekh's tahasil ID
# This map comes from cross-referencing GIS data with Bhulekh portal
GIS_BLOCK_TO_TAHASIL = {
    "0704": "4",   # Keonjhar Sadar (GIS block 0704 = Keonjhar Sadar)
    "0701": "1",   # Anandapur
    "0706": "6",   # Ghatagaon
    "0703": "3",   # Champua
    "0705": "5",   # Telkoi
    "0708": "8",   # Patna
    "0702": "2",   # Barbil
}

def normalize(s: str) -> str:
    if not s: return ""
    import re
    s = s.strip().upper()
    
    # 1. Strip common GIS technical suffixes/prefixes
    # Examples: Kimiribolidhangadpara_Mosaic -> Kimiribolidhangadpara
    # G_Keri_271 -> Keri, Un25_Jobra -> Jobra
    s = re.sub(r'^[A-Z]{1,2}\d*_', '', s)
    s = re.sub(r'_(MOSAIC|WGS84|UTM|LAYER|BOUNDARY|POLYGON)$', '', s, flags=re.IGNORECASE)
    
    # 2. Strip numeric suffixes (e.g., Keri_271 -> Keri, Jenipunursinghpur-37 -> Jenipunursinghpur)
    s = re.sub(r'[_\-]\s*\d+.*$', '', s)
    
    # 3. Strip extra spaces and normalize internal spaces
    
    # 4. General cleanup
    s = s.replace("-", " ").replace(".", "").replace("_", " ").strip()
    
    # 5. Remove redundant spaces
    s = re.sub(r'\s+', ' ', s)
    
    # 6. Custom aliases and common transliteration fixes
    if "KEONJHARNIJIG" in s: return "KEONJHARNIJIGARH"
    if "DABARCHUAN" in s: return "DABARCHUA"
    if "KIMIRIBOLIDHANGADPARA" in s: return "KIMIRIBOLIDHANGADPARA" # Ensure base name is clean
    
    return s.strip()


def get_village_id(district_id: str, tahasil_id: str, village_name: str) -> str | None:
    v = normalize(village_name)
    return VILLAGE_MAP.get((district_id, tahasil_id, v))


def get_district_id(district: str) -> str | None:
    d = normalize(district)
    if d in DISTRICT_MAP:
        return DISTRICT_MAP[d]
    # Partial match
    for key, val in DISTRICT_MAP.items():
        if d in key or key in d:
            return val
    return None


def get_tahasil_id(district_id: str, tahasil: str) -> str | None:
    t = normalize(tahasil)
    
    # Direct lookup
    key = (district_id, t)
    if key in TAHASIL_MAP:
        return TAHASIL_MAP[key]
    
    # "SADAR" alone maps to the district's main tahasil
    if t == "SADAR":
        return TAHASIL_MAP.get((district_id, "SADAR"))
    
    # Partial match within same district
    for (did, tname), tid in TAHASIL_MAP.items():
        if did != district_id:
            continue
        if t in tname or tname in t:
            return tid
    
    # Word overlap
    t_words = set(t.split())
    for (did, tname), tid in TAHASIL_MAP.items():
        if did != district_id:
            continue
        tname_words = set(tname.split())
        if t_words & tname_words:
            return tid
    
    return None


def get_tahasil_id_from_gis_block(b_id: str) -> str | None:
    """Look up Bhulekh tahasil ID from a GIS block ID (b_id field)."""
    return GIS_BLOCK_TO_TAHASIL.get(b_id.strip().upper())
