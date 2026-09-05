# BHUMITRA — CLIENT-SIDE CREDIT STATE vs SERVER-AUTHORITATIVE ENTITLEMENT AUDIT

**Target:** `SubscriptionManager.swift` (iOS) & `usage_service.py`, `subscription_service.py` (FastAPI / PostgreSQL)  
**Audit Date:** 2026-08-31  
**Focus:** Proving that client-side credit state is an ephemeral UI cache and that the backend PostgreSQL database remains the sole, uncompromised authority for user entitlements.  

---

## 1. Local Credit Storage Architecture (iOS Client)

### Storage Mechanisms:
- **Keychain Storage:**
  - `bhumitra_keychain_device_credits_v2` (Device-level starter credits cache).
  - `bhumitra_keychain_user_credits_<userId>` (Isolated per-user credit cache).
  - `bhumitra_keychain_device_unlimited_v2` (Cached unlimited flag).
- **Functions Performing Local Increments:**
  - `SubscriptionManager.addCredits(amount:)`: Modifies local `@Published remainingPlotCredits` and saves to Keychain.
  - `SubscriptionManager.loadInitialCreditState()`: Grants 10 starter credits on first install.
- **Data Upstream Propagation:**
  - **Zero Direct Upstream Uploads:** The iOS client **never** uploads raw numbers like `{"credits": 500}` to the backend.
  - The backend provides **zero endpoints** that accept arbitrary credit increments without a cryptographically verified Apple StoreKit 2 JWS receipt.

---

## 2. Server-Authoritative Architecture (PostgreSQL Source of Truth)

```
┌─────────────────────────────────────────────────────────────────┐
│                      FastAPI Backend Engine                     │
├────────────────────────────────┬────────────────────────────────┤
│ 1. Consumable Plot Credits     │ 2. Monthly Quota & Pro Status  │
│  - Table: `users.plot_credits` │  - Table: `user_usage`         │
│  - Only modified via:          │    (Tracks `ror_lookup_count`) │
│    `POST /subscription/        │  - Table: `subscriptions`      │
│     credits/purchase`          │    (Tracks `status='active'`)  │
│  - Requires Apple signed JWS   │  - Evaluated on every `/ror`   │
│    verified against Root CA    │    request via user JWT `sub`  │
└────────────────────────────────┴────────────────────────────────┘
```

---

## 3. Tamper Resistance Analysis

### Scenario: Malicious User Modifies Local Keychain (Sets 9999 Credits)
1. **Client UI:** Shows 9999 credits in `SubscriptionView`.
2. **Server Request:** User executes search $\rightarrow$ Client sends `GET /api/v1/ror` with Bearer JWT.
3. **Server Execution (`usage_service.py:check_and_increment_ror_quota`):**
   - Extracts `user_id` from cryptographically signed JWT.
   - Queries `subscriptions` table (Not Premium).
   - Queries `user_usage` table for current month's count (`ror_lookup_count`).
   - If count $\ge 10$ and `user.plot_credits == 0`, server **rejects request with HTTP 403 Forbidden (`USAGE_LIMIT_EXCEEDED`)**.
4. **Reconciliation:** On next call to `GET /api/v1/subscription/credits`, the backend returns the real database balance (0), and `SubscriptionManager.swift:701` **overwrites the tampered Keychain balance back to 0**.
5. **Verdict:** **Tampering with local client state grants zero permanent access on the server.**

---

## 4. Transaction Finish Timing & Eventual Reconciliation Analysis

### Current Flow on Network Failure:
In `SubscriptionManager.swift:420-458`:
1. User purchases consumable pack while device is offline or backend is unreachable.
2. StoreKit 2 returns `.success(VerificationResult)`.
3. Client executes on-device cryptographic verification (`checkVerified`).
4. Client attempts `processConsumablePurchaseWithBackend()`, which fails due to network error.
5. Client grants local fallback credits and executes `await transaction.finish()`.

### Technical Finding:
- **Observation:** If `transaction.finish()` is called before the backend receives the JWS payload, StoreKit 2 considers the transaction closed on the device.
- **Reconciliation Invariant:** When the user later goes online, `fetchServerCreditBalance()` reconciles the server's PostgreSQL balance. Because the backend never received the JWS during the offline failure, the server DB balance will not reflect the consumable pack until the JWS is re-submitted.
- **Recommended Hardening (P1):** Maintain a persistent `pending_transactions` queue in Keychain to re-dispatch un-synced JWS payloads upon network recovery before calling `transaction.finish()`, or defer `transaction.finish()` until backend HTTP 200 is confirmed.

---

## 5. Account Switching & Deletion Separation

- **Account Switching (User A $\rightarrow$ User B):**
  - When User B logs in, `SubscriptionManager.handleUserSignIn(userId: User B)` switches the Keychain key to `bhumitra_keychain_user_credits_UserB` and immediately calls `fetchServerCreditBalance()`.
  - User B cannot consume User A's unspent server-side credits.
- **Account Deletion:**
  - `AuthManager.deleteAccount()` calls backend deletion endpoint (purging `users`, `subscriptions`, and `user_usage` rows in PostgreSQL) and purges all Keychain keys associated with that user ID.
