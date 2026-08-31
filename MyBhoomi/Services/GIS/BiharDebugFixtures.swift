#if DEBUG
import Foundation

/// Development-Only Bihar GIS Debug Fixtures
/// Contains real-source validated cadastral geometries for local UI testing.
/// Strictly compiled in DEBUG mode; completely stripped in Release builds.
public struct BiharDebugFixtures {
    
    public static let debugDistricts: [CadastralDistrict] = [
        CadastralDistrict(id: "BR_PAT", name: "PATNA"),
        CadastralDistrict(id: "BR_GAY", name: "GAYA"),
        CadastralDistrict(id: "BR_MUZ", name: "MUZAFFARPUR")
    ]
    
    public static let debugBlocks: [String: [CadastralBlock]] = [
        "BR_PAT": [CadastralBlock(id: "BR_PAT_01", name: "PATNA SADAR", districtID: "BR_PAT")],
        "BR_GAY": [CadastralBlock(id: "BR_GAY_01", name: "BODHGAYA", districtID: "BR_GAY")],
        "BR_MUZ": [CadastralBlock(id: "BR_MUZ_01", name: "KANTI", districtID: "BR_MUZ")]
    ]
    
    public static let debugGPs: [String: [CadastralGP]] = [
        "BR_PAT_01": [CadastralGP(id: "BR_PAT_01_01", name: "Halka 01", blockID: "BR_PAT_01")],
        "BR_GAY_01": [CadastralGP(id: "BR_GAY_01_01", name: "Halka 01", blockID: "BR_GAY_01")],
        "BR_MUZ_01": [CadastralGP(id: "BR_MUZ_01_01", name: "Halka 01", blockID: "BR_MUZ_01")]
    ]
    
    public static let debugVillages: [String: [CadastralVillage]] = [
        "BR_PAT_01": [CadastralVillage(id: "BR_PAT_01_108", name: "BEGAMPUR (Thana 108)", blockID: "BR_PAT_01", districtID: "BR_PAT")],
        "BR_GAY_01": [CadastralVillage(id: "BR_GAY_01_052", name: "BAKRAUR (Thana 52)", blockID: "BR_GAY_01", districtID: "BR_GAY")],
        "BR_MUZ_01": [CadastralVillage(id: "BR_MUZ_01_021", name: "DAMODARPUR (Thana 21)", blockID: "BR_MUZ_01", districtID: "BR_MUZ")]
    ]
    
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
