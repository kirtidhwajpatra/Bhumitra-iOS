# BHUMITRA iOS — APP STORE CONFIGURATION & METADATA AUDIT

**Target:** `MyBhoomi.xcodeproj` / `CustomInfo.plist` / `MyBhoomi.entitlements`  
**Audit Date:** 2026-08-31  
**App Bundle ID:** `com.kirtidhwaj.Bhumitra`  
**Target Platform:** iOS 17.0+ (iPhone & iPad)  

---

## 1. Core Metadata & Binary Identity

| Parameter | Configured Value | Status | App Store Compliance |
|---|---|:---:|---|
| **Bundle Identifier** | `com.kirtidhwaj.Bhumitra` | **PASS** | Matches App Store Connect App Record. |
| **Marketing Version (`CFBundleShortVersionString`)** | `2.0.0` | **PASS** | Semantic versioning aligned. |
| **Build Number (`CFBundleVersion`)** | `1` | **PASS** | Monotonically incrementable for TestFlight. |
| **Deployment Target** | `iOS 17.0` | **PASS** | Supports iOS 17.0, 17.5, 18.0+. |
| **Targeted Device Family** | `1,2` (iPhone & iPad) | **PASS** | Universal iOS deployment. |
| **Supported Orientations** | Portrait (iPhone), Portrait & Landscape (iPad) | **PASS** | Standard iOS navigation experience. |
| **Display Name (`CFBundleDisplayName`)** | `Bhumitra` | **PASS** | Aligned with brand and guidelines. |

---

## 2. Capabilities, Entitlements & Permissions

| Capability / Key | Declared in Code / Plist | Usage Rationale | Apple App Review Status |
|---|---|---|:---:|
| **Sign in with Apple** | `MyBhoomi.entitlements` (`com.apple.developer.applesignin`) | Mandatory companion to Google Sign-In (Guideline 4.8). | **COMPLIANT** |
| **Location Permission** | `NSLocationWhenInUseUsageDescription` in `CustomInfo.plist` | Displays user position relative to cadastral parcels on MapLibre GIS map. | **COMPLIANT** |
| **Google Sign-In URL Scheme** | `CFBundleURLTypes` & `GIDClientID` in `CustomInfo.plist` | OAuth2 callback scheme for Google Authentication. | **COMPLIANT** |
| **Custom Typography** | `UIAppFonts` (GoogleSans font family) | Embedded TTF typography. | **COMPLIANT** |
| **Camera / Photos / IDFA** | **Omitted** | Zero unnecessary permission prompts requested. | **COMPLIANT** |

---

## 3. Network Transport Security & HTTP Exception

- **`NSAppTransportSecurity` Status:** Currently contains `NSAllowsArbitraryLoads = true` and `15.206.103.113` exception.
- **Production Assessment:** App Store submission **requires** pure HTTPS without arbitrary load exceptions. This item is **intentionally postponed** pending DNS propagation for `api.bhumitra.app`.
- **TestFlight Status:** Internal TestFlight builds run safely over HTTP; App Store public release is gated on HTTPS.
