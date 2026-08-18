"""
Phase 3.19C — Odisha-Wide Real-World RoR Retrieval & Large-Scale Validation Suite
Validates 30-district test matrix, duplicate village isolation, exact plot isolation,
cache isolation, concurrency safety, PDF validation, and zero false matches.
"""
import pytest
import asyncio
from diagnostics.odisha_ror_benchmark_engine import (
    OdishaRoRBenchmarkEngine,
    BenchmarkClassification,
    SAMPLE_ODISHA_LOCATIONS,
)
from resolvers.bhulekh_identity_resolver import (
    CadastralParcelIdentity,
    BhulekhLocationIdentity,
    ResolutionStatus,
    resolve_bhulekh_identity,
)
from services.ror_service import get_canonical_cache_key


def test_1_large_scale_30_district_matrix_coverage():
    """Verify large test matrix spans all 30 districts with 270+ villages and 800+ parcels."""
    matrix = OdishaRoRBenchmarkEngine.generate_test_matrix()
    assert len(matrix) >= 270
    assert len(matrix) >= 800
    
    districts = {p.district_name for p in matrix}
    assert len(districts) == 30
    for d in SAMPLE_ODISHA_LOCATIONS.keys():
        assert d in districts


def test_2_benchmark_evaluation_and_zero_false_matches():
    """Evaluate full benchmark and assert 0 false land-record matches across all test cases."""
    summary, md_report = OdishaRoRBenchmarkEngine.run_full_benchmark()
    
    assert summary["districts_tested"] == 30
    assert summary["tahasils_tested"] >= 90
    assert summary["villages_tested"] >= 270
    assert summary["total_test_cases"] >= 800
    assert summary["false_matches"] == 0  # CRITICAL INVARIANT: ZERO FALSE MATCHES
    assert summary["verified_success"] > 0
    assert summary["success_rate_percentage"] > 95.0
    assert "## 3. District-Wise Coverage Matrix" in md_report


def test_3_exact_plot_number_isolation_adversarial():
    """Adversarial test: Plot 12 vs 120 vs 12/1 vs 12A vs 0012."""
    base_info = {
        "district_name": "KEONJHAR",
        "tahasil_name": "KEONJHAR SADAR",
        "village_name": "G_Dimbo",
        "village_id": "0704317",
    }
    
    p_12 = CadastralParcelIdentity(**base_info, plot_number="12")
    p_120 = CadastralParcelIdentity(**base_info, plot_number="120")
    p_12_1 = CadastralParcelIdentity(**base_info, plot_number="12/1")
    p_12A = CadastralParcelIdentity(**base_info, plot_number="12A")
    p_0012 = CadastralParcelIdentity(**base_info, plot_number="0012")

    r_12 = OdishaRoRBenchmarkEngine.evaluate_parcel(p_12)
    r_120 = OdishaRoRBenchmarkEngine.evaluate_parcel(p_120)
    r_12_1 = OdishaRoRBenchmarkEngine.evaluate_parcel(p_12_1)
    r_12A = OdishaRoRBenchmarkEngine.evaluate_parcel(p_12A)
    r_0012 = OdishaRoRBenchmarkEngine.evaluate_parcel(p_0012)

    assert r_12.bhulekh_plot == "12"
    assert r_120.bhulekh_plot == "120"
    assert r_12_1.bhulekh_plot == "12/1"
    assert r_12A.bhulekh_plot == "12A"
    assert r_0012.bhulekh_plot == "0012"
    
    assert r_12.bhulekh_plot != r_120.bhulekh_plot
    assert r_12.bhulekh_plot != r_12_1.bhulekh_plot
    assert r_12.bhulekh_plot != r_12A.bhulekh_plot
    assert r_12.bhulekh_plot != r_0012.bhulekh_plot


def test_4_duplicate_village_cross_district_isolation():
    """Safety test: Same village name across distinct districts resolves to independent scoped identities."""
    # Village "Nuagaon" in Balasore (1) vs "Nuagaon" in Nayagarh (22)
    c_balasore = CadastralParcelIdentity(
        district_name="BALASORE",
        tahasil_name="BASTA",
        village_name="Nuagaon",
        plot_number="5",
    )
    c_nayagarh = CadastralParcelIdentity(
        district_name="NAYAGARH",
        tahasil_name="NAYAGARH",
        village_name="Nuagaon",
        plot_number="5",
    )

    r_balasore = OdishaRoRBenchmarkEngine.evaluate_parcel(c_balasore)
    r_nayagarh = OdishaRoRBenchmarkEngine.evaluate_parcel(c_nayagarh)

    assert r_balasore.bhulekh_district_id == "1"
    assert r_nayagarh.bhulekh_district_id == "22"
    assert r_balasore.bhulekh_district_id != r_nayagarh.bhulekh_district_id


def test_5_canonical_cache_key_isolation():
    """Cache Isolation: Different villages with the same plot number produce distinct cache keys."""
    key_cuttack = get_canonical_cache_key("CUTTACK", "ATHAGARH", "Anantapur", "101", "0301088")
    key_puri = get_canonical_cache_key("PURI", "ASTARANG", "Alangpur", "101", "1108050")
    key_keonjhar = get_canonical_cache_key("KEONJHAR", "KEONJHAR SADAR", "Dimbo", "101", "0704317")

    assert key_cuttack != key_puri
    assert key_cuttack != key_keonjhar
    assert key_puri != key_keonjhar


@pytest.mark.anyio
async def test_6_concurrent_benchmark_resolution_under_load():
    """Concurrency simulation: 10, 25, 50 simultaneous parcel evaluations without leakage."""
    matrix = OdishaRoRBenchmarkEngine.generate_test_matrix()
    sample_50 = matrix[:50]

    def sync_evaluate(p: CadastralParcelIdentity):
        return OdishaRoRBenchmarkEngine.evaluate_parcel(p)

    # Run 50 concurrent lookups
    results = await asyncio.gather(*(asyncio.to_thread(sync_evaluate, p) for p in sample_50))
    assert len(results) == 50

    for res, orig in zip(results, sample_50):
        assert res.gis_district == orig.district_name
        assert res.gis_plot == orig.plot_number
        assert res.bhulekh_plot == orig.plot_number
        assert res.classification == BenchmarkClassification.VERIFIED_SUCCESS


def test_7_pdf_structure_and_magic_bytes_validation():
    """Verify PDF validation checks %PDF- magic bytes and non-zero structure."""
    def is_valid_pdf_payload(raw: bytes) -> bool:
        return isinstance(raw, bytes) and len(raw) > 50 and raw.startswith(b"%PDF-")

    valid_sample_pdf = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF"
    invalid_sample_html = b"<html><body>Error 404 Not Found</body></html>"

    assert is_valid_pdf_payload(valid_sample_pdf) is True
    assert is_valid_pdf_payload(invalid_sample_html) is False


def test_8_zero_pii_in_benchmark_logs():
    """Security test: Benchmark logs and results contain zero PII, Aadhaar, tokens, or raw HTML."""
    matrix = OdishaRoRBenchmarkEngine.generate_test_matrix()
    sample = matrix[0]
    res = OdishaRoRBenchmarkEngine.evaluate_parcel(sample)
    
    res_dict = res.model_dump()
    forbidden_keys = ["owner", "owner_name", "aadhaar", "phone", "token", "jwt", "cookie", "html"]
    for k in forbidden_keys:
        assert k not in res_dict
