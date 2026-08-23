# App Store Privacy Nutrition Label Data Map — Bhumitra

**Application Name**: Bhumitra — Odisha Land Records & Cadastral Map  
**Bundle ID**: `com.kirtidhwaj.Bhumitra`  
**Platform**: iOS 26.0+  
**Audit Date**: August 22, 2026  
**Auditor**: Antigravity Autonomous AI Core  

---

## 1. Summary of Data Collection

| Data Category | Collected? | Linked to User Identity? | Used for Tracking? | Third-Party Sharing? | Purpose | Code Evidence / Source |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Precise Location** | **YES** (On-Device) | **NO** | **NO** | **NO** | App Functionality (Display user position relative to cadastral plots on map) | `MyBhoomi/Map/MapLibre/MapLibreView.swift:36` (`showsUserLocation = true`) |
| **User Identifiers (Apple User ID)** | **YES** (Optional Sign-in) | **YES** | **NO** | **NO** | Account Authentication & Subscription Entitlements | `MyBhoomi/Services/AuthManager.swift:185` (`sub` from Apple Identity Token) |
| **Purchase History** | **YES** | **YES** | **NO** | **NO** | In-App Subscriptions (Monthly, Yearly, Lifetime) | `MyBhoomi/Services/SubscriptionManager.swift:45` (StoreKit 2 `Transaction.currentEntitlements`) |
| **Usage Data / Queries** | **YES** (Aggregated Server-Side) | **NO** (Anonymous) / **YES** (Tiered Quotas) | **NO** | **NO** | Server-Authoritative Rate Limiting & Quotas | `BhulekBackend/routers/ror.py:59` (`usage_service.check_and_increment_ror_quota`) |
| **Diagnostics / Crash Logs** | **NO** (Zero 3rd-party trackers) | **NO** | **NO** | **NO** | N/A (Standard Apple opt-in crash reports only) | Zero Firebase/Crashlytics/Sentry SDKs installed |
| **Contact Info / Email** | **NO** | **NO** | **NO** | **NO** | N/A (Sign in with Apple uses Private Relay) | Zero contact harvesting in client code |
| **Land Ownership Records** | **YES** (Ephemeral Display) | **NO** | **NO** | **NO** | Public Government Record Retrieval (Bhulekh Odisha) | `MyBhoomi/Services/RoRService.swift:115` |

---

## 2. Detailed Privacy Declaration Matrix

### A. Location Data
- **Type**: Precise Location (`CLLocationCoordinate2D`).
- **Data Retention**: Ephemeral in memory during active map session. Never written to disk, never uploaded to Bhumitra backend or third parties.
- **Permission String**: `NSLocationWhenInUseUsageDescription` (*"Bhumitra uses your location to show your position relative to cadastral land parcels on the Odisha cadastral map and help you navigate to your land."*).
- **Opt-out Behavior**: If denied, app functions with complete manual navigation and search.

### B. User Identifiers & Account Data
- **Type**: User ID generated from Apple ID Private Sub claim.
- **Collection Mechanism**: Native Sign in with Apple (`AuthenticationServices`).
- **Storage**: Stored in PostgreSQL with standard TLS 1.3 encryption for subscription entitlement persistence across app installs.

### C. Financial & Purchase Data
- **Type**: StoreKit 2 Transaction JWS signed receipts.
- **Payment Processing**: Handled 100% by Apple In-App Purchase. Bhumitra never sees or touches credit cards, bank accounts, or billing addresses.

### D. Tracking & Advertising
- **Tracking**: `NSPrivacyTracking` = `false`.
- **Third-Party Ad Networks**: Zero advertising SDKs (No Google AdMob, Meta Audience Network, etc.).
- **Data Brokers**: Zero data sharing with external brokers or analytics vendors.

---

## 3. Privacy Manifest Declaration ([`PrivacyInfo.xcprivacy`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/PrivacyInfo.xcprivacy))

- **`NSPrivacyTracking`**: `false`
- **`NSPrivacyCollectedDataTypes`**:
  - `NSPrivacyCollectedDataTypePreciseLocation` (Linked: `false`, Tracking: `false`, Purpose: `AppFunctionality`)
- **`NSPrivacyAccessedAPITypes`**:
  - `NSPrivacyAccessedAPITypeUserDefaults` (Reason: `CA92.1` — User preferences and cache markers).
