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
        self.villageName = villageName
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
        self.villageName = identity.villageName ?? ror.village
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
    
    // MARK: - Loading Districts
    public func loadDistricts(force: Bool = false) {
        if !force && !districts.isEmpty { return }
        isLoadingDistricts = true
        districtError = nil
        
        _Concurrency.Task {
            do {
                let list = try await CadastralRepository.shared.getDistricts()
                await MainActor.run {
                    self.districts = list
                    self.isLoadingDistricts = false
                    self.districtError = nil
                }
            } catch {
                await MainActor.run {
                    self.districtError = "Couldn't load districts: \(error.localizedDescription)"
                    self.isLoadingDistricts = false
                }
            }
        }
    }
    
    // MARK: - Loading Tahasils / Blocks
    public func loadTahasils(for districtID: String) {
        if let cached = tahasilCache[districtID] {
            self.tahasils = cached
            return
        }
        
        isLoadingTahasils = true
        tahasilError = nil
        
        _Concurrency.Task {
            do {
                let list = try await CadastralRepository.shared.getBlocks(districtID: districtID)
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
    public func loadPanchayats(blockID: String) {
        if let cached = gpCache[blockID] {
            self.panchayats = cached
            return
        }
        
        isLoadingPanchayats = true
        panchayatError = nil
        
        _Concurrency.Task {
            do {
                let list = try await CadastralRepository.shared.getGPs(blockID: blockID)
                await MainActor.run {
                    self.gpCache[blockID] = list
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
    public func loadVillages(blockID: String, gpID: String? = nil) {
        let cacheKey = "\(blockID)_\(gpID ?? "all")"
        if let cached = villageCache[cacheKey] {
            self.villages = cached
            return
        }
        
        isLoadingVillages = true
        villageError = nil
        
        _Concurrency.Task {
            do {
                let list = try await CadastralRepository.shared.getVillages(blockID: blockID, gpID: gpID)
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
