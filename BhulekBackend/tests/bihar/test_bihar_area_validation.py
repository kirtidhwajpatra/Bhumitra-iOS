"""
Bihar Land Area Normalization & Conversion Test Suite
Tests exact mathematical conversion for Acre, Decimal, Bigha, Katha, Dhur
and edge cases (0, very small, large, fractions, negative values, invalid strings).
"""

import pytest
from scrapers.bihar.bihar_area_normalizer import (
    normalize_bihar_area,
    parse_traditional_bihar_units,
    to_standard_digits,
)


def test_standard_acre_normalization():
    norm_area, unit, meta = normalize_bihar_area(acre_val=0.375)
    assert norm_area == "0.375 Acre"
    assert unit == "Acre"
    assert meta["calculated_decimals"] == 37.5


def test_standard_decimal_normalization():
    norm_area, unit, meta = normalize_bihar_area(decimal_val=50)
    assert norm_area == "0.500 Acre"
    assert unit == "Acre"
    assert meta["calculated_decimals"] == 50.0


def test_traditional_bigha_katha_dhur_conversion():
    # 0 Bigha, 12 Katha, 0 Dhur
    # 12 Kathas * 3.125 decimals/katha = 37.5 decimals = 0.375 Acre
    dec, acre, trad_repr = parse_traditional_bihar_units(0, 12, 0)
    assert dec == pytest.approx(37.5, 0.001)
    assert acre == pytest.approx(0.375, 0.001)
    assert "12 Katha" in trad_repr

    norm_area, unit, meta = normalize_bihar_area(bigha=0, katha=12, dhur=0)
    assert norm_area == "0.375 Acre"
    assert meta["traditional_repr"] == "0 Bigha, 12 Katha, 0 Dhur"


def test_traditional_full_bigha_conversion():
    # 1 Bigha = 20 Katha = 62.5 decimals = 0.625 Acre
    dec, acre, trad_repr = parse_traditional_bihar_units(1, 0, 0)
    assert dec == pytest.approx(62.5, 0.001)
    assert acre == pytest.approx(0.625, 0.001)


def test_traditional_dhur_fraction():
    # 1 Katha, 10 Dhur = 1.5 Kathas * 3.125 = 4.6875 decimals = ~0.047 Acre
    dec, acre, trad_repr = parse_traditional_bihar_units(0, 1, 10)
    assert dec == pytest.approx(4.6875, 0.001)
    assert acre == pytest.approx(0.046875, 0.001)


def test_zero_area_edge_case():
    norm_area, unit, meta = normalize_bihar_area(acre_val=0.0)
    assert norm_area == "0.000 Acre"
    assert meta["calculated_decimals"] == 0.0

    norm_trad, _, _ = normalize_bihar_area(bigha=0, katha=0, dhur=0)
    assert norm_trad == "0.000 Acre"


def test_very_small_fractional_area():
    # 0.5 Decimal = 0.005 Acre
    norm_area, unit, meta = normalize_bihar_area(decimal_val=0.5)
    assert norm_area == "0.005 Acre"
    assert meta["calculated_decimals"] == 0.5


def test_large_acreage():
    norm_area, unit, meta = normalize_bihar_area(acre_val=150.750)
    assert norm_area == "150.750 Acre"
    assert meta["calculated_decimals"] == 15075.0


def test_negative_area_rejection_invariant():
    # Negative area must NEVER produce a valid positive or negative string
    norm_area, unit, meta = normalize_bihar_area(acre_val=-5.0)
    assert norm_area is None

    norm_trad, _, _ = normalize_bihar_area(bigha=-1, katha=5, dhur=0)
    assert norm_trad is None


def test_hindi_numeral_area_text_parsing():
    # "०.४५० एकड़"
    norm_area, unit, meta = normalize_bihar_area(raw_area="०.४५० एकड़")
    assert norm_area == "0.450 Acre"

    # "२५ डिसमिल"
    norm_area2, unit2, meta2 = normalize_bihar_area(raw_area="२५ डिसमिल")
    assert norm_area2 == "0.250 Acre"


def test_invalid_and_corrupt_area_strings():
    norm_area, unit, meta = normalize_bihar_area(raw_area="INVALID_STRING_XYZ")
    assert norm_area is None

    norm_empty, _, _ = normalize_bihar_area(raw_area="")
    assert norm_empty is None

    norm_none, _, _ = normalize_bihar_area(raw_area=None)
    assert norm_none is None
