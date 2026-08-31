"""
Bihar HTML Parser End-to-End Fixture Test Suite
Validates the parsing of sanitized HTML fixtures (Single Owner, Multi-Owner,
Traditional Units, Government Lands, Chauhaddi/Boundaries).
"""

import os
from scrapers.bihar.bihar_jamabandi_parser import BiharJamabandiParser

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")


def read_fixture(filename: str) -> str:
    with open(os.path.join(FIXTURES_DIR, filename), "r", encoding="utf-8") as f:
        return f.read()


def test_parse_single_owner_html():
    html = read_fixture("jamabandi_single_owner.html")
    res = BiharJamabandiParser.parse_html(html, requested_plot="245")
    assert res.success is True
    assert res.district == "PATNA"
    assert res.tahasil == "PATNA SADAR"
    assert res.village == "BEGAMPUR"
    assert res.khata_number == "78"
    assert res.plot == "245"
    assert res.area == "0.375 Acre"
    assert len(res.owners) == 1
    assert res.owners[0].name == "राम प्रसाद"
    assert "श्याम नारायण" in (res.owners[0].relation_name or "")
    assert res.raw_fields.get("is_government_land") == "false"


def test_parse_multi_owner_joint_html():
    html = read_fixture("jamabandi_multi_owner_joint.html")
    res = BiharJamabandiParser.parse_html(html, requested_plot="89")
    assert res.success is True
    assert res.district == "GAYA"
    assert res.tahasil == "BODHGAYA"
    assert res.khata_number == "115"
    assert res.plot == "89"
    assert res.area == "0.500 Acre"
    assert len(res.owners) == 3
    assert res.owners[0].name == "सुरेश कुमार"
    assert res.owners[1].name == "महेश कुमार"
    assert res.owners[2].name == "अनिता देवी"


def test_parse_traditional_units_html():
    html = read_fixture("jamabandi_traditional_bigha_katha_dhur.html")
    res = BiharJamabandiParser.parse_html(html, requested_plot="614")
    assert res.success is True
    assert res.district == "BHAGALPUR"
    assert res.tahasil == "KAHALGAON"
    assert res.plot == "614"
    assert res.area == "0.375 Acre"
    assert len(res.owners) == 1
    assert "कैलाश प्रसाद मंडल" in res.owners[0].name


def test_parse_government_gairmajarua_html():
    html = read_fixture("jamabandi_government_gairmajarua.html")
    res = BiharJamabandiParser.parse_html(html, requested_plot="1020")
    assert res.success is True
    assert res.district == "DARBHANGA"
    assert res.tahasil == "BAHADURPUR"
    assert res.plot == "1020"
    assert res.raw_fields.get("is_government_land") == "true"
    assert "Government" in (res.land_type or "")


def test_parse_mutation_and_chauhaddi_html():
    html = read_fixture("jamabandi_mutation_and_chauhaddi.html")
    res = BiharJamabandiParser.parse_html(html, requested_plot="720")
    assert res.success is True
    assert res.district == "PATNA"
    assert res.tahasil == "PHULWARI SHARIF"
    assert res.plot == "720"
    assert res.area == "0.150 Acre"
    assert len(res.owners) == 1
