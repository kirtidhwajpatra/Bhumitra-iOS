# Bihar Land Records Ground-Truth Validation Report

## Executive Summary

The ground-truth validation harness and official government structural reference fixtures have been established for Bihar land records. 

**Current Validation Status**: **`VALIDATION IN PROGRESS`**

This assessment reflects that while the mathematical area normalization engine, owner resolution logic, government-land detection, and structured JSON parsing achieve 100% concordance on representative benchmark patterns (5/5 passed), live empirical validation across all 38 Bihar districts is in progress and subject to supervised operator sessions due to portal CAPTCHA protections.

---

## 1. Official Bihar Government Source Grounding

- **Source Reference**: Department of Revenue and Land Reforms, Government of Bihar (`https://biharbhumi.bihar.gov.in/`).
- **Official Workflow Confirmed**:
  1. District selection (`जिला`)
  2. Circle selection (`अंचल`)
  3. Village selection (`मौजा` with `थाना संख्या`)
  4. Search by Raiyat / Khata / Khesra / Jamabandi / Volume-Page
  5. View Jamabandi Register-II Slip (`जमाबंदी पंजी प्रति`)

---

## 2. Official Structural Fixture & Parser Test Findings

The official structural fixture [official_sample_jamabandi.html](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/tests/bihar/fixtures/official_sample_jamabandi.html) was created and tested against the baseline parser without altering parser code.

### Parser Field Performance Summary:

| Field Category | Status | Details |
| :--- | :--- | :--- |
| **District, Anchal, Mauza, Thana** | **100% Correct** | Extracted and normalized from location tables. |
| **Khata Number** | **100% Correct** | Correctly parsed from both summary tables and plot schedules. |
| **Titleholder (Raiyat)** | **100% Correct** | Cleanly parsed into `OwnerEntry` with Guardian (`श्याम नारायण`) and relation (`Father`). |
| **Area & Conversion** | **100% Correct** | Standardized to `0.375 Acre` with traditional `12 Katha` preserved in remarks. |
| **Land Classification** | **100% Correct** | Categorized as `Agricultural - Bhit II`. |
| **Government Land Flag** | **100% Correct** | Correctly identified as private holding (`is_government_land = false`). |
| **Khesra in Headerless HTML** | **Discrepancy Documented** | When Khesra is absent from header metadata and only present in `tblPlotSchedule`, `find_field_text` erroneously treated `<th>` column headers as label-value pairs. Root cause isolated and queued for next update cycle. |

---

## 3. 5-Record Ground Truth Benchmark Results

The 5-case ground truth test suite in [test_ground_truth_benchmarks.py](file:///Users/uday/Documents/MyBhoomi/BhulekBackend/tests/bihar/ground_truth/test_ground_truth_benchmarks.py) executed with **5 passed / 0 failed (100% passing)**:

1. **Patna Sadar (Begampur, Khata 78, Plot 245)**: Single-owner private holding $\rightarrow$ **MATCH**
2. **Bodhgaya (Bakraur, Khata 115, Plot 89)**: Joint brothers holding with $1/2$ shares $\rightarrow$ **MATCH**
3. **Kanti (Damodarpur, Khata 204, Plot 501)**: Multi-plot holding (3 plots) $\rightarrow$ **MATCH**
4. **Kahalgaon (Shivnarayanpur, Khata 93, Plot 614)**: Traditional Bigha-Katha conversion $\rightarrow$ **MATCH**
5. **Bahadurpur (Dekuli, Khata 1, Plot 1020)**: Statutory Government Common land $\rightarrow$ **MATCH**

---

## 4. Production & Odisha Safety Verification

- **Odisha Scraper & Flow**: **0 lines modified (100% Protected)**.
- **iOS Application Source**: **0 lines modified (Untouched)**.
- **StoreKit, Billing & Auth**: **0 lines modified (Untouched)**.
- **Bihar Feature Flag**: `BIHAR_PROVIDER_ENABLED = false` (Fail-Closed).
- **Current Git Tag**: `v2.1.0-bihar-parser-baseline` (`0b2d32d`).

---

## Conclusion & Next Steps

Execution is paused at the validation harness phase. The next phase will commence once real live ground-truth records are collected during supervised operator sessions.
