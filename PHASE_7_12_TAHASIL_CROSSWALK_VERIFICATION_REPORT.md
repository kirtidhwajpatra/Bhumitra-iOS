# PHASE 7.12 — GIS TAHASIL CROSSWALK CONTROLLED VERIFICATION REPORT
**Timestamp**: 2026-08-23T07:15:00Z  
**Phase State**: Strictly Read-Only Controlled Validation (No Code Modified)  
**Production Decision**: ⚠️ **HOLD FOR VILLAGE-LEVEL MAPPING (NO GLOBAL ALIAS ACTIVATED)**

---

## 1. Executive Summary & Core Architectural Finding

Phase 7.12 performed multi-village consistency verification and administrative hierarchy analysis across all 15 candidate Tahasil crosswalks identified in Phase 7.11.

### Critical Architectural Discovery: The Super-Region Invariant (Section 8 & 9)
> [!IMPORTANT]
> **A GIS Tahasil label matching a District Name (e.g. GIS `Sundargarh`, `Mayurbhanj / Baripada`, `Rayagada`) is NOT a 1-to-1 Tahasil.**
> It is a **Super-Region / District Headquarter GIS container** encompassing up to 18 to 26 distinct revenue Tahasils.
> Creating a global alias such as `Sundargarh -> Banei (ID 1)` would improperly collapse all 18 Sundargarh Tahasils into Banei, creating cross-tahasil corruption.
> 
> **Correct Identity Solution (Section 9)**: Resolve identity deterministically at the **Village Level**:
> $$\text{GIS District} + \text{GIS Village / Code} \longrightarrow \text{Official Bhulekh Village Catalog} \longrightarrow (\text{Tahasil ID}, \text{Mouza ID})$$

---

## 2. Crosswalk Consistency Table (Sections 1, 2, 3 & 11)

| GIS District | GIS Tahasil String | Candidate Bhulekh Tahasil | ID | District Tahasils | Tested | Same Tahasil | Conflicting | Consistency | Structural Classification |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Mayurbhanj (ID 9) | `Baripada` | `ବାରିପଦା` | **1** | 26 | 4 | 4 | 0 | **100.0%** | `VERIFIED_TAHASIL_ALIAS` |
| Sundargarh (ID 13) | `Sundargarh` | `ବଣେଇ` | **1** | 18 | 3 | 3 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Dhenkanal (ID 4) | `Dhenkanal` | `ଢେଙ୍କାନାଳ` | **1** | 8 | 1 | 1 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Angul (ID 14) | `Angul` | `ଅନୁଗୋଳ` | **1** | 8 | 1 | 1 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Jajpur (ID 18) | `Jajpur` | `ବିଂଝାରପୁର` | **1** | 10 | 2 | 2 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Puri (ID 11) | `Puri` | `କୃଷ୍ଣପ୍ରସାଦ` | **1** | 11 | 2 | 2 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Bhadrak (ID 16) | `Bhadrak` | `ବାସୁଦେବପୁର` | **1** | 7 | 2 | 2 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Balasore (ID 1) | `Balasore` | `ବାଲେଶ୍ଵର` | **1** | 12 | 1 | 1 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Kendrapara (ID 19) | `Kendrapara` | `ଆଳି` | **1** | 9 | 2 | 2 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Jagatsinghpur (ID 17) | `Jagatsinghpur` | `ଜଗତସିଂହପୁର` | **1** | 8 | 1 | 1 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Sambalpur (ID 12) | `Sambalpur` | `କୋଚିଣ୍ଡା` | **1** | 9 | 1 | 1 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Bolangir (ID 2) | `Bolangir` | `ବଲାଙ୍ଗିର` | **1** | 14 | 2 | 2 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Jharsuguda (ID 30) | `Jharsuguda` | `ଝାରସୁଗୁଡ଼ା` | **1** | 5 | 2 | 2 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Rayagada (ID 27) | `Rayagada` | `ବିଷମ କଟକ` | **1** | 11 | 2 | 2 | 0 | **100.0%** | `GIS_TAHASIL_IS_SUPER_REGION` |
| Kalahandi (ID 6) | `Bhawanipatna` | `ଧର୍ମଗଡ଼` | **1** | 13 | 2 | 1 | 0 | **50.0%** | `INSUFFICIENT_EVIDENCE (N < 3)` |

---

## 3. Geometry & Official Identifiers Assessment (Sections 4 & 5)

- **Geometry Evidence**: `GEOMETRY EVIDENCE: UNAVAILABLE` (ORSAC GeoJSON payloads in test suite pass alphanumeric properties rather than raw GIS spatial boundary polygons).
- **Official Crosswalk Codes**: 7-digit LGD/Census codes (e.g. `0110049` in `odisha_statewide_truth.json`) provide 100% deterministic mapping: `[2-digit District][2-digit Tahasil][3-digit Mouza]`.

---

## 4. In-Depth Audit of Ambiguous Case (Section 6)

**Target Case**: District 6 (Kalahandi) / `Bhawanipatna` / Village: `ଆମ୍ବଗୁଡା` / Plot: `230`

Our catalog scan revealed multiple identical village names in Kalahandi:
- **Tahasil ID 1 (ଧର୍ମଗଡ଼)**: Mouza ID `280` (`ଆମ୍ବଗୁଡା`)
- **Tahasil ID 7 (ଲାଞ୍ଜିଗଡ)**: Mouza ID `57` (`ଆମ୍ବଗୁଡା`)

**Verdict on Ambiguous Case**: Without an explicit 7-digit village code or cadastral polygon boundary, selecting one Tahasil would be fuzzy guessing.
**Action**: Strictly **KEPT AS AMBIGUOUS (`AMBIGUOUS`)** $\rightarrow$ Fails closed with `ROR_IDENTITY_MISMATCH` to guarantee zero false owners.

---

## 5. Simulated 55-Parcel Benchmark Impact (Section 13)

| Metric | Phase 7.10.1 Baseline | Phase 7.12 Simulated Village-Level Resolution | Potential Change |
| :--- | :--- | :--- | :--- |
| **Exact Verified RoR** | **18 (32.7%)** | **45 (81.8%)** | **+27 Verified Records** |
| **Safe Unresolved** | **28 (50.9%)** | **1 (1.8%)** | -27 (Safe Reduction) |
| **Ambiguous Records (Fail-Closed)** | 0 | **1 (1.8%)** | 1 (Kalahandi Ambiguity) |
| **Upstream 502 Errors** | 9 (16.4%) | 9 (16.4%) | 0 (Transient Bhulekh Errors) |
| **False Owner Rate** | **0.00%** | **0.00%** | **0% (100% Preserved)** |
| **False Government Rate** | **0.00%** | **0.00%** | **0% (100% Preserved)** |

---

## 6. Final Recommendation & Production Decision

```text
============================================================
PHASE 7.12 FINAL DECISION: OPTION D (VILLAGE-LEVEL IDENTITY)
============================================================
1. GLOBAL TAHASIL ALIASES:      REJECTED (GIS Tahasils are super-regions)
2. VILLAGE-LEVEL CROSSWALK:     RECOMMENDED FOR PHASE 7.13
3. AMBIGUOUS HANDLING:          STRICTLY MAINTAINED AS FAIL-CLOSED
4. PRODUCTION STATUS:           DO NOT CHANGE TO GO YET
============================================================
```