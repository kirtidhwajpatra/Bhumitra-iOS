# BHUMITRA — CREDIT & ENTITLEMENT AUTHORITY FINAL REPORT

**Document ID:** BHUMITRA-CREDIT-AUTHORITY-REPORT  
**Audit Date:** 2026-08-31  
**Scope:** Client-Side Credit State vs Server-Authoritative Database Entitlements.  
**Classification:** **`A: SERVER AUTHORITATIVE — SAFE`**  

---

## 1. Executive Summary

A deep architectural security audit was conducted to evaluate the relationship between client-side Keychain credit caches in the iOS application and the server-authoritative entitlement engine in `BhulekBackend`.

The audit confirms that **the PostgreSQL database is the sole and immutable source of truth for all land record quotas, PDF downloads, and Pro subscription entitlements**. The iOS client's local Keychain values act purely as an offline display cache and have **zero capability to grant unauthorized access to backend API resources**.

---

## 2. Comprehensive Security Architecture Matrix

| Security Dimension | Client-Side Implementation | Server-Side Implementation | Security Guarantee |
|---|---|---|---|
| **Credit Balance Authority** | Ephemeral Keychain cache (`bhumitra_keychain_user_credits_*`) for offline UI display. | PostgreSQL `users.plot_credits` & `user_usage` table. | **Server-Authoritative:** Client-side modifications cannot bypass server quotas. |
| **Transaction Evidence** | Submits Apple signed JWS payload. | Cryptographically validates JWS against official Apple Root CAs (`apple_verification_service.py`). | **Cryptographic Enforcement:** Server rejects all forged or unsigned claims. |
| **Purchase Idempotency** | Checks `checkVerified` on device. | Enforces PostgreSQL `UNIQUE` constraint on `ConsumableTransactionDB.transaction_id`. | **Deduplication:** Repeated JWS submissions yield `credits_granted=0`. |
| **Quota Enforcement** | Evaluates `canPerformPlotSearch` for UI buttons. | Executes `check_and_increment_ror_quota` on every `/api/v1/ror` query inside an atomic DB session. | **Gated Access:** Rejects requests with HTTP 403 when database quota is exhausted. |
| **Reconciliation Sync** | Calls `fetchServerCreditBalance()` on launch/login. | Returns authoritative `user.plot_credits` count from database. | **Self-Healing:** Overwrites any mismatched or tampered local cache values. |
| **Account Isolation** | Separates Keychain keys per `user_id`. | Strictly partitions usage and subscriptions by `user_id` extracted from JWT `sub` claim. | **Zero Cross-Account Leakage:** User B cannot inherit User A's unspent credits. |

---

## 3. Detailed Answers to Audit Questions

### 1. Can a tampered client grant free searches?
**No.** Every RoR search query sent to `/api/v1/ror` is intercepted by `usage_service.py:check_and_increment_ror_quota`. The backend checks the user's active `SubscriptionDB` and `UserUsageDB` records in PostgreSQL. If the database indicates the user is out of credits, the backend returns `HTTP 403 Forbidden` regardless of whatever number the client UI displays.

### 2. Can Apple transaction evidence be replayed?
**No.** When a client submits an Apple JWS payload to `POST /api/v1/subscription/credits/purchase`, the backend checks `ConsumableTransactionDB` for the Apple `transactionId`. If found, it returns `already_processed: True` and grants **0 credits**.

### 3. What happens if the app restarts or switches accounts?
When a user logs in, `SubscriptionManager.handleUserSignIn(userId:)` re-keys the local storage to that user's specific Keychain key and immediately triggers `fetchServerCreditBalance()`, reconciling the exact balance stored in PostgreSQL.

---

## 4. Prioritized Recommendations

| Item ID | Priority | Description | Remediation Plan |
|---|:---:|---|---|
| **AUTH-01** | **P1** | Offline Consumable Queue Hardening | Add a persistent pending JWS sync queue in Keychain to re-dispatch unconfirmed consumable transactions upon reconnect before calling `transaction.finish()`. |
| **AUTH-02** | **P2** | Periodic Background Reconciliation | Periodically trigger `fetchServerCreditBalance()` when network transitions from offline to online via `NWPathMonitor`. |

---

### **FINAL VERDICT: CREDIT AUTHORITY: SERVER AUTHORITATIVE — SAFE**
*(The Bhumitra architecture upholds complete cryptographic and database-level authority over all user entitlements and financial transactions).*
