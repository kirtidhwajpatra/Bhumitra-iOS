//
//  SearchAssistViews.swift
//  MyBhoomi
//
//  Shared UX components for Location Search:
//  1. SearchEmptyStateCard: Actionable feedback when a query returns no results.
//  2. RecentSearchesDropdown: Quick access to recent searches with clean re-selection.
//

import SwiftUI

// MARK: - Suggestion Row (shared by map dropdown, native sheet and home)

/// One search suggestion. Villages read as
///   **Tampo** · ତମ୍ପୋ
///   Ghasipura Tahasil · Keonjhar
/// so same-named villages are easy to tell apart. Other types (landmarks,
/// localities, districts) fall back to title + subtitle.
struct LocationSuggestionRow: View {
    let result: LocationSearchResult
    var isRecent: Bool = false

    private var isVillage: Bool {
        result.type == .revenueVillage || result.type == .compoundPlot
    }

    private var primaryText: String {
        guard isVillage else { return result.title }
        if result.type == .compoundPlot, let plot = result.parsedPlotNumber, !plot.isEmpty {
            return "Plot \(plot) · \(result.villageDisplayName)"
        }
        return result.villageDisplayName
    }

    private var odiaName: String? {
        guard isVillage, let odia = result.villageNameOdia, !odia.isEmpty, odia != primaryText else { return nil }
        return odia
    }

    private var iconName: String {
        if isRecent { return "clock.arrow.circlepath" }
        return result.type.iconName
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isRecent ? Theme.Color.bhumitraSurfaceSecondary : Theme.Color.bhumitraTint)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isRecent ? Theme.Color.bhumitraTertiaryText : Theme.Color.bhumitraPrimary)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(primaryText)
                        .font(.appText(primaryText, size: 15, weight: .semibold))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .lineLimit(1)
                    if let odia = odiaName {
                        Text("·")
                            .foregroundColor(Theme.Color.bhumitraTertiaryText)
                            .accessibilityHidden(true)
                        Text(odia)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            .lineLimit(1)
                    }
                }
                Text(result.administrativeLine)
                    .font(.appText(result.administrativeLine, size: 12.5, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: isRecent ? "arrow.up.left" : "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isVillage ? "Opens this village on the map" : "Shows this place on the map")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        var parts = [primaryText]
        if let odia = odiaName { parts.append(odia) }
        parts.append(result.administrativeLine)
        if isRecent { parts.insert("Recent", at: 0) }
        return parts.joined(separator: ", ")
    }
}

/// Quiet footer under results: the manual picker is still one tap away.
struct BrowseByDistrictRow: View {
    let action: () -> Void

    var body: some View {
        Button {
            Theme.selectionHaptic()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.indent")
                    .font(.system(size: 12, weight: .semibold))
                Text("Can't find it? Browse by district")
                    .font(.googleSans(size: 13.5, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(Theme.Color.bhumitraPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Can't find it? Browse by district, tahasil and village")
    }
}

struct SearchEmptyStateCard: View {
    let query: String
    let onManualSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.myBhoomiBlue.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.myBhoomiBlue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("No village found for “\(query)”")
                        .font(.stackSansHeadline(size: 15, weight: .bold))
                        .foregroundColor(Theme.Color.bhumitraTextStrong)
                    
                    Text("Check the spelling, try the Odia name, or browse by district.")
                        .font(.stackSansHeadline(size: 12, weight: .regular))
                        .foregroundColor(Theme.Color.bhumitraTextMuted)
                        .lineLimit(2)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Try searching for:")
                    .font(.stackSansHeadline(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Color.secondaryText)
                
                HStack(spacing: 6) {
                    examplePill("Patia")
                    examplePill("ପଟିଆ")
                    examplePill("Patia 547")
                }
            }
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onManualSelect()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Browse by district")
                        .font(.stackSansHeadline(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(Theme.myBhoomiBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.myBhoomiBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(ScaledButtonStyle())
            .accessibilityLabel("Browse District and Tahasil List manually")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Color.bhumitraCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Color.bhumitraCardStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
        )
        .padding(.top, 8)
    }
    
    private func examplePill(_ text: String) -> some View {
        Text(text)
            .font(Font.containsOdiaScript(text) ? .system(size: 11, weight: .medium) : .stackSansHeadline(size: 11, weight: .medium))
            .foregroundColor(Theme.Color.bhumitraTextMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Theme.Color.bhumitraSurfaceSecondary)
            )
    }
}

struct RecentSearchesDropdown: View {
    let recents: [LocationSearchResult]
    let onSelect: (LocationSearchResult) -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Recent Searches")
                    .font(.stackSansHeadline(size: 12, weight: .bold))
                    .foregroundColor(Theme.Color.secondaryText)
                
                Spacer()
                
                Button("Clear", action: onClear)
                    .font(.stackSansHeadline(size: 12, weight: .medium))
                    .foregroundColor(Theme.myBhoomiBlue)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
            
            // List
            ForEach(recents) { item in
                Button(action: {
                    onSelect(item)
                }) {
                    LocationSuggestionRow(result: item, isRecent: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(ScaledButtonStyle())
                
                if item.id != recents.last?.id {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .padding(.bottom, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Color.bhumitraCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Color.bhumitraCardStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
        )
        .padding(.top, 8)
    }
}
