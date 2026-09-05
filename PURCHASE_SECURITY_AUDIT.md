# BHUMITRA BACKEND — PURCHASE & CREDIT SECURITY AUDIT

**Component:** `BhulekBackend/services/subscription_service.py` & `BhulekBackend/services/apple_verification_service.py`  
**Audit Date:** 2026-08-31  
**Scope:** StoreKit 2 Transaction Verification, ASSN V2 Webhooks, Idempotency, Credit Allocation, and Fraud Prevention.  

---

## 1. StoreKit 2 Cryptographic Verification

- **Verification Standard:** Native cryptographic verification of Apple JWS signed payloads.
- **Root Authority Validation:** Validates the X.509 certificate chain embedded in the JWS header against official Apple Root CAs (`AppleRootCA-G3.cer`, `AppleIncRootCertificate.cer`).
- **Claim Validation:**
  - `bundleId`: Enforces match with `com.kirtidhwaj.Bhumitra`.
  - `environment`: Validates `Production` vs `Sandbox`.
  - `expirationDate`: Validates subscription active window.
  - `revocationDate`: Immediately strips entitlements if a refund/chargeback was executed by Apple Customer Support.

---

## 2. Idempotency & Duplicate Purchase Protection

### Logical Torture Test:
```text
Step 1: Client submits Transaction "2000000123456789" for "bhumitra.plots.50"
        -> Backend verifies JWS
        -> Checks ConsumableTransactionDB for transaction_id="2000000123456789" (Not Found)
        -> Atomically inserts ConsumableTransactionDB record
        -> Increments user plot_credits by +50
        -> Returns 200 OK (credits_granted: 50, current_balance: 53)

Step 2: Client/Attacker resubmits Transaction "2000000123456789" again (or 10 times concurrently)
        -> Backend verifies JWS
        -> Checks ConsumableTransactionDB for transaction_id="2000000123456789" (FOUND)
        -> Short-circuits execution
        -> Grants ZERO additional credits
        -> Returns 200 OK (already_processed: True, credits_granted: 0, current_balance: 53)
```

- **Database Guarantee:** Unique constraint on `ConsumableTransactionDB.transaction_id` prevents race conditions at the PostgreSQL engine level.

---

## 3. App Store Server Notifications V2 (ASSN V2) Durable Idempotency

- **Webhook Endpoint:** `/api/v1/webhook/app-store`
- **Deduplication Table:** `SubscriptionEventDB` with unique constraint on `notification_uuid`.
- **Event Handling:**
  - `DID_RENEW`: Extends `expires_at` timestamp in `SubscriptionDB`.
  - `EXPIRED`: Sets `status = "expired"`, revokes premium flag.
  - `REVOKE`: Sets `status = "revoked"`, sets `revocation_date = now`, immediately suspends Pro features.
  - `DID_FAIL_TO_RENEW`: Sets `is_in_billing_retry = True` while Apple attempts grace-period billing.

---

## 4. Quota Consumption Rule Invariant

- **Invariant:** Search credits are consumed **strictly on HTTP 200 RoR record resolution**.
- **Zero-Deduction Scenarios:**
  - Search returns 404 (Plot not found): **0 credits deducted**.
  - Upstream timeout / network error: **0 credits deducted**.
  - Re-viewing a saved parcel or cached parcel: **0 credits deducted**.
  - Viewing general map vector boundaries: **0 credits deducted**.
