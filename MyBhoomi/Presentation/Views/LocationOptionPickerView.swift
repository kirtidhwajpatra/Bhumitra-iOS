//  LocationOptionPickerView.swift
//  MyBhoomi
//
//  Focused list for one location level (e.g. "Select a Village"): a compact
//  nav row, an inset search field and a plain hairline-separated list on the
//  sheet's single background.

import SwiftUI

public struct LocationOptionPickerView: View {
    public let type: LocationPickerType
    public let title: String
    public let placeholder: String
    public let items: [String]
    public let selectedItem: String?
    public let isLoading: Bool
    public let errorMessage: String?
    public let onBack: () -> Void
    public let onClose: () -> Void
    public let onRetry: (() -> Void)?
    public let onSelect: (String) -> Void

    @State private var searchText: String = ""

    private var filteredItems: [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let q = trimmed.lowercased()
        return items.filter { $0.lowercased().contains(q) }
    }

    /// "Select a Village" → "Village", for empty/loading copy.
    private var entityName: String {
        title.replacingOccurrences(of: "Select a ", with: "")
            .replacingOccurrences(of: "Select an ", with: "")
    }

    public var body: some View {
        VStack(spacing: 0) {
            navRow
            searchField
                .padding(.horizontal, SheetChrome.inset)
                .padding(.bottom, 12)
            SheetHairline()
            content
        }
        .background(SheetChrome.background.ignoresSafeArea())
    }

    private var navRow: some View {
        ZStack {
            Text(title)
                .font(.stackSansHeadline(size: 17, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .lineLimit(1)
                .padding(.horizontal, 56)
            HStack {
                SheetIconButton("chevron.left", accessibilityLabel: "Back", action: onBack)
                Spacer()
                SheetIconButton("xmark", accessibilityLabel: "Close", action: onClose)
            }
        }
        .padding(.horizontal, SheetChrome.inset)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Color.bhumitraTertiaryText)
            TextField(placeholder, text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .autocorrectionDisabled(true)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SheetChrome.controlFill))
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            statusView {
                ProgressView()
                Text("Loading \(entityName)s…")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
            }
        } else if let error = errorMessage {
            statusView {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraWarning)
                Text(error)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if let onRetry {
                    Button(action: onRetry) {
                        Label("Try again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.secondaryCTA)
                    .fixedSize()
                }
            }
        } else if filteredItems.isEmpty {
            statusView {
                Text("No \(entityName) found")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                if !searchText.isEmpty {
                    Text("Check the spelling or try a shorter name.")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Color.bhumitraTertiaryText)
                }
            }
        } else {
            list
        }
    }

    private func statusView<C: View>(@ViewBuilder _ inner: () -> C) -> some View {
        VStack(spacing: 12) {
            inner()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    private var list: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems, id: \.self) { item in
                    row(item)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func row(_ item: String) -> some View {
        let isCurrent = item.caseInsensitiveCompare(selectedItem ?? "") == .orderedSame
        return Button {
            onSelect(item)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(item)
                        .font(.system(size: 16, weight: isCurrent ? .semibold : .regular))
                        .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isCurrent {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraPrimary)
                    }
                }
                .frame(height: SheetChrome.rowHeight)
                Rectangle()
                    .fill(Theme.Color.bhumitraBorder)
                    .frame(height: 0.5)
            }
            .padding(.horizontal, SheetChrome.inset)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item)\(isCurrent ? ", selected" : "")")
    }
}
