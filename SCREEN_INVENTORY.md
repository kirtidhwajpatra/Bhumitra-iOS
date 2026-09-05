# BHUMITRA iOS — COMPLETE SCREEN & COMPONENT INVENTORY

**Application:** Bhumitra (Odisha Land Records & Cadastral GIS)  
**Bundle ID:** `com.kirtidhwaj.Bhumitra`  
**Platform:** iOS 16.0+ (SwiftUI + MapLibre Native)  
**Audit Date:** 2026-08-31  

---

## 1. Primary Full-Screen Views & Containers

### 1. `SplashScreenView`
- **File:** `MyBhoomi/Presentation/Views/SplashScreenView.swift`
- **Entry Point:** Application root startup (`MyBhoomiApp.swift` via `RootContainerView`).
- **Exit Points:** Automatically finishes and transitions to `OnboardingView` (if first launch) or `MainView` (if onboarding completed).
- **Parent:** `RootContainerView`
- **Child Views:** `GoogleLogoView`, animated progress indicator, background radial gradient.
- **Purpose:** Brand introduction, asset pre-warming, and smooth entrance animation.
- **Network Requests:** None.
- **Auth Requirement:** None.
- **Credit / Subscription Requirement:** None.
- **Analytics Events:** `app_opened`.
- **Loading / Error / Empty States:** Displays 4.0s paced linear loading bar; no error state required.
- **Offline Behavior:** Works 100% offline.

### 2. `OnboardingView`
- **File:** `MyBhoomi/Presentation/Views/OnboardingView.swift`
- **Entry Point:** Initial launch when `hasCompletedOnboarding == false`.
- **Exit Points:** "Get Started" CTA transitions user to `MainView`.
- **Parent:** `RootContainerView`
- **Child Views:** `LoopingVideoBackgroundView`, feature carousel cards, page indicator.
- **Purpose:** Onboards new users with feature highlights (Cadastral boundaries, RoR lookup, Land Passport).
- **Network Requests:** None.
- **Auth Requirement:** None (Guest allowed).
- **Credit / Subscription Requirement:** None (+3 free credits granted on onboarding completion).
- **Analytics Events:** `onboarding_started`, `onboarding_completed`.
- **Loading / Error / Empty States:** Self-contained static carousel; video fallback gradient if asset missing.
- **Offline Behavior:** Works 100% offline.

### 3. `MainView`
- **File:** `MyBhoomi/Presentation/Views/MainView.swift`
- **Entry Point:** Main application state after splash and onboarding.
- **Exit Points:** Dismissal / backgrounding.
- **Parent:** `RootContainerView`
- **Child Views:** `MapLibreView`, `MapHomeOverlay`, `CadastralPlotCardView`, `NetworkStatusBannerView`, `ClaimFreeCreditsModalView`.
- **Purpose:** Master coordinator view orchestrating the MapLibre GIS map and contextual overlays.
- **Network Requests:** Map vector tile downloads (`*.pmtiles` or vector endpoint).
- **Auth Requirement:** None (Guest mode supported).
- **Credit / Subscription Requirement:** None for map viewing; credits required for verified RoR lookup.
- **Analytics Events:** None directly (child views emit).
- **Loading / Error / Empty States:** Skeleton shimmer on parcel card loading; banner on offline.
- **Offline Behavior:** Displays cached tiles and offline banner if disconnected.

### 4. `ForceUpdateView`
- **File:** `MyBhoomi/Presentation/Views/ForceUpdateView.swift`
- **Entry Point:** Remote Config gate when app version < `min_supported_version`.
- **Exit Points:** External link to App Store URL.
- **Parent:** `RootContainerView`
- **Purpose:** Blocking update barrier preventing obsolete client versions from accessing backend.
- **Network Requests:** Remote Config fetch on launch.
- **Auth / Credit Requirement:** None.
- **Analytics Events:** None.
- **Offline Behavior:** Bypassed if offline unless cached config enforces blocking.

---

## 2. Interactive Overlays, Sheets & Modals

### 5. `MapHomeOverlay`
- **File:** `MyBhoomi/Presentation/Views/MapHomeOverlay.swift`
- **Entry Point:** Rendered directly over `MapLibreView` in `MainView`.
- **Exit Points:** Opens search modal, location picker, saved lands sheet, settings sheet, layer toggle.
- **Parent:** `MainView`
- **Child Views:** `LiquidGlassLocationSelector`, `LiquidGlassMapButton`, `RecentParcelsSectionView`, `OfficialLandRecordsHomeCard`.
- **Interactive Controls:**
  - GPS Locate Button: Centers map camera on user coordinates.
  - Map Style Toggle: Switches between Normal Vector and Satellite Raster layer.
  - Search Bar CTA: Presents `ManualRoRSearchView`.
  - Saved Lands Icon: Presents `SavedLandsView`.
  - Pro / Credits Badge: Presents `SubscriptionView`.
  - Village Location Button: Presents `OfficialLocationPickerSheet`.
- **Network Requests:** Reverse geocoding (OpenStreetMap / Location Service).
- **Analytics Events:** Map taps emit `land_search_started`.
- **Offline Behavior:** Retains current map camera and recent parcels from local cache.

### 6. `CadastralPlotCardView`
- **File:** `MyBhoomi/Presentation/Views/CadastralPlotCardView.swift`
- **Entry Point:** Map parcel selection tap event.
- **Exit Points:** Swipe down dismissal, "View Land Passport", "Official RoR PDF".
- **Parent:** `MainView` (Bottom Sheet Anchor)
- **Child Views:** Plot badge, Government classification chip, Owner count preview, Action buttons.
- **Interactive Controls:**
  - "View Land Passport": Opens `LandPassportDetailView`.
  - "Official RoR PDF": Initiates PDF download via `OfficialRoRPDFService`.
  - "Area Converter": Opens `LandAreaCalculatorView` prefilled with parcel area.
  - "Save Land": Bookmarks parcel to `SavedLandManager`.
- **Network Requests:** `GET /api/v1/ror?district=...&tahasil=...&village=...&plot=...`.
- **Auth Requirement:** None for preview; credits evaluated on RoR fetch.
- **Credit Requirement:** Consumes 1 credit on verified RoR resolution (if non-premium).
- **Analytics Events:** `land_record_viewed`, `land_record_successfully_viewed`, `land_record_action`.
- **Loading State:** Animated skeleton shimmer with plot number placeholder.
- **Error State:** In-card retry button with user-friendly error message.

### 7. `LandPassportDetailView`
- **File:** `MyBhoomi/Presentation/Views/LandPassportDetailView.swift`
- **Entry Point:** "View Land Passport" tap in `CadastralPlotCardView` or `SavedLandsView`.
- **Exit Points:** Sheet dismiss, Share Sheet, PDF Viewer.
- **Child Views:** Ownership breakdown table, Cadastral boundary thumbnail, Area breakdown card, Legal disclaimer banner.
- **Interactive Controls:**
  - "Share Report": Presents native `UIActivityViewController`.
  - "Save Land": Toggles bookmark state.
  - "Download PDF": Downloads and opens official RoR PDF.
  - "Area Calculator": Opens live converter sheet.
- **Analytics Events:** `land_passport_viewed`, `bhumitra_report_viewed`, `bhumitra_report_saved`, `bhumitra_report_shared`.
- **Offline Behavior:** Fully rendered from cached `RoRResponse` model.

### 8. `ManualRoRSearchView`
- **File:** `MyBhoomi/Presentation/Views/ManualRoRSearchView.swift`
- **Entry Point:** Search bar tap on `MapHomeOverlay`.
- **Exit Points:** Sheet dismiss, "Search Land" transition to `UnifiedRoRResultView`.
- **Child Views:** 4-Tier Hierarchical Dropdown Pickers (District $\rightarrow$ Tahasil $\rightarrow$ Village $\rightarrow$ Khata/Plot/Tenant Number).
- **Interactive Controls:**
  - Search Method Picker (`By Plot`, `By Khata`, `By Tenant Name`).
  - District, Tahasil, Village Dropdowns.
  - Query text field with instant numeric/text validation.
  - "Search Land" Submit Button.
- **Network Requests:** Catalog fetch (`/api/v1/villages/search`) and RoR search (`/api/v1/ror`).
- **Analytics Events:** `land_search_started`, `land_search_submitted`, `land_search_succeeded`, `land_search_failed`.
- **Loading State:** Spinning activity indicator inside search CTA with disabled interaction.
- **Error State:** Inline error banner with retry option.

### 9. `UnifiedRoRResultView`
- **File:** `MyBhoomi/Presentation/Views/UnifiedRoRResultView.swift`
- **Entry Point:** Successful search submission in `ManualRoRSearchView`.
- **Exit Points:** Navigation back button, "View on Map", "Download PDF", "Save".
- **Child Views:** RoR header, Owner table, Plot extents, Government / Private status badge.
- **Analytics Events:** `land_record_successfully_viewed`, `land_record_action`.
- **Offline Behavior:** Caches result for offline review.

### 10. `OfficialLandRecordsView` & `OfficialLocationPickerSheet`
- **File:** `MyBhoomi/Presentation/Views/OfficialLandRecordsView.swift`, `OfficialLocationPickerSheet.swift`
- **Entry Point:** Village selector card tap in `MapHomeOverlay`.
- **Exit Points:** Location selection dismiss, Plot detail sheet.
- **Child Views:** Alphabetical district index, Tahasil search filter, Village list with cadastral coverage indicators.
- **Interactive Controls:** Search bar, Tahasil accordion, Village row tap (animates map camera).
- **Network Requests:** `/api/v1/villages/catalog`.

### 11. `SavedLandsView`
- **File:** `MyBhoomi/Presentation/Views/SavedLandsView.swift`
- **Entry Point:** Bookmarks icon in `MapHomeOverlay` header.
- **Exit Points:** Sheet dismiss, Parcel row tap $\rightarrow$ `LandPassportDetailView`.
- **Child Views:** Search filter bar, Saved parcel cards, Empty bookmarks placeholder.
- **Interactive Controls:**
  - Parcel Row Tap: Opens `LandPassportDetailView`.
  - Swipe-to-Delete: Removes parcel from `SavedLandManager`.
  - "Clear All": Confirmation alert to purge saved list.
- **Network Requests:** None (Pure local persistence).
- **Empty State:** Illustrated empty bookmark graphic with "Explore Map" button.
- **Offline Behavior:** 100% operational offline.

### 12. `SubscriptionView` & `PurchaseSuccessModalView`
- **File:** `MyBhoomi/Presentation/Views/SubscriptionView.swift`, `PurchaseSuccessModalView.swift`
- **Entry Point:** Pro badge tap, paywall trigger on exhausted credits, or settings menu.
- **Exit Points:** Sheet dismiss, purchase confirmation modal.
- **Child Views:** Plan selection cards (Monthly, Yearly, Lifetime), Consumable plot credit packs (10, 50, 200), Feature comparison list, Legal footer.
- **Interactive Controls:**
  - Plan Selector Cards: Sets active product selection.
  - "Subscribe Now / Buy Credits" Button: Triggers StoreKit 2 transaction sheet.
  - "Restore Purchases" Button: Calls `AppStore.sync()`.
  - Terms of Service Link: Opens Safari web view.
  - Privacy Policy Link: Opens Safari web view.
- **Network Requests:** `POST /api/v1/subscription/credits/purchase` (Authoritative backend receipt verification).
- **Analytics Events:** `paywall_viewed`, `product_selected`, `purchase_started`, `purchase_completed`, `purchase_cancelled`, `purchase_failed`.
- **Loading State:** Full-card dimmed shimmer overlay during Apple StoreKit sheet processing.

### 13. `LoginView` & `ManageAccountView`
- **File:** `MyBhoomi/Presentation/Views/LoginView.swift`, `ManageAccountView.swift`
- **Entry Point:** Profile avatar in header or Settings sheet.
- **Exit Points:** Dismissal upon successful authentication.
- **Interactive Controls:**
  - "Sign in with Apple" Button: Native `ASAuthorizationAppleIDButton`.
  - "Sign in with Google" Button: Native Google GIDSignIn flow.
  - "Continue as Guest" Button: Closes modal in guest mode.
  - "Log Out" Button (ManageAccount): Clears session token, preserves `pp_UUID`.
  - "Delete Account" Button (ManageAccount): Destructive confirmation dialog $\rightarrow$ purges remote account & resets `pp_UUID`.
- **Analytics Events:** `auth_screen_viewed`, `login_started`, `login_completed`, `login_failed`, `guest_session_started`, `logout_completed`, `account_deleted`.

### 14. `LandAreaCalculatorView`
- **File:** `MyBhoomi/Presentation/Views/LandAreaCalculatorView.swift`
- **Entry Point:** Tools menu, Passport CTA, or Quick Actions sheet.
- **Exit Points:** Sheet dismiss.
- **Child Views:** Input amount field, Source unit selector, Target unit selector, 22-unit live conversion matrix, Swap units button, Copy result CTA.
- **Supported Units:** Acre, Decimal, Guntha, Mana, Katha, Cent, Sq Feet, Sq Meter, Sq Yard (Gaj), Hectare, Bigha, Biswa, etc.
- **Offline Behavior:** 100% offline mathematical conversion engine.

### 15. Utility & Diagnostic Sheets
- `LocationDetailSheet.swift`: Quick GPS coordinate inspector and boundary metadata.
- `QuickFeaturesSheet.swift`: Grid of secondary tools (Area Calculator, Saved Lands, Official Portal).
- `CadastralVillagePickerSheet.swift`: Quick village selector for cadastral vector layers.
- `ClaimFreeCreditsModalView.swift`: Onboarding promotional modal (+3 credits).
- `SaveLandSuccessModalView.swift`: Animated checkmark modal on saving land.
- `NetworkStatusBannerView.swift`: Top floating notification when device is disconnected.
