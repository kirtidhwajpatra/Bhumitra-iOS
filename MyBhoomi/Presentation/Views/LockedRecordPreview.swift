//  LockedRecordPreview.swift
//  MyBhoomi
//
//  What a user with no plot searches sees below the plot overview: the SHAPE
//  of the official record (which sections exist, how many owners) with every
//  value redacted, plus one clear way to unlock. No real record values are
//  rendered here — the placeholder bars are fixed shapes, not masked data —
//  so nothing sensitive can leak through the teaser.

import SwiftUI

struct LockedRecordPreview: View {
    let plotNumber: String
    let ownerCount: Int?
    let hasCredits: Bool
    let creditsLeft: Int
    let startingPrice: String?
    let isUnlocking: Bool
    let onUnlock: () -> Void
    let onSeePlans: () -> Void

    private struct Section: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        let bars: [CGFloat]
    }

    private var sections: [Section] {
        [
            Section(icon: "person.2", title: ownersTitle, detail: "Names, relation and share", bars: [150, 118, 132]),
            Section(icon: "number", title: "Khata number", detail: "As recorded by the Tahasil", bars: [64]),
            Section(icon: "square.dashed", title: "Recorded area", detail: "Acre, decimal, sq ft, guntha", bars: [96, 72]),
            Section(icon: "leaf", title: "Land type & use", detail: "Kisam and classification", bars: [110]),
            Section(icon: "clock.arrow.circlepath", title: "Sales history (EC)", detail: "Registered transactions, where available", bars: [140, 100]),
            Section(icon: "indianrupeesign", title: "Government value", detail: "Benchmark rate & stamp duty", bars: [84]),
            Section(icon: "doc.text", title: "Official RoR PDF", detail: "Downloadable copy", bars: [120])
        ]
    }

    private var ownersTitle: String {
        guard let ownerCount, ownerCount > 0 else { return "Owners" }
        return ownerCount == 1 ? "1 owner on record" : "\(ownerCount) owners on record"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("The full record for Plot \(plotNumber) is ready")
                    .font(.stackSansHeadline(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                Text("From the official Odisha land record. Unlock to see every detail below.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
            }
            .padding(.horizontal, SheetChrome.inset)
            .padding(.top, 20)
            .padding(.bottom, 8)

            ForEach(sections) { section in
                row(section)
                SheetHairline().padding(.leading, SheetChrome.inset + 32)
            }

            unlockFooter
                .padding(.horizontal, SheetChrome.inset)
                .padding(.top, 20)
                .padding(.bottom, 32)
        }
    }

    private func row(_ s: Section) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: s.icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(s.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    Spacer(minLength: 8)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                }
                Text(s.detail)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                // Fixed placeholder shapes (not derived from the record).
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(s.bars.enumerated()), id: \.offset) { _, width in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(SheetChrome.controlFill)
                            .frame(width: width, height: 12)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, SheetChrome.inset)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(s.title), locked")
    }

    @ViewBuilder
    private var unlockFooter: some View {
        VStack(spacing: 10) {
            if hasCredits {
                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        if isUnlocking { ProgressView() } else { Image(systemName: "lock.open") }
                        Text(isUnlocking ? "Unlocking…" : "Unlock this plot")
                    }
                }
                .buttonStyle(.primaryCTA)
                .allowsHitTesting(!isUnlocking)
                Text("Uses 1 of your \(creditsLeft) \(creditsLeft == 1 ? "search" : "searches").")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
            } else {
                Button(action: onSeePlans) {
                    Text(startingPrice.map { "See plans · from \($0)" } ?? "See plans")
                }
                .buttonStyle(.primaryCTA)
                Text("One search unlocks this plot's complete record. Searches never expire.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
