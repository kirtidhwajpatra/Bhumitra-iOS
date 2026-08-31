"""
Bihar Area Normalization Module
Handles exact mathematical conversion and representation of standard
(Acre, Decimal) and traditional (Bigha, Katha, Dhur) land area units in Bihar.
"""

import re
import math
from typing import Optional, Dict, Any, Tuple


HINDI_DIGITS_MAP = str.maketrans("०१२३४५६७८୯", "0123456789")

# Standard Bihar conversion constants
# 1 Bigha = 20 Katha = 400 Dhur
# Standard Survey (Lagan / Revenue): 1 Katha = 3.125 Decimals (~1361.25 sq ft)
# 1 Bigha = 62.5 Decimals = 0.625 Acre
DECIMALS_PER_KATHA = 3.125
KATHA_PER_BIGHA = 20.0
DHUR_PER_KATHA = 20.0
DECIMALS_PER_ACRE = 100.0


def to_standard_digits(text: str) -> str:
    """Translates Devanagari numerals to standard ASCII digits."""
    if not text:
        return ""
    return str(text).translate(HINDI_DIGITS_MAP).strip()


def parse_traditional_bihar_units(
    bigha_raw: Any,
    katha_raw: Any,
    dhur_raw: Any,
    dhurki_raw: Any = 0,
) -> Tuple[Optional[float], Optional[float], str]:
    """
    Parses traditional Bihar land units (Bigha, Katha, Dhur) into:
    (total_decimals, total_acres, traditional_string_representation).
    
    Returns (None, None, raw_str) if values are negative or completely invalid.
    """
    try:
        b_str = to_standard_digits(str(bigha_raw if bigha_raw is not None else "0"))
        k_str = to_standard_digits(str(katha_raw if katha_raw is not None else "0"))
        d_str = to_standard_digits(str(dhur_raw if dhur_raw is not None else "0"))
        dk_str = to_standard_digits(str(dhurki_raw if dhurki_raw is not None else "0"))

        if any(s.strip().startswith("-") for s in [b_str, k_str, d_str, dk_str]):
            return None, None, "Invalid negative units"

        # Clean non-numeric characters except decimal points
        b_clean = re.sub(r"[^\d.]", "", b_str) or "0"
        k_clean = re.sub(r"[^\d.]", "", k_str) or "0"
        d_clean = re.sub(r"[^\d.]", "", d_str) or "0"
        dk_clean = re.sub(r"[^\d.]", "", dk_str) or "0"

        b = float(b_clean)
        k = float(k_clean)
        d = float(d_clean)
        dk = float(dk_clean)

        if math.isnan(b) or math.isnan(k) or math.isnan(d) or math.isinf(b) or math.isinf(k) or math.isinf(d):
            return None, None, "Non-finite values"

        # Calculate total kathas
        total_kathas = (b * KATHA_PER_BIGHA) + k + (d / DHUR_PER_KATHA) + (dk / (DHUR_PER_KATHA * 20.0))
        total_decimals = total_kathas * DECIMALS_PER_KATHA
        total_acres = total_decimals / DECIMALS_PER_ACRE

        trad_repr = f"{int(b) if b.is_integer() else b} Bigha, {int(k) if k.is_integer() else k} Katha, {int(d) if d.is_integer() else d} Dhur"
        if dk > 0:
            trad_repr += f", {dk} Dhurki"

        return total_decimals, total_acres, trad_repr

    except (ValueError, TypeError):
        return None, None, "Invalid unit format"


def normalize_bihar_area(
    raw_area: Optional[str] = None,
    area_unit: Optional[str] = None,
    bigha: Optional[Any] = None,
    katha: Optional[Any] = None,
    dhur: Optional[Any] = None,
    decimal_val: Optional[Any] = None,
    acre_val: Optional[Any] = None,
) -> Tuple[Optional[str], Optional[str], Dict[str, Any]]:
    """
    Normalizes Bihar land area inputs into:
    1. Normalized Acre String (e.g. "0.375 Acre")
    2. Primary Unit String (e.g. "Acre" or "Decimal")
    3. Area Metadata Dictionary (storing raw values and exact decimals)
    
    Invariant: Area can never be negative.
    """
    meta: Dict[str, Any] = {
        "raw_input": raw_area,
        "raw_unit": area_unit,
        "calculated_decimals": None,
        "traditional_repr": None,
    }

    # 1. Check explicit traditional units if provided
    if bigha is not None or katha is not None or dhur is not None:
        dec, acre, trad_str = parse_traditional_bihar_units(bigha, katha, dhur)
        meta["traditional_repr"] = trad_str
        if acre is not None and dec is not None:
            meta["calculated_decimals"] = round(dec, 4)
            if acre == 0:
                return "0.000 Acre", "Acre", meta
            return f"{acre:.3f} Acre", "Acre", meta

    # 2. Check explicit Acre value
    if acre_val is not None:
        try:
            raw_str = to_standard_digits(str(acre_val)).strip()
            if raw_str.startswith("-"):
                return None, None, meta
            a_clean = re.sub(r"[^\d.]", "", raw_str)
            if a_clean:
                a_float = float(a_clean)
                if a_float < 0 or math.isnan(a_float) or math.isinf(a_float):
                    return None, None, meta
                meta["calculated_decimals"] = round(a_float * 100.0, 4)
                return f"{a_float:.3f} Acre", "Acre", meta
        except (ValueError, TypeError):
            pass

    # 3. Check explicit Decimal value
    if decimal_val is not None:
        try:
            raw_str = to_standard_digits(str(decimal_val)).strip()
            if raw_str.startswith("-"):
                return None, None, meta
            d_clean = re.sub(r"[^\d.]", "", raw_str)
            if d_clean:
                d_float = float(d_clean)
                if d_float < 0 or math.isnan(d_float) or math.isinf(d_float):
                    return None, None, meta
                a_float = d_float / 100.0
                meta["calculated_decimals"] = round(d_float, 4)
                return f"{a_float:.3f} Acre", "Acre", meta
        except (ValueError, TypeError):
            pass

    # 4. Parse composite raw_area text
    if raw_area:
        text = to_standard_digits(str(raw_area)).strip()
        meta["raw_input"] = text

        # Check for traditional B-K-D patterns in text (e.g. "0-12-0" or "0 बीघा 12 कट्ठा")
        bkd_match = re.search(r"(\d+(?:\.\d+)?)\s*(?:-|बीघा|bigha)\s*(\d+(?:\.\d+)?)\s*(?:-|कट्ठा|कट्टा|katha)\s*(\d+(?:\.\d+)?)", text, re.IGNORECASE)
        if bkd_match:
            b, k, d = float(bkd_match.group(1)), float(bkd_match.group(2)), float(bkd_match.group(3))
            dec, acre, trad_str = parse_traditional_bihar_units(b, k, d)
            meta["traditional_repr"] = trad_str
            if acre is not None and dec is not None:
                meta["calculated_decimals"] = round(dec, 4)
                return f"{acre:.3f} Acre", "Acre", meta

        # Check if text contains "Decimal" or "डिसमिल" / "दशमलव"
        if any(unit in text.lower() or unit in text for unit in ["decimal", "डिसमिल", "दिसमिल", "dec"]):
            num_match = re.search(r"(\d+(?:\.\d+)?)", text)
            if num_match:
                d_float = float(num_match.group(1))
                if d_float < 0:
                    return None, None, meta
                meta["calculated_decimals"] = round(d_float, 4)
                return f"{(d_float / 100.0):.3f} Acre", "Acre", meta

        # Check if text contains "Acre" or "एकड़"
        if any(unit in text.lower() or unit in text for unit in ["acre", "एकड़", "एकड"]):
            num_match = re.search(r"(\d+(?:\.\d+)?)", text)
            if num_match:
                a_float = float(num_match.group(1))
                if a_float < 0:
                    return None, None, meta
                meta["calculated_decimals"] = round(a_float * 100.0, 4)
                return f"{a_float:.3f} Acre", "Acre", meta

        # Bare number parsing
        num_clean = re.sub(r"[^\d.]", "", text)
        if num_clean and num_clean != ".":
            try:
                val = float(num_clean)
                if val < 0 or math.isnan(val) or math.isinf(val):
                    return None, None, meta
                
                # Check unit hint
                if area_unit and any(u in area_unit.lower() or u in area_unit for u in ["decimal", "डिसमिल", "दिसमिल"]):
                    meta["calculated_decimals"] = round(val, 4)
                    return f"{(val / 100.0):.3f} Acre", "Acre", meta
                elif area_unit and any(u in area_unit.lower() or u in area_unit for u in ["acre", "एकड़"]):
                    meta["calculated_decimals"] = round(val * 100.0, 4)
                    return f"{val:.3f} Acre", "Acre", meta
                else:
                    # Default: If number is formatted like an acre (e.g. 0.375 or 1.500)
                    meta["calculated_decimals"] = round(val * 100.0, 4)
                    return f"{val:.3f} Acre", "Acre", meta
            except ValueError:
                pass

    return None, None, meta
