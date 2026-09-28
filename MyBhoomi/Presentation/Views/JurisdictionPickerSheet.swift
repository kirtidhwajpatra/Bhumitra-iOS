//
//  JurisdictionPickerSheet.swift
//  MyBhoomi
//
//  Bottom sheet for user-assisted IGR jurisdiction selection.
//
//  Design: quiet, trustworthy list. One reason per row is enough — the user
//  just needs to pick the right Sub-Registrar office. Recommended match is
//  marked with a plain caption; no chips, no badges, no extra CTA labels.
//

import SwiftUI

public struct JurisdictionPickerSheet: View {
    public let candidates: [IGRValuationCandidate]
    public let plotNumber: String
    public let onSelect: (IGRValuationCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    public init(
        candidates: [IGRValuationCandidate],
        plotNumber: String,
        onSelect: @escaping (IGRValuationCandidate) -> Void
    ) {
        self.candidates = candidates
        self.plotNumber = plotNumber
        self.onSelect = onSelect
    }

    private var filteredCandidates: [IGRValuationCandidate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return candidates
        }
        return candidates.filter { cand in
            cand.villageName.lowercased().contains(query) ||
            cand.registrationOfficeName.lowercased().contains(query) ||
            (cand.thanaNumber?.contains(query) ?? false)
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if filteredCandidates.isEmpty {
                    VStack(spacing: 8) {
                        Text("No matching jurisdictions")
                            .font(.googleSans(size: 15, weight: .medium))
                            .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        Text("Try searching by village or office name.")
                            .font(.googleSans(size: 13, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(Array(filteredCandidates.enumerated()), id: \.element.id) { index, candidate in
                                Button {
                                    onSelect(candidate)
                                    dismiss()
                                } label: {
                                    candidateRow(for: candidate)
                                }
                                .buttonStyle(.plain)

                                if index < filteredCandidates.count - 1 {
                                    Divider()
                                }
                            }
                        } footer: {
                            Text("Benchmark land values depend on the Sub-Registrar office that keeps records for Plot \(plotNumber).")
                                .font(.googleSans(size: 12.5, weight: .regular))
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search village or office")
                }
            }
            .background(Theme.Color.bhumitraBackground)
            .navigationTitle("Select Jurisdiction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(nil)
    }

    @ViewBuilder
    private func candidateRow(for candidate: IGRValuationCandidate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(candidate.villageName)
                    .font(.appText(candidate.villageName, size: 15, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)

                Spacer()

                if candidate.confidence.lowercased() == "high" {
                    Text("Recommended")
                        .font(.googleSans(size: 12, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSuccess)
                }
            }

            HStack(spacing: 0) {
                Text(candidate.registrationOfficeName)
                    .font(.appText(candidate.registrationOfficeName, size: 13, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineLimit(1)

                if let thana = candidate.thanaNumber, !thana.isEmpty {
                    Text(" · Thana \(thana)")
                        .font(.googleSans(size: 13, weight: .regular))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
