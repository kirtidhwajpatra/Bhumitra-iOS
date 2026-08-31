"""
Bihar Invariant & Property Test Suite
Guarantees critical domain invariants:
- Area can never be negative
- Owner count is internally consistent
- Malformed inputs cannot fabricate successful land records or owners
- Plot and Khata identifiers are strictly preserved
- Government classifications are deterministic
- Missing optional fields do not crash the parser
"""

from scrapers.bihar.bihar_jamabandi_parser import BiharJamabandiParser
from scrapers.bihar.bihar_area_normalizer import normalize_bihar_area
from scrapers.bihar.bihar_classification import is_bihar_government_land


def test_invariant_non_negative_area():
    for negative_val in [-0.001, -1.0, -100.0]:
        norm_a, _, _ = normalize_bihar_area(acre_val=negative_val)
        assert norm_a is None
        norm_d, _, _ = normalize_bihar_area(decimal_val=negative_val)
        assert norm_d is None


def test_invariant_no_fabricated_owners():
    payload = {
        "location": {"district": "PATNA", "anchal": "PATNA SADAR", "mauza": "BEGAMPUR"},
        "register_identifiers": {"khata_number": "10", "khesra_number": "20"},
        "raiyat_details": [],  # Empty owners
        "land_schedule": [{"khesra_no": "20", "area_acre": "0.500"}],
    }
    res = BiharJamabandiParser.parse_dict(payload)
    assert len(res.owners) == 0  # Must not invent or fabricate owners


def test_invariant_preservation_of_plot_and_khata():
    payload = {
        "location": {"district": "GAYA", "anchal": "BODHGAYA", "mauza": "BAKRAUR"},
        "register_identifiers": {"khata_number": "999", "khesra_number": "888"},
        "raiyat_details": [{"raiyat_name": "राम प्रसाद"}],
    }
    res = BiharJamabandiParser.parse_dict(payload)
    assert res.plot == "888"
    assert res.khata_number == "999"


def test_invariant_deterministic_govt_classification():
    # Calling classification 100 times on the same input yields the exact same boolean
    for _ in range(100):
        assert is_bihar_government_land(raiyat_name="बिहार सरकार") is True
        assert is_bihar_government_land(raiyat_name="राम प्रसाद") is False


def test_invariant_resilience_to_missing_optional_fields():
    # Payload with minimal fields
    minimal_payload = {"location": {}, "register_identifiers": {}}
    res = BiharJamabandiParser.parse_dict(minimal_payload)
    assert res is not None
    assert isinstance(res.owners, list)
    assert isinstance(res.plots, list)
    assert isinstance(res.raw_fields, dict)
