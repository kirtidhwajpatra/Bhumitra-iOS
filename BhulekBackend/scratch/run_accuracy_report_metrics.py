"""
Runner script to execute the accuracy evaluator and display full metrics for the Phase 3 Report.
"""
from harness.accuracy_evaluator import AccuracyEvaluator
import json

def run():
    evaluator = AccuracyEvaluator()
    res = evaluator.run_evaluation()
    print("=" * 80)
    print("PHASE 3 ACCURACY EVALUATOR OUTPUT")
    print("=" * 80)
    print(f"Total Cases Evaluated:       {res['total_cases']}")
    print(f"Districts Covered:            {res['districts_count']} / 30")
    print(f"Villages Tested:              {res['villages_count']}")
    print(f"Parcels Tested:               {res['parcels_count']}")
    print(f"PASS Count:                   {res['PASS']}")
    print(f"PARTIAL Count:                {res['PARTIAL']}")
    print(f"FAIL Count:                   {res['FAIL']}")
    print(f"UNRESOLVED Count:             {res['UNRESOLVED']}")
    print(f"ERROR Count:                  {res['ERROR']}")
    print(f"False Owner Count:            {res['false_owner_count']} (Rate: {res['false_owner_rate']:.2f}%)")
    print(f"False Classification Count:   {res['false_classification_count']} (Rate: {res['false_classification_rate']:.2f}%)")
    print(f"False Parcel ID Count:        {res['false_parcel_id_count']} (Rate: {res['false_parcel_id_rate']:.2f}%)")
    print(f"Average Evaluation Time:      {res['avg_time_ms']:.3f} ms")
    print("=" * 80)

if __name__ == "__main__":
    run()
