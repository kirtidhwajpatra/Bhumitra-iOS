//
//  RegistrationCostQuickSheetView.swift
//  MyBhoomi
//
//  Interactive Odisha IGR Stamp Duty & Registration Cost Estimator Sheet.
//  Implements statutory Odisha rates, women buyer concessions, and instant calculations.
//

import SwiftUI

public struct RegistrationCostQuickSheetView: View {
    public let onDismiss: () -> Void
    public var onExploreOnMap: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var landValueInput: String = "1500000"
    @State private var areaInput: String = "10.0"
    @State private var selectedUnit: String = "Decimal"
    @State private var isFemaleBuyer: Bool = false
    @State private var selectedDeed: String = "Sale Deed"
    
    let units = ["Decimal", "Acre", "Sq. Ft", "Guntha"]
    let deedTypes = ["Sale Deed", "Gift Deed", "Partition", "Settlement"]
    
    public init(onDismiss: @escaping () -> Void, onExploreOnMap: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        self.onExploreOnMap = onExploreOnMap
    }
    
    private var considerationValue: Double {
        Double(landValueInput.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    
    // Odisha Stamp Duty: 5% standard, 4% for female buyer
    private var stampDutyRate: Double {
        isFemaleBuyer ? 0.04 : 0.05
    }
    
    // Odisha Registration Fee: 2% standard
    private var registrationFeeRate: Double {
        0.02
    }
    
    private var stampDutyAmount: Double {
        considerationValue * stampDutyRate
    }
    
    private var registrationFeeAmount: Double {
        considerationValue * registrationFeeRate
    }
    
    private var femaleConcessionAmount: Double {
        if isFemaleBuyer {
            return considerationValue * 0.01
        }
        return 0
    }
    
    private var totalGovtCharges: Double {
        stampDutyAmount + registrationFeeAmount
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
    
    public var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Banner with Official Icon
                    HStack(spacing: 14) {
                        BhumitraIcon.RegdCost(size: 48)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Registration & Stamp Duty")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            Text("Government of Odisha IGR Statutory Rates")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#7600FF").opacity(0.08))
                    )
                    
                    // Input Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("PROPERTY VALUATION DETAILS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        
                        // Consideration / Market Value
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Land Value / Consideration (₹)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            
                            HStack {
                                Text("₹")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Theme.Color.bhumitraPrimary)
                                TextField("e.g. 1500000", text: $landValueInput)
                                    .font(.system(size: 17, weight: .semibold))
                                    .keyboardType(.numberPad)
                            }
                            .padding(12)
                            .background(Theme.Color.bhumitraSurfaceSecondary)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Color.bhumitraBorder, lineWidth: 1))
                        }
                        
                        // Area & Unit
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Plot Area")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                                TextField("10.0", text: $areaInput)
                                    .font(.system(size: 16, weight: .medium))
                                    .keyboardType(.decimalPad)
                                    .padding(12)
                                    .background(Theme.Color.bhumitraSurfaceSecondary)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Color.bhumitraBorder, lineWidth: 1))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Unit")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                                Picker("Unit", selection: $selectedUnit) {
                                    ForEach(units, id: \.self) { u in
                                        Text(u).tag(u)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Theme.Color.bhumitraSurfaceSecondary)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Color.bhumitraBorder, lineWidth: 1))
                            }
                        }
                        
                        // Deed Type
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Deed Type")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            Picker("Deed", selection: $selectedDeed) {
                                ForEach(deedTypes, id: \.self) { d in
                                    Text(d).tag(d)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Female Buyer Concession Toggle
                        Toggle(isOn: $isFemaleBuyer) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Woman Buyer / Co-Owner")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                                    Text("SAVE 1%")
                                        .font(.system(size: 10, weight: .heavy))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                                Text("Odisha grants 1% concession on stamp duty (4% vs 5%)")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            }
                        }
                        .tint(Color(hex: "#7600FF"))
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .background(Theme.Color.surface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Color.bhumitraBorder, lineWidth: 1))
                    
                    // Calculation Breakdown Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ESTIMATED CHARGES BREAKDOWN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        
                        // Total Summary Pill
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total Estimated Cost")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Text(formatCurrency(totalGovtCharges))
                                    .font(.system(size: 26, weight: .heavy))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Effective Rate")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Text(String(format: "%.1f%%", (stampDutyRate + registrationFeeRate) * 100))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFE100"))
                            }
                        }
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#7600FF"), Color(hex: "#490099")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(14)
                        
                        // Line Items
                        VStack(spacing: 10) {
                            costRow(
                                title: "Stamp Duty (\(Int(stampDutyRate * 100))%)",
                                subtitle: isFemaleBuyer ? "Includes 1% woman concession" : "Standard Odisha statutory rate",
                                amount: formatCurrency(stampDutyAmount),
                                color: Theme.Color.bhumitraPrimaryText
                            )
                            
                            Divider()
                            
                            costRow(
                                title: "Registration Fee (2%)",
                                subtitle: "Sub-Registrar fee under Registration Act 1908",
                                amount: formatCurrency(registrationFeeAmount),
                                color: Theme.Color.bhumitraPrimaryText
                            )
                            
                            if isFemaleBuyer {
                                Divider()
                                costRow(
                                    title: "Woman Concession Savings",
                                    subtitle: "1% statutory rebate applied",
                                    amount: "- \(formatCurrency(femaleConcessionAmount))",
                                    color: .green
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        // Statutory Disclaimer
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            Text("Official registration charges in Odisha are calculated on whichever is higher: the declared transaction consideration or the IGR benchmark valuation for that plot & village.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .background(Theme.Color.surface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Color.bhumitraBorder, lineWidth: 1))
                    
                    // Explore On Map Button
                    if let onExplore = onExploreOnMap {
                        Button {
                            onDismiss()
                            onExplore()
                        } label: {
                            Label("Find Plot to Check Official Benchmark", systemImage: "map")
                        }
                        .buttonStyle(.primaryCTA)
                        .padding(.bottom, 20)
                    }
                }
                .padding(16)
            }
            .background(Theme.Color.background.ignoresSafeArea())
            .navigationBarTitle("Registration Cost", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                onDismiss()
            })
        }
    }
    
    private func costRow(title: String, subtitle: String, amount: String, color: Color) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
            }
            Spacer()
            Text(amount)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
        }
    }
}
