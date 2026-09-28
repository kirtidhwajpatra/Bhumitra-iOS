//
//  BenchmarkValuationDetailSheet.swift
//  MyBhoomi
//
//  Native Apple-style detail modal presenting official Odisha IGR benchmark valuation,
//  multi-unit rate comparisons, transaction data, and provenance metadata.
//

import SwiftUI

public struct BenchmarkValuationDetailSheet: View {
    public let valuation: BenchmarkValuation
    public let actualAreaText: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    public init(valuation: BenchmarkValuation, actualAreaText: String? = nil) {
        self.valuation = valuation
        self.actualAreaText = actualAreaText
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.bhumitraBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 1. Header Rate Banner
                        headerRateBanner

                        // 2. Indicative Amount Card (if calculation available)
                        if valuation.calculation.calculationAvailable, let amountStr = valuation.calculation.formattedAmount {
                            indicativeAmountCard(amountStr: amountStr)
                        }

                        // 3. Property Context Card
                        propertyContextCard

                        // 4. Multi-Unit Government Benchmark Rates Table
                        if let rates = valuation.unitRates {
                            ratesMatrixCard(rates: rates)
                        }

                        // 5. Transaction & Fee Records Card (if present)
                        if hasTransactionOrFeeInfo {
                            transactionFeeCard
                        }

                        // 6. Source Attribution & Compliance
                        sourceAttributionCard

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Benchmark Details")
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
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerRateBanner: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
                Text("GOVERNMENT BENCHMARK RATE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(red: 0.11, green: 0.55, blue: 0.33).opacity(0.12))
            .clipShape(Capsule())

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(valuation.formattedRatePerDecimal)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                Text("per Decimal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
            }

            Text("Official statutory rate for Plot \(valuation.plotNumber)")
                .font(.system(size: 13))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Color.bhumitraSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                )
        )
    }

    private func indicativeAmountCard(amountStr: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("INDICATIVE BENCHMARK AMOUNT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
            }

            Text(amountStr)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.11, green: 0.55, blue: 0.33))

            if let formula = valuation.calculation.formula {
                Text(formula)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
            }

            Text("Computed using official government rate and verified parcel acreage.")
                .font(.system(size: 11))
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Color.bhumitraSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                )
        )
    }

    private var propertyContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROPERTY IDENTITY")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundColor(Theme.Color.bhumitraTertiaryText)

            VStack(spacing: 10) {
                detailRow(label: "District", value: valuation.district)
                Divider().background(Theme.Color.bhumitraBorder)
                detailRow(label: "Registration Office", value: valuation.registrationOffice ?? "—")
                Divider().background(Theme.Color.bhumitraBorder)
                detailRow(label: "Village - Thana", value: valuation.villageThana ?? "—")
                Divider().background(Theme.Color.bhumitraBorder)
                detailRow(label: "Kisam (Category)", value: valuation.kisam ?? "Residential")
                Divider().background(Theme.Color.bhumitraBorder)
                detailRow(label: "Plot Number", value: valuation.plotNumber)
                if let actualArea = actualAreaText, !actualArea.isEmpty {
                    Divider().background(Theme.Color.bhumitraBorder)
                    detailRow(label: "Actual Parcel Area", value: actualArea)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Color.bhumitraSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                )
        )
    }

    private func ratesMatrixCard(rates: BenchmarkUnitRates) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OFFICIAL UNIT RATES")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
                Spacer()
                Text("Odisha IGR")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimary)
            }

            VStack(spacing: 10) {
                detailRow(label: "Per Decimal (100D = 1 Acre)", value: rates.formattedPerDecimal, highlight: true)
                Divider().background(Theme.Color.bhumitraBorder)
                detailRow(label: "Per Decimal (1000D = 1 Acre)", value: rates.formattedPerDecimal1000)
                Divider().background(Theme.Color.bhumitraBorder)
                detailRow(label: "Per Acre", value: rates.formattedPerAcre)
                Divider().background(Theme.Color.bhumitraBorder)
                detailRow(label: "Per Hectare", value: rates.formattedPerHectare)
                Divider().background(Theme.Color.bhumitraBorder)
                detailRow(label: "Per Square Meter", value: rates.formattedPerSqMeter)
                Divider().background(Theme.Color.bhumitraBorder)
                detailRow(label: "Per Square Foot", value: rates.formattedPerSqFt)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Color.bhumitraSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                )
        )
    }

    private var hasTransactionOrFeeInfo: Bool {
        valuation.highestTransactionValue != nil || valuation.stampDutyEstimate != nil || valuation.registrationFeeEstimate != nil
    }

    private var transactionFeeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRANSACTION & STATUTORY FEES")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundColor(Theme.Color.bhumitraTertiaryText)

            VStack(spacing: 10) {
                if let highVal = valuation.formattedHighestTransactionValue {
                    detailRow(label: "Highest Recorded Transaction", value: highVal)
                    if let date = valuation.transactionDate {
                        Divider().background(Theme.Color.bhumitraBorder)
                        detailRow(label: "Transaction Date", value: date)
                    }
                }
                if let stamp = valuation.stampDutyEstimate, stamp > 0 {
                    Divider().background(Theme.Color.bhumitraBorder)
                    detailRow(label: "Estimated Stamp Duty (1 Dec)", value: BenchmarkValuationFormatter.formatCurrency(stamp))
                }
                if let fee = valuation.registrationFeeEstimate, fee > 0 {
                    Divider().background(Theme.Color.bhumitraBorder)
                    detailRow(label: "Estimated Registration Fee", value: BenchmarkValuationFormatter.formatCurrency(fee))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Color.bhumitraSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8)
                )
        )
    }

    private var sourceAttributionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DATA PROVENANCE")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                    Text(valuation.source)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                }
                Spacer()
                if let url = URL(string: valuation.sourceURL) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("Official Portal")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Theme.Color.bhumitraPrimary)
                    }
                }
            }

            Text("This valuation reflects the official benchmark value published by the Government of Odisha for stamp duty registration purposes. It is not an appraisal of open market commercial value.")
                .font(.system(size: 11))
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                .lineSpacing(2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Color.bhumitraSurfaceSecondary.opacity(0.6))
        )
    }

    private func detailRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5, weight: highlight ? .semibold : .regular))
                .foregroundColor(highlight ? Theme.Color.bhumitraPrimaryText : Theme.Color.bhumitraSecondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13.5, weight: highlight ? .bold : .medium))
                .foregroundColor(highlight ? Color(red: 0.11, green: 0.55, blue: 0.33) : Theme.Color.bhumitraPrimaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}
