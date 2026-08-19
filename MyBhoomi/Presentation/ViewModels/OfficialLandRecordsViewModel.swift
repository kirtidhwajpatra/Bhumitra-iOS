import SwiftUI
import Combine

public enum LocationPickerType: String, Identifiable {
    case district = "District"
    case tahasil = "Tahasil"
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
}

@MainActor
public final class OfficialLandRecordsViewModel: ObservableObject {
    // MARK: - Selected Entities
    @Published public var selectedDistrict: BhulekhDistrict? = nil
    @Published public var selectedTahasil: BhulekhTahasil? = nil
    @Published public var selectedVillage: BhulekhVillage? = nil
    
    // MARK: - Active Picker Sheet
    @Published public var activePicker: LocationPickerType? = nil
    
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
    @Published public var villages: [BhulekhVillage] = []
    
    @Published public var isLoadingDistricts = false
    @Published public var isLoadingTahasils = false
    @Published public var isLoadingVillages = false
    
    @Published public var districtError: String? = nil
    @Published public var tahasilError: String? = nil
    @Published public var villageError: String? = nil
    
    // MARK: - Local Caches
    private var tahasilCache: [String: [BhulekhTahasil]] = [:]
    private var villageCache: [String: [BhulekhVillage]] = [:]
    
    public init() {
        loadDistricts()
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
    
    // MARK: - Selection Handlers with Strict Dependency Reset
    public func selectDistrict(_ district: BhulekhDistrict) {
        if selectedDistrict?.id != district.id {
            selectedDistrict = district
            selectedTahasil = nil
            selectedVillage = nil
            tahasils = []
            villages = []
            resetSearchResults()
            loadTahasils(for: district.id)
        }
    }
    
    public func selectTahasil(_ tahasil: BhulekhTahasil) {
        if selectedTahasil?.id != tahasil.id {
            selectedTahasil = tahasil
            selectedVillage = nil
            villages = []
            resetSearchResults()
            if let d = selectedDistrict {
                loadVillages(districtID: d.id, tahasilID: tahasil.id)
            }
        }
    }
    
    public func selectVillage(_ village: BhulekhVillage) {
        if selectedVillage?.id != village.id {
            selectedVillage = village
            resetSearchResults()
        }
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
                    case .timeout, .temporarilyUnavailable, .serverError, .networkError:
                        self.searchError = "Couldn't load land records"
                    default:
                        self.searchError = rorError.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    self.searchError = "Couldn't load land records"
                }
            }
        }
    }
}
