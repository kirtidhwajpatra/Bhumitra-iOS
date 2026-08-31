"""
Bihar Jamabandi Register-II & Khatiyan Parser
Deterministic, fail-closed HTML/DOM and structured payload parser for
Bihar Land Records (biharbhumi.bihar.gov.in & bhuabhilekh.bihar.gov.in).
"""

import re
import logging
from typing import Dict, Any, List, Optional
from bs4 import BeautifulSoup

from models.ror_response import (
    RoRResponse,
    OwnerEntry,
    AssociatedPlot,
    BhulekhLocationIdentity,
    RoRVerification,
    RoRVerificationStatus,
    RoRErrorCode,
    RoRErrorDetail,
)
from .bihar_area_normalizer import normalize_bihar_area, to_standard_digits
from .bihar_owner_normalizer import normalize_bihar_owners, parse_raiyat_entry, clean_name_string
from .bihar_classification import classify_bihar_land_type, is_bihar_government_land

logger = logging.getLogger("bhumitra.scraper.bihar")


class BiharJamabandiParser:
    """
    Deterministic parser for Bihar Jamabandi Register-II pages.
    Converts raw Bihar HTML / Dict structures into normalized RoRResponse models.
    """

    @classmethod
    def parse_html(
        cls,
        html_content: str,
        requested_district: Optional[str] = None,
        requested_anchal: Optional[str] = None,
        requested_village: Optional[str] = None,
        requested_plot: Optional[str] = None,
        requested_khata: Optional[str] = None,
    ) -> RoRResponse:
        """
        Parses raw HTML from biharbhumi ViewJamabandi / ViewJamabandiDetail pages.
        """
        if not html_content or not str(html_content).strip():
            return cls._create_error_response(
                code=RoRErrorCode.PARSE_FAILED,
                message="Empty HTML content received from Bihar portal.",
                district=requested_district,
                tahasil=requested_anchal,
                village=requested_village,
                plot=requested_plot,
            )

        # Check for CAPTCHA challenge in response
        if any(term in html_content for term in ["txtCaptcha", "Security Code", "कृपया कैप्चा दर्ज करें", "Enter Captcha"]):
            return cls._create_error_response(
                code=RoRErrorCode.BHULEKH_TEMPORARILY_UNAVAILABLE,
                message="Bihar portal presented a CAPTCHA challenge.",
                retryable=True,
                district=requested_district,
                tahasil=requested_anchal,
                village=requested_village,
                plot=requested_plot,
            )

        # Check for explicitly empty search results
        if any(term in html_content for term in ["कोई रिकॉर्ड नहीं मिला", "No record found", "रिकॉर्ड उपलब्ध नहीं है"]):
            return cls._create_error_response(
                code=RoRErrorCode.PLOT_NOT_FOUND,
                message="No land records found for the specified search criteria in Bihar Jamabandi Register-II.",
                retryable=False,
                district=requested_district,
                tahasil=requested_anchal,
                village=requested_village,
                plot=requested_plot,
            )

        soup = BeautifulSoup(html_content, "html.parser")
        return cls._parse_soup(
            soup=soup,
            requested_district=requested_district,
            requested_anchal=requested_anchal,
            requested_village=requested_village,
            requested_plot=requested_plot,
            requested_khata=requested_khata,
        )

    @classmethod
    def parse_dict(
        cls,
        payload: Dict[str, Any],
        requested_district: Optional[str] = None,
        requested_anchal: Optional[str] = None,
        requested_village: Optional[str] = None,
        requested_plot: Optional[str] = None,
    ) -> RoRResponse:
        """
        Parses structured dictionary payloads (e.g. from JSON fixtures or AJAX endpoints).
        """
        if not payload or not isinstance(payload, dict):
            return cls._create_error_response(
                code=RoRErrorCode.PARSE_FAILED,
                message="Invalid payload structure.",
                district=requested_district,
                tahasil=requested_anchal,
                village=requested_village,
                plot=requested_plot,
            )

        loc = payload.get("location", {})
        district = (loc.get("district") or requested_district or "").strip().upper()
        anchal = (loc.get("anchal") or loc.get("tahasil") or requested_anchal or "").strip().upper()
        halka = (loc.get("halka") or "").strip()
        village = (loc.get("mauza") or loc.get("village") or requested_village or "").strip()
        thana_no = to_standard_digits(str(loc.get("thana_number") or loc.get("thana_no") or ""))

        reg_ids = payload.get("register_identifiers", {})
        khata_no = to_standard_digits(str(reg_ids.get("khata_number") or reg_ids.get("khata_no") or payload.get("khata_number") or ""))
        khesra_no = to_standard_digits(str(reg_ids.get("khesra_number") or reg_ids.get("khesra_no") or payload.get("plot") or requested_plot or ""))
        jamabandi_no = to_standard_digits(str(reg_ids.get("jamabandi_number") or reg_ids.get("jamabandi_no") or ""))
        bhag = to_standard_digits(str(reg_ids.get("bhag_vartaman") or ""))
        prishth = to_standard_digits(str(reg_ids.get("prishth_vartaman") or ""))

        # Parse Owners
        raw_owners = payload.get("raiyat_details") or payload.get("owners") or []
        owners = normalize_bihar_owners(raw_owners, default_khata=khata_no)

        # Parse Plots Schedule & Area
        plots_schedule = payload.get("land_schedule") or payload.get("plots") or []
        parsed_plots: List[AssociatedPlot] = []
        primary_area_str: Optional[str] = None
        primary_land_type: Optional[str] = None
        all_boundaries: Dict[str, str] = {}

        for p_idx, p_item in enumerate(plots_schedule):
            p_khesra = to_standard_digits(str(p_item.get("khesra_no") or p_item.get("plot_number") or khesra_no or ""))
            p_bigha = p_item.get("area_bigha") or p_item.get("bigha")
            p_katha = p_item.get("area_katha") or p_item.get("katha")
            p_dhur = p_item.get("area_dhur") or p_item.get("dhur")
            p_dec = p_item.get("area_decimal") or p_item.get("decimal")
            p_acre = p_item.get("area_acre") or p_item.get("acre")
            p_raw_area = p_item.get("area") or p_item.get("rakba")

            norm_area, _, area_meta = normalize_bihar_area(
                raw_area=p_raw_area,
                bigha=p_bigha,
                katha=p_katha,
                dhur=p_dhur,
                decimal_val=p_dec,
                acre_val=p_acre,
            )

            raw_type = p_item.get("land_type") or p_item.get("classification")
            norm_type, _ = classify_bihar_land_type(raw_classification=raw_type)

            lagan_dict = p_item.get("lagan_breakdown", {})
            total_tax = lagan_dict.get("total_annual_demand") or p_item.get("rent_cess") or p_item.get("lagan")
            tax_str = f"Rs. {total_tax}" if total_tax else None

            remarks_parts = []
            if area_meta.get("traditional_repr"):
                remarks_parts.append(area_meta["traditional_repr"])
            if p_item.get("remarks"):
                remarks_parts.append(str(p_item["remarks"]))
            rem_str = "; ".join(remarks_parts) if remarks_parts else None

            assoc_plot = AssociatedPlot(
                plot_number=p_khesra or str(p_idx + 1),
                area=norm_area,
                land_type=norm_type,
                rent_cess=tax_str,
                remarks=rem_str,
            )
            parsed_plots.append(assoc_plot)

            if p_idx == 0 or p_khesra == khesra_no:
                primary_area_str = norm_area
                primary_land_type = norm_type
                bounds = p_item.get("boundaries", {})
                if bounds:
                    all_boundaries = {f"boundary_{k}": str(v) for k, v in bounds.items()}

        # Check Government Land Status
        first_owner_name = owners[0].name if owners else ""
        is_govt = is_bihar_government_land(
            raiyat_name=first_owner_name,
            land_type=primary_land_type,
            remarks=str(payload.get("mutation_history", "")),
        )

        if is_govt and primary_land_type and "government" not in primary_land_type.lower():
            primary_land_type = f"Government ({primary_land_type})"

        raw_fields = {
            "source_state": "BIHAR",
            "jamabandi_no": jamabandi_no,
            "vol_page_no": f"Vol {bhag}, Page {prishth}" if (bhag or prishth) else "",
            "thana_no": thana_no,
            "halka": halka,
            "is_government_land": str(is_govt).lower(),
            **all_boundaries,
        }

        mut = payload.get("mutation_history")
        if isinstance(mut, dict):
            raw_fields["mutation_case_no"] = str(mut.get("case_number") or "")
            raw_fields["mutation_status"] = str(mut.get("status") or "")

        verification = RoRVerification(
            status=RoRVerificationStatus.VERIFIED if (khesra_no or khata_no) else RoRVerificationStatus.INSUFFICIENT_DATA,
            requested_district=requested_district or district,
            requested_tahasil=requested_anchal or anchal,
            requested_village=requested_village or village,
            requested_plot=requested_plot or khesra_no or "UNKNOWN",
            returned_district=district,
            returned_tahasil=anchal,
            returned_village=village,
            returned_plot=khesra_no or requested_plot,
            location_match=bool(district and anchal),
            plot_match=bool(khesra_no and requested_plot and khesra_no == requested_plot),
            details="Bihar Jamabandi Register-II record verified.",
        )

        loc_identity = BhulekhLocationIdentity(
            district_id="BIHAR_" + district,
            tahasil_id="BIHAR_" + anchal,
            village_id="BIHAR_" + (thana_no or village),
            district_name=district,
            tahasil_name=anchal,
            village_name=village,
        )

        return RoRResponse(
            success=True,
            plot=khesra_no or requested_plot or "0",
            village=village or requested_village or "",
            district=district or requested_district or "",
            tahasil=anchal or requested_anchal or "",
            khata_number=khata_no or None,
            area=primary_area_str,
            land_type=primary_land_type,
            owners=owners,
            plots=parsed_plots,
            raw_fields=raw_fields,
            location_identity=loc_identity,
            verification=verification,
            source="biharbhumi.bihar.gov.in",
            cached=False,
        )

    @classmethod
    def _parse_soup(
        cls,
        soup: BeautifulSoup,
        requested_district: Optional[str] = None,
        requested_anchal: Optional[str] = None,
        requested_village: Optional[str] = None,
        requested_plot: Optional[str] = None,
        requested_khata: Optional[str] = None,
    ) -> RoRResponse:
        """
        Extracts tabular elements and key-value label pairs from Jamabandi Register-II HTML.
        """
        # 1. Extract Header & Location Meta
        def find_field_text(keywords: List[str]) -> Optional[str]:
            for kw in keywords:
                for tag in soup.find_all(["td", "div", "p", "span", "label", "b", "strong"]):
                    txt = tag.get_text(" ", strip=True)
                    if kw in txt:
                        # If tag itself contains colon with value (e.g. "जिला: PATNA")
                        if ":" in txt:
                            parts = txt.split(":", 1)
                            val = parts[1].strip()
                            if val and val not in ("-", ":", ""):
                                return val
                        # Otherwise check next sibling td/span (skip th to prevent scanning table headers)
                        next_sib = tag.find_next_sibling(["td", "span", "div"])
                        if next_sib and next_sib.name != "th":
                            val = next_sib.get_text(" ", strip=True)
                            if val and val not in ("-", ":", "") and not any(k in val for k in ["जिला", "अंचल", "मौजा", "खाता", "खेसरा", "रकबा"]):
                                return val
            return None

        district = find_field_text(["जिला", "District"]) or requested_district or ""
        anchal = find_field_text(["अंचल", "Anchal", "प्रखंड", "Circle"]) or requested_anchal or ""
        halka = find_field_text(["हल्का", "Halka"]) or ""
        village = find_field_text(["मौजा", "Mauza", "ग्राम", "Village"]) or requested_village or ""
        thana_no = find_field_text(["थाना", "Thana", "थाना नं"]) or ""
        khata_no = find_field_text(["खाता संख्या", "खाता सं", "Khata"]) or requested_khata or ""
        khesra_no = find_field_text(["खेसरा संख्या", "खेसरा सं", "Plot", "Khesra"]) or requested_plot or ""
        jamabandi_no = find_field_text(["जमाबंदी संख्या", "जमाबंदी सं", "Jamabandi"]) or ""
        bhag = find_field_text(["भाग वर्तमान", "भाग"]) or ""
        prishth = find_field_text(["पृष्ठ संख्या", "पृष्ठ वर्तमान", "पृष्ठ"]) or ""

        # Normalize digits
        district = clean_name_string(district).upper()
        anchal = clean_name_string(anchal).upper()
        village = clean_name_string(village)
        thana_no = to_standard_digits(thana_no)
        khata_no = to_standard_digits(khata_no)
        khesra_no = to_standard_digits(khesra_no)
        jamabandi_no = to_standard_digits(jamabandi_no)

        # 2. Extract Owners Table
        raw_owners_list: List[Dict[str, Any]] = []
        owner_table = None

        for table in soup.find_all("table"):
            table_text = table.get_text()
            if "रैयत" in table_text or "Raiyat" in table_text or "खातेदार" in table_text:
                owner_table = table
                break

        if owner_table:
            for row in owner_table.find_all("tr")[1:]:  # skip header
                cols = [c.get_text(strip=True) for c in row.find_all(["td", "th"])]
                if len(cols) >= 2:
                    r_name = cols[1] if len(cols) > 1 else cols[0]
                    g_name = cols[2] if len(cols) > 2 else None
                    caste = cols[3] if len(cols) > 3 else None
                    rel = None
                    if g_name and any(p in g_name for p in ["पिता", "पति", "माता"]):
                        rel = "Father" if "पिता" in g_name else "Husband"
                    raw_owners_list.append({
                        "raiyat_name": r_name,
                        "guardian_name": g_name,
                        "relation": rel,
                        "caste": caste,
                        "khata_number": khata_no,
                    })

        # Fallback: Check simple label if no table found
        if not raw_owners_list:
            single_raiyat = find_field_text(["रैयत का नाम", "रैयत", "Raiyat Name", "Owner"])
            single_guard = find_field_text(["पिता/पति का नाम", "अभिभावक", "Father/Husband"])
            if single_raiyat:
                raw_owners_list.append({
                    "raiyat_name": single_raiyat,
                    "guardian_name": single_guard,
                    "khata_number": khata_no,
                })

        owners = normalize_bihar_owners(raw_owners_list, default_khata=khata_no)

        # 3. Extract Plot Schedule Table
        plots_schedule: List[AssociatedPlot] = []
        plot_table = None

        for table in soup.find_all("table"):
            table_text = table.get_text()
            if ("खेसरा" in table_text or "Plot" in table_text) and ("रकबा" in table_text or "Area" in table_text):
                plot_table = table
                break

        primary_area: Optional[str] = None
        primary_land_type: Optional[str] = None
        boundaries_dict: Dict[str, str] = {}

        if plot_table:
            rows = plot_table.find_all("tr")
            header_cols: List[str] = []
            data_rows = rows
            if rows:
                first_cols = [c.get_text(strip=True) for c in rows[0].find_all(["th", "td"])]
                if any(any(k in c for k in ["खेसरा", "रकबा", "Plot", "Area", "किस्म"]) for c in first_cols):
                    header_cols = first_cols
                    data_rows = rows[1:]

            khesra_idx = -1
            rakba_idx = -1
            type_idx = -1
            lagan_idx = -1

            for idx, h in enumerate(header_cols):
                if any(k in h for k in ["खेसरा", "Plot"]) and khesra_idx == -1:
                    khesra_idx = idx
                elif any(k in h for k in ["रकबा", "Area"]) and rakba_idx == -1:
                    rakba_idx = idx
                elif any(k in h for k in ["किस्म", "प्रकार", "Type", "Classification"]) and type_idx == -1:
                    type_idx = idx
                elif any(k in h for k in ["लगान", "Rent", "Tax"]) and lagan_idx == -1:
                    lagan_idx = idx

            for row in data_rows:
                cols = [c.get_text(strip=True) for c in row.find_all(["td", "th"])]
                if not cols:
                    continue

                if khesra_idx >= 0 and khesra_idx < len(cols):
                    row_khesra = to_standard_digits(cols[khesra_idx])
                else:
                    row_khesra = to_standard_digits(cols[2]) if len(cols) > 2 else khesra_no

                if rakba_idx >= 0 and rakba_idx < len(cols):
                    row_rakba = cols[rakba_idx]
                else:
                    row_rakba = cols[3] if len(cols) > 3 else (cols[1] if len(cols) > 1 else "")

                if type_idx >= 0 and type_idx < len(cols):
                    row_type = cols[type_idx]
                else:
                    row_type = cols[4] if len(cols) > 4 else (cols[2] if len(cols) > 2 else "")

                if lagan_idx >= 0 and lagan_idx < len(cols):
                    row_lagan = cols[lagan_idx]
                else:
                    row_lagan = cols[5] if len(cols) > 5 else ""

                norm_a, _, meta_a = normalize_bihar_area(raw_area=row_rakba)
                norm_t, _ = classify_bihar_land_type(raw_classification=row_type)

                assoc = AssociatedPlot(
                    plot_number=row_khesra or khesra_no or "1",
                    area=norm_a,
                    land_type=norm_t,
                    rent_cess=f"Rs. {row_lagan}" if row_lagan and row_lagan != "-" else None,
                    remarks=meta_a.get("traditional_repr"),
                )
                plots_schedule.append(assoc)
                if not primary_area:
                    primary_area = norm_a
                    primary_land_type = norm_t

        # If khesra_no was not found in location summary table, extract from plot schedule
        if (not khesra_no or khesra_no in ("0", "UNKNOWN")) and plots_schedule:
            khesra_no = plots_schedule[0].plot_number

        # Fallback if no plot table: extract bare area field
        if not primary_area:
            bare_area = find_field_text(["कुल रकबा", "रकबा", "Area", "डिसमिल", "एकड़"])
            if bare_area:
                primary_area, _, _ = normalize_bihar_area(raw_area=bare_area)

        if not primary_land_type:
            bare_type = find_field_text(["जमीन का प्रकार", "किस्म", "Land Type", "Classification"])
            primary_land_type, _ = classify_bihar_land_type(raw_classification=bare_type)

        # Check government land status strictly from owner and land classification
        first_owner_name = owners[0].name if owners else ""
        is_govt = is_bihar_government_land(
            raiyat_name=first_owner_name,
            land_type=primary_land_type,
            khata_type=find_field_text(["खाता का प्रकार", "खाता किस्म"]),
        )

        if is_govt and primary_land_type and "government" not in primary_land_type.lower():
            primary_land_type = f"Government ({primary_land_type})"

        raw_fields = {
            "source_state": "BIHAR",
            "jamabandi_no": jamabandi_no,
            "vol_page_no": f"Vol {bhag}, Page {prishth}" if (bhag or prishth) else "",
            "thana_no": thana_no,
            "halka": halka,
            "is_government_land": str(is_govt).lower(),
            **boundaries_dict,
        }

        # Verification check
        verification_status = RoRVerificationStatus.VERIFIED if (khesra_no or khata_no or owners) else RoRVerificationStatus.INSUFFICIENT_DATA
        plot_matched = bool(khesra_no and requested_plot and khesra_no == requested_plot)

        verification = RoRVerification(
            status=verification_status,
            requested_district=requested_district or district,
            requested_tahasil=requested_anchal or anchal,
            requested_village=requested_village or village,
            requested_plot=requested_plot or khesra_no or "UNKNOWN",
            returned_district=district,
            returned_tahasil=anchal,
            returned_village=village,
            returned_plot=khesra_no or requested_plot,
            location_match=bool(district and anchal),
            plot_match=plot_matched,
            details="Bihar Jamabandi Register-II HTML parsed successfully.",
        )

        loc_identity = BhulekhLocationIdentity(
            district_id="BIHAR_" + district,
            tahasil_id="BIHAR_" + anchal,
            village_id="BIHAR_" + (thana_no or village),
            district_name=district,
            tahasil_name=anchal,
            village_name=village,
        )

        return RoRResponse(
            success=True,
            plot=khesra_no or requested_plot or "0",
            village=village or requested_village or "",
            district=district or requested_district or "",
            tahasil=anchal or requested_anchal or "",
            khata_number=khata_no or None,
            area=primary_area,
            land_type=primary_land_type,
            owners=owners,
            plots=plots_schedule,
            raw_fields=raw_fields,
            location_identity=loc_identity,
            verification=verification,
            source="biharbhumi.bihar.gov.in",
            cached=False,
        )

    @staticmethod
    def _create_error_response(
        code: RoRErrorCode,
        message: str,
        retryable: bool = False,
        district: Optional[str] = None,
        tahasil: Optional[str] = None,
        village: Optional[str] = None,
        plot: Optional[str] = None,
    ) -> RoRResponse:
        """Helper to construct safe, fail-closed error responses."""
        return RoRResponse(
            success=False,
            plot=plot or "0",
            village=village or "",
            district=district or "",
            tahasil=tahasil or "",
            owners=[],
            plots=[],
            error=RoRErrorDetail(
                code=code,
                message=message,
                retryable=retryable,
            ),
            verification=RoRVerification(
                status=RoRVerificationStatus.SOURCE_ERROR,
                requested_district=district or "",
                requested_tahasil=tahasil or "",
                requested_village=village or "",
                requested_plot=plot or "0",
                location_match=False,
                plot_match=False,
                details=message,
            ),
            source="biharbhumi.bihar.gov.in",
            cached=False,
        )
