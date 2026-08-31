"""
Bihar Government Land Classification Test Suite
Tests detection of statutory public, government, and common lands:
- Gairmajarua Aam (Public Common)
- Gairmajarua Khas (State-Owned)
- Kaisar-e-Hind (Union Property)
- Infrastructure (Railway, Roads, Canals)
- Private Ryoti distinctions
"""

from scrapers.bihar.bihar_classification import (
    classify_bihar_land_type,
    is_bihar_government_land,
)


def test_gairmajarua_aam_public_land():
    is_govt = is_bihar_government_land(
        raiyat_name="बिहार सरकार",
        land_type="गैरमजरूआ आम",
    )
    assert is_govt is True

    label, govt_flag = classify_bihar_land_type(raw_classification="गैरमजरूआ आम (पोखर/तालाब)")
    assert govt_flag is True
    assert "Public Common" in label or "Government" in label


def test_gairmajarua_khas_state_land():
    is_govt = is_bihar_government_land(
        raiyat_name="अनाबाद बिहार सरकार",
        land_type="गैरमजरूआ खास",
    )
    assert is_govt is True

    label, govt_flag = classify_bihar_land_type(raw_classification="गैरमजरूआ खास")
    assert govt_flag is True
    assert "State Owned" in label or "Government" in label


def test_kaisar_e_hind_union_property():
    is_govt = is_bihar_government_land(
        raiyat_name="कैसर-ए-हिन्द",
        land_type="कैसर-ए-हिन्द",
    )
    assert is_govt is True

    label, govt_flag = classify_bihar_land_type(raw_classification="कैसर-ए-हिन्द")
    assert govt_flag is True
    assert "Kaisar-e-Hind" in label or "Union Property" in label


def test_railway_and_road_infrastructure():
    is_railway = is_bihar_government_land(
        raiyat_name="पूर्व रेलवे",
        land_type="रेलवे भूमि",
    )
    assert is_railway is True

    is_road = is_bihar_government_land(
        raiyat_name="सर्वसाधारण / पथ निर्माण विभाग",
        land_type="सड़क",
    )
    assert is_road is True


def test_private_ryoti_agricultural_land():
    is_govt = is_bihar_government_land(
        raiyat_name="राम प्रसाद",
        land_type="भीठ-2",
        khata_type="रैयती",
    )
    assert is_govt is False

    label, govt_flag = classify_bihar_land_type(raw_classification="भीठ-2")
    assert govt_flag is False
    assert "Bhit" in label


def test_private_homestead_basgit_land():
    is_govt = is_bihar_government_land(
        raiyat_name="सुरेश कुमार",
        land_type="बासगीत / मकान",
    )
    assert is_govt is False

    label, govt_flag = classify_bihar_land_type(raw_classification="बासगीत")
    assert govt_flag is False
    assert "Homestead" in label or "Basgit" in label
