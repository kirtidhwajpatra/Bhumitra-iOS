//
//  LandDetailsReportBuilder.swift
//  MyBhoomi
//
//  Deterministic Builder for LandDetailsReport.
//  Transforms raw API responses into strongly typed domain models with guaranteed provenance.
//

import Foundation
import CoreLocation

public enum LandDetailsReportBuilder {
    
    public static func build(
        identity: CanonicalParcelIdentity,
        rorResponse: RoRResponse?,
        benchmarkValuation: BenchmarkValuation?,
        parcel: Parcel? = nil,
        geocodedPlacemark: CLPlacemark? = nil,
        officialPDFURL: URL? = nil,
        isDownloadingPDF: Bool = false,
        rorLoadingState: SectionLoadingState = .loaded,
        valuationLoadingState: SectionLoadingState = .loaded,
        locationLoadingState: SectionLoadingState = .loaded
    ) -> LandDetailsReport {
        
        let targetPlotNumber = identity.plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. PROPERTY SECTION
        let propKhata = rorResponse?.khataNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasKhata = propKhata != nil && !propKhata!.isEmpty && propKhata != "N/A" && propKhata != "-"
        
        // Human-readable PP- display identifier — formed deterministically here so
        // it is identical everywhere (screen, share text, saved records). Requires a
        // real area/administrative code; otherwise "Not available" rather than a fake.
        let displayCode = identity.tahasilID?.isEmpty == false
            ? identity.tahasilID
            : (identity.villageID?.isEmpty == false ? identity.villageID.map { String($0.prefix(4)) } : nil)
        let displayParcel: String? = (displayCode != nil && !targetPlotNumber.isEmpty)
            ? "PP-\(targetPlotNumber)-\(displayCode!)"
            : nil
        
        let property = PropertySectionData(
            plotNumber: ReportField(
                value: targetPlotNumber,
                label: "Plot Number",
                source: rorResponse != nil ? .officialRoR : .bhumitraGIS
            ),
            khataNumber: ReportField(
                value: hasKhata ? propKhata : nil,
                label: "Khata / Khatian No.",
                source: hasKhata ? .officialRoR : .unavailable
            ),
            parcelID: ReportField(
                value: identity.parcelID,
                label: "Parcel Identifier",
                source: .bhumitraGIS
            ),
            displayParcelID: ReportField(
                value: displayParcel,
                label: "Parcel ID",
                source: displayParcel != nil ? .bhumitraGIS : .unavailable
            ),
            uniquePlotID: ReportField(
                value: "\(identity.districtID ?? "0"):\(identity.tahasilID ?? "0"):\(identity.villageID ?? "0"):\(targetPlotNumber)",
                label: "Unique Plot Code",
                source: .bhumitraGIS,
                isCalculated: true
            ),
            revenuePlot: ReportField(
                value: rorResponse?.plot.isEmpty == false ? rorResponse?.plot : targetPlotNumber,
                label: "Revenue Plot",
                source: .officialRoR
            ),
            villageID: ReportField(
                value: (identity.villageID?.isEmpty == false ? identity.villageID : nil),
                label: "Village Census Code",
                source: identity.villageID != nil ? .authoritativeMasterData : .unavailable
            ),
            additionalIdentifiers: [
                "District Code": identity.districtID ?? "—",
                "Tahasil Code": identity.tahasilID ?? "—",
                "Village Code": identity.villageID ?? "—"
            ]
        )
        
        // 2. OWNERSHIP SECTION
        var reportOwners: [ReportOwner] = []
        if let rawOwners = rorResponse?.owners, !rawOwners.isEmpty {
            for (idx, o) in rawOwners.enumerated() {
                // If relation is not populated, parse from raw string
                let parsed = OwnerParserHelper.parse(rawName: o.name)
                let name = o.name.isEmpty ? "Recorded Citizen Owner" : (parsed.primaryName.isEmpty ? o.name : parsed.primaryName)
                let relType = o.relation ?? parsed.relationType
                let relName = o.relationName ?? parsed.relationName
                let caste = o.caste ?? parsed.caste
                let residence = o.residence ?? parsed.residence
                
                let isGov = rorResponse?.isGovernmentLand == true ||
                            name.lowercased().contains("sarkar") ||
                            name.lowercased().contains("government") ||
                            name.contains("ସରକାର")
                
                reportOwners.append(ReportOwner(
                    index: idx + 1,
                    name: name,
                    relationType: relType,
                    relationName: relName,
                    caste: caste,
                    residence: residence,
                    share: o.share,
                    khataNumber: o.khataNumber ?? propKhata,
                    ownershipDetails: o.ownershipDetails,
                    isGovernment: isGov
                ))
            }
        }
        
        let ownership = OwnershipSectionData(
            totalOwnersCount: reportOwners.count,
            owners: reportOwners,
            source: .officialRoR
        )
        
        // 3. LOCATION SECTION
        let sanitizedVillage = VillageNameSanitizer.sanitize(
            identity.villageName.isEmpty ? (rorResponse?.village ?? "") : identity.villageName
        )
        let displayTahasil = identity.tahasilName.isEmpty ? (rorResponse?.tahasil ?? "") : identity.tahasilName
        let displayDistrict = identity.districtName.isEmpty ? (rorResponse?.district ?? "") : identity.districtName
        
        // Official Thana and RI Circle directly from RoR raw fields
        let rawThana = rorResponse?.rawFields?["thana"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawRI = rorResponse?.rawFields?["ri_circle"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Postal details from geocoder (clearly marked as postal / geocoded)
        let postalPO = geocodedPlacemark?.subLocality ?? geocodedPlacemark?.locality
        let postalPIN = geocodedPlacemark?.postalCode
        
        let roPostOffice = rorResponse?.rawFields?["po"] ?? rorResponse?.rawFields?["post_office"]
        let finalPO = (roPostOffice != nil && !roPostOffice!.isEmpty) ? roPostOffice : postalPO
        let poSource: ReportFieldSource = (roPostOffice != nil && !roPostOffice!.isEmpty) ? .officialRoR : (postalPO != nil ? .geocodedPostal : .unavailable)
        
        let location = LocationSectionData(
            village: ReportField(value: sanitizedVillage, label: "Revenue Village (Mouza)", source: .officialRoR),
            tahasil: ReportField(value: displayTahasil, label: "Tahasil", source: .officialRoR),
            district: ReportField(value: displayDistrict, label: "District", source: .officialRoR),
            riCircle: ReportField(
                value: (rawRI != nil && !rawRI!.isEmpty && rawRI != "-") ? rawRI : nil,
                label: "Revenue Inspector (RI) Circle",
                source: (rawRI != nil && !rawRI!.isEmpty && rawRI != "-") ? .officialRoR : .unavailable
            ),
            policeStationThana: ReportField(
                value: (rawThana != nil && !rawThana!.isEmpty && rawThana != "-") ? rawThana : nil,
                label: "Police Station / Thana",
                source: (rawThana != nil && !rawThana!.isEmpty && rawThana != "-") ? .officialRoR : .unavailable
            ),
            postOffice: ReportField(
                value: finalPO,
                label: "Post Office",
                source: poSource
            ),
            pinCode: ReportField(
                value: postalPIN,
                label: "Postal PIN Code",
                source: postalPIN != nil ? .geocodedPostal : .unavailable,
                notes: postalPIN != nil ? "Derived from coordinate geocoding (non-cadastral)" : nil
            ),
            state: ReportField(value: "Odisha", label: "State", source: .authoritativeMasterData),
            country: ReportField(value: "India", label: "Country", source: .authoritativeMasterData),
            latitude: parcel?.center.latitude,
            longitude: parcel?.center.longitude,
            addressString: ReportField(
                value: "\(sanitizedVillage), \(displayTahasil), \(displayDistrict), Odisha",
                label: "Administrative Address",
                source: .officialRoR
            )
        )
        
        // 4. LAND PARTICULARS SECTION
        let targetPlotAssociated = rorResponse?.plots.first(where: { $0.plotNumber == targetPlotNumber })
        let officialLandType = targetPlotAssociated?.landType ?? rorResponse?.landType ?? benchmarkValuation?.kisam
        let officialTenure = rorResponse?.rawFields?["tenure"]
        
        // Property class must be BACKED by data, not invented. Government land is a
        // hard signal from RoR; a private classification is only asserted when the
        // RoR actually recorded a tenure/class. Otherwise "Not available".
        let isGovLand = rorResponse?.isGovernmentLand == true
        let hasTenure = officialTenure != nil && !officialTenure!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let propertyClassValue: String?
        let propertyClassSource: ReportFieldSource
        if isGovLand {
            propertyClassValue = "Government Land"
            propertyClassSource = .officialRoR
        } else if hasTenure {
            propertyClassValue = "Private Citizen Holding (Rayati)"
            propertyClassSource = .officialRoR
        } else {
            propertyClassValue = nil
            propertyClassSource = .unavailable
        }
        
        let landParticulars = LandParticularsSectionData(
            landTypeKisam: ReportField(
                value: officialLandType,
                label: "Land Classification (Kisam)",
                source: officialLandType != nil ? .officialRoR : .unavailable
            ),
            landUse: ReportField(
                value: rorResponse?.rawFields?["land_use"],
                label: "Recorded Land Use",
                source: rorResponse?.rawFields?["land_use"] != nil ? .officialRoR : .unavailable
            ),
            tenureSettlement: ReportField(
                value: officialTenure,
                label: "Tenure / Settlement Classification",
                source: officialTenure != nil ? .officialRoR : .unavailable
            ),
            propertyClass: ReportField(
                value: propertyClassValue,
                label: "Property Class",
                source: propertyClassSource
            ),
            isGovernmentClassification: isGovLand
        )
        
        // 5. AREA & MEASUREMENT SECTION
        let officialAreaStr = targetPlotAssociated?.area ?? rorResponse?.area
        var conversions: [AreaConversionEntry] = []
        
        if let rawA = officialAreaStr, let sqMeters = LandAreaUnitConverter.parseToSqMeters(from: rawA) {
            let primaryUnits: [(LandAreaUnit, String)] = [
                (.acres, "Acre"),
                (.decimal, "Decimal"),
                (.squareFeet, "Square Feet"),
                (.squareMeters, "Square Meters"),
                (.hectares, "Hectare"),
                (.guntha, "Guntha (Odisha)")
            ]
            for (u, name) in primaryUnits {
                if let val = LandAreaUnitConverter.fromSqMeters(sqMeters, to: u) {
                    let formatted: String
                    if u == .squareFeet {
                        let formatter = NumberFormatter()
                        formatter.numberStyle = .decimal
                        formatted = "\(formatter.string(from: NSNumber(value: Int(round(val)))) ?? "\(Int(round(val)))") sq ft"
                    } else if u == .decimal {
                        formatted = String(format: "%.2f Decimal", val).replacingOccurrences(of: ".00", with: "")
                    } else if u == .acres {
                        formatted = String(format: "%.3f Acre", val).replacingOccurrences(of: ".000", with: "")
                    } else {
                        formatted = String(format: "%.2f %@", val, u.displayName)
                    }
                    conversions.append(AreaConversionEntry(
                        unitName: name,
                        formattedValue: formatted,
                        rawValue: val,
                        source: .bhumitraCalculated,
                        isCalculated: true
                    ))
                }
            }
        }
        
        let areaSection = AreaSectionData(
            recordedArea: ReportField(
                value: officialAreaStr,
                label: "Recorded Area (RoR)",
                source: officialAreaStr != nil ? .officialRoR : .unavailable
            ),
            gisPolygonAreaAcre: ReportField(
                value: parcel?.metadata.estimatedAreaAcre,
                label: "Cadastral Polygon GIS Area",
                unit: "Acre",
                source: parcel?.metadata.estimatedAreaAcre != nil ? .bhumitraGIS : .unavailable,
                isCalculated: true,
                notes: "Planar polygon area calculated from satellite vector boundary"
            ),
            deededArea: ReportField(value: nil, label: "Deeded Area", source: .unavailable),
            transferredArea: ReportField(value: nil, label: "Transferred Area", source: .unavailable),
            conversions: conversions
        )
        
        // 6. VALUATION & REGISTRATION SECTION
        let bv = benchmarkValuation
        let isBVAvailable = bv != nil && bv?.status == "AVAILABLE"
        
        let valuation = ValuationSectionData(
            status: bv?.status ?? "UNAVAILABLE",
            benchmarkValue: ReportField(
                value: isBVAvailable ? (bv?.areaWiseBenchmarkValue ?? bv?.calculation.indicativeBenchmarkAmount) : nil,
                label: "Statutory Benchmark Valuation",
                unit: "INR",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            ratePerDecimal: ReportField(
                value: isBVAvailable ? bv?.unitRates?.perDecimal100 : nil,
                label: "Benchmark Rate per Decimal",
                unit: "INR / Decimal",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            ratePerAcre: ReportField(
                value: isBVAvailable ? bv?.unitRates?.perAcre : nil,
                label: "Benchmark Rate per Acre",
                unit: "INR / Acre",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            ratePerSqFt: ReportField(
                value: isBVAvailable ? bv?.unitRates?.perSquareFoot : nil,
                label: "Benchmark Rate per Sq Ft",
                unit: "INR / Sq Ft",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            ratePerSqMeter: ReportField(
                value: isBVAvailable ? bv?.unitRates?.perSquareMeter : nil,
                label: "Benchmark Rate per Sq Meter",
                unit: "INR / Sq M",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            highestTransactionValue: ReportField(
                value: (isBVAvailable && bv?.highestTransactionValue != nil && bv!.highestTransactionValue! > 0) ? bv?.highestTransactionValue : nil,
                label: "Highest Recorded Transaction Value",
                unit: "INR",
                source: (isBVAvailable && bv?.highestTransactionValue != nil && bv!.highestTransactionValue! > 0) ? .officialIGR : .unavailable
            ),
            highestTransactionDate: ReportField(
                value: isBVAvailable ? bv?.transactionDate : nil,
                label: "Highest Transaction Date",
                source: (isBVAvailable && bv?.transactionDate != nil && !bv!.transactionDate!.isEmpty) ? .officialIGR : .unavailable
            ),
            stampDutyEstimate: ReportField(
                value: isBVAvailable ? bv?.stampDutyEstimate : nil,
                label: "Statutory Stamp Duty Estimate",
                unit: "INR",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            registrationFeeEstimate: ReportField(
                value: isBVAvailable ? bv?.registrationFeeEstimate : nil,
                label: "Statutory Registration Fee Estimate",
                unit: "INR",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            deedType: ReportField(
                value: "SALE IMMOVABLE",
                label: "Base Deed Classification",
                source: .officialIGR
            ),
            registrationOffice: ReportField(
                value: isBVAvailable ? bv?.registrationOffice : nil,
                label: "Sub-Registrar Office (DSR / SR)",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            villageThanaUsed: ReportField(
                value: isBVAvailable ? bv?.villageThana : nil,
                label: "IGR Valuation Jurisdiction",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            kisamUsed: ReportField(
                value: isBVAvailable ? bv?.kisam : nil,
                label: "Valuation Kisam Used",
                source: isBVAvailable ? .officialIGR : .unavailable
            ),
            calculationFormula: bv?.calculation.formula,
            sourceURL: bv?.sourceURL ?? "https://igrodisha.gov.in/ViewFeeValue.aspx",
            retrievedAt: bv?.retrievedAt,
            message: bv?.message
        )
        
        // 7. LAND REVENUE & TAX SECTION
        let officialRent = targetPlotAssociated?.rentCess ?? rorResponse?.rawFields?["rent"]
        let officialCess = rorResponse?.rawFields?["cess"]
        
        let revenue = RevenueSectionData(
            landRevenueRent: ReportField(
                value: officialRent,
                label: "Annual Land Revenue / Rent",
                source: officialRent != nil ? .officialRoR : .unavailable
            ),
            cess: ReportField(
                value: officialCess,
                label: "Cess",
                source: officialCess != nil ? .officialRoR : .unavailable
            ),
            revenueYear: ReportField(value: nil, label: "Revenue Assessment Year", source: .unavailable),
            taxAmount: ReportField(value: nil, label: "Tax Assessment", source: .unavailable),
            paymentStatus: ReportField(value: nil, label: "Payment Clearance Status", source: .unavailable),
            pautiInfo: ReportField(value: nil, label: "Pauti Receipt Information", source: .unavailable)
        )
        
        // 8. TRANSACTION HISTORY SECTION
        var reportTransactions: [ReportTransaction] = []
        if let hVal = bv?.highestTransactionValue, hVal > 0 {
            reportTransactions.append(ReportTransaction(
                transactionType: "Highest Benchmark Valuation Record",
                saleDate: bv?.transactionDate,
                transferPrice: hVal,
                registrationOffice: bv?.registrationOffice,
                source: .officialIGR
            ))
        }
        
        let transactions = TransactionSectionData(
            transactions: reportTransactions,
            isAvailable: !reportTransactions.isEmpty,
            availabilityNote: reportTransactions.isEmpty ? "No public transaction deeds published online for this specific parcel in state registry." : "Verified from official Odisha IGR registry."
        )
        
        // 9. ASSOCIATED PLOTS SECTION
        let rawPlots = rorResponse?.plots ?? []
        let reportPlots: [ReportAssociatedPlot] = rawPlots.map { p in
            ReportAssociatedPlot(
                plotNumber: p.plotNumber,
                area: p.area,
                landType: p.landType,
                rentCess: p.rentCess,
                remarks: p.remarks,
                isCurrentPlot: p.plotNumber == targetPlotNumber
            )
        }
        
        let associatedPlots = AssociatedPlotsSectionData(
            totalCount: reportPlots.count,
            plots: reportPlots,
            source: .officialRoR
        )
        
        // 10. REMARKS SECTION
        let officialRemarks = targetPlotAssociated?.remarks ?? rorResponse?.rawFields?["remarks"]
        let remarks = RemarksSectionData(
            officialRemarks: officialRemarks,
            bhumitraNotes: rorResponse?.isGovernmentLand == true ? "Statutory Government parcel holding under Odisha Land Revenue rules." : nil
        )
        
        // 11. DOCUMENTS SECTION
        var docItems: [ReportDocumentItem] = []
        
        // Document 1: Official RoR PDF
        let rorDocState: DocumentAvailabilityState
        if let url = officialPDFURL {
            rorDocState = .ready(url)
        } else if isDownloadingPDF {
            rorDocState = .downloading
        } else if rorResponse?.officialDocument?.available == true {
            rorDocState = .available
        } else {
            rorDocState = .available // can be fetched on demand
        }
        docItems.append(ReportDocumentItem(
            title: "Official Record of Rights (RoR)",
            subtitle: "Government of Odisha Certified Land Passport (A4 PDF)",
            state: rorDocState,
            fileFormat: "PDF",
            source: .officialRoR
        ))
        
        // Document 2: Bhumitra Comprehensive Land Report
        docItems.append(ReportDocumentItem(
            title: "Bhumitra Comprehensive Land Report",
            subtitle: "Normalized digital summary including valuation, area ground truth & coordinates",
            state: .available,
            fileFormat: "DIGITAL REPORT",
            source: .bhumitraCalculated
        ))
        
        // Document 3: Encumbrance Certificate (EC)
        docItems.append(ReportDocumentItem(
            title: "Encumbrance Certificate (EC)",
            subtitle: "13 to 30 year registered liability certificate",
            state: .applyOnline,
            fileFormat: "IGR APPLICATION",
            source: .officialIGR
        ))
        
        // Document 4: Pauti / Rent Receipt
        docItems.append(ReportDocumentItem(
            title: "Odisha Land Revenue Pauti Receipt",
            subtitle: "Annual land tax payment token from Odisha Revenue Department",
            state: .unavailable(reason: "Direct digital retrieval unavailable; requires treasury challan query"),
            fileFormat: "REVENUE TOKEN",
            source: .officialRoR
        ))
        
        let documents = DocumentsSectionData(documents: docItems)
        
        // 12. DATA SOURCES & METADATA SECTION
        let meta = ReportMetadataSectionData(
            landRecordsSource: "Odisha Bhulekh / RoR (bhulekh.ori.nic.in)",
            registrationSource: "Inspector General of Registration Odisha (igrodisha.gov.in)",
            parcelGeometrySource: "Bhumitra GIS Layer (Odisha 4K GEO / ORSAC)",
            reportGeneratedAt: Date(),
            lastDataRetrievalAt: Date(),
            // Never assert VERIFIED without a verification object from RoR. Absent
            // verification is UNVERIFIED — presenting it as verified on a legal
            // land-records screen is the most dangerous possible fabrication.
            verificationStatus: rorResponse?.verification?.status.rawValue ?? "UNVERIFIED",
            canonicalIdentity: identity.parcelID
        )
        
        return LandDetailsReport(
            property: property,
            ownership: ownership,
            location: location,
            landParticulars: landParticulars,
            area: areaSection,
            valuation: valuation,
            revenue: revenue,
            transactions: transactions,
            associatedPlots: associatedPlots,
            remarks: remarks,
            documents: documents,
            metadata: meta,
            rorLoadingState: rorLoadingState,
            valuationLoadingState: valuationLoadingState,
            locationLoadingState: locationLoadingState,
            documentLoadingState: isDownloadingPDF ? .loading : (officialPDFURL != nil ? .loaded : .idle)
        )
    }
}
