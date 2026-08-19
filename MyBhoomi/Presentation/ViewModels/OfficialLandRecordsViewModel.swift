import SwiftUI
import Combine

public enum LocationPickerType: String, Identifiable {
    case district = "District"
    case tahasil = "Tahasil"
    case village = "Village"
    
    public var id: String { rawValue }
}

@MainActor
public final class OfficialLandRecordsViewModel: ObservableObject {
    // MARK: - Selected Entities
    @Published public var selectedDistrict: BhulekhDistrict? = nil
    @Published public var selectedTahasil: BhulekhTahasil? = nil
    @Published public var selectedVillage: BhulekhVillage? = nil
    
    // MARK: - Active Picker Sheet
    @Published public var activePicker: LocationPickerType? = nil
    
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
            loadTahasils(for: district.id)
        }
    }
    
    public func selectTahasil(_ tahasil: BhulekhTahasil) {
        if selectedTahasil?.id != tahasil.id {
            selectedTahasil = tahasil
            selectedVillage = nil
            villages = []
            if let d = selectedDistrict {
                loadVillages(districtID: d.id, tahasilID: tahasil.id)
            }
        }
    }
    
    public func selectVillage(_ village: BhulekhVillage) {
        selectedVillage = village
    }
}
