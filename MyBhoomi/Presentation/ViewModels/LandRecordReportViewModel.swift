//
//  LandRecordReportViewModel.swift
//  MyBhoomi
//
//  Independent Asynchronous ViewModel for LandRecordReportView.
//  Orchestrates fail-soft, isolated parallel data fetching across RoR, IGR, and Location services.
//

import SwiftUI
import CoreLocation
import Combine
import UIKit

@MainActor
public final class LandRecordReportViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var report: LandDetailsReport
    @Published public var isLoadingRoR: Bool = false
    @Published public var isLoadingValuation: Bool = false
    @Published public var isDownloadingPDF: Bool = false
    @Published public var pdfURL: URL? = nil
    @Published public var errorMessage: String? = nil
    @Published public var showShareSheet: Bool = false
    @Published public var shareItems: [Any] = []
    @Published public var showPDFViewer: Bool = false
    
    // User-assisted valuation & stamp duty inputs
    @Published public var valuationCandidates: [IGRValuationCandidate] = []
    @Published public var selectedCandidate: IGRValuationCandidate? = nil
    @Published public var isUserAssistedValuation: Bool = false
    @Published public var customAreaInput: Double? = nil
    @Published public var customUnitInput: String = "Decimal"
    @Published public var customConsiderationInput: Double? = nil
    @Published public var customBuyerCategoryInput: BuyerCategoryOption = .standard
    @Published public var customDeedIdInput: Int = 1
    
    // Identity context
    public let identity: CanonicalParcelIdentity
    public let parcel: Parcel?
    private var initialRoR: RoRResponse?

    /// True when the server returned a masked zero-credit preview instead of
    /// the full record. The UI must then show the locked teaser, never the
    /// (masked) report fields.
    public var isPreviewRecord: Bool {
        guard let ror = initialRoR else { return false }
        return ror.isPreview || ror.isLocked
    }

    /// Real number of owner entries on record (counts are not masked by the
    /// server preview; names are). Nil until the record has loaded.
    public var recordOwnerCount: Int? {
        guard let ror = initialRoR else { return nil }
        return ror.owners.count
    }
    private var initialValuation: BenchmarkValuation?
    private var geocodedPlacemark: CLPlacemark?
    
    // Dependencies
    private let rorService = RoRService.shared
    private let benchmarkService = BenchmarkValuationService.shared
    private let registrationCostService = RegistrationCostService.shared
    private let pdfService = OfficialRoRPDFService.shared
    private let savedLandManager = SavedLandManager.shared
    
    // MARK: - Initializers
    
    public init(parcel: Parcel) {
        self.parcel = parcel
        self.identity = parcel.identity
        self.initialRoR = nil
        self.initialValuation = nil
        
        self.report = LandDetailsReportBuilder.build(
            identity: parcel.identity,
            rorResponse: nil,
            benchmarkValuation: nil,
            parcel: parcel,
            rorLoadingState: .loading,
            valuationLoadingState: .loading,
            locationLoadingState: .loading
        )
    }
    
    public init(result: OfficialSearchResult, parcel: Parcel? = nil) {
        self.parcel = parcel
        self.identity = CanonicalParcelIdentity(
            parcelID: nil,
            plotNumber: result.plotNumber,
            districtName: result.districtName,
            districtID: result.districtID,
            tahasilName: result.tahasilName,
            tahasilID: result.tahasilID,
            villageName: result.villageName,
            villageID: result.villageID
        )
        self.initialRoR = result.rawResponse
        self.initialValuation = nil
        
        self.report = LandDetailsReportBuilder.build(
            identity: self.identity,
            rorResponse: result.rawResponse,
            benchmarkValuation: nil,
            parcel: parcel,
            rorLoadingState: .loaded,
            valuationLoadingState: .loading,
            locationLoadingState: .loading
        )
    }
    
    public init(identity: CanonicalParcelIdentity, ror: RoRResponse?, valuation: BenchmarkValuation? = nil, parcel: Parcel? = nil) {
        self.parcel = parcel
        self.identity = identity
        self.initialRoR = ror
        self.initialValuation = valuation
        
        self.report = LandDetailsReportBuilder.build(
            identity: identity,
            rorResponse: ror,
            benchmarkValuation: valuation,
            parcel: parcel,
            rorLoadingState: ror != nil ? .loaded : .loading,
            valuationLoadingState: valuation != nil ? .loaded : .loading,
            locationLoadingState: .loading
        )
    }
    
    // MARK: - Lifecycle & Loading
    
    public func loadData() async {
        // Run parallel independent tasks so slow or failing secondary services never block RoR
        async let rorTask: Void = fetchRoRIfNeeded()
        async let valTask: Void = fetchValuationIfNeeded()
        async let locTask: Void = fetchGeocodedPostal()
        async let pdfTask: Void = checkCachedPDF()
        
        _ = await (rorTask, valTask, locTask, pdfTask)
    }

    /// Replaces a masked preview with the full record. Called only on an
    /// explicit user "Unlock" tap once they have a credit: the full fetch is
    /// what spends that credit server-side.
    public func unlockFullRecord() async {
        guard isPreviewRecord else { return }
        initialRoR = nil
        await fetchRoRIfNeeded()
    }
    
    /// Re-runs all failed/incomplete section fetches (used by pull-to-refresh and retry buttons).
    public func retry() {
        errorMessage = nil
        _Concurrency.Task { @MainActor in
            await loadData()
        }
    }
    
    // MARK: - Independent Loaders
    
    private func fetchRoRIfNeeded() async {
        if initialRoR != nil {
            rebuildReport(rorState: .loaded)
            logLandRecordViewedOnce()
            return
        }
        
        isLoadingRoR = true
        rebuildReport(rorState: .loading)
        
        do {
            let ror = try await rorService.fetch(
                district: identity.districtName,
                tahasil: identity.tahasilName,
                village: identity.villageName,
                plot: identity.plotNumber,
                bId: identity.tahasilID,
                vId: identity.villageID
            )
            self.initialRoR = ror
            self.isLoadingRoR = false
            rebuildReport(rorState: .loaded)
            logLandRecordViewedOnce()
        } catch {
            self.isLoadingRoR = false
            let msg = error.localizedDescription
            rebuildReport(rorState: .failed(message: msg))
        }
    }
    
    /// Fires the `landRecordViewed` analytics event exactly once per view model,
    /// after the RoR record resolves. Preserves the analytics that previously
    /// lived in CadastralPlotCardView now that the report is reached through the
    /// unified PlotDetailSheet.
    private var didLogLandRecordViewed = false
    private func logLandRecordViewedOnce() {
        guard !didLogLandRecordViewed, let ror = initialRoR else { return }
        didLogLandRecordViewed = true
        AnalyticsService.shared.log(.landRecordViewed(
            districtID: identity.districtName,
            isGovernmentLand: ror.isGovernmentLand,
            ownerCount: ror.owners.count,
            landClassification: report.landParticulars.landTypeKisam.value ?? "—"
        ))
    }
    
    private func computeRoRAreaInDecimals() -> Double? {
        guard let areaStr = initialRoR?.area,
              let sqM = LandAreaUnitConverter.parseToSqMeters(from: areaStr),
              let dec = LandAreaUnitConverter.fromSqMeters(sqM, to: .decimal) else {
            return nil
        }
        return dec
    }
    
    public var defaultAreaDecimal: Double {
        if let explicit = customAreaInput, explicit > 0 { return explicit }
        if let dec = computeRoRAreaInDecimals(), dec > 0 {
            return dec
        }
        if let acre = parcel?.metadata.estimatedAreaAcre, acre > 0 {
            return acre * 100.0
        }
        return 1.0
    }
    
    private func fetchValuationIfNeeded() async {
        if let val = initialValuation {
            if let cands = val.candidates, !cands.isEmpty {
                self.valuationCandidates = cands
            }
            if Self.hasValue(val) {
                rebuildReport(valState: .loaded)
                return
            }
            // Cached result without a value: resolve the office ourselves
            // instead of asking the user to pick one.
            rebuildReport(valState: .loading)
            if await autoResolveJurisdiction() { return }
            rebuildReport(valState: .unavailable(message: val.message ?? "Not available"))
            return
        }
        
        isLoadingValuation = true
        rebuildReport(valState: .loading)
        
        do {
            let areaDec = computeRoRAreaInDecimals()
            let areaDecimalForEstimate = Decimal(areaDec ?? 1.0)
            
            let val = try await benchmarkService.fetchValuation(
                district: identity.districtName,
                tahasil: identity.tahasilName,
                village: identity.villageName,
                plot: identity.plotNumber,
                actualArea: areaDec,
                actualAreaUnit: "Decimal",
                bId: identity.tahasilID,
                vId: identity.villageID
            )
            self.initialValuation = val
            if let cands = val.candidates, !cands.isEmpty {
                self.valuationCandidates = cands
            }
            
            var finalVal = val
            if let est = try? await registrationCostService.fetchEstimate(
                district: identity.districtName,
                tahasil: identity.tahasilName,
                village: identity.villageName,
                plot: identity.plotNumber,
                area: areaDecimalForEstimate,
                unit: "Decimal",
                bId: identity.tahasilID,
                vId: identity.villageID
            ) {
                if let cands = est.candidates, !cands.isEmpty, self.valuationCandidates.isEmpty {
                    self.valuationCandidates = cands
                }
                finalVal = mergeValuation(val, with: est)
            }
            
            self.initialValuation = finalVal

            if Self.hasValue(finalVal) {
                self.isLoadingValuation = false
                rebuildReport(valState: .loaded)
                return
            }

            // No value from the default lookup. When IGR returned candidate
            // offices, try them silently (best match first) so the user sees a
            // value instead of a "select your jurisdiction" dropdown. The
            // section stays in its loading state while this runs.
            let resolved = await autoResolveJurisdiction()
            self.isLoadingValuation = false
            if resolved { return }

            let fallbackMsg = self.valuationCandidates.isEmpty ? "No benchmark valuation recorded" : "Sub-Registrar jurisdiction required"
            rebuildReport(valState: .unavailable(message: finalVal.message ?? fallbackMsg))
        } catch {
            self.isLoadingValuation = false
            // A network/service failure is retryable — not "no rate exists".
            rebuildReport(valState: .failed(message: "Couldn't reach the government valuation service."))
        }
    }
    
    // MARK: - User-Assisted Valuation & Stamp Duty Actions
    
    /// Manual override: the user picked a different registration office from
    /// the "Change" menu. Rates are re-fetched for that office only.
    public func applyJurisdictionCandidate(_ candidate: IGRValuationCandidate) async {
        let previous = selectedCandidate
        isLoadingValuation = true
        rebuildReport(valState: .loading)

        let areaToUse = customAreaInput ?? defaultAreaDecimal
        let finalVal = await resolveValuation(candidate: candidate, area: areaToUse, unit: customUnitInput)
        isLoadingValuation = false

        if let finalVal, Self.hasValue(finalVal) {
            self.selectedCandidate = candidate
            self.isJurisdictionAutoSelected = false
            self.initialValuation = finalVal
            rebuildReport(valState: .loaded)
        } else if previous != nil, let kept = initialValuation, Self.hasValue(kept) {
            // Keep the value we already had rather than blanking the section.
            rebuildReport(valState: .loaded)
        } else {
            self.selectedCandidate = candidate
            rebuildReport(valState: .unavailable(message: finalVal?.message ?? "Plot not found in selected office"))
        }
    }

    // MARK: - Smart Jurisdiction Resolution

    /// True when the office behind the displayed value was picked automatically.
    @Published public private(set) var isJurisdictionAutoSelected: Bool = false

    /// How many candidate offices are tried in parallel before giving up.
    private static let maxAutoResolveAttempts = 4

    static func hasValue(_ v: BenchmarkValuation) -> Bool {
        v.status == "AVAILABLE" && (v.areaWiseBenchmarkValue ?? 0) > 0
    }

    /// Candidates ordered best-first: an exact village-name match with this
    /// plot's village wins, then the server's own match score.
    public var rankedCandidates: [IGRValuationCandidate] {
        let village = Self.normalized(identity.villageName)
        return valuationCandidates.sorted { a, b in
            let aMatch = Self.normalized(a.villageName) == village
            let bMatch = Self.normalized(b.villageName) == village
            if aMatch != bMatch { return aMatch }
            return a.score > b.score
        }
    }

    private static func normalized(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Tries the top-ranked candidate offices in parallel and adopts the
    /// best-ranked one that returns a real value. Returns false when none did.
    private func autoResolveJurisdiction() async -> Bool {
        let candidates = Array(rankedCandidates.prefix(Self.maxAutoResolveAttempts))
        guard !candidates.isEmpty else { return false }
        let area = customAreaInput ?? defaultAreaDecimal
        let unit = customUnitInput

        var results: [Int: BenchmarkValuation] = [:]
        await withTaskGroup(of: (Int, BenchmarkValuation?).self) { group in
            for (index, cand) in candidates.enumerated() {
                group.addTask { @MainActor in
                    (index, await self.resolveValuation(candidate: cand, area: area, unit: unit))
                }
            }
            for await (index, val) in group {
                if let val { results[index] = val }
            }
        }

        for (index, cand) in candidates.enumerated() {
            if let val = results[index], Self.hasValue(val) {
                self.selectedCandidate = cand
                self.isJurisdictionAutoSelected = true
                self.initialValuation = val
                rebuildReport(valState: .loaded)
                return true
            }
        }
        return false
    }

    /// Benchmark + registration-cost lookup for one candidate office.
    private func resolveValuation(candidate: IGRValuationCandidate, area: Double, unit: String) async -> BenchmarkValuation? {
        guard let val = try? await benchmarkService.fetchValuation(
            district: identity.districtName,
            tahasil: identity.tahasilName,
            village: identity.villageName,
            plot: identity.plotNumber,
            actualArea: area,
            actualAreaUnit: unit,
            bId: identity.tahasilID,
            vId: identity.villageID,
            selectedRegoffID: candidate.registrationOfficeId,
            selectedVillageID: candidate.villageId,
            candidateToken: candidate.candidateToken,
            forceRefresh: true
        ) else { return nil }

        if let est = try? await registrationCostService.fetchEstimate(
            district: identity.districtName,
            tahasil: identity.tahasilName,
            village: identity.villageName,
            plot: identity.plotNumber,
            area: Decimal(area),
            unit: unit,
            bId: identity.tahasilID,
            vId: identity.villageID,
            selectedRegoffID: candidate.registrationOfficeId,
            selectedVillageID: candidate.villageId,
            candidateToken: candidate.candidateToken,
            forceRefresh: true
        ) {
            return mergeValuation(val, with: est)
        }
        return val
    }
    
    public func calculateWithCustomInputs(
        area: Double,
        unit: String,
        buyerCategory: BuyerCategoryOption,
        deedId: Int,
        manualConsiderationValue: Double?,
        candidate: IGRValuationCandidate?
    ) async {
        self.customAreaInput = area
        self.customUnitInput = unit
        self.customBuyerCategoryInput = buyerCategory
        self.customConsiderationInput = manualConsiderationValue
        self.customDeedIdInput = deedId
        if let cand = candidate {
            self.selectedCandidate = cand
        }
        
        isLoadingValuation = true
        rebuildReport(valState: .loading)
        
        let candToUse = candidate ?? selectedCandidate
        
        var queriedVal: BenchmarkValuation? = nil
        do {
            queriedVal = try await benchmarkService.fetchValuation(
                district: identity.districtName,
                tahasil: identity.tahasilName,
                village: identity.villageName,
                plot: identity.plotNumber,
                actualArea: area,
                actualAreaUnit: unit,
                bId: identity.tahasilID,
                vId: identity.villageID,
                selectedRegoffID: candToUse?.registrationOfficeId,
                selectedVillageID: candToUse?.villageId,
                candidateToken: candToUse?.candidateToken,
                forceRefresh: true
            )
        } catch {
            queriedVal = nil
        }
        
        var queriedEst: RegistrationCostEstimate? = nil
        if let est = try? await registrationCostService.fetchEstimate(
            district: identity.districtName,
            tahasil: identity.tahasilName,
            village: identity.villageName,
            plot: identity.plotNumber,
            area: Decimal(area),
            unit: unit,
            deedId: deedId,
            buyerCategory: buyerCategory,
            bId: identity.tahasilID,
            vId: identity.villageID,
            selectedRegoffID: candToUse?.registrationOfficeId,
            selectedVillageID: candToUse?.villageId,
            candidateToken: candToUse?.candidateToken,
            forceRefresh: true
        ) {
            queriedEst = est
        }
        
        if let est = queriedEst, (est.status == "AVAILABLE" || est.benchmarkValueForArea != nil) {
            let baseVal = queriedVal ?? createValuationFromEstimate(est)
            let merged = mergeValuation(baseVal, with: est)
            self.initialValuation = merged
            self.isUserAssistedValuation = true
            self.isLoadingValuation = false
            rebuildReport(valState: .loaded)
            return
        }
        
        if let qv = queriedVal, qv.status == "AVAILABLE", qv.areaWiseBenchmarkValue != nil {
            self.initialValuation = qv
            self.isUserAssistedValuation = true
            self.isLoadingValuation = false
            rebuildReport(valState: .loaded)
            return
        }
        
        // If official rates are unlisted for this plot in IGR, but user supplied a manual land consideration value:
        if let consideration = manualConsiderationValue, consideration > 0 {
            // Odisha statutory rates (single source of truth for both the math and
            // the displayed formula, so the two can never drift apart). If the
            // state revises these, change them here only.
            let stampDutyRate = buyerCategory == .womanBuyer
                ? OdishaStatutoryRates.stampDutyWomanBuyer
                : OdishaStatutoryRates.stampDutyStandard
            let regFeeRate = OdishaStatutoryRates.registrationFee
            let stampDuty = consideration * stampDutyRate
            let regFee = consideration * regFeeRate
            
            let areaInDec: Double = {
                if unit.lowercased().contains("acre") { return area * 100.0 }
                if unit.lowercased().contains("sq") { return area / 435.6 }
                return area
            }()
            
            let pDec = areaInDec > 0 ? (consideration / areaInDec) : 0.0
            let pAcre = pDec * 100.0
            let pHectare = pAcre * 2.47105
            let pDec1000 = pDec / 10.0
            let pSqFt = pDec / 435.6
            let pSqM = pSqFt * 10.7639
            
            let synthVal = BenchmarkValuation(
                status: "AVAILABLE",
                source: "Odisha IGR Statutory Valuation (User Assisted)",
                retrievedAt: ISO8601DateFormatter().string(from: Date()),
                district: identity.districtName,
                registrationOffice: candToUse?.registrationOfficeName,
                villageThana: candToUse?.villageName ?? identity.villageName,
                kisam: nil,
                plotNumber: identity.plotNumber,
                queryArea: area,
                queryUnit: unit,
                actualParcelArea: area,
                actualParcelAreaUnit: unit,
                areaWiseBenchmarkValue: consideration,
                unitRates: BenchmarkUnitRates(
                    perAcre: pAcre,
                    perHectare: pHectare,
                    perDecimal100: pDec,
                    perDecimal1000: pDec1000,
                    perSquareMeter: pSqM,
                    perSquareFoot: pSqFt
                ),
                highestTransactionValue: nil,
                transactionDate: nil,
                stampDutyEstimate: stampDuty,
                registrationFeeEstimate: regFee,
                calculation: BenchmarkCalculation(
                    indicativeBenchmarkAmount: consideration,
                    formula: "\(OdishaStatutoryRates.percentString(stampDutyRate)) Stamp Duty + \(OdishaStatutoryRates.percentString(regFeeRate)) Registration Fee"
                ),
                cached: false,
                message: "Indicative estimate computed from the consideration you entered, using Odisha's current statutory stamp-duty and registration-fee rates. Not an official IGR valuation — confirm at the Sub-Registrar office.",
                reason: nil,
                candidates: self.valuationCandidates,
                userAssistanceUsed: true,
                selectionMode: "USER_INPUT"
            )
            
            self.initialValuation = synthVal
            self.isUserAssistedValuation = true
            self.isLoadingValuation = false
            rebuildReport(valState: .loaded)
            return
        }
        
        self.isLoadingValuation = false
        let failureMsg = queriedVal?.message ?? "Unable to determine valuation with given parameters"
        rebuildReport(valState: .unavailable(message: failureMsg))
    }
    
    private func mergeValuation(_ val: BenchmarkValuation, with est: RegistrationCostEstimate) -> BenchmarkValuation {
        let stampDuty = est.stampDuty.map { NSDecimalNumber(decimal: $0).doubleValue } ?? val.stampDutyEstimate
        let regFee = est.registrationFee.map { NSDecimalNumber(decimal: $0).doubleValue } ?? val.registrationFeeEstimate
        let totalValue = est.benchmarkValueForArea.map { NSDecimalNumber(decimal: $0).doubleValue } ?? val.areaWiseBenchmarkValue
        
        let rates: BenchmarkUnitRates? = {
            if let r = val.unitRates { return r }
            guard let dec = est.benchmarkRatePerDecimal else { return nil }
            let dDec = NSDecimalNumber(decimal: dec).doubleValue
            let dAcre = est.benchmarkRatePerAcre.map { NSDecimalNumber(decimal: $0).doubleValue } ?? (dDec * 100.0)
            let dHectare = est.benchmarkRatePerHectare.map { NSDecimalNumber(decimal: $0).doubleValue } ?? (dAcre * 2.47105)
            let dSqM = est.benchmarkRatePerSqMeter.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0.0
            let dSqFt = est.benchmarkRatePerSqFoot.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0.0
            return BenchmarkUnitRates(
                perAcre: dAcre,
                perHectare: dHectare,
                perDecimal100: dDec,
                perDecimal1000: dDec / 10.0,
                perSquareMeter: dSqM,
                perSquareFoot: dSqFt
            )
        }()
        
        return BenchmarkValuation(
            status: val.status == "AVAILABLE" ? "AVAILABLE" : (est.status == "AVAILABLE" ? "AVAILABLE" : val.status),
            source: val.source,
            sourceURL: val.sourceURL,
            retrievedAt: val.retrievedAt.isEmpty ? est.calculatedAt : val.retrievedAt,
            district: val.district,
            registrationOffice: val.registrationOffice ?? est.registrationOffice,
            villageThana: val.villageThana ?? est.villageThana,
            kisam: val.kisam ?? est.kisam,
            plotNumber: val.plotNumber,
            queryArea: val.queryArea,
            queryUnit: val.queryUnit,
            actualParcelArea: val.actualParcelArea,
            actualParcelAreaUnit: val.actualParcelAreaUnit,
            areaWiseBenchmarkValue: totalValue,
            unitRates: rates,
            highestTransactionValue: val.highestTransactionValue,
            transactionDate: val.transactionDate,
            stampDutyEstimate: stampDuty,
            registrationFeeEstimate: regFee,
            calculation: BenchmarkCalculation(
                indicativeBenchmarkAmount: totalValue,
                formula: est.formula ?? val.calculation.formula
            ),
            cached: val.cached,
            message: val.message ?? est.message,
            reason: val.reason ?? est.reason,
            candidates: val.candidates ?? est.candidates,
            userAssistanceUsed: val.userAssistanceUsed ?? est.userAssistanceUsed,
            selectionMode: val.selectionMode ?? est.selectionMode
        )
    }
    
    private func createValuationFromEstimate(_ est: RegistrationCostEstimate) -> BenchmarkValuation {
        let totalVal = est.benchmarkValueForArea.map { NSDecimalNumber(decimal: $0).doubleValue }
        let stampDuty = est.stampDuty.map { NSDecimalNumber(decimal: $0).doubleValue }
        let regFee = est.registrationFee.map { NSDecimalNumber(decimal: $0).doubleValue }
        let rates: BenchmarkUnitRates? = {
            guard let dec = est.benchmarkRatePerDecimal else { return nil }
            let dDec = NSDecimalNumber(decimal: dec).doubleValue
            let dAcre = est.benchmarkRatePerAcre.map { NSDecimalNumber(decimal: $0).doubleValue } ?? (dDec * 100.0)
            let dHectare = est.benchmarkRatePerHectare.map { NSDecimalNumber(decimal: $0).doubleValue } ?? (dAcre * 2.47105)
            let dSqM = est.benchmarkRatePerSqMeter.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0.0
            let dSqFt = est.benchmarkRatePerSqFoot.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0.0
            return BenchmarkUnitRates(
                perAcre: dAcre,
                perHectare: dHectare,
                perDecimal100: dDec,
                perDecimal1000: dDec / 10.0,
                perSquareMeter: dSqM,
                perSquareFoot: dSqFt
            )
        }()
        
        return BenchmarkValuation(
            status: est.status,
            source: est.source,
            sourceURL: est.sourceURL,
            retrievedAt: est.calculatedAt,
            district: est.district,
            registrationOffice: est.registrationOffice,
            villageThana: est.villageThana,
            kisam: est.kisam,
            plotNumber: est.plotNumber,
            queryArea: NSDecimalNumber(decimal: est.selectedArea).doubleValue,
            queryUnit: est.selectedUnit,
            actualParcelArea: NSDecimalNumber(decimal: est.selectedArea).doubleValue,
            actualParcelAreaUnit: est.selectedUnit,
            areaWiseBenchmarkValue: totalVal,
            unitRates: rates,
            highestTransactionValue: nil,
            transactionDate: nil,
            stampDutyEstimate: stampDuty,
            registrationFeeEstimate: regFee,
            calculation: BenchmarkCalculation(indicativeBenchmarkAmount: totalVal, formula: est.formula),
            cached: est.cached,
            message: est.message,
            reason: est.reason,
            candidates: est.candidates,
            userAssistanceUsed: est.userAssistanceUsed,
            selectionMode: est.selectionMode
        )
    }
    
    private func fetchGeocodedPostal() async {
        guard let coord = parcel?.centerCoordinate ?? (parcel?.boundary.first.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }) else {
            rebuildReport(locState: .loaded)
            return
        }
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let p = placemarks.first {
                self.geocodedPlacemark = p
            }
            rebuildReport(locState: .loaded)
        } catch {
            // Geocoding failure is non-fatal: purely optional postal detail
            rebuildReport(locState: .loaded)
        }
    }
    
    private func checkCachedPDF() async {
        let cached = await pdfService.getCachedURL(
            district: identity.districtName,
            tahasil: identity.tahasilName,
            village: identity.villageName,
            plot: identity.plotNumber,
            khata: initialRoR?.khataNumber,
            vId: identity.villageID
        )
        if let url = cached {
            self.pdfURL = url
            rebuildReport()
        }
    }
    
    public func downloadOfficialPDF() async {
        guard !isDownloadingPDF else { return }
        isDownloadingPDF = true
        rebuildReport()
        
        do {
            let url = try await pdfService.fetchOrGetPDF(
                district: identity.districtName,
                tahasil: identity.tahasilName,
                village: identity.villageName,
                plot: identity.plotNumber,
                khataNumber: initialRoR?.khataNumber,
                bId: identity.tahasilID,
                vId: identity.villageID
            )
            self.pdfURL = url
            self.isDownloadingPDF = false
            self.showPDFViewer = true
            rebuildReport()
        } catch {
            self.isDownloadingPDF = false
            self.errorMessage = "Unable to download official PDF: \(error.localizedDescription)"
            rebuildReport()
        }
    }
    
    // MARK: - State Synchronizer
    
    private func rebuildReport(
        rorState: SectionLoadingState? = nil,
        valState: SectionLoadingState? = nil,
        locState: SectionLoadingState? = nil
    ) {
        let effectiveRoR = rorState ?? report.rorLoadingState
        let effectiveVal = valState ?? report.valuationLoadingState
        let effectiveLoc = locState ?? report.locationLoadingState
        
        self.report = LandDetailsReportBuilder.build(
            identity: identity,
            rorResponse: initialRoR,
            benchmarkValuation: initialValuation,
            parcel: parcel,
            geocodedPlacemark: geocodedPlacemark,
            officialPDFURL: pdfURL,
            isDownloadingPDF: isDownloadingPDF,
            rorLoadingState: effectiveRoR,
            valuationLoadingState: effectiveVal,
            locationLoadingState: effectiveLoc
        )
    }
    
    // MARK: - Actions
    
    public var isSaved: Bool {
        savedLandManager.isSaved(
            districtID: identity.districtID ?? "",
            tahasilID: identity.tahasilID ?? "",
            villageID: identity.villageID ?? "",
            plotNumber: identity.plotNumber
        )
    }
    
    public func toggleSave() {
        let result = OfficialSearchResult(
            districtID: identity.districtID ?? "",
            districtName: identity.districtName,
            tahasilID: identity.tahasilID ?? "",
            tahasilName: identity.tahasilName,
            villageID: identity.villageID ?? "",
            villageName: identity.villageName,
            plotNumber: identity.plotNumber,
            khatianNumber: initialRoR?.khataNumber ?? "—",
            area: initialRoR?.area,
            ownersCount: initialRoR?.owners.count ?? 0,
            associatedPlots: initialRoR?.plots.map { $0.plotNumber } ?? [],
            rawResponse: initialRoR ?? RoRResponse(
                success: true,
                plot: identity.plotNumber,
                village: identity.villageName,
                district: identity.districtName,
                tahasil: identity.tahasilName
            )
        )
        savedLandManager.toggleSave(result: result, boundary: parcel?.boundary)
    }
    
    public func navigate() {
        guard let coord = parcel?.centerCoordinate ?? (parcel?.boundary.first.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }) else {
            return
        }
        
        let lat = coord.latitude
        let lon = coord.longitude
        
        // Apple Maps direct navigation URL
        if let appleMapsURL = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lon)&dirflg=d") {
            UIApplication.shared.open(appleMapsURL)
        }
    }
    
    public func shareReport() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateStr = dateFormatter.string(from: Date())
        
        var lines: [String] = []
        lines.append("═════════════════════════════════════")
        lines.append("PRETTYPLOT OFFICIAL LAND RECORD REPORT")
        lines.append("═════════════════════════════════════")
        lines.append("Plot No: \(report.property.plotNumber.value)")
        if let khata = report.property.khataNumber.value {
            lines.append("Khata / Khatian No: \(khata)")
        }
        lines.append("Location: \(report.location.village.value), \(report.location.tahasil.value), \(report.location.district.value), Odisha")
        if let thana = report.location.policeStationThana.value {
            lines.append("Police Station / Thana: \(thana)")
        }
        if let kisam = report.landParticulars.landTypeKisam.value {
            lines.append("Land Classification (Kisam): \(kisam)")
        }
        if let area = report.area.recordedArea.value {
            lines.append("Recorded Area: \(area)")
        }
        
        lines.append("\nOWNERS (\(report.ownership.totalOwnersCount)):")
        for owner in report.ownership.owners {
            var oLine = "• \(owner.name)"
            if let relT = owner.relationType, let relN = owner.relationName {
                oLine += " (\(relT): \(relN))"
            }
            if let share = owner.share {
                oLine += " — Share: \(share)"
            }
            lines.append(oLine)
        }
        
        if report.valuation.status == "AVAILABLE", let bv = report.valuation.benchmarkValue.value {
            let currencyFormatter = NumberFormatter()
            currencyFormatter.numberStyle = .currency
            currencyFormatter.currencySymbol = "₹"
            lines.append("\nBENCHMARK VALUATION (IGR Odisha):")
            lines.append("Benchmark Value: \(currencyFormatter.string(from: NSNumber(value: bv)) ?? "₹\(bv)")")
            if let rDec = report.valuation.ratePerDecimal.value {
                lines.append("Rate per Decimal: ₹\(Int(round(rDec)))")
            }
        }
        
        lines.append("\nDATA SOURCES:")
        lines.append("• Land Records: Odisha Bhulekh / RoR (bhulekh.ori.nic.in)")
        lines.append("• Valuation: Inspector General of Registration Odisha")
        lines.append("• Cadastral Geometry: PrettyPlot GIS Layer")
        lines.append("• Generated: \(dateStr)")
        lines.append("═════════════════════════════════════")
        lines.append("Generated with PrettyPlot • Land Intelligence")
        
        let reportText = lines.joined(separator: "\n")
        self.shareItems = [reportText]
        self.showShareSheet = true
    }
}
