import Foundation
import SwiftUI
import Combine

/// State holder and coordinator for the standalone Land Area Converter experience.
/// Pure local reactive architecture: instant updates on keystrokes, zero network calls.
@MainActor
public final class LandAreaConverterViewModel: ObservableObject {
    
    // MARK: - Input State
    @Published public var inputValueString: String = "1" {
        didSet { recalculate() }
    }
    @Published public var sourceUnit: LandAreaUnit = .acres {
        didSet { recalculate() }
    }
    @Published public var targetUnit: LandAreaUnit = .decimal {
        didSet { recalculate() }
    }
    @Published public var selectedRegion: LandAreaRegion = .odisha {
        didSet { recalculate() }
    }
    
    // MARK: - Parcel Context (Optional Preload)
    @Published public var parcelContext: String? = nil
    @Published public var officialAreaString: String? = nil
    
    // MARK: - Computed / Output State
    @Published public var convertedValueFormatted: String = ""
    @Published public var convertedRawValue: Double? = nil
    @Published public var isConversionAvailable: Bool = true
    @Published public var canonicalSqMeters: Double? = nil
    
    // Quick Conversions
    @Published public var quickConversions: [LandAreaConversionItem] = []
    @Published public var regionalConversions: [LandAreaConversionItem] = []
    @Published public var showRegionalUnits: Bool = false
    
    // Copy Feedback
    @Published public var copiedUnitId: String? = nil
    @Published public var isCopiedResult: Bool = false
    
    // MARK: - Unit Rate
    public var unitRateString: String {
        if let rate = LandAreaUnitConverter.convert(value: 1.0, from: sourceUnit, to: targetUnit, in: selectedRegion) {
            return "1 \(sourceUnit.displayName) = \(targetUnit.format(value: rate)) \(targetUnit.displayName)"
        }
        return "1 \(sourceUnit.displayName)"
    }
    
    // MARK: - Initialization
    
    public init(
        officialArea: String? = nil,
        parcelContext: String? = nil,
        defaultRegion: LandAreaRegion = .odisha
    ) {
        self.selectedRegion = defaultRegion
        self.parcelContext = parcelContext
        
        let cleanOfficial = officialArea?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let clean = cleanOfficial, !clean.isEmpty, clean != "—", clean != "-" {
            self.officialAreaString = clean
            
            // Preload structured parcel area if possible
            if let structured = LandAreaUnitConverter.parseStructuredExtent(from: clean) {
                self.sourceUnit = structured.unit
                self.inputValueString = structured.unit.format(value: structured.value)
                
                // Smart target unit selection based on preloaded source
                switch structured.unit {
                case .decimal:
                    self.targetUnit = .squareFeet
                case .acres:
                    self.targetUnit = .decimal
                case .squareFeet:
                    self.targetUnit = .decimal
                default:
                    self.targetUnit = .acres
                }
            } else if let sqM = LandAreaUnitConverter.parseToSqMeters(from: clean, in: defaultRegion) {
                let decVal = LandAreaUnitConverter.fromSqMeters(sqM, to: .decimal, in: defaultRegion) ?? 0
                self.sourceUnit = .decimal
                self.inputValueString = LandAreaUnit.decimal.format(value: decVal)
                self.targetUnit = .squareFeet
            }
        } else {
            self.officialAreaString = nil
            self.inputValueString = "1"
            self.sourceUnit = .acres
            self.targetUnit = .decimal
        }
        
        recalculate()
    }
    
    // MARK: - Reactive Calculation (Zero Network Calls)
    
    public func recalculate() {
        let cleanedInput = inputValueString
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedInput.isEmpty else {
            self.convertedValueFormatted = "—"
            self.convertedRawValue = nil
            self.canonicalSqMeters = nil
            self.isConversionAvailable = true
            self.quickConversions = []
            self.regionalConversions = []
            return
        }
        
        guard let num = Double(cleanedInput), num >= 0 else {
            self.convertedValueFormatted = "Invalid"
            self.convertedRawValue = nil
            self.canonicalSqMeters = nil
            self.isConversionAvailable = false
            self.quickConversions = []
            self.regionalConversions = []
            return
        }
        
        // Canonical square meters
        if let sqM = LandAreaUnitConverter.toSqMeters(value: num, from: sourceUnit, in: selectedRegion) {
            self.canonicalSqMeters = sqM
            
            // Target unit conversion
            if let converted = LandAreaUnitConverter.fromSqMeters(sqM, to: targetUnit, in: selectedRegion) {
                self.convertedRawValue = converted
                self.convertedValueFormatted = targetUnit.format(value: converted)
                self.isConversionAvailable = true
            } else {
                self.convertedRawValue = nil
                self.convertedValueFormatted = "Unavailable in \(selectedRegion.shortName)"
                self.isConversionAvailable = false
            }
            
            // Quick conversions list
            self.quickConversions = LandAreaUnitConverter.primaryConversions(for: sqM, region: selectedRegion)
            self.regionalConversions = LandAreaUnitConverter.regionalConversions(for: sqM, region: selectedRegion)
        } else {
            self.canonicalSqMeters = nil
            self.convertedRawValue = nil
            self.convertedValueFormatted = "Unavailable in \(selectedRegion.shortName)"
            self.isConversionAvailable = false
            self.quickConversions = []
            self.regionalConversions = []
        }
    }
    
    // MARK: - User Actions
    
    /// Swaps the source and target units, transferring the converted result into the input field.
    public func swapUnits() {
        let oldSource = sourceUnit
        let oldTarget = targetUnit
        
        // If we have a valid converted value, place it into the input field
        if let converted = convertedRawValue {
            sourceUnit = oldTarget
            targetUnit = oldSource
            inputValueString = oldTarget.format(value: converted)
        } else {
            sourceUnit = oldTarget
            targetUnit = oldSource
        }
    }
    
    /// Copies the main converted result to clipboard.
    public func copyResult() {
        guard isConversionAvailable, !convertedValueFormatted.isEmpty, convertedValueFormatted != "—" else { return }
        
        let textToCopy = "\(convertedValueFormatted) \(targetUnit.displayName)"
        UIPasteboard.general.string = textToCopy
        
        withAnimation(Theme.Animation.micro) {
            self.isCopiedResult = true
        }
        
        _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                withAnimation(Theme.Animation.micro) {
                    self.isCopiedResult = false
                }
            }
        }
    }
    
    /// Copies a specific quick conversion item to clipboard.
    public func copyConversion(_ item: LandAreaConversionItem) {
        let textToCopy = "\(item.formattedValue) \(item.unit.displayName)"
        UIPasteboard.general.string = textToCopy
        
        withAnimation(Theme.Animation.micro) {
            self.copiedUnitId = item.id
        }
        
        _Concurrency.Task {
            try? await _Concurrency.Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                if self.copiedUnitId == item.id {
                    withAnimation(Theme.Animation.micro) {
                        self.copiedUnitId = nil
                    }
                }
            }
        }
    }
}

/// Backwards compatibility alias for existing references.
public typealias LandAreaCalculatorViewModel = LandAreaConverterViewModel
