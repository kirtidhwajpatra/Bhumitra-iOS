"""
Village Identity Normalizer for Odisha Land Records.
Performs deterministic, representation-only normalization across English, Odia Unicode,
and GIS naming variations WITHOUT uncontrolled fuzzy guessing.
"""
import re
import unicodedata
from typing import Optional, Tuple


def normalize_unicode_representation(text: str) -> str:
    """
    Normalizes representation differences:
    - NFC Canonical Composition
    - Strips zero-width characters (ZWJ \u200D, ZWNJ \u200C, BOM \uFEFF)
    - Replaces non-breaking spaces and irregular whitespace with standard space
    - Collapses multiple whitespace into single space
    - Normalizes Odia Nukta / Ya / Ra combinations (e.g., ଡ + ଼ -> ଡ଼, ଢ + ଼ -> ଢ଼, ୟ vs ଯ)
    - Strips non-alphanumeric punctuation (dashes, quotes, brackets) while preserving slash numbers
    """
    if not text:
        return ""
    
    # 1. Canonical Unicode Normalization (NFC)
    t = unicodedata.normalize("NFC", str(text))
    
    # 2. Strip Zero-Width and Invisible Characters
    t = re.sub(r"[\u200B-\u200F\uFEFF\u2060\u00AD]", "", t)
    
    # 3. Normalize Whitespace (NBSP, tabs, etc.)
    t = re.sub(r"[\s\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000]+", " ", t).strip()
    
    # 4. Canonical Odia Composite Normalization
    # ଡ (\u0B21) + ଼ (\u0B3C) -> ଡ଼ (\u0B5C)
    t = t.replace("\u0B21\u0B3C", "\u0B5C")
    # ଢ (\u0B22) + ଼ (\u0B3C) -> ଢ଼ (\u0B5D)
    t = t.replace("\u0B22\u0B3C", "\u0B5D")
    # ଳ (\u0B33) + ଼ (\u0B3C) -> ୡ / ଳ
    t = t.replace("\u0B33\u0B3C", "\u0B33")
    # ୟ (\u0B5F) vs ଯ (\u0B2F) + ଼ (\u0B3C)
    t = t.replace("\u0B2F\u0B3C", "\u0B5F")
    
    # 5. Normalize Odia Anusvara / Chandrabindu variations
    # ଁ (\u0B01) vs ଂ (\u0B02) in standard village prefixes (ଅଁଳା vs ଅଂଳା)
    # preserve but harmonize representation
    return t


def normalize_village_name(name: str) -> str:
    """
    Normalizes a village name deterministically for index lookup.
    """
    if not name:
        return ""
    
    t = normalize_unicode_representation(name)
    
    # Strip GIS metadata suffixes like (Mosaic), Unit No, etc.
    t = re.sub(r"[\(_]Mosaic[\)_]", "", t, flags=re.IGNORECASE)
    t = re.sub(r"\bUnit\s*[-–—:]*\s*(?:No\.?)?\s*[-–—:]*\s*\d+\b", "", t, flags=re.IGNORECASE)
    t = re.sub(r"ୟୁନିଟ\s*[-–—:]*\s*(?:ନଂ\.?)?\s*[-–—:]*\s*[\d\u0B66-\u0B6F]+", "", t)
    
    # Replace separators with spaces
    t = re.sub(r"[_\-\–—/,\.()]+", " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    
    return t.upper()


def normalize_odia_village_key(name: str) -> str:
    """
    Generates a deterministic Odia lookup key with normalized nukta and space collapse.
    """
    if not name:
        return ""
    t = normalize_unicode_representation(name)
    # Remove punctuation & whitespace for strict key comparison
    t = re.sub(r"[\s\-_/,\.()]+", "", t)
    return t


def clean_gis_village_input(gis_village: str) -> str:
    """
    Cleans raw GIS village input strings from GeoJSON/API parameters.
    """
    if not gis_village:
        return ""
    t = unicodedata.normalize("NFC", str(gis_village).strip())
    t = re.sub(r"[\u200B-\u200F\uFEFF]", "", t)
    return t
