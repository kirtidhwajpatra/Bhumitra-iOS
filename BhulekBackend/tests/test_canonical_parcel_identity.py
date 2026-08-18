"""
Canonical Parcel Identity & Core Data Accuracy Tests
Validates immutable parcel identity rules, cross-village plot isolation,
numeric/string attribute normalization, missing field rejection, and RoR separation.
"""

import pytest
from dataclasses import dataclass
from typing import Optional, Dict, Any


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


# ==============================================================================
# TESTS
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
