"""
Phase 3.5 Pytest Suite: Independent Human Ground-Truth Validation
Executes evaluation against the independently grounded official validation dataset (independent_official_validation.json)
and validates zero false error rates, fail-closed handling, and historical failure resolution.
"""
import pytest
from harness.accuracy_evaluator import AccuracyEvaluator


@pytest.fixture(scope="module")
def independent_results():
    evaluator = AccuracyEvaluator(dataset_path="BhulekBackend/data/parcel_truth/independent_official_validation.json")
    return evaluator.run_evaluation()


def test_1_independent_dataset_size(independent_results):
    """Verify independent validation dataset contains between 20 and 30 high-risk cases."""
    assert 20 <= independent_results["total_cases"] <= 30


def test_2_zero_false_owner_rate_independent(independent_results):
    """Production Gate: False owner rate on independent data must be 0.0%."""
    assert independent_results["false_owner_count"] == 0
    assert independent_results["false_owner_rate"] == 0.0


def test_3_zero_false_classification_rate_independent(independent_results):
    """Production Gate: False classification rate on independent data must be 0.0%."""
    assert independent_results["false_classification_count"] == 0
    assert independent_results["false_classification_rate"] == 0.0


def test_4_zero_false_parcel_identity_rate_independent(independent_results):
    """Production Gate: False parcel identity rate on independent data must be 0.0%."""
    assert independent_results["false_parcel_id_count"] == 0
    assert independent_results["false_parcel_id_rate"] == 0.0


def test_5_zero_fails_independent(independent_results):
    """Verify zero incorrect mismatches; all cases either cleanly PASS or fail-closed as UNRESOLVED."""
    assert independent_results["FAIL"] == 0
    assert independent_results["ERROR"] == 0


def test_6_historical_failures_all_verified(independent_results):
    """Verify historical regressions (Keonjhar, Cuttack, Khurda) are all independently verified."""
    historical_cases = [d for d in independent_results["diagnostics"] if d["category"] == "HISTORICAL_REGRESSION"]
    assert len(historical_cases) >= 3
    for hc in historical_cases:
        assert hc["error_msg"] is None
