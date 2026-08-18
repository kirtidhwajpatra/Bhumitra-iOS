# Phase 3.25 — Unified RoR Pipeline Verification Report

## 1. Executive Summary
- **Total Test Cases**: 6
- **Live Verified Successes**: **6 / 6 (100.0%)**
- **Manual Search Path**: **100% LIVE_VERIFIED_SUCCESS**
- **Map Selection Path**: **100% LIVE_VERIFIED_SUCCESS**
- **Cross-Flow Identity Parity**: **Confirmed Identical**

## 2. Scorecard: Manual Search vs Map Selection
| Flow | Case Name | Location | Plot | Khata | Owners | PDF Valid | Latency | Status |
|---|---|---|---|---|---|---|---|---|
| `MANUAL_SEARCH` | Manual Search: Keri (330) / Plot 1050 | KEONJHAR/KEONJHAR SADAR/କେରି | 1050 | 139/57 | 3 (Redacted) | True | 22.75s | `LIVE_VERIFIED_SUCCESS` |
| `MAP_SELECTION` | Map Selection: G_Keri 271 / Plot 1050 | KEONJHAR/KEONJHAR SADAR/G_Keri 271 | 1050 | 139/57 | 3 (Redacted) | True | 22.31s | `LIVE_VERIFIED_SUCCESS` |
| `MANUAL_SEARCH` | Manual Search: Dimbo (317) / Plot 489 | KEONJHAR/KEONJHAR SADAR/ଡ଼ିମ୍ବୋ | 489 | 212 | 3 (Redacted) | True | 22.50s | `LIVE_VERIFIED_SUCCESS` |
| `MAP_SELECTION` | Map Selection: G_Dimbo / Plot 489 | KEONJHAR/KEONJHAR SADAR/G_Dimbo | 489 | 212 | 3 (Redacted) | True | 23.73s | `LIVE_VERIFIED_SUCCESS` |
| `MAP_SELECTION` | Map Selection: G_Dimbo / Plot 12 | KEONJHAR/KEONJHAR SADAR/G_Dimbo | 12 | 112 | 18 (Redacted) | True | 23.74s | `LIVE_VERIFIED_SUCCESS` |
| `MAP_SELECTION` | Map Selection: Anantapur-64 / Plot 101 | CUTTACK/ATHAGARH/Anantapur-64 | 101 | 125/110 | 3 (Redacted) | True | 23.39s | `LIVE_VERIFIED_SUCCESS` |