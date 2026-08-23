"""
Canonical Plot Number Normalization Engine
Enforces deterministic, strict, and field-aware plot number normalization across Odisha Bhulekh.

Preserves exact plot distinction:
- Odia numerals are deterministically converted to ASCII digits (e.g. '୧୨୩' -> '123').
- Harmless internal whitespace around slashes/hyphens is cleaned (e.g. '12 / 1' -> '12/1').
- Alphanumeric sub-plot suffixes are standardized to uppercase (e.g. '12a' -> '12A').
- Leading zeroes and fractions are STRICTLY preserved (e.g. '0123' != '123', '12' != '12/1').
"""
import re
from typing import Optional

ODIA_TO_ASCII_DIGITS = str.maketrans("୦୧୨୩୪୫୬୭୮୯", "0123456789")


def normalize_plot_number(raw_plot: Optional[str]) -> str:
    """
    Normalizes a plot identifier string without merging distinct plots.
    
    Examples:
        normalize_plot_number(" 123 ") -> "123"
        normalize_plot_number("୧୨୩") -> "123"
        normalize_plot_number("12 / 1") -> "12/1"
        normalize_plot_number("୧୨/୧") -> "12/1"
        normalize_plot_number("12a") -> "12A"
        normalize_plot_number("0123") -> "0123" (distinct from "123")
        normalize_plot_number("12/1A") -> "12/1A"
    """
    if raw_plot is None:
        return ""
    
    # 1. Stringify and strip surrounding whitespace
    text = str(raw_plot).strip()
    if not text:
        return ""
    
    # 2. Translate Odia numerals to ASCII digits
    text = text.translate(ODIA_TO_ASCII_DIGITS)
    
    # 3. Clean harmless whitespace around slashes and hyphens
    text = re.sub(r'\s*/\s*', '/', text)
    text = re.sub(r'\s*-\s*', '-', text)
    
    # 4. Standardize whitespace between numbers and suffix letters (e.g. "12 a" -> "12A")
    text = re.sub(r'(\d+)\s+([A-Za-z]+)', r'\1\2', text)
    
    # 5. Standardize uppercase
    text = text.upper()
    
    # 6. Clean any remaining multiple spaces
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text


def is_exact_plot_match(plot_a: Optional[str], plot_b: Optional[str]) -> bool:
    """
    Strict equality comparison between two plot strings after canonical normalization.
    """
    norm_a = normalize_plot_number(plot_a)
    norm_b = normalize_plot_number(plot_b)
    if not norm_a or not norm_b:
        return False
    return norm_a == norm_b
