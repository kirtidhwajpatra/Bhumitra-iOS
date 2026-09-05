# BHUMITRA iOS — END-TO-END PRODUCT FLOW AUDIT

**Application:** Bhumitra (Odisha Land Records & Cadastral GIS)  
**Audit Date:** 2026-08-31  
**Scope:** Complete User Journeys, Edge Cases, Data Integrity, and UX Safeguards.  

---

## 1. Journey A: First-Time User Onboarding & Activation

### Step-by-Step Flow:
1. **App Launch (`SplashScreenView`):**
   - Brand entrance animation displays smoothly with 4.0s progress indicator.
   - Zero jarring pops or flickering.
2. **Onboarding Carousel (`OnboardingView`):**
   - 3 high-impact slides introducing: (1) Odisha Cadastral Map & Boundaries, (2) Official RoR Verification, (3) Instant Area Calculator.
   - Emits `onboarding_started`.
3. **CTA Completion ("Get Started"):**
   - Tapping "Get Started" grants 3 free search credits and sets `hasCompletedOnboarding = true`.
   - Emits `onboarding_completed(durationSeconds: X)`.
4. **Location Permission Prompt:**
   - Standard iOS `NSLocationWhenInUse` system alert with clear bilingual Odisha context.
   - If granted: Camera animates to user's real GPS position.
   - If denied: Gracefully defaults to Central Odisha (Bhubaneswar/Cuttack) without crashing or blocking.
5. **Initial Parcel Tap & Activation:**
   - Tapping any parcel boundary fetches RoR data, deduplicates state, and reveals bottom card.
   - **Core Activation KPI:** Emits `land_record_successfully_viewed`.

---

## 2. Journey B: Cadastral Map & GIS Interactions

- **Map Engine:** MapLibre Native with Metal GPU acceleration.
- **Gesture Performance:** 60 FPS silky smooth panning, pinching, and rotating.
- **Cadastral Vector Layers:**
  - High-contrast neon green/cyan boundary outlines.
  - Tapping a polygon executes spatial query against vector geometry to extract `plot` and `village` identifiers.
- **Layer Switching:**
  - Instant transition between Standard Vector Map and High-Resolution Satellite Raster.
- **Offline / Low-Connectivity Handling:**
  - Cached vector tiles remain interactive; when offline, top banner displays `NetworkStatusBannerView` and informs user without interrupting map panning.

---

## 3. Journey C: 4-Tier Manual Search & Verification Funnel

### Search Methods Supported:
1. **By Plot Number:** Select District $\rightarrow$ Tahasil $\rightarrow$ Village $\rightarrow$ Enter numeric Plot ID.
2. **By Khata Number:** Select District $\rightarrow$ Tahasil $\rightarrow$ Village $\rightarrow$ Enter Khata ID.
3. **By Tenant Name:** Select District $\rightarrow$ Tahasil $\rightarrow$ Village $\rightarrow$ Enter full/partial owner name.

### Funnel & Resilience Safeguards:
- **Input Validation:** Numeric fields sanitize non-digit characters; submit CTA is disabled until required hierarchy is chosen.
- **SingleFlight Coalescing:** Rapid double-taps on "Search Land" are coalesced; only 1 network request is dispatched.
- **Government Classification Banner:** Clearly highlights verified government parcels (e.g., *Rakhit / Sarbasadharana / Anabadi*) with distinct visual badges to prevent land disputes.

---

## 4. Journey D: Official RoR vs Bhumitra Digital Passport

### Clear Legal Distinction:
- **Official Government RoR PDF (`OfficialRoRPDFService`):**
  - Downloaded directly from the official Bhulekh portal repository.
  - Tagged with official government watermark and stamp.
- **Bhumitra Digital Passport (`LandPassportDetailView`):**
  - Modern, high-readability digital summary designed by Bhumitra.
  - Features prominent disclaimer: *"Bhumitra Digital Passport is an informational summary compiled from public land records. For official legal transactions, please download the Official RoR PDF."*

---

## 5. Journey E: Offline Saved Lands & Data Persistence

- **Persistence Layer:** `SavedLandManager` utilizing encrypted on-device storage.
- **Save Action:** 1-tap bookmarking from parcel card or passport sheet.
- **Offline Access:** Saved parcels display complete ownership tables, plot areas, and notes without requiring network connectivity.
- **Swipe-to-Delete:** Smooth swipe gesture to remove entries with undo/confirmation safeguards.

---

## 6. Journey F: User Authentication & Identity Lifecycle

- **Guest Session:** Immediate access without forced login walls.
- **Sign in with Apple:** One-tap authentication using Apple ID Private Relay.
- **Sign in with Google:** Seamless OAuth authorization via `GoogleSignInSwift`.
- **Identity Continuity:**
  - User's persistent analytics UUID (`pp_UUID`) survives guest mode, login, logout, and re-login.
  - Logging out preserves saved lands and restores guest state without session confusion.
  - **Account Deletion:** Explicit 2-step destructive confirmation dialog calls backend purge and purges local Keychain credentials.

---

## 7. Journey G: StoreKit 2 Monetization & Credit Quota Invariants

### Invariant Rules:
1. **Credit Deduction Gate:**
   - Credits are **never deducted before or during a network request**.
   - Credit deduction occurs **strictly upon verified HTTP 200 RoR record display**.
   - Failed searches, 404 not found, timeouts, and cached parcel redraws **consume 0 credits**.
2. **Purchase Entitlement Verification:**
   - In-app purchases send signed StoreKit 2 JWS receipts to backend for cryptographic verification against Apple Root CAs.
   - **Offline Resilience:** If backend is temporarily unreachable, StoreKit 2 local verification grants immediate user entitlement on-device so the user is never denied their purchase.

---

## 8. Journey H: Land Area Unit Converter

- **Mathematical Engine:** Bidirectional 22-unit conversion matrix.
- **Regional Accuracy:** Exact Odisha customary ratios verified:
  - $1 \text{ Acre} = 100 \text{ Decimals}$
  - $1 \text{ Acre} = 43,560 \text{ Sq Feet}$
  - $1 \text{ Acre} = 4,046.856 \text{ Sq Meters}$
  - $1 \text{ Acre} = 4,840 \text{ Sq Yards (Gaj)}$
  - $1 \text{ Mana} = 25 \text{ Decimals}$
  - $1 \text{ Guntha} = 4 \text{ Decimals}$
- **Direct Parcel Prefill:** Tapping "Area Converter" from any parcel card automatically loads that plot's exact acreage.

---

## 9. Journey I: Error Recovery & Empty States

| Failure Scenario | User Experience & Recovery |
|---|---|
| **No Internet Connection** | Floating non-intrusive offline banner; cached maps and saved lands remain 100% readable. |
| **Plot Not Found (404)** | Friendly empty-state card suggesting spelling check or cadastral map manual selection. |
| **Upstream Bhulekh Slowdown** | Automatic background fallback cache utilized; progress spinner with timeout cancellation. |
| **0 Credits Remaining** | Contextual paywall sheet appears with option to claim daily bonus or upgrade to Pro. |
| **Payment Cancelled** | Silently dismisses payment modal; no error popups or penalty. |
