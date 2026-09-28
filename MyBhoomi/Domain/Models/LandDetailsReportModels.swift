//
//  LandDetailsReportModels.swift
//  MyBhoomi
//
//  Normalized Domain Model for PrettyPlot Land Record Report.
//  Strictly enforces DATA CORRECTNESS, SOURCE TRACEABILITY, READABILITY, AND COMPLETENESS.
//  Zero fabricated data, zero fake zeroes, zero invented statuses.
//

import Foundation

// MARK: - Provenance & Field Taxonomy

public enum ReportFieldSource: String, Codable, Equatable, Sendable {
    case officialRoR = "Odisha Bhulekh / RoR"
    case officialIGR = "Odisha IGR"
    case prettyPlotGIS = "PrettyPlot GIS"
    case prettyPlotCalculated = "Calculated by PrettyPlot"
    case geocodedPostal = "Postal / Geocoding Service"
    case authoritativeMasterData = "Authoritative Administrative Catalog"
    case unavailable = "Not Available"
    
    public var badgeText: String {
        switch self {
        case .officialRoR: return "Official RoR"
        case .officialIGR: return "Official IGR"
        case .prettyPlotGIS: return "PrettyPlot GIS"
        case .prettyPlotCalculated: return "Calculated"
        case .geocodedPostal: return "Postal / Geocoded"
        case .authoritativeMasterData: return "Official Catalog"
        case .unavailable: return "Unavailable"
        }
    }
    
    public var isOfficial: Bool {
        self == .officialRoR || self == .officialIGR || self == .authoritativeMasterData
    }
}

public struct ReportField<T: Equatable & Sendable>: Equatable, Sendable {
    public let value: T
    public let label: String
    public let unit: String?
    public let source: ReportFieldSource
    public let isCalculated: Bool
    public let notes: String?
    
    public init(
        value: T,
        label: String,
        unit: String? = nil,
        source: ReportFieldSource,
        isCalculated: Bool = false,
        notes: String? = nil
    ) {
        self.value = value
        self.label = label
        self.unit = unit
        self.source = source
        self.isCalculated = isCalculated
        self.notes = notes
    }
}

// MARK: - SECTION 1: Property Section

public struct PropertySectionData: Equatable, Sendable {
    public let plotNumber: ReportField<String>
    public let khataNumber: ReportField<String?>
    public let parcelID: ReportField<String>
    /// Human-readable PP- display identifier (e.g. "PP-3422-0313"), derived
    /// deterministically in the builder so the view never invents its own.
    /// `nil` when the identifier cannot be formed — surfaced as "Not available".
    public let displayParcelID: ReportField<String?>
    public let uniquePlotID: ReportField<String?>
    public let revenuePlot: ReportField<String?>
    public let villageID: ReportField<String?>
    public let additionalIdentifiers: [String: String]
    
    public init(
        plotNumber: ReportField<String>,
        khataNumber: ReportField<String?>,
        parcelID: ReportField<String>,
        displayParcelID: ReportField<String?> = ReportField(value: nil, label: "Parcel ID", source: .unavailable),
        uniquePlotID: ReportField<String?> = ReportField(value: nil, label: "Unique Plot ID", source: .unavailable),
        revenuePlot: ReportField<String?> = ReportField(value: nil, label: "Revenue Plot", source: .unavailable),
        villageID: ReportField<String?> = ReportField(value: nil, label: "Village ID", source: .unavailable),
        additionalIdentifiers: [String: String] = [:]
    ) {
        self.plotNumber = plotNumber
        self.khataNumber = khataNumber
        self.parcelID = parcelID
        self.displayParcelID = displayParcelID
        self.uniquePlotID = uniquePlotID
        self.revenuePlot = revenuePlot
        self.villageID = villageID
        self.additionalIdentifiers = additionalIdentifiers
    }
}

// MARK: - SECTION 2: Ownership Section

public struct ReportOwner: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let index: Int
    public let name: String
    public let relationType: String?    // e.g. "Father", "Husband", "Mother", "Guardian"
    public let relationName: String?    // Relative's name
    public let caste: String?           // Official caste if recorded in tenant record
    public let residence: String?       // Official village/residence if recorded
    public let share: String?           // Fractional share
    public let khataNumber: String?
    public let ownershipDetails: String?
    public let isGovernment: Bool
    
    public init(
        id: UUID = UUID(),
        index: Int,
        name: String,
        relationType: String? = nil,
        relationName: String? = nil,
        caste: String? = nil,
        residence: String? = nil,
        share: String? = nil,
        khataNumber: String? = nil,
        ownershipDetails: String? = nil,
        isGovernment: Bool = false
    ) {
        self.id = id
        self.index = index
        self.name = name
        self.relationType = relationType
        self.relationName = relationName
        self.caste = caste
        self.residence = residence
        self.share = share
        self.khataNumber = khataNumber
        self.ownershipDetails = ownershipDetails
        self.isGovernment = isGovernment
    }
}

public struct OwnershipSectionData: Equatable, Sendable {
    public let totalOwnersCount: Int
    public let owners: [ReportOwner]
    public let source: ReportFieldSource
    
    public init(
        totalOwnersCount: Int,
        owners: [ReportOwner],
        source: ReportFieldSource = .officialRoR
    ) {
        self.totalOwnersCount = totalOwnersCount
        self.owners = owners
        self.source = source
    }
}

// MARK: - SECTION 3: Location Section

public struct LocationSectionData: Equatable, Sendable {
    public let village: ReportField<String>
    public let tahasil: ReportField<String>
    public let district: ReportField<String>
    public let riCircle: ReportField<String?>
    public let policeStationThana: ReportField<String?>
    public let postOffice: ReportField<String?>
    public let pinCode: ReportField<String?>
    public let state: ReportField<String>
    public let country: ReportField<String>
    public let latitude: Double?
    public let longitude: Double?
    public let addressString: ReportField<String?>
    
    public init(
        village: ReportField<String>,
        tahasil: ReportField<String>,
        district: ReportField<String>,
        riCircle: ReportField<String?>,
        policeStationThana: ReportField<String?>,
        postOffice: ReportField<String?>,
        pinCode: ReportField<String?>,
        state: ReportField<String> = ReportField(value: "Odisha", label: "State", source: .authoritativeMasterData),
        country: ReportField<String> = ReportField(value: "India", label: "Country", source: .authoritativeMasterData),
        latitude: Double? = nil,
        longitude: Double? = nil,
        addressString: ReportField<String?> = ReportField(value: nil, label: "Address", source: .unavailable)
    ) {
        self.village = village
        self.tahasil = tahasil
        self.district = district
        self.riCircle = riCircle
        self.policeStationThana = policeStationThana
        self.postOffice = postOffice
        self.pinCode = pinCode
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.addressString = addressString
    }
}

// MARK: - SECTION 4: Land Particulars Section

public struct LandParticularsSectionData: Equatable, Sendable {
    public let landTypeKisam: ReportField<String?>
    public let landUse: ReportField<String?>
    public let tenureSettlement: ReportField<String?>
    public let propertyClass: ReportField<String?>
    public let isGovernmentClassification: Bool
    
    public init(
        landTypeKisam: ReportField<String?>,
        landUse: ReportField<String?> = ReportField(value: nil, label: "Land Use", source: .unavailable),
        tenureSettlement: ReportField<String?> = ReportField(value: nil, label: "Settlement / Tenure", source: .unavailable),
        propertyClass: ReportField<String?> = ReportField(value: nil, label: "Property Class", source: .unavailable),
        isGovernmentClassification: Bool = false
    ) {
        self.landTypeKisam = landTypeKisam
        self.landUse = landUse
        self.tenureSettlement = tenureSettlement
        self.propertyClass = propertyClass
        self.isGovernmentClassification = isGovernmentClassification
    }
}

// MARK: - SECTION 5: Area & Measurement Section

public struct AreaConversionEntry: Identifiable, Equatable, Sendable {
    public var id: String { unitName }
    public let unitName: String
    public let formattedValue: String
    public let rawValue: Double
    public let source: ReportFieldSource
    public let isCalculated: Bool
    
    public init(unitName: String, formattedValue: String, rawValue: Double, source: ReportFieldSource = .prettyPlotCalculated, isCalculated: Bool = true) {
        self.unitName = unitName
        self.formattedValue = formattedValue
        self.rawValue = rawValue
        self.source = source
        self.isCalculated = isCalculated
    }
}

public struct AreaSectionData: Equatable, Sendable {
    public let recordedArea: ReportField<String?>
    public let gisPolygonAreaAcre: ReportField<Double?>
    public let deededArea: ReportField<String?>
    public let transferredArea: ReportField<String?>
    public let conversions: [AreaConversionEntry]
    
    public init(
        recordedArea: ReportField<String?>,
        gisPolygonAreaAcre: ReportField<Double?> = ReportField(value: nil, label: "GIS Polygon Area", source: .prettyPlotGIS, isCalculated: true),
        deededArea: ReportField<String?> = ReportField(value: nil, label: "Deeded Area", source: .unavailable),
        transferredArea: ReportField<String?> = ReportField(value: nil, label: "Transferred Area", source: .unavailable),
        conversions: [AreaConversionEntry] = []
    ) {
        self.recordedArea = recordedArea
        self.gisPolygonAreaAcre = gisPolygonAreaAcre
        self.deededArea = deededArea
        self.transferredArea = transferredArea
        self.conversions = conversions
    }
}

// MARK: - SECTION 6: Valuation & Registration Section

public struct ValuationSectionData: Equatable, Sendable {
    public let status: String // "AVAILABLE", "NOT_FOUND", "AMBIGUOUS", "UNAVAILABLE"
    public let benchmarkValue: ReportField<Double?>
    public let ratePerDecimal: ReportField<Double?>
    public let ratePerAcre: ReportField<Double?>
    public let ratePerSqFt: ReportField<Double?>
    public let ratePerSqMeter: ReportField<Double?>
    public let highestTransactionValue: ReportField<Double?>
    public let highestTransactionDate: ReportField<String?>
    public let stampDutyEstimate: ReportField<Double?>
    public let registrationFeeEstimate: ReportField<Double?>
    public let deedType: ReportField<String?>
    public let registrationOffice: ReportField<String?>
    public let villageThanaUsed: ReportField<String?>
    public let kisamUsed: ReportField<String?>
    public let calculationFormula: String?
    public let sourceURL: String
    public let retrievedAt: String?
    public let message: String?
    
    public init(
        status: String,
        benchmarkValue: ReportField<Double?>,
        ratePerDecimal: ReportField<Double?>,
        ratePerAcre: ReportField<Double?>,
        ratePerSqFt: ReportField<Double?>,
        ratePerSqMeter: ReportField<Double?>,
        highestTransactionValue: ReportField<Double?>,
        highestTransactionDate: ReportField<String?>,
        stampDutyEstimate: ReportField<Double?>,
        registrationFeeEstimate: ReportField<Double?>,
        deedType: ReportField<String?> = ReportField(value: "SALE IMMOVABLE", label: "Deed Type", source: .officialIGR),
        registrationOffice: ReportField<String?>,
        villageThanaUsed: ReportField<String?>,
        kisamUsed: ReportField<String?>,
        calculationFormula: String? = nil,
        sourceURL: String = "https://igrodisha.gov.in/ViewFeeValue.aspx",
        retrievedAt: String? = nil,
        message: String? = nil
    ) {
        self.status = status
        self.benchmarkValue = benchmarkValue
        self.ratePerDecimal = ratePerDecimal
        self.ratePerAcre = ratePerAcre
        self.ratePerSqFt = ratePerSqFt
        self.ratePerSqMeter = ratePerSqMeter
        self.highestTransactionValue = highestTransactionValue
        self.highestTransactionDate = highestTransactionDate
        self.stampDutyEstimate = stampDutyEstimate
        self.registrationFeeEstimate = registrationFeeEstimate
        self.deedType = deedType
        self.registrationOffice = registrationOffice
        self.villageThanaUsed = villageThanaUsed
        self.kisamUsed = kisamUsed
        self.calculationFormula = calculationFormula
        self.sourceURL = sourceURL
        self.retrievedAt = retrievedAt
        self.message = message
    }
}

// MARK: - SECTION 7: Land Revenue & Tax Section

public struct RevenueSectionData: Equatable, Sendable {
    public let landRevenueRent: ReportField<String?>
    public let cess: ReportField<String?>
    public let revenueYear: ReportField<String?>
    public let taxAmount: ReportField<String?>
    public let paymentStatus: ReportField<String?>
    public let pautiInfo: ReportField<String?>
    
    public init(
        landRevenueRent: ReportField<String?>,
        cess: ReportField<String?>,
        revenueYear: ReportField<String?> = ReportField(value: nil, label: "Revenue Year", source: .unavailable),
        taxAmount: ReportField<String?> = ReportField(value: nil, label: "Tax Amount", source: .unavailable),
        paymentStatus: ReportField<String?> = ReportField(value: nil, label: "Payment Status", source: .unavailable),
        pautiInfo: ReportField<String?> = ReportField(value: nil, label: "Pauti Information", source: .unavailable)
    ) {
        self.landRevenueRent = landRevenueRent
        self.cess = cess
        self.revenueYear = revenueYear
        self.taxAmount = taxAmount
        self.paymentStatus = paymentStatus
        self.pautiInfo = pautiInfo
    }
}

// MARK: - SECTION 8: Transaction History Section

public struct ReportTransaction: Identifiable, Equatable, Sendable {
    public let id: String
    public let transactionType: String
    public let saleDate: String?
    public let documentDate: String?
    public let documentNumber: String?
    public let documentType: String?
    public let buyerName: String?
    public let sellerName: String?
    public let transferPrice: Double?
    public let registrationOffice: String?
    public let source: ReportFieldSource
    
    public init(
        id: String = UUID().uuidString,
        transactionType: String,
        saleDate: String? = nil,
        documentDate: String? = nil,
        documentNumber: String? = nil,
        documentType: String? = nil,
        buyerName: String? = nil,
        sellerName: String? = nil,
        transferPrice: Double? = nil,
        registrationOffice: String? = nil,
        source: ReportFieldSource = .officialIGR
    ) {
        self.id = id
        self.transactionType = transactionType
        self.saleDate = saleDate
        self.documentDate = documentDate
        self.documentNumber = documentNumber
        self.documentType = documentType
        self.buyerName = buyerName
        self.sellerName = sellerName
        self.transferPrice = transferPrice
        self.registrationOffice = registrationOffice
        self.source = source
    }
}

public struct TransactionSectionData: Equatable, Sendable {
    public let transactions: [ReportTransaction]
    public let isAvailable: Bool
    public let availabilityNote: String
    
    public init(
        transactions: [ReportTransaction] = [],
        isAvailable: Bool = false,
        availabilityNote: String = "No online deed transaction records published for this plot in public registry."
    ) {
        self.transactions = transactions
        self.isAvailable = isAvailable
        self.availabilityNote = availabilityNote
    }
}

// MARK: - SECTION 9: Associated Plots Section

public struct ReportAssociatedPlot: Identifiable, Equatable, Sendable {
    public var id: String { plotNumber }
    public let plotNumber: String
    public let area: String?
    public let landType: String?
    public let rentCess: String?
    public let remarks: String?
    public let isCurrentPlot: Bool
    
    public init(
        plotNumber: String,
        area: String? = nil,
        landType: String? = nil,
        rentCess: String? = nil,
        remarks: String? = nil,
        isCurrentPlot: Bool = false
    ) {
        self.plotNumber = plotNumber
        self.area = area
        self.landType = landType
        self.rentCess = rentCess
        self.remarks = remarks
        self.isCurrentPlot = isCurrentPlot
    }
}

public struct AssociatedPlotsSectionData: Equatable, Sendable {
    public let totalCount: Int
    public let plots: [ReportAssociatedPlot]
    public let source: ReportFieldSource
    
    public init(
        totalCount: Int,
        plots: [ReportAssociatedPlot],
        source: ReportFieldSource = .officialRoR
    ) {
        self.totalCount = totalCount
        self.plots = plots
        self.source = source
    }
}

// MARK: - SECTION 10: Remarks Section

public struct RemarksSectionData: Equatable, Sendable {
    public let officialRemarks: String?
    public let prettyPlotNotes: String?
    public let hasContent: Bool
    
    public init(officialRemarks: String? = nil, prettyPlotNotes: String? = nil) {
        self.officialRemarks = officialRemarks
        self.prettyPlotNotes = prettyPlotNotes
        let hasRemarks: Bool = {
            guard let r = officialRemarks?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return !r.isEmpty && r != "—" && r != "-"
        }()
        let hasNotes: Bool = {
            guard let n = prettyPlotNotes?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return !n.isEmpty
        }()
        self.hasContent = hasRemarks || hasNotes
    }
}

// MARK: - SECTION 11: Documents Section

public enum DocumentAvailabilityState: Equatable, Sendable {
    case available
    case ready(URL)
    case downloading
    case applyOnline
    case unavailable(reason: String)
}

public struct ReportDocumentItem: Identifiable, Equatable, Sendable {
    public var id: String { title }
    public let title: String
    public let subtitle: String
    public let state: DocumentAvailabilityState
    public let fileFormat: String
    public let source: ReportFieldSource
    
    public init(
        title: String,
        subtitle: String,
        state: DocumentAvailabilityState,
        fileFormat: String = "PDF",
        source: ReportFieldSource
    ) {
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.fileFormat = fileFormat
        self.source = source
    }
}

public struct DocumentsSectionData: Equatable, Sendable {
    public let documents: [ReportDocumentItem]
    
    public init(documents: [ReportDocumentItem]) {
        self.documents = documents
    }
}

// MARK: - SECTION 12: Data Sources & Report Metadata Section

public struct ReportMetadataSectionData: Equatable, Sendable {
    public let landRecordsSource: String
    public let registrationSource: String
    public let parcelGeometrySource: String
    public let reportGeneratedAt: Date
    public let lastDataRetrievalAt: Date?
    public let verificationStatus: String
    public let canonicalIdentity: String
    
    public init(
        landRecordsSource: String = "Odisha Bhulekh / RoR (bhulekh.ori.nic.in)",
        registrationSource: String = "Inspector General of Registration Odisha (igrodisha.gov.in)",
        parcelGeometrySource: String = "PrettyPlot GIS (Odisha 4K GEO / ORSAC)",
        reportGeneratedAt: Date = Date(),
        lastDataRetrievalAt: Date? = nil,
        verificationStatus: String,
        canonicalIdentity: String
    ) {
        self.landRecordsSource = landRecordsSource
        self.registrationSource = registrationSource
        self.parcelGeometrySource = parcelGeometrySource
        self.reportGeneratedAt = reportGeneratedAt
        self.lastDataRetrievalAt = lastDataRetrievalAt
        self.verificationStatus = verificationStatus
        self.canonicalIdentity = canonicalIdentity
    }
}

// MARK: - Aggregate Land Details Report

public enum SectionLoadingState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case unavailable(message: String)
    case failed(message: String)
}

public struct LandDetailsReport: Equatable, Sendable {
    public let property: PropertySectionData
    public let ownership: OwnershipSectionData
    public let location: LocationSectionData
    public let landParticulars: LandParticularsSectionData
    public let area: AreaSectionData
    public let valuation: ValuationSectionData
    public let revenue: RevenueSectionData
    public let transactions: TransactionSectionData
    public let associatedPlots: AssociatedPlotsSectionData
    public let remarks: RemarksSectionData
    public let documents: DocumentsSectionData
    public let metadata: ReportMetadataSectionData
    
    // Independent section states
    public let rorLoadingState: SectionLoadingState
    public let valuationLoadingState: SectionLoadingState
    public let locationLoadingState: SectionLoadingState
    public let documentLoadingState: SectionLoadingState
    
    public init(
        property: PropertySectionData,
        ownership: OwnershipSectionData,
        location: LocationSectionData,
        landParticulars: LandParticularsSectionData,
        area: AreaSectionData,
        valuation: ValuationSectionData,
        revenue: RevenueSectionData,
        transactions: TransactionSectionData,
        associatedPlots: AssociatedPlotsSectionData,
        remarks: RemarksSectionData,
        documents: DocumentsSectionData,
        metadata: ReportMetadataSectionData,
        rorLoadingState: SectionLoadingState = .loaded,
        valuationLoadingState: SectionLoadingState = .loaded,
        locationLoadingState: SectionLoadingState = .loaded,
        documentLoadingState: SectionLoadingState = .loaded
    ) {
        self.property = property
        self.ownership = ownership
        self.location = location
        self.landParticulars = landParticulars
        self.area = area
        self.valuation = valuation
        self.revenue = revenue
        self.transactions = transactions
        self.associatedPlots = associatedPlots
        self.remarks = remarks
        self.documents = documents
        self.metadata = metadata
        self.rorLoadingState = rorLoadingState
        self.valuationLoadingState = valuationLoadingState
        self.locationLoadingState = locationLoadingState
        self.documentLoadingState = documentLoadingState
    }
}
