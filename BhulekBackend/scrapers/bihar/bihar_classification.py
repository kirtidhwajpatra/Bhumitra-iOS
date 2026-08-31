"""
Bihar Land Classification & Statutory Government Land Detection Module
Distinguishes between private agricultural/homestead tenures and public/statutory
government lands (Gairmajarua Aam, Gairmajarua Khas, Khas Mahal, Kaisar-e-Hind).
"""

import re
from typing import Tuple, Optional


GOVERNMENT_LAND_KEYWORDS = [
    "बिहार सरकार",
    "अनाबाद बिहार सरकार",
    "अनाबाद सर्वसाधारण",
    "अनाबाद",
    "गैरमजरूआ आम",
    "गैरमजरूआ खास",
    "गैर मजरूआ",
    "गैरमजरुआ",
    "खास महल",
    "कैसर-ए-हिन्द",
    "कैसरे हिन्द",
    "केसर-ए-हिन्द",
    "सरकार",
    "रेलवे",
    "सड़क",
    "पथ निर्माण",
    "नहर",
    "जलकर",
    "तालाब",
    "पोखर",
    "आहर",
    "पइन",
    "कब्रिस्तान",
    "श्मशान",
    "वन विभाग",
    "गोचर",
    "सर्वसाधारण",
]


LAND_CLASSIFICATION_MAP = [
    # Government & Public Utilities
    (r"(?:गैरमजरूआ आम|अनाबाद सर्वसाधारण|गोचर|सार्वजनिक)", "Government - Public Common (Gairmajarua Aam)"),
    (r"(?:गैरमजरूआ खास|अनाबाद बिहार सरकार|खास महल)", "Government - State Owned (Gairmajarua Khas)"),
    (r"(?:कैसर[- ]?ए[- ]?हिन्द)", "Government - Union Property (Kaisar-e-Hind)"),
    (r"(?:रेलवे|railway)", "Government - Railways"),
    (r"(?:सड़क|रास्ता|पथ|road)", "Government - Road / Infrastructure"),
    (r"(?:तालाब|पोखर|नहर|जलकर|आहर|पइन|water)", "Government - Water Body"),
    (r"(?:कब्रिस्तान|श्मशान|मठ|मंदिर|मस्जिद)", "Public / Religious Amenity"),
    (r"(?:बिहार सरकार|govt|government)", "Government Land"),

    # Agricultural Lands
    (r"(?:भीठ[- ]?1|भीठ[- ]?१|bhit[- ]?1)", "Agricultural - Bhit I (Upland High Yield)"),
    (r"(?:भीठ[- ]?2|भीठ[- ]?२|bhit[- ]?2|भीठ|bhit)", "Agricultural - Bhit II (Upland)"),
    (r"(?:धनहर[- ]?1|धनहर[- ]?१|dhanhar[- ]?1)", "Agricultural - Dhanhar I (Lowland Paddy High Yield)"),
    (r"(?:धनहर[- ]?2|धनहर[- ]?२|dhanhar[- ]?2)", "Agricultural - Dhanhar II (Lowland Paddy)"),
    (r"(?:धनहर[- ]?3|धनहर[- ]?३|dhanhar[- ]?3|धनहर|dhanhar)", "Agricultural - Dhanhar III (Lowland)"),
    (r"(?:बगीचा|बाग|उद्यान|orchard)", "Agricultural - Orchard (Bagh)"),
    (r"(?:परती|parti|parti kadim|parti jadid)", "Agricultural - Fallow (Parti)"),

    # Residential & Commercial Lands
    (r"(?:बासगीत|मकान|आवासीय|residential|homestead)", "Residential - Homestead (Basgit / Makan)"),
    (r"(?:व्यावसायिक|दुकान|commercial)", "Commercial Land"),

    # General Ryoti
    (r"(?:रैयती|कायमी|शिकमी|काश्त|ryoti)", "Private Ryoti Tenancy"),
]


def is_bihar_government_land(
    raiyat_name: Optional[str] = None,
    land_type: Optional[str] = None,
    khata_type: Optional[str] = None,
    remarks: Optional[str] = None,
) -> bool:
    """
    Deterministic rule engine to identify whether a Bihar land parcel is government-owned.
    Checks Raiyat name, land classification, Khata category, and remarks.
    """
    combined_text = " ".join([
        str(raiyat_name or ""),
        str(land_type or ""),
        str(khata_type or ""),
        str(remarks or ""),
    ]).strip().lower()

    if not combined_text:
        return False

    for kw in GOVERNMENT_LAND_KEYWORDS:
        if kw.lower() in combined_text:
            return True

    return False


def classify_bihar_land_type(
    raw_classification: Optional[str] = None,
    raiyat_name: Optional[str] = None,
    remarks: Optional[str] = None,
) -> Tuple[str, bool]:
    """
    Normalizes Bihar vernacular land classification into a standard descriptive type
    and returns (standardized_land_type, is_government_land).
    """
    raw_str = (raw_classification or "").strip()
    is_govt = is_bihar_government_land(
        raiyat_name=raiyat_name,
        land_type=raw_str,
        remarks=remarks,
    )

    if not raw_str:
        if is_govt:
            return "Government Land", True
        return "Standard Agricultural / Ryoti", False

    for pattern, normalized_label in LAND_CLASSIFICATION_MAP:
        if re.search(pattern, raw_str, re.IGNORECASE):
            return normalized_label, is_govt

    # Fallback preservation of raw string
    if is_govt:
        return f"Government ({raw_str})", True
    return raw_str, False
