# Bhumitra Backend — Render Production Deployment Guide (Gate 1.3)

**Platform:** Render (Docker Web Service)  
**Region:** `Singapore` (Recommended for low latency to Odisha/India)  
**Service Name:** `mybhoomi-backend-prod`  
**Plan:** `Free`  
**Root Directory:** `BhulekBackend`  
**Dockerfile Path:** `Dockerfile`  
**Docker Context:** `.`  
**Health Check Path:** `/health`  

---

## 1. Overview & Architecture

The Bhumitra backend service runs FastAPI with Playwright Chromium for real-time NIC Odisha Bhulekh identity resolution, SOAP helpers, and cadastral spatial mapping.

```
iOS App (Bhumitra)
      ↓
api.bhumitra.app (Cloudflare / DNS)
      ↓
Render Web Service (FastAPI + Gunicorn + Playwright Chromium)
      ↓
NIC Odisha Bhulekh & 4K GEO Spatial GIS
```

---

## 2. Render Deployment Options

### Option A: Using `render.yaml` Blueprint (Recommended — 1-Click)

The repository root includes a verified `render.yaml` Blueprint:
1. Log in to your [Render Dashboard](https://dashboard.render.com/).
2. Click **New +** &rarr; **Blueprint**.
3. Connect your GitHub repository `kirtidhwajpatra/Bhumitra-iOS`.
4. Render will automatically detect `render.yaml` and configure the service:
   - Service Name: `mybhoomi-backend-prod`
   - Plan: `Free`
   - Runtime: Docker
   - Root Directory: `BhulekBackend`
   - Context: `.`
   - Dockerfile: `Dockerfile`
   - Health Check: `/health`
5. Click **Apply**.

---

### Option B: Manual Web Service Setup via Dashboard

1. Log in to [Render Dashboard](https://dashboard.render.com/).
2. Click **New +** &rarr; **Web Service**.
3. Choose **Build and deploy from a Git repository**.
4. Select the repository and branch (`main`).
5. Configure the following fields:
   - **Name:** `mybhoomi-backend-prod`
   - **Region:** `Singapore` (or closest available region)
   - **Branch:** `main`
   - **Root Directory:** `BhulekBackend`
   - **Runtime:** `Docker`
   - **Dockerfile Path:** `Dockerfile`
   - **Docker Build Context:** `.`
   - **Instance Type:** `Free`
6. Under **Advanced**:
   - **Health Check Path:** `/health`
   - **Auto-Deploy:** `Yes`

---

## 3. Production Environment Variables

Configure these environment variables in **Render Dashboard &rarr; Environment**:

| Variable | Value | Purpose |
|---|---|---|
| `ENV` | `production` | Enables production security, disables Swagger UI |
| `LOG_LEVEL` | `INFO` | Structured JSON log stream |
| `JWT_SECRET_KEY` | *(Render auto-generated secret)* | Secret key for auth tokens |
| `ADMIN_API_KEY` | *(Render auto-generated secret)* | Admin access key |
| `APPLE_BUNDLE_ID` | `com.kirtidhwaj.Bhumitra` | App Store bundle identifier |
| `APPLE_ENVIRONMENT` | `Production` | StoreKit server environment |
| `BHULEKH_MAX_CONCURRENT` | `3` | Maximum concurrent Chromium scrapers |
| `MAX_PENDING_BHULEKH_REQUESTS` | `10` | Maximum pending queue depth |
| `ROR_TIMEOUT_SECONDS` | `90` | Upstream scraper timeout |
| `PDF_TIMEOUT_SECONDS` | `60` | Offline document generator timeout |
| `GIS_TIMEOUT_SECONDS` | `15` | Spatial GIS catalog timeout |
| `BHULEKH_NAVIGATION_TIMEOUT_MS` | `20000` | Browser page load timeout (ms) |
| `BHULEKH_ACTION_TIMEOUT_MS` | `10000` | Browser action timeout (ms) |

> [!IMPORTANT]
> Never commit actual production secrets to Git. Use Render's Secret Manager or Environment Variables tab.

---

## 4. Verification & Testing Checklist

Once Render finishes deploying and displays **Live**:

### Step 4.1: Test Liveness Probe (`GET /health`)
```bash
curl -i https://<your-render-service>.onrender.com/health
```
**Expected Response:** `HTTP 200 OK`
```json
{
  "status": "ok",
  "service": "Bhumitra RoR & Subscription API",
  "environment": "production"
}
```

### Step 4.2: Test Readiness Probe (`GET /ready`)
```bash
curl -i https://<your-render-service>.onrender.com/ready
```

### Step 4.3: Test Odisha GIS Districts (`GET /api/v1/gis/districts`)
```bash
curl -i https://<your-render-service>.onrender.com/api/v1/gis/districts
```
**Expected Response:** All 30 Odisha districts.

### Step 4.4: Run Live Real-World RoR Resolution
```bash
curl -X POST "https://<your-render-service>.onrender.com/api/v1/ror" \
  -H "Content-Type: application/json" \
  -d '{
    "district_id": "178",
    "district_name": "Bhadrak",
    "tahasil_name": "Chandbali",
    "village_name": "Chandakuda",
    "plot_number": "241"
  }'
```
**Expected Output:**
- `status`: `VERIFIED`
- `khata_number`: `54`
- `total_area`: `1 Acre 4200 Decimal`
- `land_type`: `ଶାରଦ ଦୁଇ`
- 7 verified tenants/owners

---

## 5. Domain & iOS App Migration Protocol

To safely transition live traffic with zero downtime:

1. **Verify Render Instance:** Confirm all health probes, district queries, and live RoRs pass on `*.onrender.com`.
2. **Point Custom Domain / Cloudflare:**
   - In Render Dashboard &rarr; **Settings** &rarr; **Custom Domains**, add `api.bhumitra.app`.
   - Update DNS in Cloudflare: CNAME `api.bhumitra.app` &rarr; `<your-service>.onrender.com`.
3. **Verify iOS App Endpoint:**
   - In [`APIConfiguration.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Services/APIConfiguration.swift), ensure `defaultProductionURL` points to `https://api.bhumitra.app/api/v1` (or your Render URL).
