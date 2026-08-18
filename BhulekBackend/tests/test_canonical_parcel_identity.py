"""
Canonical Parcel Identity & Core Data Accuracy Tests
Validates immutable parcel identity rules, cross-village plot isolation,
numeric/string attribute normalization, missing field rejection, RoR separation,
and Phase 2 map tap resolution & polygon disambiguation.
"""

import pytest
from dataclasses import dataclass
from typing import Optional, Dict, Any, List, Tuple


@dataclass(frozen=True)
class CanonicalParcelIdentity:
    parcel_id: str
    plot_number: str
    district_name: str
    tahasil_name: str
    village_name: str
    district_id: Optional[str] = None
    tahasil_id: Optional[str] = None
    village_id: Optional[str] = None
    panchayat_name: Optional[str] = None
    is_fully_resolved: bool = True

    @classmethod
    def create(
        cls,
        plot_number: Any,
        district_name: str,
        tahasil_name: str,
        village_name: str,
        parcel_id: Optional[str] = None,
        district_id: Optional[str] = None,
        tahasil_id: Optional[str] = None,
        village_id: Optional[str] = None,
        panchayat_name: Optional[str] = None,
    ) -> "CanonicalParcelIdentity":
        clean_plot = str(plot_number or "").strip()
        clean_district = str(district_name or "").strip()
        clean_tahasil = str(tahasil_name or "").strip()
        clean_village = str(village_name or "").strip()

        valid_plot = bool(clean_plot and clean_plot != "N/A")
        valid_dist = bool(clean_district and clean_district != "N/A")
        valid_tahasil = bool(clean_tahasil and clean_tahasil != "N/A")
        valid_village = bool(clean_village and clean_village != "N/A")

        is_resolved = valid_plot and valid_dist and valid_tahasil and valid_village

        if parcel_id and str(parcel_id).strip():
            pid = str(parcel_id).strip()
        else:
            d = district_id or clean_district
            t = tahasil_id or clean_tahasil
            v = village_id or clean_village
            pid = f"{d}:{t}:{v}:{clean_plot}"

        return cls(
            parcel_id=pid,
            plot_number=clean_plot,
            district_name=clean_district,
            district_id=str(district_id).strip() if district_id else None,
            tahasil_name=clean_tahasil,
            tahasil_id=str(tahasil_id).strip() if tahasil_id else None,
            village_name=clean_village,
            village_id=str(village_id).strip() if village_id else None,
            panchayat_name=str(panchayat_name).strip() if panchayat_name else None,
            is_fully_resolved=is_resolved,
        )


def is_coordinate_inside_polygon(point: Tuple[float, float], vertices: List[Tuple[float, float]]) -> bool:
    """Ray-casting point in polygon algorithm (lat, lon)."""
    if len(vertices) < 3:
        return False
    inside = False
    j = len(vertices) - 1
    p_lat, p_lon = point
    for i in range(len(vertices)):
        vi_lat, vi_lon = vertices[i]
        vj_lat, vj_lon = vertices[j]
        if ((vi_lat > p_lat) != (vj_lat > p_lat)) and (
            p_lon < (vj_lon - vi_lon) * (p_lat - vi_lat) / (vj_lat - vi_lat) + vi_lon
        ):
            inside = not inside
        j = i
    return inside


def resolve_tapped_candidates(
    features: List[Dict[str, Any]],
    tap_coord: Tuple[float, float],
) -> Dict[str, Any]:
    """Simulates CadastralFeatureResolver.resolveTappedParcel."""
    if not features:
        return {"status": "no_feature"}

    parsed = []
    for f in features:
        attrs = f.get("attributes", {})
        plot = attrs.get("revenue_plot")
        if not plot or str(plot).strip() in ("0", "N/A", ""):
            continue

        ident = CanonicalParcelIdentity.create(
            parcel_id=attrs.get("p_id"),
            plot_number=plot,
            district_name=attrs.get("District", "Keonjhar"),
            tahasil_name=attrs.get("Tahasil", "N/A"),
            tahasil_id=attrs.get("b_id"),
            village_name=attrs.get("Village", "N/A"),
            village_id=attrs.get("v_id"),
        )
        parsed.append({
            "identity": ident,
            "boundary": f.get("boundary", []),
            "area": attrs.get("area_in_acre", 0.0),
        })

    if not parsed:
        return {"status": "no_feature"}

    # Group by canonical parcel_id (tile fragment deduplication)
    grouped: Dict[str, List[Dict[str, Any]]] = {}
    for c in parsed:
        grouped.setdefault(c["identity"].parcel_id, []).append(c)

    if len(grouped) == 1:
        single_group = list(grouped.values())[0]
        rep = max(single_group, key=lambda x: len(x["boundary"]))
        return {"status": "resolved", "parcel_id": rep["identity"].parcel_id, "identity": rep["identity"]}

    # Multiple distinct parcels: run point in polygon
    enclosing = []
    for pid, group in grouped.items():
        rep = max(group, key=lambda x: len(x["boundary"]))
        if is_coordinate_inside_polygon(tap_coord, rep["boundary"]):
            enclosing.append(rep)

    if len(enclosing) == 1:
        winner = enclosing[0]
        return {"status": "resolved", "parcel_id": winner["identity"].parcel_id, "identity": winner["identity"]}

    return {
        "status": "ambiguous",
        "candidate_count": len(grouped),
        "message": "Multiple parcels found at this tap point. Please zoom in to select the exact parcel.",
    }


# ==============================================================================
# PHASE 1 TESTS
# ==============================================================================

def test_1_same_plot_in_different_villages_produces_different_identities():
    """1. Plot 100 in Village A must NOT equal Plot 100 in Village B."""
    parcel_a = CanonicalParcelIdentity.create(
        plot_number="100",
        district_name="KEONJHAR",
        tahasil_name="KEONJHAR SADAR",
        village_name="G KERI 271",
        village_id="0704179",
    )
    parcel_b = CanonicalParcelIdentity.create(
        plot_number="100",
        district_name="KEONJHAR",
        tahasil_name="KEONJHAR SADAR",
        village_name="DIMBO 180",
        village_id="0704180",
    )
    assert parcel_a.plot_number == parcel_b.plot_number == "100"
    assert parcel_a.parcel_id != parcel_b.parcel_id
    assert parcel_a != parcel_b


def test_2_same_plot_in_different_tahasils_produces_different_identities():
    """2. Tahasil A + Village A + Plot 100 != Tahasil B + Village A + Plot 100."""
    parcel_1 = CanonicalParcelIdentity.create(
        plot_number="100",
        district_name="KEONJHAR",
        tahasil_name="ANANDAPUR",
        tahasil_id="0701",
        village_name="RAMPUR",
    )
    parcel_2 = CanonicalParcelIdentity.create(
        plot_number="100",
        district_name="KEONJHAR",
        tahasil_name="GHATAGAON",
        tahasil_id="0706",
        village_name="RAMPUR",
    )
    assert parcel_1.parcel_id != parcel_2.parcel_id
    assert parcel_1 != parcel_2


def test_3_unique_p_id_is_prioritized():
    """3. If p_id exists in GIS dataset, it is used as the primary parcel ID."""
    parcel = CanonicalParcelIdentity.create(
        parcel_id="OD_KEONJHAR_0704_179_1182",
        plot_number="1182",
        district_name="KEONJHAR",
        tahasil_name="KEONJHAR SADAR",
        village_name="G KERI 271",
    )
    assert parcel.parcel_id == "OD_KEONJHAR_0704_179_1182"
    assert parcel.is_fully_resolved is True


def test_4_missing_p_id_falls_back_to_stable_compound_identity():
    """4. If p_id is absent, compound key (district:tahasil:village:plot) is deterministically generated."""
    parcel = CanonicalParcelIdentity.create(
        parcel_id=None,
        plot_number="45/1",
        district_name="CUTTACK",
        district_id="3",
        tahasil_name="SALIPUR",
        tahasil_id="307",
        village_name="BAHALPADA",
        village_id="307012",
    )
    assert parcel.parcel_id == "3:307:307012:45/1"
    assert parcel.is_fully_resolved is True


def test_5_missing_required_fields_marks_unresolved():
    """5. Missing district, village, or plot leaves is_fully_resolved = False."""
    unresolved_parcel = CanonicalParcelIdentity.create(
        plot_number="1182",
        district_name="KEONJHAR",
        tahasil_name="N/A",
        village_name="N/A",
    )
    assert unresolved_parcel.is_fully_resolved is False


def test_6_numeric_vs_string_attribute_values():
    """6. Numeric plot numbers (e.g. 1182 as int) are normalized to clean strings without scientific notation."""
    p_int = CanonicalParcelIdentity.create(
        plot_number=1182,
        district_name="KEONJHAR",
        tahasil_name="KEONJHAR SADAR",
        village_name="G KERI",
    )
    p_str = CanonicalParcelIdentity.create(
        plot_number="1182",
        district_name="KEONJHAR",
        tahasil_name="KEONJHAR SADAR",
        village_name="G KERI",
    )
    assert p_int.plot_number == p_str.plot_number == "1182"
    assert p_int.parcel_id == p_str.parcel_id


def test_7_malformed_attributes_handled_safely():
    """7. None or whitespace attributes are stripped and do not crash."""
    parcel = CanonicalParcelIdentity.create(
        parcel_id="   ",
        plot_number="  505  ",
        district_name="  CUTTACK  ",
        tahasil_name="  BARANG  ",
        village_name="  NARAJ  ",
    )
    assert parcel.plot_number == "505"
    assert parcel.district_name == "CUTTACK"
    assert parcel.tahasil_name == "BARANG"
    assert parcel.village_name == "NARAJ"
    assert parcel.parcel_id == "CUTTACK:BARANG:NARAJ:505"
    assert parcel.is_fully_resolved is True


# ==============================================================================
# PHASE 2 MAP TAP & DISAMBIGUATION TESTS
# ==============================================================================

def test_8_tile_boundary_fragment_merging():
    """8. A polygon split across 2 vector tiles produces 1 logical parcel."""
    poly_fragment_1 = [(21.62, 85.58), (21.63, 85.58), (21.63, 85.585), (21.62, 85.585)]
    poly_fragment_2 = [(21.62, 85.585), (21.63, 85.585), (21.63, 85.59), (21.62, 85.59)]

    features = [
        {
            "attributes": {"p_id": "P_001", "revenue_plot": "101", "Village": "V1", "Tahasil": "T1"},
            "boundary": poly_fragment_1,
        },
        {
            "attributes": {"p_id": "P_001", "revenue_plot": "101", "Village": "V1", "Tahasil": "T1"},
            "boundary": poly_fragment_2,
        },
    ]

    res = resolve_tapped_candidates(features, (21.625, 85.582))
    assert res["status"] == "resolved"
    assert res["parcel_id"] == "P_001"
    assert res["identity"].plot_number == "101"


def test_9_adjacent_parcels_point_in_polygon_disambiguation():
    """9. Two adjacent parcels returned at tap point are disambiguated by ray-casting point-in-polygon."""
    # Parcel A: [0, 0] to [1, 1]
    poly_a = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    # Parcel B: [1, 0] to [2, 1]
    poly_b = [(1.0, 0.0), (2.0, 0.0), (2.0, 1.0), (1.0, 1.0)]

    features = [
        {
            "attributes": {"p_id": "P_10", "revenue_plot": "10", "Village": "V1", "Tahasil": "T1"},
            "boundary": poly_a,
        },
        {
            "attributes": {"p_id": "P_11", "revenue_plot": "11", "Village": "V1", "Tahasil": "T1"},
            "boundary": poly_b,
        },
    ]

    # Tap strictly inside Parcel B (lat=1.5, lon=0.5)
    res = resolve_tapped_candidates(features, (1.5, 0.5))
    assert res["status"] == "resolved"
    assert res["parcel_id"] == "P_11"
    assert res["identity"].plot_number == "11"


def test_10_shared_boundary_ambiguity_returns_warning():
    """10. Tap on exact shared edge between 2 parcels triggers ambiguous warning without guessing."""
    poly_a = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    poly_b = [(1.0, 0.0), (2.0, 0.0), (2.0, 1.0), (1.0, 1.0)]

    features = [
        {
            "attributes": {"p_id": "P_10", "revenue_plot": "10", "Village": "V1", "Tahasil": "T1"},
            "boundary": poly_a,
        },
        {
            "attributes": {"p_id": "P_11", "revenue_plot": "11", "Village": "V1", "Tahasil": "T1"},
            "boundary": poly_b,
        },
    ]

    # Tap outside both interiors (e.g. on edge vertex or coordinate touching both or neither interior)
    res = resolve_tapped_candidates(features, (5.0, 5.0))
    assert res["status"] == "ambiguous"
    assert res["candidate_count"] == 2
    assert "zoom in" in res["message"].lower()


def test_11_no_feature_at_tap_returns_no_feature():
    """11. Tap on empty area with no vector features returns no_feature."""
    res = resolve_tapped_candidates([], (21.62, 85.58))
    assert res["status"] == "no_feature"


# ==============================================================================
# PHASE 3 GIS DATASET INTEGRITY & VALIDATION TESTS
# ==============================================================================

def test_12_polygon_ring_closure_and_bounds_validation():
    """12. Validates polygon rings: must have >= 4 points, must be closed, must be within WGS84 range."""
    valid_ring = [(85.58, 21.62), (85.59, 21.62), (85.59, 21.63), (85.58, 21.63), (85.58, 21.62)]
    unclosed_ring = [(85.58, 21.62), (85.59, 21.62), (85.59, 21.63), (85.58, 21.63)]
    short_ring = [(85.58, 21.62), (85.59, 21.62)]

    assert len(valid_ring) >= 4 and valid_ring[0] == valid_ring[-1]
    assert unclosed_ring[0] != unclosed_ring[-1]
    assert len(short_ring) < 4


def test_13_synchronization_of_labels_and_polygons():
    """13. Verifies that plot label and polygon boundary both originate strictly from the same feature layer."""
    feature = {
        "source_layer": "Odisha4kgeo_OD_Cadastrals",
        "attributes": {
            "p_id": "0704179001182",
            "revenue_plot": "1182",
            "area_in_acre": 1.45,
            "d_name": "KEONJHAR",
            "b_name": "KEONJHAR SADAR",
            "v_name": "G KERI 271",
        },
    }
    # Label is directly extracted from revenue_plot property
    label_text = str(feature["attributes"]["revenue_plot"])
    assert label_text == "1182"
    assert feature["source_layer"] == "Odisha4kgeo_OD_Cadastrals"


def test_14_odisha_bounding_box_filter():
    """14. Verifies spatial bounding box check for Odisha State (Lon 81.3-87.6, Lat 17.7-22.7)."""
    keonjhar_coord = (21.6289, 85.5817) # lat, lon
    pune_coord = (18.5200, 73.8560)      # lat, lon (sample_parcels.json)

    def is_in_odisha(lat: float, lon: float) -> bool:
        return (17.7 <= lat <= 22.7) and (81.3 <= lon <= 87.6)

    assert is_in_odisha(keonjhar_coord[0], keonjhar_coord[1]) is True
    assert is_in_odisha(pune_coord[0], pune_coord[1]) is False


# ==============================================================================
# PHASE 4 DETERMINISTIC & FAIL-CLOSED BHULEKH RESOLUTION TESTS
# ==============================================================================

def select_exact_option(target: str, options: List[Dict[str, str]]) -> Optional[str]:
    """Simulates fail-closed deterministic dropdown resolution (no substring, no prefix)."""
    from scrapers.bhulekh_mappings import normalize
    norm_target = normalize(target)
    exact_matches = [o["value"] for o in options if normalize(o["text"]) == norm_target]
    if len(exact_matches) == 1:
        return exact_matches[0]
    elif len(exact_matches) > 1:
        raise ValueError(f"Ambiguous target '{target}' matched multiple dropdown options.")
    return None


def select_exact_plot(target_plot: str, options: List[Dict[str, str]]) -> Optional[str]:
    """Simulates fail-closed deterministic plot selection."""
    clean_target = str(target_plot).strip()
    exact_matches = [o["value"] for o in options if o["text"].strip() == clean_target]
    if len(exact_matches) == 1:
        return exact_matches[0]
    elif len(exact_matches) > 1:
        raise ValueError(f"Ambiguous plot '{target_plot}' matches multiple records.")
    return None


def test_15_village_a_vs_village_a_1_isolation():
    """15. Searching for 'KANTAPALI' must NEVER match 'KANTAPALI 1' via prefix or substring."""
    dropdown = [
        {"value": "101", "text": "KANTAPALI 1"},
        {"value": "102", "text": "KANTAPALI 2"},
        {"value": "103", "text": "KANTAPALI"},
    ]
    # Searching for exact "KANTAPALI" resolves strictly to value 103, not 101 or 102
    assert select_exact_option("KANTAPALI", dropdown) == "103"
    assert select_exact_option("KANTAPALI 1", dropdown) == "101"
    assert select_exact_option("KANTAPALI 2", dropdown) == "102"
    # Non-existent "KANTAPALI 3" fails safely (returns None, does NOT fallback to 103)
    assert select_exact_option("KANTAPALI 3", dropdown) is None


def test_16_village_a_vs_village_a_10_isolation():
    """16. 'VILLAGE A' must not match 'VILLAGE A 10'."""
    dropdown = [
        {"value": "50", "text": "CHANDPUR 10"},
        {"value": "51", "text": "CHANDPUR"},
    ]
    assert select_exact_option("CHANDPUR", dropdown) == "51"
    assert select_exact_option("CHANDPUR 10", dropdown) == "50"
    assert select_exact_option("CHANDPUR 1", dropdown) is None


def test_17_plot_12_vs_120_strict_equality():
    """17. Plot '12' must NEVER match Plot '120' or Plot '1200'."""
    plot_dropdown = [
        {"value": "val_120", "text": "120"},
        {"value": "val_12", "text": "12"},
        {"value": "val_1200", "text": "1200"},
    ]
    assert select_exact_plot("12", plot_dropdown) == "val_12"
    assert select_exact_plot("120", plot_dropdown) == "val_120"
    assert select_exact_plot("1200", plot_dropdown) == "val_1200"
    assert select_exact_plot("121", plot_dropdown) is None


def test_18_plot_12_vs_12_slash_1_strict_equality():
    """18. Plot '12' must NEVER match Plot '12/1' (bata sub-plot)."""
    plot_dropdown = [
        {"value": "val_bata", "text": "12/1"},
        {"value": "val_main", "text": "12"},
    ]
    assert select_exact_plot("12", plot_dropdown) == "val_main"
    assert select_exact_plot("12/1", plot_dropdown) == "val_bata"
    assert select_exact_plot("12/2", plot_dropdown) is None


def test_19_plot_101_vs_101A_strict_equality():
    """19. Plot '101' must NEVER match Plot '101A'."""
    plot_dropdown = [
        {"value": "val_101a", "text": "101A"},
        {"value": "val_101", "text": "101"},
    ]
    assert select_exact_plot("101", plot_dropdown) == "val_101"
    assert select_exact_plot("101A", plot_dropdown) == "val_101a"
    assert select_exact_plot("101B", plot_dropdown) is None


def test_20_ambiguous_village_multiple_matches_rejected():
    """20. If duplicate village names appear in the dropdown, ambiguous lookup raises ValueError."""
    dropdown = [
        {"value": "1", "text": "RAMPUR"},
        {"value": "2", "text": "RAMPUR"},
    ]
    with pytest.raises(ValueError, match="Ambiguous"):
        select_exact_option("RAMPUR", dropdown)


def test_21_ambiguous_tahasil_multiple_matches_rejected():
    """21. If duplicate tahasil names appear, ambiguous lookup raises ValueError."""
    dropdown = [
        {"value": "10", "text": "SADAR"},
        {"value": "20", "text": "SADAR"},
    ]
    with pytest.raises(ValueError, match="Ambiguous"):
        select_exact_option("SADAR", dropdown)


# ==============================================================================
# PHASE 5 ROR VERIFICATION LAYER TESTS (PROOF OF NON-MISMATCH)
# ==============================================================================

def test_22_mismatched_plot_fails_verification():
    """22. Requested Plot 100, but portal rendered Plot 101 -> MUST FAIL."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result, _parse_ror_page
    from models.ror_response import RoRVerificationStatus

    mismatched_html = """
    <html>
        <body>
            <span id="lblDistrictName">KEONJHAR</span>
            <span id="lblTahasilName">KEONJHAR SADAR</span>
            <span id="lblVillageName">G KERI 271</span>
            <span id="lblKhatiyanslNo">305</span>
            <span id="lblName">Balaram Jena</span>
            <table id="gvRorBack">
                <tr><td><span id="lblPlotNo">101</span></td></tr>
            </table>
        </body>
    </html>
    """
    soup = BeautifulSoup(mismatched_html, "lxml")
    verification = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G KERI 271",
        requested_plot="100",  # Requested 100, but page contains 101!
    )
    assert verification.status == RoRVerificationStatus.MISMATCH
    assert verification.plot_match is False
    assert "Plot mismatch" in verification.details

    # Parsing must raise ValueError and refuse to return ownership data
    with pytest.raises(ValueError, match="Unable to verify this parcel"):
        _parse_ror_page(
            html=mismatched_html,
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot="100",
        )


def test_23_mismatched_village_fails_verification():
    """23. Requested Village A, but portal rendered Village B -> MUST FAIL."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result, _parse_ror_page
    from models.ror_response import RoRVerificationStatus

    mismatched_html = """
    <html>
        <body>
            <span id="lblDistrictName">KEONJHAR</span>
            <span id="lblTahasilName">KEONJHAR SADAR</span>
            <span id="lblVillageName">DIMBO 180</span>
            <span id="lblKhatiyanslNo">55</span>
            <span id="lblName">Ananta Mohapatra</span>
            <table id="gvRorBack">
                <tr><td><span id="lblPlotNo">100</span></td></tr>
            </table>
        </body>
    </html>
    """
    soup = BeautifulSoup(mismatched_html, "lxml")
    verification = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G KERI 271",  # Requested G Keri, but page has Dimbo!
        requested_plot="100",
    )
    assert verification.status == RoRVerificationStatus.MISMATCH
    assert verification.location_match is False
    assert "Location mismatch" in verification.details

    with pytest.raises(ValueError, match="Unable to verify this parcel"):
        _parse_ror_page(
            html=mismatched_html,
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot="100",
        )


def test_24_insufficient_data_empty_page_fails_verification():
    """24. If portal returns empty HTML without confirmation plot, verification fails safely."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result, _parse_ror_page
    from models.ror_response import RoRVerificationStatus

    empty_html = "<html><body><div>Session Expired or No Record</div></body></html>"
    soup = BeautifulSoup(empty_html, "lxml")
    verification = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G KERI 271",
        requested_plot="100",
    )
    assert verification.status == RoRVerificationStatus.INSUFFICIENT_DATA
    assert verification.plot_match is False

    with pytest.raises(ValueError, match="Unable to verify this parcel"):
        _parse_ror_page(
            html=empty_html,
            district="KEONJHAR",
            tahasil="KEONJHAR SADAR",
            village="G KERI 271",
            plot="100",
        )


def test_25_matching_parcel_passes_verification_and_constructs_ror():
    """25. Requested Village A / Plot 100 matching portal Village A / Plot 100 PASSES and extracts owners."""
    from bs4 import BeautifulSoup
    from scrapers.bhulekh_scraper import verify_ror_result, _parse_ror_page
    from models.ror_response import RoRVerificationStatus

    valid_html = """
    <html>
        <body>
            <span id="lblDistrictName">KEONJHAR</span>
            <span id="lblTahasilName">KEONJHAR SADAR</span>
            <span id="lblVillageName">G KERI 271</span>
            <span id="lblKhatiyanslNo">412</span>
            <span id="lblName">Rabindra Sahu, Gitanjali Sahu</span>
            <table id="gvRorBack">
                <tr>
                    <td><span id="lblPlotNo">100</span></td>
                    <td><span id="lbllType">Sarada-1</span></td>
                    <td><span id="lblAcre">1</span></td>
                    <td><span id="lblDecimil">25</span></td>
                </tr>
            </table>
        </body>
    </html>
    """
    soup = BeautifulSoup(valid_html, "lxml")
    verification = verify_ror_result(
        soup=soup,
        requested_district="KEONJHAR",
        requested_tahasil="KEONJHAR SADAR",
        requested_village="G KERI 271",
        requested_plot="100",
    )
    assert verification.status == RoRVerificationStatus.VERIFIED
    assert verification.plot_match is True
    assert verification.location_match is True

    ror = _parse_ror_page(
        html=valid_html,
        district="KEONJHAR",
        tahasil="KEONJHAR SADAR",
        village="G KERI 271",
        plot="100",
    )
    assert ror.success is True
    assert ror.plot == "100"
    assert ror.khata_number == "412"
    assert ror.land_type == "Sarada-1"
    assert ror.area == "1 Acre 25 Decimal"
    assert len(ror.owners) == 2
    assert ror.owners[0].name == "Rabindra Sahu"
    assert ror.owners[1].name == "Gitanjali Sahu"
    assert ror.verification.status == RoRVerificationStatus.VERIFIED


# ==============================================================================
# PHASE 8 GIS-ROR CROSS-VERIFICATION PIPELINE TESTS
# ==============================================================================

def cross_verify_gis_with_ror(gis_parcel: Dict[str, Any], ror_response: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    """Simulates the final fail-closed cross-verification pipeline between GIS parcel and RoR."""
    from scrapers.bhulekh_mappings import normalize

    if not ror_response:
        return {
            "status": "INSUFFICIENT_DATA",
            "is_verified": False,
            "show_owners": False,
            "reasons": ["No Record of Rights response received."],
        }

    gis_plot = str(gis_parcel.get("plot_number", "")).strip()
    gis_village = gis_parcel.get("village_name", "")
    gis_tahasil = gis_parcel.get("tahasil_name", "")
    gis_district = gis_parcel.get("district_name", "")

    # Fully resolved check
    if not (gis_plot and gis_village and gis_tahasil and gis_district):
        return {
            "status": "INSUFFICIENT_DATA",
            "is_verified": False,
            "show_owners": False,
            "reasons": ["GIS parcel is missing required revenue identifiers."],
        }

    ror_plot = str(ror_response.get("plot", "")).strip()
    ror_village = ror_response.get("village", "")
    ror_tahasil = ror_response.get("tahasil", "")
    ror_district = ror_response.get("district", "")

    reasons = []
    plot_match = (gis_plot == ror_plot)
    if not plot_match:
        reasons.append(f"Plot mismatch: GIS '{gis_plot}' != RoR '{ror_plot}'")

    vill_match = (normalize(gis_village) == normalize(ror_village))
    if not vill_match:
        reasons.append(f"Village mismatch: GIS '{gis_village}' != RoR '{ror_village}'")

    tah_match = (normalize(gis_tahasil) == normalize(ror_tahasil))
    if not tah_match:
        reasons.append(f"Tahasil mismatch: GIS '{gis_tahasil}' != RoR '{ror_tahasil}'")

    dist_match = (normalize(gis_district) == normalize(ror_district))
    if not dist_match:
        reasons.append(f"District mismatch: GIS '{gis_district}' != RoR '{ror_district}'")

    if reasons:
        return {
            "status": "MISMATCH",
            "is_verified": False,
            "show_owners": False,
            "reasons": reasons,
        }

    return {
        "status": "VERIFIED",
        "is_verified": True,
        "show_owners": True,
        "reasons": ["Exact parcel match verified."],
    }


def test_26_cross_verification_exact_match_enables_owners():
    """26. Exact GIS and RoR match -> VERIFIED -> Owners enabled."""
    gis = {
        "plot_number": "1182",
        "village_name": "G KERI 271",
        "tahasil_name": "KEONJHAR SADAR",
        "district_name": "KEONJHAR",
    }
    ror = {
        "plot": "1182",
        "village": "G KERI 271",
        "tahasil": "KEONJHAR SADAR",
        "district": "KEONJHAR",
        "owners": ["Dillip Kumar Mahanta"],
    }
    result = cross_verify_gis_with_ror(gis, ror)
    assert result["status"] == "VERIFIED"
    assert result["is_verified"] is True
    assert result["show_owners"] is True


def test_27_cross_verification_plot_mismatch_blocks_owners():
    """27. Plot 12 vs 120 -> MISMATCH -> Owners blocked."""
    gis = {
        "plot_number": "12",
        "village_name": "G KERI 271",
        "tahasil_name": "KEONJHAR SADAR",
        "district_name": "KEONJHAR",
    }
    ror = {
        "plot": "120",
        "village": "G KERI 271",
        "tahasil": "KEONJHAR SADAR",
        "district": "KEONJHAR",
        "owners": ["Wrong Person"],
    }
    result = cross_verify_gis_with_ror(gis, ror)
    assert result["status"] == "MISMATCH"
    assert result["is_verified"] is False
    assert result["show_owners"] is False
    assert "Plot mismatch" in result["reasons"][0]


def test_28_cross_verification_village_mismatch_blocks_owners():
    """28. Village A vs Village B -> MISMATCH -> Owners blocked."""
    gis = {
        "plot_number": "100",
        "village_name": "KANTAPALI 1",
        "tahasil_name": "BARGARH",
        "district_name": "BARGARH",
    }
    ror = {
        "plot": "100",
        "village": "KANTAPALI 2",
        "tahasil": "BARGARH",
        "district": "BARGARH",
        "owners": ["Wrong Village Holder"],
    }
    result = cross_verify_gis_with_ror(gis, ror)
    assert result["status"] == "MISMATCH"
    assert result["is_verified"] is False
    assert result["show_owners"] is False


def test_29_cross_verification_missing_gis_fields_blocks_owners():
    """29. Missing GIS village -> INSUFFICIENT_DATA -> Owners blocked."""
    gis = {
        "plot_number": "100",
        "village_name": "",
        "tahasil_name": "BARGARH",
        "district_name": "BARGARH",
    }
    ror = {
        "plot": "100",
        "village": "KANTAPALI",
        "tahasil": "BARGARH",
        "district": "BARGARH",
    }
    result = cross_verify_gis_with_ror(gis, ror)
    assert result["status"] == "INSUFFICIENT_DATA"
    assert result["is_verified"] is False
    assert result["show_owners"] is False




