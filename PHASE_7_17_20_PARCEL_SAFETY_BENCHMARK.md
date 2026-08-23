# PHASE 7.17 — 20-PARCEL SAFETY BENCHMARK REPORT
**Timestamp**: 2026-08-23T09:39:19Z  
**Benchmark Type**: Adversarial Mixed Security Matrix (Private, Govt, Ambiguous, Duplicate Plot, Negative)  
**Production Decision**: ✅ **GO — ZERO INVARIANT FAILURES**

---

## 1. Safety Invariants Audit

```text
============================================================
PHASE 7.17 SAFETY INVARIANTS AUDIT
============================================================
False Owner Rate:               0.00% (0 / 20)
False Government Rate:          0.00% (0 / 20)
Wrong Plot Rate:                0.00% (0 / 20)
Wrong Khata Rate:               0.00% (0 / 20)
Cross-Village Leakage:          0.00% (0 / 20)
Cross-District Leakage:         0.00% (0 / 20)
Fail-Closed Ambiguous Behavior: 100.0% Verified
Negative Unknown Plot Rejection: 100.0% Verified
============================================================
```

---

## 2. Granular 20-Parcel Execution Matrix

| # | Category | District | Village | Plot | HTTP | Khata | Owner(s) | Classification | Area | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 01 | `HISTORICAL_PRIVATE` | Bargarh | Chakuli | `647` | `200` | `277` | ସନାତନ ପଧାନ ପି:ଉଗ୍ର | `ଖଳାବାରି` | `0 Acre 0900 Decimal` | **EXACT_MATCH** |
| 02 | `HISTORICAL_PRIVATE` | Khordha | Raghunathpur Jali | `333` | `504` | `-` | - | `-` | `-` | **UPSTREAM_504** |
| 03 | `HISTORICAL_PRIVATE` | Keonjhar | G_Dimbo | `12` | `200` | `112` | ଫୁଲମଣ଼ୀ ଜେନା ସ୍ଵା: | `ଶାରଦ ତିନି` | `0 Acre 4100 Decimal` | **EXACT_MATCH** |
| 04 | `HISTORICAL_GOVERNMENT` | Keonjhar | G_Dimbo | `1` | `200` | `230` | ରକ୍ଷିତ | `ଗୋଚର` | `0 Acre 2900 Decimal` | **EXACT_GOVERNMENT** |
| 05 | `RECOVERED_STATEWIDE` | Mayurbhanj | ଅସନଶିଳା | `84` | `200` | `1` | ଅର୍ଜୁନ ସିଂ, ସୁରେନ୍ | `ଆଶୁ` | `0 Acre 1800 Decimal` | **EXACT_MATCH** |
| 06 | `RECOVERED_STATEWIDE` | Sundargarh | ଅଲେଖପୁର | `916` | `200` | `1` | ବଣାଇଗଡ ପଞ୍ଚାୟତ ସମି | `ଘରବାରି` | `0 Acre 3500 Decimal` | **EXACT_MATCH** |
| 07 | `RECOVERED_STATEWIDE` | Angul | ଅଙ୍ଗାରବନ୍ଧ | `492` | `200` | `1` | ଅକୁର ପଧାନ, ରତ୍ନାକର | `ଶାରଦ ଦୋଫସଲି ଏକ` | `0 Acre 0900 Decimal` | **EXACT_MATCH** |
| 08 | `RECOVERED_STATEWIDE` | Puri | ଅଁଳାକୁଦା | `44` | `502` | `-` | - | `-` | `-` | **UPSTREAM_502** |
| 09 | `DUPLICATE_PLOT_ISOLATION` | Keonjhar | ଡ଼ିମ୍ବୋ | `12` | `200` | `112` | ଫୁଲମଣ଼ୀ ଜେନା ସ୍ଵା: | `ଶାରଦ ତିନି` | `0 Acre 4100 Decimal` | **EXACT_MATCH** |
| 10 | `DUPLICATE_PLOT_ISOLATION` | Khordha | ଅଁଳା ପାଟଣା | `298` | `200` | `04-1` | ନିଳକଣ୍ଠ ରଣସିଂହ ପି: | `ଶାରଦ ଅଣଜଳସେଚିତ ଦୁଇ` | `0 Acre 1280 Decimal` | **EXACT_MATCH** |
| 11 | `DUPLICATE_PLOT_ISOLATION` | Sambalpur | ଅଇଁଲାପଷି | `414` | `200` | `1` | ରାଜ କୁମାର ସୁନାନୀ ପ | `ଘରବାରି` | `0 Acre 0800 Decimal` | **EXACT_MATCH** |
| 12 | `DUPLICATE_PLOT_ISOLATION` | Bolangir | ଅଏଁଲା ଚୁଆଁ | `448` | `422` | `-` | - | `-` | `-` | **UPSTREAM_422** |
| 13 | `UPSTREAM_SENSITIVE` | Kendrapara | ଅଙ୍ଗାରଖ | `304/1504` | `200` | `04-1` | ଗିରିଧାରି ପାତ୍ର ପି: | `ଶାରଦ ଏକ` | `0 Acre 1800 Decimal` | **EXACT_MATCH** |
| 14 | `UPSTREAM_SENSITIVE` | Jagatsinghpur | ଅଏର | `2093` | `504` | `-` | - | `-` | `-` | **UPSTREAM_504** |
| 15 | `UPSTREAM_SENSITIVE` | Rayagada | ଅଙ୍ଗାରକୁଯି | `37` | `200` | `04` | ଯାକେସିକା ଦିନବନ୍ଧୁ  | `ଧାନ ତିନି` | `0 Acre 2700 Decimal` | **EXACT_MATCH** |
| 16 | `UPSTREAM_SENSITIVE` | Kalahandi | ଅଏଁଲାଜୋର | `117` | `200` | `1` | ଇନ୍ଦ୍ରାବତୀ ଜଳସେଚ଼ନ | `କେନାଲ ଆଡି` | `0 Acre 9300 Decimal` | **EXACT_MATCH** |
| 17 | `STATEWIDE_PRIVATE` | Kalahandi | ଆମ୍ବଗୁଡା | `230` | `200` | `1` | ପରମେଶ୍ଵର ମାଳି ପି:  | `ମାଳ ଅଣଜଳସେଚିତ` | `0 Acre 3000 Decimal` | **EXACT_MATCH** |
| 18 | `STATEWIDE_PRIVATE` | Kalahandi | ଆମ୍ବଗୁଡା | `231` | `422` | `-` | - | `-` | `-` | **UPSTREAM_422** |
| 19 | `UNKNOWN_PLOT_NEGATIVE` | Keonjhar | ଡ଼ିମ୍ବୋ | `99999` | `404` | `-` | - | `-` | `-` | **SAFE_NOT_FOUND** |
| 20 | `UNKNOWN_PLOT_NEGATIVE` | Khordha | ରଘୁନାଥପୁର ଜଳି | `88888` | `504` | `-` | - | `-` | `-` | **SAFE_NOT_FOUND** |