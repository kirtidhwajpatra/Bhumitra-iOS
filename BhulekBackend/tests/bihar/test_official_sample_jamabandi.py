"""
Test Suite: Official Bihar Government Jamabandi Structural Fixture
Validates the current baseline parser against the official Bihar government Jamabandi sample.
"""

import os
import json
import pytest
from scrapers.bihar.bihar_jamabandi_parser import BiharJamabandiParser

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")


def read_fixture_file(filename: str) -> str:
    with open(os.path.join(FIXTURES_DIR, filename), "r", encoding="utf-8") as f:
        return f.read()


def test_parse_official_sample_html():
    html = read_fixture_file("official_sample_jamabandi.html")
    res = BiharJamabandiParser.parse_html(
        html_content=html,
        requested_district="PATNA",
        requested_anchal="PATNA SADAR",
        requested_village="BEGAMPUR",
        requested_plot="245",
        requested_khata="78",
    )

    # 1. Verification & Top-Level Success
    assert res.success is True
    assert res.district == "PATNA"
    assert res.tahasil == "PATNA SADAR"
    assert res.village == "BEGAMPUR"
    assert res.plot == "245"
    assert res.khata_number == "78"

    # 2. Area & Classification Parsing
    assert res.area == "0.375 Acre"
    assert "Bhit" in (res.land_type or "") or "भीठ" in (res.land_type or "")

    # 3. Titleholders (Raiyat) Parsing
    assert len(res.owners) == 1
    assert res.owners[0].name == "राम प्रसाद"
    assert "श्याम नारायण" in (res.owners[0].relation_name or "")
    assert res.owners[0].relation == "Father"

    # 4. Supplementary Raw Fields
    assert res.raw_fields.get("thana_no") == "108"
    assert res.raw_fields.get("jamabandi_no") == "412"
    assert "12" in res.raw_fields.get("vol_page_no", "")
    assert "85" in res.raw_fields.get("vol_page_no", "")
    assert res.raw_fields.get("is_government_land") == "false"


def test_parse_official_sample_json_dict():
    payload_str = read_fixture_file("official_sample_jamabandi.json")
    payload = json.loads(payload_str)

    res = BiharJamabandiParser.parse_dict(
        payload=payload,
        requested_district="PATNA",
        requested_anchal="PATNA SADAR",
        requested_village="BEGAMPUR",
        requested_plot="245",
    )

    assert res.success is True
    assert res.district == "PATNA"
    assert res.tahasil == "PATNA SADAR"
    assert res.village == "BEGAMPUR"
    assert res.plot == "245"
    assert res.khata_number == "78"
    assert res.area == "0.375 Acre"
    assert len(res.owners) == 1
    assert res.owners[0].name == "राम प्रसाद"
    assert res.owners[0].relation_name == "श्याम नारायण"
    assert res.raw_fields.get("mutation_case_no") == "04/2021-2022"
    assert res.raw_fields.get("is_government_land") == "false"
