# Bihar Cadastral GIS REST API Contract

## Overview

This specification details the request/response payloads, validation rules, query parameters, and error schemas for Bihar cadastral map retrieval via the Bhumitra backend API (`/api/v1/gis/*`).

---

## 1. Endpoints & Route Definitions

All endpoints accept an optional `state` query parameter defaulting to `"ODISHA"`.

### 1.1 District Hierarchy
- **Endpoint**: `GET /api/v1/gis/districts`
- **Query Parameters**:
  - `state` (optional, string): `"ODISHA"` or `"BIHAR"` (Default: `"ODISHA"`)
- **Response**: `List[CadastralDistrict]`
  ```json
  [
    {"id": "BR_PAT", "name": "PATNA"},
    {"id": "BR_GAY", "name": "GAYA"}
  ]
  ```

### 1.2 Circle (Block) Hierarchy
- **Endpoint**: `GET /api/v1/gis/blocks`
- **Query Parameters**:
  - `district_id` (required, string): District identifier (e.g. `"BR_PAT"`)
  - `state` (optional, string): `"BIHAR"`
- **Response**: `List[CadastralBlock]`
  ```json
  [
    {"id": "BR_PAT_01", "name": "PATNA SADAR", "district_id": "BR_PAT"},
    {"id": "BR_PAT_02", "name": "PHULWARI SHARIF", "district_id": "BR_PAT"}
  ]
  ```

### 1.3 Mauza (Revenue Village) Hierarchy
- **Endpoint**: `GET /api/v1/gis/villages`
- **Query Parameters**:
  - `block_id` (required, string): Circle identifier (e.g. `"BR_PAT_01"`)
  - `state` (optional, string): `"BIHAR"`
- **Response**: `List[CadastralVillage]`
  ```json
  [
    {"id": "BR_PAT_01_108", "name": "BEGAMPUR", "block_id": "BR_PAT_01", "district_id": "BR_PAT"}
  ]
  ```

### 1.4 Village Cadastral Sheet Parcels
- **Endpoint**: `GET /api/v1/gis/village/{village_id}/parcels`
- **Path Parameter**: `village_id` (string, e.g. `"BR_PAT_01_108"`)
- **Query Parameters**:
  - `sheet_no` (optional, string, e.g. `"01"`)
  - `state` (optional, string): `"BIHAR"`
- **Response**: `CadastralFeatureCollection`
  ```json
  {
    "type": "FeatureCollection",
    "source": "BIHAR_BHUNAKSHA",
    "village_id": "BR_PAT_01_108",
    "village_name": "BEGAMPUR",
    "total_parcels": 10,
    "features": [
      {
        "type": "Feature",
        "id": "BR_PAT_01_108_245",
        "geometry": {
          "type": "Polygon",
          "coordinates": [[[85.121, 25.593], [85.123, 25.593], [85.123, 25.595], [85.121, 25.595], [85.121, 25.593]]]
        },
        "properties": {
          "plot_number": "245",
          "khesra_id": "245",
          "sheet_no": "01",
          "area_sq_m": 1517.5,
          "centroid": [85.122, 25.594],
          "source": "BIHAR_BHUNAKSHA"
        }
      }
    ]
  }
  ```

### 1.5 Plot Resolution
- **Endpoint**: `GET /api/v1/gis/village/{village_id}/plot/{plot_number}`
- **Query Parameters**: `state=BIHAR`, `sheet_no=01`
- **Response**: `CadastralParcel`

### 1.6 Coordinate Identification (Ray-Casting)
- **Endpoint**: `GET /api/v1/gis/parcel/identify`
- **Query Parameters**: `lat=25.594`, `lng=85.122`, `village_id=BR_PAT_01_108`, `state=BIHAR`
- **Response**: `CadastralParcel`

---

## 2. Guardrails & Error Schemas

| Error Code | HTTP Status | Trigger Condition |
| :--- | :--- | :--- |
| `BIHAR_GIS_DISABLED` | `503 Service Unavailable` | `BIHAR_GIS_PROVIDER_ENABLED=false` |
| `GIS_MAP_TOO_LARGE` | `413 Payload Too Large` | Village parcels $> 5,000$ or payload $> 10\text{MB}$ |
| `UNSUPPORTED_STATE` | `422 Unprocessable Entity` | State not in `["ODISHA", "BIHAR"]` |
| `CADASTRAL_SOURCE_UNAVAILABLE` | `503 Service Unavailable` | Upstream portal timeout / 5xx |
