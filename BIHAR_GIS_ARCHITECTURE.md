# Bihar Cadastral GIS Map Architecture & Data Contract

## Executive Summary

This document specifies the architecture, data contracts, coordinate systems, and resource boundaries for the **Bihar Cadastral GIS Map Provider (`BiharCadastralProvider`)**, providing spatial cadastral mapping from Bihar BhuNaksha without destabilizing Odisha GIS or modifying the iOS application.

---

## 1. Official Source & System Architecture

- **Primary Spatial Authority**: Department of Revenue and Land Reforms, Government of Bihar / National Informatics Centre (NIC).
- **Public Portal**: `https://bhunaksha.bihar.gov.in/`
- **Cadastral Hierarchy**:
  ```
  District (जिला) ── (38 Districts)
        │
        ▼
  Sub-Division (अनुमंडल)
        │
        ▼
  Circle / Anchal (अंचल) ── (534 Circles)
        │
        ▼
  Mauza / Revenue Village (मौजा) + Thana Number (थाना संख्या)
        │
        ▼
  Survey Type (सर्वे प्रकार: CS - Cadastral Survey / RS - Revision Survey)
        │
        ▼
  Sheet Number (चादर / शीट संख्या: Sheet 01, Sheet 02)
        │
        ▼
  Cadastral Vector Polygons (खेसरा / प्लॉट बहुभुज)
  ```

---

## 2. Normalized GIS Data Contract

The provider implements the abstract `CadastralProvider` contract, reusing standard models to maintain backend consistency:

| Normalized Model | Source Representation | Field Mapping | Description |
| :--- | :--- | :--- | :--- |
| `CadastralDistrict` | District dropdown | `id: "BR_PAT"`, `name: "PATNA"` | 38 official administrative districts. |
| `CadastralBlock` | Sub-Division / Circle | `id: "BR_PAT_01"`, `name: "PATNA SADAR"` | Circle/Anchal mapped to block level. |
| `CadastralGP` | Halka (हल्का) | `id: "BR_PAT_01_H01"`, `name: "Halka 01"` | Sub-circle revenue jurisdiction. |
| `CadastralVillage` | Mauza (मौजा) | `id: "BR_PAT_01_108"`, `name: "BEGAMPUR"` | Revenue village disambiguated by Thana number. |
| `CadastralExtent` | Map Bounding Box | `min_lng, min_lat, max_lng, max_lat, center` | Geographical viewport bounds. |
| `CadastralParcel` | Single Plot Polygon | `plot_number: "245"`, `geometry: Polygon`, `centroid` | Individual land parcel with geometry and centroid. |
| `CadastralFeatureCollection` | Village Sheet Map | `type: "FeatureCollection"`, `features: [...]` | Complete vector sheet with all plot polygons. |

---

## 3. Coordinate Reference System (CRS) & Geometry Validation

- **Standard CRS**: WGS84 (`EPSG:4326`) in `[longitude, latitude]` axis order.
- **Local Grid Policy**: Where un-georeferenced historical sheets use local survey origins, coordinates are marked as local cadastral units and never falsely transformed into GPS space.
- **Strict Ring Validation (`validate_polygon_ring`)**:
  1. Rejects NaN, Inf, and non-numeric vertices.
  2. Enforces minimum 4 coordinate pairs per polygon ring.
  3. Guarantees ring closure: $[x_0, y_0] == [x_{-1}, y_{-1}]$.
  4. Computes true geometric centroid via shoelace cross-product.

---

## 4. Performance, Caching & Resource Limits

| Resource Guardrail | Value | Enforcement Strategy |
| :--- | :--- | :--- |
| **Max Parcels per Village** | `5,000` | Slices feature array to prevent memory exhaustion on massive urban sheets. |
| **Max Coordinates per Ring** | `50,000` | Caps vertex count per parcel. |
| **Max Payload Size** | `10 MB` | Hard limit on raw upstream GeoJSON / vector files. |
| **Isolated GIS Cache** | `bihar:gis:*` (500 items, 24h TTL) | Zero cross-talk with Odisha's `_cache`. |
| **Concurrency Semaphore** | `_bihar_gis_semaphore` (max 3) | Independent asyncio semaphore. |
| **SingleFlight Coalescing** | `_bihar_gis_inflight` | 100 simultaneous requests for Sheet 1 execute exactly 1 parse. |

---

## 5. RoR & GIS Decoupling Guarantee

- **Separation of Concerns**: Cadastral map vectors contain ONLY geometry, plot number, sheet reference, and computed area.
- **Zero RoR Leakage**: Textual Jamabandi owner records (Raiyats, guardians, lagan demand) are NOT embedded into GIS vector payloads.
- **Future Linkage**: The mobile client or unified backend resolver links GIS polygons to Jamabandi RoR on-demand using the composite key `(district, anchal, mauza, khesra)`.
