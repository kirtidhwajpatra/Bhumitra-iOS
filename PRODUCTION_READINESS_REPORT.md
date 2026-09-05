# BHUMITRA iOS — FINAL PRODUCTION READINESS AUDIT REPORT

**Document Version:** 1.0  
**Audit Date:** 2026-08-31  
**Target Platform:** iOS 16.0+  
**Application:** Bhumitra (formerly MyBhoomi)  
**Bundle ID:** `com.kirtidhwaj.Bhumitra`  
**Current Checkpoint Tag:** `v2.0.0-analytics-stable` (`dec0d1be85de71dfef194c3c9234a983a94b140e`)  
**Audit Branch:** `production-readiness-audit`  

---

## 1. Executive Summary

A comprehensive, end-to-end production readiness audit of the **Bhumitra iOS Land Records & Cadastral GIS** application and its FastAPI backend was conducted across source code, build pipelines, test suites, StoreKit 2 monetization, Firebase telemetry, and App Store review compliance.

The application core features (Odisha cadastral vector map, RoR parsing, PDF export, StoreKit 2 monetization, and Firebase Analytics/Crashlytics) are **stable, fully functional, and building cleanly in Release configuration with 100% test pass rates**.

### **Ship Status**
- **TestFlight Status:** **`READY FOR TESTFLIGHT`**
- **App Store Production Status:** **`BLOCKED (Pending 3 P0 Pre-Submission Items)`**

---

## 2. Readiness Scorecard

| Category | Score / Status | Critical Finding |
|---|:---:|---|
| **Build & Compilation** | **100% / PASS** | Release configuration builds with 0 errors (`** BUILD SUCCEEDED **`). |
| **Unit & Specification Tests** | **100% / PASS** | 29/29 iOS specification tests pass (Area Converter + False Gov UI). |
| **Monetization & StoreKit 2** | **95% / PASS** | StoreKit 2 transactions verified by backend; offline fallback works. |
| **Analytics & Crash Monitoring**| **100% / PASS** | 31-event taxonomy, zero PII, `pp_UUID` persistence, Crashlytics run phase. |
| **Backend & Resilience** | **90% / PASS** | SingleFlight coalescing, verified local fallbacks, SQLite catalog cache. |
| **App Store Security / ATS** | **65% / P0 BLOCKED** | `NSAllowsArbitraryLoads = true` due to HTTP IP backend (`15.206.103.113`). |
| **Privacy Manifest Compliance** | **70% / P0 BLOCKED** | `PrivacyInfo.xcprivacy` needs update for Firebase Analytics & Crashlytics SDKs. |
| **App Bundle Size** | **80% / P1 OPTIMIZATION**| 77 MB `.app` includes 15.6 MB of duplicate `GoogleSans_17pt` font files. |
| **Overall Production Score** | **88 / 100** | **Ready for TestFlight; requires HTTPS domain + Privacy manifest for App Store.** |

---

## 3. Issue Classification: P0 / P1 / P2

### P0 Blockers (Must fix before App Store Submission)
1. **App Transport Security (ATS) & Plaintext HTTP Backend (Security / Guideline 2.5.4)**
   - *Issue:* `CustomInfo.plist` enables `NSAllowsArbitraryLoads = true` and an explicit exception for `15.206.103.113`. Production traffic in `APIConfiguration.swift` routes to plaintext `http://15.206.103.113/api/v1`.
   - *Impact:* Apple App Store review strictly scrutinizes arbitrary loads and HTTP IP backends, risking rejection under Section 2.5.4 (Network Security).
   - *Fix:* Attach a custom domain with an SSL/TLS certificate (HTTPS) or route production traffic through Cloud Run HTTPS (`https://mybhoomi-backend-...run.app`) and remove `NSAllowsArbitraryLoads = true`.
2. **Privacy Manifest Declaration Update (`PrivacyInfo.xcprivacy`)**
   - *Issue:* `MyBhoomi/PrivacyInfo.xcprivacy` only declares `PreciseLocation` and `UserDefaults`. It does not declare required Apple privacy types for Firebase Analytics (`ProductInteraction`, `DiagnosticsData`, `DeviceID`) and Crashlytics (`CrashData`).
   - *Impact:* Xcode 15/16 App Store Connect automated upload validation will flag missing required reason declarations for third-party SDKs.
   - *Fix:* Add entries for `NSPrivacyCollectedDataTypeCrashData`, `NSPrivacyCollectedDataTypePerformanceData`, and `NSPrivacyCollectedDataTypeProductInteraction` linked as non-tracking.
3. **Government Data Source Disclaimer (App Store Guideline 5.2.5)**
   - *Issue:* Apps displaying government data must clearly display a prominent, non-affiliated disclaimer stating: *"Bhumitra is an independent tool and is not affiliated with, endorsed by, or representing the Government of Odisha or the Revenue & Disaster Management Department."*
   - *Fix:* Ensure this disclaimer is visible on the About/Settings screen, onboarding screen, and App Store metadata description.

### P1 Issues (Strongly Recommended Before Launch)
1. **Remove Duplicate Font Assets (-15.6 MB app reduction)**
   - *Issue:* `MyBhoomi/Resources/Fonts/` contains 8 duplicate `GoogleSans_17pt-*.ttf` files that are unreferenced in `CustomInfo.plist` (which registers `GoogleSans-*.ttf`).
   - *Fix:* Delete the 8 `GoogleSans_17pt` TTF files from bundle resources to reduce download size from 77 MB to ~61 MB.
2. **Add iOS Build Step to CI/CD (`.github/workflows/ci.yml`)**
   - *Issue:* GitHub Actions only runs backend pytest and secret checks; it does not compile the iOS application or run Swift tests.
   - *Fix:* Add a macOS runner job executing `xcodebuild -scheme MyBhoomi build` and `swift run_land_area_tests.swift`.
3. **Purge Root Debug & History Bundles from Repo Tracking**
   - *Issue:* Large backup bundles (`phase7.26_verified_stable.bundle`, `phase7.27_verified_stable.bundle`, `pre_analytics_stable.bundle`) total ~95 MB in root directory.

### P2 Improvements (Post-Launch)
1. **Offline Map Tile Pack Pre-caching:** Allow users to download regional Odisha district boundaries for fully disconnected rural field surveys.
2. **Dark Mode GIS Layer Adaptation:** Add high-contrast cadastral boundary outline toggling when user toggles dark mode.
3. **Automated dSYM Archive Upload Fastlane Action:** Automate Symbol upload on release tags.

---

## 4. Complete Screen Inventory (39 SwiftUI Views)

| Screen / View Name | Primary Entry Point | Exit / Navigation Destination | Key Features & Telemetry |
|---|---|---|---|
| `SplashScreenView` | App Launch (`MyBhoomiApp`) | `MainView` / `OnboardingView` | Brand animated logo, progress bar, 4s delay timer |
| `OnboardingView` | First Launch (`!hasCompletedOnboarding`) | `MainView` via "Get Started" | Telemetry: `onboarding_started`, `onboarding_completed` |
| `MainView` | Root Container | Coordinates Map, Sheets, Overlays | Tab/Overlay state management, GPS manager lifecycle |
| `MapHomeOverlay` | Primary App Screen | Parcel card, Location picker, Settings | Search trigger, layers toggle, recent searches drawer |
| `CadastralPlotCardView` | Map Tap on Parcel Boundary | `LandPassportDetailView`, RoR sheet | Telemetry: `land_record_viewed`, `land_record_successfully_viewed` |
| `LandPassportDetailView` | Bottom Card "View Full Passport" | Save, Share, RoR PDF Download | Telemetry: `land_passport_viewed`, `bhumitra_report_shared` |
| `ManualRoRSearchView` | Top Search Bar / Search Button | `UnifiedRoRResultView` | 4-tier dropdown hierarchy (District $\rightarrow$ Tahasil $\rightarrow$ Village $\rightarrow$ Khata/Plot) |
| `UnifiedRoRResultView` | Manual Search Success | Full RoR Sheet, PDF Download | Government classification banner, plot area converter |
| `OfficialLandRecordsView` | Quick Access Drawer | District/Tahasil catalog browser | Official Bhulekh database browser |
| `OfficialLocationPickerSheet`| Location Selector Tap | Map camera animation to selected village| Hierarchical district/tahasil picker |
| `OfficialPlotDetailSheet` | Official catalog plot selection | RoR details modal | Plot owner list, land type |
| `SavedLandsView` | Bookmarks Icon in Header | Saved parcel details | Local CoreData/UserDefaults offline saved parcels |
| `SubscriptionView` | "Upgrade to Pro" / Paywall trigger | StoreKit 2 Purchase Modal | Telemetry: `paywall_viewed`, `product_selected`, `purchase_started` |
| `PurchaseSuccessModalView` | Backend confirmation HTTP 200 | Dismiss to Pro view | Telemetry: `purchase_completed` |
| `LoginView` | Settings / Auth Prompt | Guest session / Apple / Google Auth | Telemetry: `auth_screen_viewed`, `login_started`, `login_completed` |
| `ManageAccountView` | Settings $\rightarrow$ Account | Logout, Delete Account | Telemetry: `logout_completed`, `account_deleted` |
| `LandAreaCalculatorView` | Passport Tools / Quick Actions | Live conversion sheet | 22-unit bidirectional converter (Guntha, Mana, Decimal, Acre) |
| `ForceUpdateView` | Remote Config `min_version` gate | App Store redirect URL | Blocking update barrier |
| `ClaimFreeCreditsModalView` | Promo banner / First install | Dismiss with +3 plot credits | Free credit onboarding incentive |
| `NetworkStatusBannerView` | NWPathMonitor offline event | Auto-dismisses on reconnect | Offline indicator banner |
| `SaveLandSuccessModalView` | "Save Land" CTA tap | Dismiss | Bookmark confirmation modal |

---

## 5. Button-by-Button QA Matrix

| Screen | Button / Control | Expected Action | Actual Behavior | QA Status | Priority |
|---|---|---|---|:---:|:---:|
| `OnboardingView` | "Get Started" | Set UserDefaults flag, transition to Map | Transitions smoothly to Map | **PASS** | Normal |
| `MapHomeOverlay` | GPS Locate Me | Pan camera to user coordinate | Pans and zooms to user coordinate | **PASS** | Normal |
| `MapHomeOverlay` | Layer Switcher (Satellite/Normal) | Toggle raster satellite style | Changes MapLibre style layer | **PASS** | Normal |
| `MapHomeOverlay` | Search Bar | Open `ManualRoRSearchView` modal | Presents 4-tier search modal | **PASS** | Normal |
| `CadastralPlotCardView` | "View Land Passport" | Present `LandPassportDetailView` sheet | Presents detailed passport sheet | **PASS** | Normal |
| `CadastralPlotCardView` | "Official RoR PDF" | Initiate download via `OfficialRoRPDFService` | Downloads & presents PDF viewer | **PASS** | Normal |
| `LandPassportDetailView` | "Share Report" | Open iOS UIActivityViewController | Opens native share sheet | **PASS** | Normal |
| `LandPassportDetailView` | "Save Land" | Save to offline store & show modal | Saves parcel & shows confirmation | **PASS** | Normal |
| `LandPassportDetailView` | "Area Calculator" | Open `LandAreaCalculatorView` | Prefills current parcel acreage | **PASS** | Normal |
| `ManualRoRSearchView` | District Dropdown | Load list of Odisha districts | Displays 30 districts | **PASS** | Normal |
| `ManualRoRSearchView` | Tahasil Dropdown | Filter tahasils by selected district | Correctly filters tahasils | **PASS** | Normal |
| `ManualRoRSearchView` | "Search Land" | Dispatch search request | Executes and emits telemetry | **PASS** | Normal |
| `SubscriptionView` | "Monthly Plan" | Select `bhumitra_premium_monthly` | Highlights card and updates CTA | **PASS** | Normal |
| `SubscriptionView` | "Yearly Plan" | Select `bhumitra_premium_yearly` | Highlights card and updates CTA | **PASS** | Normal |
| `SubscriptionView` | "Subscribe / Pay" | Trigger StoreKit 2 sheet | Launches native Apple purchase sheet | **PASS** | Normal |
| `SubscriptionView` | "Restore Purchases" | Call `AppStore.sync()` | Restores existing transactions | **PASS** | Normal |
| `LoginView` | "Sign in with Apple" | Present Apple authorization controller | Authenticates & updates identity | **PASS** | Normal |
| `LoginView` | "Sign in with Google" | Present Google Sign-In sheet | Authenticates with Google SDK | **PASS** | Normal |
| `LoginView` | "Continue as Guest" | Set guest mode & dismiss | Emits `guest_session_started` | **PASS** | Normal |
| `ManageAccountView` | "Log Out" | Clear token, preserve `pp_UUID` | Clears auth state safely | **PASS** | Normal |
| `ManageAccountView` | "Delete Account" | Purge backend + purge Keychain `pp_UUID` | Emits `account_deleted` & resets | **PASS** | Normal |

---

## 6. Payment & StoreKit 2 Torture Test Audit

- **Product IDs Verified:**
  - `bhumitra_premium_monthly` (Auto-renewable subscription)
  - `bhumitra_premium_yearly` (Auto-renewable subscription)
  - `bhumitra_premium_lifetime` (Non-consumable lifetime unlock)
  - `bhumitra.plots.10`, `bhumitra.plots.50`, `bhumitra.plots.200` (Consumable search packs)
- **Local StoreKit Configuration:** `MyBhoomi/Resources/Subscriptions.storekit` properly configured.
- **Authoritative Flow Verified:**
  - App initiates purchase $\rightarrow$ Apple signs JWS $\rightarrow$ Backend verifies cryptographic signature against Apple Root CA $\rightarrow$ Credits allocated in DB $\rightarrow$ `purchase_completed` emitted.
- **Network Resilience Invariant:**
  - If backend is temporarily offline during purchase, `SubscriptionManager` verifies cryptographic integrity on-device, credits the user locally, and retries background sync so **the user never loses purchased entitlements**.

---

## 7. Security & Secret Audit

- **Committed Secrets Scan:** **CLEAN** (0 private keys, 0 service account JSON files, 0 JWT secrets, 0 database passwords).
- **Firebase API Key:** Standard client-side identifier in `GoogleService-Info.plist`, restricted in Google Cloud Console to bundle ID `com.kirtidhwaj.Bhumitra`.
- **App Transport Security (ATS):**
  - **Flagged P0 Item:** Plaintext HTTP endpoint `http://15.206.103.113/api/v1` requires migration to HTTPS domain before final App Store submission.

---

## 8. App Store Privacy Compliance & Data Map

### Discrepancy Analysis vs `APP_STORE_PRIVACY_DATA_MAP.md`:
1. **Analytics Data:** With Firebase Analytics enabled, App Store Connect declarations must include:
   - **Product Interaction:** App functionality, Analytics (Not linked, Not tracking).
   - **Identifiers:** User ID / Device ID (Unlinked pseudonymous `pp_UUID`).
2. **Crash Reporting:** With Firebase Crashlytics enabled, declarations must include:
   - **Crash Data & Diagnostics:** App functionality, Diagnostics (Not linked, Not tracking).

---

## 9. App Size & Optimization Audit

- **Release `.app` Size:** 77 MB
- **Executable Binary:** 20 MB
- **Assets.car:** 13 MB
- **MapLibre Framework:** 7.3 MB
- **Fonts (31 MB Total):**
  - Active: 8 `GoogleSans-*.ttf` files (15.4 MB)
  - **Duplicate Unreferenced:** 8 `GoogleSans_17pt-*.ttf` files (15.6 MB) — **Candidate for immediate removal (reduces size by 20%)**.

---

## 10. Repository Cleanup Candidates

| File / Folder | Category | Size | Reason / Action |
|---|:---:|:---:|---|
| `pre_analytics_stable.bundle` | ARCHIVE / DELETE | 53 MB | Historical Git backup bundle; safely stored in Git history. |
| `phase7.26_verified_stable.bundle` | ARCHIVE / DELETE | 21 MB | Historical Git backup bundle. |
| `phase7.27_verified_stable.bundle` | ARCHIVE / DELETE | 21 MB | Historical Git backup bundle. |
| `build_ws*.log`, `build.log` | DELETE | 2.5 MB | Temporary build output logs. |
| `add_admob.py`, `add_admob.rb` | DELETE | 3.5 KB | Unused legacy script. |
| `test_pw.py`, `patch_pbxproj.py` | ARCHIVE / DELETE | 5 KB | Old exploratory scratch scripts. |
| `MyBhoomi/Resources/Fonts/GoogleSans_17pt-*.ttf` | DELETE | 15.6 MB | Duplicate unreferenced font files. |

---

## 11. Rollback & Emergency Runbook

- **Permanent Rollback Tag:** `v2.0.0-analytics-stable`
- **Permanent Rollback Branch:** `stable/firebase-analytics`
- **Verified Working Commit SHA:** `dec0d1be85de71dfef194c3c9234a983a94b140e`
- **Emergency Rollback Command:**
  ```bash
  git fetch origin --tags
  git switch main
  git reset --hard v2.0.0-analytics-stable
  ```

---

## 12. Final Verdict

### **SHIP STATUS: READY FOR TESTFLIGHT**

**Action Required for App Store Release:**
1. Point `APIConfiguration.defaultProductionURL` to HTTPS backend and remove `NSAllowsArbitraryLoads = true`.
2. Add Firebase Analytics/Crashlytics reason codes to `PrivacyInfo.xcprivacy`.
3. Delete the 8 duplicate `GoogleSans_17pt-*.ttf` font files to save 15.6 MB.
