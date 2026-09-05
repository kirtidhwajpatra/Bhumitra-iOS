# BHUMITRA iOS — APP STORE PRIVACY AUDIT & DATA MAP

**Application Name:** Bhumitra — Odisha Land Records & Cadastral GIS  
**Bundle ID:** `com.kirtidhwaj.Bhumitra`  
**Platform:** iOS 16.0+  
**Audit Date:** 2026-08-31  
**Status:** **VERIFIED & COMPLIANT**  

---

## 1. Privacy Nutrition Label Matrix

| Data Category | Data Type (Apple Spec) | Source / Collector | Linked to Identity? | Used for Tracking? | App Store Purpose | App Store Connect Disclosure? | `PrivacyInfo.xcprivacy` Declared? | Code Evidence |
|:---|:---|:---|:---:|:---:|:---|:---:|:---:|:---|
| **Location** | `PreciseLocation` | Bhumitra Map (CoreLocation) | **NO** | **NO** | App Functionality (Display user position relative to cadastral plots on map) | **YES** | **YES** (`NSPrivacyCollectedDataTypePreciseLocation`) | `MapLibreView.swift:36` (`showsUserLocation = true`) |
| **User Identifiers** | `UserID` | AuthManager (Sign in with Apple / Google) | **YES** | **NO** | App Functionality (Account identification, saved parcels, & subscription access) | **YES** | **YES** (`NSPrivacyCollectedDataTypeUserID`) | `AuthManager.swift:185` (Apple sub ID / Google UID) |
| **Financial Info** | `PurchaseHistory` | SubscriptionManager (StoreKit 2) | **YES** | **NO** | App Functionality (Managing subscriptions & credit quotas) | **YES** | **YES** (`NSPrivacyCollectedDataTypePurchaseHistory`) | `SubscriptionManager.swift:45` (`Transaction.currentEntitlements`) |
| **Usage Data** | `ProductInteraction` | AnalyticsService (Firebase Analytics) | **NO** (Pseudonymous `pp_UUID`) | **NO** | Analytics (Search funnels, parcel view telemetry, feature usage) | **YES** | **YES** (`NSPrivacyCollectedDataTypeProductInteraction`) | `AnalyticsService.swift:124` (`Analytics.logEvent`) |
| **Diagnostics** | `CrashData` | Firebase Crashlytics | **NO** | **NO** | App Functionality (Stability & fatal crash reporting) | **YES** | **YES** (`NSPrivacyCollectedDataTypeCrashData`) | `AnalyticsService.swift:5` (`FirebaseCrashlytics`) |
| **Performance** | `PerformanceData` | AnalyticsService / RoRService | **NO** | **NO** | App Functionality (Network latency & PDF download duration) | **YES** | **YES** (`NSPrivacyCollectedDataTypePerformanceData`) | `RoRService.swift:523` (`latencyMs`) |

---

## 2. Tracking Declaration
- **`NSPrivacyTracking`:** `false`
- **`NSPrivacyTrackingDomains`:** `[]` (Empty)
- **Third-Party Advertising:** **Zero** ad networks (No AdMob, Meta, Unity, etc.).
- **Data Broker Sharing:** **Zero** data shared with external data brokers.

---

## 3. Required API Access Declarations
- **API Type:** `NSPrivacyAccessedAPITypeUserDefaults`
- **Reason Code:** `CA92.1`
- **Purpose:** Accessing app-internal `UserDefaults` for user preferences, onboarding flags, and offline cache identifiers.

---

## 4. Third-Party SDK Privacy Manifest Bundles Verified

Every embedded third-party dependency in `MyBhoomi.app` includes its official, bundled `PrivacyInfo.xcprivacy`:
1. `FirebaseCore.bundle/PrivacyInfo.xcprivacy`
2. `FirebaseCrashlytics.bundle/PrivacyInfo.xcprivacy`
3. `GoogleSignIn.bundle/PrivacyInfo.xcprivacy`
4. `GoogleDataTransport.bundle/PrivacyInfo.xcprivacy`
5. `GoogleUtilities.bundle/PrivacyInfo.xcprivacy`
6. `MapLibre.framework/PrivacyInfo.xcprivacy`
7. `AppAuth.bundle/PrivacyInfo.xcprivacy`
8. `Promises.bundle/PrivacyInfo.xcprivacy`
