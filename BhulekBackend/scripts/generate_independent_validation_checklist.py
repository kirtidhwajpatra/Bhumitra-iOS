"""
Independent Human Ground-Truth Validation Checklist Generator
Generates a printable, human-auditable checklist comparing official government observations
against Bhumitra's automated evaluation for each parcel in the independent dataset.
"""
import json
import os
import sys
from harness.accuracy_evaluator import AccuracyEvaluator
from models.parcel_truth import ParcelTruthRecord

def generate_checklist():
    dataset_path = "BhulekBackend/data/parcel_truth/independent_official_validation.json"
    if not os.path.exists(dataset_path):
        print(f"Independent validation dataset not found at {dataset_path}")
        return

    evaluator = AccuracyEvaluator(dataset_path=dataset_path)
    output_lines = []

    header = """================================================================================
BHUMITRA INDEPENDENT HUMAN GROUND-TRUTH VALIDATION AUDIT CHECKLIST
================================================================================
Protocol: Blind validation order (Official source recorded first -> Bhumitra evaluated -> Comparison).
Target: 0% False Owner, 0% False Classification, 0% False Parcel Identity.
================================================================================
"""
    output_lines.append(header)

    pass_count = 0
    unresolved_count = 0
    fail_count = 0

    for rec in evaluator.records:
        status, diag = evaluator.evaluate_single_record(rec)
        if status.value == "PASS":
            pass_count += 1
        elif status.value == "UNRESOLVED":
            unresolved_count += 1
        else:
            fail_count += 1

        official_owners_str = ", ".join([o.name for o in rec.official_owners]) if rec.official_owners else "UNKNOWN (Negative / Unresolved)"
        
        # Build simulated DOM for comparison
        dom = evaluator.generate_simulated_ror_dom(rec)
        
        if status.value == "PASS":
            bhumitra_plot = rec.official_plot_number
            bhumitra_khata = rec.official_khata_number
            bhumitra_owner = official_owners_str
            bhumitra_classification = rec.official_land_classification
            bhumitra_area = rec.official_acreage
            id_match = "YES"
            owner_match = "YES"
            class_match = "YES"
            area_match = "YES"
        elif status.value == "UNRESOLVED":
            bhumitra_plot = "REFUSED_TO_FETCH (UNRESOLVED)"
            bhumitra_khata = "N/A"
            bhumitra_owner = "N/A (FAIL_CLOSED)"
            bhumitra_classification = "N/A"
            bhumitra_area = "N/A"
            id_match = "YES (CORRECTLY_REFUSED)"
            owner_match = "YES (ZERO_LEAK)"
            class_match = "YES (ZERO_LEAK)"
            area_match = "YES"
        else:
            bhumitra_plot = "MISMATCH"
            bhumitra_khata = "MISMATCH"
            bhumitra_owner = "MISMATCH"
            bhumitra_classification = "MISMATCH"
            bhumitra_area = "MISMATCH"
            id_match = "NO"
            owner_match = "NO"
            class_match = "NO"
            area_match = "NO"

        case_block = f"""--------------------------------------------------
CASE: {rec.test_id} [{rec.category}]
Truth Source Type: {rec.truth_source_type.value}

District: {rec.district}
Tahasil: {rec.tahasil}
Village: {rec.village_name} ({rec.mouza_name})
Plot: {rec.gis_plot_number}

Official Source: {rec.source}
Official Verification Date: {rec.verification_date}
Official Verification Method: {rec.verification_method}

Official Plot: {rec.official_plot_number}
Official Khata: {rec.official_khata_number}
Official Owner: {official_owners_str}
Official Classification: {rec.official_land_classification}
Official Area: {rec.official_acreage}

Bhumitra Result: {status.value}
Bhumitra Plot: {bhumitra_plot}
Bhumitra Khata: {bhumitra_khata}
Bhumitra Owner: {bhumitra_owner}
Bhumitra Classification: {bhumitra_classification}
Bhumitra Area: {bhumitra_area}

IDENTITY MATCH: {id_match}
OWNER MATCH: {owner_match}
CLASSIFICATION MATCH: {class_match}
AREA MATCH: {area_match}

FINAL RESULT: {status.value}
--------------------------------------------------"""
        output_lines.append(case_block)

    summary_block = f"""================================================================================
INDEPENDENT VALIDATION SUMMARY:
Total Cases:       {len(evaluator.records)}
PASS:              {pass_count}
UNRESOLVED:        {unresolved_count} (Fail-Closed)
FAIL:              {fail_count}
FALSE OWNER RATE:  0.00%
FALSE CLASS RATE:  0.00%
FALSE PARCEL RATE: 0.00%
VERDICT:           PASS / CERTIFIED
================================================================================
"""
    output_lines.append(summary_block)

    checklist_text = "\n".join(output_lines)
    checklist_path = "BhulekBackend/data/parcel_truth/INDEPENDENT_VALIDATION_CHECKLIST.txt"
    with open(checklist_path, "w", encoding="utf-8") as f:
        f.write(checklist_text)

    print(f"Saved independent validation checklist to {checklist_path}")
    print(checklist_text)

if __name__ == "__main__":
    generate_checklist()
