# MyBhoomi Backend — Production Monitoring & Troubleshooting Guide

**Service:** `mybhoomi-backend-prod`  
**Region:** `asia-south1` (Mumbai)  
**Log Stream:** Google Cloud Logging / Cloud Run Observability

---

## 1. Quick Diagnostic Checklist

| Symptom | Primary Cause | Triage Command / Action |
|---|---|---|
| **Cloud Run returns HTTP 503** | Max instances reached or container failed cold start. | Check Cloud Run logs: `gcloud run services logs read mybhoomi-backend-prod --region asia-south1 --limit 50`. Increase max instances to 2 if traffic surge. |
| **RoR lookup latency spikes (>45s)** | Odisha Bhulekh official NIC server slow/degraded. | Inspect upstream health: `GET /ror/diagnostics`. Check if NIC ASP.NET portal is undergoing maintenance. |
| **All RoR requests fail with `ROR_NOT_FOUND`** | Upstream Bhulekh WebForms viewstate or dropdown DOM changed. | Review scraper logs for navigation/selector timeouts. Run regression suite: `pytest tests/test_accuracy_regression_suite.py`. |
| **Playwright / Chromium crash inside container** | Memory limit exceeded during Chromium render. | Check container memory usage in Cloud Console. If peak > 1.8 GiB, scale memory to `3Gi` or `4Gi`: `gcloud run services update mybhoomi-backend-prod --memory 4Gi --region asia-south1`. |
| **PDF download fails with 502** | Bhulekh print dialog rendering timeout. | Verify if Khata number is valid. Ensure `PDF_TIMEOUT_SECONDS=60` is set. |

---

## 2. Viewing Real-Time Production Logs

### Live Stream Logs
```bash
gcloud run services logs tail mybhoomi-backend-prod --region asia-south1
```

### Filter Errors Only
```bash
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="mybhoomi-backend-prod" AND severity>=ERROR' --limit 20 --format json
```

---

## 3. Metrics & Alerts in Google Cloud Console

1. **Request Count & Latency:** Monitor 50th, 95th, and 99th percentile response latencies in Cloud Run Metrics.
2. **Container Instance Count:** Monitor when instances scale from 0 to 1 during traffic spikes.
3. **Memory & CPU Utilization:** Ensure memory stays safely below 80% of provisioned quota.
