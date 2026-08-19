import SwiftUI

/// Main screen for searching Odisha official land records directly.
public struct OfficialLandRecordsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OfficialLandRecordsViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Apple-style very light surface
                Color(white: 0.98).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Official Land Records")
                                .font(.system(size: 26, weight: .bold, design: .default))
                                .foregroundColor(.black)
                            
                            Text("Search Odisha land records directly")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        
                        // Location Hierarchy Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 10) {
                                // 1. District Row
                                LocationSelectionCard(
                                    title: "District",
                                    value: viewModel.selectedDistrict?.officialName,
                                    placeholder: "Select District",
                                    isEnabled: true,
                                    action: {
                                        viewModel.loadDistricts()
                                        viewModel.activePicker = .district
                                    }
                                )
                                
                                // 2. Tahasil Row
                                LocationSelectionCard(
                                    title: "Tahasil",
                                    value: viewModel.selectedTahasil?.officialName,
                                    placeholder: viewModel.selectedDistrict == nil ? "Select District first" : "Select Tahasil",
                                    isEnabled: viewModel.selectedDistrict != nil,
                                    action: {
                                        if let d = viewModel.selectedDistrict {
                                            viewModel.loadTahasils(for: d.id)
                                            viewModel.activePicker = .tahasil
                                        }
                                    }
                                )
                                
                                // 3. Village Row
                                LocationSelectionCard(
                                    title: "Village",
                                    value: viewModel.selectedVillage?.officialName,
                                    placeholder: viewModel.selectedTahasil == nil ? "Select Tahasil first" : "Select Village",
                                    isEnabled: viewModel.selectedTahasil != nil,
                                    action: {
                                        if let d = viewModel.selectedDistrict, let t = viewModel.selectedTahasil {
                                            viewModel.loadVillages(districtID: d.id, tahasilID: t.id)
                                            viewModel.activePicker = .village
                                        }
                                    }
                                )
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        hapticFeedback(.light)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.emeraldGreen)
                }
            }
            .sheet(item: $viewModel.activePicker) { pickerType in
                switch pickerType {
                case .district:
                    OfficialLocationPickerSheet(
                        title: "District",
                        items: viewModel.districts.map {
                            LocationPickerItem(id: $0.id, title: $0.officialName)
                        },
                        selectedID: viewModel.selectedDistrict?.id,
                        isLoading: viewModel.isLoadingDistricts,
                        errorMessage: viewModel.districtError,
                        onSelect: { item in
                            if let match = viewModel.districts.first(where: { $0.id == item.id }) {
                                viewModel.selectDistrict(match)
                            }
                        },
                        onRetry: {
                            viewModel.loadDistricts()
                        }
                    )
                    
                case .tahasil:
                    OfficialLocationPickerSheet(
                        title: "Tahasil",
                        items: viewModel.tahasils.map {
                            LocationPickerItem(id: $0.id, title: $0.officialName)
                        },
                        selectedID: viewModel.selectedTahasil?.id,
                        isLoading: viewModel.isLoadingTahasils,
                        errorMessage: viewModel.tahasilError,
                        onSelect: { item in
                            if let match = viewModel.tahasils.first(where: { $0.id == item.id }) {
                                viewModel.selectTahasil(match)
                            }
                        },
                        onRetry: {
                            if let d = viewModel.selectedDistrict {
                                viewModel.loadTahasils(for: d.id)
                            }
                        }
                    )
                    
                case .village:
                    OfficialLocationPickerSheet(
                        title: "Village",
                        items: viewModel.villages.map {
                            LocationPickerItem(id: $0.id, title: $0.officialName)
                        },
                        selectedID: viewModel.selectedVillage?.id,
                        isLoading: viewModel.isLoadingVillages,
                        errorMessage: viewModel.villageError,
                        onSelect: { item in
                            if let match = viewModel.villages.first(where: { $0.id == item.id }) {
                                viewModel.selectVillage(match)
                            }
                        },
                        onRetry: {
                            if let d = viewModel.selectedDistrict, let t = viewModel.selectedTahasil {
                                viewModel.loadVillages(districtID: d.id, tahasilID: t.id)
                            }
                        }
                    )
                }
            }
        }
    }
}

/// Large rounded selection card for District / Tahasil / Village rows.
struct LocationSelectionCard: View {
    let title: String
    let value: String?
    let placeholder: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if isEnabled {
                hapticFeedback(.light)
                action()
            }
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(isEnabled ? .black : Color.black.opacity(0.4))
                
                Spacer()
                
                Text(value ?? placeholder)
                    .font(.system(size: 16, weight: value != nil ? .bold : .regular))
                    .foregroundColor(value != nil ? .black : Color.black.opacity(0.3))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.black.opacity(isEnabled ? 0.2 : 0.08))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(ScaledButtonStyle())
        .disabled(!isEnabled)
    }
}

#Preview {
    OfficialLandRecordsView()
}
