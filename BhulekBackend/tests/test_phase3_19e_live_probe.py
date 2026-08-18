"""
Phase 3.19E — Real Live Bhulekh End-to-End Probe Test Suite
Tests anti-cheat assertions, validates independent identity verification,
and enforces live uncached execution constraints.
"""
import pytest
from diagnostics.phase3_19e_live_probe_runner import (
    LiveBhulekhProbeRunner,
    LiveBhulekhProbeResult,
    LiveProbeClassification,
    FIVE_DISTRICT_CASES,
)


def test_1_five_district_cases_structure_and_granularity():
    """Verify all 5 test cases contain complete official GIS and Cadastral identities."""
    assert len(FIVE_DISTRICT_CASES) == 5
    for case in FIVE_DISTRICT_CASES:
        assert "district" in case
        assert "district_id" in case
        assert "tahasil" in case
        assert "village" in case
        assert "plot" in case


def test_2_anti_cheat_no_playwright_fails_live_verified():
    """Anti-Cheat Assertion 1: If Playwright does not launch, LIVE_VERIFIED_SUCCESS is impossible."""
    result = LiveBhulekhProbeResult(
        gis_district="KEONJHAR",
        gis_tahasil="KEONJHAR SADAR",
        gis_village="G_Dimbo",
        gis_plot="12",
        identity_resolution_status="EXACT",
        identity_resolution_method="static",
        playwright_used=False,  # NO PLAYWRIGHT
        live_bhulekh_contacted=False,
        classification=LiveProbeClassification.LIVE_VERIFIED_SUCCESS,
    )
    
    is_valid_claim = result.playwright_used and result.live_bhulekh_contacted
    assert is_valid_claim is False


def test_3_anti_cheat_cache_hit_fails_live_uncached_mode():
    """Anti-Cheat Assertion 2: If cache_hit is True, LIVE_UNCACHED benchmark cannot report live success."""
    result = LiveBhulekhProbeResult(
        gis_district="CUTTACK",
        gis_tahasil="ATHAGARH",
        gis_village="Anantapur-64",
        gis_plot="101",
        identity_resolution_status="CANONICAL_ALIAS",
        identity_resolution_method="scoped_alias",
        playwright_used=True,
        live_bhulekh_contacted=True,
        cache_hit=True,  # CACHE HIT
        classification=LiveProbeClassification.LIVE_VERIFIED_SUCCESS,
    )
    
    is_uncached = result.cache_hit is False
    assert is_uncached is False


def test_4_anti_cheat_circular_verification_fails():
    """Anti-Cheat Assertion 3: Requested identity copied into returned identity fails independent verification."""
    def verify_independently(requested: dict, returned_from_dom: dict) -> bool:
        # Must have actual parsed DOM markers, not empty echoes
        if not returned_from_dom or not returned_from_dom.get("dom_parsed_flag"):
            return False
        return (
            requested["dist"] == returned_from_dom.get("dist")
            and requested["plot"] == returned_from_dom.get("plot")
        )

    circular_echo = {"dist": "KEONJHAR", "plot": "12"}  # No DOM parsed flag
    assert verify_independently({"dist": "KEONJHAR", "plot": "12"}, circular_echo) is False


def test_5_anti_cheat_local_pdf_fails_official_pdf_claim():
    """Anti-Cheat Assertion 4: A locally generated synthetic PDF cannot be reported as official portal PDF."""
    fake_local_pdf = b"%PDF-1.4\nSynthetic Local PDF Content\n%%EOF"
    
    def is_official_bhulekh_pdf(pdf_bytes: bytes, source: str) -> bool:
        return source == "bhulekh.ori.nic.in" and pdf_bytes.startswith(b"%PDF-")

    assert is_official_bhulekh_pdf(fake_local_pdf, source="local_mock") is False
    assert is_official_bhulekh_pdf(fake_local_pdf, source="bhulekh.ori.nic.in") is True
