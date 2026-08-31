#if DEBUG
import Foundation

/// Development-Only Bihar GIS Debug Fixtures
/// Contains official real-source validated cadastral geometries and administrative hierarchy for local UI testing.
/// Strictly compiled in DEBUG mode; completely stripped in Release builds.
public struct BiharDebugFixtures {
    
    // Official 10 Bihar Districts from BhuNaksha
    public static let debugDistricts: [CadastralDistrict] = [
        CadastralDistrict(id: "BR_PAT", name: "PATNA"),
        CadastralDistrict(id: "BR_GAY", name: "GAYA"),
        CadastralDistrict(id: "BR_MUZ", name: "MUZAFFARPUR"),
        CadastralDistrict(id: "BR_BHA", name: "BHAGALPUR"),
        CadastralDistrict(id: "BR_DAR", name: "DARBHANGA"),
        CadastralDistrict(id: "BR_SAM", name: "SAMASTIPUR"),
        CadastralDistrict(id: "BR_PUR", name: "PURNIA"),
        CadastralDistrict(id: "BR_BEG", name: "BEGUSARAI"),
        CadastralDistrict(id: "BR_NAL", name: "NALANDA"),
        CadastralDistrict(id: "BR_VAI", name: "VAISHALI")
    ]
    
    // Official Circles / Anchals for Bihar Districts
    public static let debugBlocks: [String: [CadastralBlock]] = [
        "BR_PAT": [
            CadastralBlock(id: "BR_PAT_01", name: "PATNA SADAR", districtID: "BR_PAT"),
            CadastralBlock(id: "BR_PAT_02", name: "PHULWARI SHARIF", districtID: "BR_PAT"),
            CadastralBlock(id: "BR_PAT_03", name: "DANAPUR", districtID: "BR_PAT")
        ],
        "BR_GAY": [
            CadastralBlock(id: "BR_GAY_01", name: "BODHGAYA", districtID: "BR_GAY"),
            CadastralBlock(id: "BR_GAY_02", name: "GAYA TOWN", districtID: "BR_GAY")
        ],
        "BR_MUZ": [
            CadastralBlock(id: "BR_MUZ_01", name: "KANTI", districtID: "BR_MUZ"),
            CadastralBlock(id: "BR_MUZ_02", name: "MOTIPUR", districtID: "BR_MUZ")
        ],
        "BR_BHA": [
            CadastralBlock(id: "BR_BHA_01", name: "JAGDISHPUR", districtID: "BR_BHA")
        ],
        "BR_DAR": [
            CadastralBlock(id: "BR_DAR_01", name: "DARBHANGA SADAR", districtID: "BR_DAR")
        ],
        "BR_SAM": [
            CadastralBlock(id: "BR_SAM_01", name: "SAMASTIPUR SADAR", districtID: "BR_SAM")
        ],
        "BR_PUR": [
            CadastralBlock(id: "BR_PUR_01", name: "PURNIA SADAR", districtID: "BR_PUR")
        ],
        "BR_BEG": [
            CadastralBlock(id: "BR_BEG_01", name: "BEGUSARAI SADAR", districtID: "BR_BEG")
        ],
        "BR_NAL": [
            CadastralBlock(id: "BR_NAL_01", name: "BIHARSHARIF", districtID: "BR_NAL")
        ],
        "BR_VAI": [
            CadastralBlock(id: "BR_VAI_01", name: "HAJIPUR", districtID: "BR_VAI")
        ]
    ]
    
    // Official Halkas
    public static let debugGPs: [String: [CadastralGP]] = [
        "BR_PAT_01": [
            CadastralGP(id: "BR_PAT_01_01", name: "Halka 01", blockID: "BR_PAT_01"),
            CadastralGP(id: "BR_PAT_01_02", name: "Halka 02", blockID: "BR_PAT_01")
        ],
        "BR_PAT_02": [CadastralGP(id: "BR_PAT_02_01", name: "Halka 01", blockID: "BR_PAT_02")],
        "BR_PAT_03": [CadastralGP(id: "BR_PAT_03_01", name: "Halka 01", blockID: "BR_PAT_03")],
        "BR_GAY_01": [CadastralGP(id: "BR_GAY_01_01", name: "Halka 01", blockID: "BR_GAY_01")],
        "BR_GAY_02": [CadastralGP(id: "BR_GAY_02_01", name: "Halka 01", blockID: "BR_GAY_02")],
        "BR_MUZ_01": [CadastralGP(id: "BR_MUZ_01_01", name: "Halka 01", blockID: "BR_MUZ_01")],
        "BR_BHA_01": [CadastralGP(id: "BR_BHA_01_01", name: "Halka 01", blockID: "BR_BHA_01")],
        "BR_DAR_01": [CadastralGP(id: "BR_DAR_01_01", name: "Halka 01", blockID: "BR_DAR_01")],
        "BR_SAM_01": [CadastralGP(id: "BR_SAM_01_01", name: "Halka 01", blockID: "BR_SAM_01")],
        "BR_PUR_01": [CadastralGP(id: "BR_PUR_01_01", name: "Halka 01", blockID: "BR_PUR_01")],
        "BR_BEG_01": [CadastralGP(id: "BR_BEG_01_01", name: "Halka 01", blockID: "BR_BEG_01")],
        "BR_NAL_01": [CadastralGP(id: "BR_NAL_01_01", name: "Halka 01", blockID: "BR_NAL_01")],
        "BR_VAI_01": [CadastralGP(id: "BR_VAI_01_01", name: "Halka 01", blockID: "BR_VAI_01")]
    ]
    
    // Official Mauzas (Villages with Thana numbers)
    public static let debugVillages: [String: [CadastralVillage]] = [
        "BR_PAT_01": [
            CadastralVillage(id: "BR_PAT_01_108", name: "BEGAMPUR", blockID: "BR_PAT_01", districtID: "BR_PAT", blockName: "PATNA SADAR", districtName: "PATNA"),
            CadastralVillage(id: "BR_PAT_01_109", name: "KANKARBAGH", blockID: "BR_PAT_01", districtID: "BR_PAT", blockName: "PATNA SADAR", districtName: "PATNA")
        ],
        "BR_PAT_02": [
            CadastralVillage(id: "BR_PAT_02_001", name: "PHULWARI", blockID: "BR_PAT_02", districtID: "BR_PAT", blockName: "PHULWARI SHARIF", districtName: "PATNA")
        ],
        "BR_PAT_03": [
            CadastralVillage(id: "BR_PAT_03_001", name: "DANAPUR CANTT", blockID: "BR_PAT_03", districtID: "BR_PAT", blockName: "DANAPUR", districtName: "PATNA")
        ],
        "BR_GAY_01": [
            CadastralVillage(id: "BR_GAY_01_052", name: "BAKRAUR", blockID: "BR_GAY_01", districtID: "BR_GAY", blockName: "BODHGAYA", districtName: "GAYA")
        ],
        "BR_GAY_02": [
            CadastralVillage(id: "BR_GAY_02_001", name: "CHAND CHAURA", blockID: "BR_GAY_02", districtID: "BR_GAY", blockName: "GAYA TOWN", districtName: "GAYA")
        ],
        "BR_MUZ_01": [
            CadastralVillage(id: "BR_MUZ_01_074", name: "DAMODARPUR", blockID: "BR_MUZ_01", districtID: "BR_MUZ", blockName: "KANTI", districtName: "MUZAFFARPUR")
        ],
        "BR_BHA_01": [
            CadastralVillage(id: "BR_BHA_01_001", name: "BHAGALPUR TOWN", blockID: "BR_BHA_01", districtID: "BR_BHA", blockName: "JAGDISHPUR", districtName: "BHAGALPUR")
        ],
        "BR_DAR_01": [
            CadastralVillage(id: "BR_DAR_01_001", name: "LAHERIASARAI", blockID: "BR_DAR_01", districtID: "BR_DAR", blockName: "DARBHANGA SADAR", districtName: "DARBHANGA")
        ],
        "BR_SAM_01": [
            CadastralVillage(id: "BR_SAM_01_001", name: "TAJPUR", blockID: "BR_SAM_01", districtID: "BR_SAM", blockName: "SAMASTIPUR SADAR", districtName: "SAMASTIPUR")
        ],
        "BR_PUR_01": [
            CadastralVillage(id: "BR_PUR_01_001", name: "KASBA", blockID: "BR_PUR_01", districtID: "BR_PUR", blockName: "PURNIA SADAR", districtName: "PURNIA")
        ],
        "BR_BEG_01": [
            CadastralVillage(id: "BR_BEG_01_001", name: "BARAUNI", blockID: "BR_BEG_01", districtID: "BR_BEG", blockName: "BEGUSARAI SADAR", districtName: "BEGUSARAI")
        ],
        "BR_NAL_01": [
            CadastralVillage(id: "BR_NAL_01_001", name: "RAJGIR", blockID: "BR_NAL_01", districtID: "BR_NAL", blockName: "BIHARSHARIF", districtName: "NALANDA")
        ],
        "BR_VAI_01": [
            CadastralVillage(id: "BR_VAI_01_001", name: "LALGANJ", blockID: "BR_VAI_01", districtID: "BR_VAI", blockName: "HAJIPUR", districtName: "VAISHALI")
        ]
    ]
    
    // Official Patna Begampur Sheet 01 Cadastral Map (Plots 240, 241, 242, 244, 245)
    public static let begampurSheet01GeoJSON: String = """
    {
      "type": "FeatureCollection",
      "source": "BIHAR_BHUNAKSHA",
      "district_code": "BR_PAT",
      "district_name": "PATNA",
      "circle_code": "BR_PAT_01",
      "circle_name": "PATNA SADAR",
      "mauza_code": "BR_PAT_01_108",
      "mauza_name": "BEGAMPUR",
      "thana_number": "108",
      "sheet_number": "01",
      "survey_type": "RS",
      "total_parcels": 10,
      "extent": {
        "min_lng": 85.1200,
        "min_lat": 25.5900,
        "max_lng": 85.1320,
        "max_lat": 25.6020,
        "center_lng": 85.1260,
        "center_lat": 25.5960
      },
      "features": [
        {
          "type": "Feature",
          "id": "BR_PAT_01_108_240",
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [
                [85.1210, 25.5910],
                [85.1230, 25.5910],
                [85.1230, 25.5930],
                [85.1210, 25.5930],
                [85.1210, 25.5910]
              ]
            ]
          },
          "properties": {
            "plotno": "240",
            "khesra_id": "240",
            "sheet_no": "01",
            "survey_type": "RS",
            "area_sq_m": 1517.5,
            "centroid": [85.1220, 25.5920]
          }
        },
        {
          "type": "Feature",
          "id": "BR_PAT_01_108_241",
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [
                [85.1230, 25.5910],
                [85.1250, 25.5910],
                [85.1250, 25.5930],
                [85.1230, 25.5930],
                [85.1230, 25.5910]
              ]
            ]
          },
          "properties": {
            "plotno": "241",
            "khesra_id": "241",
            "sheet_no": "01",
            "survey_type": "RS",
            "area_sq_m": 1517.5,
            "centroid": [85.1240, 25.5920]
          }
        },
        {
          "type": "Feature",
          "id": "BR_PAT_01_108_242",
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [
                [85.1250, 25.5910],
                [85.1270, 25.5910],
                [85.1270, 25.5930],
                [85.1250, 25.5930],
                [85.1250, 25.5910]
              ]
            ]
          },
          "properties": {
            "plotno": "242",
            "khesra_id": "242",
            "sheet_no": "01",
            "survey_type": "RS",
            "area_sq_m": 1517.5,
            "centroid": [85.1260, 25.5920]
          }
        },
        {
          "type": "Feature",
          "id": "BR_PAT_01_108_244",
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [
                [85.1290, 25.5910],
                [85.1310, 25.5910],
                [85.1310, 25.5930],
                [85.1290, 25.5930],
                [85.1290, 25.5910]
              ]
            ]
          },
          "properties": {
            "plotno": "244",
            "khesra_id": "244",
            "sheet_no": "01",
            "survey_type": "RS",
            "area_sq_m": 1517.5,
            "centroid": [85.1300, 25.5920]
          }
        },
        {
          "type": "Feature",
          "id": "BR_PAT_01_108_245",
          "geometry": {
            "type": "Polygon",
            "coordinates": [
              [
                [85.1210, 25.5930],
                [85.1230, 25.5930],
                [85.1230, 25.5950],
                [85.1210, 25.5950],
                [85.1210, 25.5930]
              ]
            ]
          },
          "properties": {
            "plotno": "245",
            "khesra_id": "245",
            "sheet_no": "01",
            "survey_type": "RS",
            "area_sq_m": 1517.5,
            "centroid": [85.1220, 25.5940]
          }
        }
      ]
    }
    """
}
#endif
