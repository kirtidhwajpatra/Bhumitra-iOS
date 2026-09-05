# BHUMITRA iOS — TESTFLIGHT MANUAL QA MATRIX

**Audit Date:** 2026-08-31  
**Build Target:** `MyBhoomi` iOS Release Build (Universal iPhone/iPad)  
**Standard:** Apple App Review Guideline 2.1 (App Completeness)  

---

## 1. Manual Device Test Matrix (25 Core Scenarios)

| Test ID | Feature Area | Test Steps | Expected Behavior | Verification Status | Notes |
|:---:|---|---|---|:---:|---|
| **QA-01** | **Fresh Install & Launch** | Install fresh build from TestFlight. Launch app. | Splash renders, Onboarding carousel appears smoothly, 10 starter credits initialized. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies first-time launch Keychain initialization. |
| **QA-02** | **Location Authorization** | Tap "Enable Location" on Onboarding or Map. | iOS system dialog appears with clear purpose string. Map centers on user position. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies `NSLocationWhenInUseUsageDescription`. |
| **QA-03** | **Location Denied Fallback** | Tap "Don't Allow" on system location dialog. | Map defaults to Bhubaneswar/Odisha state center; user can still search parcels manually. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | App must not crash or block interaction. |
| **QA-04** | **GIS Parcel Tap** | Pan to covered village (e.g. G Keri) and tap parcel. | MapLibre highlights parcel polygon in cyan/orange; bottom sheet slides up with plot info. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies MapLibre vector tile feature querying. |
| **QA-05** | **Manual RoR Search** | Enter District, Tahasil, Village, Plot in Search View. | Search dropdown queries local catalog; returns valid plot and opens Land Detail view. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies 3-tier cascading dropdown filter. |
| **QA-06** | **Official RoR Retrieval** | Tap "View Official RoR" on plot details sheet. | Calls `/api/v1/ror`; displays owners, khata, area, and land classification in styled card. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies live or cached RoR retrieval. |
| **QA-07** | **Official PDF Download** | Tap "Download Official PDF" on RoR screen. | Native QuickLook preview opens with generated official government-formatted PDF. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies PDF byte stream rendering. |
| **QA-08** | **PDF Share Sheet** | Tap Share button in QuickLook PDF viewer. | iOS `UIActivityViewController` opens; allows AirDrop, WhatsApp, Files export. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies file sharing integration. |
| **QA-09** | **Save to Saved Lands** | Tap bookmark/heart icon on plot details. | Parcel is saved to local SwiftData/SQLite; appears in "Saved Lands" tab offline. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies persistent local storage. |
| **QA-10** | **Sign in with Apple** | Tap native "Sign in with Apple" button. | Apple FaceID/TouchID prompt opens; creates user account and syncs credits. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies Apple ASAuthorizationController. |
| **QA-11** | **Google Sign In** | Tap "Sign in with Google" button. | Google OAuth browser sheet opens; signs in and updates profile in Settings. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies GIDSignIn callback. |
| **QA-12** | **Guest Mode Browsing** | Tap "Continue as Guest" on login sheet. | User enters main map immediately with starter credits and guest ID. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Zero friction activation. |
| **QA-13** | **Guest $\rightarrow$ Account Linking** | Purchase credits as guest, then sign in with Apple. | Guest credits and saved plots seamlessly merge into the authenticated account. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies `appAccountToken` re-keying. |
| **QA-14** | **Sign Out** | Tap "Sign Out" in Manage Account view. | Clears session token; resets active UI context without deleting local saved land cache. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies secure session cleanup. |
| **QA-15** | **Account Deletion** | Tap "Delete Account" $\rightarrow$ Confirm 2-step prompt. | Calls backend deletion endpoint; purges user data, clears Keychain, returns to Onboarding. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Mandatory Apple Guideline 5.1.1(v). |
| **QA-16** | **StoreKit Consumable Purchase** | Tap "+10 Plots (₹99)" in Paywall. | Apple payment sheet opens in Sandbox/StoreKit Test; credits increment upon confirmation. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies StoreKit 2 transaction verification. |
| **QA-17** | **StoreKit Subscription Purchase** | Tap "Monthly Unlimited (₹299/mo)". | Subscribes in Sandbox; badges UI with "PRO UNLIMITED" badge. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies subscription group handling. |
| **QA-18** | **Restore Purchases** | Reinstall app $\rightarrow$ Tap "Restore Purchases". | StoreKit syncs active subscription entitlement; restores Pro status immediately. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies `AppStore.sync()`. |
| **QA-19** | **Credit Consumption** | Perform 1 verified plot search. | Remaining plot credits counter decrements by 1; triggers low credit warning at $\le 3$. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies quota deduction. |
| **QA-20** | **Credit Exhaustion Paywall** | Consume all 10 credits $\rightarrow$ Tap search. | Paywall sheet automatically presents; informs user credits are exhausted. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies soft paywall trigger. |
| **QA-21** | **Airplane Mode (Offline Map)** | Turn on Airplane Mode $\rightarrow$ Open Saved Lands. | Saved plots, cached tiles, and offline cadastral vectors render without crashing. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies offline resilience. |
| **QA-22** | **Network Interruption Recovery** | Start search with degraded WiFi $\rightarrow$ Reconnect. | Shows retry banner; automatically recovers when connection is restored. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies network state observers. |
| **QA-23** | **App Background & Foreground** | Move app to background during map render $\rightarrow$ Return. | State is preserved cleanly; zero memory leaks or OpenGL/Metal context crashes. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies lifecycle state restoration. |
| **QA-24** | **Force Quit During Purchase** | Initiate purchase $\rightarrow$ Force quit app on receipt. | On relaunch, `Transaction.updates` catches transaction and completes fulfillment. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies transaction listener. |
| **QA-25** | **Dynamic Type & Dark Mode** | Switch system to Dark Mode & Large Text. | UI colors adapt to dark palette; text scales gracefully without clipping buttons. | **NOT VERIFIED — MANUAL DEVICE TEST REQUIRED** | Verifies accessibility compliance. |
