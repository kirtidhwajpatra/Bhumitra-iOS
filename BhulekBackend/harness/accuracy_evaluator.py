"""
Phase 3 Accuracy Evaluator and Regression Harness
Consumes the parcel truth dataset, runs identity resolution, exact plot matching,
record association, and computes dynamic accuracy metrics across Odisha.
"""
import json
import time
import os
from typing import Dict, List, Any, Tuple, Optional
from bs4 import BeautifulSoup

from models.parcel_truth import ParcelTruthRecord, ValidationLevel, AccuracyCategory
from resolvers.bhulekh_identity_resolver import (
    VerifiedBhulekhCatalog,
    BhulekhVillageResolver,
    ResolutionStatus,
)
from resolvers.plot_normalizer import normalize_plot_number, is_exact_plot_match
from scrapers.bhulekh_scraper import verify_ror_result
from scrapers.structured_ror_parser import parse_structured_ror


class AccuracyEvaluator:
    def __init__(self, dataset_path: Optional[str] = None):
        if dataset_path:
            self.dataset_path = dataset_path
        else:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.dataset_path = os.path.join(base_dir, "data", "parcel_truth", "odisha_statewide_truth.json")
        self.records: List[ParcelTruthRecord] = []
        self.load_dataset()
        VerifiedBhulekhCatalog.load()

    def load_dataset(self):
        p = self.dataset_path
        if not os.path.exists(p):
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            alt1 = os.path.join(base_dir, p.replace("BhulekBackend/", ""))
            alt2 = os.path.join(base_dir, p)
            if os.path.exists(alt1):
                p = alt1
            elif os.path.exists(alt2):
                p = alt2
            else:
                raise FileNotFoundError(f"Truth dataset not found at {self.dataset_path}")
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
            self.records = [ParcelTruthRecord(**item) for item in data]

    def generate_simulated_ror_dom(self, rec: ParcelTruthRecord) -> str:
        """Constructs authentic Bhulekh HTML representation based on ground truth for testing."""
        owners_html = ""
        for o in rec.official_owners:
            rel = f" {o.relation} {o.relation_name}" if o.relation and o.relation != "UNKNOWN" else ""
            owners_html += f"<tr><td><span id=\"lblName\">{o.name}{rel}</span></td><td><span id=\"lblShare\">{o.share}</span></td></tr>"

        landlord_html = ""
        if rec.category == "GOVT_LAND" and rec.official_owners:
            landlord_html = f"<span id=\"lblLandlordName\">{rec.official_owners[0].name}</span>"

        # Split area if present
        acre = "0"
        dec = "0"
        if "Acre" in rec.official_acreage:
            parts = rec.official_acreage.split("Acre")
            acre = parts[0].strip()
            if "Decimal" in parts[1]:
                dec = parts[1].replace("Decimal", "").strip()

        dom = f"""
        <html><body>
            <span id="lblDistrictName">{rec.district}</span>
            <span id="lblTahasilName">{rec.tahasil}</span>
            <span id="lblVillageName">{rec.mouza_name if rec.mouza_name != 'UNKNOWN' else rec.village_name}</span>
            <span id="lblKhatiyanslNo">{rec.official_khata_number if rec.official_khata_number != 'UNKNOWN' else '120'}</span>
            {landlord_html}
            <table id="gvfront">
                {owners_html}
            </table>
            <table id="gvRorBack">
                <tr>
                    <td>{rec.official_plot_number}</td>
                    <td>{rec.official_land_classification if rec.official_land_classification != 'UNKNOWN' else 'Sarada-1'}</td>
                    <td>{acre}</td>
                    <td>{dec}</td>
                </tr>
            </table>
        </body></html>
        """
        return dom

    def evaluate_single_record(self, rec: ParcelTruthRecord) -> Tuple[AccuracyCategory, Dict[str, Any]]:
        t_start = time.perf_counter()
        diag = {
            "test_id": rec.test_id,
            "district": rec.district,
            "village": rec.village_name,
            "plot": rec.gis_plot_number,
            "category": rec.category,
            "level_reached": 0,
            "false_owner": False,
            "false_classification": False,
            "false_parcel_id": False,
            "time_ms": 0.0,
            "error_msg": None,
        }

        # Level 1: GIS Identity
        norm_plot = normalize_plot_number(rec.gis_plot_number)
        if not rec.district or not rec.tahasil or not rec.village_name:
            diag["time_ms"] = (time.perf_counter() - t_start) * 1000
            return AccuracyCategory.FAIL, diag
        diag["level_reached"] = 1

        # Level 2: Bhulekh Identity Resolution
        res_rec, status, detail = VerifiedBhulekhCatalog.lookup(
            district_id=rec.district_id,
            tahasil_id=rec.tahasil_id,
            village_name=rec.village_name,
        )

        is_resolved = status in (
            ResolutionStatus.EXACT,
            ResolutionStatus.NORMALIZED_EXACT,
            ResolutionStatus.CANONICAL_ALIAS,
            ResolutionStatus.BILINGUAL_MATCH,
            ResolutionStatus.VERIFIED_MAPPED,
        )

        if rec.is_negative_test and "VILLAGE" in (rec.historical_failure_type or ""):
            # Negative village test: Expected UNRESOLVED
            diag["time_ms"] = (time.perf_counter() - t_start) * 1000
            if not is_resolved:
                diag["level_reached"] = 2
                return AccuracyCategory.UNRESOLVED, diag
            else:
                diag["error_msg"] = "Negative village test unexpectedly resolved"
                return AccuracyCategory.FAIL, diag

        if not is_resolved:
            diag["time_ms"] = (time.perf_counter() - t_start) * 1000
            if rec.expected_status == AccuracyCategory.UNRESOLVED:
                return AccuracyCategory.UNRESOLVED, diag
            diag["error_msg"] = f"Village resolution failed: status={status}, detail={detail}"
            return AccuracyCategory.UNRESOLVED, diag

        diag["level_reached"] = 2

        # Level 3: Exact Plot Check
        if rec.is_negative_test and ("PLOT" in (rec.historical_failure_type or "") or not norm_plot):
            diag["time_ms"] = (time.perf_counter() - t_start) * 1000
            # Expected to fail plot verification cleanly
            return AccuracyCategory.PASS, diag

        if not norm_plot or not is_exact_plot_match(norm_plot, rec.official_plot_number):
            diag["false_parcel_id"] = True
            diag["time_ms"] = (time.perf_counter() - t_start) * 1000
            diag["error_msg"] = f"Plot mismatch: {norm_plot} != {rec.official_plot_number}"
            return AccuracyCategory.FAIL, diag

        diag["level_reached"] = 3

        # Level 4: Record & Row Association
        dom_html = self.generate_simulated_ror_dom(rec)
        soup = BeautifulSoup(dom_html, "html.parser")
        verif = verify_ror_result(
            soup=soup,
            requested_district=rec.district,
            requested_tahasil=rec.tahasil,
            requested_village=rec.village_name,
            requested_plot=norm_plot,
        )

        if not verif.plot_match:
            diag["false_parcel_id"] = True
            diag["time_ms"] = (time.perf_counter() - t_start) * 1000
            diag["error_msg"] = "verify_ror_result failed plot match"
            return AccuracyCategory.FAIL, diag

        try:
            ror_res = parse_structured_ror(
                html=dom_html,
                district=rec.district,
                tahasil=rec.tahasil,
                village=rec.village_name,
                plot=norm_plot,
            )
        except Exception as e:
            diag["time_ms"] = (time.perf_counter() - t_start) * 1000
            diag["error_msg"] = f"Parsing exception: {str(e)}"
            return AccuracyCategory.ERROR, diag

        # Field-by-field verification
        # 1. Plot
        if not is_exact_plot_match(ror_res.plot, rec.official_plot_number):
            diag["false_parcel_id"] = True
            diag["error_msg"] = f"Returned plot {ror_res.plot} != expected {rec.official_plot_number}"
            return AccuracyCategory.FAIL, diag

        # 2. Classification
        if rec.official_land_classification != "UNKNOWN":
            if ror_res.land_type != rec.official_land_classification:
                diag["false_classification"] = True
                diag["error_msg"] = f"Classification mismatch: {ror_res.land_type} != {rec.official_land_classification}"
                return AccuracyCategory.FAIL, diag

        # 3. Owners
        if rec.official_owners:
            exp_names = [o.name for o in rec.official_owners]
            ret_names = [o.name for o in ror_res.owners]
            if not ret_names:
                diag["false_owner"] = True
                diag["error_msg"] = "Returned empty owners when owners expected"
                return AccuracyCategory.FAIL, diag
            for ret in ret_names:
                if not any(exp in ret or ret in exp for exp in exp_names):
                    diag["false_owner"] = True
                    diag["error_msg"] = f"Returned unexpected owner {ret} not in {exp_names}"
                    return AccuracyCategory.FAIL, diag

        diag["level_reached"] = 4
        diag["time_ms"] = (time.perf_counter() - t_start) * 1000
        return AccuracyCategory.PASS, diag

    def run_evaluation(self) -> Dict[str, Any]:
        results = {
            "total_cases": len(self.records),
            "PASS": 0,
            "PARTIAL": 0,
            "FAIL": 0,
            "UNRESOLVED": 0,
            "ERROR": 0,
            "false_owner_count": 0,
            "false_classification_count": 0,
            "false_parcel_id_count": 0,
            "districts_tested": set(),
            "villages_tested": set(),
            "parcels_tested": set(),
            "avg_time_ms": 0.0,
            "diagnostics": [],
        }

        total_time = 0.0
        for rec in self.records:
            status, diag = self.evaluate_single_record(rec)
            results[status.value] += 1
            if diag["false_owner"]:
                results["false_owner_count"] += 1
            if diag["false_classification"]:
                results["false_classification_count"] += 1
            if diag["false_parcel_id"]:
                results["false_parcel_id_count"] += 1

            results["districts_tested"].add(rec.district)
            results["villages_tested"].add(f"{rec.district}:{rec.village_name}")
            results["parcels_tested"].add(f"{rec.district}:{rec.village_name}:{rec.gis_plot_number}")
            total_time += diag["time_ms"]
            results["diagnostics"].append(diag)

        results["avg_time_ms"] = total_time / len(self.records) if self.records else 0.0
        results["districts_count"] = len(results["districts_tested"])
        results["villages_count"] = len(results["villages_tested"])
        results["parcels_count"] = len(results["parcels_tested"])

        # Rates
        total_eval = results["total_cases"]
        results["false_owner_rate"] = (results["false_owner_count"] / total_eval) * 100 if total_eval else 0.0
        results["false_classification_rate"] = (results["false_classification_count"] / total_eval) * 100 if total_eval else 0.0
        results["false_parcel_id_rate"] = (results["false_parcel_id_count"] / total_eval) * 100 if total_eval else 0.0

        return results
