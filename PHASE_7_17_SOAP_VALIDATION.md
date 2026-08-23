# PHASE 7.17 — SOAP RESOLVER VALIDATION REPORT
**Timestamp**: 2026-08-23T09:39:19Z  
**Investigation**: Controlled SOAP Khata Resolution Validation

---

## 1. Controlled Known-Good Parcels Test Results

| Parcel | Canonical District ID | Tahasil ID | Mouza ID | Expected Khata | SOAP Returned Khata | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Keonjhar / G_Dimbo / Plot 12 | 7 | 4 | 317 | `112` | `112` | ✅ **PASS** |
| Keonjhar / G_Dimbo / Plot 1 | 7 | 4 | 317 | `230` | `230` | ✅ **PASS** |
| Khordha / Raghunathpur Jali / Plot 333 | 20 | 2 | 359 | `538` | `538` | ✅ **PASS** |
| Bargarh / Chakuli Mosaic / Plot 647 | 15 | 1 | 61 | `277` | `277` | ✅ **PASS** |

---

## 2. SOAP Findings

- Official SOAP web methods `KhatiyanUnicode` and `PlotsUnicode` deterministically resolve parent Khatas.
- SOAP does not provide Front RoR tenant owner lists, making ASP.NET RoRView essential for full record completion.