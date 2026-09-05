# BHUMITRA BACKEND — RESOURCE EXHAUSTION & MEMORY AUDIT

**Component:** `BhulekBackend` (FastAPI / Playwright / ReportLab / Cache)  
**Audit Date:** 2026-08-31  
**Scope:** Memory leaks, Playwright context leaks, large payload buffering, PDF generation ceilings, and denial of service protections.  

---

## 1. Playwright / Chromium Resource Management

- **Headless Browser Architecture:**
  - Playwright browser instances are bounded by `BHULEKH_MAX_CONCURRENT = 3`.
  - Scrape workers use isolated `BrowserContext` and `Page` objects.
  - **Cleanup Guarantee:** Scrape methods wrap execution in `try ... finally` blocks explicitly ensuring `await page.close()` and `await context.close()` execute on both success and exceptions.
- **Memory Footprint:** Each Chromium context consumes ~40–60 MB RAM; max 3 concurrent contexts consume a bounded maximum of ~180 MB RAM.

---

## 2. PDF Generation & Buffer Safety

- **Engine:** In-memory PDF streaming via ReportLab / PDF generator.
- **Size Ceiling:** `MAX_PDF_SIZE_BYTES = 15728640` (15 MB maximum buffer).
- **Disk Leaks:** Generated PDFs are streamed directly via `StreamingResponse` / in-memory bytes buffers without leaving orphan temporary files on the disk filesystem.
- **PDF Concurrency Semaphore:** `_pdf_semaphore` limits concurrent PDF generation to 3 workers.

---

## 3. In-Memory TTLCache Memory Bounding

- **`_cache` (RoR Record Cache):** Max 2,000 entries $\times$ ~5 KB average payload = **~10 MB RAM**.
- **`_pdf_cache` (PDF Document Cache):** Max 500 entries $\times$ ~150 KB average PDF = **~75 MB RAM**.
- **`_negative_cache` (404 Cache):** Max 1,000 entries $\times$ ~0.5 KB = **~0.5 MB RAM**.
- **Total In-Memory Cache Cap:** **< 100 MB RAM total**.

---

## 4. Input Payload & Query String Boundaries

- **Query Parameters:** String length caps enforced on `/api/v1/ror` (`plot <= 32`, `district <= 64`, `tahasil <= 64`, `village <= 64`).
- **Null-Byte Injection:** Sanitizer rejects `\x00` and path traversal sequences (`..`).
- **Request Body Size:** Fast-rejects oversized JSON payloads (> 1 MB) at the ASGI parser level.
