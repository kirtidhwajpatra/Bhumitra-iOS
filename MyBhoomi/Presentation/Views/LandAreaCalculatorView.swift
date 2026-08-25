import SwiftUI

// ============================================================
// MARK: - BHUMITRA LAND AREA CONVERTER (STANDALONE GOOGLE-STYLE UX)
// ============================================================

/// Clean, responsive, full-screen Land Area Converter designed with
/// Google-style interactive conversion cards, real-time conversion rates,
/// instant unit swapping, and complete Odisha regional unit parity styled in Google Sans.
public struct LandAreaConverterView: View {
    @StateObject public var viewModel: LandAreaConverterViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool
    
    public init(viewModel: LandAreaConverterViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public init() {
        self._viewModel = StateObject(wrappedValue: LandAreaConverterViewModel())
    }
    
    public init(officialArea: String?, parcelContext: String? = nil) {
        self._viewModel = StateObject(wrappedValue: LandAreaConverterViewModel(
            officialArea: officialArea,
            parcelContext: parcelContext
        ))
    }
    
    public init(parcelExtentString: String, parcelContext: String? = nil) {
        self._viewModel = StateObject(wrappedValue: LandAreaConverterViewModel(
            officialArea: parcelExtentString,
            parcelContext: parcelContext
        ))
    }
    
    // MARK: - Adaptive Theme Colors
    
    private var canvasBackground: Color {
        colorScheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.07) : Color(red: 0.95, green: 0.96, blue: 0.98)
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color(red: 0.08, green: 0.08, blue: 0.10)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.60) : Color.black.opacity(0.55)
    }
    
    private var pillBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.85)
    }
    
    private var pillBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Adaptive Atmospheric Canvas
            canvasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Navigation Header
                navigationHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {
                        // 2. Primary Converter Card
                        mainConverterCard
                        
                        // 3. Quick Multi-Unit Results Strip
                        quickConversionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
    
    // MARK: - 1. Top Navigation Bar
    
    private var navigationHeader: some View {
        HStack(alignment: .center) {
            // Liquid Glass Back Button
            Button {
                Theme.haptic(.light)
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.googleSans(size: 17, weight: .bold))
                    .foregroundColor(primaryTextColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .padding(3)
            .glassEffect(
                .regular.interactive(),
                in: .circle
            )
            .accessibilityLabel("Go back")
            
            Spacer()
            
            Text("Land Area Converter")
                .font(.googleSans(size: 18, weight: .bold))
                .foregroundColor(primaryTextColor)
            
            Spacer()
            
            Color.clear
                .frame(width: 50, height: 44)
        }
    }
    
    // MARK: - 2. Main Converter Card (Exact Reference Design with Liquid Glass)
    
    private var mainConverterCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card Header (Selected Plot with Green Checkmark OR Action Title)
            VStack(alignment: .leading, spacing: 4) {
                if let parcelCtx = viewModel.parcelContext {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.Color.success)
                        
                        Text(parcelCtx)
                            .font(.googleSans(size: 22, weight: .bold))
                            .foregroundColor(primaryTextColor)
                            .lineLimit(1)
                    }
                } else {
                    Text("Convert \(viewModel.sourceUnit.displayName)")
                        .font(.googleSans(size: 24, weight: .bold))
                        .foregroundColor(primaryTextColor)
                }
                
                // Real-time conversion rate subtitle (e.g. 1 Decimal = 435.6 Square Feet)
                Text(viewModel.unitRateString)
                    .font(.googleSans(size: 14, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)
            
            // Interactive Swap Container (FROM pill + Centered Swap button + TO pill)
            VStack(spacing: -14) {
                // --- FROM PILL BOX ---
                HStack(alignment: .center, spacing: 12) {
                    // Left: Unit Dropdown
                    unitSelectorButton(
                        unit: viewModel.sourceUnit,
                        title: "Source Unit",
                        onSelect: { unit in
                            viewModel.sourceUnit = unit
                        }
                    )
                    
                    Spacer(minLength: 8)
                    
                    // Right: Editable Numeric Input
                    TextField("0", text: $viewModel.inputValueString)
                        .font(.googleSans(size: 22, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                        .minimumScaleFactor(0.60)
                        .lineLimit(1)
                        .accessibilityLabel("Source amount to convert")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(pillBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(pillBorder, lineWidth: 1.2)
                )
                .zIndex(1)
                
                // --- CENTER INTERSECTING SWAP BUTTON ---
                Button {
                    viewModel.swapUnits()
                } label: {
                    Image(systemName: "arrow.down")
                        .font(.googleSans(size: 14, weight: .bold))
                        .foregroundColor(Color.accentColor)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .padding(3)
                .glassEffect(
                    .regular.interactive(),
                    in: .circle
                )
                .accessibilityLabel("Swap source and target units")
                .zIndex(3)
                
                // --- TO PILL BOX ---
                HStack(alignment: .center, spacing: 12) {
                    // Left: Target Unit Dropdown
                    unitSelectorButton(
                        unit: viewModel.targetUnit,
                        title: "Target Unit",
                        onSelect: { unit in
                            viewModel.targetUnit = unit
                        }
                    )
                    
                    Spacer(minLength: 8)
                    
                    // Right: Converted Value Text
                    Text(viewModel.convertedValueFormatted)
                        .font(.googleSans(size: 22, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.60)
                        .lineLimit(1)
                        .accessibilityLabel("Converted result: \(viewModel.convertedValueFormatted) \(viewModel.targetUnit.displayName)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(pillBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(pillBorder, lineWidth: 1.2)
                )
                .zIndex(1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
        .padding(2)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }
    
    // MARK: - Unit Selector Button with Icon Badge & Native Menu
    
    private func unitSelectorButton(
        unit: LandAreaUnit,
        title: String,
        onSelect: @escaping (LandAreaUnit) -> Void
    ) -> some View {
        Menu {
            Section("Primary Units") {
                ForEach(LandAreaUnit.allCases.filter { $0.category == .primary }) { u in
                    Button {
                        Theme.haptic(.light)
                        onSelect(u)
                    } label: {
                        HStack {
                            Text(u.displayName)
                            if unit == u {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Section("Regional Units (Odisha)") {
                ForEach(LandAreaUnit.allCases.filter { $0.category == .regional }) { u in
                    Button {
                        Theme.haptic(.light)
                        onSelect(u)
                    } label: {
                        HStack {
                            Text(u.displayName)
                            if unit == u {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Section("Metric") {
                ForEach(LandAreaUnit.allCases.filter { $0.category == .metric }) { u in
                    Button {
                        Theme.haptic(.light)
                        onSelect(u)
                    } label: {
                        HStack {
                            Text(u.displayName)
                            if unit == u {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Unit Icon Circle Badge
                ZStack {
                    Circle()
                        .fill(unit.iconColor.opacity(0.16))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: unit.iconName)
                        .font(.googleSans(size: 13, weight: .bold))
                        .foregroundColor(unit.iconColor)
                }
                
                // Unit Name
                Text(unit.displayName)
                    .font(.googleSans(size: 17, weight: .bold))
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)
                
                // Dropdown Chevron
                Image(systemName: "chevron.down")
                    .font(.googleSans(size: 11, weight: .bold))
                    .foregroundColor(secondaryTextColor)
            }
        }
        .accessibilityLabel("\(title), currently \(unit.displayName)")
    }
    
    // MARK: - 3. Quick Conversions Section
    
    private var allConversionsList: [LandAreaConversionItem] {
        viewModel.quickConversions + viewModel.regionalConversions
    }
    
    private var quickConversionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK CONVERSIONS")
                .font(.googleSans(size: 12, weight: .bold))
                .foregroundColor(secondaryTextColor)
                .tracking(1.0)
                .padding(.leading, 6)
            
            VStack(spacing: 8) {
                ForEach(allConversionsList) { item in
                    HStack(alignment: .center) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(item.unit.iconColor.opacity(0.14))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: item.unit.iconName)
                                        .font(.googleSans(size: 13, weight: .bold))
                                        .foregroundColor(item.unit.iconColor)
                                )
                            
                            Text(item.unit.displayName)
                                .font(.googleSans(size: 16.5, weight: .semibold))
                                .foregroundColor(primaryTextColor)
                        }
                        
                        Spacer()
                        
                        Text(item.formattedValue)
                            .font(.googleSans(size: 17.5, weight: .bold))
                            .foregroundColor(primaryTextColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassEffect(
                        .regular.interactive(),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
            }
        }
    }
}

/// Backwards compatibility alias for existing references.
public typealias LandAreaCalculatorView = LandAreaConverterView
