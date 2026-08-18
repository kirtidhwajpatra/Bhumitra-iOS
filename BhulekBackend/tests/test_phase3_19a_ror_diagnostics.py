"""
Phase 3.19A — RoR Runtime Failure Audit & Odisha-Wide Diagnostics Test Suite
Tests diagnostic tracing, failure taxonomy classification, and zero-PII logging.
"""
import pytest
from diagnostics.ror_diagnostic_engine import (
    RoRResolutionTrace,
    DiagnosticFailureCategory,
    RoRDiagnosticEngine,
)
from models.ror_response import RoRErrorCode, RoRErrorDetail


def test_1_ror_resolution_trace_structure_and_no_pii():
    """Verify RoRResolutionTrace contains only sanitized diagnostic identifiers."""
    trace = RoRDiagnosticEngine.audit_trace(
        gis_district="KEONJHAR",
        gis_tahasil="KEONJHAR SADAR",
        gis_village="G_Dimbo",
        gis_village_id="0704317",
        gis_plot="12",
        bhulekh_district="7",
        bhulekh_tahasil="4",
        bhulekh_village="271",
        bhulekh_plot="12",
        match_status="VERIFIED",
        latency_ms=1250.0,
    )
    
    assert trace.request_id.startswith("diag-")
    assert trace.gis_district == "KEONJHAR"
    assert trace.gis_plot == "12"
    assert trace.match_status == "VERIFIED"
    assert trace.latency_ms == 1250.0
    
    # Assert no sensitive fields exist in model
    fields = set(trace.model_dump().keys())
    assert "owner" not in fields
    assert "owner_name" not in fields
    assert "aadhaar" not in fields
    assert "phone" not in fields
    assert "token" not in fields
    assert "html" not in fields


def test_2_failure_classification_categories_a_to_p():
    """Verify all 16 diagnostic failure stages are formally defined."""
    categories = [
        DiagnosticFailureCategory.A_GIS_IDENTITY_PROBLEM,
        DiagnosticFailureCategory.B_VILLAGE_IDENTITY_MAPPING_PROBLEM,
        DiagnosticFailureCategory.C_DISTRICT_MISMATCH,
        DiagnosticFailureCategory.D_TAHASIL_MISMATCH,
        DiagnosticFailureCategory.E_VILLAGE_NAME_MISMATCH,
        DiagnosticFailureCategory.F_PLOT_NUMBER_MISMATCH,
        DiagnosticFailureCategory.G_PLOT_FORMAT_MISMATCH,
        DiagnosticFailureCategory.H_BHULEKH_SEARCH_FAILURE,
        DiagnosticFailureCategory.I_BHULEKH_SESSION_FAILURE,
        DiagnosticFailureCategory.J_BHULEKH_PAGE_STRUCTURE_CHANGE,
        DiagnosticFailureCategory.K_VERIFICATION_MISMATCH,
        DiagnosticFailureCategory.L_NO_RECORD_FOUND,
        DiagnosticFailureCategory.M_TIMEOUT,
        DiagnosticFailureCategory.N_RATE_LIMIT,
        DiagnosticFailureCategory.O_PDF_GENERATION_FAILURE,
        DiagnosticFailureCategory.P_IOS_DECODING_FAILURE,
    ]
    assert len(categories) == 16
    for c in categories:
        assert isinstance(c, str)
        assert len(c) > 3


def test_3_plot_format_diagnostic_matrix():
    """Verify diagnostic trace handles diverse legitimate Odisha plot formats."""
    plot_formats = ["12", "12/1", "12A", "0012", "2/936", "1182/2345"]
    
    for plot in plot_formats:
        trace = RoRDiagnosticEngine.audit_trace(
            gis_district="CUTTACK",
            gis_tahasil="ATHAGARH",
            gis_village="Anantapur-64",
            gis_village_id="0301088",
            gis_plot=plot,
            match_status="FAILED",
            failure_stage=DiagnosticFailureCategory.E_VILLAGE_NAME_MISMATCH,
            failure_detail=f"Village 'Anantapur-64' not found in Athagarh dropdown",
            latency_ms=850.0,
        )
        assert trace.gis_plot == plot
        assert trace.failure_stage == DiagnosticFailureCategory.E_VILLAGE_NAME_MISMATCH
        assert "Anantapur-64" in trace.failure_detail


def test_4_odisha_wide_diagnostic_simulation_matrix():
    """Verify diagnostic traces across representative Odisha districts."""
    sample_locations = [
        ("KEONJHAR", "KEONJHAR SADAR", "G_Dimbo", "0704317", "12", "VERIFIED", None),
        ("KHURDA", "BALIANTA", "Baindolo", "2008007", "15", "FAILED", DiagnosticFailureCategory.E_VILLAGE_NAME_MISMATCH),
        ("CUTTACK", "ATHAGARH", "Anantapur-64", "0301088", "101", "FAILED", DiagnosticFailureCategory.B_VILLAGE_IDENTITY_MAPPING_PROBLEM),
        ("PURI", "ASTARANG", "Alangpur", "1108050", "44", "FAILED", DiagnosticFailureCategory.F_PLOT_NUMBER_MISMATCH),
        ("GANJAM", "ASKA", "Alipur", "0501002", "89/1", "FAILED", DiagnosticFailureCategory.K_VERIFICATION_MISMATCH),
    ]
    
    traces = []
    for dist, tah, vill, vid, plot, status, failure in sample_locations:
        tr = RoRDiagnosticEngine.audit_trace(
            gis_district=dist,
            gis_tahasil=tah,
            gis_village=vill,
            gis_village_id=vid,
            gis_plot=plot,
            match_status=status,
            failure_stage=failure,
            latency_ms=1100.0,
        )
        traces.append(tr)
        
    assert len(traces) == 5
    assert traces[0].match_status == "VERIFIED"
    assert traces[1].failure_stage == DiagnosticFailureCategory.E_VILLAGE_NAME_MISMATCH
    assert traces[2].failure_stage == DiagnosticFailureCategory.B_VILLAGE_IDENTITY_MAPPING_PROBLEM
