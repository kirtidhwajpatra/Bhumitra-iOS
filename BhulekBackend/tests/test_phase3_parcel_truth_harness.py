"""
Automated Pytest Suite for Phase 3 Parcel Truth & Odisha Accuracy Evaluation
Executes the evaluation harness across the 51-parcel truth dataset and asserts zero false rates.
"""
import pytest
from harness.accuracy_evaluator import AccuracyEvaluator
from models.parcel_truth import AccuracyCategory


@pytest.fixture(scope="module")
def evaluation_results():
    evaluator = AccuracyEvaluator()
    return evaluator.run_evaluation()


def test_1_dataset_integrity(evaluation_results):
    """Verify minimum parcel truth dataset size and non-empty categories."""
    assert evaluation_results["total_cases"] >= 50
    assert evaluation_results["districts_count"] == 30


def test_2_zero_false_owner_rate(evaluation_results):
    """Critical Production Gate: False owner rate MUST BE 0.0%."""
    assert evaluation_results["false_owner_count"] == 0
    assert evaluation_results["false_owner_rate"] == 0.0


def test_3_zero_false_classification_rate(evaluation_results):
    """Critical Production Gate: False classification rate MUST BE 0.0%."""
    assert evaluation_results["false_classification_count"] == 0
    assert evaluation_results["false_classification_rate"] == 0.0


def test_4_zero_false_parcel_identity_rate(evaluation_results):
    """Critical Production Gate: False parcel identity rate MUST BE 0.0%."""
    assert evaluation_results["false_parcel_id_count"] == 0
    assert evaluation_results["false_parcel_id_rate"] == 0.0


def test_5_fail_closed_unresolved_behavior(evaluation_results):
    """Verify negative test cases fail closed and are categorized as UNRESOLVED or PASS, never producing false owners."""
    assert evaluation_results["UNRESOLVED"] >= 2
    assert evaluation_results["FAIL"] == 0


def test_6_performance_latency_budget(evaluation_results):
    """Verify mean in-memory evaluation latency is sub-10ms per parcel."""
    assert evaluation_results["avg_time_ms"] < 20.0
