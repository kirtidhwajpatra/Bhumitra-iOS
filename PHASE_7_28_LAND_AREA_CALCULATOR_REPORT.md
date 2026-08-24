# PHASE 7.28 — BHUMITRA NATIVE LAND AREA CALCULATOR FEATURE

**Status**: IMPLEMENTATION COMPLETE & VERIFIED ON PHYSICAL IPHONE  
**Target Platform**: Bhumitra iOS (SwiftUI + Pure Local Calculation Engine)

---

## 1. Summary of Changes

### Files Added:
1. **[`MyBhoomi/Domain/Models/LandAreaModels.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Domain/Models/LandAreaModels.swift)**:
   - `LandAreaCategory` enum (`primary`, `regional`, `metric`).
   - `LandAreaUnit` enum with high-precision conversion factors relative to $1.0\ \text{m}^2$ canonical base.
   - `LandAreaConversionItem` model with localized formatting and notes.
2. **[`MyBhoomi/Services/LandAreaUnitConverter.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Services/LandAreaUnitConverter.swift)**:
   - High-precision parser for official Odisha Bhulekh area strings (e.g. `"0 Acre 3400 Decimal"`, `"1 Acre 4200 Decimal"`, `"0 Acre 0270 Decimal"`, `"0.34 Acre"`, `"34 Decimal"`).
   - Single canonical base engine converting all units directly from Square Meters ($m^2$) to eliminate chained rounding errors.
3. **[`MyBhoomi/Presentation/ViewModels/LandAreaCalculatorViewModel.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/ViewModels/LandAreaCalculatorViewModel.swift)**:
   - State manager coordinating official area display, conversion list generation, and subtle clipboard copying with haptic feedback.
4. **[`MyBhoomi/Presentation/Views/LandAreaCalculatorView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/LandAreaCalculatorView.swift)**:
   - Native Apple Liquid Glass SwiftUI modal sheet (`presentationDetents: [.medium, .large]`).
   - Clean information hierarchy: Official Source Extent Header Card $\rightarrow$ Quick Primary Conversions Card $\rightarrow$ Collapsible Regional Odisha Units Card.
5. **[`MyBhoomi/Tests/LandAreaCalculatorTests.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Tests/LandAreaCalculatorTests.swift)**:
   - Unit test suite covering standard constants, real-world known parcels, regional units, edge cases, and reverse consistency.

### Files Modified:
1. **[`MyBhoomi/Presentation/Views/CadastralPlotCardView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/CadastralPlotCardView.swift)**:
   - Enhanced `AttributePill` for `AREA` with a subtle conversion indicator (`"arrow.left.arrow.right"`).
   - Tapping the verified Area pill presents `LandAreaCalculatorView` as a native sheet.
2. **[`MyBhoomi/Presentation/Views/KhatianDetailView.swift`](file:///Users/uday/Documents/MyBhoomi/MyBhoomi/Presentation/Views/KhatianDetailView.swift)**:
   - In `extentTableSection`, added a small `"Convert"` capsule button alongside `TOTAL RECORDED EXTENT`.
   - Tapping presents `LandAreaCalculatorView` preloaded with the official RoR extent.

---

## 2. Exact UX Entry Points

1. **Cadastral Plot Bottom Card (`CadastralPlotCardView.swift`)**:
   - Location: Inside the 3-box key metric grid (`KHATIAN`, `AREA`, `LAND TYPE`).
   - Behavior: When the parcel is verified, a small `arrow.left.arrow.right` symbol appears next to `AREA`. Tapping opens the calculator sheet.
   - Preserves card visual cleanliness — zero intrusive or oversized buttons added.

2. **Full Official RoR / Khatian Detail Screen (`KhatianDetailView.swift`)**:
   - Location: Inside the `EXTENT` table view strip, directly beside `TOTAL RECORDED EXTENT: 0 Acre 3400 Decimal`.
   - Behavior: A small secondary capsule button `"Convert"` opens the calculator sheet.

---

## 3. Conversion Rules & Constants

All calculations derive from a single canonical base of **Square Meters ($m^2$)**:

| Unit | Symbol | Exact Ratio to $1\ \text{m}^2$ | Reference Standard |
|---|---|---|---|
| **Acre** | `ac` | $4,046.8564224\ \text{m}^2$ | Standard Revenue ($43,560\ \text{sq ft}$) |
| **Decimal** | `dec` | $40.468564224\ \text{m}^2$ | $1/100\ \text{Acre} = 435.6\ \text{sq ft}$ |
| **Square Feet** | `sq ft` | $0.09290304\ \text{m}^2$ | Standard Imperial |
| **Square Meters** | `sq m` | $1.0\ \text{m}^2$ | Canonical Base |
| **Square Yard (Gaj)**| `sq yd / gaj` | $0.83612736\ \text{m}^2$ | $9\ \text{sq ft}$ |
| **Hectare** | `ha` | $10,000.0\ \text{m}^2$ | Metric ($2.47105\ \text{Acres}$) |
| **Guntha (Odisha)** | `guntha` | $161.874256896\ \text{m}^2$ | $4\ \text{Decimals} = 1,742.4\ \text{sq ft}$ ($25\ \text{Guntha} = 1\ \text{Acre}$) |
| **Mana (Odisha)** | `mana` | $4,046.8564224\ \text{m}^2$ | $1\ \text{Acre} = 25\ \text{Guntha} = 100\ \text{Decimals}$ |
| **Bigha (Standard Odisha)** | `bigha` | $1,348.9521408\ \text{m}^2$ | $1/3\ \text{Acre} = 33.333\ \text{Decimals} = 14,520\ \text{sq ft}$ |
| **Katha / Biswa (Odisha)** | `katha` | $67.44760704\ \text{m}^2$ | $1/20\ \text{Bigha} = 1.666\ \text{Decimals} = 726\ \text{sq ft}$ |
| **Cent** | `cent` | $40.468564224\ \text{m}^2$ | $1\ \text{Decimal} = 435.6\ \text{sq ft}$ |

---

## 4. Test Validation & Real-World Parcel Verification

### Test Suite Execution:
- **`LandAreaCalculatorTests.swift`**: **11 / 11 tests passed (100%)**

### Real-World Parcel Tests:
1. **G_Baliabeda Plot 45 (`"0 Acre 3400 Decimal"`)**:
   - `34.0 Decimal`
   - `14,810.4 Sq Ft`
   - `1,375.93 Sq M`
   - `1,645.6 Gaj`
   - `0.34 Acre`
2. **Chandakuda Plot 241 (`"1 Acre 4200 Decimal"`)**:
   - `142.0 Decimal`
   - `61,855.2 Sq Ft`
   - `5,746.54 Sq M`
   - `6,872.8 Gaj`
   - `1.42 Acre`
3. **Buxibazar Plot 1110 (`"0 Acre 0270 Decimal"`)**:
   - `2.70 Decimal`
   - `1,176.12 Sq Ft`
   - `109.27 Sq M`
   - `0.027 Acre`
4. **Barimelak Plot 378 (`"0 Acre 1700 Decimal"`)**:
   - `17.0 Decimal`
   - `7,405.2 Sq Ft`
   - `687.96 Sq M`
   - `0.17 Acre`

---

## 5. Performance & Verification Safety

- **Zero Network Requests**: Opening the Land Area Calculator triggers **0** HTTP calls, **0** Bhulekh scrapers, **0** PDF downloads, and **0** backend requests.
- **Verification Invariance**: If an area string is missing (`nil`, `""`, `"—"`, `"-"`, or unparseable), the calculator displays `"Area Unavailable"` and will never guess or fabricate numbers.
- **Official RoR Invariance**: The raw official string (e.g. `"0 Acre 3400 Decimal"`) is preserved verbatim at the top of the view as the authoritative source of truth.

---

## 6. Build & Physical Deployment

- **Xcode Build Status**: `** BUILD SUCCEEDED **`
- **Physical Device**: Successfully installed and launched on `aabbc’s iPhone` (bundle ID: `com.kirtidhwaj.Bhumitra`).
