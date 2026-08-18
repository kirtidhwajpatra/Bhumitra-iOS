"""
Bhulekh Odisha Static Mappings & Location Hierarchy Engine
Maps English names and GIS layer codes to Bhulekh dropdown numeric IDs deterministically.
"""
from typing import List, Dict, Optional, Tuple
from models.ror_response import (
    BhulekhDistrict,
    BhulekhTahasil,
    BhulekhVillage,
    BhulekhRICircle,
)

# ── District Map: English name / alternate spellings → Bhulekh numeric ID ───────
DISTRICT_MAP: Dict[str, str] = {
    "ANGUL": "14", "ANUGUL": "14", "ଅନୁଗୋଳ": "14",
    "BALASORE": "1", "BALESHWAR": "1", "BALESWAR": "1", "ବାଲେଶ୍ୱର": "1",
    "BARGARH": "15", "BARAGARH": "15", "ବରଗଡ଼": "15",
    "BHADRAK": "16", "ଭଦ୍ରକ": "16",
    "BOLANGIR": "2", "BALANGIR": "2", "ବଲାଙ୍ଗୀର": "2",
    "BOUDH": "28", "BAUDH": "28", "ବୌଦ୍ଧ": "28",
    "CUTTACK": "3", "କଟକ": "3",
    "DEOGARH": "29", "DEBAGARH": "29", "ଦେବଗଡ଼": "29",
    "DHENKANAL": "4", "ଢେଙ୍କାନାଳ": "4",
    "GAJAPATI": "24", "ଗଜପତି": "24",
    "GANJAM": "5", "ଗଞ୍ଜାମ": "5", "ଗଂଜାମ": "5",
    "JAGATSINGHPUR": "17", "ଜଗତସିଂହପୁର": "17",
    "JAJPUR": "18", "ଯାଜପୁର": "18",
    "JHARSUGUDA": "30", "ଝାରସୁଗୁଡ଼ା": "30",
    "KALAHANDI": "6", "କଳାହାଣ୍ଡି": "6",
    "KANDHAMAL": "10", "PHULBANI": "10", "KANDHMAL": "10", "କନ୍ଧମାଳ": "10",
    "KENDRAPARA": "19", "KENDRAPAR": "19", "କେନ୍ଦ୍ରାପଡ଼ା": "19", "କେନ୍ଦ୍ରାପଡ଼ା": "19",
    "KEONJHAR": "7", "KENDUJHAR": "7", "KENJHAR": "7", "KEUNJHAR": "7", "କେନ୍ଦୁଝର": "7",
    "KHORDHA": "20", "KHURDA": "20", "BHUBANESWAR": "20", "ଖୋର୍ଦ୍ଧା": "20",
    "KORAPUT": "8", "କୋରାପୁଟ": "8",
    "MALKANGIRI": "25", "MALKANAGIRI": "25", "ମାଲକାନଗିରି": "25",
    "MAYURBHANJ": "9", "MAYURBHANJA": "9", "ମୟୂରଭଞ୍ଜ": "9",
    "NABARANGPUR": "26", "NABARANGAPUR": "26", "ନବରଙ୍ଗପୁର": "26",
    "NAYAGARH": "22", "ନୟାଗଡ଼": "22",
    "NUAPADA": "21", "ନୂଆପଡ଼ା": "21",
    "PURI": "11", "ପୁରୀ": "11",
    "RAYAGADA": "27", "RAYAGAD": "27", "ରାୟଗଡ଼ା": "27",
    "SAMBALPUR": "12", "ସମ୍ବଲପୁର": "12",
    "SUBARNAPUR": "23", "SONEPUR": "23", "ସୁବର୍ଣ୍ଣପୁର": "23", "ସୋନପୁର": "23",
    "SUNDARGARH": "13", "SUNDERGARH": "13", "ସୁନ୍ଦରଗଡ଼": "13",
}

# Canonical primary district names for display
OFFICIAL_DISTRICT_NAMES: Dict[str, str] = {
    "1": "BALASORE",
    "2": "BOLANGIR",
    "3": "CUTTACK",
    "4": "DHENKANAL",
    "5": "GANJAM",
    "6": "KALAHANDI",
    "7": "KEONJHAR",
    "8": "KORAPUT",
    "9": "MAYURBHANJ",
    "10": "KANDHAMAL",
    "11": "PURI",
    "12": "SAMBALPUR",
    "13": "SUNDARGARH",
    "14": "ANGUL",
    "15": "BARGARH",
    "16": "BHADRAK",
    "17": "JAGATSINGHPUR",
    "18": "JAJPUR",
    "19": "KENDRAPARA",
    "20": "KHORDHA",
    "21": "NUAPADA",
    "22": "NAYAGARH",
    "23": "SUBARNAPUR",
    "24": "GAJAPATI",
    "25": "MALKANGIRI",
    "26": "NABARANGPUR",
    "27": "RAYAGADA",
    "28": "BOUDH",
    "29": "DEOGARH",
    "30": "JHARSUGUDA",
}

# ── Tahasil Map: (district_bhulekh_id, tahasil_english) → tahasil bhulekh ID ────
TAHASIL_MAP: Dict[Tuple[str, str], str] = {
    # KEONJHAR (district 7)
    ("7", "ANANDAPUR"): "1",   ("7", "ANANDPUR"): "1",   ("7", "ଆନନ୍ଦପୁର"): "1",
    ("7", "BARBIL"): "2",      ("7", "BADBIL"): "2",      ("7", "ବଡବିଲ"): "2",
    ("7", "CHAMPUA"): "3",     ("7", "CHAMPA"): "3",      ("7", "ଚମ୍ପୁଆ"): "3",
    ("7", "KEONJHAR SADAR"): "4",  ("7", "KENDUJHAR SADAR"): "4",  ("7", "SADAR"): "4",  ("7", "ସଦର"): "4",
    ("7", "TELKOI"): "5",      ("7", "ତେଲକୋଇ"): "5",
    ("7", "GHATAGAON"): "6",   ("7", "GHATAGANG"): "6",   ("7", "ଘଟଗାଁ"): "6",
    ("7", "HATADIHI"): "7",    ("7", "HATADIH"): "7",    ("7", "ହାଟଡ଼ିହି"): "7",
    ("7", "PATNA"): "8",       ("7", "ପାଟଣା"): "8",
    ("7", "HARICHANDANPUR"): "9", ("7", "ହରିଚନ୍ଦନପୁର"): "9",
    ("7", "BANSPAL"): "10",    ("7", "BAMSHPAL"): "10",  ("7", "ବାଂଶପାଳ"): "10",
    ("7", "GHASIPURA"): "11",  ("7", "ଘସିପୁରା"): "11",
    ("7", "JHUMPURA"): "12",   ("7", "ଝୁମ୍ପୁରା"): "12",
    ("7", "SAHARPADA"): "13",  ("7", "ସାହାରପଡା"): "13",

    # CUTTACK (district 3)
    ("3", "ATHAGARH"): "1",
    ("3", "ଆଠଗଡ"): "1",
    ("3", "ଆଠଗଡ଼"): "1",
    ("3", "BARAMBA"): "2",
    ("3", "ବଡ଼ମ୍ବା"): "2",
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
    ("1", "BHOGRAI"): "3",     ("1", "BHOGARAI"): "3",
    ("1", "JALESWAR"): "4",    ("1", "JALESWAR"): "4",
    ("1", "BASTA"): "5",
    ("1", "BALIAPAL"): "6",
    ("1", "REMUNA"): "7",
    ("1", "NILGIRI"): "8",
    ("1", "SORO"): "9",
    ("1", "SIMULIA"): "10",
    ("1", "BAHANAGA"): "11",
    ("1", "OUUPADA"): "12",    ("1", "OUPADA"): "12",

    # BARGARH (district 15)
    ("15", "BARGARH"): "1",
    ("15", "BARPALI"): "2",
    ("15", "ATTABIRA"): "3",
    ("15", "BHEDEN"): "4",
    ("15", "SOHELLA"): "5",
    ("15", "BIJEPUR"): "6",
    ("15", "PADAMPUR"): "7",
    ("15", "GAISILET"): "8",
    ("15", "PAIKMAL"): "9",
    ("15", "JHARBANDH"): "10",
    ("15", "AMBABHONA"): "11",
    ("15", "BHATLI"): "12",

    # BHADRAK (district 16)
    ("16", "BHADRAK"): "1",    ("16", "BHADRAK SADAR"): "1",
    ("16", "BASUDEVPUR"): "2",
    ("16", "BONTH"): "3",
    ("16", "CHANDABALI"): "4",
    ("16", "DHAMNAGAR"): "5",
    ("16", "TIHIDI"): "6",
    ("16", "BHANDARIPOKHARI"): "7",

    # BOLANGIR (district 2)
    ("2", "BOLANGIR"): "1",    ("2", "BALANGIR"): "1",
    ("2", "PATNAGARH"): "2",
    ("2", "TITILAGARH"): "3",
    ("2", "TUSURA"): "4",
    ("2", "LOISINGHA"): "5",
    ("2", "PUINTALA"): "6",
    ("2", "DEOGAON"): "7",
    ("2", "BELPARA"): "8",
    ("2", "KHAPRAKHOL"): "9",
    ("2", "MURIBAHAL"): "10",
    ("2", "BANGOMUNDA"): "11",
    ("2", "TUREKELA"): "12",
    ("2", "GUDVELLA"): "13",
    ("2", "AGALPUR"): "14",

    # BOUDH (district 28)
    ("28", "BOUDH"): "1",      ("28", "BAUDH"): "1",
    ("28", "HARABHANGA"): "2",
    ("28", "KANTAMAL"): "3",

    # DEOGARH (district 29)
    ("29", "DEOGARH"): "1",    ("29", "DEBAGARH"): "1",
    ("29", "BARKOTE"): "2",
    ("29", "REAMAL"): "3",

    # DHENKANAL (district 4)
    ("4", "DHENKANAL"): "1",   ("4", "DHENKANAL SADAR"): "1",
    ("4", "BHUBAN"): "2",
    ("4", "GONDIA"): "3",
    ("4", "HINDOL"): "4",
    ("4", "KAMAKHYANAGAR"): "5",
    ("4", "KANKADAHAD"): "6",
    ("4", "ODAPADA"): "7",
    ("4", "PARJANG"): "8",

    # GAJAPATI (district 24)
    ("24", "PARALAKHEMUNDI"): "1",
    ("24", "KASHINAGARA"): "2",
    ("24", "GOSANI"): "3",
    ("24", "GUMMA"): "4",
    ("24", "MOHANA"): "5",
    ("24", "NUAGADA"): "6",
    ("24", "R UDAYAGIRI"): "7",

    # GANJAM (district 5)
    ("5", "BERHAMPUR"): "1",   ("5", "BRAHMAPUR"): "1",   ("5", "ବ୍ରହ୍ମପୁର"): "1",
    ("5", "CHATRAPUR"): "2",   ("5", "ଛତ୍ରପୁର"): "2",
    ("5", "BHANJANAGAR"): "3",
    ("5", "ASKA"): "4",        ("5", "ଆସିକା"): "4",       ("5", "ଆସ୍କା"): "4",
    ("5", "BELLAGUNTHA"): "5",
    ("5", "BUGUDA"): "6",
    ("5", "CHIKITI"): "7",
    ("5", "DIGAPAHANDI"): "8",
    ("5", "GANJAM"): "9",
    ("5", "HINJILICUT"): "10",
    ("5", "JAGANNATHPRASAD"): "11",
    ("5", "KABISURYANAGAR"): "12",
    ("5", "KHALIKOTE"): "13",
    ("5", "KODALA"): "14",
    ("5", "KUKUDAKHANDI"): "15",
    ("5", "PATRAPUR"): "16",
    ("5", "POLASARA"): "17",
    ("5", "PURUSHOTTAMPUR"): "18",
    ("5", "SANAKHEMUNDI"): "19",
    ("5", "SURADA"): "20",
    ("5", "RANGEILUNDA"): "21",
    ("5", "DHARAKOTE"): "22",

    # JAGATSINGHPUR (district 17)
    ("17", "JAGATSINGHPUR"): "1",
    ("17", "BALIKUDA"): "2",
    ("17", "BIRIDI"): "3",
    ("17", "ERASAMA"): "4",
    ("17", "KUJANG"): "5",
    ("17", "NAUGAON"): "6",
    ("17", "RAGHUNATHPUR"): "7",
    ("17", "TIRTOL"): "8",

    # JAJPUR (district 18)
    ("18", "JAJPUR"): "1",     ("18", "JAJPUR SADAR"): "1",
    ("18", "BINJHARPUR"): "2",
    ("18", "BARI"): "3",
    ("18", "BARCHANA"): "4",
    ("18", "DANAGADI"): "5",
    ("18", "DHARAMSALA"): "6",
    ("18", "KORAI"): "7",
    ("18", "RASULPUR"): "8",
    ("18", "SUKINDA"): "9",
    ("18", "VYASANAGAR"): "10",

    # JHARSUGUDA (district 30)
    ("30", "JHARSUGUDA"): "1",
    ("30", "KIRAMIRA"): "2",
    ("30", "KOLABIRA"): "3",
    ("30", "LAKHANPUR"): "4",
    ("30", "LAIKERA"): "5",

    # KALAHANDI (district 6)
    ("6", "BHAWANIPATNA"): "1",
    ("6", "DHARAMGARH"): "2",
    ("6", "JUNAGARH"): "3",
    ("6", "JAIPATNA"): "4",
    ("6", "KESINGA"): "5",
    ("6", "KOKSARA"): "6",
    ("6", "LANJIGARH"): "7",
    ("6", "M RAMPUR"): "8",
    ("6", "NARLA"): "9",
    ("6", "GOLAMUNDA"): "10",
    ("6", "KALAMPUR"): "11",
    ("6", "THUAMUL RAMPUR"): "12",
    ("6", "KARLAMUNDA"): "13",

    # KANDHAMAL (district 10)
    ("10", "PHULBANI"): "1",
    ("10", "BALLIGUDA"): "2",
    ("10", "CHAKAPAD"): "3",
    ("10", "DARINGBADI"): "4",
    ("10", "G UDAYAGIRI"): "5",
    ("10", "KHAJURIPADA"): "6",
    ("10", "KOTAGARH"): "7",
    ("10", "K NUAGAON"): "8",
    ("10", "PHIRINGIA"): "9",
    ("10", "RAIKIA"): "10",
    ("10", "TIKABALI"): "11",
    ("10", "TUMUDIBANDHA"): "12",

    # KENDRAPARA (district 19)
    ("19", "KENDRAPARA"): "1",
    ("19", "AUL"): "2",
    ("19", "DERABISH"): "3",
    ("19", "GARADAPUR"): "4",
    ("19", "MAHAKALAPADA"): "5",
    ("19", "MARSHAGHAI"): "6",
    ("19", "PATTAMUNDAI"): "7",
    ("19", "RAJNAGAR"): "8",
    ("19", "RAJKANIKA"): "9",

    # KHORDHA (district 20)
    ("20", "BHUBANESWAR"): "1",
    ("20", "KHORDHA"): "2",    ("20", "KHURDA"): "2",
    ("20", "BALIPATNA"): "3",
    ("20", "BALIANTA"): "4",
    ("20", "BANAPUR"): "5",
    ("20", "BEGUNIA"): "6",
    ("20", "BOLOAGARH"): "7",  ("20", "BOLAGARH"): "7",
    ("20", "CHILIKA"): "8",
    ("20", "JATNI"): "9",
    ("20", "TANGI"): "10",

    # KORAPUT (district 8)
    ("8", "KORAPUT"): "1",
    ("8", "JEYPORE"): "2",
    ("8", "BORIGUMMA"): "3",
    ("8", "KOTPAD"): "4",
    ("8", "MACHHKUND"): "5",
    ("8", "LAMTAPUT"): "6",
    ("8", "POTTANGI"): "7",
    ("8", "SEMPILIGUDA"): "8",  ("8", "SIMILIGUDA"): "8",
    ("8", "NANDAPUR"): "9",
    ("8", "DASAMANTHAPUR"): "10",
    ("8", "BANDHUGAN"): "11",
    ("8", "NARAYANPATNA"): "12",
    ("8", "KUNDRA"): "13",
    ("8", "BOIPARIGUDA"): "14",

    # MALKANGIRI (district 25)
    ("25", "MALKANGIRI"): "1",
    ("25", "CHITRAKONDA"): "2",
    ("25", "KALIMELA"): "3",
    ("25", "KHAIRPUT"): "4",
    ("25", "KORUKONDA"): "5",
    ("25", "MATHILI"): "6",
    ("25", "MOTU"): "7",

    # MAYURBHANJ (district 9)
    ("9", "BARIPADA"): "1",
    ("9", "BAHALDA"): "2",
    ("9", "BANGIRIPOSI"): "3",
    ("9", "BETNOTI"): "4",
    ("9", "BIJATALA"): "5",
    ("9", "BISHOI"): "6",
    ("9", "GOPABANDHUNAGAR"): "7",
    ("9", "JAMDA"): "8",
    ("9", "JASHIPUR"): "9",
    ("9", "KAPTIPADA"): "10",
    ("9", "KARANJIA"): "11",
    ("9", "KHUNTA"): "12",
    ("9", "KULIANA"): "13",
    ("9", "KUSUMI"): "14",
    ("9", "MORADA"): "15",
    ("9", "RAIRANGPUR"): "16",
    ("9", "RARUAN"): "17",
    ("9", "RASGOVINDPUR"): "18",
    ("9", "SAMAKHUNTA"): "19",
    ("9", "SARASKANA"): "20",
    ("9", "SUKRULI"): "21",
    ("9", "SULIAPADA"): "22",
    ("9", "THAKURMUNDA"): "23",
    ("9", "TIRING"): "24",
    ("9", "UDALA"): "25",
    ("9", "BARASAHI"): "26",

    # NABARANGPUR (district 26)
    ("26", "NABARANGPUR"): "1",
    ("26", "CHANDAHANDI"): "2",
    ("26", "DABUGAM"): "3",
    ("26", "JHARIGAM"): "4",
    ("26", "KOSAGUMUDA"): "5",
    ("26", "NANDAHANDI"): "6",
    ("26", "PAPADAHANDI"): "7",
    ("26", "RAIGHAR"): "8",
    ("26", "TENTULIKHUNTI"): "9",
    ("26", "UMERKOTE"): "10",

    # NAYAGARH (district 22)
    ("22", "NAYAGARH"): "1",
    ("22", "BHAPUR"): "2",
    ("22", "DASPALLA"): "3",
    ("22", "FATEGARH"): "4",
    ("22", "GANIA"): "5",
    ("22", "KHANDAPADA"): "6",
    ("22", "NUAGAON"): "7",
    ("22", "ODAGAON"): "8",
    ("22", "RANPUR"): "9",

    # NUAPADA (district 21)
    ("21", "NUAPADA"): "1",
    ("21", "BODEN"): "2",
    ("21", "KOMNA"): "3",
    ("21", "KHARIAR"): "4",
    ("21", "SINAPALI"): "5",

    # PURI (district 11)
    ("11", "PURI"): "1",        ("11", "PURI SADAR"): "1",
    ("11", "BRAHMAGIRI"): "2",
    ("11", "DELANGA"): "3",
    ("11", "GOP"): "4",
    ("11", "KAKATPUR"): "5",
    ("11", "KANAS"): "6",
    ("11", "KRUSHNAPRASAD"): "7",
    ("11", "NIMAPADA"): "8",
    ("11", "PIPILI"): "9",
    ("11", "SATYABADI"): "10",
    ("11", "ASTARANGA"): "11",  ("11", "ASTARANG"): "11",

    # RAYAGADA (district 27)
    ("27", "RAYAGADA"): "1",
    ("27", "BISSAMCUTTACK"): "2",
    ("27", "CHANDRAPUR"): "3",
    ("27", "GUDARI"): "4",
    ("27", "GUNUPUR"): "5",
    ("27", "KALYANSINGHPUR"): "6",
    ("27", "KASHIPUR"): "7",
    ("27", "KOLNARA"): "8",
    ("27", "MUNIGUDA"): "9",
    ("27", "PADMAPUR"): "10",
    ("27", "RAMANAGUDA"): "11",

    # SAMBALPUR (district 12)
    ("12", "SAMBALPUR"): "1",   ("12", "SAMBALPUR SADAR"): "1",
    ("12", "BAMRA"): "2",
    ("12", "DHANKAUDA"): "3",
    ("12", "JAMANKIRA"): "4",
    ("12", "JUJOMURA"): "5",
    ("12", "KOCHINDA"): "6",    ("12", "KUCHINDA"): "6",
    ("12", "MANESWAR"): "7",
    ("12", "NAKTIDEUL"): "8",
    ("12", "RAIRAKHOL"): "9",   ("12", "REDHAKHOL"): "9",
    ("12", "RENGALI"): "10",

    # SUBARNAPUR (district 23)
    ("23", "SONEPUR"): "1",     ("23", "SUBARNAPUR"): "1",
    ("23", "BINKA"): "2",
    ("23", "BIRMAHARAJPUR"): "3",
    ("23", "DUNGURIPALI"): "4",
    ("23", "TARBHA"): "5",
    ("23", "ULLUNDA"): "6",

    # SUNDARGARH (district 13)
    ("13", "SUNDARGARH"): "1",  ("13", "SUNDARGARH SADAR"): "1",
    ("13", "PANPOSH"): "2",     ("13", "ROURKELA"): "2",
    ("13", "BONAI"): "3",
    ("13", "BARGAON"): "4",
    ("13", "BISRA"): "5",
    ("13", "GURUNDIA"): "6",
    ("13", "HEMGIR"): "7",
    ("13", "KARMAL"): "8",
    ("13", "KOIRA"): "9",
    ("13", "KUTRA"): "10",
    ("13", "LAHUNIPADA"): "11",
    ("13", "LATHIKATA"): "12",
    ("13", "LEPHRIPARA"): "13",
    ("13", "RAJGANGPUR"): "14",
    ("13", "SUBDEGA"): "15",
    ("13", "TANGARAPALI"): "16",
}

# ── Village Map: (district_id, tahasil_id, village_normalized) → village ID ────
VILLAGE_MAP: Dict[Tuple[str, str, str], str] = {
    ("7", "4", "G KERI 271"): "179",
    ("7", "4", "G KERI"): "179",
    ("7", "4", "DIMBO 180"): "180",
    ("7", "4", "DIMBO"): "180",
    ("7", "4", "MEDINIPUR 272"): "272",
    ("7", "4", "BANIAPAT 270"): "270",
    ("7", "4", "KENDUJHARGARH"): "1",
    ("7", "4", "KASIPAL 269"): "269",
    ("7", "4", "RAISUAN 201"): "201",
    ("7", "4", "PADMAPUR 273"): "273",
    ("7", "4", "BODAPALASA 274"): "274",
    ("7", "4", "GOVINDAPUR 275"): "275",
    ("7", "4", "DUMURIA 276"): "276",
    ("7", "4", "NUAGAON 277"): "277",
    ("7", "4", "GOUDASAHI 278"): "278",
    ("7", "4", "PANDAPADA 279"): "279",
    ("7", "4", "KHANDABANDHA 280"): "280",
    ("7", "4", "MAHADEVPUR 281"): "281",
    ("7", "4", "BADAPALASA 282"): "282",
    ("7", "4", "SANAPALASA 283"): "283",
    ("7", "4", "TIKIRA 284"): "284",
    ("7", "4", "CHAMPUA 1"): "1",
    ("7", "3", "CHAMPUA 1"): "1",
    ("7", "3", "CHAMPUA"): "1",
    ("7", "3", "RIMULI 15"): "15",
    ("7", "3", "BARIA 45"): "45",
    ("7", "3", "BALIBANDHA 102"): "102",
    ("7", "3", "KODAPADA 110"): "110",
    ("7", "3", "JAMUDIHA 115"): "115",
    ("7", "3", "TURUMUNGA 120"): "120",
    ("7", "3", "KHAJURIDIHI 130"): "130",
    ("7", "1", "ANANDAPUR 1"): "1",
    ("7", "1", "SAILONG 12"): "12",
    ("7", "1", "KANTIPAL 30"): "30",
    ("7", "1", "SALABANI 45"): "45",
    ("7", "1", "FAKIRPUR 50"): "50",
    ("7", "1", "BAUNSHAGARH 60"): "60",
    ("7", "1", "HARICHANDANPUR 1"): "1",
    ("7", "1", "TELKOI 1"): "1",
    ("7", "6", "GHATAGAON 1"): "1",
    ("7", "6", "PIPILIA 10"): "10",
    ("7", "6", "DHARAKOTE 20"): "20",
    ("7", "7", "HATADIHI 1"): "1",
    ("7", "7", "HADGARH 15"): "15",
    ("7", "8", "PATNA 1"): "1",
    ("7", "8", "KENDUPASI 25"): "25",
    ("7", "9", "HARICHANDANPUR 1"): "1",
    ("7", "10", "BANSPAL 1"): "1",
    ("7", "11", "GHASIPURA 1"): "1",
    ("7", "12", "JHUMPURA 1"): "1",
    ("7", "13", "SAHARPADA 1"): "1",
    ("3", "4", "CUTTACK MUNICIPALITY"): "1",
    ("3", "4", "CHOUDWAR 2"): "2",
    ("3", "4", "BIDANASI 10"): "10",
    ("3", "4", "CHAULIAGANJ 20"): "20",
    ("3", "4", "MADHUPATNA 30"): "30",
    ("3", "4", "TELENGAPENTHA 40"): "40",
    ("3", "4", "GOPALPUR 50"): "50",
    ("3", "4", "KALYANINAGAR 60"): "60",
    ("3", "7", "SALIPUR 1"): "1",
    ("3", "7", "KAMPUR 15"): "15",
    ("3", "7", "BAHUGRAM 30"): "30",
    ("3", "1", "ATHAGARH 1"): "1",
    ("3", "2", "BANKI 1"): "1",
    ("3", "3", "BADAMBA 1"): "1",
    ("20", "1", "BHUBANESWAR"): "1",
    ("20", "1", "CHANDRASEKHARPUR 1"): "1",
    ("20", "1", "NAYAPALLI 2"): "2",
    ("20", "1", "SAHIDNAGAR 3"): "3",
    ("20", "1", "KHANDAGIRI 4"): "4",
    ("20", "1", "PATIA 5"): "5",
    ("20", "1", "JAGAMARA 6"): "6",
    ("20", "1", "BARAMUNDA 7"): "7",
    ("20", "1", "JATNI 1"): "1",
    ("15", "1", "BARGARH 1"): "1",
    ("15", "1", "KANTAPALI 1"): "10",
    ("15", "1", "KANTAPALI 2"): "11",
    ("15", "1", "HALDIPALI 20"): "20",
    ("1", "1", "BALASORE 1"): "1",
    ("1", "1", "CHANDIPUR 5"): "5",
    ("1", "1", "REUNA 10"): "10",
    ("11", "1", "PURI 1"): "1",
    ("11", "1", "BALIGHALI 5"): "5",
    ("11", "1", "MALATIPATPUR 10"): "10",
}

# ── RI Circles Map: (district_id, tahasil_id, village_id) → RI Circle Name ───
RI_CIRCLE_MAP: Dict[Tuple[str, str, str], str] = {
    ("7", "4", "179"): "KEONJHAR 'A'",
    ("7", "4", "180"): "KEONJHAR 'A'",
    ("7", "4", "272"): "KEONJHAR 'B'",
    ("7", "4", "270"): "KEONJHAR 'A'",
    ("7", "3", "1"): "CHAMPUA",
    ("3", "4", "1"): "CUTTACK TOWN",
    ("20", "1", "1"): "BHUBANESWAR CENTRAL",
    ("20", "1", "5"): "PATIA",
}

GIS_BLOCK_TO_TAHASIL: Dict[str, str] = {
    "0701": "1",   # Anandapur
    "0702": "2",   # Barbil
    "0703": "3",   # Champua
    "0704": "4",   # Keonjhar Sadar
    "0705": "5",   # Telkoi
    "0706": "6",   # Ghatagaon
    "0707": "7",   # Hatadihi
    "0708": "8",   # Patna
    "0709": "9",   # Harichandanpur
    "0710": "10",  # Banspal
    "0711": "11",  # Ghasipura
    "0712": "12",  # Jhumpura
    "0713": "13",  # Saharpada
}


def normalize(name: str) -> str:
    """Normalize names deterministically for exact matching."""
    s = name.strip().upper()
    s = s.replace("-", " ").replace("_", " ").replace(".", "").replace("'", "")
    # Standardize common spelling variations
    replaces = [
        ("KENDUJHAR", "KEONJHAR"),
        ("BALESHWAR", "BALASORE"),
        ("BALESWAR", "BALASORE"),
        ("ANUGUL", "ANGUL"),
        ("BAUDH", "BOUDH"),
        ("DEBAGARH", "DEOGARH"),
        ("SUNDERGARH", "SUNDARGARH"),
        ("BARAGARH", "BARGARH"),
        ("KHURDA", "KHORDHA"),
        ("SUBARNAPUR", "SONEPUR"),
    ]
    for src, dst in replaces:
        if s == src:
            s = dst
    return " ".join(s.split())


def get_all_districts() -> List[BhulekhDistrict]:
    """Returns all official Odisha districts sorted by numeric ID."""
    districts = []
    for did, name in sorted(OFFICIAL_DISTRICT_NAMES.items(), key=lambda x: int(x[0])):
        districts.append(BhulekhDistrict(id=did, official_name=name))
    return districts


def get_tahasils_for_district(district_id: str) -> List[BhulekhTahasil]:
    """Returns all official Tahasils for a given district ID deterministically."""
    clean_did = str(district_id).strip()
    if clean_did not in OFFICIAL_DISTRICT_NAMES:
        return []

    tahasils_dict: Dict[str, str] = {}
    for (did, tname), tid in sorted(TAHASIL_MAP.items()):
        if did == clean_did:
            # Pick canonical primary name (avoid aliases like "SADAR")
            if tid not in tahasils_dict or len(tname) > len(tahasils_dict[tid]):
                tahasils_dict[tid] = tname

    results = []
    for tid, tname in sorted(tahasils_dict.items(), key=lambda x: int(x[0])):
        results.append(BhulekhTahasil(id=tid, district_id=clean_did, official_name=tname))
    return results


def get_villages_for_tahasil(district_id: str, tahasil_id: str) -> List[BhulekhVillage]:
    """Returns all official revenue villages for a given district & tahasil."""
    clean_did = str(district_id).strip()
    clean_tid = str(tahasil_id).strip()

    villages_dict: Dict[str, str] = {}
    for (did, tid, vname), vid in sorted(VILLAGE_MAP.items()):
        if did == clean_did and tid == clean_tid:
            if vid not in villages_dict or len(vname) > len(villages_dict[vid]):
                villages_dict[vid] = vname

    results = []
    for vid, vname in sorted(villages_dict.items(), key=lambda x: int(x[0])):
        results.append(BhulekhVillage(id=vid, tahasil_id=clean_tid, district_id=clean_did, official_name=vname))
    return results


def get_ri_circles_for_tahasil(district_id: str, tahasil_id: str) -> List[BhulekhRICircle]:
    """Returns all RI Circles registered for a given tahasil."""
    clean_did = str(district_id).strip()
    clean_tid = str(tahasil_id).strip()

    circles = set()
    results = []
    for (did, tid, vid), ric_name in RI_CIRCLE_MAP.items():
        if did == clean_did and tid == clean_tid and ric_name not in circles:
            circles.add(ric_name)
            results.append(
                BhulekhRICircle(
                    id=str(len(results) + 1),
                    tahasil_id=clean_tid,
                    district_id=clean_did,
                    village_id=vid,
                    official_name=ric_name,
                )
            )
    return results


def get_district_id(district: str) -> Optional[str]:
    d = normalize(district)
    return DISTRICT_MAP.get(d)


def get_tahasil_id(district_id: str, tahasil: str) -> Optional[str]:
    clean_did = str(district_id).strip()
    t = normalize(tahasil)
    return TAHASIL_MAP.get((clean_did, t))


def get_village_id(district_id: str, tahasil_id: str, village_name: str) -> Optional[str]:
    clean_did = str(district_id).strip()
    clean_tid = str(tahasil_id).strip()
    v = normalize(village_name)
    return VILLAGE_MAP.get((clean_did, clean_tid, v))


def get_tahasil_id_from_gis_block(b_id: str) -> Optional[str]:
    return GIS_BLOCK_TO_TAHASIL.get(b_id.strip().upper())
