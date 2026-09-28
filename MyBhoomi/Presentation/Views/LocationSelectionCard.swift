//  LocationSelectionCard.swift
//  MyBhoomi
//
//  One row of the location picker's 4-step hierarchy (District → Tahsil →
//  Panchayat → Village). Rows sit directly on the sheet background, separated
//  by hairlines — no floating cards — and a numbered step marker shows where
//  the user is in the chain.

import SwiftUI

public struct LocationSelectionCard: View {
    public let levelTitle: String
    public let selectedValue: String?
    public let placeholder: String
    public let iconSystemName: String
    public let stepNumber: Int?
    public let isSelected: Bool
    public let isActive: Bool
    public let isEnabled: Bool
    public let showSkeleton: Bool
    public let onClear: (() -> Void)?
    public let onTap: () -> Void

    public init(
        levelTitle: String,
        selectedValue: String?,
        placeholder: String,
        iconSystemName: String,
        stepNumber: Int? = nil,
        isSelected: Bool,
        isActive: Bool = false,
        isEnabled: Bool = true,
        showSkeleton: Bool = false,
        onTap: @escaping () -> Void,
        onClear: (() -> Void)? = nil
    ) {
        self.levelTitle = levelTitle
        self.selectedValue = selectedValue
        self.placeholder = placeholder
        self.iconSystemName = iconSystemName
        self.stepNumber = stepNumber
        self.isSelected = isSelected
        self.isActive = isActive
        self.isEnabled = isEnabled
        self.showSkeleton = showSkeleton
        self.onClear = onClear
        self.onTap = onTap
    }

    public var body: some View {
        if showSkeleton {
            skeletonRow
        } else {
            selectableRow
        }
    }

    private var skeletonRow: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(SheetChrome.controlFill)
                .frame(width: 28, height: 28)
                .skeletonShimmer()
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(SheetChrome.controlFill)
                    .frame(width: 60, height: 10).skeletonShimmer()
                RoundedRectangle(cornerRadius: 4).fill(SheetChrome.controlFill)
                    .frame(width: 150, height: 14).skeletonShimmer()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .accessibilityLabel("\(levelTitle) loading")
    }

    private var selectableRow: some View {
        Button {
            guard isEnabled else { return }
            onTap()
        } label: {
            HStack(spacing: 14) {
                stepMarker

                VStack(alignment: .leading, spacing: 2) {
                    Text(levelTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    Text(hasValue ? (selectedValue ?? "") : placeholder)
                        .font(hasValue
                              ? .stackSansHeadline(size: 16, weight: .semibold)
                              : .system(size: 15, weight: .regular))
                        .foregroundColor(hasValue ? Theme.Color.bhumitraPrimaryText : Theme.Color.bhumitraTertiaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                if let onClear, isSelected, isEnabled {
                    Button {
                        Theme.haptic(.light)
                        onClear()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraSecondaryText)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(SheetChrome.controlFill))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(levelTitle) selection")
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraTertiaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(MapChromePressStyle())
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(levelTitle), \(selectedValue ?? placeholder), \(isSelected ? "selected" : (isEnabled ? "not selected" : "disabled"))")
    }

    private var hasValue: Bool {
        if let v = selectedValue { return !v.isEmpty }
        return false
    }

    /// Filled check = done; accent ring = current step; grey ring = locked.
    @ViewBuilder
    private var stepMarker: some View {
        ZStack {
            if isSelected {
                Circle().fill(Theme.Color.bhumitraPrimary)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Circle()
                    .stroke(isEnabled ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraBorder, lineWidth: 1.5)
                if let stepNumber {
                    Text("\(stepNumber)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isEnabled ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraTertiaryText)
                } else {
                    Image(systemName: iconSystemName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isEnabled ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraTertiaryText)
                }
            }
        }
        .frame(width: 28, height: 28)
    }
}
