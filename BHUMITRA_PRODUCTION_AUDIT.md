# Bhumitra — Production-Grade Audit & Change Note

**Date:** 2026-09-28
**Scope:** iOS app (`MyBhoomi/`) + backend (`BhulekBackend/`) + admin service (`OdishaAdminService/`)
**Builds on:** `PRETTYPlot_PRODUCTION_AUDIT.md` (2026-09-25, still current) and `.kiro/architecture.md`.
This note is the single running list of **what has been changed**, **what can be changed**, and **what must be done** to reach absolute production grade. Update it as items close.

---

## 0. What "Bhumitra" means for this repo

The product ships under the name **Bhumitra**. The codebase still carries two older names:
- **`MyBhoomi`** — the Xcode target / module / bundle folder name (structural; safe to keep, renaming is high-churn and cosmetic).
- **`PrettyPlot` / `Preetyplot` / `api.prettyplot.in`** — the previous brand. User-visible text must read **Bhumitra**; the API domain is infrastructure and is a separate decision (see §2).

---

## 1. Rebrand: PrettyPlot → Bhumitra

### 1.1 DONE (2026-09-28) — user-visible strings
Every string a user can actually read now says **Bhumitra**:

| File | What changed |
|---|---|
| `MyBhoomi/Domain/Models/LandDetailsReportModels.swift` | Provenance display + badge strings: `"PrettyPlot GIS"→"Bhumitra GIS"`, `"Calculated by PrettyPlot"→"Calculated by Bhumitra"`; file header comment |
| `MyBhoomi/Presentation/ViewModels/LandRecordReportViewModel.swift` | Share-report header `PRETTYPLOT OFFICIAL…→BHUMITRA OFFICIAL…`, footer `Generated with PrettyPlot→…Bhumitra`, source line `PrettyPlot GIS Layer→Bhumitra GIS Layer` |
| `MyBhoomi/MyBhoomiApp.swift` | Maintenance banner + "newer version available" banner: `Preetyplot→Bhumitra` |
| `MyBhoomi/Presentation/Views/LandRecordReportView.swift` | File header comment |
| `MyBhoomi/Presentation/Views/SplashScreenView.swift` | Wordmark comment |

### 1.2 TODO — deliberately NOT auto-changed (need a decision or asset)

- **Splash wordmark asset `PreetyplotLogo`** — **DONE (2026-09-28).** New `BhumitraWordmark.imageset` (@1x/@2x/@3x, brand purple `#7C3AED`, transparent bg, legible on both light-white and dark-black splash canvases) added to `Assets.xcassets`; both `Image("PreetyplotLogo")` refs in `SplashScreenView.swift` repointed to `Image("BhumitraWordmark")` (base + shine-sweep mask). Old `PreetyplotLogo.imageset` left in place, now unreferenced — safe to delete. Generator: `docs/app-icon-concepts/make_wordmark.py`.
- **Enum case identifiers** `prettyPlotGIS` / `prettyPlotCalculated` (`LandDetailsReportModels.swift`, referenced in `LandDetailsReportBuilder.swift` + `run_land_record_report_tests.swift`) — code-only, invisible to users. Renaming to `bhumitraGIS` etc. is a safe mechanical refactor but touches 3 files + tests; do it in a dedicated pass to avoid mixing with behavior changes.
- **API domain `api.prettyplot.in`** (`APIConfiguration.swift`, `AppConfig.swift` comment) — see §2. **Do not blind-rename.**
- **Old audit/doc filenames + git author "PrettyPlot" commit messages** — historical; no runtime effect.

---

## 2. Infrastructure branding: `api.prettyplot.in` (DECISION NEEDED)

`APIConfiguration.swift` hard-wires **all Release traffic** to `https://api.prettyplot.in/api/v1`. This is the **live production backend the shipping app calls**. Renaming the string does nothing on its own and, if the DNS is later retired, would break every install.

To move to a Bhumitra domain (e.g. `api.bhumitra.app`) requires, in order:
1. Register/point the new domain's DNS at the current backend host (AWS EC2 `15.206.103.113` per `CLOUD_RUN_PRODUCTION_REPORT.md`).
2. Provision a TLS cert for it and confirm the backend serves it.
3. Update `finalProductionHTTPSURL` / `defaultProductionURL` / `awsTestingURL` in `APIConfiguration.swift`.
4. Keep the old domain resolving for a deprecation window so already-installed apps keep working.

**Until you decide and the DNS exists, leave the domain as-is.** This is a one-way-door infra change, not a text edit.

---

## 3. Open production blockers (carried from the 2026-09-25 audit)

**P0 — RESOLVED (re-verified live 2026-09-28 ~20:24 UTC against `api.prettyplot.in`):**
- ~~Backend deployment drift~~ **FIXED.** `/health` → 200 (0.65s); `/api/v1/version` now returns a **real git SHA** (`6b972b55…`, was `"unknown"`) and self-identifies as **"Bhumitra Backend"**; `/api/v1/location/search?q=KIIT` → **200 with real data** (was 404); `/api/v1/location/resolve` → 200 via `lat`/`lng` GET or POST; `/api/v1/districts` and `/api/v1/gis/districts` → 200. The version-stamp fix (old item F2) is in place. The single biggest go-live risk from the Sep-25 audit is gone.

**Still open:**
- **GIS↔Bhulekh identity mismatch.** Census GIS names ("Dhamanagar" as district, "Phalapur") don't match Bhulekh revenue names ("DHAMNAGAR", district BHADRAK). App forwards GIS identity verbatim → backend correctly refuses. **Fix:** extend the GIS→Bhulekh village crosswalk for missing tahasils; never guess mappings. (Now that `/location/resolve` is live, verify whether coordinate→jurisdiction resolution already mitigates this in practice.)

**P1**
- **iOS collapses all errors into "Record unavailable".** `RoRErrorState` has granularity, but `LandServicesViews.performActualSearch` reports outages, unmapped identities, and true no-records identically. **Fix:** map backend error `code` → distinct states + copy ("Official service temporarily unavailable" / "This village isn't verified in official records yet — try manual search" / "No record found" / "No connection").

**P2**
- Triage ~64 `try?` uses in `Services/` (mostly benign prefetch).
- Structured `os.Logger` categories (`[LocationSearch] [ParcelLookup] [LandRecordLookup] [StoreKit] [PurchaseActivation]`) with durations, no PII/tokens.

---

## 4. Production-grade checklist (path to "absolute production grade")

### Release / store
- [ ] Google Play product IDs + OAuth client ID (per member briefing "queued after verification").
- [ ] Live StoreKit sandbox purchase round-trip on device (design verified in code; run not yet executed).
- [ ] App icon: current set is only `AppIcon-1024` + `-dark` (no tinted variant). Finalize the chosen concept and generate light/dark/tinted (see `docs/app-icon-concepts/`).
- [ ] Splash `PreetyplotLogo` → Bhumitra wordmark (§1.2).
- [ ] Backend account-deletion endpoint (App Store requirement; queued).

### Reliability / observability
- [ ] Redeploy backend + version SHA stamp (§3 P0).
- [ ] iOS diagnostics screen shows backend phase + git SHA + catalog version.
- [ ] Distinct error surfaces (§3 P1).
- [ ] Characterize edge 429/burst behavior (one dropped connection seen under 4 rapid requests).

### Hygiene
- [ ] `.gitignore` for build caches / SPM checkouts — the repo tree includes `DerivedData/`, `build_device/`, `.build/`, `.moduleCache/`, `.spmCache/`, `venv/` (tens of thousands of files). Confirm they're ignored and untracked.
- [ ] Split oversized views (member rule: no file >300 lines) — e.g. `VillagePickerSheet.kt` on the Android port; on iOS `LandRecordReportView.swift` and `CadastralPlotCardView.swift` are large.
- [ ] Remove stray scratch/log files at repo root (`build_ws*.log`, `*.bundle` snapshots, `user_audio.txt`, `test_pw.py`).

### Data correctness (the trust promise)
- [ ] Never fabricate land data — enforced today via typed sources/`"-"` placeholders. Keep it that way; the "official vs calculated" provenance badge (§1.1) is the user's trust signal.
- [ ] Expand crosswalk coverage; publish a coverage % in diagnostics.

---

## 5. Verification status (from 2026-09-25 audit)
- Backend: **110/110** pytest passed (46 s).
- iOS: **167/169** — the 2 failures are live-EC2-dependent (prod 404 drift), pass on local server.
- StoreKit/credit ledger: idempotent, server-authoritative, immutable ledger — verified in code.

---

## 6. This session's changes (2026-09-28)
- Rebranded all user-visible PrettyPlot/Preetyplot strings → Bhumitra (§1.1, 8 edits across 5 files).
- Not built here: the Swift toolchain can't run in this shell sandbox (SPM resolution blocked). **Build in Xcode to confirm** — all edits are string/comment-only, no API surface changed, so compile risk is near-zero.

---

## 7. Pre-publish review (2026-09-28, App Store readiness)

**Passes:** display name `Bhumitra`, bundle `com.kirtidhwaj.Bhumitra`, v2.1 (build 3), encryption declared NO, location usage string is clear, privacy manifest present (no tracking), Restore Purchases present, account deletion wired and live (`DELETE /api/v1/auth/me` → 401 unauthenticated in prod), privacy policy live and branded Bhumitra, Firebase/entitlements production, no debug UI/logging in Release, Xcode synchronized folders auto-include the new files.

**Must fix before submitting**
1. Satellite/labels tiles pulled straight from `mt1.google.com/vt` (`MapLibreView.swift` ~660/683). This is an undocumented Google endpoint, which breaks Google's terms; it can get the app rejected or have the tiles cut off. Switch to a licensed provider (MapTiler, Mapbox, Esri, or the Google Map Tiles API with a key).
2. Privacy policy doesn't mention Google Sign-In/Firebase or how to delete an account. Guideline 5.1.1 requires it to disclose what's collected, which third parties receive it, and how to request deletion.
3. Privacy manifest doesn't list Email Address / Name, which Apple and Google sign-in collect. Add both (linked, App Functionality) and match them in the App Store Connect privacy labels.
4. Commit the work: 30 modified files plus 3 new ones (`DebugLog.swift`, `BhumitraWordmark.imageset`, this note) are uncommitted on `feature/perf-search-settings-payments`. Merge to the release branch before archiving.
5. Build number: `CURRENT_PROJECT_VERSION = 3` must be higher than the last build uploaded to App Store Connect.

**Decide**
- Deployment target iOS 26.0 leaves out every device on iOS 18 or older, which is a large share of the Indian market. Lower it if the APIs allow.
- iPad is enabled (`TARGETED_DEVICE_FAMILY 1,2`): you'll need iPad screenshots and iPad layout QA, or make it iPhone-only.
- App icon is still the old one (you said you want a new one).
- Subscription copy says "Bhumitra + Land Simplified Terms", but the Terms link opens Apple's standard EULA. Confirm the name and that link are what you intend.

**Nice to have**
- `NSAllowsLocalNetworking` in Info.plist only exists for the dev server. Remove it from Release.
- Delete the unused `PreetyplotLogo.imageset`; rename the `prettyPlot*` enum cases.
- Run one live sandbox purchase on a device before submitting.

### 7.1 Done (2026-09-28, second pass)
- **Map tiles licensed:** Google `mt1.google.com/vt` satellite + labels and community `tile.openstreetmap.org` streets replaced with Esri ArcGIS basemaps via `MyBhoomi/Map/MapLibre/MapTileProvider.swift`; attribution button re-enabled. **Blocked on key:** set `ArcGISAPIKey` in `CustomInfo.plist` (empty placeholder added); until then the base map is blank.
- **Privacy manifest:** added Email Address, Name, Device ID (all linked, App Functionality). Mirror these in App Store Connect → App Privacy.
- **Privacy policy:** new draft at `docs/privacy-policy.md` (third parties, retention, in-app deletion path, device anti-abuse record). **Publish it** to `kirtidhwajpatra.github.io/Bhumitra_PrivacyPolicy/`.
- **Build number** 3 → 4 (all configs).
- **Rebrand finished:** enum cases `prettyPlot*` → `bhumitra*`, `prettyPlotNotes` → `bhumitraNotes`, and the remaining visible strings ("PrettyPlot Comprehensive Land Report", geometry-source labels). Standalone report tests: 34/34 pass. Only `api.prettyplot.in` remains, by design.
- **Removed:** unused `PreetyplotLogo.imageset`; hard-coded `/Users/uday/…/style.json` fallback path in `MapLibreView`.

### 7.2 Left as-is, with reason
- `NSAllowsLocalNetworking`: Apple accepts it without review justification, and the simulator dev server needs it.
- iOS 26 target, iPad support, app icon, "Land Simplified" terms wording: your decisions. Lowering the target means wrapping 15 `glassEffect` uses (8 files) in availability checks and a build/test loop in Xcode.
- Map text labels load glyphs from `demotiles.maplibre.org` (MapLibre's demo server, no uptime promise). Bundle the glyphs or point at a hosted font endpoint after launch.
- Backend `delete_me` still prints `DEBUG:` lines to server logs (not user-facing).
