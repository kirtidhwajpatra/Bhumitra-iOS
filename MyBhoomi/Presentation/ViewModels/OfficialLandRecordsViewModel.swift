import SwiftUI
import Combine

public enum LocationPickerType: String, Identifiable, CaseIterable {
    case district = "District"
    case tahasil = "Tahsil"
    case panchayat = "Panchayat"
    case village = "Village"
    
    public var id: String { rawValue }
}

public enum LandRecordSearchMode: String, CaseIterable, Identifiable {
    case khatian = "Khatian"
    case plot = "Plot"
    
    public var id: String { rawValue }
}

public struct OfficialSearchResult: Identifiable, Equatable {
    public var id: String { "\(plotNumber)_\(khatianNumber)" }
    public let districtID: String
    public let districtName: String
    public let tahasilID: String
    public let tahasilName: String
    public let villageID: String
    public let villageName: String
    public let plotNumber: String
    public let khatianNumber: String
    public let area: String?
    public let ownersCount: Int
    public let associatedPlots: [String]
    public let rawResponse: RoRResponse
    
    public init(
        districtID: String,
        districtName: String,
        tahasilID: String,
        tahasilName: String,
        villageID: String,
        villageName: String,
        plotNumber: String,
        khatianNumber: String,
        area: String?,
        ownersCount: Int,
        associatedPlots: [String],
        rawResponse: RoRResponse
    ) {
        self.districtID = districtID
        self.districtName = districtName
        self.tahasilID = tahasilID
        self.tahasilName = tahasilName
        self.villageID = villageID
        self.villageName = villageName
        self.plotNumber = plotNumber
        self.khatianNumber = khatianNumber
        self.area = area
        self.ownersCount = ownersCount
        self.associatedPlots = associatedPlots
        self.rawResponse = rawResponse
    }
    
    public init(ror: RoRResponse, identity: CanonicalParcelIdentity) {
        let distID = identity.districtID ?? ""
        let distName = !identity.districtName.isEmpty && identity.districtName != "N/A" ? identity.districtName : ror.district
        let tahID = identity.tahasilID ?? ""
        let tahName = !identity.tahasilName.isEmpty && identity.tahasilName != "N/A" ? identity.tahasilName : ror.tahasil
        let villID = identity.villageID ?? ""
        let villName = !identity.villageName.isEmpty && identity.villageName != "N/A" ? identity.villageName : ror.village
        
        self.init(
            districtID: distID,
            districtName: distName,
            tahasilID: tahID,
            tahasilName: tahName,
            villageID: villID,
            villageName: villName,
            plotNumber: ror.plot,
            khatianNumber: ror.khataNumber ?? "N/A",
            area: ror.area,
            ownersCount: ror.owners.count,
            associatedPlots: ror.plots.map { $0.plotNumber },
            rawResponse: ror
        )
    }
}

@MainActor
public final class OfficialLandRecordsViewModel: ObservableObject {
    // MARK: - Selected Entities
    @Published public var selectedDistrict: BhulekhDistrict? = nil
    @Published public var selectedTahasil: BhulekhTahasil? = nil
    @Published public var selectedPanchayat: CadastralGP? = nil
    @Published public var selectedVillage: BhulekhVillage? = nil
    
    // MARK: - Inline Expansion State (Only 1 expanded at a time)
    @Published public var expandedCard: LocationPickerType? = nil
    
    // MARK: - Per-Card Search Query Filters
    @Published public var districtSearchText: String = ""
    @Published public var tahasilSearchText: String = ""
    @Published public var panchayatSearchText: String = ""
    @Published public var villageSearchText: String = ""
    
    // MARK: - Plots Section Visibility
    @Published public var isPlotsSectionVisible: Bool = false
    
    // MARK: - Search Mode & Inputs
    @Published public var searchMode: LandRecordSearchMode = .plot {
        didSet {
            searchQuery = ""
            searchResults = []
            searchError = nil
            isNoRecordFound = false
            searchedQuery = ""
        }
    }
    @Published public var searchQuery: String = ""
    @Published public var searchedQuery: String = ""
    @Published public var isSearching: Bool = false
    @Published public var searchError: String? = nil
    @Published public var isNoRecordFound: Bool = false
    @Published public var searchResults: [OfficialSearchResult] = []
    
    // MARK: - Lists & Loading States
    @Published public var districts: [BhulekhDistrict] = []
    @Published public var tahasils: [BhulekhTahasil] = []
    @Published public var panchayats: [CadastralGP] = []
    @Published public var villages: [BhulekhVillage] = []
    
    @Published public var isLoadingDistricts = false
    @Published public var isLoadingTahasils = false
    @Published public var isLoadingPanchayats = false
    @Published public var isLoadingVillages = false
    
    @Published public var districtError: String? = nil
    @Published public var tahasilError: String? = nil
    @Published public var panchayatError: String? = nil
    @Published public var villageError: String? = nil
    
    // MARK: - Local In-Memory Caches
    private var tahasilCache: [String: [BhulekhTahasil]] = [:]
    private var gpCache: [String: [CadastralGP]] = [:]
    private var villageCache: [String: [BhulekhVillage]] = [:]
    
    public init() {
        loadDistricts()
    }
    
    public var isSelectionComplete: Bool {
        selectedDistrict != nil && selectedTahasil != nil && selectedVillage != nil
    }
    
    // MARK: - Local Search Filters
    public var filteredDistricts: [BhulekhDistrict] {
        let query = districtSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return districts }
        return districts.filter {
            $0.officialName.lowercased().contains(query) || $0.id.contains(query)
        }
    }
    
    public var filteredTahasils: [BhulekhTahasil] {
        let query = tahasilSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return tahasils }
        return tahasils.filter {
            $0.officialName.lowercased().contains(query) || $0.id.contains(query)
        }
    }
    
    public var filteredPanchayats: [CadastralGP] {
        let query = panchayatSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return panchayats }
        return panchayats.filter {
            $0.name.lowercased().contains(query) || $0.id.contains(query)
        }
    }
    
    public var filteredVillages: [BhulekhVillage] {
        var list = villages
        if let gp = selectedPanchayat, !gp.name.isEmpty {
            let gpQuery = gp.name.lowercased()
            let matched = list.filter { $0.officialName.lowercased().contains(gpQuery) }
            if !matched.isEmpty {
                list = matched
            }
        }
        let query = villageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return list }
        return list.filter {
            $0.officialName.lowercased().contains(query) || $0.id.contains(query)
        }
    }
    
    // MARK: - Expansion Toggle
    public func toggleExpansion(for type: LocationPickerType) {
        if expandedCard == type {
            expandedCard = nil
        } else {
            expandedCard = type
        }
    }
    
    // MARK: - Loading Districts
    public func loadDistricts() {
        guard districts.isEmpty else { return }
        isLoadingDistricts = true
        districtError = nil
        
        _Concurrency.Task {
            do {
                let list = try await RoRService.shared.fetchDistricts()
                await MainActor.run {
                    self.districts = list
                    self.isLoadingDistricts = false
                }
            } catch {
                await MainActor.run {
                    self.districtError = "Couldn't load districts"
                    self.isLoadingDistricts = false
                }
            }
        }
    }
    
    // MARK: - Loading Tahasils
    public func loadTahasils(for districtID: String) {
        if let cached = tahasilCache[districtID] {
            self.tahasils = cached
            return
        }
        
        isLoadingTahasils = true
        tahasilError = nil
        
        _Concurrency.Task {
            do {
                let list = try await RoRService.shared.fetchTahasils(districtID: districtID)
                await MainActor.run {
                    self.tahasilCache[districtID] = list
                    self.tahasils = list
                    self.isLoadingTahasils = false
                }
            } catch {
                await MainActor.run {
                    self.tahasilError = "Couldn't load tahasils"
                    self.isLoadingTahasils = false
                }
            }
        }
    }
    
    // MARK: - Loading Gram Panchayats
    public func loadPanchayats(districtID: String, tahasilID: String) {
        let blockCode = String(format: "%02d%02d", Int(districtID) ?? 0, Int(tahasilID) ?? 0)
        if let cached = gpCache[blockCode] {
            self.panchayats = cached
            return
        }
        
        isLoadingPanchayats = true
        panchayatError = nil
        
        _Concurrency.Task {
            do {
                let list = try await CadastralAPIClient.shared.fetchGPs(blockID: blockCode)
                await MainActor.run {
                    self.gpCache[blockCode] = list
                    self.panchayats = list
                    self.isLoadingPanchayats = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingPanchayats = false
                }
            }
        }
    }
    
    // MARK: - Loading Villages
    public func loadVillages(districtID: String, tahasilID: String) {
        let cacheKey = "\(districtID)_\(tahasilID)"
        if let cached = villageCache[cacheKey] {
            self.villages = cached
            return
        }
        
        isLoadingVillages = true
        villageError = nil
        
        _Concurrency.Task {
            do {
                let list = try await RoRService.shared.fetchVillages(districtID: districtID, tahasilID: tahasilID)
                await MainActor.run {
                    self.villageCache[cacheKey] = list
                    self.villages = list
                    self.isLoadingVillages = false
                }
            } catch {
                await MainActor.run {
                    self.villageError = "Couldn't load villages"
                    self.isLoadingVillages = false
                }
            }
        }
    }
    
    // MARK: - Selection Handlers with Strict Cascading Invalidation
    public func selectDistrict(_ district: BhulekhDistrict) {
        if selectedDistrict?.id != district.id {
            selectedDistrict = district
            selectedTahasil = nil
            selectedPanchayat = nil
            selectedVillage = nil
            expandedCard = nil
            districtSearchText = ""
            tahasilSearchText = ""
            panchayatSearchText = ""
            villageSearchText = ""
            tahasils = []
            panchayats = []
            villages = []
            isPlotsSectionVisible = false
            resetSearchResults()
            loadTahasils(for: district.id)
        } else {
            expandedCard = nil
        }
    }
    
    public func selectTahasil(_ tahasil: BhulekhTahasil) {
        if selectedTahasil?.id != tahasil.id {
            selectedTahasil = tahasil
            selectedPanchayat = nil
            selectedVillage = nil
            expandedCard = nil
            tahasilSearchText = ""
            panchayatSearchText = ""
            villageSearchText = ""
            panchayats = []
            villages = []
            isPlotsSectionVisible = false
            resetSearchResults()
            if let d = selectedDistrict {
                loadPanchayats(districtID: d.id, tahasilID: tahasil.id)
                loadVillages(districtID: d.id, tahasilID: tahasil.id)
            }
        } else {
            expandedCard = nil
        }
    }
    
    public func selectPanchayat(_ gp: CadastralGP) {
        selectedPanchayat = gp
        selectedVillage = nil
        expandedCard = nil
        panchayatSearchText = ""
        villageSearchText = ""
        resetSearchResults()
    }
    
    public func selectVillage(_ village: BhulekhVillage) {
        selectedVillage = village
        expandedCard = nil
        villageSearchText = ""
        resetSearchResults()
    }
    
    public func resetAll() {
        selectedDistrict = nil
        selectedTahasil = nil
        selectedPanchayat = nil
        selectedVillage = nil
        expandedCard = nil
        districtSearchText = ""
        tahasilSearchText = ""
        panchayatSearchText = ""
        villageSearchText = ""
        isPlotsSectionVisible = false
        tahasils = []
        panchayats = []
        villages = []
        resetSearchResults()
        loadDistricts()
    }
    
    public func resetSearchResults() {
        searchQuery = ""
        searchedQuery = ""
        searchResults = []
        searchError = nil
        isNoRecordFound = false
    }
    
    // MARK: - Execute Official Search
    public func executeSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        guard let d = selectedDistrict, let t = selectedTahasil, let v = selectedVillage else { return }
        
        isSearching = true
        searchError = nil
        isNoRecordFound = false
        searchResults = []
        searchedQuery = query
        
        _Concurrency.Task {
            do {
                let ror = try await RoRService.shared.fetch(
                    district: d.officialName,
                    tahasil: t.officialName,
                    village: v.officialName,
                    plot: query,
                    bId: t.id,
                    vId: v.id
                )
                
                await MainActor.run {
                    self.isSearching = false
                    let res = OfficialSearchResult(
                        districtID: d.id,
                        districtName: d.officialName,
                        tahasilID: t.id,
                        tahasilName: t.officialName,
                        villageID: v.id,
                        villageName: v.officialName,
                        plotNumber: ror.plot,
                        khatianNumber: ror.khataNumber ?? "N/A",
                        area: ror.area,
                        ownersCount: ror.owners.count,
                        associatedPlots: ror.plots.map { $0.plotNumber },
                        rawResponse: ror
                    )
                    self.searchResults = [res]
                }
            } catch let rorError as RoRError {
                await MainActor.run {
                    self.isSearching = false
                    switch rorError {
                    case .notFound, .identityMismatch:
                        self.isNoRecordFound = true
                    case .timeout:
                        self.searchError = "The official portal took too long to respond."
                    case .temporarilyUnavailable:
                        self.searchError = "Official land records are temporarily unavailable."
                    case .networkError:
                        self.searchError = "Couldn't connect to official land records."
                    case .serverError:
                        self.searchError = "Couldn't load official land records."
                    default:
                        self.searchError = rorError.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    self.searchError = "Couldn't connect to official land records."
                }
            }
        }
    }
}
