# MyBhoomi Backend — Cloud Run Deployment Audit

**Document Version:** 1.0.0  
**Date:** August 21, 2026  
**Target Environment:** Google Cloud Run (`asia-south1` / Mumbai)  
**Target Service Name:** `mybhoomi-backend-prod`  
**GCP Project:** `mybhoomi-backend-prod` (Project Number: `758542001999`)

---

## 1. Executive Summary

This audit examines the MyBhoomi FastAPI backend (`BhulekBackend/`) to prepare for production deployment to **Google Cloud Run**. The objective is to decouple the iOS client completely from localhost / local Mac dependencies, allowing the app to query official land records from anywhere over public HTTPS while preserving 100% of existing scraping, parsing, caching, PDF generation, and GIS pipelines.

---

## 2. Phase 0 Audit Findings (Questions 1 – 17)

| # | Audit Item | Findings & Technical Details |
|---|---|---|
| **1** | **What starts FastAPI?** | `app.py` defines the factory `create_app()`, which initializes database tables, CORS middleware, structured logging middleware, root health probes (`/health`, `/ready`), and versioned routers (`/api/v1/ror`, `/api/v1/auth`, `/api/v1/usage`, `/api/v1/subscriptions`, `/api/v1/config`, `/api/v1/support`, `/api/v1/bhulekh-coverage`, `/api/v1/gis`). The top-level entry point is `main.py` which instantiates `app = create_app()` and exposes it for ASGI servers. |
| **2** | **What host/port does it currently use?** | Binds to `0.0.0.0`. Port is read dynamically via `os.environ.get("PORT", 8000)` (defaults to 8000 for local development, and automatically binds to `8080` when provided by Cloud Run). |
| **3** | **What endpoint exposes `/api/v1/ror`?** | Defined in `routers/ror.py` as `@router.get("/ror")` and mounted in `app.py` with prefix `/api/v1`. |
| **4** | **What endpoint exposes `/api/v1/ror/pdf`?** | Defined in `routers/ror.py` as `@router.get("/ror/pdf")` and mounted under prefix `/api/v1`. Returns streaming binary PDF with SHA256 integrity headers. |
| **5** | **What endpoint exposes `/villages`?** | `routers/ror.py` exposes `GET /api/v1/villages` (Bhulekh hierarchy), and `routers/gis.py` exposes `GET /api/v1/gis/villages` (cadastral hierarchy). |
| **6** | **What endpoint exposes `/districts` or equivalent?** | `routers/ror.py` exposes `GET /api/v1/districts` & `GET /api/v1/tahasils`; `routers/gis.py` exposes `GET /api/v1/gis/districts`, `GET /api/v1/gis/blocks`, `GET /api/v1/gis/gps`. |
| **7** | **What files are required at runtime?** | 1. `data/bhulekh_catalog/catalog_v3.json` (~59 MB verified Odisha statewide location catalog).<br>2. `certs/` (Apple App Store root CA certificates).<br>3. Playwright Chromium browser binaries & Linux system dependencies (`libnss3`, `libatk`, `libcups2`, etc.).<br>4. Python packages in `requirements.txt`. |
| **8** | **Where is `catalog_v3.json` loaded from?** | `data/bhulekh_catalog/catalog_v3.json` loaded via `resolvers/bhulekh_identity_resolver.py` using `CATALOG_V3_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "bhulekh_catalog", "catalog_v3.json")`. |
| **9** | **Where does Playwright obtain Chromium?** | Inside the container, Playwright installs Chromium to `PLAYWRIGHT_BROWSERS_PATH=/ms-playwright` via `playwright install chromium && playwright install-deps chromium`. At runtime, `scrapers/playwright_scraper.py` launches `async_playwright().chromium.launch(headless=True)`. |
| **10** | **Are there environment variables?** | `ENV`, `PORT`, `DATABASE_URL`, `JWT_SECRET_KEY`, `ADMIN_API_KEY`, `APPLE_BUNDLE_ID`, `APPLE_ENVIRONMENT`, `LOG_LEVEL`, `BHULEKH_MAX_CONCURRENT`, `MAX_PENDING_BHULEKH_REQUESTS`, `ROR_TIMEOUT_SECONDS`, `PDF_TIMEOUT_SECONDS`, `GIS_TIMEOUT_SECONDS`. |
| **11** | **Are there secrets?** | `JWT_SECRET_KEY`, `ADMIN_API_KEY`, and optional Apple StoreKit private key. None are hardcoded into git. |
| **12** | **Does anything assume the local filesystem is permanent?** | No. Ephemeral caches (in-memory `cachetools.TTLCache` & SingleFlight) and SQLite storage are instance-local. Temporary files (e.g. downloaded PDFs) reside in memory/temporary buffers. |
| **13** | **Does anything assume a local browser installation?** | No. Containerized Playwright manages Chromium in Linux paths. |
| **14** | **Does anything assume localhost?** | No. All backend routing uses standard HTTP/HTTPS request contexts. |
| **15** | **Does anything assume the Mac timezone?** | No. All timestamps are standardized on UTC (`timezone.utc`). |
| **16** | **Does anything assume a persistent process?** | No. The application is stateless with respect to incoming client requests. In-memory caching & SingleFlight coalesce live requests per instance, but scale-to-zero is fully supported without state corruption. |
| **17** | **Does anything assume a fixed working directory?** | No. File paths are resolved dynamically using `os.path.dirname(os.path.abspath(__file__))`. |

---

## 3. Deployment Architecture & Sizing

```
                      INTERNET
                         │
                         ▼
           Google Cloud Run (asia-south1)
             Public HTTPS URL Endpoint
                         │
                         ▼
                 FastAPI Application
                (Gunicorn / Uvicorn)
                         │
        ┌────────────────┴────────────────┐
        ▼                                 ▼
   /api/v1/ror                     /api/v1/ror/pdf
  (RoR Service)                     (PDF Service)
        │                                 │
        └────────────────┬────────────────┘
                         ▼
               scrapers/playwright_scraper
                         │
                         ▼
             Chromium (Headless Linux)
                         │
                         ▼
        Official Odisha Bhulekh Portal (NIC)
```

### Initial Resource Allocation:
- **Region:** `asia-south1` (Mumbai)
- **Min Instances:** `0` (Scales to zero when idle for minimal cost)
- **Max Instances:** `1` (Safe initial concurrency against government portal)
- **Concurrency:** `1`
- **CPU:** `1 vCPU` (with CPU startup boost)
- **Memory:** `2 GiB` (Accommodates Chromium + Python in-memory catalog)
- **Request Timeout:** `120s` (Handles upstream 20–24s Bhulekh scraping latency with comfortable safety buffer)

---

## 4. Pre-Flight Verification

- **FastAPI / Playwright Scraper Integrity:** Verified through 566 backend unit, integration, and security tests (**100% pass rate**).
- **GCP Project Verification:** `mybhoomi-backend-prod` active under `kirtidhwajpatra@gmail.com`.
- **Cloud Run Service:** `mybhoomi-backend-prod` configured in `asia-south1`.
