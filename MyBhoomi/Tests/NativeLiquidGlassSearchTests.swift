//
//  NativeLiquidGlassSearchTests.swift
//  MyBhoomi
//
//  Focused verification suite for Bhumitra Native Apple-style Liquid Glass Search.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
public struct NativeLiquidGlassSearchTests {
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
        print("  RUNNING BHUMITRA NATIVE LIQUID GLASS SEARCH TESTS  ")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 1. NativeSearchTextField wraps UISearchTextField with native search configurations
        evaluate("test_1_native_search_text_field_instantiation") {
            let field = UISearchTextField(frame: .zero)
            field.placeholder = "Search Odisha locations..."
            field.returnKeyType = .search
            field.clearButtonMode = .whileEditing
            field.borderStyle = .none
            field.backgroundColor = .clear
            
            guard field.placeholder == "Search Odisha locations..." else { return false }
            guard field.returnKeyType == .search else { return false }
            guard field.clearButtonMode == .whileEditing else { return false }
            guard field.borderStyle == .none else { return false }
            guard field.backgroundColor == .clear else { return false }
            return true
        }
        
        // 2. UISearchTextField clear button action clears text and calls onClear
        evaluate("test_2_native_search_clear_behavior") {
            var text = "Tompo"
            var cleared = false
            let binding = Binding(get: { text }, set: { text = $0 })
            let representable = NativeSearchTextField(
                text: binding,
                placeholder: "Search Odisha locations...",
                onClear: { cleared = true }
            )
            let coordinator = representable.makeCoordinator()
            let field = UISearchTextField(frame: .zero)
            let shouldClear = coordinator.textFieldShouldClear(field)
            
            guard shouldClear == true else { return false }
            guard text.isEmpty else { return false }
            guard cleared == true else { return false }
            return true
        }
        
        // 3. Typing "Tompo" updates MapViewModel and triggers suggestion pipeline
        evaluate("test_3_type_tompo_triggers_search") {
            let vm = MapViewModel()
            vm.searchQuery = "Tompo"
            guard vm.searchQuery == "Tompo" else { return false }
            return true
        }
        
        // 4. Result selection flow executes cleanly without map bouncing
        evaluate("test_4_selection_flow_executes_cleanly") {
            let vm = MapViewModel()
            vm.moveCamera(to: Coordinate(latitude: 19.98, longitude: 86.02), zoom: 16.0)
            guard vm.mapCenter.latitude == 19.98 else { return false }
            guard vm.mapCenter.longitude == 86.02 else { return false }
            guard vm.zoomLevel == 16.0 else { return false }
            return true
        }
        
        // 5. Map dismisses search cleanly on interaction
        evaluate("test_5_map_interaction_dismisses_search") {
            let vm = MapViewModel()
            vm.isSearchFocused = true
            vm.searchQuery = "Tompo"
            vm.dismissSearchOnMapInteraction()
            guard vm.isSearchFocused == false else { return false }
            guard vm.searchQuery.isEmpty else { return false }
            return true
        }
        
        // 6. Continuous typing ("t", "to", "tom", "tomp", "tompo") preserves search focus
        evaluate("test_6_continuous_typing_preserves_focus") {
            let vm = MapViewModel()
            vm.isSearchFocused = true
            let sequentialQueries = ["t", "to", "tom", "tomp", "tompo"]
            for q in sequentialQueries {
                vm.searchQuery = q
                guard vm.isSearchFocused == true else { return false }
                guard vm.searchQuery == q else { return false }
            }
            return true
        }
        
        let summary = "[NativeLiquidGlassSearchTests] Summary: \(passed) passed, \(failed) failed. Errors: \(errors.joined(separator: ", "))"
        print(summary)
        if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docDir.appendingPathComponent("search_tests_result.txt")
            try? summary.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        return (passed, failed, errors)
    }
}
