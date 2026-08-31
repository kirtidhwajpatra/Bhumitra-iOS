# Bihar Production Isolation & Scalability Architecture

## 1. Zero-Blast-Radius Guarantee

The core mandate for Bihar integration is absolute operational isolation: **Any failure, degradation, slowdown, or crash in the Bihar provider pipeline must have zero impact on Odisha production operations, authentication, StoreKit payments, or server-authoritative credit systems.**

---

## 2. Isolation Boundaries & Failure Safeguards

```
                                 [ Incoming Request ]
                                          │
                        ┌─────────────────┴─────────────────┐
                        ▼                                   ▼
              ┌───────────────────┐               ┌───────────────────┐
              │   ODISHA FLOW     │               │    BIHAR FLOW     │
              │  (State=ODISHA)   │               │   (State=BIHAR)   │
              └─────────┬─────────┘               └─────────┬─────────┘
                        │                                   │
      ┌─────────────────┴─────────────────┐       ┌─────────┴─────────────────┐
      ▼                                   ▼       ▼                           ▼
┌──────────────┐                 ┌──────────────┐ ┌──────────────┐     ┌──────────────┐
│ Odisha Cache │                 │ Odisha Queue │ │ Bihar Cache  │     │ Bihar Queue  │
│  (TTLCache)  │                 │ (Semaphore=6)│ │ (TTLCache)   │     │ (Semaphore=3)│
└──────────────┘                 └──────┬───────┘ └──────────────┘     └──────┬───────┘
                                        │                                     │
                                 ┌──────▼───────┐                      ┌──────▼───────┐
                                 │ Odisha Scraper│                     │ Bihar Scraper│
                                 │ (Playwright) │                      │ (Isolated)   │
                                 └──────────────┘                      └──────────────┘
```

| Threat Scenario | Potential Impact on Odisha if Shared | Isolation Safeguard Implemented |
| :--- | :--- | :--- |
| **Upstream Bihar Portal Outage / Slowness** | Scraper pool starvation, high response latencies. | **Separate Concurrency Semaphores**: Odisha is governed by `_odisha_semaphore` (capacity 6); Bihar is bounded by `_bihar_semaphore` (capacity 3). Bihar delays cannot starve Odisha concurrency slots. |
| **Playwright Browser Crash** | All in-flight requests dropped, process crash. | **Isolated Browser Contexts**: Bihar scraping runs in ephemeral browser contexts with isolated memory allocations and independent lifecycle teardowns. |
| **Cache Key Collisions** | Odisha users receiving Bihar land records or vice-versa. | **Namespaced Cache Keys**: Bihar cache keys use the strict prefix `bihar:ror:{dist}:{anchal}:{mauza}:{plot}` completely disjoint from Odisha's `ror:{d_id}:{t_id}:...`. |
| **Database Lock / Latency Contention** | Delayed credit verification or user authentication. | **Read-Only / State-Agnostic DB Operations**: RoR lookups do not execute write locks against `users` or `subscriptions` tables. Credit decrements use atomic PostgreSQL updates. |
| **StoreKit / Credit Subsystem Contention** | Users failing to consume purchased search credits. | **Shared Auth/Billing Decoupling**: Billing, App Store server notifications, and credit ledgers remain completely isolated from individual state provider implementations. |
| **Memory Leak in Scraper** | Pod Out-Of-Memory (OOM) termination on Cloud Run. | **Aggressive Resource Teardowns**: Scraper pages and contexts are destroyed in strict `finally` blocks, with strict memory ceilings monitored via Cloud Run container limits. |

---

## 3. Scalability & Upstream Protection Design

1. **Conservative Concurrency Limits**:
   - `BIHAR_MAX_CONCURRENT_SCRAPES = 3`
   - Prevents overwhelming upstream government servers (`biharbhumi.bihar.gov.in`), protecting our backend IPs from anti-bot blocking or Cloudflare/NIC rate-limiting.
2. **SingleFlight Request Coalescing**:
   - Duplicate concurrent requests for the exact same Bihar parcel are coalesced into a single active upstream fetch using `asyncio.Future`. 
   - 50 simultaneous user queries for Plot 245 in Village X result in exactly 1 upstream fetch.
3. **Multi-Tier Caching Architecture**:
   - **L1 Verified TTLCache**: 24-hour TTL for successful parsed records (max 2,000 entries).
   - **L2 Negative TTLCache**: 5-minute TTL for confirmed `PLOT_NOT_FOUND` results to prevent repeated scraping of erroneous inputs.
4. **Upstream Circuit Breaker**:
   - If 5 consecutive requests to Biharbhumi encounter connection timeouts or CAPTCHA enforcement, the Bihar provider automatically transitions to `CIRCUIT_OPEN` for 300 seconds.
   - During `CIRCUIT_OPEN`, requests immediately fail fast with `RoRErrorCode.BHULEKH_TEMPORARILY_UNAVAILABLE` without allocating scraper or thread resources.

---

## 4. Emergency Instant Kill-Switch Playbook

If any unforeseen instability occurs in Bihar services:

1. **Step 1 — Disable Environment Variable**:
   Set `BIHAR_PROVIDER_ENABLED=false` in the backend environment configuration.
2. **Step 2 — Immediate Routing Response**:
   All `/api/v1/ror?state=BIHAR` requests instantly return HTTP 503 (`STATE_PROVIDER_DISABLED`) in `< 1ms` with zero scraper invocation.
3. **Step 3 — Odisha Unaffected**:
   Odisha endpoints continue processing requests normally with zero downtime or degradation.
