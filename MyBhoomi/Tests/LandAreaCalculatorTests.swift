import Foundation

/// Comprehensive test suite for LandAreaConverter & LandAreaUnitConverter:
/// Covers all 21 core requirements from specification:
/// 1. 1 Acre → 100 Decimal
/// 2. 1 Acre → 43,560 Square Feet
/// 3. 1 Acre → 4,046.856 Square Meter
/// 4. 1 Acre → 4,840 Square Yard (Gaj)
/// 5. 0 Acre 3400 Decimal → 34 Decimal
/// 6. 1 Acre 4200 Decimal → 142 Decimal / 1.42 Acre
/// 7. 0 Acre 0270 Decimal → 2.7 Decimal / 0.027 Acre
/// 8. Decimal → Acre
/// 9. Square Feet → Acre
/// 10. Square Meter → Acre
/// 11. Square Yard → Acre
/// 12. Swap behavior
/// 13. Typing updates result immediately
/// 14. Invalid input handling
/// 15. Empty input handling
/// 16. Zero input handling
/// 17. Large values precision
/// 18. Rounding & formatting
/// 19. Regional unit without conversion rule / strict safety
/// 20. Parcel prefill
/// 21. Manual editing after parcel prefill
@MainActor
public struct LandAreaCalculatorTests {
    
    // MARK: - Test Runner
    
    public static func runAllTests() -> (passed: Int, failed: Int, errors: [String]) {
        var passed = 0
        var failed = 0
        var errors: [String] = []
        
        func evaluate(_ name: String, _ block: () -> Bool) {
            let result = block()
            if result {
                passed += 1
                print("✅ [PASS] \(name)")
            } else {
                failed += 1
                let err = "❌ [FAIL] \(name)"
                errors.append(err)
                print(err)
            }
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  RUNNING BHUMITRA LAND AREA CONVERTER TEST SUITE")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 1. 1 Acre → 100 Decimal
        evaluate("test_1_acre_to_decimal") {
            let res = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .decimal, in: .odisha)
            guard let val = res else { return false }
            return abs(val - 100.0) < 0.0001
        }
        
        // 2. 1 Acre → 43,560 Square Feet
        evaluate("test_1_acre_to_square_feet") {
            let res = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .squareFeet, in: .odisha)
            guard let val = res else { return false }
            return abs(val - 43560.0) < 0.01
        }
        
        // 3. 1 Acre → 4,046.856 Square Meter
        evaluate("test_1_acre_to_square_meters") {
            let res = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .squareMeters, in: .odisha)
            guard let val = res else { return false }
            return abs(val - 4046.8564) < 0.01
        }
        
        // 4. 1 Acre → 4,840 Square Yard (Gaj)
        evaluate("test_1_acre_to_square_yards_gaj") {
            let res = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .squareYards, in: .odisha)
            guard let val = res else { return false }
            return abs(val - 4840.0) < 0.01
        }
        
        // 5. 0 Acre 3400 Decimal → 34 Decimal
        evaluate("test_parse_0_acre_3400_decimal") {
            guard let parsed = LandAreaUnitConverter.parseStructuredExtent(from: "0 Acre 3400 Decimal") else { return false }
            guard parsed.unit == .decimal && abs(parsed.value - 34.0) < 0.001 else { return false }
            guard let sqM = LandAreaUnitConverter.parseToSqMeters(from: "0 Acre 3400 Decimal") else { return false }
            let sqFt = LandAreaUnitConverter.fromSqMeters(sqM, to: .squareFeet) ?? 0
            return abs(sqFt - 14810.4) < 0.1
        }
        
        // 6. 1 Acre 4200 Decimal
        evaluate("test_parse_1_acre_4200_decimal") {
            guard let parsed = LandAreaUnitConverter.parseStructuredExtent(from: "1 Acre 4200 Decimal") else { return false }
            guard parsed.unit == .decimal && abs(parsed.value - 142.0) < 0.001 else { return false }
            guard let sqM = LandAreaUnitConverter.parseToSqMeters(from: "1 Acre 4200 Decimal") else { return false }
            let acres = LandAreaUnitConverter.fromSqMeters(sqM, to: .acres) ?? 0
            let sqFt = LandAreaUnitConverter.fromSqMeters(sqM, to: .squareFeet) ?? 0
            return abs(acres - 1.42) < 0.001 && abs(sqFt - 61855.2) < 0.1
        }
        
        // 7. 0 Acre 0270 Decimal
        evaluate("test_parse_0_acre_0270_decimal") {
            guard let parsed = LandAreaUnitConverter.parseStructuredExtent(from: "0 Acre 0270 Decimal") else { return false }
            guard parsed.unit == .decimal && abs(parsed.value - 2.7) < 0.001 else { return false }
            guard let sqM = LandAreaUnitConverter.parseToSqMeters(from: "0 Acre 0270 Decimal") else { return false }
            let acres = LandAreaUnitConverter.fromSqMeters(sqM, to: .acres) ?? 0
            return abs(acres - 0.027) < 0.0001
        }
        
        // 8. Decimal → Acre
        evaluate("test_decimal_to_acre") {
            let res = LandAreaUnitConverter.convert(value: 100.0, from: .decimal, to: .acres)
            guard let val = res else { return false }
            return abs(val - 1.0) < 0.0001
        }
        
        // 9. Square Feet → Acre
        evaluate("test_square_feet_to_acre") {
            let res = LandAreaUnitConverter.convert(value: 43560.0, from: .squareFeet, to: .acres)
            guard let val = res else { return false }
            return abs(val - 1.0) < 0.0001
        }
        
        // 10. Square Meter → Acre
        evaluate("test_square_meter_to_acre") {
            let res = LandAreaUnitConverter.convert(value: 4046.8564224, from: .squareMeters, to: .acres)
            guard let val = res else { return false }
            return abs(val - 1.0) < 0.0001
        }
        
        // 11. Square Yard → Acre
        evaluate("test_square_yard_to_acre") {
            let res = LandAreaUnitConverter.convert(value: 4840.0, from: .squareYards, to: .acres)
            guard let val = res else { return false }
            return abs(val - 1.0) < 0.0001
        }
        
        // 12. Swap behavior
        evaluate("test_viewmodel_swap_behavior") {
            let vm = LandAreaConverterViewModel()
            vm.inputValueString = "1"
            vm.sourceUnit = .acres
            vm.targetUnit = .decimal
            vm.recalculate()
            
            guard vm.convertedValueFormatted == "100" else { return false }
            
            vm.swapUnits()
            
            return vm.sourceUnit == .decimal &&
                   vm.targetUnit == .acres &&
                   vm.inputValueString == "100" &&
                   vm.convertedValueFormatted == "1"
        }
        
        // 13. Typing updates result immediately
        evaluate("test_viewmodel_typing_immediate_update") {
            let vm = LandAreaConverterViewModel()
            vm.sourceUnit = .acres
            vm.targetUnit = .decimal
            
            vm.inputValueString = "2"
            guard vm.convertedValueFormatted == "200" else { return false }
            
            vm.inputValueString = "0.5"
            guard vm.convertedValueFormatted == "50" else { return false }
            
            vm.inputValueString = "1.25"
            guard vm.convertedValueFormatted == "125" else { return false }
            
            return true
        }
        
        // 14. Invalid input handling
        evaluate("test_viewmodel_invalid_input") {
            let vm = LandAreaConverterViewModel()
            vm.inputValueString = "abc"
            return vm.convertedValueFormatted == "Invalid" && !vm.isConversionAvailable
        }
        
        // 15. Empty input handling
        evaluate("test_viewmodel_empty_input") {
            let vm = LandAreaConverterViewModel()
            vm.inputValueString = ""
            return vm.convertedValueFormatted == "—" && vm.isConversionAvailable
        }
        
        // 16. Zero input handling
        evaluate("test_viewmodel_zero_input") {
            let vm = LandAreaConverterViewModel()
            vm.inputValueString = "0"
            return vm.convertedValueFormatted == "0" && vm.convertedRawValue == 0.0
        }
        
        // 17. Large values precision
        evaluate("test_large_values_precision") {
            let vm = LandAreaConverterViewModel()
            vm.inputValueString = "1000"
            vm.sourceUnit = .acres
            vm.targetUnit = .squareFeet
            guard let raw = vm.convertedRawValue else { return false }
            return abs(raw - 43560000.0) < 0.1 && !vm.convertedValueFormatted.isEmpty
        }
        
        // 18. Rounding & display formatting
        evaluate("test_rounding_and_display_formatting") {
            let acreFormatted = LandAreaUnit.acres.format(value: 0.34)
            let sqFtFormatted = LandAreaUnit.squareFeet.format(value: 14810.4)
            let sqMFormatted = LandAreaUnit.squareMeters.format(value: 4046.86)
            return acreFormatted == "0.34" &&
                   sqFtFormatted == "14,810.4" &&
                   sqMFormatted == "4,046.86"
        }
        
        // 19. Regional unit without conversion rule (Strict safety: no fake conversions)
        evaluate("test_regional_unit_safety_and_unavailability") {
            let bighaInOdisha = LandAreaUnitConverter.convert(value: 1.0, from: .bighaOdisha, to: .squareFeet, in: .odisha)
            guard let odishaSqFt = bighaInOdisha, abs(odishaSqFt - 14520.0) < 0.1 else { return false }
            
            // In national standard region, bigha is unsupported because there is no universal conversion
            let bighaInNational = LandAreaUnitConverter.convert(value: 1.0, from: .bighaOdisha, to: .squareFeet, in: .nationalStandard)
            return bighaInNational == nil
        }
        
        // 20. Parcel prefill
        evaluate("test_parcel_prefill") {
            let vm = LandAreaConverterViewModel(
                officialArea: "0 Acre 3400 Decimal",
                parcelContext: "Plot 45 • G_Baliabeda"
            )
            return vm.parcelContext == "Plot 45 • G_Baliabeda" &&
                   vm.officialAreaString == "0 Acre 3400 Decimal" &&
                   vm.sourceUnit == .decimal &&
                   vm.inputValueString == "34" &&
                   vm.targetUnit == .squareFeet &&
                   vm.convertedValueFormatted == "14,810.4"
        }
        
        // 21. Manual editing after parcel prefill
        evaluate("test_manual_editing_after_parcel_prefill") {
            let vm = LandAreaConverterViewModel(
                officialArea: "0 Acre 3400 Decimal",
                parcelContext: "Plot 45 • G_Baliabeda"
            )
            // User deletes 34 and types 1
            vm.inputValueString = "1"
            vm.sourceUnit = .decimal
            vm.targetUnit = .acres
            
            return vm.convertedValueFormatted == "0.01" &&
                   vm.officialAreaString == "0 Acre 3400 Decimal" // Official context remains unmodified
        }
        
        // 22. Additional Odisha regional units (Guntha, Mana, Katha)
        evaluate("test_odisha_regional_units_exact_ratios") {
            let guntha = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .guntha, in: .odisha) ?? 0
            let mana = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .mana, in: .odisha) ?? 0
            let katha = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .kathaOdisha, in: .odisha) ?? 0
            let cent = LandAreaUnitConverter.convert(value: 1.0, from: .acres, to: .cent, in: .odisha) ?? 0
            
            return abs(guntha - 25.0) < 0.001 &&
                   abs(mana - 1.0) < 0.001 &&
                   abs(katha - 60.0) < 0.001 &&
                   abs(cent - 100.0) < 0.001
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  TEST RESULTS: \(passed) PASSED, \(failed) FAILED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        return (passed, failed, errors)
    }
}
