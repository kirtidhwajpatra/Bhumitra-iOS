# Bihar Land Records Provider Architecture Plan

## Executive Summary

This architecture plan establishes the foundational design for introducing **Bihar State Land Records (Jamabandi Register-II & BhuNaksha)** into Bhumitra without compromising or modifying the stable Odisha production flow (`v2.0.0-analytics-stable`, commit `dec0d1b`). 

Bihar support will be developed behind an strict fail-closed feature flag (`BIHAR_PROVIDER_ENABLED=false`) using isolated provider abstractions, decoupled scraper pipelines, separate concurrency controls, and identical normalized API contracts.

---

## 1. How Odisha Currently Works (Current Production Architecture)

The existing Odisha land records implementation is structured across several resilient layers:

```
┌────────────────────────────────────────────────────────────────────────┐
│                          FastAPI Router Layer                          │
│   (/api/v1/ror, /api/v1/search/plot, /api/v1/search/khata, /api/v1/gis)│
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                RoR Service Layer (services/ror_service.py)             │
│   • Request Coalescing (SingleFlight with asyncio.Future)              │
│   • Multi-Tier Caching (Verified TTLCache + Negative TTLCache)         │
│   • Rate Limiting & Monthly Quota Enforcement                          │
│   • Dynamic Bounded Semaphores (settings.BHULEKH_MAX_CONCURRENT)       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                  ┌─────────────────┴─────────────────┐
                  ▼                                   ▼
┌──────────────────────────────────┐ ┌──────────────────────────────────┐
│   GIS Cadastral Provider         │ │   Odisha Scraper & Resolver      │
│   (providers/odisha_4kgeo_provider)│ (scrapers/bhulekh_scraper.py)   │
│   • District / Block / GP /      │ │   • SOAP Pre-Resolver (Fast path)│
│     Village hierarchy            │ │   • Playwright Headless Chromium │
│   • GeoJSON parcel geometries    │ │   • 3-Level Verification Engine  │
│   • Spatial ray-casting lookup   │ │   • Structured RoR Parser        │
└──────────────────────────────────┘ └──────────────────────────────────┘
```

### Key Odisha Components & Capabilities:
1. **Cadastral Provider (`providers/cadastral_provider.py` & `odisha_4kgeo_provider.py`)**:
   - Implements abstract `CadastralProvider` interface.
   - Fetches administrative hierarchy (District -> Block -> GP -> Village) and GeoJSON parcel polygons from Odisha's 4KGEO spatial services.
2. **SOAP Pre-Resolver (`resolvers/bhulekh_soap_resolver.py`)**:
   - Performs ultra-fast, low-overhead plot-to-Khata resolutions against official Odisha SOAP endpoints prior to full DOM scraping.
3. **Deterministic Scraper (`scrapers/bhulekh_scraper.py`)**:
   - Uses Playwright headless Chromium for executing ASP.NET postbacks on `bhulekh.ori.nic.in`.
   - Employs language-independent identity resolution (Odia-to-English phonetic normalizer, consonant skeletons, bilingual catalog mappings).
4. **Structured Parser (`scrapers/structured_ror_parser.py`)**:
   - Extracts Khatiyan front page (Front/Back) tables: Tenant/Owner entries, Father/Husband names, Plot schedule, Land Classification (Kissam), Rent/Cess, and Statutory Government Tenures.
5. **3-Level Verification Engine**:
   - `LEVEL 1`: Strict Canonical ID and Plot number verification.
   - `LEVEL 2`: Diagnostic phonetic & bilingual name check.
   - `LEVEL 3`: Fail-closed conflict detection to reject mismatching scraped records.
6. **Concurrency & SingleFlight**:
   - Prevents upstream stampedes by coalescing duplicate concurrent lookups for identical plots into a single in-flight `asyncio.Future`.

---

## 2. Abstractions to Safely Reuse

To ensure consistency across states and maintain zero churn for client integrations, the following domain models and infrastructural components will be shared:

| Component / Abstraction | Source Path | Reusability Rationale |
|-------------------------|-------------|-----------------------|
| `CadastralProvider` (ABC) | `BhulekBackend/providers/cadastral_provider.py` | Universal contract for administrative hierarchy and GeoJSON cadastral parcel queries. |
| `RoRResponse` & `OwnerEntry` | `BhulekBackend/models/ror_response.py` | Stable normalized output format consumed by iOS client. |
| `PlotSearchResult` / `KhataSearchResult` | `BhulekBackend/models/ror_response.py` | Standardized fast-search response envelopes. |
| `SingleFlight` Request Coalescing Pattern | `BhulekBackend/services/` | Eliminates redundant upstream queries for concurrent user requests. |
| Rate Limiter & Security Tokens | `BhulekBackend/core/rate_limiter.py` | Protects backend from abuse across all state endpoints. |
| Server-Authoritative Quota Service | `BhulekBackend/services/usage_service.py` | Enforces monthly search limits uniformly regardless of state. |
| Structured Logging & Tracing | `BhulekBackend/core/logging_middleware.py` | Unified request tracing (`X-Request-ID`) across all state lookups. |

---

## 3. Components That Must Remain Odisha-Specific

The following components are tightly coupled to Odisha's unique portal architecture, Odia script, and revenue terminology and **MUST NOT** be modified or polluted with Bihar logic:

1. `BhulekBackend/providers/odisha_4kgeo_provider.py`: Odisha-specific ESRI/GeoServer GIS endpoints.
2. `BhulekBackend/scrapers/bhulekh_scraper.py`: Playwright automation specifically tailored for `bhulekh.ori.nic.in/RoRView.aspx`.
3. `BhulekBackend/scrapers/bhulekh_mappings.py`: Static ID dictionaries for Odisha's 30 districts and tehsils.
4. `BhulekBackend/scrapers/structured_ror_parser.py`: HTML table parser for Odisha's dual-table RoR format.
5. `BhulekBackend/resolvers/bhulekh_soap_resolver.py`: Odisha NIC SOAP XML client.
6. `BhulekBackend/resolvers/bhulekh_identity_resolver.py`: Odia phonetic and script transliteration engines.

---

## 4. What a Bihar Provider Must Implement

Bihar's land administration operates via **Biharbhumi (Department of Revenue and Land Reforms)** and **BhuNaksha Bihar**. 

A dedicated `BiharBhumiProvider` and associated scraping/parsing services will be constructed in isolated files:

### Target Component Architecture:
```
BhulekBackend/
├── providers/
│   ├── cadastral_provider.py         (Existing Shared ABC)
│   ├── odisha_4kgeo_provider.py      (Existing Odisha GIS - UNTOUCHED)
│   └── bihar_bhunaksha_provider.py   [NEW] (Bihar BhuNaksha GIS implementation)
├── scrapers/
│   ├── bihar/                        [NEW Directory for clean isolation]
│   │   ├── __init__.py
│   │   ├── bihar_constants.py        [NEW] (Bihar 38 districts & revenue codes)
│   │   ├── bihar_jamabandi_scraper.py [NEW] (Playwright / HTTP client for biharbhumi)
│   │   ├── bihar_jamabandi_parser.py  [NEW] (Register-II HTML parser & sanitization)
│   │   └── bihar_khatian_parser.py    [NEW] (Khatiyan RoR parser)
├── services/
│   ├── ror_service.py                (Existing Odisha RoR Service - UNTOUCHED)
│   └── bihar_ror_service.py          [NEW] (Dedicated Bihar service with independent cache & semaphores)
```

### Bihar Provider Operations:
1. **Administrative Hierarchy Resolution**:
   - State -> District (38 Districts) -> Anchal/Circle -> Halka -> Mauza (Revenue Village).
2. **Search Operations**:
   - `search_by_khesra(district, anchal, halka, mauza, plot)`
   - `search_by_khata(district, anchal, halka, mauza, khata)`
   - `search_by_jamabandi(district, anchal, halka, mauza, jamabandi_no)`
   - `search_by_raiyat(district, anchal, halka, mauza, owner_name)`
3. **Register-II (जमाबंदी पंजी भाग-२) Extraction**:
   - Extracts Raiyat Name, Father/Husband Name, Caste/Category, Khata No, Khesra No, Rakba (Area in Acre/Decimal/Bigha-Katha-Dhur), Lagan/Cess, Boundary (Chauhaddi), and Mutation/Dakhil-Kharij status.
4. **BhuNaksha Cadastral Mapping**:
   - Fetches vector parcel boundaries for Bihar villages via BhuNaksha WMS/GeoJSON endpoints.

---

## 5. Normalized API Contract Compatibility

The Bihar provider will normalize all Bihar-specific terms into Bhumitra's existing canonical response models:

```
[ Bihar Raw Field ]              [ Bhumitra Normalized Contract ]
जमाबंदी / खतियान          ───►   RoRResponse / VerifiedRoRRecord
रैयत (Raiyat)             ───►   OwnerEntry.name
पिता / पति का नाम        ───►   OwnerEntry.relation_name ("Father" / "Husband")
खाता सं. (Khata)          ───►   RoRResponse.khata_number
खेसरा सं. (Khesra)        ───►   RoRResponse.plot
रकबा (Rakba)              ───►   RoRResponse.area (Normalized to Standard Acre/Decimal)
लगान / उपकर (Lagan/Cess)  ───►   AssociatedPlot.rent_cess
जमीन का वर्गीकरण          ───►   RoRResponse.land_type (Bhit, Dhanhar, Makan, Govt)
चौहद्दी (Chauhaddi)       ───►   RoRResponse.raw_fields["boundary_north/south/east/west"]
दाखिल-खारिज वाद संख्या    ───►   RoRResponse.raw_fields["mutation_case_no"]
```

Clients querying `/api/v1/ror` or `/api/v1/search/plot` with a Bihar state parameter will receive the exact same Pydantic schema structure as Odisha.

---

## 6. Feature Flag Strategy

Bihar functionality will be governed by explicit environment variables and settings:

```python
# core/config.py
class Settings(BaseSettings):
    # Existing settings...
    
    # State Provider Flags
    ODISHA_PROVIDER_ENABLED: bool = True
    BIHAR_PROVIDER_ENABLED: bool = False   # Default FAIL-CLOSED
    BIHAR_MAX_CONCURRENT_SCRAPES: int = 3
    BIHAR_SCRAPER_TIMEOUT_SECONDS: int = 25
    BIHAR_CACHE_TTL_SECONDS: int = 86400
```

### Routing & Dispatch Logic:
```python
# Conceptual state router dispatch:
@router.get("/ror")
async def get_ror(state: str = Query("ODISHA", description="State code: ODISHA, BIHAR"), ...):
    state_normalized = state.strip().upper()
    
    if state_normalized == "BIHAR":
        if not settings.BIHAR_PROVIDER_ENABLED:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={
                    "code": "STATE_PROVIDER_DISABLED",
                    "message": "Bihar land records provider is currently offline for scheduled maintenance.",
                    "retryable": False
                }
            )
        return await bihar_ror_service.get_ror(...)
    
    # Default path: Odisha (Preserves 100% existing backward compatibility)
    return await ror_service.get_ror(...)
```

---

## 7. Instant Kill-Switch Mechanism

To guarantee zero operational risk:
1. **Environment Kill-Switch**: Setting `BIHAR_PROVIDER_ENABLED=false` immediately halts all Bihar traffic without application restarts when combined with dynamic configuration reloading.
2. **Upstream Circuit Breaker**: If Biharbhumi responds with > 5 consecutive HTTP 5xx or captcha challenge errors, the Bihar provider automatically trips to open (disabled) state for a 5-minute cooldown, logging alerts without impacting Odisha scrapers.
3. **No Quota Leakage**: In the event of a Bihar provider failure, user search credits are strictly preserved (quota is only deducted upon successful record delivery).

---

## 8. Preventing Bihar Changes from Affecting Odisha

| Risk Area | Isolation Boundary |
|-----------|--------------------|
| **Memory / Concurrency** | Dedicated `asyncio.Semaphore` for Bihar (`BIHAR_MAX_CONCURRENT_SCRAPES=3`) separate from Odisha's semaphore (`BHULEKH_MAX_CONCURRENT=6`). |
| **Playwright Pools** | Separate browser contexts and isolated cookie jars; crashes in Bihar context cannot tear down Odisha browser sessions. |
| **Cache Collision** | Separate cache key namespaces (`bihar:ror:{dist}:{anchal}:{mauza}:{khesra}` vs `ror:{d_id}:{t_id}:...`). |
| **Rate Limiting** | Independent client rate limiter buckets tagged by state (`ror_bihar` vs `ror_odisha`). |
| **Source Code** | Zero edits to `services/ror_service.py` or `scrapers/bhulekh_scraper.py`. All Bihar code resides in `scrapers/bihar/` and `services/bihar_ror_service.py`. |

---

## 9. Database Evolution Strategy

The existing PostgreSQL schema (`UserDB`, `SubscriptionDB`, `UsageAuditDB`) is already state-agnostic. 

When Bihar support is officially enabled in the future:
1. `UsageAuditDB`: Optional `state` column (varchar(16), default `'ODISHA'`, nullable) to segment usage analytics per state.
2. `UserDB`: No schema changes required.
3. **Alembic Migration**: A non-blocking, backward-compatible Alembic migration will be written when database persistence is introduced. No destructive DDL will be executed.

---

## 10. Test Strategy Summary

A standalone test suite (`tests/bihar/`) will be developed containing:
- **Unit Parser Tests**: 100% offline tests against sanitized HTML fixtures of Jamabandi Register-II and Khatian slips.
- **Provider Mock Tests**: Mocking upstream HTTP/Playwright responses to verify error codes, timeouts, and empty search results.
- **Contract Verification Tests**: Validating that Bihar responses adhere 100% to `RoRResponse` schema.
- **Isolation Tests**: Verifying that disabling Bihar feature flags leaves Odisha endpoints completely operational.
