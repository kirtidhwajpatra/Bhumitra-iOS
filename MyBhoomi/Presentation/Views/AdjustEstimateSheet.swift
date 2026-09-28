//
//  AdjustEstimateSheet.swift
//  MyBhoomi
//
//  Native Apple-style bottom modal allowing users to customize area, unit, deed type,
//  and buyer category to recompute statutory registration charges directly from Odisha IGR.
//

import SwiftUI

public struct AdjustEstimateSheet: View {
    public let initialArea: Decimal
    public let initialUnit: String
    public let initialDeedId: Int
    public let initialBuyerCategory: BuyerCategoryOption
    public let onCalculate: (Decimal, String, IGRDeedOption, BuyerCategoryOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var areaText: String = ""
    @State private var selectedUnit: String = "Decimal"
    @State private var selectedDeed: IGRDeedOption
    @State private var selectedBuyerCategory: BuyerCategoryOption = .standard
    @State private var validationError: String? = nil

    private let supportedUnits = ["Decimal", "Acre", "Sq Feet"]

    public init(
        initialArea: Decimal,
        initialUnit: String = "Decimal",
        initialDeedId: Int = 1,
        initialBuyerCategory: BuyerCategoryOption = .standard,
        onCalculate: @escaping (Decimal, String, IGRDeedOption, BuyerCategoryOption) -> Void
    ) {
        self.initialArea = initialArea
        self.initialUnit = initialUnit
        self.initialDeedId = initialDeedId
        self.initialBuyerCategory = initialBuyerCategory
        self.onCalculate = onCalculate

        let matchingDeed = IGRDeedOption.standardDeeds.first(where: { $0.id == initialDeedId }) ?? IGRDeedOption.standardDeeds[0]
        _selectedDeed = State(initialValue: matchingDeed)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.bhumitraBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Banner
                        headerBanner

                        // Section 1: Area & Unit
                        areaSection

                        // Section 2: Deed Type
                        deedSection

                        // Section 3: Buyer Category
                        buyerSection

                        // Error message if any
                        if let err = validationError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Calculate Action Button
                        Button {
                            applyCalculation()
                        } label: {
                            Label("Recalculate Charges", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.primaryCTA)
                        .padding(.top, 8)
                        .accessibilityLabel("Recalculate Government Charges")

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Adjust Registration Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.Color.bhumitraTertiaryText)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onAppear {
                let doubleVal = NSDecimalNumber(decimal: initialArea).doubleValue
                if doubleVal.truncatingRemainder(dividingBy: 1) == 0 {
                    areaText = "\(Int(doubleVal))"
                } else {
                    areaText = String(format: "%.2f", doubleVal).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
                }
                selectedUnit = initialUnit
                selectedBuyerCategory = initialBuyerCategory
            }
        }
    }

    // MARK: - Subviews

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimary)
                Text("CUSTOM TRANSACTION ESTIMATE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(Theme.Color.bhumitraPrimary)
            }

            Text("Calculate official registration fee and stamp duty based on custom acreage, deed category, or buyer profile.")
                .font(.system(size: 13))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Color.bhumitraSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                )
        )
    }

    private var areaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LAND AREA & UNIT")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundColor(Theme.Color.bhumitraTertiaryText)

            HStack(spacing: 12) {
                // Area Textfield
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Area", text: $areaText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(Theme.Color.bhumitraBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                        )
                }
                .frame(maxWidth: .infinity)

                // Unit Picker
                Picker("Unit", selection: $selectedUnit) {
                    ForEach(supportedUnits, id: \.self) { u in
                        Text(u).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            Text("Note: 100 Decimal = 1 Acre = 43,560 sq. ft")
                .font(.system(size: 11.5))
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.Color.bhumitraSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                )
        )
    }

    private var deedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEED TYPE")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundColor(Theme.Color.bhumitraTertiaryText)

            VStack(spacing: 8) {
                ForEach(IGRDeedOption.standardDeeds) { deed in
                    Button {
                        selectedDeed = deed
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedDeed.id == deed.id ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(selectedDeed.id == deed.id ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraTertiaryText)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(deed.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraPrimaryText)

                                if let desc = deed.description {
                                    Text(desc)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                }
                            }

                            Spacer()

                            if deed.womenConcessionEligible {
                                Text("Concession eligible")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 0.11, green: 0.55, blue: 0.33).opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            selectedDeed.id == deed.id
                                ? Theme.Color.bhumitraPrimary.opacity(0.06)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.Color.bhumitraSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                )
        )
    }

    private var buyerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BUYER CATEGORY")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundColor(Theme.Color.bhumitraTertiaryText)

            Picker("Buyer Category", selection: $selectedBuyerCategory) {
                ForEach(BuyerCategoryOption.allCases) { cat in
                    Text(cat.displayName).tag(cat)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedBuyerCategory.subtitle)
                .font(.system(size: 12))
                .foregroundColor(selectedBuyerCategory == .womanBuyer ? Color(red: 0.11, green: 0.55, blue: 0.33) : Theme.Color.bhumitraSecondaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.Color.bhumitraSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                )
        )
    }

    private func applyCalculation() {
        validationError = nil
        let cleanText = areaText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let doubleArea = Double(cleanText), doubleArea > 0 else {
            validationError = "Please enter a valid positive land area."
            return
        }

        let areaDecimal = Decimal(doubleArea)
        onCalculate(areaDecimal, selectedUnit, selectedDeed, selectedBuyerCategory)
        dismiss()
    }
}
