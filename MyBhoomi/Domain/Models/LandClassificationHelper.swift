import Foundation

// ============================================================
// MARK: - LAND CLASSIFICATION HELPER & DESCRIPTOR
// ============================================================

/// Authoritative helper for translating, classifying, and explaining revenue land types
/// (Kissam / Classification) in Odisha, Bihar, and Indian cadastral land records.
public enum LandClassificationHelper {
    
    /// Normalizes and cleans the raw land classification name from RoR / Cadastral metadata.
    public static func cleanName(for rawClassification: String?) -> String {
        guard let raw = rawClassification?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "ଘରବାରି"
        }
        return raw
    }
    
    /// Returns a human-friendly, authoritative English explanation/meaning of the given land type.
    public static func meaning(for rawClassification: String?) -> String {
        guard let raw = rawClassification?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "Homestead / Residential land designated for dwelling and domestic living."
        }
        
        let lower = raw.lowercased()
        
        // 1. Homestead / Residential / Gharabari / Makan / Dhiha
        if lower.contains("ଘରବାରି") || lower.contains("ଘରବାରୀ") || lower.contains("ବାସସ୍ଥାନ") ||
           lower.contains("gharabari") || lower.contains("homestead") || lower.contains("residential") ||
           lower.contains("makan") || lower.contains("makaan") || lower.contains("basa") {
            return "Homestead / Residential land designated for dwelling and domestic living."
        }
        
        // 2. Sarada (1/2/3) / Wetland / Paddy / Irrigated / Do-fasali
        if lower.contains("ଶାରଦ") || lower.contains("ସାରଦ") || lower.contains("sarada") || lower.contains("sarad") ||
           lower.contains("ଧାନ") || lower.contains("paddy") || lower.contains("wetland") || lower.contains("irrigated") ||
           lower.contains("ଜଳାସିକ") || lower.contains("ଦୋଫସଲ") || lower.contains("dofasali") {
            return "Prime agricultural wetland suitable for irrigated and seasonal paddy cultivation."
        }
        
        // 3. Biali / Autumn Crop / High Land Rice
        if lower.contains("ବିଆଳି") || lower.contains("biali") || lower.contains("autumn") {
            return "Upland agricultural field suitable for autumn rice and seasonal multi-crop rotation."
        }
        
        // 4. Taila / Dry Upland / Rainfed
        if lower.contains("ତଇଳା") || lower.contains("taila") || lower.contains("toila") ||
           lower.contains("dry land") || lower.contains("upland") || lower.contains("rainfed") {
            return "Rainfed dry upland suitable for pulses, millets, and seasonal dry crops."
        }
        
        // 5. Dangar / Highland / Hilly Tract
        if lower.contains("ଡଙ୍ଗର") || lower.contains("dangar") || lower.contains("dongar") ||
           lower.contains("highland") || lower.contains("hilly") || lower.contains("pahad") {
            return "Elevated highland tract typically used for seasonal or rainfed upland agriculture."
        }
        
        // 6. Bagayat / Orchard / Plantation / Garden
        if lower.contains("ବାଗାୟତ") || lower.contains("ବଗିଚା") || lower.contains("ବାଗାନ") ||
           lower.contains("bagayat") || lower.contains("orchard") || lower.contains("plantation") ||
           lower.contains("garden") || lower.contains("bagicha") {
            return "Orchard or plantation land dedicated to fruit trees and perennial horticulture."
        }
        
        // 7. Bari / Khalabari / Kitchen Garden / Threshing Floor
        if lower.contains("ଖଳାବାରି") || lower.contains("ଖଳାବାରୀ") || lower.contains("ଖଳା") ||
           lower.contains("ବାରି") || lower.contains("khalabari") || lower.contains("bari") ||
           lower.contains("khala") || lower.contains("khari") {
            return "Enclosed garden or traditional threshing ground adjacent to the homestead."
        }
        
        // 8. Gochar / Pasture / Grazing
        if lower.contains("ଗୋଚର") || lower.contains("gochar") || lower.contains("pasture") ||
           lower.contains("grazing") || lower.contains("charagah") {
            return "Communal pasture reserved for village livestock and cattle grazing."
        }
        
        // 9. Patita / Anabadi / Fallow / Waste Land
        if lower.contains("ପତିତ") || lower.contains("ଅନାବାଦୀ") || lower.contains("patita") ||
           lower.contains("anabadi") || lower.contains("fallow") || lower.contains("waste") ||
           lower.contains("barren") {
            return "Barren or fallow uncultivated tract not currently under active farming."
        }
        
        // 10. Jalashaya / Pokhari / Pond / River / Nala / Waterbody
        if lower.contains("ଜଳାଶୟ") || lower.contains("ପୋଖରୀ") || lower.contains("ଗାଡ଼ିଆ") ||
           lower.contains("ନଦୀ") || lower.contains("ନାଳ") || lower.contains("jalashaya") ||
           lower.contains("pokhari") || lower.contains("pond") || lower.contains("river") ||
           lower.contains("water") || lower.contains("nala") || lower.contains("gadang") {
            return "Waterbody, reservoir, or channel reserved for water catchment and fishery."
        }
        
        // 11. Rasta / Road / Pathway / Gali
        if lower.contains("ରାସ୍ତା") || lower.contains("ସଡ଼କ") || lower.contains("rasta") ||
           lower.contains("road") || lower.contains("pathway") || lower.contains("street") ||
           lower.contains("gali") {
            return "Public roadway, village pathway, or government right-of-way."
        }
        
        // 12. Jangal / Forest / Ban
        if lower.contains("ଜଙ୍ଗଲ") || lower.contains("jangal") || lower.contains("jungle") ||
           lower.contains("forest") || lower.contains("ban") {
            return "Woodland or forest tract governed by state conservation regulations."
        }
        
        // 13. Sarkar / Rakhit / Government Land / Sarbasadharana
        if lower.contains("ସରକାରୀ") || lower.contains("ରକ୍ଷିତ") || lower.contains("ସର୍ବସାଧାରଣ") ||
           lower.contains("sarkari") || lower.contains("rakhit") || lower.contains("government") ||
           lower.contains("public") || lower.contains("sarbasadharan") {
            return "State-owned revenue land reserved for public infrastructure or governance."
        }
        
        // 14. Chandina / Commercial / Market / Dukan
        if lower.contains("ଚାନ୍ଦିନା") || lower.contains("chandina") || lower.contains("commercial") ||
           lower.contains("market") || lower.contains("bazaar") || lower.contains("dukan") {
            return "Non-agricultural municipal land used for commercial shops and markets."
        }
        
        // 15. Rayati / Stitiban / Settled Tenant / Kashtkar
        if lower.contains("ରୟତି") || lower.contains("ସ୍ଥିତିବାନ") || lower.contains("rayati") ||
           lower.contains("stitiban") || lower.contains("tenant") || lower.contains("kashtkar") {
            return "Permanent agricultural tenant land with hereditary possession rights."
        }
        
        // 16. Bhit / Bhita / Elevated High Ground
        if lower.contains("ଭିଟା") || lower.contains("ଢିହ") || lower.contains("bhita") ||
           lower.contains("bhit") || lower.contains("dhiha") {
            return "Elevated high-ground parcel safe from flooding, suited for settlement."
        }
        
        // 17. Abada / Krishi / Cultivable
        if lower.contains("ଆବାଦ") || lower.contains("କୃଷି") || lower.contains("abada") ||
           lower.contains("krishi") || lower.contains("cultivable") || lower.contains("agricultural") {
            return "Arable agricultural parcel suitable for farming and crop production."
        }
        
        // 18. Default fallback for specific custom/unlisted classifications
        return "Official land classification recorded in the state revenue register."
    }
}
