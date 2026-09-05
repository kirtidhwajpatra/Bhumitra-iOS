# BHUMITRA iOS — APP STORE PRIVACY & NUTRITION LABEL AUDIT

**Target:** `MyBhoomi/PrivacyInfo.xcprivacy` & Third-Party SDK Privacy Bundles  
**Audit Date:** 2026-08-31  
**Apple Guideline:** Guideline 5.1.1 (Data Collection and Storage) & Guideline 5.1.2 (Data Use and Sharing)  

---

## 1. Privacy Manifest Declarations (`PrivacyInfo.xcprivacy`)

The application's `PrivacyInfo.xcprivacy` declares **zero tracking** (`NSPrivacyTracking: false`) and accurately specifies the following collected data types:

| Data Type Category | Specific Apple Privacy Type | Collection Purpose | Linked to User? | Used for Tracking? |
|---|---|---|:---:|:---:|
| **Location** | `NSPrivacyCollectedDataTypePreciseLocation` | App Functionality (GIS map navigation) | **No** | **No** |
| **Identifiers** | `NSPrivacyCollectedDataTypeUserID` | App Functionality (Account authentication & sync) | **Yes** | **No** |
| **Purchases** | `NSPrivacyCollectedDataTypePurchaseHistory` | App Functionality (StoreKit 2 entitlements) | **Yes** | **No** |
| **Usage Data** | `NSPrivacyCollectedDataTypeProductInteraction` | Analytics (Feature discovery & search performance) | **No** | **No** |
| **Diagnostics** | `NSPrivacyCollectedDataTypeCrashData` | Diagnostics (Firebase Crashlytics stability) | **No** | **No** |
| **Diagnostics** | `NSPrivacyCollectedDataTypePerformanceData` | Diagnostics (Render and response latency) | **No** | **No** |

---

## 2. Required Reason APIs Declared

| Apple Required Reason API | Selected Reason Code | Stated Purpose | Compliance Status |
|---|---|---|:---:|
| **`NSPrivacyAccessedAPICategoryUserDefaults`** | `CA92.1` | Accessing UserDefaults inside app container for user preferences, onboarding status, and UI theme. | **COMPLIANT** |

---

## 3. Third-Party SDK Privacy Manifest Bundles

- **`FirebaseAnalytics.framework`:** Contains Apple Privacy Manifest declaring product interactions and diagnostics.
- **`FirebaseCrashlytics.framework`:** Contains Apple Privacy Manifest declaring crash logs and performance diagnostics.
- **`GoogleSignIn.framework`:** Contains Apple Privacy Manifest declaring OAuth authentication identifiers.
- **`MapLibre.framework`:** Contains Apple Privacy Manifest declaring tile caching and rendering.
- **`StoreKit 2` (Apple Native):** Native OS framework with zero third-party leakage.

---

### **PRIVACY VERDICT: 100% COMPLIANT WITH APPLE PRIVACY NUTRITION LABEL REQUIREMENTS**
