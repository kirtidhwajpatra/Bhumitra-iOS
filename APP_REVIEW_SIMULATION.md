# BHUMITRA iOS — APPLE APP REVIEW SIMULATION

**Auditor Persona:** Senior Apple App Reviewer  
**Audit Target:** Bhumitra iOS (Bundle ID: `com.kirtidhwaj.Bhumitra`)  
**Audit Date:** 2026-08-31  

---

## 1. Guideline-by-Guideline Evaluation

### Guideline 2.1 — App Completeness
- **Status:** **PASS / READY FOR REVIEW**
- **Evaluation:** App compiles cleanly without crashes (`BUILD SUCCEEDED`), includes valid placeholder and fallback handling for network outages, and contains zero dead-end buttons or broken links.

---

### Guideline 2.3 — Accurate Metadata & Government Disclaimer
- **Status:** **PASS / READY FOR REVIEW**
- **Evaluation:**
  - **Government Disclaimer:** App prominently features `DisclaimerView` on Onboarding, Map Home, and Land Services stating:
    > *"Bhumitra is an independent application developed for public convenience and informational purposes. This application is NOT affiliated with, endorsed by, sponsored by, or representative of the Government of Odisha or any other government entity."*
  - **Data Attribution:** Clearly attributes public records to official Odisha state land portals (`bhulekh.ori.nic.in`).
  - **No Misleading Emblems:** Zero unauthorized government emblems or falsified certified badges are present.

---

### Guideline 3.1.1 — In-App Purchase & Subscriptions
- **Status:** **PASS / READY FOR REVIEW**
- **Evaluation:**
  - **StoreKit 2 Native Integration:** Uses native Apple StoreKit 2 APIs for all digital purchases.
  - **Pricing Transparency:** `SubscriptionView` clearly distinguishes between consumable search packs (10, 50, 200 plots) and auto-renewable subscriptions (Monthly Unlimited).
  - **Restore Purchases:** Prominently visible in the navigation bar and settings sheet (`AppStore.sync()`).
  - **Terms & Privacy Links:** Direct links to Apple EULA and Bhumitra Privacy Policy are embedded inside the purchase sheet footer.

---

### Guideline 4.8 — Sign in with Apple
- **Status:** **PASS / READY FOR REVIEW**
- **Evaluation:**
  - Sign in with Apple is offered prominently alongside Google Sign-In with equivalent visual prominence.
  - Guest mode is provided for frictionless exploration.

---

### Guideline 5.1.1(v) — Account Deletion
- **Status:** **PASS / READY FOR REVIEW**
- **Evaluation:**
  - `ManageAccountView` provides a direct "Delete Account" button with a 2-step destructive confirmation dialog.
  - Purges user profile and cloud usage records cleanly without forcing users into a web-only flow.

---

### Guideline 5.1.2 — Privacy & Data Collection
- **Status:** **PASS / READY FOR REVIEW**
- **Evaluation:**
  - `PrivacyInfo.xcprivacy` strictly matches actual data collection (`PreciseLocation`, `UserID`, `PurchaseHistory`, `ProductInteraction`, `CrashData`, `PerformanceData`).
  - `NSLocationWhenInUseUsageDescription` provides clear rationale for cadastral map positioning.

---

### Guideline 5.4 — App Transport Security (ATS)
- **Status:** **HOLD FOR PRODUCTION RELEASE (P0-1)**
- **Evaluation:**
  - `CustomInfo.plist` currently allows HTTP arbitrary loads for temporary testing on `15.206.103.113`.
  - **Review Finding:** App Store public release requires closing ATS exceptions once TLS domain (`api.bhumitra.app`) is active.
