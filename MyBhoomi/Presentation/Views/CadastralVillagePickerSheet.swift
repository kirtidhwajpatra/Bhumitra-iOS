import SwiftUI

public struct CadastralVillagePickerSheet: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var districts: [CadastralDistrict] = []
    @State private var blocks: [CadastralBlock] = []
    @State private var gps: [CadastralGP] = []
    @State private var villages: [CadastralVillage] = []
    
    @State private var selectedDistrict: CadastralDistrict? = nil
    @State private var selectedBlock: CadastralBlock? = nil
    @State private var selectedGP: CadastralGP? = nil
    
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    
    public init(viewModel: MapViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                AppAtmosphereBackground()
                VStack(spacing: 0) {
                // Stepper breadcrumbs
                HStack(spacing: 8) {
                    StepPill(title: selectedDistrict?.name ?? "1. District", isActive: selectedDistrict == nil, isCompleted: selectedDistrict != nil) {
                        selectedDistrict = nil
                        selectedBlock = nil
                        selectedGP = nil
                        blocks = []
                        gps = []
                        villages = []
                    }
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                    StepPill(title: selectedBlock?.name ?? "2. Block", isActive: selectedDistrict != nil && selectedBlock == nil, isCompleted: selectedBlock != nil) {
                        selectedBlock = nil
                        selectedGP = nil
                        gps = []
                        villages = []
                    }
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.secondary)
                    StepPill(title: selectedGP?.name ?? "3. GP", isActive: selectedBlock != nil && selectedGP == nil, isCompleted: selectedGP != nil) {
                        selectedGP = nil
                        villages = []
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .liquidGlassCard(tint: Theme.Color.indigo, radius: Theme.Radius.medium)
                .padding(.horizontal, Theme.Spacing.md)
                
                // Search Input
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search...", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .liquidGlassCard(tint: Theme.Color.primary, radius: Theme.Radius.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                if isLoading {
                    Spacer()
                    ParcelLoadingIndicator(title: "Finding locations", subtitle: "Connecting to the 4K GEO directory")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Retry") { loadInitialDistricts() }
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else {
                    List {
                        if selectedDistrict == nil {
                            // Step 1: Select District
                            ForEach(filteredDistricts) { d in
                                PickerListRow(title: d.name, icon: "map") { selectDistrict(d) }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } else if selectedBlock == nil {
                            // Step 2: Select Block
                            ForEach(filteredBlocks) { b in
                                PickerListRow(title: b.name, icon: "building.2") { selectBlock(b) }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } else if selectedGP == nil {
                            // Step 3: Select GP
                            ForEach(filteredGPs) { g in
                                PickerListRow(title: g.name, icon: "person.3") { selectGP(g) }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } else {
                            // Step 4: Select Village
                            ForEach(filteredVillages) { v in
                                PickerListRow(title: v.name, subtitle: "Location code \(v.id)", icon: "house.and.flag") { selectVillage(v) }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                }
            }
            .navigationTitle("Select 4K GEO Village")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                loadInitialDistricts()
            }
        }
    }
    
    private var filteredDistricts: [CadastralDistrict] {
        if searchText.isEmpty { return districts }
        return districts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredBlocks: [CadastralBlock] {
        if searchText.isEmpty { return blocks }
        return blocks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredGPs: [CadastralGP] {
        if searchText.isEmpty { return gps }
        return gps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var filteredVillages: [CadastralVillage] {
        if searchText.isEmpty { return villages }
        return villages.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.id.contains(searchText) }
    }
    
    private func loadInitialDistricts() {
        isLoading = true
        errorMessage = nil
        _Concurrency.Task {
            do {
                let list = try await CadastralRepository.shared.getDistricts()
                await MainActor.run {
                    self.districts = list
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load districts from official 4K GEO API: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func selectDistrict(_ d: CadastralDistrict) {
        selectedDistrict = d
        searchText = ""
        isLoading = true
        _Concurrency.Task {
            do {
                let list = try await CadastralRepository.shared.getBlocks(districtID: d.id)
                await MainActor.run {
                    self.blocks = list
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load blocks: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func selectBlock(_ b: CadastralBlock) {
        selectedBlock = b
        searchText = ""
        isLoading = true
        _Concurrency.Task {
            do {
                let list = try await CadastralRepository.shared.getGPs(blockID: b.id)
                await MainActor.run {
                    self.gps = list
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load GPs: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func selectGP(_ g: CadastralGP) {
        selectedGP = g
        searchText = ""
        isLoading = true
        guard let b = selectedBlock else { return }
        
        _Concurrency.Task {
            do {
                let list = try await CadastralRepository.shared.getVillages(blockID: b.id, gpID: g.id)
                await MainActor.run {
                    self.villages = list
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load villages: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func selectVillage(_ v: CadastralVillage) {
        dismiss()
        let resolvedVillage = CadastralVillage(
            id: v.id,
            name: v.name,
            gpID: selectedGP?.id ?? v.gpID,
            blockID: selectedBlock?.id ?? v.blockID,
            districtID: selectedDistrict?.id ?? v.districtID,
            blockName: selectedBlock?.name,
            districtName: selectedDistrict?.name
        )
        _Concurrency.Task {
            await viewModel.loadCadastralVillage(village: resolvedVillage)
        }
    }
}

struct StepPill: View {
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? Theme.primary : (isCompleted ? .primary : .secondary))
                .lineLimit(1)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, 6)
                .background(Capsule().fill(isActive ? Theme.Color.primaryLight : Color.white.opacity(0.46)))
        }
        .buttonStyle(TactileGlassButtonStyle(isActive: isActive))
    }
}

private struct PickerListRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            Theme.selectionHaptic()
            action()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.Color.primaryLight))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.primaryBodyBold)
                        .foregroundStyle(Theme.Color.primaryText)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Color.secondaryText)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Color.tertiaryText)
            }
            .padding(Theme.Spacing.sm)
            .liquidGlassCard(tint: Theme.Color.primary, radius: Theme.Radius.medium)
        }
        .buttonStyle(TactileGlassButtonStyle())
        .padding(.vertical, 3)
    }
}
