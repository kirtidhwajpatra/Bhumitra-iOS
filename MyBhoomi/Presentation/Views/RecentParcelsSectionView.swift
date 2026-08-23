//
//  RecentParcelsSectionView.swift
//  MyBhoomi
//
//  Compact Apple-style list for recently verified land parcels.
//  Provides instant access to cached results, smart suggestions, and clear history.
//

import SwiftUI

/// Compact Apple-style list showing recently verified land parcels.
public struct RecentParcelsSectionView: View {
    @ObservedObject private var cache = VerifiedParcelCache.shared
    @Environment(\.colorScheme) private var colorScheme
    
    public let onSelectParcel: (CachedVerifiedParcel) -> Void
    public var onOpenOnMap: ((CachedVerifiedParcel) -> Void)? = nil
    
    @State private var showClearConfirmation: Bool = false
    
    public init(
        onSelectParcel: @escaping (CachedVerifiedParcel) -> Void,
        onOpenOnMap: ((CachedVerifiedParcel) -> Void)? = nil
    ) {
        self.onSelectParcel = onSelectParcel
        self.onOpenOnMap = onOpenOnMap
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Section Header with Title & Clear Action
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.accentColor)
                    
                    Text("RECENT PARCELS")
                        .font(.system(size: 12, weight: .bold, design: .default))
                        .foregroundColor(Theme.Color.secondaryText)
                }
                
                Spacer()
                
                if !cache.recentParcels.isEmpty {
                    Button {
                        Theme.haptic(.light)
                        showClearConfirmation = true
                    } label: {
                        Text("Clear Recent")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Color.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            if cache.recentParcels.isEmpty {
                // Subtle Empty State
                HStack {
                    Image(systemName: "doc.badge.clock")
                        .foregroundColor(Theme.Color.secondaryText.opacity(0.6))
                    Text("Your verified parcels will appear here.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Color.secondaryText)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Color.surface)
                .cornerRadius(Theme.Radius.medium)
            } else {
                // List of Compact Apple-style Recent Cards
                VStack(spacing: 8) {
                    ForEach(cache.recentParcels) { parcel in
                        RecentParcelCardRow(
                            parcel: parcel,
                            onTap: {
                                Theme.haptic(.light)
                                onSelectParcel(parcel)
                            },
                            onOpenMap: onOpenOnMap != nil ? {
                                Theme.haptic(.light)
                                onOpenOnMap?(parcel)
                            } : nil
                        )
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear recent parcels?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Recent Parcels", role: .destructive) {
                Theme.haptic(.medium)
                cache.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your saved verified parcel results will be removed from this device. Official records on Bhulekh will not be affected.")
        }
    }
}

/// Compact card row displaying a single recently verified parcel.
public struct RecentParcelCardRow: View {
    public let parcel: CachedVerifiedParcel
    public let onTap: () -> Void
    public var onOpenMap: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Row 1: PLOT NO (Left) & VERIFIED BADGE (Right)
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Text("PLOT \(parcel.plotNumber)")
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .foregroundColor(Theme.Color.primaryText)
                        
                        if parcel.isGovernmentLand {
                            Text("GOVT")
                                .font(.system(size: 10, weight: .bold, design: .default))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(Color.accentColor)
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    // Verification Badge
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.accentColor)
                        Text("Verified")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.accentColor)
                    }
                }
                
                // Row 2: Village Name
                Text(parcel.villageName)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(Theme.Color.primaryText)
                    .lineLimit(1)
                
                // Row 3: Tahasil · District
                Text("\(parcel.tahasilName) · \(parcel.districtName)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Color.secondaryText)
                    .lineLimit(1)
                
                // Divider Line
                Rectangle()
                    .frame(height: 0.6)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    .padding(.vertical, 2)
                
                // Row 4: Khata Number (Left) & Area Metric (Right)
                HStack {
                    Text("Khata \(parcel.khataNumber)")
                        .font(.system(size: 12.5, weight: .medium, design: .default))
                        .foregroundColor(Theme.Color.secondaryText)
                    
                    Spacer()
                    
                    Text(parcel.compactAreaDisplay)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Color.primaryText)
                }
            }
            .padding(14)
            .background(Theme.Color.surface)
            .cornerRadius(Theme.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Theme.Shadow.subtle, radius: 6, y: 2)
        }
        .buttonStyle(ScaledButtonStyle())
    }
}
