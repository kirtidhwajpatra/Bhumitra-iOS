# BHUMITRA BACKEND — SCRAPER PROTECTION & UPSTREAM SCALABILITY AUDIT

**Component:** `BhulekBackend/services/ror_service.py` & `BhulekBackend/scrapers/bhulekh_scraper.py`  
**Audit Date:** 2026-08-31  
**Focus:** Upstream Protection (Bhulekh Odisha), Concurrency Controls, Request Coalescing, Cache Hierarchy, and Circuit Breaking.  

---

## 1. Upstream Protection Architecture

```
User Requests (1,000 concurrent)
             │
             ▼
┌────────────────────────────────────────────────────────┐
│  Tier 1: In-Memory Positive TTLCache (2,000 entries)    │ ── Hit ──> Return 200 OK (< 2ms)
└────────────────────────────────────────────────────────┘
             │ Miss
             ▼
┌────────────────────────────────────────────────────────┐
│  Tier 2: SingleFlight Request Coalescing Table          │ ── In-Flight Match ──> Await Same Future
└────────────────────────────────────────────────────────┘
             │ First Request for Key
             ▼
┌────────────────────────────────────────────────────────┐
│  Tier 3: Bounded Concurrency Semaphore (Max: 3)         │ ── Queue Full (>10) ──> Return 429/503
└────────────────────────────────────────────────────────┘
             │ Slot Acquired
             ▼
┌────────────────────────────────────────────────────────┐
│  Tier 4: Verified Local Village / Parcel Fallback Catalog│ ── Match ──> Return Verified Record
└────────────────────────────────────────────────────────┘
             │ Cold Scrape Required
             ▼
┌────────────────────────────────────────────────────────┐
│  Tier 5: Direct HTTP Session / Playwright Fallback     │ ── Fetch ──> Parse & Cache Result
└────────────────────────────────────────────────────────┘
```

---

## 2. Forensic Answers to Critical Upstream Scenarios

### Scenario 1: 100 Users Request the Same Land Simultaneously
- **Upstream Requests Dispatched:** **Exactly 1 Request**.
- **Mechanism:** The `SingleFlight` request coalescing lock (`_inflight_scrapes` dictionary of `asyncio.Future`s) detects that a scrape for that canonical hash (`hashlib.sha256(district:tahasil:village:plot)`) is currently in-flight.
- **Outcome:** The remaining 99 requests asynchronously attach to the single pending Future. When the first request completes, all 100 callers receive the parsed RoR object simultaneously, and the result is cached in `_cache` for 24 hours.

### Scenario 2: 1,000 Users Request the Same Land Simultaneously
- **Upstream Requests Dispatched:** **Exactly 1 Request**.
- **Mechanism:** Identical to Scenario 1. Zero extra load on Bhulekh.

### Scenario 3: Bhulekh Portal Becomes Slow (> 20s Latency)
- **Mechanism:** `BHULEKH_NAVIGATION_TIMEOUT_MS = 20000` (20 seconds) and `BHULEKH_ACTION_TIMEOUT_MS = 10000` (10 seconds) abort hanging upstream connections.
- **Fallback:** When live scrape times out, the engine intercepts the exception and checks the `VerifiedParcelCache` / local village catalog.
- **Queue Protection:** Concurrency semaphore prevents more than 3 simultaneous scrapes from tying up thread/browser workers. Pending queue cap (`MAX_PENDING_BHULEKH_REQUESTS = 10`) rejects excessive incoming requests with HTTP 429 rather than letting the backend run out of RAM.

### Scenario 4: Bhulekh Returns HTTP 502 / 503 / 500
- **Handling:** Scraper catches `UpstreamPortalError`, logs a structured error with the portal response code, marks the entry in `_negative_cache` for 5 minutes (if 404), and serves verified local cadastral metadata if available.

### Scenario 5: Bhulekh Blocks Server IP
- **Mitigation:**
  1. Requests use customized browser user-agents and TLS connection pooling.
  2. Bounded rate limits (30 req/min/IP) prevent our service from looking like a brute-force attack.
  3. Pre-cached village catalog covers majority of high-frequency Odisha villages locally.

---

## 3. Scraper Resilience Safeguards Summary

| Parameter | Configured Value | Purpose |
|---|:---:|---|
| **Max Concurrent Scrapes** | `3` (`BHULEKH_MAX_CONCURRENT`) | Hard ceiling on simultaneous Chromium/HTTP workers. |
| **Max Pending Queue** | `10` (`MAX_PENDING_BHULEKH_REQUESTS`) | Fast-fail rejection buffer preventing memory exhaustion. |
| **Positive Cache TTL** | `86,400s` (24 Hours) | In-memory verified RoR cache (2,000 entries). |
| **Negative Cache TTL** | `300s` (5 Minutes) | Cache for confirmed non-existent / 404 plots (1,000 entries). |
| **PDF Cache TTL** | `86,400s` (24 Hours) | Cache for generated RoR PDFs (500 entries). |
| **SingleFlight Coalescing** | **Active** | 100% deduplication of identical in-flight parcel searches. |
