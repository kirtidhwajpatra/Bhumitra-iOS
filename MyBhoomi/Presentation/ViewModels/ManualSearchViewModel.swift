import Foundation
import SwiftUI
import Combine

public enum ManualSearchMode: String, CaseIterable, Identifiable {
    case plot = "Plot Number"
    case khata = "Khata / Khatiyan Number"
    case tenant = "Tenant / Raiyat Name"
    
    public var id: String { rawValue }
    
    public var placeholder: String {
        switch self {
        case .plot: return "Enter plot number (e.g. 1182)"
        case .khata: return "Enter khata number (e.g. 142)"
        case .tenant: return "Enter tenant name"
        }
    }
    
    public var icon: String {
        switch self {
        case .plot: return "map"
        case .khata: return "doc.text.fill"
        case .tenant: return "person.fill"
        }
    }
}

public enum ManualSearchState: Equatable {
    case idle
    case loading
    case success(RoRResponse, ParcelVerificationResult)
    case unverified(ParcelVerificationResult)
    case error(String)
}

@MainActor
public final class ManualSearchViewModel: ObservableObject {
    @Published public var districts: [BhulekhDistrict] = []
    @Published public var tahasils: [BhulekhTahasil] = []
    @Published public var villages: [BhulekhVillage] = []
    
    @Published public var isLoadingDistricts: Bool = false
    @Published public var isLoadingTahasils: Bool = false
    @Published public var isLoadingVillages: Bool = false
    
    @Published public var districtError: String? = nil
    @Published public var tahasilError: String? = nil
    @Published public var villageError: String? = nil
    
    @Published public var selectedDistrict: BhulekhDistrict? = nil {
        didSet {
            if oldValue?.id != selectedDistrict?.id {
                tahasils = []
                selectedTahasil = nil
                villages = []
                selectedVillage = nil
                state = .idle
                downloadedPDFURL = nil
                if let d = selectedDistrict {
                    loadTahasils(for: d.id)
                }
            }
        }
    }
    
    @Published public var selectedTahasil: BhulekhTahasil? = nil {
        didSet {
            if oldValue?.id != selectedTahasil?.id {
                villages = []
                selectedVillage = nil
                state = .idle
                downloadedPDFURL = nil
                if let d = selectedDistrict, let t = selectedTahasil {
                    loadVillages(districtID: d.id, tahasilID: t.id)
                }
            }
        }
    }
    
    @Published public var selectedVillage: BhulekhVillage? = nil {
        didSet {
            if oldValue?.id != selectedVillage?.id {
                state = .idle
                downloadedPDFURL = nil
            }
        }
    }
    
    @Published public var searchMode: ManualSearchMode = .plot
    @Published public var searchValue: String = ""
    @Published public var state: ManualSearchState = .idle
    @Published public var isDownloadingPDF: Bool = false
    @Published public var downloadedPDFURL: URL? = nil
    
    public init() {
        loadDistricts()
    }
    
    // MARK: - Loading Hierarchy
    
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
                    self.districtError = "Unable to load districts: \(error.localizedDescription)"
                    self.isLoadingDistricts = false
                }
            }
        }
    }
    
    public func loadTahasils(for districtID: String) {
        isLoadingTahasils = true
        tahasilError = nil
        
        _Concurrency.Task {
            do {
                let list = try await RoRService.shared.fetchTahasils(districtID: districtID)
                await MainActor.run {
                    self.tahasils = list
                    self.isLoadingTahasils = false
                }
            } catch {
                await MainActor.run {
                    self.tahasilError = "Unable to load tahasils: \(error.localizedDescription)"
                    self.isLoadingTahasils = false
                }
            }
        }
    }
    
    public func loadVillages(districtID: String, tahasilID: String) {
        isLoadingVillages = true
        villageError = nil
        
        _Concurrency.Task {
            do {
                let list = try await RoRService.shared.fetchVillages(districtID: districtID, tahasilID: tahasilID)
                await MainActor.run {
                    self.villages = list
                    self.isLoadingVillages = false
                }
            } catch {
                await MainActor.run {
                    self.villageError = "Unable to load villages: \(error.localizedDescription)"
                    self.isLoadingVillages = false
                }
            }
        }
    }
    
    // MARK: - Perform Manual Search
    
    public var isFormComplete: Bool {
        selectedDistrict != nil && selectedTahasil != nil && selectedVillage != nil && !searchValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public func performSearch() {
        guard let d = selectedDistrict, let t = selectedTahasil, let v = selectedVillage else { return }
        let cleanVal = searchValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanVal.isEmpty else { return }
        
        state = .loading
        downloadedPDFURL = nil
        
        _Concurrency.Task {
            do {
                // Construct a canonical parcel identity for verification
                let identity = CanonicalParcelIdentity(
                    parcelID: nil,
                    plotNumber: cleanVal,
                    districtName: d.officialName,
                    districtID: d.id,
                    tahasilName: t.officialName,
                    tahasilID: t.id,
                    villageName: v.officialName,
                    villageID: v.id
                )
                
                let parcel = Parcel(
                    id: identity.parcelID,
                    boundary: [],
                    metadata: ParcelMetadata(identity: identity, estimatedAreaAcre: nil)
                )
                
                let ror = try await RoRService.shared.fetchOwnerDetails(for: parcel)
                let verif = ParcelCrossVerifier.verify(
                    gisIdentity: identity,
                    rorResponse: ror,
                    gisAreaInAcre: nil
                )
                
                await MainActor.run {
                    if verif.isVerified {
                        self.state = .success(ror, verif)
                    } else {
                        self.state = .unverified(verif)
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    public func downloadPDF() {
        guard case .success(let ror, _) = state,
              let d = selectedDistrict, let t = selectedTahasil, let v = selectedVillage else { return }
        
        isDownloadingPDF = true
        
        _Concurrency.Task {
            do {
                let identity = CanonicalParcelIdentity(
                    parcelID: nil,
                    plotNumber: ror.plot,
                    districtName: d.officialName,
                    districtID: d.id,
                    tahasilName: t.officialName,
                    tahasilID: t.id,
                    villageName: v.officialName,
                    villageID: v.id
                )
                let parcel = Parcel(
                    id: identity.parcelID,
                    boundary: [],
                    metadata: ParcelMetadata(identity: identity, estimatedAreaAcre: nil)
                )
                let url = try await RoRService.shared.downloadROR(for: parcel)
                await MainActor.run {
                    self.downloadedPDFURL = url
                    self.isDownloadingPDF = false
                }
            } catch {
                await MainActor.run {
                    self.isDownloadingPDF = false
                }
            }
        }
    }
}
