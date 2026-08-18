"""
Phase 3.19A — RoR Resolution Diagnostics & Odisha-Wide Failure Audit Engine
Provides fail-closed diagnostic tracing for RoR runtime lookups across all 30 Odisha districts.
"""
import time
import uuid
import logging
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field

logger = logging.getLogger("bhumitra.diagnostics")


class RoRResolutionTrace(BaseModel):
    """Safe diagnostic trace object strictly excluding PII, tokens, or raw HTML."""
    request_id: str = Field(default_factory=lambda: f"diag-{uuid.uuid4().hex[:8]}")
    gis_district: str
    gis_district_id: Optional[str] = None
    gis_tahasil: str
    gis_tahasil_id: Optional[str] = None
    gis_village: str
    gis_village_id: Optional[str] = None
    gis_plot: str

    bhulekh_district: Optional[str] = None
    bhulekh_district_id: Optional[str] = None
    bhulekh_tahasil: Optional[str] = None
    bhulekh_tahasil_id: Optional[str] = None
    bhulekh_village: Optional[str] = None
    bhulekh_village_id: Optional[str] = None
    bhulekh_plot: Optional[str] = None

    resolution_method: Optional[str] = None
    resolution_status: Optional[str] = None
    verification_status: Optional[str] = None
    match_status: str = "PENDING"  # VERIFIED, MISMATCH, FAILED, DATA_UNAVAILABLE
    failure_stage: Optional[str] = None  # Category A through P
    failure_detail: Optional[str] = None
    provider_status: Optional[int] = None
    latency_ms: float = 0.0


class DiagnosticFailureCategory:
    A_GIS_IDENTITY_PROBLEM = "A_GIS_IDENTITY_PROBLEM"
    B_VILLAGE_IDENTITY_MAPPING_PROBLEM = "B_VILLAGE_IDENTITY_MAPPING_PROBLEM"
    C_DISTRICT_MISMATCH = "C_DISTRICT_MISMATCH"
    D_TAHASIL_MISMATCH = "D_TAHASIL_MISMATCH"
    E_VILLAGE_NAME_MISMATCH = "E_VILLAGE_NAME_MISMATCH"
    F_PLOT_NUMBER_MISMATCH = "F_PLOT_NUMBER_MISMATCH"
    G_PLOT_FORMAT_MISMATCH = "G_PLOT_FORMAT_MISMATCH"
    H_BHULEKH_SEARCH_FAILURE = "H_BHULEKH_SEARCH_FAILURE"
    I_BHULEKH_SESSION_FAILURE = "I_BHULEKH_SESSION_FAILURE"
    J_BHULEKH_PAGE_STRUCTURE_CHANGE = "J_BHULEKH_PAGE_STRUCTURE_CHANGE"
    K_VERIFICATION_MISMATCH = "K_VERIFICATION_MISMATCH"
    L_NO_RECORD_FOUND = "L_NO_RECORD_FOUND"
    M_TIMEOUT = "M_TIMEOUT"
    N_RATE_LIMIT = "N_RATE_LIMIT"
    O_PDF_GENERATION_FAILURE = "O_PDF_GENERATION_FAILURE"
    P_IOS_DECODING_FAILURE = "P_IOS_DECODING_FAILURE"


class RoRDiagnosticEngine:
    """
    Audits RoR resolution and captures diagnostic traces without altering matching behavior.
    """

    @staticmethod
    def audit_trace(
        gis_district: str,
        gis_tahasil: str,
        gis_village: str,
        gis_plot: str,
        gis_district_id: Optional[str] = None,
        gis_tahasil_id: Optional[str] = None,
        gis_village_id: Optional[str] = None,
        bhulekh_district: Optional[str] = None,
        bhulekh_district_id: Optional[str] = None,
        bhulekh_tahasil: Optional[str] = None,
        bhulekh_tahasil_id: Optional[str] = None,
        bhulekh_village: Optional[str] = None,
        bhulekh_village_id: Optional[str] = None,
        bhulekh_plot: Optional[str] = None,
        resolution_method: Optional[str] = None,
        resolution_status: Optional[str] = None,
        verification_status: Optional[str] = None,
        match_status: str = "FAILED",
        failure_stage: Optional[str] = None,
        failure_detail: Optional[str] = None,
        provider_status: Optional[int] = None,
        latency_ms: float = 0.0,
    ) -> RoRResolutionTrace:
        trace = RoRResolutionTrace(
            gis_district=gis_district,
            gis_district_id=gis_district_id,
            gis_tahasil=gis_tahasil,
            gis_tahasil_id=gis_tahasil_id,
            gis_village=gis_village,
            gis_village_id=gis_village_id,
            gis_plot=gis_plot,
            bhulekh_district=bhulekh_district,
            bhulekh_district_id=bhulekh_district_id,
            bhulekh_tahasil=bhulekh_tahasil,
            bhulekh_tahasil_id=bhulekh_tahasil_id,
            bhulekh_village=bhulekh_village,
            bhulekh_village_id=bhulekh_village_id,
            bhulekh_plot=bhulekh_plot,
            resolution_method=resolution_method,
            resolution_status=resolution_status,
            verification_status=verification_status,
            match_status=match_status,
            failure_stage=failure_stage,
            failure_detail=failure_detail,
            provider_status=provider_status,
            latency_ms=latency_ms,
        )
        logger.info(
            f"[RoRDiagnostic] [{trace.request_id}] district={trace.gis_district}, "
            f"tahasil={trace.gis_tahasil}, village={trace.gis_village}, plot={trace.gis_plot} "
            f"-> status={trace.match_status}, method={trace.resolution_method}, stage={trace.failure_stage}, latency={trace.latency_ms:.1f}ms"
        )
        return trace
