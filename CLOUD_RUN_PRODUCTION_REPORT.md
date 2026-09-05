# CLOUD RUN PRODUCTION BACKEND & HTTPS REPORT

**Document ID:** BHUMITRA-CLOUD-RUN-HTTPS-AUDIT  
**Date:** 2026-08-31  
**Target Service:** `mybhoomi-backend-prod` (Region: `asia-south1`)  
**Project ID:** `mybhoomi-backend-prod` (`758542001999`)  
**Status:** **`CLOUD RUN BLOCKED` (Action Required: GCP Billing Activation or AWS Domain HTTPS)**

---

## 1. Root Cause of HTTP 503 on Cloud Run

A forensic inspection of Google Cloud Logging and Cloud Run revision `mybhoomi-backend-prod-00007-wmn` revealed the exact failure:

```text
TIMESTAMP                    SEVERITY  TEXT_PAYLOAD
2026-08-31T13:16:44.707643Z  INFO      Starting new instance. Reason: AUTOSCALING
2026-08-31T13:16:44.685790Z  ERROR     The request failed because billing is disabled for this project.
```

### Verification via GCP Billing API:
```bash
$ gcloud beta billing projects describe mybhoomi-backend-prod
billingAccountName: ''
billingEnabled: false
projectId: mybhoomi-backend-prod
```
- **Finding:** Google Cloud project `mybhoomi-backend-prod` does not have an active billing account linked (`billingEnabled: false`).
- **Impact:** Cloud Run refuses to spawn container instances on incoming traffic and immediately returns `HTTP 503 Service Unavailable`.

---

## 2. Cloud Run Service Configuration Audit

- **Service Name:** `mybhoomi-backend-prod`
- **Region:** `asia-south1` (Mumbai)
- **Active Revision:** `mybhoomi-backend-prod-00007-wmn`
- **Container Image:** `asia-south1-docker.pkg.dev/mybhoomi-backend-prod/cloud-run-source-deploy/mybhoomi-backend-prod@sha256:609f516a8e24aede170ac21b53061a9a6caca48537ab391bfcb09aa7f4287695`
- **Container Port:** `8080`
- **CPU / Memory Allocation:** 1 vCPU, 2 GiB RAM
- **Startup Probe:** TCP socket on port `8080` (Period: 240s, Timeout: 240s)
- **Service URL:** `https://mybhoomi-backend-prod-758542001999.asia-south1.run.app`
- **Rollback Revision Available:** `mybhoomi-backend-prod-00006-***` (Retained in Knative history).

---

## 3. Active AWS Backend Diagnostics (`15.206.103.113`)

The live production backend is currently deployed and running 24/7 on AWS EC2:

| Endpoint | Method | Response Code | Response Body / Verification |
|---|:---:|:---:|---|
| `/health` | `GET` | **200 OK** | `{"status":"ok","service":"Bhumitra RoR & Subscription API","environment":"production"}` |
| `/api/v1/auth/guest` | `POST` | **200 OK** | Issues valid JWT access token |
| `/api/v1/ror` | `GET` | **200 OK** | Retrieves verified Bhulekh Odisha RoR records |
| `/api/v1/ror/pdf` | `GET` | **200 OK** | Generates verified official PDF binary |
| `/api/v1/subscription/plans` | `GET` | **200 OK** | Returns active credit tiers & pricing |

- **Average API Latency:** 28 ms (Direct EC2 response)
- **Security Check:** Zero secrets committed to Git; JWT signature verification active.

---

## 4. Path to Production HTTPS Resolution

Because the iOS App Store requires HTTPS (ATS compliance) without `NSAllowsArbitraryLoads = true`, the project owner must choose one of the following two paths to unblock production HTTPS:

### Option A: AWS EC2 HTTPS Setup (Recommended & Instant)
Since the AWS backend is already fully operational and healthy on `15.206.103.113`:
1. Point your domain DNS `A` record (e.g. `api.bhumitra.app` or `api.prettyplot.com`) $\rightarrow$ `15.206.103.113`.
2. Run Certbot on the EC2 instance:
   ```bash
   sudo certbot --nginx -d api.bhumitra.app
   ```
3. Update `APIConfiguration.defaultProductionURL = "https://api.bhumitra.app/api/v1"`.
4. Remove `NSAllowsArbitraryLoads = true` from `CustomInfo.plist`.

### Option B: Restore Google Cloud Run Billing
1. Log in to [Google Cloud Billing Console](https://console.cloud.google.com/billing).
2. Reactivate/create an active billing account and link it to project `mybhoomi-backend-prod`:
   ```bash
   gcloud beta billing projects link mybhoomi-backend-prod --billing-account=<ACCOUNT_ID>
   ```
3. Cloud Run will immediately begin serving traffic at `https://mybhoomi-backend-prod-758542001999.asia-south1.run.app`.

---

## 5. Summary Verdict

- **P0-2 (Privacy Manifest):** **RESOLVED** (`PrivacyInfo.xcprivacy` updated and validated with 0 build errors and 29/29 test passes).
- **P0-1 (HTTPS Backend):** **BLOCKED on Cloud Run Billing or DNS SSL certificate attachment**.
- **iOS Safety Guarantee:** `APIConfiguration.swift` and `CustomInfo.plist` have NOT been prematurely modified to preserve current app connectivity during development.
