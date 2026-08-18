"""
Bhulekh Odisha Structured RoR Parser
Extracts Khata, Raiyat owners, shares, plot Kisama, and acre/decimal measurements
using exact ASP.NET element IDs, GridView table semantics, and strict relation separation.
"""

from typing import List, Dict, Any, Optional
import re
import logging
from bs4 import BeautifulSoup
from models.ror_response import (
    RoRResponse, OwnerEntry, BhulekhLocationIdentity,
    RoRVerification, RoRVerificationStatus
)

logger = logging.getLogger(__name__)


RELATION_PREFIXES = [
    r"^S/O\s+", r"^W/O\s+", r"^D/O\s+", r"^C/O\s+",
    r"^GUARDIAN\s*:\s*", r"^FATHER\s*:\s*", r"^HUSBAND\s*:\s*",
    r"^MOTHER\s*:\s*",
    r"^ପିତା\s*:\s*", r"^ସ୍ୱାମୀ\s*:\s*", r"^ମାତା\s*:\s*",
    r"^ପିତା-\s*", r"^ସ୍ୱାମୀ-\s*", r"^ମାତା-\s*",
]

NON_OWNER_QUALIFIERS = {
    "M.B.B.S.", "MBBS", "M.D.", "MD", "B.A.", "B.SC.", "B.COM.", "LL.B.", "LLB",
    "ADVOCATE", "PH.D.", "PHD", "ENGINEER", "IAS", "OAS", "IPS",
}


def clean_owner_name(raw_name: str) -> Optional[str]:
    """
    Cleans raw name text while strictly removing relation prefixes, guardian titles, and blank entries.
    Preserves Odia script, initials (e.g. 'P. K.'), and titles.
    """
    if not raw_name:
        return None
    s = raw_name.strip()
    if s in ("N/A", "-", "", "<null>", "null", "SL NO", "Sl.No."):
        return None
    if s.isdigit():
        return None

    # If the string starts with a relation/guardian prefix, it is relation metadata, NOT an owner
    for pattern in RELATION_PREFIXES:
        if re.search(pattern, s, re.IGNORECASE):
            return None

    if s.upper() in NON_OWNER_QUALIFIERS:
        return None

    return s


def split_cell_names(raw_text: str) -> List[str]:
    """
    Splits multi-name cell text by newlines and commas while preserving educational titles (e.g. M.B.B.S.).
    """
    lines = [l.strip() for l in raw_text.split("\n") if l.strip()]
    results = []
    
    for line in lines:
        if "," in line:
            parts = [p.strip() for p in line.split(",") if p.strip()]
            # Re-assemble if trailing part is a qualification (e.g. "Dr. P. K. Patnaik", "M.B.B.S.")
            combined: List[str] = []
            for part in parts:
                if part.upper() in NON_OWNER_QUALIFIERS and combined:
                    combined[-1] = f"{combined[-1]}, {part}"
                else:
                    combined.append(part)
            results.extend(combined)
        else:
            results.append(line)
            
    return results


def parse_structured_ror(
    html: str,
    district: str,
    tahasil: str,
    village: str,
    plot: str,
    location_identity: Optional[BhulekhLocationIdentity] = None
) -> RoRResponse:
    """
    Executes structured extraction against verified Bhulekh RoR DOM.
    """
    from scrapers.bhulekh_scraper import verify_ror_result

    soup = BeautifulSoup(html, "lxml")
    clean_target_plot = plot.strip()

    # 1. Run Verification Layer (Fail-closed on mismatch)
    verification = verify_ror_result(soup, district, tahasil, village, clean_target_plot)
    if verification.status != RoRVerificationStatus.VERIFIED:
        logger.error(f"RoR Verification Failed: status={verification.status}, details={verification.details}")
        raise ValueError(f"Unable to verify this parcel from the official land record: {verification.details}")

    # 2. Extract Khata Number
    khata_number = None
    khata_el = soup.find(id=lambda x: x and "lblKhatiyanslNo" in x)
    if khata_el:
        txt = khata_el.get_text(strip=True)
        if txt and txt not in ("N/A", "-"):
            khata_number = txt

    # 3. Extract Landlord (State Government / Khasmahal)
    landlord = None
    landlord_el = soup.find(id=lambda x: x and "lblLandlordName" in x)
    if landlord_el:
        txt = landlord_el.get_text(strip=True)
        if txt and txt not in ("N/A", "-"):
            landlord = txt

    # 4. Extract Raiyat / Owners from GridView Front (#gvfront)
    owners: List[OwnerEntry] = []
    gvfront = soup.find(id=lambda x: x and "gvfront" in x)

    if gvfront:
        rows = gvfront.find_all("tr")
        for row in rows:
            name_el = row.find(id=lambda x: x and "lblName" in x)
            share_el = row.find(id=lambda x: x and "lblShare" in x)
            
            if name_el:
                raw_name = name_el.get_text(strip=True)
                share = share_el.get_text(strip=True) if share_el else None
                if share in ("N/A", "-", ""):
                    share = None
                    
                sub_names = split_cell_names(raw_name)
                for sn in sub_names:
                    c_sn = clean_owner_name(sn)
                    if c_sn:
                        owners.append(OwnerEntry(name=c_sn, share=share, khata_number=khata_number))

    # Fallback to standalone lblName if gvfront table was not rendered
    if not owners:
        owner_el = soup.find(id=lambda x: x and "lblName" in x)
        if owner_el:
            owner_text = owner_el.get_text(strip=True)
            if owner_text:
                sub_names = split_cell_names(owner_text)
                for sn in sub_names:
                    cleaned = clean_owner_name(sn)
                    if cleaned:
                        owners.append(OwnerEntry(name=cleaned, khata_number=khata_number))

    # 5. Extract Plot-Specific Details from #gvRorBack (Back Page)
    land_type = None
    area = None

    plot_rows = soup.find_all("tr")
    for row in plot_rows:
        plot_el = row.find(id=lambda x: x and "lblPlotNo" in x)
        if plot_el and plot_el.get_text(strip=True) == clean_target_plot:
            type_el = row.find(id=lambda x: x and "lbllType" in x) or row.find(id=lambda x: x and "lblKisama" in x)
            if type_el:
                land_type = type_el.get_text(strip=True)

            acre_el = row.find(id=lambda x: x and "lblAcre" in x)
            dec_el = row.find(id=lambda x: x and "lblDecimil" in x)
            if acre_el or dec_el:
                a = acre_el.get_text(strip=True) if acre_el else "0"
                d = dec_el.get_text(strip=True) if dec_el else "0"
                area = f"{a} Acre {d} Decimal".strip()
            break

    # 6. Government Land Handling
    # If no Raiyat owner exists, but landlord is official Government of Odisha, set landlord as owner
    if not owners and landlord:
        owners.append(OwnerEntry(name=landlord, share="1.000", khata_number=khata_number))

    if not owners and not khata_number:
        raise ValueError("No verified owner or khatiyan records found in official portal response.")

    return RoRResponse(
        success=True,
        plot=verification.returned_plot or clean_target_plot,
        village=verification.returned_village or village,
        district=verification.returned_district or district,
        tahasil=verification.returned_tahasil or tahasil,
        khata_number=khata_number,
        area=area,
        land_type=land_type,
        owners=owners,
        raw_fields={"landlord": landlord} if landlord else {},
        location_identity=location_identity,
        verification=verification,
        source="bhulekh.ori.nic.in",
        cached=False,
    )
