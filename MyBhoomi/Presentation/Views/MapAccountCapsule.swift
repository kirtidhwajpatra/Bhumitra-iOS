//  MapAccountCapsule.swift
//  MyBhoomi
//
//  Top-right map chrome: the search-credit balance and the account/settings
//  entry as two separate controls (capsule + circle) on the shared map glass,
//  same 44pt height, 8pt apart.

import SwiftUI

public struct MapAccountCapsule: View {
    public let credits: Int
    public let isUnlimited: Bool
    public let isCoverPresented: Bool
    public let onCreditsTap: () -> Void
    public let onProfileTap: () -> Void

    public init(
        credits: Int,
        isUnlimited: Bool,
        isCoverPresented: Bool,
        onCreditsTap: @escaping () -> Void,
        onProfileTap: @escaping () -> Void
    ) {
        self.credits = credits
        self.isUnlimited = isUnlimited
        self.isCoverPresented = isCoverPresented
        self.onCreditsTap = onCreditsTap
        self.onProfileTap = onProfileTap
    }

    public var body: some View {
        HStack(spacing: MapChrome.spacing) {
            // Credits: its own capsule
            PlotSearchCreditButton(
                credits: credits,
                isUnlimited: isUnlimited,
                isCoverPresented: isCoverPresented,
                embedded: true,
                action: onCreditsTap
            )
            .frame(height: MapChrome.controlHeight)
            .mapChromeSurface(in: Capsule())

            // Account: its own circle
            Button {
                Theme.haptic(.light)
                onProfileTap()
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .frame(width: MapChrome.controlHeight, height: MapChrome.controlHeight)
                    .contentShape(Circle())
            }
            .buttonStyle(MapChromePressStyle())
            .mapChromeSurface(in: Circle())
            .accessibilityLabel("Account and settings")
        }
    }
}
