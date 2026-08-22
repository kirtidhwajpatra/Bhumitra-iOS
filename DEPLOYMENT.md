# MyBhoomi Backend — Production Deployment Guide

**Target Cloud Platform:** Google Cloud Run  
**Region:** `asia-south1` (Mumbai)  
**Service Name:** `mybhoomi-backend-prod`  
**GCP Project:** `mybhoomi-backend-prod`  
**Public Service URL:** `https://mybhoomi-backend-prod-758542001999.asia-south1.run.app`

---

## 1. Prerequisites & GCP Setup

### 1.1 Enable Billing
Cloud Run and Google Artifact Registry require an active billing account linked to the GCP project (free tier includes 2 million requests/month):
```bash
# Visit the Google Cloud Console to link/enable billing for the project:
https://console.developers.google.com/billing/enable?project=mybhoomi-backend-prod
```

### 1.2 Verify GCP Account and Project
```bash
gcloud auth login
gcloud config set project mybhoomi-backend-prod
```

### 1.3 Enable Required Google Cloud APIs
```bash
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com
```

---

## 2. Docker Architecture

The backend uses a production-ready `Dockerfile` that packages:
- Python 3.12 (Debian Bookworm)
- FastAPI + Gunicorn ASGI worker
- Playwright Chromium headless engine + all required Linux shared libraries (`libnss3`, `libatk`, `libcups2`, etc.)
- Official Odisha statewide location catalog (`data/bhulekh_catalog/catalog_v3.json`)

### 2.1 Build Container Image with Cloud Build
```bash
cd /Users/uday/Documents/MyBhoomi/BhulekBackend

gcloud builds submit --tag gcr.io/mybhoomi-backend-prod/mybhoomi-backend:latest .
```

---

## 3. Deploying to Cloud Run

Deploy directly from source with conservative cost and stability parameters:

```bash
cd /Users/uday/Documents/MyBhoomi/BhulekBackend

gcloud run deploy mybhoomi-backend-prod \
  --source . \
  --project mybhoomi-backend-prod \
  --region asia-south1 \
  --platform managed \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 1 \
  --concurrency 1 \
  --cpu 1 \
  --memory 2Gi \
  --timeout 120s \
  --set-env-vars ENV=production,LOG_LEVEL=INFO
```

### Resource Sizing Rationale:
- **Min Instances (`0`):** Automatically scales to zero when idle to ensure near-zero ongoing cost.
- **Max Instances (`1`):** Protects the state-level Bhulekh portal from overload.
- **Concurrency (`1`):** Ensures one Playwright Chromium scraping operation runs per instance at a time.
- **Memory (`2Gi`):** Sufficient headroom for Chromium + in-memory Odisha GIS catalog.
- **Timeout (`120s`):** Safely accommodates Bhulekh scraping latency (typically 20–24s).

---

## 4. Environment Variables & Secrets

| Variable | Recommended Value | Purpose |
|---|---|---|
| `ENV` | `production` | Enables production security, disables Swagger UI |
| `LOG_LEVEL` | `INFO` | Structured JSON log stream |
| `PORT` | `8080` | Injected by Cloud Run runtime |
| `ROR_TIMEOUT_SECONDS` | `45` | Maximum duration for RoR scraping |
| `PDF_TIMEOUT_SECONDS` | `60` | Maximum duration for PDF generation |

---

## 5. Verification & Health Probes

### 5.1 Liveness Probe
```bash
curl -i https://mybhoomi-backend-prod-758542001999.asia-south1.run.app/health
```
*Expected Response:*
```json
{
  "status": "ok",
  "service": "Bhumitra RoR & Subscription API",
  "environment": "production"
}
```

### 5.2 Real RoR Query Verification
```bash
curl -s "https://mybhoomi-backend-prod-758542001999.asia-south1.run.app/api/v1/ror?district=Keonjhar&tahasil=Keonjhar%20Sadar&village=G_Dimbo&plot=489" | python3 -m json.tool
```

### 5.3 Official PDF Document Verification
```bash
curl -s -o test_ror.pdf "https://mybhoomi-backend-prod-758542001999.asia-south1.run.app/api/v1/ror/pdf?district=Keonjhar&tahasil=Keonjhar%20Sadar&village=G_Dimbo&plot=489&khata=212"
```

---

## 6. Monitoring & Logging

### View Real-Time Production Logs
```bash
gcloud run services logs tail mybhoomi-backend-prod --region asia-south1
```

---

## 7. Rollback Procedure

If a new deployment experiences issues, instantly route traffic back to the previous stable revision:

```bash
# 1. List all revisions
gcloud run revisions list --service mybhoomi-backend-prod --region asia-south1

# 2. Rollback to a specific stable revision
gcloud run services update-traffic mybhoomi-backend-prod \
  --region asia-south1 \
  --to-revisions <PREVIOUS_REVISION_NAME>=100
```
