import SwiftUI
import Combine

public enum LocationPickerType: String, CaseIterable, Identifiable {
    case district = "District"
    case tahasil = "Tahsil"
    case panchayat = "Panchayat"
    case village = "Village"
    
    public var id: String { rawValue }
}

public struct OfficialSearchResult: Identifiable, Hashable, Equatable {
    public let id = UUID()
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
        self.villageName = VillageNameSanitizer.sanitize(villageName)
        self.plotNumber = plotNumber
        self.khatianNumber = khatianNumber
        self.area = area
        self.ownersCount = ownersCount
        self.associatedPlots = associatedPlots
        self.rawResponse = rawResponse
    }
    
    public init(ror: RoRResponse, identity: CanonicalParcelIdentity) {
        self.districtID = identity.districtID ?? ""
        self.districtName = identity.districtName ?? ror.district
        self.tahasilID = identity.tahasilID ?? ""
        self.tahasilName = identity.tahasilName ?? ror.tahasil
        self.villageID = identity.villageID ?? ""
        self.villageName = VillageNameSanitizer.sanitize(identity.villageName ?? ror.village)
        self.plotNumber = ror.plot.isEmpty ? identity.plotNumber : ror.plot
        self.khatianNumber = ror.khataNumber ?? "N/A"
        self.area = ror.area
        self.ownersCount = ror.owners.count
        self.associatedPlots = ror.plots.map { $0.plotNumber }
        self.rawResponse = ror
    }
    
    public var landClassificationStatus: LandClassificationStatus {
        CachedVerifiedParcel.determineLandClassification(
            landType: rawResponse.landType,
            tenure: rawResponse.rawFields?["tenure"],
            owners: rawResponse.owners
        )
    }
    
    public var resolutionStatus: ParcelResolutionStatus {
        if rawResponse.verification?.status == .verified || rawResponse.success {
            return .verified
        }
        return .unresolved
    }
    
    public var isGovernmentLand: Bool {
        resolutionStatus == .verified && landClassificationStatus == .verifiedGovernment
    }
    
    public var isPrivateLand: Bool {
        resolutionStatus == .verified && landClassificationStatus == .verifiedPrivate
    }
    
    public static func == (lhs: OfficialSearchResult, rhs: OfficialSearchResult) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Unified ViewModel for Official Land Records location selection.
/// Directly powered by CadastralRepository & Odisha GIS for instant map plot rendering and RoR lookup.
public final class OfficialLandRecordsViewModel: ObservableObject {
    // MARK: - Selected Administrative State
    @Published public var selectedDistrict: CadastralDistrict? = nil
    @Published public var selectedTahasil: CadastralBlock? = nil
    @Published public var selectedPanchayat: CadastralGP? = nil
    @Published public var selectedVillage: CadastralVillage? = nil
    
    // MARK: - Lists for Selection
    @Published public var districts: [CadastralDistrict] = []
    @Published public var tahasils: [CadastralBlock] = []
    @Published public var panchayats: [CadastralGP] = []
    @Published public var villages: [CadastralVillage] = []
    
    // MARK: - Search Filtering
    @Published public var districtSearchText: String = ""
    @Published public var tahasilSearchText: String = ""
    @Published public var panchayatSearchText: String = ""
    @Published public var villageSearchText: String = ""
    
    // MARK: - Loading & Error States
    @Published public var isLoadingDistricts: Bool = false
    @Published public var isLoadingTahasils: Bool = false
    @Published public var isLoadingPanchayats: Bool = false
    @Published public var isLoadingVillages: Bool = false
    
    @Published public var districtError: String? = nil
    @Published public var tahasilError: String? = nil
    @Published public var panchayatError: String? = nil
    @Published public var villageError: String? = nil
    
    // MARK: - UI Expansion State
    @Published public var expandedCard: LocationPickerType? = nil
    
    // MARK: - In-Flight Task Tracking (Race-Condition Guard)
    private var districtsTask: _Concurrency.Task<Void, Never>? = nil
    private var tahasilsTask: _Concurrency.Task<Void, Never>? = nil
    private var panchayatsTask: _Concurrency.Task<Void, Never>? = nil
    private var villagesTask: _Concurrency.Task<Void, Never>? = nil

    // MARK: - In-Memory Caches
    private var tahasilCache: [String: [CadastralBlock]] = [:]
    private var gpCache: [String: [CadastralGP]] = [:]
    private var villageCache: [String: [CadastralVillage]] = [:]
    
    public init() {
        loadDistricts()
    }
    
    public var isSelectionComplete: Bool {
        selectedDistrict != nil && selectedTahasil != nil && selectedVillage != nil
    }
    
    // MARK: - Local Search Filters
    public var filteredDistricts: [CadastralDistrict] {
        let query = districtSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return districts }
        return districts.filter {
            $0.name.lowercased().contains(query) || $0.id.contains(query)
        }
    }
    
    public var filteredTahasils: [CadastralBlock] {
        let query = tahasilSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return tahasils }
        return tahasils.filter {
            $0.name.lowercased().contains(query) || $0.id.contains(query)
        }
    }
    
    public var filteredPanchayats: [CadastralGP] {
        let query = panchayatSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return panchayats }
        return panchayats.filter {
            $0.name.lowercased().contains(query) || $0.id.contains(query)
        }
    }
    
    public var filteredVillages: [CadastralVillage] {
        let query = villageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return villages }
        return villages.filter {
            $0.name.lowercased().contains(query) || $0.id.contains(query)
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
    
    public var currentState: String = "ODISHA"
    
    public func resetForState(_ state: String) {
        let norm = state.uppercased()
        districtsTask?.cancel()
        tahasilsTask?.cancel()
        panchayatsTask?.cancel()
        villagesTask?.cancel()
        
        currentState = norm
        selectedDistrict = nil
        selectedTahasil = nil
        selectedPanchayat = nil
        selectedVillage = nil
        districts = []
        tahasils = []
        panchayats = []
        villages = []
        districtError = nil
        tahasilError = nil
        panchayatError = nil
        villageError = nil
        expandedCard = nil
        districtSearchText = ""
        tahasilSearchText = ""
        panchayatSearchText = ""
        villageSearchText = ""
        
        loadDistricts(force: true)
    }
    
    // MARK: - Loading Districts
    public func loadDistricts(force: Bool = false) {
        if !force && !districts.isEmpty { return }
        districtsTask?.cancel()
        isLoadingDistricts = true
        districtError = nil
        let state = currentState
        
        districtsTask = _Concurrency.Task { [weak self] in
            do {
                let list = try await CadastralRepository.shared.getDistricts(state: state, forceRefresh: force)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.districts = list
                    self?.isLoadingDistricts = false
                    self?.districtError = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.districtError = "Couldn't load districts"
                    self?.isLoadingDistricts = false
                }
            }
        }
    }
    
    // MARK: - Loading Tahasils / Blocks
    public func loadTahasils(for districtID: String) {
        print("[ViewModel Trace] 🔍 loadTahasils() called for districtID: '\(districtID)'")
        tahasilsTask?.cancel()
        let state = currentState
        let cacheKey = "\(state)_\(districtID)"
        
        if let cached = tahasilCache[cacheKey] {
            print("[ViewModel Trace] ⚡️ loadTahasils cache hit for districtID '\(districtID)': \(cached.count) tahasils")
            self.tahasils = cached
            self.isLoadingTahasils = false
            self.tahasilError = nil
            return
        }
        
        isLoadingTahasils = true
        tahasilError = nil
        
        tahasilsTask = _Concurrency.Task { [weak self] in
            do {
                let list = try await CadastralRepository.shared.getBlocks(districtID: districtID, state: state)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self = self, self.selectedDistrict?.id == districtID else { return }
                    print("[ViewModel Trace] 📥 loadTahasils assigned \(list.count) tahasils to @Published tahasils")
                    self.tahasilCache[cacheKey] = list
                    self.tahasils = list
                    self.isLoadingTahasils = false
                    self.tahasilError = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self = self, self.selectedDistrict?.id == districtID else { return }
                    print("[ViewModel Trace] ❌ loadTahasils failed: \(error.localizedDescription) (error: \(error))")
                    self.tahasilError = "Couldn't load tahsils"
                    self.isLoadingTahasils = false
                }
            }
        }
    }
    
    // MARK: - Loading Gram Panchayats
    public func loadPanchayats(blockID: String) {
        panchayatsTask?.cancel()
        let state = currentState
        let cacheKey = "\(state)_\(blockID)"
        
        if let cached = gpCache[cacheKey] {
            self.panchayats = cached
            self.isLoadingPanchayats = false
            self.panchayatError = nil
            return
        }
        
        isLoadingPanchayats = true
        panchayatError = nil
        
        panchayatsTask = _Concurrency.Task { [weak self] in
            do {
                let list = try await CadastralRepository.shared.getGPs(blockID: blockID, state: state)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self = self, self.selectedTahasil?.id == blockID else { return }
                    self.gpCache[cacheKey] = list
                    self.panchayats = list
                    self.isLoadingPanchayats = false
                    self.panchayatError = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self = self, self.selectedTahasil?.id == blockID else { return }
                    self.panchayatError = "Couldn't load panchayats"
                    self.isLoadingPanchayats = false
                }
            }
        }
    }
    
    // MARK: - Loading Villages
    public func loadVillages(blockID: String, gpID: String? = nil) {
        villagesTask?.cancel()
        let state = currentState
        let cacheKey = "\(state)_\(blockID)_\(gpID ?? "all")"
        if let cached = villageCache[cacheKey] {
            self.villages = cached
            self.isLoadingVillages = false
            self.villageError = nil
            return
        }
        
        isLoadingVillages = true
        villageError = nil
        
        villagesTask = _Concurrency.Task { [weak self] in
            do {
                let list = try await CadastralRepository.shared.getVillages(blockID: blockID, gpID: gpID, state: state)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self = self, self.selectedTahasil?.id == blockID else { return }
                    if let currentGP = self.selectedPanchayat, let reqGP = gpID, currentGP.id != reqGP {
                        return
                    }
                    self.villageCache[cacheKey] = list
                    self.villages = list
                    self.isLoadingVillages = false
                    self.villageError = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self = self, self.selectedTahasil?.id == blockID else { return }
                    self.villageError = "Couldn't load villages"
                    self.isLoadingVillages = false
                }
            }
        }
    }
    
    // MARK: - Selection Handlers with Strict Cascading Invalidation
    public func selectDistrict(_ district: CadastralDistrict) {
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
            loadTahasils(for: district.id)
        } else {
            expandedCard = nil
        }
    }
    
    public func selectTahasil(_ tahasil: CadastralBlock) {
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
            loadPanchayats(blockID: tahasil.id)
            loadVillages(blockID: tahasil.id)
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
        if let t = selectedTahasil {
            loadVillages(blockID: t.id, gpID: gp.id)
        }
    }
    
    public func selectVillage(_ village: CadastralVillage) {
        var enriched = village
        if enriched.districtName == nil || enriched.districtName?.isEmpty == true {
            enriched = CadastralVillage(
                id: village.id,
                name: village.name,
                gpID: village.gpID,
                blockID: village.blockID,
                districtID: selectedDistrict?.id ?? village.districtID,
                blockName: selectedTahasil?.name ?? village.blockName,
                districtName: selectedDistrict?.name ?? village.districtName
            )
        }
        selectedVillage = enriched
        expandedCard = nil
        villageSearchText = ""
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
        tahasils = []
        panchayats = []
        villages = []
        loadDistricts()
    }
}
