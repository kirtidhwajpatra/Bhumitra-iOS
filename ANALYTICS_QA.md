# Bhumitra Analytics & Crash Monitoring QA Verification

**Document Version:** 1.0  
**Implementation Date:** 2026-08-31  
**Target Environment:** iOS 16.0+  
**SDK Versions:** Firebase iOS SDK v11.15.0 (`FirebaseAnalytics`, `FirebaseCrashlytics`)  

---

## 1. Executive Summary

This document verifies the end-to-end implementation of production-grade telemetry, privacy controls, crash monitoring, and event taxonomy for the **Bhumitra iOS App**.

### Core Verifications:
- **Centralized Service:** All events routed through `AnalyticsService.shared`.
- **Identity Continuity:** User analytics ID `pp_UUID` persisted securely in Keychain across guest sessions, Apple/Google logins, logouts, and re-logins. Purged only on explicit account deletion.
- **Strict Privacy / Zero-PII Policy:** No names, tenant identities, emails, phone numbers, raw tokens (JWT, Apple identity token, Google token), StoreKit transaction signatures (JWS), or exact plot numbers are transmitted to Firebase.
- **Backend Revenue Source of Truth:** `purchase_completed` strictly triggers after the backend API validates StoreKit transactions.
- **Crashlytics Breadcrumbs:** Telemetry breadcrumbs attached without PII to aid in diagnosing crash sequences.

---

## 2. Event QA Matrix (All 31 Events)

| # | Event Name | Trigger Location | Tested & Verified | Expected Parameters | Privacy Sanitization Verified | Duplicate Risk Guarded |
|---|---|---|---|---|---|---|
| 1 | `app_opened` | `MyBhoomiApp.init` | ✅ Verified | `app_version`, `build_number`, `device_model`, `os_version` | ✅ Clean | Single per launch |
| 2 | `guest_session_started` | `LoginView.swift` | ✅ Verified | `session_type = "guest"` | ✅ Clean | Debounced |
| 3 | `auth_screen_viewed` | `LoginView.swift` | ✅ Verified | `source` | ✅ Clean | On appear |
| 4 | `login_started` | `LoginView.swift` | ✅ Verified | `auth_provider` (`"apple"`, `"google"`) | ✅ Clean | On button tap |
| 5 | `login_completed` | `AuthManager.swift` | ✅ Verified | `auth_provider`, `is_new_user` | ✅ Clean (Tokens stripped) | Single on success |
| 6 | `login_failed` | `LoginView.swift` | ✅ Verified | `auth_provider`, `error_category` | ✅ Controlled Enum | On failure catch |
| 7 | `logout_completed` | `AuthManager.swift` | ✅ Verified | `previous_account_type` | ✅ Clean (`pp_UUID` preserved) | On user logout |
| 8 | `account_deleted` | `AuthManager.swift` | ✅ Verified | `account_type` | ✅ Identity purged | Explicit action |
| 9 | `onboarding_started` | `WelcomeView.swift` | ✅ Verified | `source` | ✅ Clean | First install |
| 10 | `onboarding_completed` | `WelcomeView.swift` | ✅ Verified | `duration_seconds` | ✅ Clean | Single on finish |
| 11 | `land_search_started` | `RoRService.swift` / `ManualSearchViewModel.swift` | ✅ Verified | `search_method`, `district_id`, `tehsil_id` | ✅ Standard IDs | Single per search query |
| 12 | `land_search_submitted` | `RoRService.swift` | ✅ Verified | `search_method`, `district_id`, `tehsil_id` | ✅ Standard IDs | On HTTP dispatch |
| 13 | `land_search_succeeded` | `RoRService.swift` | ✅ Verified | `search_method`, `district_id`, `has_results`, `latency_ms` | ✅ Standard IDs | On HTTP 200 |
| 14 | `land_search_failed` | `RoRService.swift` | ✅ Verified | `search_method`, `district_id`, `error_category` | ✅ Controlled Enum | On catch block |
| 15 | `land_record_viewed` | `CadastralPlotCardView.swift` | ✅ Verified | `district_id`, `is_government_land`, `owner_count`, `land_classification` | ✅ No Citizen Names | On bottom card display |
| 16 | `land_record_successfully_viewed` *(Activation KPI)* | `CadastralPlotCardView.swift` | ✅ Verified | `district_id`, `is_government_land`, `owner_count`, `land_classification` | ✅ Verified Payload | On verified RoR load |
| 17 | `land_record_action` | `CadastralPlotCardView.swift` | ✅ Verified | `action`, `district_id` | ✅ Controlled Enum | On user button tap |
| 18 | `official_ror_download_started` | `OfficialRoRPDFService.swift` | ✅ Verified | `district_id`, `is_prefetched` | ✅ Standard IDs | SingleFlight coalesced |
| 19 | `official_ror_download_completed` | `OfficialRoRPDFService.swift` | ✅ Verified | `district_id`, `latency_ms`, `file_size_kb` | ✅ Clean | On PDF saved |
| 20 | `official_ror_download_failed` | `OfficialRoRPDFService.swift` | ✅ Verified | `district_id`, `error_category` | ✅ Controlled Enum | On failure catch |
| 21 | `bhumitra_report_viewed` | `LandPassportDetailView.swift` | ✅ Verified | `district_id` | ✅ Clean | On view appear |
| 22 | `bhumitra_report_saved` | `LandPassportDetailView.swift` | ✅ Verified | `district_id` | ✅ Clean | On bookmark tap |
| 23 | `bhumitra_report_shared` | `LandPassportDetailView.swift` | ✅ Verified | `district_id` | ✅ Clean | On share sheet tap |
| 24 | `land_passport_viewed` | `LandPassportDetailView.swift` | ✅ Verified | `district_id`, `is_government_land`, `owner_count` | ✅ Clean | On detail screen appear |
| 25 | `plot_credit_consumed` | `SubscriptionManager.swift` | ✅ Verified | `remaining_credit_bucket`, `is_unlimited` | ✅ Bucketed ("0", "1-3", etc.) | On successful plot inspect |
| 26 | `credits_low_warning_shown` | `SubscriptionManager.swift` | ✅ Verified | `remaining_credit_bucket` | ✅ Bucketed | On $\le 3$ credits left |
| 27 | `credits_exhausted` | `SubscriptionManager.swift` | ✅ Verified | `trigger_source` | ✅ Clean | On 0 credits blocked |
| 28 | `paywall_viewed` | `SubscriptionView.swift` | ✅ Verified | `trigger`, `remaining_credit_bucket` | ✅ Controlled Enum | On sheet appear |
| 29 | `product_selected` | `SubscriptionView.swift` | ✅ Verified | `product_id`, `product_type`, `credits`, `price` | ✅ Clean | On card tap |
| 30 | `purchase_started` | `SubscriptionManager.swift` | ✅ Verified | `product_id`, `product_type`, `price`, `trigger` | ✅ Clean | On Pay button tap |
| 31 | `purchase_completed` | `SubscriptionManager.swift` | ✅ Verified | `product_id`, `product_type`, `credits_granted`, `price` | ✅ Backend Server Confirmed | Strictly on server 200 response |
| 32 | `purchase_cancelled` | `SubscriptionManager.swift` | ✅ Verified | `product_id` | ✅ Clean | On user dismiss sheet |
| 33 | `purchase_failed` | `SubscriptionManager.swift` | ✅ Verified | `product_id`, `error_category` | ✅ Controlled Enum | On StoreKit/network error |

---

## 3. User Property Verification

The following user properties are maintained and synced to Firebase Analytics:

| User Property Key | Example Values | Timing & Persistence |
|---|---|---|
| `account_type` | `"guest"`, `"authenticated"`, `"premium"` | Updated on session load, login, purchase, and logout |
| `lifetime_record_views_bucket` | `"0"`, `"1-5"`, `"6-20"`, `"21-50"`, `"50+"` | Incremented on `land_record_successfully_viewed` |
| `plot_credits_bucket` | `"0"`, `"1-3"`, `"4-10"`, `"11-50"`, `"50+"` | Updated on credit consumption and purchase completion |
| `auth_provider` | `"apple"`, `"google"`, `"guest"` | Set on sign-in / session restoration |
| `preferred_district` | `"Puri"`, `"Khurda"`, `"Bhadrak"`, etc. | Set on district selection in search flow |
| `has_downloaded_official_ror` | `true`, `false` | Set to `true` on first successful official RoR download |
| `has_purchased` | `true`, `false` | Set to `true` on first successful StoreKit purchase |
| `app_version` | `"2.1"` | Set at app launch |

---

## 4. Controlled Error Taxonomy Verification

No raw error strings are emitted to Analytics. Only controlled enums are used:
- `cancelled`
- `network`
- `provider_error`
- `configuration`
- `backend_error`
- `invalid_token`
- `timeout`
- `upstream_error`
- `parse_error`
- `unknown`

---

## 5. Security & Privacy Audit Verification

- [x] No citizen names transmitted.
- [x] No tenant names transmitted.
- [x] No email addresses transmitted.
- [x] No phone numbers transmitted.
- [x] No JWT / Bearer tokens transmitted.
- [x] No Apple identity tokens transmitted.
- [x] No Google ID tokens transmitted.
- [x] No StoreKit JWS transaction signatures transmitted.
- [x] No exact plot/khata numbers transmitted to Analytics.
- [x] Crashlytics non-fatal logging records errors without PII.

---

## 6. Build and Verification Status

- **Xcode Build Scheme:** `MyBhoomi`
- **Build Result:** `** BUILD SUCCEEDED **`
- **Compiler Checks:** Zero errors.
- **Linker Configuration:** `-ObjC` linker flag configured, `FirebaseAnalytics` & `FirebaseCrashlytics` linked.
- **Symbol Upload Phase:** Configured with `${PODS_ROOT}/FirebaseCrashlytics/run` / SPM executable.
