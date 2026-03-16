import SwiftUI

// MARK: - Navigation State
enum LandServiceType: String, CaseIterable {
    case offlineMaps = "Offline Maps"
    case viewRor = "View ROR"
    case downloadedRor = "Downloaded ROR"
}

struct LandServiceDetailView: View {
    let service: LandServiceType
    let onDismiss: () -> Void
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text(service.rawValue)
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // Invisible spacer for balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    switch service {
                    case .offlineMaps:
                        OfflineMapsView(viewModel: viewModel)
                    case .viewRor:
                        RoRSearchView(viewModel: viewModel)
                    case .downloadedRor:
                        DownloadedRoRView(viewModel: viewModel)
                    }
                }
                .padding(24)
            }
        }
        .background(Color(white: 0.98))
        .transition(.move(edge: .trailing))
    }
}

// MARK: - Individual Service Views

struct SearchItem: Identifiable, Codable {
    let id: String
    let name: String
}

struct SelectionField: View {
    let label: String
    let value: String
    let placeholder: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.2)
                .padding(.leading, 4)
            
            Button(action: {
                hapticFeedback(.light)
                action()
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.primary)
                    }
                    
                    if value.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray.opacity(0.5))
                    } else {
                        Text(value)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.black.opacity(0.05), Color.black.opacity(0.1))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
            }
            .buttonStyle(ScaledButtonStyle())
        }
    }
}

struct SelectionSheet: View {
    let title: String
    let items: [SearchItem]
    @Binding var searchText: String
    let onSelect: (SearchItem) -> Void
    let onDismiss: () -> Void
    
    var filteredItems: [SearchItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Premium Header for selection
            VStack(spacing: 20) {
                HStack {
                    Text("Select \(title)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.primary)
                    
                    TextField("Search \(title.lowercased())...", text: $searchText)
                        .font(.system(size: 16, weight: .medium))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.04))
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    if filteredItems.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.3))
                            Text("No \(title.lowercased()) matches your search")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(filteredItems) { item in
                            Button(action: {
                                hapticFeedback(.medium)
                                onSelect(item)
                            }) {
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black.opacity(0.1))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .background(Color.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black.opacity(0.03), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaledButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 8)
            }
        }
        .background(Color(white: 0.98))
    }
}

struct RoRSearchView: View {
    @ObservedObject var viewModel: MapViewModel
    
    @State private var districts: [SearchItem] = []
    @State private var tahasils: [SearchItem] = []
    @State private var villages: [SearchItem] = []
    
    @State private var selectedDistrict: SearchItem? = nil
    @State private var selectedTahasil: SearchItem? = nil
    @State private var selectedVillage: SearchItem? = nil
    
    @State private var searchBy = "Plot"
    @State private var searchId = ""
    @State private var isSearching = false
    @State private var showResult = false
    
    @State private var activeSheet: SheetType? = nil
    @State private var pickerSearchText = ""
    
    // Result data
    @State private var resultData: [String: String] = [:]
    
    enum SheetType: Identifiable {
        case district, tahasil, village
        var id: Self { self }
    }
    
    let searchOptions = ["Khata", "Plot", "Tenant"]
    let baseUrl = RoRService.shared.baseURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !showResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Record of Rights")
                        .font(.system(size: 20, weight: .bold))
                    Text("Select your location details exactly as per Bhulekh Odisha.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    SelectionField(label: "District", value: selectedDistrict?.name ?? "", placeholder: "Select District", icon: "map") {
                        activeSheet = .district
                    }
                    
                    SelectionField(label: "Tahasil", value: selectedTahasil?.name ?? "", placeholder: "Select Tahasil", icon: "building.columns") {
                        if selectedDistrict != nil { activeSheet = .tahasil }
                    }
                    .opacity(selectedDistrict == nil ? 0.5 : 1.0)
                    
                    SelectionField(label: "Village / Town Area", value: selectedVillage?.name ?? "", placeholder: "Select Area", icon: "house") {
                        if selectedTahasil != nil { activeSheet = .village }
                    }
                    .opacity(selectedTahasil == nil ? 0.5 : 1.0)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SEARCH BY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("Search By", selection: $searchBy) {
                            ForEach(searchOptions, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    InputField(label: "\(searchBy) Number/Name", text: $searchId, placeholder: "Enter \(searchBy.lowercased())", icon: "number")
                }
                
                Button(action: {
                    hapticFeedback(.medium)
                    performActualSearch()
                }) {
                    HStack {
                        if isSearching {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                            Text("View RoR Detail")
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.brandGradient)
                    .cornerRadius(16)
                    .shadow(color: Theme.primary.opacity(0.3), radius: 10, y: 5)
                }
                .disabled(isSearching || selectedVillage == nil || searchId.isEmpty)
                .opacity((selectedVillage == nil || searchId.isEmpty) ? 0.6 : 1.0)
            } else {
                // Result View
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RoR Details")
                                .font(.system(size: 20, weight: .bold))
                            Text("Khata No: \(resultData["khata"] ?? "N/A") | Plot No: \(searchId)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { showResult = false }) {
                            Text("Edit")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.primary)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        RoRDetailRow(label: "Khatiyan Holder", value: resultData["owner"] ?? "Loading...")
                        RoRDetailRow(label: "Area", value: resultData["area"] ?? "Loading...")
                        RoRDetailRow(label: "Land Type", value: resultData["type"] ?? "Loading...")
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    
                    Button(action: {
                        hapticFeedback(.medium)
                        downloadPdf()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Download PDF")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                    }
                    
                    Button(action: {
                        _Concurrency.Task {
                            // Zoom to plot logic
                            _ = try? await viewModel.selectLocation(SearchResult(title: "Plot \(searchId)", subtitle: selectedVillage?.name ?? "", type: .plot(searchId)))
                        }
                    }) {
                        Text("View on Map")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.primary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .sheet(item: $activeSheet) { type in
            switch type {
            case .district:
                SelectionSheet(title: "District", items: districts, searchText: $pickerSearchText) { item in
                    selectedDistrict = item
                    selectedTahasil = nil
                    selectedVillage = nil
                    activeSheet = nil
                    fetchTahasils()
                } onDismiss: { activeSheet = nil }
            case .tahasil:
                SelectionSheet(title: "Tahasil", items: tahasils, searchText: $pickerSearchText) { item in
                    selectedTahasil = item
                    selectedVillage = nil
                    activeSheet = nil
                    fetchVillages()
                } onDismiss: { activeSheet = nil }
            case .village:
                SelectionSheet(title: "Village / Town Area", items: villages, searchText: $pickerSearchText) { item in
                    selectedVillage = item
                    activeSheet = nil
                } onDismiss: { activeSheet = nil }
            }
        }
        .onAppear {
            fetchDistricts()
        }
    }
    
    private func fetchDistricts() {
        guard districts.isEmpty else { return }
        _Concurrency.Task {
            do {
                let url = URL(string: "\(baseUrl)/districts")!
                let (data, _) = try await URLSession.shared.data(from: url)
                districts = try JSONDecoder().decode([SearchItem].self, from: data)
                // Default select Keonjhar if found
                if let kj = districts.first(where: { $0.name.contains("KEONJHAR") }) {
                    selectedDistrict = kj
                    fetchTahasils()
                }
            } catch {
                print("Failed to fetch districts: \(error)")
            }
        }
    }
    
    private func fetchTahasils() {
        guard let d_id = selectedDistrict?.id else { return }
        tahasils = []
        _Concurrency.Task {
            do {
                let url = URL(string: "\(baseUrl)/tahasils?district_id=\(d_id)")!
                let (data, _) = try await URLSession.shared.data(from: url)
                tahasils = try JSONDecoder().decode([SearchItem].self, from: data)
            } catch {
                print("Failed to fetch tahasils: \(error)")
            }
        }
    }
    
    private func fetchVillages() {
        guard let d_id = selectedDistrict?.id, let t_id = selectedTahasil?.id else { return }
        villages = []
        _Concurrency.Task {
            do {
                let url = URL(string: "\(baseUrl)/villages?district_id=\(d_id)&tahasil_id=\(t_id)")!
                let (data, _) = try await URLSession.shared.data(from: url)
                villages = try JSONDecoder().decode([SearchItem].self, from: data)
            } catch {
                print("Failed to fetch villages: \(error)")
            }
        }
    }
    
    private func performActualSearch() {
        guard let d = selectedDistrict, let t = selectedTahasil, let v = selectedVillage else { return }
        isSearching = true
        
        _Concurrency.Task {
            do {
                let urlString = "\(baseUrl)/ror?district=\(d.name)&tahasil=\(t.name)&village=\(v.name)&plot=\(searchId)"
                let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
                let url = URL(string: encoded)!
                
                let (data, _) = try await URLSession.shared.data(from: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let owners = json?["owners"] as? [[String: Any]], let firstOwner = owners.first?["name"] as? String {
                    resultData["owner"] = firstOwner
                }
                resultData["khata"] = json?["khata_number"] as? String ?? "N/A"
                resultData["area"] = json?["area"] as? String ?? "N/A"
                resultData["type"] = json?["land_type"] as? String ?? "N/A"
                
                await MainActor.run {
                    isSearching = false
                    withAnimation { showResult = true }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    viewModel.showToast("Record not found on Bhulekh", icon: "exclamationmark.triangle")
                }
            }
        }
    }
    
    private func downloadPdf() {
        guard let d = selectedDistrict, let t = selectedTahasil, let v = selectedVillage else { return }
        viewModel.showToast("Downloading ROR...", icon: "arrow.down.doc")
        
        // In a real app, you'd use a BackgroundTask or better download manager
        _Concurrency.Task {
            // Simulated delay for UI feedback
            try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                let newItem = MapViewModel.DownloadedROR(
                    filename: "ROR_\(searchId)_\(v.name).pdf",
                    date: formatter.string(from: Date()),
                    details: resultData["area"] ?? "N/A"
                )
                viewModel.downloadedRORs.insert(newItem, at: 0)
                viewModel.showToast("ROR Saved to Downloads", icon: "checkmark.circle.fill")
            }
        }
    }
}

struct RoRDetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
        }
    }
}


struct OfflineMapsView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Offline Maps")
                    .font(.system(size: 20, weight: .bold))
                Text("Download village maps to use them without internet.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                MapFeatureRow(title: "Satellite Cache", description: "Keep recently viewed terrain", icon: "globe.asia.australia.fill", isOn: $viewModel.isSatellite)
                MapFeatureRow(title: "Vector Boundaries", description: "Always show plot outlines", icon: "square.dashed", isOn: $viewModel.showParcels)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(20)
            
            Text("Available for Download")
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 8)
            
            ForEach([
                ("Keonjhar District (Full)", "124 MB"),
                ("Ghatgaon Block", "12 MB"),
                ("Champua Block", "15 MB")
            ], id: \.0) { area, size in
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(area)
                            .font(.system(size: 15, weight: .bold))
                        Text(size)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Download") { hapticFeedback(.medium) }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
            }
        }
    }
}

struct DownloadedRoRView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Downloaded RORs")
                    .font(.system(size: 20, weight: .bold))
                Text("Access your saved land records anytime, even offline.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            if viewModel.downloadedRORs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No downloaded records yet.\nSearch and download an ROR to see it here.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(viewModel.downloadedRORs) { ror in
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "doc.fill")
                                .foregroundColor(.red)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ror.filename)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                            Text("\(ror.date) • \(ror.details)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .onTapGesture {
                        hapticFeedback(.medium)
                        viewModel.showToast("Opening \(ror.filename)", icon: "doc.text")
                    }
                }
            }
        }
    }
}



// MARK: - Helper Components

struct InputField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var icon: String
    var isDisabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.primary)
                    .frame(width: 20)
                
                TextField(placeholder, text: $text)
                    .disabled(isDisabled)
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(16)
            .background(isDisabled ? Color(white: 0.95) : Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
    }
}

struct MapFeatureRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(Theme.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
        }
    }
}

struct ValuationResultRow: View {
    let label: String
    let value: String
    var color: Color = .black
    var isBold: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: isBold ? .bold : .medium))
                .foregroundColor(isBold ? .black : .secondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: isBold ? .bold : .bold))
                .foregroundColor(color)
        }
    }
}
