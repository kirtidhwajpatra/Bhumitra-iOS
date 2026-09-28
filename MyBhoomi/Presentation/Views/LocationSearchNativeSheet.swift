//
//  LocationSearchNativeSheet.swift
//  MyBhoomi
//
//  Native Apple SwiftUI Location Search Presentation using .searchable and
//  native search presentation APIs with Liquid Glass styling.
//

import SwiftUI

public struct LocationSearchNativeSheet: View {
    /// Not observed: the sheet owns its query text and reads results from the
    /// search service, so typing never republishes the (huge) map view model
    /// and never re-renders the map underneath the sheet.
    public let viewModel: MapViewModel
    @ObservedObject public var locationSearchService: LocationSearchService
    @State private var query: String = ""
    private var results: [LocationSearchResult] { locationSearchService.searchResults }
    @ObservedObject public var recentStore: RecentLocationSearchStore
    public var isDarkMode: Bool
    public var onSelect: (LocationSearchResult, Bool) -> Void
    public var onOpenManualSelector: () -> Void
    public var onOpenProfile: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFieldFocused: Bool
    
    public init(
        viewModel: MapViewModel,
        locationSearchService: LocationSearchService,
        recentStore: RecentLocationSearchStore,
        isDarkMode: Bool,
        onSelect: @escaping (LocationSearchResult, Bool) -> Void,
        onOpenManualSelector: @escaping () -> Void,
        onOpenProfile: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.locationSearchService = locationSearchService
        self.recentStore = recentStore
        self.isDarkMode = isDarkMode
        self.onSelect = onSelect
        self.onOpenManualSelector = onOpenManualSelector
        self.onOpenProfile = onOpenProfile
    }
    
    private var resultsHeader: String {
        let villageCount = results.filter { $0.type == .revenueVillage || $0.type == .compoundPlot }.count
        return villageCount == results.count ? "Villages" : "Places in Odisha"
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if locationSearchService.isSearching && results.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .controlSize(.regular)
                            .tint(Theme.Color.bhumitraPrimary)
                        Text("Searching Odisha locations...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                        Spacer()
                    }
                } else if !results.isEmpty {
                    List {
                        Section {
                            ForEach(results) { result in
                                Button {
                                    onSelect(result, false)
                                    dismiss()
                                } label: {
                                    LocationSuggestionRow(result: result)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(resultsHeader)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                        }
                        
                        Section {
                            BrowseByDistrictRow {
                                dismiss()
                                onOpenManualSelector()
                            }
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollDismissesKeyboard(.immediately)
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !locationSearchService.isSearching {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(Color(hex: "#9E9E9E"))
                        Text("No matching locations found for \"\(query)\"")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isDarkMode ? .white : Color(hex: "#111111"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        Button {
                            dismiss()
                            onOpenManualSelector()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet.rectangle.portrait")
                                Text("Browse Districts & Tahasils")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Theme.Color.bhumitraPrimary))
                            .foregroundColor(.white)
                        }
                        Spacer()
                    }
                } else if !recentStore.recents.isEmpty {
                    List {
                        Section {
                            ForEach(recentStore.recents) { recent in
                                Button {
                                    onSelect(recent, true)
                                    dismiss()
                                } label: {
                                    LocationSuggestionRow(result: recent, isRecent: true)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack {
                                Text("Recent Searches")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                                Spacer()
                                Button("Clear") {
                                    recentStore.clearAll()
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.Color.bhumitraPrimary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollDismissesKeyboard(.immediately)
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "map.circle")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(Theme.Color.bhumitraPrimary.opacity(0.6))
                        Text("Type a village name in English or Odia")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isDarkMode ? .white : Color(hex: "#111111"))
                            .multilineTextAlignment(.center)
                        Text("Pick it from the list to open its plots directly.\nAdd a plot number to jump to it, e.g. “Patia 547”.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button {
                            dismiss()
                            onOpenManualSelector()
                        } label: {
                            Text("Browse by district instead")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.Color.bhumitraPrimary)
                        }
                        .padding(.top, 4)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Search Odisha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        onOpenProfile()
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Theme.Color.bhumitraPrimary)
                    }
                    .accessibilityLabel("Profile and Settings")
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Village name, e.g. Patia or ପଟିଆ"
            )
            .searchFocused($isSearchFieldFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
            .onChange(of: query) { _, newValue in
                // Debounced + de-duplicated inside the service.
                locationSearchService.search(query: newValue)
            }
            .onAppear {
                locationSearchService.clearSearch()
                // Open straight into typing: the keyboard is up as soon as the sheet appears.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isSearchFieldFocused = true
                }
            }
            .onDisappear {
                locationSearchService.clearSearch()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // Solid background: a blur material over a live satellite map is
        // re-composited every frame and made typing visibly laggy.
        .presentationBackground(Theme.Color.bhumitraBackground)
    }
}
