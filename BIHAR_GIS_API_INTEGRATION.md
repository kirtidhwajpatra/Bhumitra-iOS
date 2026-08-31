# Bihar Cadastral GIS API Integration Architecture

## Architecture Overview

```
                      [ Incoming Client Request: /api/v1/gis/* ]
                                         │
                                         ▼
                         [ GISRouter (services/gis_router.py) ]
                                         │
                    ┌────────────────────┴────────────────────┐
                    │ (state="BIHAR")                         │ (state="ODISHA" / default)
                    ▼                                         ▼
    [ Check: BIHAR_GIS_PROVIDER_ENABLED ]       [ Odisha 4K GEO Provider ]
    ├── If False: Raise 503 (BIHAR_GIS_DISABLED)├── Cache: 'gis:*'
    └── If True: BiharCadastralProvider         └── Provider: Odisha4KGEOProvider
                    │
                    ▼
     [ BiharCadastralProvider (providers/bihar_cadastral_provider.py) ]
     ├── Isolated Cache: 'bihar:gis:*' (24h TTL)
     ├── Concurrency Semaphore: _bihar_gis_semaphore (max=3)
     ├── SingleFlight: _bihar_gis_inflight
     └── Large Map Limiter: MAX_PARCELS_PER_VILLAGE (5000)
                    │
                    ▼
       [ Normalized Cadastral Models (models/cadastral.py) ]
```

---

## Key Design Principles & Safety Boundaries

1. **Strict Feature Gating**: Default `BIHAR_GIS_PROVIDER_ENABLED=false` prevents accidental production exposure.
2. **Zero Cross-Provider Fallback**: A failure in Bihar GIS never executes an Odisha search, and vice versa.
3. **Cache Namespace Isolation**: Bihar keys (`bihar:gis:*`) and Odisha keys (`gis:*`) are completely disjoint.
4. **SingleFlight Coalescing**: Multiple concurrent requests for the exact same village sheet execute exactly 1 upstream parse.
5. **Fail-Closed Geometry**: Polygons with non-finite coordinates or corrupted boundaries are dropped cleanly.
6. **Large Map Protection**: Village sheets with $>5,000$ parcels return `GIS_MAP_TOO_LARGE` (HTTP 413) to protect memory and client rendering stability.
