# Bihar Backend API Integration & Provider Routing Architecture

## Executive Summary

This document specifies the backend provider routing layer designed to support multi-state land records starting with Bihar, while guaranteeing **100% isolation, fail-closed feature flagging, and zero blast radius** to the production Odisha flow and iOS application.

**Integration Status**: **`BIHAR BACKEND INTEGRATION BOUNDARY READY`**
**Provider Execution Status**: **`PARTIALLY VALIDATED`** (Feature flag defaulted to `false`)

---

## 1. Provider Routing Architecture

```
                       [ Incoming API Request: /api/v1/ror ]
                                         │
                                         ▼
                 [ Common Security, Rate Limiting & Auth Layer ]
                 ├── Bearer JWT Authentication (get_optional_current_user)
                 ├── Tiered Rate Limiter (enforce_rate_limit)
                 ├── Server-Authoritative Quota (usage_service.check_ror_quota)
                 └── Input Sanitization (Length, Null-byte, Character checks)
                                         │
                                         ▼
                         [ ProviderRouter (Dispatch Layer) ]
                                         │
                    ┌────────────────────┴────────────────────┐
                    │                                         │
                    ▼ (state="BIHAR")                         ▼ (state="ODISHA" / default)
   [ Feature Flag Check: BIHAR_PROVIDER_ENABLED ]     [ Odisha RoR Service (services/ror_service.py) ]
   ├── If False: Raise 503 (Controlled Rejection)     ├── L1 Cache: 'ror:*'
   └── If True: Forward to BiharRoRService            ├── Semaphore: _scrape_semaphore (max=3)
                    │                                 ├── SingleFlight: _inflight_scrapes
                    ▼                                 └── Scraper: BhulekhScraper (Playwright)
   [ Bihar RoR Service (services/bihar_ror_service.py) ]      │
   ├── L1 Cache: 'bihar:ror:*'                                │
   ├── L2 Negative Cache: 'bihar:ror:*' (5m)                  │
   ├── Semaphore: _bihar_semaphore (max=3)                    │
   ├── SingleFlight: _bihar_inflight_scrapes                  │
   └── Scraper / Parser: BiharJamabandiParser                 │
                    │                                         │
                    └────────────────────┬────────────────────┘
                                         │
                                         ▼
                     [ Canonical Normalized RoRResponse Contract ]
                                         │
                                         ▼
                       [ Quota Increment & JSON Delivery ]
```

---

## 2. Feature Flag & Kill Switch Controls

| Parameter | Environment Variable | Default Value | Operational Purpose |
| :--- | :--- | :--- | :--- |
| **Bihar Kill Switch** | `BIHAR_PROVIDER_ENABLED` | `false` | When `false`, all Bihar requests are rejected at the router boundary with zero resource consumption. |
| **Max Concurrent Bihar** | `BIHAR_MAX_CONCURRENT` | `3` | Independent bounded semaphore protecting system memory and upstream connections. |
| **Max Pending Queue** | `BIHAR_MAX_PENDING_REQUESTS` | `10` | Rejects overflow traffic with `BHULEKH_RATE_LIMITED` to prevent queue buildup. |
| **Timeout Limit** | `BIHAR_TIMEOUT_SECONDS` | `30` | Enforces hard cap on upstream Bihar parsing requests. |

### Kill-Switch Reaction Time:
Toggling `BIHAR_PROVIDER_ENABLED=false` takes effect dynamically for the very next request. No server restart, database migration, or cache flushing is required.

---

## 3. State Selection & Backward Compatibility

- **State Parameter**: `state: Optional[str] = Query("ODISHA", description="State identifier")`.
- **Default State**: `"ODISHA"` ensures that all existing mobile clients, webhooks, and third-party integrations continue functioning without any modification.
- **Normalization**: Input is stripped and converted to uppercase (`"bihar"` $\rightarrow$ `"BIHAR"`, `"Odisha"` $\rightarrow$ `"ODISHA"`).
- **Unsupported States**: Any state other than `"ODISHA"` or `"BIHAR"` raises `RoRErrorCode.AMBIGUOUS_LOCATION` (`HTTP 422`).

---

## 4. Security, Authentication & Quota Boundaries

1. **Common Authentication**: Bearer JWT authentication and user resolution occur before provider selection. No provider code accesses raw authentication tokens or cryptographic keys.
2. **Authoritative Quotas**: `usage_service.check_ror_quota()` and `increment_ror_quota()` apply uniformly across all states. A user cannot bypass credit limits by switching states.
3. **PII Redaction**: Logs record only structural diagnostic tokens (`request_id`, `provider=bihar`, `district=PATNA`, `status=VERIFIED`). No names, phone numbers, or tokens are logged.

---

## 5. Blast-Radius Containment & Cross-Provider Isolation

| Subsystem | Odisha Subsystem | Bihar Subsystem | Cross-Talk Possible? |
| :--- | :--- | :--- | :--- |
| **Cache Storage** | `_cache` (max 2000, 24h) | `_bihar_cache` (max 2000, 24h) | **NO** (Isolated TTLCache instances) |
| **Negative Cache** | `_negative_cache` (max 1000, 5m) | `_bihar_negative_cache` (max 1000, 5m) | **NO** (Isolated TTLCache instances) |
| **Cache Keys** | `ror:{d_id}:{t_id}:{v_id}:{plot}` | `bihar:ror:{dist}:{anch}:{vill}:{plot}` | **NO** (Disjoint SHA-256 prefixes) |
| **Concurrency Lock** | `_scrape_semaphore` (max 3) | `_bihar_semaphore` (max 3) | **NO** (Independent asyncio Semaphores) |
| **Request Coalescing** | `_inflight_scrapes` | `_bihar_inflight_scrapes` | **NO** (Independent Future dictionaries) |
| **Fallback Policy** | Throws `RoRServiceException` | Throws `BiharRoRServiceException` | **NO FALLBACK** (Zero cross-state redirection) |

---

## 6. Known Limitations & Rollback Procedures

### Known Upstream Limitations:
- **Interactive CAPTCHA**: The official `biharbhumi.bihar.gov.in` portal uses dynamic CAPTCHAs. Automated live scraping without human interaction will return `CAPTCHA_REQUIRED` / `BHULEKH_TEMPORARILY_UNAVAILABLE`.
- **Legacy Jamabandi Quality**: Some manual registers digitized in rural circles lack Khata or Area. These are preserved as `None` rather than fabricated values.

### Rollback Procedures:
1. **Instant Operational Rollback**: Set `BIHAR_PROVIDER_ENABLED=false` in environment variables.
2. **Git Codebase Rollback**: Revert to tag `v2.2.0-bihar-service-layer` or stable Odisha checkpoint `v2.0.0-analytics-stable` (`dec0d1b`).
