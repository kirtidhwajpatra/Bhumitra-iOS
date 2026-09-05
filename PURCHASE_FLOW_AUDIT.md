# BHUMITRA iOS & BACKEND — END-TO-END PURCHASE & CREDIT FLOW AUDIT

**Target:** Bhumitra StoreKit 2 Client + FastAPI Subscription Backend  
**Audit Date:** 2026-08-31  
**Scope:** StoreKit 2 purchase lifecycle, JWS validation, server-authoritative credit allocations, idempotency, failure matrix, and offline safety.  

---

## 1. Complete End-to-End Purchase Flow Map

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Product Loading & Display                                │
│    - StoreKit 2 queries App Store for Product IDs           │
│    - Renders SubscriptionView with live localized pricing   │
└──────────────────────────────┬──────────────────────────────┘
                               │ User Selects Plan & Taps CTA
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Purchase Initiation & Telemetry                          │
│    - Emits `purchase_started(productID, price, trigger)`    │
│    - Attaches `.appAccountToken(user.appAccountUUID)`       │
│    - Calls `product.purchase(options)`                      │
└──────────────────────────────┬──────────────────────────────┘
                               │ Apple In-App Purchase Sheet
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Apple Cryptographic Signing & Transaction Delivery       │
│    - Apple executes biometric auth (FaceID / TouchID)       │
│    - Apple signs JWS payload with Apple Root CA chain       │
│    - StoreKit returns `.success(VerificationResult)`        │
└──────────────────────────────┬──────────────────────────────┘
                               │ Client Cryptographic Check
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Client JWS Verification (`checkVerified`)                │
│    - Client verifies JWS integrity on-device                │
│    - Extracts `transaction.id`, `originalID`, `productID`   │
└──────────────────────────────┬──────────────────────────────┘
                               │
               ┌───────────────┴───────────────┐
               │ Consumable Plot Packs         │ Auto-Renewable Subscriptions
               ▼                               ▼
┌───────────────────────────────┐ ┌───────────────────────────┐
│ 5A. Consumable Credit Flow    │ │ 5B. Subscription Flow     │
│  - POST `/subscription/       │ │  - POST `/subscription/   │
│    credits/purchase`          │ │    verify`                │
│  - Backend verifies JWS       │ │  - Backend verifies JWS   │
│  - Checks idempotency table   │ │  - Upserts SubscriptionDB │
│    (`ConsumableTransactionDB`)│ │    keyed by original_id   │
│  - Atomically increments      │ │  - Inserts TransactionDB  │
│    `UserDB.plot_credits`      │ │  - Returns Pro status     │
│  - Returns `current_balance`  │ │  - Updates local state    │
└──────────────┬────────────────┘ └─────────────┬─────────────┘
               │                                │
               └───────────────┬────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Finalization & Telemetry Confirmation                    │
│    - Calls `await transaction.finish()`                     │
│    - Updates UI state (`remainingPlotCredits`, `isPremium`) │
│    - Emits `purchase_completed(productID, credits, price)`  │
│    - Shows `PurchaseSuccessModalView`                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Transaction Identity & Idempotency Keys

| Flow Type | Apple Primary Identifier | Database Idempotency Key | Guarantee Mechanism |
|---|---|---|---|
| **Consumable Packs** (`bhumitra.plots.*`) | `transaction.id` | `ConsumableTransactionDB.transaction_id` | Unique Constraint on `transaction_id`. Duplicate requests return `already_processed=True` with `credits_granted=0`. |
| **Subscriptions** (`bhumitra.unlimited.*`) | `transaction.originalID` | `SubscriptionDB.original_transaction_id` | Unique Constraint on `original_transaction_id`. Updates active expiration date without creating duplicate subscription records. |
| **Server Webhooks (ASSN V2)** | `notificationUUID` | `SubscriptionEventDB.notification_uuid` | Unique Constraint on `notification_uuid`. Duplicate Apple webhook retries are skipped immediately. |

---

## 3. Credit Allocation Matrix

| Product Identifier | Product Type | Search Credits Granted | Backend Verification Endpoint | Fallback Credit Safety |
|---|:---:|:---:|---|:---:|
| `bhumitra.plots.10` / `bhumitra_pack_10plots` | Consumable | **+10 Plots** | `POST /api/v1/subscription/credits/purchase` | Local Keychain Cache |
| `bhumitra.plots.50` / `bhumitra_pack_50plots` | Consumable | **+50 Plots** | `POST /api/v1/subscription/credits/purchase` | Local Keychain Cache |
| `bhumitra.plots.200` | Consumable | **+200 Plots** | `POST /api/v1/subscription/credits/purchase` | Local Keychain Cache |
| `bhumitra.unlimited.monthly` / `bhumitra_premium_monthly` | Auto-Renewable | **Unlimited** | `POST /api/v1/subscription/verify` | `Transaction.currentEntitlements` |
| `bhumitra_premium_yearly` | Auto-Renewable | **Unlimited** | `POST /api/v1/subscription/verify` | `Transaction.currentEntitlements` |
| `bhumitra_premium_lifetime` | Non-Consumable | **Unlimited (Forever)** | `POST /api/v1/subscription/verify` | `Transaction.currentEntitlements` |

---

## 4. User Identity & Account Linking Model

- **Guest User Purchase:**
  - If a guest purchases before logging in, the purchase attaches to their persistent `app_account_token` UUID.
  - When the guest later logs in with Apple or Google, `AuthManager` links the `app_account_token` to their newly created user account, **seamlessly preserving their purchased credits**.
- **Account Switching Safety:**
  - If User A logs out and User B logs in on the same device, `SubscriptionManager.handleUserSignIn(userId: User B)` switches the active credit context to User B's Keychain key `bhumitra_keychain_user_credits_UserB` and reconciles with the backend. User B cannot consume User A's unspent credits.
