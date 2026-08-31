"""
Bihar Ground Truth 5-Record Benchmark Suite
Tests the 5 core real-world representative patterns:
1. Single-owner private land (Patna)
2. Joint brother tenancy with shares (Gaya)
3. Multi-plot schedule (Muzaffarpur)
4. Traditional Bigha-Katha conversion (Bhagalpur)
5. Statutory Government Land (Darbhanga)
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
    }
]


@pytest.mark.parametrize("case", GROUND_TRUTH_CASES, ids=lambda c: c["case_id"])
def test_ground_truth_case(case):
    res = BiharJamabandiParser.parse_dict(case["payload"])
    assert res.success is True
    assert res.district == case["district"]
    assert res.tahasil == case["anchal"]
    assert res.village == case["village"]
    assert res.khata_number == case["khata"]
    assert res.plot == case["khesra"]
    assert res.area == case["expected_area"]
    assert len(res.owners) == case["expected_owner_count"]
    
    if "expected_plot_count" in case:
        assert len(res.plots) == case["expected_plot_count"]
    
    is_govt = res.raw_fields.get("is_government_land") == "true"
    assert is_govt == case["expected_is_govt"]
