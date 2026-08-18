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
                .background(Color(UIColor.secondarySystemBackground))
                
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
                .padding(10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                if isLoading {
                    Spacer()
                    ProgressView("Connecting to 4K GEO GIS API...")
                        .tint(Theme.primary)
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
                                Button(action: { selectDistrict(d) }) {
                                    HStack {
                                        Text(d.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else if selectedBlock == nil {
                            // Step 2: Select Block
                            ForEach(filteredBlocks) { b in
                                Button(action: { selectBlock(b) }) {
                                    HStack {
                                        Text(b.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else if selectedGP == nil {
                            // Step 3: Select GP
                            ForEach(filteredGPs) { g in
                                Button(action: { selectGP(g) }) {
                                    HStack {
                                        Text(g.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else {
                            // Step 4: Select Village
                            ForEach(filteredVillages) { v in
                                Button(action: { selectVillage(v) }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(v.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Text("Code: \(v.id)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundColor(Theme.primary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
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
        _Concurrency.Task {
            await viewModel.loadCadastralVillage(village: v)
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
        }
    }
}
