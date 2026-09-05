# BHUMITRA iOS — BUTTON-BY-BUTTON INTERACTION AUDIT

**Application:** Bhumitra (Odisha Land Records & Cadastral GIS)  
**Audit Date:** 2026-08-31  
**Scope:** All Interactive Buttons, Pickers, Modals, Navigation Controls, and Gestures.  

---

## 1. Master Interaction Audit Matrix

| Screen / View | Control / Button | Intended Action | Actual Wired Action | Navigation | Feedback / States | Analytics Event | Auth / Credit Rule | Status | Priority |
|:---|:---|:---|:---|:---|:---|:---|:---|:---:|:---:|
| `OnboardingView` | "Get Started" Button | Complete onboarding & enter Map | Sets `hasCompletedOnboarding=true` | Pushes `MainView` | Smooth animated transition | `onboarding_completed` | Free (+3 credits granted) | **PASS** | Normal |
| `OnboardingView` | Carousel Swipe Gesture | Navigate feature slides | Updates `currentPageIndex` | In-place card slide | Page dots animate | None | None | **PASS** | Normal |
| `MapHomeOverlay` | "GPS Locate Me" | Center camera on user location | Calls `LocationManager.requestLocation()` | Animates map camera | Blue pulsing user puck | None | None | **PASS** | Normal |
| `MapHomeOverlay` | "Layer Switcher" | Toggle Normal vs Satellite | Updates `mapStyle` state | Updates MapLibre raster layer | Icon transitions | None | None | **PASS** | Normal |
| `MapHomeOverlay` | "Search Bar CTA" | Open manual search sheet | Sets `showSearchSheet=true` | Modal presentation | Sheet slides up | None | None | **PASS** | Normal |
| `MapHomeOverlay` | "Saved Lands Icon" | Open saved parcels sheet | Sets `showSavedLandsSheet=true` | Modal presentation | Sheet slides up | None | None | **PASS** | Normal |
| `MapHomeOverlay` | "Pro / Credits Badge" | Open subscription paywall | Sets `showSubscriptionSheet=true` | Modal presentation | Sheet slides up | `paywall_viewed` | None | **PASS** | Normal |
| `MapHomeOverlay` | "Location Selector" | Open hierarchical village sheet | Sets `showLocationPicker=true` | Modal presentation | Sheet slides up | None | None | **PASS** | Normal |
| `MapLibreView` | Parcel Boundary Tap | Select cadastral plot & load RoR | Calls `MapViewModel.selectParcel()` | Opens `CadastralPlotCardView` | Outline highlights cyan | `land_search_started` | Evaluates credit quota | **PASS** | Normal |
| `CadastralPlotCardView` | "View Land Passport" | Present full passport sheet | Sets `showPassportSheet=true` | Presents `LandPassportDetailView` | Seamless sheet expand | `land_passport_viewed` | None (RoR pre-fetched) | **PASS** | Normal |
| `CadastralPlotCardView` | "Official RoR PDF" | Download official Bhulekh PDF | Calls `OfficialRoRPDFService.downloadPDF()` | Opens PDF preview modal | Progress spinner in button | `official_ror_download_started` | None | **PASS** | Normal |
| `CadastralPlotCardView` | "Area Converter" | Open calculator with prefill | Sets `showAreaCalculator=true` | Presents `LandAreaCalculatorView` | Prefills acreage | None | None | **PASS** | Normal |
| `CadastralPlotCardView` | "Save Land" | Bookmark parcel | Calls `SavedLandManager.save()` | Displays checkmark toast | Button icon fills yellow | None | None | **PASS** | Normal |
| `CadastralPlotCardView` | "Retry Search" | Re-fetch failed plot record | Calls `RoRService.fetchRoR()` | Reloads card state | Skeleton shimmer spins | `land_search_started` | Re-checks cache/quota | **PASS** | Normal |
| `LandPassportDetailView` | "Share Report" | Open native iOS share sheet | Instantiates `UIActivityViewController` | System share sheet | Native sheet appears | `bhumitra_report_shared` | None | **PASS** | Normal |
| `LandPassportDetailView` | "Download PDF" | Download & share RoR PDF | Calls `OfficialRoRPDFService` | Opens QuickLook viewer | Download bar fills | `official_ror_download_started` | None | **PASS** | Normal |
| `LandPassportDetailView` | "Save Bookmark" | Toggle saved status | Calls `SavedLandManager.toggle()` | Checkmark toast banner | Bookmark icon toggles | `bhumitra_report_saved` | None | **PASS** | Normal |
| `LandPassportDetailView` | Dismiss "X" Button | Close passport sheet | Calls `dismiss()` | Sheet slides down | Smooth GPU spring | None | None | **PASS** | Normal |
| `ManualRoRSearchView` | "Search Method" Tab | Switch between Plot / Khata / Tenant | Updates `searchMethod` enum | Switches input fields | Tab selector animates | None | None | **PASS** | Normal |
| `ManualRoRSearchView` | District Picker | Select Odisha district | Updates `selectedDistrict` | Filters tahasils dynamically | Dropdown animates | None | None | **PASS** | Normal |
| `ManualRoRSearchView` | Tahasil Picker | Select Tahasil | Updates `selectedTahasil` | Filters villages dynamically | Dropdown animates | None | None | **PASS** | Normal |
| `ManualRoRSearchView` | Village Picker | Select Village | Updates `selectedVillage` | Sets active boundary | Dropdown animates | None | None | **PASS** | Normal |
| `ManualRoRSearchView` | "Search Land" CTA | Submit query to backend | Calls `ManualSearchViewModel.search()` | Pushes `UnifiedRoRResultView` | Button shows activity ring | `land_search_submitted` | Consumes 1 credit on 200 | **PASS** | Normal |
| `ManualRoRSearchView` | Clear Text "X" | Clear textfield input | Sets `queryText=""` | Clears field | Text resets | None | None | **PASS** | Normal |
| `UnifiedRoRResultView` | "View on Map" | Fly camera to parcel on map | Updates `MapViewModel.center` & dismisses | Pans map to target plot | Boundary flashes neon | None | None | **PASS** | Normal |
| `UnifiedRoRResultView` | "Download PDF" | Initiate official PDF download | Calls `OfficialRoRPDFService` | Presents PDF sheet | Spinner in button | `official_ror_download_started` | None | **PASS** | Normal |
| `SavedLandsView` | Parcel Row Tap | Open saved land details | Sets `selectedSavedParcel` | Presents `LandPassportDetailView` | Sheet expands | `land_passport_viewed` | None (Offline cached) | **PASS** | Normal |
| `SavedLandsView` | Swipe-to-Delete | Delete parcel from offline storage | Calls `SavedLandManager.delete()` | Removes row with animation | Row slides off-screen | None | None | **PASS** | Normal |
| `SavedLandsView` | "Clear All" Button | Purge all saved bookmarks | Presents confirmation alert | Purges list on confirm | Empties list view | None | None | **PASS** | Normal |
| `SavedLandsView` | "Explore Map" (Empty) | Close sheet and guide to map | Calls `dismiss()` | Dismisses modal | Map revealed | None | None | **PASS** | Normal |
| `SubscriptionView` | "Monthly Plan Card" | Select monthly subscription | Sets `selectedProduct = "bhumitra_premium_monthly"` | Highlights plan card | Card border glows neon | `product_selected` | None | **PASS** | Normal |
| `SubscriptionView` | "Yearly Plan Card" | Select yearly subscription | Sets `selectedProduct = "bhumitra_premium_yearly"` | Highlights plan card | Card border glows neon | `product_selected` | None | **PASS** | Normal |
| `SubscriptionView` | "Lifetime Plan Card" | Select lifetime unlock | Sets `selectedProduct = "bhumitra_premium_lifetime"` | Highlights plan card | Card border glows neon | `product_selected` | None | **PASS** | Normal |
| `SubscriptionView` | Consumable Pack Card | Select 10 / 50 / 200 credits pack | Sets `selectedProduct = "bhumitra.plots.*"` | Highlights pack card | Card border glows neon | `product_selected` | None | **PASS** | Normal |
| `SubscriptionView` | "Subscribe / Purchase" | Launch Apple StoreKit 2 modal | Calls `SubscriptionManager.purchase()` | Presents native iOS payment sheet | Shimmer overlay on view | `purchase_started` | Authoritative backend verify | **PASS** | Normal |
| `SubscriptionView` | "Restore Purchases" | Sync Apple transactions | Calls `AppStore.sync()` | Shows status toast | Spinner on restore text | None | Syncs existing receipts | **PASS** | Normal |
| `SubscriptionView` | "Terms of Service" | Open legal terms in browser | Calls `UIApplication.open(url)` | Opens Safari | Browser opens | None | None | **PASS** | Normal |
| `SubscriptionView` | "Privacy Policy" | Open privacy policy in browser | Calls `UIApplication.open(url)` | Opens Safari | Browser opens | None | None | **PASS** | Normal |
| `LoginView` | "Sign in with Apple" | Native Apple ID authorization | Calls `AuthManager.signInWithApple()` | Closes login on success | Apple native modal | `login_started` | Creates / links user account | **PASS** | Normal |
| `LoginView` | "Sign in with Google" | Native Google OAuth flow | Calls `AuthManager.signInWithGoogle()` | Closes login on success | Google Sign-In sheet | `login_started` | Creates / links user account | **PASS** | Normal |
| `LoginView` | "Continue as Guest" | Enter anonymous guest session | Calls `AuthManager.enterGuestMode()` | Dismisses modal | Transitions to map | `guest_session_started` | Guest quota (3 credits) | **PASS** | Normal |
| `ManageAccountView` | "Log Out" | Clear current user session | Calls `AuthManager.logout()` | Resets view to Guest state | User avatar resets | `logout_completed` | Preserves `pp_UUID` | **PASS** | Normal |
| `ManageAccountView` | "Delete Account" | Permanent account deletion | Calls `AuthManager.deleteAccount()` | Presents destructive alert $\rightarrow$ resets | Resets app state | `account_deleted` | Purges backend & Keychain | **PASS** | Normal |
| `LandAreaCalculatorView` | "Swap Units" Button | Swap source and target units | Swaps unit enum state variables | Re-computes live conversion | Input/output swap values | None | None | **PASS** | Normal |
| `LandAreaCalculatorView` | "Copy Result" Button | Copy converted value to clipboard | Writes string to `UIPasteboard.general` | Displays copied checkmark toast | Icon changes to checkmark | None | None | **PASS** | Normal |
| `ClaimFreeCreditsModalView`| "Claim Free Credits" | Credit +3 bonus search credits | Calls `SubscriptionManager.addCredits(3)` | Dismisses modal | Confetti animation | None | First install promo | **PASS** | Normal |

---

## 2. Interaction Summary Statistics

- **Total Interactive Elements Audited:** **46 controls**
- **PASS:** **46 (100%)**
- **FAIL:** **0**
- **PARTIAL:** **0**
- **NOT VERIFIED:** **0**
