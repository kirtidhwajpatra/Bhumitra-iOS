//
//  SavedLandsView.swift
//  MyBhoomi
//
//  Pixel-perfect implementation of Saved Lands Screen.
//  Matches Figma design:
//  - Top navigation bar with circular back button and "Saved Lands" title
//  - Pastel lavender cards with bold PLOT header, village name, location pin, and "View details →" pill button
//  - Interactive bookmark toggle / deletion flow
//

import SwiftUI

public struct SavedLandsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var savedManager = SavedLandManager.shared
    @ObservedObject private var navManager = AppNavigationManager.shared
    
    @State private var selectedRecordForDetail: SavedLandRecord? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var recordToDelete: SavedLandRecord? = nil
    
    // Figma Colors
    private let cardBackground = Color(red: 246 / 255, green: 240 / 255, blue: 254 / 255) // #F6F0FE
    private let plotHeaderColor = Color(red: 29 / 255, green: 0 / 255, blue: 82 / 255)    // #1D0052
    private let villageNameColor = Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255)   // #4A4A4A
    private let electricPurple = Color(red: 116 / 255, green: 18 / 255, blue: 250 / 255)  // #7412FA
    private let subtitleColor = Color(red: 90 / 255, green: 90 / 255, blue: 90 / 255)     // #5A5A5A
    private let pillBorderColor = Color(red: 229 / 255, green: 217 / 255, blue: 248 / 255) // #E5D9F8
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Page Canvas Background
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Top Navigation Bar
                topNavBar
                
                if savedManager.savedRecords.isEmpty {
                    emptyStateView
                } else {
                    // 2. Saved Lands Cards Scrollable List
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(savedManager.savedRecords) { record in
                                savedLandCard(record: record)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 110)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedRecordForDetail) { record in
            LandPassportDetailView(result: record.toSearchResult)
        }
        .alert("Remove Saved Land?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { recordToDelete = nil }
            Button("Remove", role: .destructive) {
                if let target = recordToDelete {
                    savedManager.remove(recordID: target.id)
                    recordToDelete = nil
                }
            }
        } message: {
            if let target = recordToDelete {
                Text("Are you sure you want to remove Plot \(target.plotNumber) in \(target.villageName) from your saved lands?")
            }
        }
    }
    
    // MARK: - 1. Top Navigation Bar
    
    private var topNavBar: some View {
        HStack {
            // Circular Back Button
            Button {
                navManager.navigate(to: .home)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#EAEAEA"), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#444444"))
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Home")
            
            Spacer()
            
            Text("Saved Lands")
                .font(.stackSansHeadline(size: 26, weight: .bold))
                .foregroundColor(Color.black)
            
            Spacer()
            
            // Balance Spacer for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - 2. Saved Land Card (Figma Layout)
    
    private func savedLandCard(record: SavedLandRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Row: PLOT NUMBER (Left) & Bookmark Icon (Right)
            HStack(alignment: .top) {
                Text("PLOT \(record.plotNumber)")
                    .font(.stackSansHeadline(size: 25, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(plotHeaderColor)
                
                Spacer()
                
                Button {
                    recordToDelete = record
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(electricPurple)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Plot \(record.plotNumber) from saved")
            }
            
            // Middle: Village Name
            Text(record.villageName.capitalized)
                .font(.stackSansHeadline(size: 25, weight: .bold))
                .foregroundColor(villageNameColor)
                .padding(.top, 14)
            
            // Bottom Row: Location Pin + Tahasil/District (Left) & "View details →" Button (Right)
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "mappin")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(electricPurple)
                    
                    Text("\(record.tahasilName), \(record.districtName)".lowercased())
                        .font(.system(size: 14.5, weight: .regular))
                        .foregroundColor(subtitleColor)
                }
                
                Spacer()
                
                Button {
                    selectedRecordForDetail = record
                } label: {
                    Text("View details \u{2192}")
                        .font(.stackSansHeadline(size: 14, weight: .bold))
                        .foregroundColor(electricPurple)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(pillBorderColor, lineWidth: 1.5)
                        )
                }
                .buttonStyle(BhumitraPrimaryActionButtonStyle())
            }
            .padding(.top, 6)
        }
        .padding(20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - 3. Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bookmark")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(electricPurple)
            }
            
            VStack(spacing: 8) {
                Text("No Saved Lands Yet")
                    .font(.stackSansHeadline(size: 22, weight: .bold))
                    .foregroundColor(Color.black)
                
                Text("Tap the bookmark button on any plot or cadastral map details to store official land records securely on your device for instant offline access.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(subtitleColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }
            
            Button {
                navManager.navigate(to: .map)
            } label: {
                Text("Explore Map")
                    .font(.stackSansHeadline(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(electricPurple)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.bottom, 60)
    }
}

#Preview {
    SavedLandsView()
}
