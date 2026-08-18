# Bhumitra Production Operations Runbook

Comprehensive guide for operating, deploying, maintaining, and recovering the Bhumitra backend services, PostgreSQL database, Apple StoreKit 2 subscription system, and dynamic remote configuration.

---

## 1. System Architecture & Environment Configuration

### Architecture Components
- **API Backend**: FastAPI service running in Google Cloud Run (`asia-south1`).
- **Database**: PostgreSQL 16 (Google Cloud SQL) storing users, subscriptions, transactions, ASSN V2 events, usage records, and remote config.
- **Client**: Native iOS 16+ SwiftUI application with StoreKit 2 and Sign in with Apple.

### Production Environment Variables

| Variable | Description | Example / Default |
| :--- | :--- | :--- |
| `ENV` | Environment name | `production` |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://user:pass@host:5432/bhumitra_prod` |
| `JWT_SECRET_KEY` | Secret key for Bhumitra session access tokens | `(Generated 64-char hex string)` |
| `ADMIN_API_KEY` | Secret key for remote config admin updates | `(Generated 64-char hex string)` |
| `APPLE_BUNDLE_ID` | iOS App Bundle Identifier | `com.kirtidhwaj.Bhumitra` |
| `APPLE_ENVIRONMENT` | StoreKit Verification environment | `Production` (or `Sandbox` in staging) |
| `FREE_MONTHLY_ROR_LIMIT` | Monthly free RoR lookup quota | `5` |
| `FREE_MONTHLY_PDF_LIMIT` | Monthly free PDF download quota | `1` |
| `LOG_LEVEL` | Logging verbosity | `INFO` |

---

## 2. Deployment Procedures (Google Cloud Run)

### Standard Deployment
Deploy new backend container revisions to Cloud Run using Google Cloud SDK:

```bash
# 1. Build and push container to Google Artifact Registry
gcloud builds submit --tag asia-south1-docker.pkg.dev/bhumitra-prod/containers/bhumitra-backend:latest ./BhulekBackend

# 2. Deploy revision to Cloud Run
gcloud run deploy bhumitra-backend-prod \
  --image asia-south1-docker.pkg.dev/bhumitra-prod/containers/bhumitra-backend:latest \
  --region asia-south1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars ENV=production,APPLE_ENVIRONMENT=Production,APPLE_BUNDLE_ID=com.kirtidhwaj.Bhumitra \
  --set-secrets DATABASE_URL=DATABASE_URL:latest,JWT_SECRET_KEY=JWT_SECRET_KEY:latest,ADMIN_API_KEY=ADMIN_API_KEY:latest \
  --min-instances 1 \
  --max-instances 20 \
  --memory 1Gi \
  --cpu 1
```

### Instant Rollback
To rollback to a previous working revision:
```bash
# 1. List revisions
gcloud run revisions list --service bhumitra-backend-prod --region asia-south1

# 2. Route 100% traffic to previous revision
gcloud run services update-traffic bhumitra-backend-prod \
  --to-revisions bhumitra-backend-prod-00012-abc=100 \
  --region asia-south1
```

---

## 3. Database Operations & Backups

### Running Migrations
Always run Alembic migrations prior to deploying new container versions:
```bash
cd BhulekBackend
DATABASE_URL="postgresql://user:pass@host:5432/bhumitra_prod" alembic upgrade head
```

### Automated & On-Demand Backups
- **Automated Cloud SQL Backups**: Configured daily at 03:00 UTC with 7-day retention and point-in-time recovery (PITR).
- **Manual Snapshot before major changes**:
```bash
gcloud sql backups create --instance=bhumitra-pg-prod --description="Pre-migration snapshot"
```

### Database Restoration Procedure
If database corruption occurs:
```bash
# Restore from specific backup ID
gcloud sql backups restore BACKUP_ID --restore-instance=bhumitra-pg-prod
```

---

## 4. Apple StoreKit 2 & Webhook Setup

### App Store Server Notifications V2 (ASSN V2)
1. In **App Store Connect** -> **App Information** -> **App Store Server Notifications**:
   - Production URL: `https://api.bhumitra.app/api/v1/webhook/app-store`
   - Sandbox URL: `https://staging.bhumitra.app/api/v1/webhook/app-store`
   - Version: **Version 2 Notifications**
2. **Apple Root CA Verification**:
   - The backend validates the `x5c` certificate chain directly against Apple's Root CAs bundled in `certs/`.

---

## 5. Dynamic Remote Configuration & Version Management

### Mutating Remote Configuration
To change feature flags, version requirements, or copy dynamically without releasing an iOS build:

```bash
curl -X PUT "https://api.bhumitra.app/api/v1/app-config" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: <YOUR_ADMIN_API_KEY>" \
  -d '{
    "min_supported_version": "2.0.0",
    "recommended_version": "2.2.0",
    "latest_version": "2.3.0",
    "maintenance_mode": false,
    "subscription_enabled": true,
    "features": {
      "advanced_search": true,
      "property_history": false,
      "valuation": false,
      "pdf_download": true,
      "satellite_view": true
    }
  }'
```

### Emergency Maintenance Mode
To immediately lock all client apps for scheduled database or GIS maintenance:
```bash
curl -X PUT "https://api.bhumitra.app/api/v1/app-config" \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: <YOUR_ADMIN_API_KEY>" \
  -d '{
    "maintenance_mode": true,
    "maintenance_message": "Bhumitra services are undergoing scheduled cadastral maintenance. Services will resume at 6:00 PM IST."
  }'
```

---

## 6. Incident Response & Scraper Degradation

### Symptoms of Portal Structural Change
If Bhulekh Odisha changes their HTML markup:
1. Structured logs will output `SCRAPER_PARSER_ERROR`.
2. Scraper metrics will show elevated `parser_errors`.
3. The service prevents caching malformed or empty data.

### Remediation Steps:
1. Inspect live scraper logs:
   ```bash
   gcloud logging read 'resource.type="cloud_run_revision" AND jsonPayload.status_code>=500' --limit 20
   ```
2. Update selector logic in `scrapers/bhulekh_scraper.py`.
3. Run tests: `pytest tests/test_usage_and_rate_limiting.py`.
4. Deploy hotfix revision to Cloud Run.
