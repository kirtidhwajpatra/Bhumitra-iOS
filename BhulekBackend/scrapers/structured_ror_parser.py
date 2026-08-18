"""
Bhulekh Structured RoR Parser (Front & Back Page Engine)
Extracts individual Raiyats, fractional shares, and all associated plots from verified HTML tables
without collapsing multiple joint owners or losing distinct sub-plots.
"""
import re
import logging
from bs4 import BeautifulSoup
from typing import List, Dict, Optional
from models.ror_response import (
    RoRResponse,
    OwnerEntry,
    AssociatedPlot,
    KhataSearchResult,
    BhulekhLocationIdentity,
    RoRVerificationStatus,
)

logger = logging.getLogger("bhumitra.parser")

RELATION_PREFIXES = [
    "S/O", "S/O.", "W/O", "W/O.", "D/O", "D/O.", "C/O", "C/O.",
    "FATHER:", "FATHER-", "HUSBAND:", "HUSBAND-", "GUARDIAN:", "GUARDIAN-",
    "ପିତା-", "ସ୍ୱାମୀ-", "ମାତା-", "ଅଭିଭାବକ-",
]

NON_OWNER_QUALIFIERS = [
    "DR.", "DR", "MAJOR", "COL.", "COLONEL", "PROF.", "PROFESSOR", "ADVOCATE",
    "M.B.B.S.", "MBBS", "B.TECH", "BTECH", "M.A.", "M.SC", "PH.D"
]


HEADER_NOISE = [
    "SL NO", "SL. NO.", "SL.NO.", "SLNO", "NAME", "SHARE", "FATHER NAME", "RELATION", "କ୍ରମିକ ନଂ", "ନାମ"
]


def clean_owner_name(raw_name: str) -> Optional[str]:
    """Cleans owner string, separating relations while preserving titles."""
    if not raw_name:
        return None
        
    cleaned = " ".join(raw_name.replace("\r", " ").replace("\n", " ").split()).strip()
    if not cleaned or cleaned in ("-", "N/A", "null", "None") or cleaned.upper() in HEADER_NOISE:
        return None

    # Filter out numeric digits / serial numbers
    if cleaned.isdigit() or re.match(r'^\d+$', cleaned):
        return None

    # Strip trailing relations (e.g. "Ramesh Sahu S/O Suresh Sahu" -> "Ramesh Sahu")
    # or reject if entire line is just a relation (e.g. "S/O Late Bipin Sahu")
    for prefix in RELATION_PREFIXES:
        if prefix in cleaned.upper():
            idx = cleaned.upper().find(prefix)
            if idx == 0:
                return None
            elif idx > 0:
                cleaned = cleaned[:idx].strip()

    # Remove any trailing commas or hyphens
    cleaned = cleaned.rstrip(",- :").strip()
    return cleaned if len(cleaned) >= 2 else None


def split_cell_names(raw_text: str) -> List[str]:
    """Splits multiple names within a single table cell."""
    lines = [l.strip() for l in raw_text.split("\n") if l.strip()]
    results = []
    
    for line in lines:
        if "," in line:
            parts = [p.strip() for p in line.split(",") if p.strip()]
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


def parse_associated_plots(soup: BeautifulSoup) -> List[AssociatedPlot]:
    """Extracts all associated plots from #gvRorBack GridView table or plain table rows."""
    plots: List[AssociatedPlot] = []
    seen_plots = set()

    plot_rows = soup.find_all("tr")
    for row in plot_rows:
        plot_el = row.find(id=lambda x: x and "lblPlotNo" in x)
        if plot_el:
            p_no = plot_el.get_text(strip=True)
            if p_no and p_no not in seen_plots:
                seen_plots.add(p_no)
                type_el = row.find(id=lambda x: x and ("lbllType" in x or "lblKisama" in x))
                land_type = type_el.get_text(strip=True) if type_el else None
                acre_el = row.find(id=lambda x: x and "lblAcre" in x)
                dec_el = row.find(id=lambda x: x and "lblDecimil" in x)
                area = None
                if acre_el or dec_el:
                    a = acre_el.get_text(strip=True) if acre_el else "0"
                    d = dec_el.get_text(strip=True) if dec_el else "0"
                    area = f"{a} Acre {d} Decimal".strip()

                plots.append(AssociatedPlot(plot_number=p_no, area=area, land_type=land_type))

    # Also parse from gvRorBack table cells
    back_table = soup.find("table", id=lambda x: x and "gvRorBack" in str(x))
    if back_table:
        for row in back_table.find_all("tr"):
            tds = row.find_all("td")
            if len(tds) >= 4:
                first_col = tds[0].get_text(strip=True)
                m = re.match(r'^(\d+(?:/\d+)?[A-Za-z]?)(.*)$', first_col)
                if m:
                    p_no = m.group(1).strip()
                    if p_no and p_no not in seen_plots:
                        seen_plots.add(p_no)
                        land_type = tds[1].get_text(strip=True) if len(tds) > 1 else None
                        acre = tds[3].get_text(strip=True) if len(tds) > 3 else "0"
                        dec = tds[4].get_text(strip=True) if len(tds) > 4 else "0"
                        area = f"{acre} Acre {dec} Decimal".strip() if (acre or dec) else None
                        plots.append(AssociatedPlot(plot_number=p_no, area=area, land_type=land_type))

    return plots


def parse_structured_ror(
    html: str,
    district: str,
    tahasil: str,
    village: str,
    plot: str,
    location_identity: Optional[BhulekhLocationIdentity] = None
) -> RoRResponse:
    """Executes structured extraction against verified Bhulekh RoR DOM."""
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

    if not khata_number:
        # Fallback to regex from page text (e.g. "ଖତିୟାନର କ୍ରମିକ ନଂ : 112" or "1) ଖତିୟାନର କ୍ରମିକ ନମ୍ବର")
        page_text = soup.get_text()
        k_match = re.search(r'(?:ଖତିୟାନର\s*କ୍ରମିକ\s*ନ[ଂମ୍ବର]+|Khata\s*No|Khatiyan\s*No)\s*[:\-]?\s*(\d+(?:/\d+)?)', page_text)
        if k_match:
            khata_number = k_match.group(1).strip()

    # 3. Extract Landlord
    landlord = None
    landlord_el = soup.find(id=lambda x: x and "lblLandlordName" in x)
    if landlord_el:
        txt = landlord_el.get_text(strip=True)
        if txt and txt not in ("N/A", "-"):
            landlord = txt

    if not landlord:
        page_text = soup.get_text()
        l_match = re.search(r'(?:ଜମିଦାରଙ୍କ\s*ନାମ[^\n]*)\n([^\n]+)', page_text)
        if l_match:
            landlord = l_match.group(1).strip()

    # 4. Extract Raiyat / Owners from #gvfront or Odia table cells
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

    if not owners:
        # Check for Odia tenant cell "2) ପ୍ରଜାର ନାମ, ପିତାର ନାମ, ଜାତି ଓ ବାସସ୍ଥାନ"
        page_text = soup.get_text()
        praja_m = re.search(r'2\)\s*ପ୍ରଜାର\s*ନାମ[^\n]*\n([^\n]+)', page_text)
        if praja_m:
            praja_text = praja_m.group(1).strip()
            # Extract name and father name: e.g. "ଉଜ୍ଵଳ ଚନ୍ଦ୍ର ସାହୁ ପି:ହରିହର ସାହୁ ଜା: ତେଲି ବା: ନିଜଗାଁ"
            name_parts = re.split(r'\s+ପି:|\s+ପିତା:|\s+ସ୍ଵାମୀ:|\s+ଜା:|\s+ବା:', praja_text)
            primary_name = name_parts[0].strip() if name_parts else praja_text
            father_name = name_parts[1].strip() if len(name_parts) > 1 else None
            owners.append(OwnerEntry(
                name=primary_name,
                father_husband_name=father_name,
                relation="Father" if father_name else None,
                khata_number=khata_number
            ))

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

    # 5. Extract All Associated Plots from #gvRorBack (Back Page)
    all_plots = parse_associated_plots(soup)
    target_plot_record = next((p for p in all_plots if p.plot_number == clean_target_plot), None)

    land_type = target_plot_record.land_type if target_plot_record else None
    area = target_plot_record.area if target_plot_record else None

    # 6. Government Land Handling
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
        plots=all_plots,
        raw_fields={"landlord": landlord} if landlord else {},
        location_identity=location_identity,
        verification=verification,
        source="bhulekh.ori.nic.in",
        cached=False,
    )


def parse_structured_khata_ror(
    html: str,
    district: str,
    tahasil: str,
    village: str,
    requested_khata: str,
    location_identity: Optional[BhulekhLocationIdentity] = None
) -> KhataSearchResult:
    """Parses a multi-plot Khata record verifying that the returned Khata matches the requested one."""
    soup = BeautifulSoup(html, "lxml")
    clean_k = requested_khata.strip()

    # Extract confirmation Khata
    returned_khata = None
    khata_el = soup.find(id=lambda x: x and "lblKhatiyanslNo" in x)
    if khata_el:
        returned_khata = khata_el.get_text(strip=True)

    if not returned_khata or returned_khata != clean_k:
        raise ValueError(
            f"Khata mismatch: Requested Khata '{clean_k}', but portal returned Khata '{returned_khata or 'None'}'."
        )

    # Parse owners
    owners: List[OwnerEntry] = []
    gvfront = soup.find(id=lambda x: x and "gvfront" in x)
    if gvfront:
        for row in gvfront.find_all("tr"):
            name_el = row.find(id=lambda x: x and "lblName" in x)
            share_el = row.find(id=lambda x: x and "lblShare" in x)
            if name_el:
                raw_name = name_el.get_text(strip=True)
                share = share_el.get_text(strip=True) if share_el else None
                if share in ("N/A", "-", ""):
                    share = None
                for sn in split_cell_names(raw_name):
                    c_sn = clean_owner_name(sn)
                    if c_sn:
                        owners.append(OwnerEntry(name=c_sn, share=share, khata_number=clean_k))

    # Parse all associated plots
    all_plots = parse_associated_plots(soup)

    from scrapers.bhulekh_scraper import verify_ror_result
    # Build verification for first plot if available
    first_p = all_plots[0].plot_number if all_plots else "1"
    verification = verify_ror_result(soup, district, tahasil, village, first_p)

    loc = location_identity or BhulekhLocationIdentity(
        district_id="0",
        tahasil_id="0",
        village_id="0",
        district_name=district,
        tahasil_name=tahasil,
        village_name=village,
    )

    return KhataSearchResult(
        success=True,
        verified_location=loc,
        exact_khata_number=clean_k,
        owners=owners,
        plots=all_plots,
        total_plots_count=len(all_plots),
        total_area=None,
        official_identifiers={"khata_number": clean_k},
        verification=verification,
        source="bhulekh.ori.nic.in",
        cached=False,
    )
