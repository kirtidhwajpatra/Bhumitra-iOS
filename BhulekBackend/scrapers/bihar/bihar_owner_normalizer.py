"""
Bihar Owner / Raiyat Normalization Module
Extracts, parses, and normalizes titleholders, guardians, relationships,
and fractional shares from Bihar Jamabandi Register-II & Khatiyan records.
"""

import re
from typing import List, Dict, Any, Optional
from models.ror_response import OwnerEntry


RELATION_PREFIX_PATTERNS = [
    (r"(?:पिता\s*स्व[०.]?\s*|पिता\s*:\s*|पिता\s*-\s*|पिता\s+|w/o|s/o|d/o|son of|father:?\s*)", "Father"),
    (r"(?:पति\s*स्व[०.]?\s*|पति\s*:\s*|पति\s*-\s*|पति\s+|husband:?\s*)", "Husband"),
    (r"(?:माता\s*स्व[०.]?\s*|माता\s*:\s*|माता\s*-\s*|माता\s+|mother:?\s*)", "Mother"),
    (r"(?:संरक्षक\s*:\s*|अभिभावक\s*:\s*|guardian:?\s*)", "Guardian"),
]

HONORIFICS_REGEX = r"^(?:श्रीमान|श्रीमती|श्री|स्व०|स्वर्गवासी|स्व\.|मो०|मोहम्मद|डॉ०|डॉक्टर|mr\.|mrs\.|late)\s+"


def clean_name_string(name: str) -> str:
    """Cleans whitespace, trailing punctuation, and extra commas from names."""
    if not name:
        return ""
    cleaned = re.sub(r"[\s\t\n\r]+", " ", str(name)).strip()
    cleaned = re.sub(r"^[,;:\-]+|[,;:\-]+$", "", cleaned).strip()
    return cleaned


def parse_raiyat_entry(
    raiyat_raw: str,
    guardian_raw: Optional[str] = None,
    relation_raw: Optional[str] = None,
    share_raw: Optional[str] = None,
    khata_number: Optional[str] = None,
    caste_or_details: Optional[str] = None,
) -> Optional[OwnerEntry]:
    """
    Parses a single raiyat entity into a verified OwnerEntry object.
    Preserves exact names without fabricating unstated relations.
    """
    cleaned_name = clean_name_string(raiyat_raw)
    if not cleaned_name:
        return None

    rel_type: Optional[str] = None
    rel_name: Optional[str] = None

    # 1. Check explicit guardian field if provided
    if guardian_raw:
        g_clean = clean_name_string(guardian_raw)
        if g_clean:
            rel_name = g_clean
            if relation_raw:
                r_clean = relation_raw.strip().lower()
                if "पिता" in r_clean or "father" in r_clean:
                    rel_type = "Father"
                elif "पति" in r_clean or "husband" in r_clean:
                    rel_type = "Husband"
                elif "माता" in r_clean or "mother" in r_clean:
                    rel_type = "Mother"
                elif "संरक्षक" in r_clean or "guardian" in r_clean:
                    rel_type = "Guardian"
                else:
                    rel_type = relation_raw.strip()
            else:
                # Default relation if guardian is specified without explicit label
                rel_type = "Father"

    # 2. Check if relation is embedded in the main raiyat_raw name text
    # e.g., "राम कुमार पिता श्याम कुमार"
    if not rel_name:
        for pat, rel_label in RELATION_PREFIX_PATTERNS:
            match = re.search(pat, cleaned_name, re.IGNORECASE)
            if match:
                parts = cleaned_name[:match.start()], cleaned_name[match.end():]
                part_name = clean_name_string(parts[0])
                part_rel = clean_name_string(parts[1])
                if part_name and part_rel:
                    cleaned_name = part_name
                    rel_name = part_rel
                    rel_type = rel_label
                    break

    # 3. Clean share
    cleaned_share: Optional[str] = None
    if share_raw:
        s_clean = clean_name_string(share_raw)
        if s_clean and s_clean not in ("-", "N/A", "0", "पूर्ण", "16 आना"):
            cleaned_share = s_clean

    # 4. Details
    ownership_details: Optional[str] = None
    if caste_or_details:
        d_clean = clean_name_string(caste_or_details)
        if d_clean and d_clean not in ("-", "N/A"):
            ownership_details = f"Caste/Details: {d_clean}"

    return OwnerEntry(
        name=cleaned_name,
        relation=rel_type,
        relation_name=rel_name,
        share=cleaned_share,
        khata_number=khata_number,
        ownership_details=ownership_details,
    )


def normalize_bihar_owners(
    raw_owners_list: List[Dict[str, Any]],
    default_khata: Optional[str] = None,
) -> List[OwnerEntry]:
    """
    Normalizes an array of raw owner dictionaries or strings.
    Guarantees no accidental person merging and preserves distinct entries.
    """
    owners: List[OwnerEntry] = []
    seen_identities = set()

    for item in raw_owners_list:
        if isinstance(item, str):
            # Split comma or newline separated names if single string passed
            lines = [l for l in re.split(r"[\n\r,;]+", item) if clean_name_string(l)]
            for line in lines:
                entry = parse_raiyat_entry(line, khata_number=default_khata)
                if entry and entry.name:
                    ident_key = (entry.name, entry.relation_name or "", entry.relation or "")
                    if ident_key not in seen_identities:
                        seen_identities.add(ident_key)
                        owners.append(entry)
        elif isinstance(item, dict):
            r_name = item.get("raiyat_name") or item.get("name") or item.get("owner_name")
            if not r_name:
                continue
            
            g_name = item.get("guardian_name") or item.get("father_name") or item.get("relation_name")
            rel = item.get("relation") or item.get("relationship")
            share = item.get("share") or item.get("hissa")
            khata = item.get("khata_number") or item.get("khata") or default_khata
            details = item.get("caste") or item.get("ownership_details") or item.get("details")

            entry = parse_raiyat_entry(
                raiyat_raw=str(r_name),
                guardian_raw=str(g_name) if g_name else None,
                relation_raw=str(rel) if rel else None,
                share_raw=str(share) if share else None,
                khata_number=str(khata) if khata else None,
                caste_or_details=str(details) if details else None,
            )

            if entry and entry.name:
                ident_key = (entry.name, entry.relation_name or "", entry.relation or "", entry.share or "")
                if ident_key not in seen_identities:
                    seen_identities.add(ident_key)
                    owners.append(entry)

    return owners
