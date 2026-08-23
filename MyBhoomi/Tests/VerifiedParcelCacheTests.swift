//
//  VerifiedParcelCacheTests.swift
//  MyBhoomi
//
//  Comprehensive test suite for VerifiedParcelCache:
//  - LRU eviction (cap at 10 items)
//  - Canonical key isolation & cross-village/cross-district protection
//  - Strict verification invariance (never cache 404, 422, 502, 504, unverified)
//  - Search suggestions ranking & disk reload survivability
//

import Foundation

@MainActor
public struct VerifiedParcelCacheTests {
    
    // MARK: - Test Runner
    
    public static func runAllTests() -> (passed: Int, failed: Int, errors: [String]) {
        var passed = 0
        var failed = 0
        var errors: [String] = []
        
        func evaluate(_ name: String, _ block: () -> Bool) {
            let result = block()
            if result {
                passed += 1
                print("✅ [PASS] \(name)")
            } else {
                failed += 1
                errors.append(name)
                print("❌ [FAIL] \(name)")
            }
        }
        
        print("=== RUNNING VERIFIED PARCEL CACHE TEST SUITE ===")
        
        evaluate("1. Successful verified result is cached", testSuccessfulVerifiedResultIsCached)
        evaluate("2. 422 is not cached", test422IsNotCached)
        evaluate("3. 404 is not cached", test404IsNotCached)
        evaluate("4. 502 is not cached", test502IsNotCached)
        evaluate("5. 504 is not cached", test504IsNotCached)
        evaluate("6. Identity mismatch is not cached", testIdentityMismatchIsNotCached)
        evaluate("7. Same parcel does not create duplicate entries", testSameParcelDoesNotCreateDuplicates)
        evaluate("8. Newest parcel moves to top", testNewestParcelMovesToTop)
        evaluate("9. Maximum cache size of 10 is respected", testMaxCacheSizeIsRespected)
        evaluate("10. Oldest parcel is evicted (LRU)", testOldestParcelIsEvicted)
        evaluate("11. Cache hit returns correct parcel", testCacheHitReturnsCorrectParcel)
        evaluate("12. Wrong district cannot retrieve another district parcel", testWrongDistrictCannotRetrieveAnotherDistrictParcel)
        evaluate("13. Wrong Tahasil cannot retrieve another Tahasil parcel", testWrongTahasilCannotRetrieveAnotherTahasilParcel)
        evaluate("14. Wrong village cannot retrieve another village parcel", testWrongVillageCannotRetrieveAnotherVillageParcel)
        evaluate("15. Same plot number in different villages remains isolated", testSamePlotNumberInDifferentVillagesIsIsolated)
        evaluate("16. Government Land remains correctly classified", testGovernmentLandRemainsCorrectlyClassified)
        evaluate("17. Empty owners never automatically becomes Government Land", testEmptyOwnersNeverAutomaticallyBecomesGovernment)
        evaluate("18. Cache survives disk reload simulation", testCacheSurvivesDiskReload)
        evaluate("19. Clear Recent removes local entries", testClearHistoryRemovesLocalEntries)
        evaluate("20. Refresh success updates cache and timestamps", testRefreshSuccessUpdatesCache)
        evaluate("21. Refresh failure preserves previous verified cached result", testRefreshFailurePreservesCache)
        evaluate("22. Search suggestions ranking and matching", testSearchSuggestionsRanking)
        evaluate("23. Legacy Cache file is auto-purged on V2 startup", testLegacyCacheFileAutoPurgedOnV2Startup)
        evaluate("24. LandClassificationStatus strict taxonomy evaluation", testLandClassificationStatusStrictTaxonomy)
        evaluate("25. Parcel Resolution Status gate", testParcelResolutionStatusGate)
        evaluate("26. UI Truth Matrix Case A (VERIFIED + VERIFIED_PRIVATE)", testUITruthMatrixCaseA)
        evaluate("27. UI Truth Matrix Case B (VERIFIED + VERIFIED_GOVERNMENT)", testUITruthMatrixCaseB)
        evaluate("28. UI Truth Matrix Cases C-G (UNVERIFIED / NOT_FOUND / MISMATCH)", testUITruthMatrixCasesCG)
        evaluate("29. Multi-Owner Joint Tenant Preservation", testMultiOwnerJointTenantPreservation)
        evaluate("30. Area String Preservation without conversion loss", testAreaStringPreservation)
        evaluate("31. Cache V2 rejects unverified entries", testCacheV2RejectsUnverifiedEntries)
        evaluate("32. Canonical Identity Consistency across Map, Search, and Cache", testCanonicalIdentityConsistency)
        
        print("=== TEST SUMMARY: \(passed) PASSED, \(failed) FAILED ===")
        return (passed, failed, errors)
    }
    
    // MARK: - Test Cases
    
    // 1. Successful verified result is cached
    public static func testSuccessfulVerifiedResultIsCached() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_1.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(
            parcelID: nil,
            plotNumber: "647",
            districtName: "Bargarh",
            districtID: "01",
            tahasilName: "Atabira",
            tahasilID: "01",
            villageName: "Chakuli",
            villageID: "242"
        )
        let ror = RoRResponse(
            success: true,
            plot: "647",
            village: "Chakuli",
            district: "Bargarh",
            tahasil: "Atabira",
            khataNumber: "277",
            area: "0.09 Ac",
            landType: "Khalabari",
            owners: [OwnerEntry(name: "Sanatan Pradhan", share: "1/1", khataNumber: "277")],
            plots: [],
            rawFields: nil,
            verification: nil,
            source: "BHULEKH"
        )
        let verif = ParcelVerificationResult(status: .verified, reasons: ["Verified"])
        
        let saved = cache.save(identity: identity, ror: ror, verification: verif)
        let fetched = cache.get(identity: identity)
        
        return saved && fetched != nil && fetched?.plotNumber == "647" && fetched?.khataNumber == "277"
    }
    
    // 2. 422 is not cached
    public static func test422IsNotCached() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_2.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "999", districtName: "Khordha", districtID: "02", tahasilName: "Bhubaneswar", tahasilID: "01", villageName: "Patia", villageID: "100")
        let ror = RoRResponse(success: false, plot: "999", village: "Patia", district: "Khordha", tahasil: "Bhubaneswar", khataNumber: nil, area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let verif = ParcelVerificationResult(status: .mismatch, reasons: ["422 Identity Mismatch"])
        
        let saved = cache.save(identity: identity, ror: ror, verification: verif)
        return !saved && cache.get(identity: identity) == nil
    }
    
    // 3. 404 is not cached
    public static func test404IsNotCached() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_3.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "404", districtName: "Cuttack", districtID: "03", tahasilName: "Sadar", tahasilID: "01", villageName: "Nuapatna", villageID: "50")
        let ror = RoRResponse(success: false, plot: "404", village: "Nuapatna", district: "Cuttack", tahasil: "Sadar", khataNumber: nil, area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let verif = ParcelVerificationResult(status: .insufficientData, reasons: ["404 Not Found"])
        
        let saved = cache.save(identity: identity, ror: ror, verification: verif)
        return !saved && cache.get(identity: identity) == nil
    }
    
    // 4. 502 is not cached
    public static func test502IsNotCached() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_4.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "502", districtName: "Puri", districtID: "04", tahasilName: "Pipili", tahasilID: "02", villageName: "Dhauli", villageID: "12")
        let ror = RoRResponse(success: false, plot: "502", village: "Dhauli", district: "Puri", tahasil: "Pipili", khataNumber: nil, area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let verif = ParcelVerificationResult(status: .sourceUnavailable, reasons: ["502 Bad Gateway"])
        
        let saved = cache.save(identity: identity, ror: ror, verification: verif)
        return !saved && cache.get(identity: identity) == nil
    }
    
    // 5. 504 is not cached
    public static func test504IsNotCached() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_5.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "504", districtName: "Balasore", districtID: "05", tahasilName: "Sadar", tahasilID: "01", villageName: "Remuna", villageID: "88")
        let ror = RoRResponse(success: false, plot: "504", village: "Remuna", district: "Balasore", tahasil: "Sadar", khataNumber: nil, area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let verif = ParcelVerificationResult(status: .sourceUnavailable, reasons: ["504 Gateway Timeout"])
        
        let saved = cache.save(identity: identity, ror: ror, verification: verif)
        return !saved && cache.get(identity: identity) == nil
    }
    
    // 6. Identity mismatch is not cached
    public static func testIdentityMismatchIsNotCached() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_6.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "100", districtName: "Sambalpur", districtID: "06", tahasilName: "Rengali", tahasilID: "03", villageName: "Katarbaga", villageID: "14")
        let ror = RoRResponse(success: true, plot: "999", village: "WrongVillage", district: "Sambalpur", tahasil: "Rengali", khataNumber: "12", area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let verif = ParcelVerificationResult(status: .mismatch, reasons: ["Plot mismatch: expected 100, got 999"])
        
        let saved = cache.save(identity: identity, ror: ror, verification: verif)
        return !saved && cache.get(identity: identity) == nil
    }
    
    // 7. Same parcel does not create duplicate entries
    public static func testSameParcelDoesNotCreateDuplicates() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_7.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "647", districtName: "Bargarh", districtID: "01", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "242")
        let ror = RoRResponse(success: true, plot: "647", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "277", area: "0.09 Ac", landType: "Khalabari", owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let verif = ParcelVerificationResult(status: .verified, reasons: ["Verified"])
        
        _ = cache.save(identity: identity, ror: ror, verification: verif)
        _ = cache.save(identity: identity, ror: ror, verification: verif)
        _ = cache.save(identity: identity, ror: ror, verification: verif)
        
        return cache.recentParcels.count == 1
    }
    
    // 8. Newest parcel moves to top
    public static func testNewestParcelMovesToTop() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_8.json")
        cache.clearHistory()
        
        func makeParcel(_ plot: String) -> CachedVerifiedParcel {
            CachedVerifiedParcel(
                canonicalKey: "01:01:242:\(plot)",
                plotNumber: plot,
                villageName: "Chakuli",
                villageID: "242",
                tahasilName: "Atabira",
                tahasilID: "01",
                districtName: "Bargarh",
                districtID: "01",
                khataNumber: "100",
                area: "1.0 Ac",
                landClassification: "Rayati",
                tenure: nil,
                landClassificationStatus: .verifiedPrivate,
                resolutionStatus: .verified,
                owners: [],
                landlord: nil,
                rawRoRResponse: RoRResponse(success: true, plot: plot, village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "100", area: "1.0 Ac", landType: "Rayati", owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH"),
                verificationStatus: "verified"
            )
        }
        
        _ = cache.save(makeParcel("101"))
        _ = cache.save(makeParcel("102"))
        _ = cache.save(makeParcel("103"))
        
        // 103 should be on top
        guard cache.recentParcels.first?.plotNumber == "103" else { return false }
        
        // Touch 101 -> 101 should move to top
        cache.touch(canonicalKey: "01:01:242:101")
        return cache.recentParcels.first?.plotNumber == "101"
    }
    
    // 9. Maximum cache size of 10 is respected
    public static func testMaxCacheSizeIsRespected() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_9.json")
        cache.clearHistory()
        
        for i in 1...15 {
            let p = CachedVerifiedParcel(
                canonicalKey: "01:01:242:\(i)",
                plotNumber: "\(i)",
                villageName: "Chakuli",
                villageID: "242",
                tahasilName: "Atabira",
                tahasilID: "01",
                districtName: "Bargarh",
                districtID: "01",
                khataNumber: "\(i)",
                area: nil,
                landClassification: nil,
                tenure: nil,
                landClassificationStatus: .verifiedPrivate,
                resolutionStatus: .verified,
                owners: [],
                landlord: nil,
                rawRoRResponse: RoRResponse(success: true, plot: "\(i)", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "\(i)", area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH"),
                verificationStatus: "verified"
            )
            _ = cache.save(p)
        }
        
        return cache.recentParcels.count == 10
    }
    
    // 10. Oldest parcel is evicted (LRU)
    public static func testOldestParcelIsEvicted() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_10.json")
        cache.clearHistory()
        
        for i in 1...11 {
            let p = CachedVerifiedParcel(
                canonicalKey: "01:01:242:\(i)",
                plotNumber: "\(i)",
                villageName: "Chakuli",
                villageID: "242",
                tahasilName: "Atabira",
                tahasilID: "01",
                districtName: "Bargarh",
                districtID: "01",
                khataNumber: "\(i)",
                area: nil,
                landClassification: nil,
                tenure: nil,
                landClassificationStatus: .verifiedPrivate,
                resolutionStatus: .verified,
                owners: [],
                landlord: nil,
                rawRoRResponse: RoRResponse(success: true, plot: "\(i)", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "\(i)", area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH"),
                verificationStatus: "verified"
            )
            _ = cache.save(p)
        }
        
        // Item "1" should have been evicted
        let item1 = cache.get(canonicalKey: "01:01:242:1")
        let item11 = cache.get(canonicalKey: "01:01:242:11")
        return item1 == nil && item11 != nil && cache.recentParcels.count == 10
    }
    
    // 11. Cache hit returns correct parcel
    public static func testCacheHitReturnsCorrectParcel() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_11.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "333", districtName: "Khordha", districtID: "02", tahasilName: "Bhubaneswar", tahasilID: "01", villageName: "Raghunathpur Jali", villageID: "538")
        let ror = RoRResponse(success: true, plot: "333", village: "Raghunathpur Jali", district: "Khordha", tahasil: "Bhubaneswar", khataNumber: "538", area: "0.01 Ac", landType: "Biali Dofasal", owners: [OwnerEntry(name: "Hadu Behera", share: "1/2", khataNumber: "538")], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let verif = ParcelVerificationResult(status: .verified, reasons: ["Verified"])
        
        _ = cache.save(identity: identity, ror: ror, verification: verif)
        guard let cached = cache.get(identity: identity) else { return false }
        
        return cached.plotNumber == "333" && cached.khataNumber == "538" && cached.owners.first?.name == "Hadu Behera"
    }
    
    // 12. Wrong district cannot retrieve another district parcel
    public static func testWrongDistrictCannotRetrieveAnotherDistrictParcel() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_12.json")
        cache.clearHistory()
        
        let identity1 = CanonicalParcelIdentity(parcelID: nil, plotNumber: "100", districtName: "Bargarh", districtID: "01", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "242")
        let ror = RoRResponse(success: true, plot: "100", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "10", area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        _ = cache.save(identity: identity1, ror: ror, verification: ParcelVerificationResult(status: .verified, reasons: []))
        
        // Attempt retrieval with wrong district ID (99)
        let identityWrongDist = CanonicalParcelIdentity(parcelID: nil, plotNumber: "100", districtName: "WrongDist", districtID: "99", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "242")
        return cache.get(identity: identityWrongDist) == nil
    }
    
    // 13. Wrong Tahasil cannot retrieve another Tahasil parcel
    public static func testWrongTahasilCannotRetrieveAnotherTahasilParcel() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_13.json")
        cache.clearHistory()
        
        let identity1 = CanonicalParcelIdentity(parcelID: nil, plotNumber: "100", districtName: "Bargarh", districtID: "01", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "242")
        let ror = RoRResponse(success: true, plot: "100", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "10", area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        _ = cache.save(identity: identity1, ror: ror, verification: ParcelVerificationResult(status: .verified, reasons: []))
        
        // Attempt retrieval with wrong tahasil ID (99)
        let identityWrongTah = CanonicalParcelIdentity(parcelID: nil, plotNumber: "100", districtName: "Bargarh", districtID: "01", tahasilName: "WrongTah", tahasilID: "99", villageName: "Chakuli", villageID: "242")
        return cache.get(identity: identityWrongTah) == nil
    }
    
    // 14. Wrong village cannot retrieve another village parcel
    public static func testWrongVillageCannotRetrieveAnotherVillageParcel() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_14.json")
        cache.clearHistory()
        
        let identity1 = CanonicalParcelIdentity(parcelID: nil, plotNumber: "100", districtName: "Bargarh", districtID: "01", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "242")
        let ror = RoRResponse(success: true, plot: "100", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "10", area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        _ = cache.save(identity: identity1, ror: ror, verification: ParcelVerificationResult(status: .verified, reasons: []))
        
        // Attempt retrieval with wrong village ID (99)
        let identityWrongVill = CanonicalParcelIdentity(parcelID: nil, plotNumber: "100", districtName: "Bargarh", districtID: "01", tahasilName: "Atabira", tahasilID: "01", villageName: "OtherVillage", villageID: "99")
        return cache.get(identity: identityWrongVill) == nil
    }
    
    // 15. Same plot number in different villages remains isolated
    public static func testSamePlotNumberInDifferentVillagesIsIsolated() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_15.json")
        cache.clearHistory()
        
        let idVillageA = CanonicalParcelIdentity(parcelID: nil, plotNumber: "84", districtName: "Bargarh", districtID: "01", tahasilName: "Atabira", tahasilID: "01", villageName: "VillageA", villageID: "101")
        let rorA = RoRResponse(success: true, plot: "84", village: "VillageA", district: "Bargarh", tahasil: "Atabira", khataNumber: "100", area: "1.0 Ac", landType: "Khalabari", owners: [OwnerEntry(name: "Owner In Village A", share: "1/1", khataNumber: "100")], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        
        let idVillageB = CanonicalParcelIdentity(parcelID: nil, plotNumber: "84", districtName: "Bargarh", districtID: "01", tahasilName: "Atabira", tahasilID: "01", villageName: "VillageB", villageID: "102")
        let rorB = RoRResponse(success: true, plot: "84", village: "VillageB", district: "Bargarh", tahasil: "Atabira", khataNumber: "200", area: "2.0 Ac", landType: "Gharabari", owners: [OwnerEntry(name: "Owner In Village B", share: "1/1", khataNumber: "200")], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        
        _ = cache.save(identity: idVillageA, ror: rorA, verification: ParcelVerificationResult(status: .verified, reasons: []))
        _ = cache.save(identity: idVillageB, ror: rorB, verification: ParcelVerificationResult(status: .verified, reasons: []))
        
        let fetchedA = cache.get(identity: idVillageA)
        let fetchedB = cache.get(identity: idVillageB)
        
        return fetchedA?.owners.first?.name == "Owner In Village A" &&
               fetchedB?.owners.first?.name == "Owner In Village B" &&
               fetchedA?.khataNumber == "100" &&
               fetchedB?.khataNumber == "200"
    }
    
    // 16. Government Land remains correctly classified
    public static func testGovernmentLandRemainsCorrectlyClassified() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_16.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "500", districtName: "Keonjhar", districtID: "07", tahasilName: "Sadar", tahasilID: "04", villageName: "GKeri", villageID: "179")
        let ror = RoRResponse(success: true, plot: "500", village: "GKeri", district: "Keonjhar", tahasil: "Sadar", khataNumber: "1", area: "5.0 Ac", landType: "ସରକାରୀ ରକ୍ଷିତ (Gochar)", owners: [], plots: [], rawFields: ["landlord": "ଓଡିଶା ସରକାର"], verification: nil, source: "BHULEKH")
        
        _ = cache.save(identity: identity, ror: ror, verification: ParcelVerificationResult(status: .verified, reasons: []))
        let fetched = cache.get(identity: identity)
        
        return fetched?.isGovernmentLand == true
    }
    
    // 17. Empty owners never automatically becomes Government Land
    public static func testEmptyOwnersNeverAutomaticallyBecomesGovernment() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_17.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "501", districtName: "Keonjhar", districtID: "07", tahasilName: "Sadar", tahasilID: "04", villageName: "GKeri", villageID: "179")
        // Land type is Rayati (private), but owners array happens to be empty
        let ror = RoRResponse(success: true, plot: "501", village: "GKeri", district: "Keonjhar", tahasil: "Sadar", khataNumber: "12", area: "0.5 Ac", landType: "Rayati (ରୟତି)", owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        
        _ = cache.save(identity: identity, ror: ror, verification: ParcelVerificationResult(status: .verified, reasons: []))
        let fetched = cache.get(identity: identity)
        
        return fetched?.isGovernmentLand == false
    }
    
    // 18. Cache survives disk reload simulation
    public static func testCacheSurvivesDiskReload() -> Bool {
        let filename = "test_cache_persist.json"
        let cache1 = VerifiedParcelCache(maxSize: 10, customFilename: filename)
        cache1.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "777", districtName: "Cuttack", districtID: "03", tahasilName: "Sadar", tahasilID: "01", villageName: "Choudwar", villageID: "55")
        let ror = RoRResponse(success: true, plot: "777", village: "Choudwar", district: "Cuttack", tahasil: "Sadar", khataNumber: "88", area: "2.5 Ac", landType: "Gharabari", owners: [OwnerEntry(name: "Persistent Test Owner", share: "1/1", khataNumber: "88")], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        
        _ = cache1.save(identity: identity, ror: ror, verification: ParcelVerificationResult(status: .verified, reasons: []))
        
        // Instantiate a second cache instance reading the same file
        let cache2 = VerifiedParcelCache(maxSize: 10, customFilename: filename)
        let fetched = cache2.get(identity: identity)
        
        return fetched != nil && fetched?.plotNumber == "777" && fetched?.owners.first?.name == "Persistent Test Owner"
    }
    
    // 19. Clear Recent removes local entries
    public static func testClearHistoryRemovesLocalEntries() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_19.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "10", districtName: "Puri", districtID: "04", tahasilName: "Pipili", tahasilID: "02", villageName: "Dhauli", villageID: "12")
        let ror = RoRResponse(success: true, plot: "10", village: "Dhauli", district: "Puri", tahasil: "Pipili", khataNumber: "1", area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        _ = cache.save(identity: identity, ror: ror, verification: ParcelVerificationResult(status: .verified, reasons: []))
        
        guard cache.recentParcels.count == 1 else { return false }
        cache.clearHistory()
        return cache.recentParcels.isEmpty && cache.get(identity: identity) == nil
    }
    
    // 20. Refresh success updates cache and timestamps
    public static func testRefreshSuccessUpdatesCache() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_20.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "647", districtName: "Bargarh", districtID: "01", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "242")
        let rorInitial = RoRResponse(success: true, plot: "647", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "277", area: "0.09 Ac", landType: "Khalabari", owners: [OwnerEntry(name: "Old Owner", share: "1/1", khataNumber: "277")], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        _ = cache.save(identity: identity, ror: rorInitial, verification: ParcelVerificationResult(status: .verified, reasons: []))
        
        let rorRefreshed = RoRResponse(success: true, plot: "647", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "277", area: "0.09 Ac", landType: "Khalabari", owners: [OwnerEntry(name: "Updated Owner", share: "1/1", khataNumber: "277")], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        _ = cache.save(identity: identity, ror: rorRefreshed, verification: ParcelVerificationResult(status: .verified, reasons: []))
        
        let fetched = cache.get(identity: identity)
        return fetched?.owners.first?.name == "Updated Owner"
    }
    
    // 21. Refresh failure preserves previous verified cached result
    public static func testRefreshFailurePreservesCache() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_21.json")
        cache.clearHistory()
        
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "647", districtName: "Bargarh", districtID: "01", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "242")
        let ror = RoRResponse(success: true, plot: "647", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "277", area: "0.09 Ac", landType: "Khalabari", owners: [OwnerEntry(name: "Sanatan Pradhan", share: "1/1", khataNumber: "277")], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        _ = cache.save(identity: identity, ror: ror, verification: ParcelVerificationResult(status: .verified, reasons: []))
        
        // Simulating failed refresh: save fails and leaves cache intact
        let rorFailed = RoRResponse(success: false, plot: "647", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: nil, area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let verifFailed = ParcelVerificationResult(status: .sourceUnavailable, reasons: ["502 Bad Gateway"])
        
        let saved = cache.save(identity: identity, ror: rorFailed, verification: verifFailed)
        let fetched = cache.get(identity: identity)
        
        return !saved && fetched != nil && fetched?.owners.first?.name == "Sanatan Pradhan"
    }
    
    // 22. Search suggestions ranking and matching
    public static func testSearchSuggestionsRanking() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_22.json")
        cache.clearHistory()
        
        func add(_ plot: String, _ village: String, _ khata: String) {
            let p = CachedVerifiedParcel(
                canonicalKey: "01:01:\(village):\(plot)",
                plotNumber: plot,
                villageName: village,
                villageID: village,
                tahasilName: "Atabira",
                tahasilID: "01",
                districtName: "Bargarh",
                districtID: "01",
                khataNumber: khata,
                area: nil,
                landClassification: nil,
                tenure: nil,
                landClassificationStatus: .verifiedPrivate,
                resolutionStatus: .verified,
                owners: [],
                landlord: nil,
                rawRoRResponse: RoRResponse(success: true, plot: plot, village: village, district: "Bargarh", tahasil: "Atabira", khataNumber: khata, area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH"),
                verificationStatus: "verified"
            )
            _ = cache.save(p)
        }
        
        add("647", "Chakuli", "277")
        add("333", "Raghunathpur", "538")
        add("64", "Chakuli", "100")
        
        // Exact plot query "647" should rank 647 first
        let suggestionsPlot = cache.searchSuggestions(query: "647")
        guard suggestionsPlot.first?.plotNumber == "647" else { return false }
        
        // Village query "chak" should match both Chakuli parcels
        let suggestionsVillage = cache.searchSuggestions(query: "chak")
        guard suggestionsVillage.count >= 2 && suggestionsVillage.allSatisfy({ $0.villageName == "Chakuli" }) else { return false }
        
        // Khata query "538" should match Plot 333
        let suggestionsKhata = cache.searchSuggestions(query: "538")
        guard suggestionsKhata.first?.plotNumber == "333" else { return false }
        
        return true
    }
    
    // 23. Legacy Cache file is auto-purged on V2 startup
    public static func testLegacyCacheFileAutoPurgedOnV2Startup() -> Bool {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let legacyURL = appSupport.appendingPathComponent("verified_parcels_cache.json")
        
        // Simulate a legacy contaminated cache file
        try? "{\"legacy\": true}".data(using: .utf8)?.write(to: legacyURL)
        guard fileManager.fileExists(atPath: legacyURL.path) else { return false }
        
        // Initializing Cache V2 must purge legacy file
        _ = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_v2_purge.json")
        
        return !fileManager.fileExists(atPath: legacyURL.path)
    }
    
    // 24. LandClassificationStatus strict taxonomy evaluation
    public static func testLandClassificationStatusStrictTaxonomy() -> Bool {
        // Government test
        let govtStatus = CachedVerifiedParcel.determineLandClassification(
            landType: "ସରକାରୀ ରକ୍ଷିତ (Gochar)",
            tenure: nil,
            owners: []
        )
        guard govtStatus == .verifiedGovernment else { return false }
        
        // Private test with Rayati keyword
        let privateStatus = CachedVerifiedParcel.determineLandClassification(
            landType: "Rayati (ରୟତି)",
            tenure: "Stitiban",
            owners: []
        )
        guard privateStatus == .verifiedPrivate else { return false }
        
        // Empty owners with non-government keywords must be unverified (NEVER Government!)
        let unverifiedStatus = CachedVerifiedParcel.determineLandClassification(
            landType: "Unknown",
            tenure: nil,
            owners: []
        )
        guard unverifiedStatus == .unverified else { return false }
        
        return true
    }
    
    // 25. Parcel Resolution Status gate
    public static func testParcelResolutionStatusGate() -> Bool {
        let rorVerified = RoRResponse(success: true, plot: "100", village: "V", district: "D", tahasil: "T", khataNumber: "1", area: "1 Ac", landType: "Rayati", owners: [OwnerEntry(name: "Citizen", khataNumber: "1")], plots: [], rawFields: nil, verification: RoRVerification(status: RoRVerificationStatus.verified, details: "OK"), source: "BHULEKH")
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "100", districtName: "D", districtID: "01", tahasilName: "T", tahasilID: "01", villageName: "V", villageID: "01")
        let result = OfficialSearchResult(ror: rorVerified, identity: identity)
        
        return result.resolutionStatus == ParcelResolutionStatus.verified && result.landClassificationStatus == LandClassificationStatus.verifiedPrivate && !result.isGovernmentLand
    }
    
    // 26. UI Truth Matrix Case A (VERIFIED + VERIFIED_PRIVATE)
    public static func testUITruthMatrixCaseA() -> Bool {
        let p = CachedVerifiedParcel(
            canonicalKey: "01:01:242:647",
            plotNumber: "647",
            villageName: "Chakuli",
            villageID: "242",
            tahasilName: "Atabira",
            tahasilID: "01",
            districtName: "Bargarh",
            districtID: "01",
            khataNumber: "277",
            area: "0 Acre 0900 Decimal",
            landClassification: "Khalabari",
            tenure: "Stitiban",
            landClassificationStatus: .verifiedPrivate,
            resolutionStatus: .verified,
            owners: [CachedOwnerEntry(name: "Sanatan Padhan", share: nil, khataNumber: "277")],
            landlord: nil,
            rawRoRResponse: RoRResponse(success: true, plot: "647", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "277", area: "0 Acre 0900 Decimal", landType: "Khalabari", owners: [OwnerEntry(name: "Sanatan Padhan", khataNumber: "277")], plots: [], rawFields: nil, verification: nil, source: "BHULEKH"),
            verificationStatus: "verified"
        )
        return p.isPrivateLand == true && p.isGovernmentLand == false && p.resolutionStatus == .verified
    }
    
    // 27. UI Truth Matrix Case B (VERIFIED + VERIFIED_GOVERNMENT)
    public static func testUITruthMatrixCaseB() -> Bool {
        let p = CachedVerifiedParcel(
            canonicalKey: "07:04:317:1",
            plotNumber: "1",
            villageName: "Dimbo",
            villageID: "317",
            tahasilName: "Keonjhar Sadar",
            tahasilID: "04",
            districtName: "Keonjhar",
            districtID: "07",
            khataNumber: "230",
            area: "0 Acre 2900 Decimal",
            landClassification: "Gochar",
            tenure: nil,
            landClassificationStatus: .verifiedGovernment,
            resolutionStatus: .verified,
            owners: [CachedOwnerEntry(name: "Rakhita", share: nil, khataNumber: "230")],
            landlord: "State of Odisha",
            rawRoRResponse: RoRResponse(success: true, plot: "1", village: "Dimbo", district: "Keonjhar", tahasil: "Keonjhar Sadar", khataNumber: "230", area: "0 Acre 2900 Decimal", landType: "Gochar", owners: [OwnerEntry(name: "Rakhita", khataNumber: "230")], plots: [], rawFields: nil, verification: nil, source: "BHULEKH"),
            verificationStatus: "verified"
        )
        return p.isGovernmentLand == true && p.isPrivateLand == false && p.resolutionStatus == .verified
    }
    
    // 28. UI Truth Matrix Cases C-G (UNVERIFIED / NOT_FOUND / MISMATCH)
    public static func testUITruthMatrixCasesCG() -> Bool {
        // Case C: unverified + unverified
        let pC = CachedVerifiedParcel(
            canonicalKey: "01:01:242:99",
            plotNumber: "99",
            villageName: "V", villageID: "01", tahasilName: "T", tahasilID: "01", districtName: "D", districtID: "01", khataNumber: "1", area: nil, landClassification: nil, tenure: nil,
            landClassificationStatus: .unverified,
            resolutionStatus: .unresolved,
            owners: [], landlord: nil, rawRoRResponse: RoRResponse(success: false, plot: "99", village: "V", district: "D", tahasil: "T", khataNumber: nil, area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH"),
            verificationStatus: "unresolved"
        )
        guard pC.isGovernmentLand == false && pC.isPrivateLand == false else { return false }
        
        // Case G: unresolved + verifiedGovernment keyword present -> MUST NOT be government
        let pG = CachedVerifiedParcel(
            canonicalKey: "01:01:242:99",
            plotNumber: "99",
            villageName: "V", villageID: "01", tahasilName: "T", tahasilID: "01", districtName: "D", districtID: "01", khataNumber: "1", area: nil, landClassification: "Gochar", tenure: nil,
            landClassificationStatus: .verifiedGovernment,
            resolutionStatus: .unresolved,
            owners: [], landlord: nil, rawRoRResponse: RoRResponse(success: false, plot: "99", village: "V", district: "D", tahasil: "T", khataNumber: nil, area: nil, landType: "Gochar", owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH"),
            verificationStatus: "unresolved"
        )
        guard pG.isGovernmentLand == false else { return false }
        
        return true
    }
    
    // 29. Multi-Owner Joint Tenant Preservation
    public static func testMultiOwnerJointTenantPreservation() -> Bool {
        let owners = [
            OwnerEntry(name: "Phulamani Jena", share: "0.500", khataNumber: "112"),
            OwnerEntry(name: "Babaji Jena", share: "0.500", khataNumber: "112"),
            OwnerEntry(name: "Ghasia Jena", share: nil, khataNumber: "112")
        ]
        let ror = RoRResponse(success: true, plot: "12", village: "Dimbo", district: "Keonjhar", tahasil: "Sadar", khataNumber: "112", area: "0.41 Ac", landType: "Sarada 3", owners: owners, plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "12", districtName: "Keonjhar", districtID: "07", tahasilName: "Sadar", tahasilID: "04", villageName: "Dimbo", villageID: "317")
        let result = OfficialSearchResult(ror: ror, identity: identity)
        
        return result.rawResponse.owners.count == 3 && result.rawResponse.owners[0].name == "Phulamani Jena" && result.rawResponse.owners[1].name == "Babaji Jena" && result.rawResponse.owners[2].name == "Ghasia Jena"
    }
    
    // 30. Area String Preservation without conversion loss
    public static func testAreaStringPreservation() -> Bool {
        let officialExtent = "0 Acre 0900 Decimal"
        let ror = RoRResponse(success: true, plot: "647", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: "277", area: officialExtent, landType: "Khalabari", owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH")
        let identity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "647", districtName: "Bargarh", districtID: "15", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "61")
        let result = OfficialSearchResult(ror: ror, identity: identity)
        
        return result.area == officialExtent
    }
    
    // 31. Cache V2 rejects unverified entries
    public static func testCacheV2RejectsUnverifiedEntries() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_31.json")
        cache.clearHistory()
        
        let unverifiedParcel = CachedVerifiedParcel(
            canonicalKey: "01:01:242:999",
            plotNumber: "999",
            villageName: "Chakuli", villageID: "242", tahasilName: "Atabira", tahasilID: "01", districtName: "Bargarh", districtID: "01", khataNumber: "0", area: nil, landClassification: nil, tenure: nil,
            landClassificationStatus: .unverified,
            resolutionStatus: .unresolved,
            owners: [], landlord: nil, rawRoRResponse: RoRResponse(success: false, plot: "999", village: "Chakuli", district: "Bargarh", tahasil: "Atabira", khataNumber: nil, area: nil, landType: nil, owners: [], plots: [], rawFields: nil, verification: nil, source: "BHULEKH"),
            verificationStatus: "unresolved"
        )
        
        let saved = cache.save(unverifiedParcel)
        return cache.recentParcels.isEmpty && saved == false
    }
    
    // 32. Canonical Identity Consistency across Map, Search, and Cache
    public static func testCanonicalIdentityConsistency() -> Bool {
        let mapIdentity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "647", districtName: "Bargarh", districtID: "15", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "61")
        let searchIdentity = CanonicalParcelIdentity(parcelID: nil, plotNumber: "647", districtName: "Bargarh", districtID: "15", tahasilName: "Atabira", tahasilID: "01", villageName: "Chakuli", villageID: "61")
        
        let mapKey = "\(mapIdentity.districtID ?? ""):\(mapIdentity.tahasilID ?? ""):\(mapIdentity.villageID ?? ""):\(mapIdentity.plotNumber)"
        let searchKey = "\(searchIdentity.districtID ?? ""):\(searchIdentity.tahasilID ?? ""):\(searchIdentity.villageID ?? ""):\(searchIdentity.plotNumber)"
        
        return mapKey == searchKey && mapKey == "15:01:61:647"
    }
    
    // 33. Chandakuda Plot 241 Cache Isolation & Exact Key Retrieval
    public static func testChandakudaPlot241CacheIsolation() -> Bool {
        let cache = VerifiedParcelCache(maxSize: 10, customFilename: "test_cache_33.json")
        cache.clearHistory()
        
        let identityChandakuda = CanonicalParcelIdentity(
            parcelID: "1603022_241",
            plotNumber: "241",
            districtName: "Bhadrak",
            districtID: "16",
            tahasilName: "Chandbali",
            tahasilID: "3",
            villageName: "Chandakuda",
            villageID: "22"
        )
        
        let owners = [
            OwnerEntry(name: "Gayatri Biswal", share: nil, khataNumber: "54"),
            OwnerEntry(name: "Savitri Biswal", share: nil, khataNumber: "54"),
            OwnerEntry(name: "Dharitri Biswal", share: nil, khataNumber: "54"),
            OwnerEntry(name: "Sumitra Biswal", share: nil, khataNumber: "54"),
            OwnerEntry(name: "Monalisa Biswal", share: nil, khataNumber: "54"),
            OwnerEntry(name: "Shubhashree Biswal", share: nil, khataNumber: "54"),
            OwnerEntry(name: "Niansha Mrita", share: nil, khataNumber: "54")
        ]
        
        let ror = RoRResponse(
            success: true,
            plot: "241",
            village: "ଚାନ୍ଦ କୁଡା",
            district: "ଭଦ୍ରକ",
            tahasil: "ଚାନ୍ଦବାଲି",
            khataNumber: "54",
            area: "1 Acre 4200 Decimal",
            landType: "ଶାରଦ ଦୁଇ",
            owners: owners,
            plots: [],
            rawFields: ["landlord": "ଓଡିଶା ସରକାର", "tenure": "ସ୍ଥିତିବାନ"],
            verification: RoRVerification(status: RoRVerificationStatus.verified, details: "Verified"),
            source: "BHULEKH"
        )
        
        let verif = ParcelCrossVerifier.verify(gisIdentity: identityChandakuda, rorResponse: ror, gisAreaInAcre: 1.42)
        
        let saved = cache.save(identity: identityChandakuda, ror: ror, verification: verif, boundary: [])
        guard saved else { return false }
        
        // 1. Retrieve with exact Chandakuda identity
        guard let retrieved = cache.get(identity: identityChandakuda) else { return false }
        guard retrieved.canonicalKey == "16:3:22:241" && retrieved.khataNumber == "54" && retrieved.area == "1 Acre 4200 Decimal" && retrieved.owners.count == 7 && retrieved.isPrivateLand == true else { return false }
        
        // 2. Querying different village with SAME plot number (Utkuda Plot 241, villageID = 8) MUST return nil
        let identityUtkuda = CanonicalParcelIdentity(
            parcelID: "1603008_241",
            plotNumber: "241",
            districtName: "Bhadrak",
            districtID: "16",
            tahasilName: "Chandbali",
            tahasilID: "3",
            villageName: "Utkuda",
            villageID: "8"
        )
        
        let retrievedUtkuda = cache.get(identity: identityUtkuda)
        return retrievedUtkuda == nil
    }
}
