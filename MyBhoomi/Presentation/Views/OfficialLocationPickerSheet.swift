import SwiftUI

public struct LocationPickerItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String?
    
    public init(id: String, title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

/// Reusable Apple-style Liquid Glass picker sheet for District, Tahasil, and Village selection.
public struct OfficialLocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public let title: String
    public let items: [LocationPickerItem]
    public let selectedID: String?
    public let isLoading: Bool
    public let errorMessage: String?
    public let onSelect: (LocationPickerItem) -> Void
    public let onRetry: () -> Void
    
    @State private var searchText = ""
    
    public init(
        title: String,
        items: [LocationPickerItem],
        selectedID: String?,
        isLoading: Bool,
        errorMessage: String?,
        onSelect: @escaping (LocationPickerItem) -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.title = title
        self.items = items
        self.selectedID = selectedID
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onSelect = onSelect
        self.onRetry = onRetry
    }
    
    private var filteredItems: [LocationPickerItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return items
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter {
            $0.title.lowercased().contains(query) || ($0.subtitle?.lowercased().contains(query) ?? false)
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Liquid Glass Background
                Color(white: 0.98).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar at the top of sheet
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.black.opacity(0.35))
                        
                        TextField("Search \(title.lowercased())", text: $searchText)
                            .font(.system(size: 15))
                            .autocorrectionDisabled(true)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.black.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    // Content Area
                    if isLoading {
                        VStack(spacing: 14) {
                            Spacer()
                            ProgressView()
                                .tint(Theme.myBhoomiBlue)
                                .scaleEffect(1.2)
                            Text("Loading \(title.lowercased())s...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.orange)
                            
                            Text(error)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            
                            Button(action: {
                                hapticFeedback(.medium)
                                onRetry()
                            }) {
                                Text("Try Again")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Theme.myBhoomiBlue)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                    } else if filteredItems.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundColor(Color.black.opacity(0.2))
                            Text("No \(title.lowercased()) found")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        // Scrollable List
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredItems) { item in
                                    let isSelected = item.id == selectedID
                                    Button(action: {
                                        hapticFeedback(.light)
                                        onSelect(item)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                                                    .foregroundColor(isSelected ? Theme.myBhoomiBlue : .black)
                                                if let sub = item.subtitle {
                                                    Text(sub)
                                                        .font(.system(size: 12, weight: .regular))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(Theme.myBhoomiBlue)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 14)
                                        .background(isSelected ? Theme.myBhoomiBlue.opacity(0.06) : Color.clear)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(ScaledButtonStyle())
                                    
                                    Divider()
                                        .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        hapticFeedback(.light)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.myBhoomiBlue)
                }
            }
        }
    }
}
