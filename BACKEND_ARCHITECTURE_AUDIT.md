# BHUMITRA BACKEND — ARCHITECTURE & SUBSYSTEM INVENTORY AUDIT

**Target:** `BhulekBackend` (FastAPI / Python 3.11 / PostgreSQL / Playwright / Uvicorn)  
**Audit Date:** 2026-08-31  
**Scope:** Architecture, Routers, Middleware, DB Sessions, Scrapers, Caches, Workers, and Rate Limiters.  

---

## 1. Core Framework & Architecture
- **Framework:** FastAPI (ASGI asynchronous web framework).
- **ASGI Server:** Uvicorn running behind Nginx / Cloud Run.
- **Database Engine:** PostgreSQL via SQLAlchemy 2.0 ORM with connection pooling (`pool_size=10, max_overflow=20`).
- **Data Serialization:** Pydantic V2 models with strict type validation.
- **Asynchronous Loop:** Asyncio event loop with non-blocking I/O.

---

## 2. API Routers & Versioned Endpoints (`/api/v1`)

| Router | Prefix | Key Endpoints | Purpose & Protection |
|---|---|---|---|
| `health.py` | `/` | `GET /health`, `GET /ready` | Unauthenticated, zero-dependency liveness/readiness probes. |
| `auth.py` | `/api/v1` | `POST /auth/apple`, `POST /auth/google`, `GET /auth/me` | Server-side Apple & Google identity verification, JWT generation. |
| `ror.py` | `/api/v1` | `GET /ror`, `GET /ror/pdf`, `POST /ror/search/*` | Cadastral Record of Rights retrieval, HTML parsing, PDF generation. |
| `subscriptions.py` | `/api/v1` | `POST /subscription/verify`, `POST /subscription/credits/purchase`, `GET /subscription/status` | StoreKit 2 transaction verification, ASSN V2 webhooks, credit balances. |
| `usage.py` | `/api/v1` | `GET /usage/quota`, `POST /usage/claim-bonus` | Tiered monthly quota and daily credit bonus allocation. |
| `gis.py` | `/api/v1` | `GET /gis/parcel`, `GET /gis/overlay` | Cadastral vector tile coordinates and crosswalk translation. |
| `config.py` | `/api/v1` | `GET /app-config`, `PUT /app-config` | Dynamic feature flags and minimum supported version gates. |
| `support.py` | `/api/v1` | `POST /support/feedback` | In-app feedback submission. |
| `bhulekh_coverage.py` | `/api/v1` | `GET /bhulekh/coverage` | Odisha 30-district cadastral coverage status. |

---

## 3. Middleware Pipeline (In Execution Order)

1. **`StructuredLoggingMiddleware` (`core/logging_middleware.py`):**
   - Injects unique `X-Request-ID` UUID into request state and response headers.
   - Measures endpoint execution latency in milliseconds.
   - Logs structured JSON log lines at INFO / WARN / ERROR levels.
   - **Security Redaction:** Strictly strips `Authorization`, `X-Admin-Key`, `Cookie`, `identity_token`, `access_token`, and `signed_transaction_jws` from log output.
2. **`CORSMiddleware` (`fastapi.middleware.cors`):**
   - In Production (`ENV=production`): Strictly whitelists `https://bhumitra.app`, `https://api.bhumitra.app`, and `https://admin.bhumitra.app`.
   - Disallows wildcard origins with credentials.

---

## 4. Authentication & JWT Cryptographic Security

- **Algorithm:** `HS256` HMAC-SHA256.
- **Token Validity:** 30 days (`ACCESS_TOKEN_EXPIRE_DAYS = 30`).
- **Subject Claim (`sub`):** Explicit user identifier (e.g. Apple private sub or `google_<sub_id>`).
- **Issuer (`iss`):** Enforced as `https://api.bhumitra.in`.
- **Secret Key Handling:** Loaded via `JWT_SECRET_KEY` environment variable. If absent in development, securely initializes a random process-scoped key via `secrets.token_hex(32)`.

---

## 5. Rate Limiting Subsystem (`core/rate_limiter.py`)

- **Implementation:** Thread-safe In-Memory Sliding Window Rate Limiter.
- **Tiers Enforced:**
  - `RoR Anonymous`: 30 requests / 60 seconds (Keyed by client IP).
  - `RoR Authenticated`: 60 requests / 60 seconds (Keyed by `user_id`).
  - `Auth / Login`: 10 attempts / 60 seconds.
  - `Purchase Verification`: 10 requests / 60 seconds.
- **Rate Limit Exceeded Behavior:** Returns `HTTP 429 Too Many Requests` with JSON error payload and standard `Retry-After` header.

---

## 6. External APIs & Third-Party Dependencies

1. **Bhulekh Odisha Portal (`bhulekh.ori.nic.in`):**
   - Direct HTTP scraping + fallback Chromium headless automation for dynamic ASP.NET ViewState forms.
2. **Apple StoreKit & JWKS (`appleid.apple.com`):**
   - Fetches Apple public root certs and JWKS keys to cryptographically verify Apple Sign-In identity tokens and StoreKit 2 JWS transactions.
3. **Google Identity (`oauth2.googleapis.com`):**
   - Google public certs for Google OAuth ID token verification.
