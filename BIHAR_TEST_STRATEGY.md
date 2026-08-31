# Bihar Land Records Test Strategy & Quality Assurance Matrix

## 1. Overview & Test Principles

The Bihar testing strategy enforces deterministic quality, strict schema compliance, and zero regression risk for existing Odisha operations. All test suites follow three fundamental principles:
1. **100% Offline CI/CD Compatibility**: Unit and contract tests must never execute live network requests against upstream government portals during standard CI runs.
2. **Deterministic Golden Fixtures**: Parsers and normalizers are validated against static, sanitized HTML and JSON snapshots.
3. **Total State Isolation**: Bihar test execution must never touch or pollute Odisha test caches, databases, or rate-limiter buckets.

---

## 2. Test Suite Architecture

```
BhulekBackend/tests/bihar/
├── __init__.py
├── fixtures/
│   ├── jamabandi_single_owner.html
│   ├── jamabandi_multiple_owners.html
│   ├── jamabandi_traditional_units_bigha.html
│   ├── jamabandi_mutation_history.html
│   ├── jamabandi_empty_result.html
│   ├── jamabandi_captcha_challenge.html
│   ├── khatian_survey_slip.html
│   └── expected_normalized_responses.json
├── test_bihar_jamabandi_parser.py       (HTML table extraction & unit parsing)
├── test_bihar_normalizer.py             (Bigha/Katha/Dhur to Decimal conversion & relations)
├── test_bihar_provider_contract.py      (RoRResponse schema compliance)
├── test_bihar_service_caching.py        (Verified TTLCache, Negative Cache & SingleFlight)
├── test_bihar_concurrency_and_limits.py (Semaphore bounds, rate limits & resource cleanup)
├── test_bihar_error_resilience.py       (Timeouts, 503 circuit breakers & empty searches)
└── test_bihar_isolation.py              (Verifies Odisha remains untouched & functional)
```

---

## 3. Detailed Test Matrix

| Test Suite Category | Test Case ID | Test Description | Assertions & Expected Outcome |
| :--- | :--- | :--- | :--- |
| **Parser Tests** | `BIHAR-PARSE-001` | Parse single-owner Jamabandi Register-II slip | `len(owners) == 1`, `khata == "78"`, `plot == "245"`, area correctly parsed. |
| | `BIHAR-PARSE-002` | Parse multi-owner joint tenancy slip with relations | Correct array of `OwnerEntry` objects with distinct `relation_name` values. |
| | `BIHAR-PARSE-003` | Parse complex land types (Bhit, Dhanhar, Gairmajarua) | `land_type` accurately categorized; statutory tenures detected. |
| | `BIHAR-PARSE-004` | Parse traditional land units (बीघा-कट्ठा-धूर) | Raw traditional units preserved in `remarks`/`raw_fields`; decimal area normalized. |
| | `BIHAR-PARSE-005` | Parse boundary data (चौहद्दी) and mutation history | Boundaries populated in `raw_fields["boundary_north/south/east/west"]`. |
| **Normalization Tests** | `BIHAR-NORM-001` | Convert Bigha-Katha-Dhur to standard Acre/Decimal | Mathematical conversion verified against standard revenue conversion formula. |
| | `BIHAR-NORM-002` | Hindi relation normalizer (`पिता:`, `पति:`, `स्व:`) | Maps cleanly to `"Father"`, `"Husband"`, and flags deceased predecessors. |
| | `BIHAR-NORM-003` | Thana & Mauza string cleaner | Strips trailing whitespace, brackets, and isolates pure village name and Thana ID. |
| **Error Handling Tests**| `BIHAR-ERR-001` | Handle empty / record not found response | Returns `success=False`, `RoRErrorCode.PLOT_NOT_FOUND`, `retryable=False`. |
| | `BIHAR-ERR-002` | Handle upstream timeout / gateway error (HTTP 504) | Returns `RoRErrorCode.BHULEKH_TIMEOUT`, `retryable=True`. |
| | `BIHAR-ERR-003` | Handle dynamic Captcha challenge | Triggers scraper retry or fail-closed `BHULEKH_TEMPORARILY_UNAVAILABLE`. |
| | `BIHAR-ERR-004` | Handle invalid plot characters / SQL injection attempt | HTTP 400 Bad Request before calling scraper or database. |
| **Cache & SingleFlight**| `BIHAR-CACHE-001`| Consecutive identical plot lookups | First request scrapes/parses; second request hits TTLCache with `< 5ms` latency. |
| | `BIHAR-CACHE-002`| Negative caching for confirmed non-existent plots | Subsequent lookups within 5 min return negative cache hit without scraping. |
| | `BIHAR-COALESCE-001`| 10 concurrent requests for same Bihar plot | SingleFlight coalesces 10 requests into exactly 1 upstream execution. |
| **Concurrency & Semaphores**| `BIHAR-CONC-001` | Exceeding `BIHAR_MAX_CONCURRENT_SCRAPES` limit | Queue manages excess gracefully without memory leaks or unhandled rejections. |
| | `BIHAR-CLEANUP-001`| Browser context cleanup upon exception | Playwright browser page/context explicitly closed in `finally` block. |
| **Isolation Tests** | `BIHAR-ISOL-001` | Bihar flag disabled (`BIHAR_PROVIDER_ENABLED=false`)| Bihar requests return HTTP 503; Odisha requests execute with 100% success. |
| | `BIHAR-ISOL-002` | Bihar cache isolation | Modifying or flushing Bihar cache does not alter Odisha cached records. |

---

## 4. Golden Fixture Strategy

Sanitized golden fixtures are maintained in `tests/bihar/fixtures/`:
1. **Sanitization Protocol**: All names, telephone numbers, Aadhaar tokens, and personal identifiers in HTML snapshots are scrubbed and replaced with generic placeholder values (`SAMPLE_TENANT_A`, `SAMPLE_GUARDIAN_X`).
2. **Snapshot Coverage**:
   - `jamabandi_single_owner.html`: Clean single-owner Register-II table.
   - `jamabandi_joint_tenancy.html`: Joint family tenancy with 5+ Raiyats.
   - `jamabandi_traditional_units.html`: Area given in Bigha, Katha, Dhur.
   - `jamabandi_government_land.html`: Gairmajarua Aam / Khas land with no private Raiyat.
   - `jamabandi_not_found.html`: Standard "कोई रिकॉर्ड नहीं मिला" upstream response.

---

## 5. Real Data Validation Plan (Phase 8 Execution)

Before enabling Bihar in any staging environment, a rigorous real-world validation exercise will be conducted across a curated benchmark of **30 representative Bihar records**:

### Target Sample Distribution:
- **Districts Covered (Minimum 5)**: Patna, Gaya, Muzaffarpur, Bhagalpur, Darbhanga.
- **Anchal/Circle Types**: Sadar urban circles and rural blocks.
- **Land Classifications**: Bhit-1, Bhit-2, Dhanhar, Makan, Gairmajarua (Govt).
- **Tenancy Varieties**: Single titleholder, multi-party joint holding, partitioned holdings.
- **Area Formats**: Acre/Decimal formats and Bigha/Katha/Dhur traditional units.

### Real Record Comparison Protocol:
For every record in the validation batch:
1. **Manual Reference Extraction**: The record is manually inspected on `biharbhumi.bihar.gov.in`.
2. **Automated Pipeline Extraction**: The record is processed through `BiharRoRService`.
3. **Field-by-Field Audit**:
   - Titleholder Name match (100% character / phonetic concordance)
   - Khata & Khesra Number exact match
   - Area mathematical equivalence ($\pm 0.001$ acre)
   - Rent/Lagan calculation concordance
4. **Accuracy Threshold**: $\ge 99\%$ concordance required across all 30 validation records before provider certification.
