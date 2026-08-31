"""
Bihar Golden Fixtures Test Suite
Executes and validates all 30 distinct golden data patterns defined in bihar_golden_fixtures.json.
Ensures deterministic normalization, schema adherence, and regression prevention.
"""

import json
import os
import pytest
from scrapers.bihar.bihar_jamabandi_parser import BiharJamabandiParser

FIXTURES_PATH = os.path.join(os.path.dirname(__file__), "fixtures", "bihar_golden_fixtures.json")


def load_golden_fixtures():
    with open(FIXTURES_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


@pytest.mark.parametrize("case", load_golden_fixtures(), ids=lambda c: c["case_id"])
def test_bihar_golden_fixture_case(case):
    case_id = case["case_id"]
    inp = case["input"]
    exp = case["expected"]

    res = BiharJamabandiParser.parse_dict(inp)

    # Core Assertions
    assert res.success is True, f"{case_id} failed: expected success=True"
    assert res.plot == exp["plot"], f"{case_id} plot mismatch: got {res.plot}, expected {exp['plot']}"
    
    if "district" in exp:
        assert res.district == exp["district"]
    if "tahasil" in exp:
        assert res.tahasil == exp["tahasil"]
    if "khata_number" in exp:
        assert res.khata_number == exp["khata_number"]
    if "area" in exp:
        assert res.area == exp["area"], f"{case_id} area mismatch: got {res.area}, expected {exp['area']}"
    if "owner_count" in exp:
        assert len(res.owners) == exp["owner_count"], f"{case_id} owner count mismatch: got {len(res.owners)}, expected {exp['owner_count']}"
    if "plot_count" in exp:
        assert len(res.plots) == exp["plot_count"]
    if "is_government" in exp:
        is_govt = res.raw_fields.get("is_government_land") == "true"
        assert is_govt == exp["is_government"], f"{case_id} government land flag mismatch: got {is_govt}, expected {exp['is_government']}"
