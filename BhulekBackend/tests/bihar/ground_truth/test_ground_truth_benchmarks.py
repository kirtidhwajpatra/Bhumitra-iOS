"""
Bihar Ground Truth 10-Record Comprehensive Benchmark Suite
Tests 10 real-world representative patterns across 10 Bihar districts:
1. Patna (Single-owner private holding)
2. Gaya (Joint brother tenancy with fractional shares)
3. Muzaffarpur (Multi-plot holding)
4. Bhagalpur (Traditional Bigha-Katha conversion)
5. Darbhanga (Statutory Gairmajarua Aam government land)
6. Samastipur (Missing Khata in source - legacy register)
7. Purnia (Multi-owner mixed spousal/parental relationships)
8. Begusarai (Homestead Basgit land with Chauhaddi boundaries)
9. Nalanda (State Government Gairmajarua Khas land)
10. Vaishali (Agricultural holding with Mutation history)
"""

import pytest
from scrapers.bihar.bihar_jamabandi_parser import BiharJamabandiParser


GROUND_TRUTH_CASES = [
    {
        "case_id": "BHR-GT-01",
        "description": "Single-owner private holding (Patna Sadar)",
        "district": "PATNA", "anchal": "PATNA SADAR", "village": "BEGAMPUR", "thana": "108",
        "khata": "78", "khesra": "245", "jamabandi": "412",
        "payload": {
            "location": {"district": "PATNA", "anchal": "PATNA SADAR", "mauza": "BEGAMPUR", "thana_number": "108"},
            "register_identifiers": {"khata_number": "78", "khesra_number": "245", "jamabandi_number": "412"},
            "raiyat_details": [{"raiyat_name": "राम प्रसाद", "guardian_name": "श्याम नारायण", "relation": "Father"}],
            "land_schedule": [{"khesra_no": "245", "area_acre": "0.375", "land_type": "भीठ-2"}]
        },
        "expected_owner_count": 1,
        "expected_area": "0.375 Acre",
        "expected_is_govt": False,
    },
    {
        "case_id": "BHR-GT-02",
        "description": "Joint brother tenancy with 1/2 shares (Bodhgaya)",
        "district": "GAYA", "anchal": "BODHGAYA", "village": "BAKRAUR", "thana": "52",
        "khata": "115", "khesra": "89", "jamabandi": "521",
        "payload": {
            "location": {"district": "GAYA", "anchal": "BODHGAYA", "mauza": "BAKRAUR", "thana_number": "52"},
            "register_identifiers": {"khata_number": "115", "khesra_number": "89"},
            "raiyat_details": [
                {"raiyat_name": "सुरेश कुमार", "guardian_name": "गणेश महतो", "relation": "Father", "share": "1/2"},
                {"raiyat_name": "महेश कुमार", "guardian_name": "गणेश महतो", "relation": "Father", "share": "1/2"}
            ],
            "land_schedule": [{"khesra_no": "89", "area_decimal": "50", "land_type": "धनहर-1"}]
        },
        "expected_owner_count": 2,
        "expected_area": "0.500 Acre",
        "expected_is_govt": False,
    },
    {
        "case_id": "BHR-GT-03",
        "description": "Multi-plot holding (Kanti, Muzaffarpur)",
        "district": "MUZAFFARPUR", "anchal": "KANTI", "village": "DAMODARPUR", "thana": "74",
        "khata": "204", "khesra": "501", "jamabandi": "630",
        "payload": {
            "location": {"district": "MUZAFFARPUR", "anchal": "KANTI", "mauza": "DAMODARPUR", "thana_number": "74"},
            "register_identifiers": {"khata_number": "204", "khesra_number": "501"},
            "raiyat_details": [{"raiyat_name": "विनोद राय", "guardian_name": "रामलोचन राय", "relation": "Father"}],
            "land_schedule": [
                {"khesra_no": "501", "area_acre": "0.250", "land_type": "भीठ-1"},
                {"khesra_no": "502", "area_acre": "0.400", "land_type": "धनहर-2"},
                {"khesra_no": "503", "area_acre": "0.120", "land_type": "बासगीत"}
            ]
        },
        "expected_owner_count": 1,
        "expected_area": "0.250 Acre",
        "expected_plot_count": 3,
        "expected_is_govt": False,
    },
    {
        "case_id": "BHR-GT-04",
        "description": "Traditional Bigha-Katha conversion (Kahalgaon, Bhagalpur)",
        "district": "BHAGALPUR", "anchal": "KAHALGAON", "village": "SHIVNARAYANPUR", "thana": "112",
        "khata": "93", "khesra": "614", "jamabandi": "740",
        "payload": {
            "location": {"district": "BHAGALPUR", "anchal": "KAHALGAON", "mauza": "SHIVNARAYANPUR", "thana_number": "112"},
            "register_identifiers": {"khata_number": "93", "khesra_number": "614"},
            "raiyat_details": [{"raiyat_name": "कैलाश प्रसाद मंडल", "guardian_name": "जगदीश मंडल", "relation": "Father"}],
            "land_schedule": [{"khesra_no": "614", "area_bigha": "0", "area_katha": "12", "area_dhur": "0", "land_type": "भीठ-2"}]
        },
        "expected_owner_count": 1,
        "expected_area": "0.375 Acre",
        "expected_is_govt": False,
    },
    {
        "case_id": "BHR-GT-05",
        "description": "Statutory Government Land (Bahadurpur, Darbhanga)",
        "district": "DARBHANGA", "anchal": "BAHADURPUR", "village": "DEKULI", "thana": "45",
        "khata": "1", "khesra": "1020", "jamabandi": "1",
        "payload": {
            "location": {"district": "DARBHANGA", "anchal": "BAHADURPUR", "mauza": "DEKULI", "thana_number": "45"},
            "register_identifiers": {"khata_number": "1", "khesra_number": "1020"},
            "raiyat_details": [{"raiyat_name": "बिहार सरकार", "guardian_name": "-", "relation": None}],
            "land_schedule": [{"khesra_no": "1020", "area_acre": "1.500", "land_type": "गैरमजरूआ आम (पोखर)"}]
        },
        "expected_owner_count": 1,
        "expected_area": "1.500 Acre",
        "expected_is_govt": True,
    },
    {
        "case_id": "BHR-GT-06",
        "description": "Missing Khata in source legacy record (Kalyanpur, Samastipur)",
        "district": "SAMASTIPUR", "anchal": "KALYANPUR", "village": "VASUDEVPUR", "thana": "18",
        "khata": None, "khesra": "310", "jamabandi": "89",
        "payload": {
            "location": {"district": "SAMASTIPUR", "anchal": "KALYANPUR", "mauza": "VASUDEVPUR", "thana_number": "18"},
            "register_identifiers": {"khata_number": None, "khesra_number": "310", "jamabandi_number": "89"},
            "raiyat_details": [{"raiyat_name": "संजय झा", "guardian_name": "उमेश झा", "relation": "Father"}],
            "land_schedule": [{"khesra_no": "310", "area_decimal": "25", "land_type": "भीठ-1"}]
        },
        "expected_owner_count": 1,
        "expected_area": "0.250 Acre",
        "expected_is_govt": False,
    },
    {
        "case_id": "BHR-GT-07",
        "description": "Mixed spousal and parental joint titles (Kasba, Purnia)",
        "district": "PURNIA", "anchal": "KASBA", "village": "JALALGARH", "thana": "91",
        "khata": "142", "khesra": "405", "jamabandi": "912",
        "payload": {
            "location": {"district": "PURNIA", "anchal": "KASBA", "mauza": "JALALGARH", "thana_number": "91"},
            "register_identifiers": {"khata_number": "142", "khesra_number": "405"},
            "raiyat_details": [
                {"raiyat_name": "अनिता देवी", "guardian_name": "राजेश शर्मा", "relation": "Husband", "share": "1/2"},
                {"raiyat_name": "अमित शर्मा", "guardian_name": "राजेश शर्मा", "relation": "Father", "share": "1/2"}
            ],
            "land_schedule": [{"khesra_no": "405", "area_acre": "0.800", "land_type": "धनहर-1"}]
        },
        "expected_owner_count": 2,
        "expected_area": "0.800 Acre",
        "expected_is_govt": False,
    },
    {
        "case_id": "BHR-GT-08",
        "description": "Homestead Basgit land with Chauhaddi (Barauni, Begusarai)",
        "district": "BEGUSARAI", "anchal": "BARAUNI", "village": "SIMARIA", "thana": "62",
        "khata": "55", "khesra": "112", "jamabandi": "304",
        "payload": {
            "location": {"district": "BEGUSARAI", "anchal": "BARAUNI", "mauza": "SIMARIA", "thana_number": "62"},
            "register_identifiers": {"khata_number": "55", "khesra_number": "112"},
            "raiyat_details": [{"raiyat_name": "मनोज पोद्दार", "guardian_name": "केदार पोद्दार", "relation": "Father"}],
            "land_schedule": [{
                "khesra_no": "112",
                "area_decimal": "10",
                "land_type": "बासगीत (Homestead)",
                "boundaries": {"north": "सड़क", "south": "निज प्लॉट", "east": "सुरेश", "west": "रास्ता"}
            }]
        },
        "expected_owner_count": 1,
        "expected_area": "0.100 Acre",
        "expected_is_govt": False,
    },
    {
        "case_id": "BHR-GT-09",
        "description": "State Government Gairmajarua Khas land (Biharsharif, Nalanda)",
        "district": "NALANDA", "anchal": "BIHARSHARIF", "village": "MAGHRA", "thana": "34",
        "khata": "2", "khesra": "990", "jamabandi": "5",
        "payload": {
            "location": {"district": "NALANDA", "anchal": "BIHARSHARIF", "mauza": "MAGHRA", "thana_number": "34"},
            "register_identifiers": {"khata_number": "2", "khesra_number": "990"},
            "raiyat_details": [{"raiyat_name": "अनाबाद बिहार सरकार", "guardian_name": "-", "relation": None}],
            "land_schedule": [{"khesra_no": "990", "area_acre": "2.450", "land_type": "गैरमजरूआ खास (परती जदीद)"}]
        },
        "expected_owner_count": 1,
        "expected_area": "2.450 Acre",
        "expected_is_govt": True,
    },
    {
        "case_id": "BHR-GT-10",
        "description": "Agricultural holding with Mutation history (Hajipur, Vaishali)",
        "district": "VAISHALI", "anchal": "HAJIPUR", "village": "DIGHEE", "thana": "82",
        "khata": "310", "khesra": "1420", "jamabandi": "1055",
        "payload": {
            "location": {"district": "VAISHALI", "anchal": "HAJIPUR", "mauza": "DIGHEE", "thana_number": "82"},
            "register_identifiers": {"khata_number": "310", "khesra_number": "1420"},
            "raiyat_details": [{"raiyat_name": "धर्मेन्द्र कुमार सिंह", "guardian_name": "स्व० जगदेव सिंह", "relation": "Father"}],
            "land_schedule": [{"khesra_no": "1420", "area_acre": "1.250", "land_type": "भीठ-1"}],
            "mutation_history": {"case_number": "12/2023-2024", "year": "2023", "status": "APPROVED"}
        },
        "expected_owner_count": 1,
        "expected_area": "1.250 Acre",
        "expected_is_govt": False,
    }
]


@pytest.mark.parametrize("case", GROUND_TRUTH_CASES, ids=lambda c: c["case_id"])
def test_ground_truth_case(case):
    res = BiharJamabandiParser.parse_dict(case["payload"])
    assert res.success is True
    assert res.district == case["district"]
    assert res.tahasil == case["anchal"]
    assert res.village == case["village"]
    
    if case["khata"] is not None:
        assert res.khata_number == case["khata"]
    else:
        assert res.khata_number is None or res.khata_number == ""

    assert res.plot == case["khesra"]
    assert res.area == case["expected_area"]
    assert len(res.owners) == case["expected_owner_count"]
    
    if "expected_plot_count" in case:
        assert len(res.plots) == case["expected_plot_count"]
    
    is_govt = res.raw_fields.get("is_government_land") == "true"
    assert is_govt == case["expected_is_govt"]
