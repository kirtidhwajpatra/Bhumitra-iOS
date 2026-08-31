"""
Bihar Owner / Raiyat Normalization Test Suite
Tests single raiyat, multiple raiyats (joint tenancy), guardian names,
father/husband relationships, deceased markers, shares, and identity integrity.
"""

from scrapers.bihar.bihar_owner_normalizer import (
    parse_raiyat_entry,
    normalize_bihar_owners,
)


def test_single_owner_with_explicit_guardian():
    entry = parse_raiyat_entry(
        raiyat_raw="राम प्रसाद",
        guardian_raw="श्याम नारायण",
        relation_raw="Father",
        khata_number="78",
        caste_or_details="GENERAL",
    )
    assert entry is not None
    assert entry.name == "राम प्रसाद"
    assert entry.relation_name == "श्याम नारायण"
    assert entry.relation == "Father"
    assert entry.khata_number == "78"
    assert "GENERAL" in (entry.ownership_details or "")


def test_owner_with_husband_relation():
    entry = parse_raiyat_entry(
        raiyat_raw="अनिता देवी",
        guardian_raw="सुरेश कुमार",
        relation_raw="पति",
        khata_number="115",
    )
    assert entry is not None
    assert entry.name == "अनिता देवी"
    assert entry.relation_name == "सुरेश कुमार"
    assert entry.relation == "Husband"


def test_owner_with_deceased_father_prefix():
    entry = parse_raiyat_entry(
        raiyat_raw="सुरेश कुमार",
        guardian_raw="पिता: स्व० गणेश महतो",
        khata_number="115",
    )
    assert entry is not None
    assert entry.name == "सुरेश कुमार"
    assert "गणेश महतो" in (entry.relation_name or "")
    assert entry.relation == "Father"


def test_embedded_relation_in_raiyat_string():
    entry = parse_raiyat_entry(
        raiyat_raw="दिनेश कुमार पिता रामेश्वर यादव",
        khata_number="200",
    )
    assert entry is not None
    assert entry.name == "दिनेश कुमार"
    assert entry.relation_name == "रामेश्वर यादव"
    assert entry.relation == "Father"


def test_multiple_owners_joint_tenancy_no_merging():
    raw_list = [
        {"name": "सुरेश कुमार", "father_name": "गणेश महतो", "relation": "Father", "share": "1/2"},
        {"name": "महेश कुमार", "father_name": "गणेश महतो", "relation": "Father", "share": "1/2"},
    ]
    owners = normalize_bihar_owners(raw_list, default_khata="115")
    assert len(owners) == 2
    assert owners[0].name == "सुरेश कुमार"
    assert owners[1].name == "महेश कुमार"
    assert owners[0].share == "1/2"
    assert owners[1].share == "1/2"


def test_duplicate_owner_deduplication():
    # If the exact same person is repeated verbatim, dedup safely
    raw_list = [
        {"name": "राम प्रसाद", "guardian_name": "श्याम नारायण", "relation": "Father"},
        {"name": "राम प्रसाद", "guardian_name": "श्याम नारायण", "relation": "Father"},
    ]
    owners = normalize_bihar_owners(raw_list, default_khata="78")
    assert len(owners) == 1
    assert owners[0].name == "राम प्रसाद"


def test_empty_and_whitespace_raiyat_handling():
    entry = parse_raiyat_entry(raiyat_raw="   ", guardian_raw="")
    assert entry is None

    owners = normalize_bihar_owners([{"name": ""}], default_khata="10")
    assert len(owners) == 0
