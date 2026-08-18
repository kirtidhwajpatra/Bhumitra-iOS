"""
Coordinate Reference System (CRS) Conversion Utilities
Converts Odisha 4K GEO EPSG:3857 (Spherical Mercator) geometries to standard WGS84 (EPSG:4326).
"""

import math
from typing import Tuple, List, Dict, Any, Union

# WGS 84 / Pseudo-Mercator constants
EARTH_RADIUS = 6378137.0
ORIGIN_SHIFT = 20037508.342789244


def epsg3857_to_epsg4326(x: float, y: float) -> Tuple[float, float]:
    """
    Converts a single (x, y) coordinate from EPSG:3857 (meters) to EPSG:4326 (degrees: lng, lat).
    
    Returns:
        Tuple[float, float]: (longitude, latitude) in decimal degrees.
    """
    lng = (x / ORIGIN_SHIFT) * 180.0
    lat = (y / ORIGIN_SHIFT) * 180.0
    lat = 180.0 / math.pi * (2.0 * math.atan(math.exp(lat * math.pi / 180.0)) - math.pi / 2.0)
    return round(lng, 7), round(lat, 7)


def epsg4326_to_epsg3857(lng: float, lat: float) -> Tuple[float, float]:
    """
    Converts a single (lng, lat) coordinate from EPSG:4326 (degrees) to EPSG:3857 (meters: x, y).
    
    Returns:
        Tuple[float, float]: (x, y) in EPSG:3857 meters.
    """
    x = (lng * ORIGIN_SHIFT) / 180.0
    y = math.log(math.tan((90.0 + lat) * math.pi / 360.0)) / (math.pi / 180.0)
    y = (y * ORIGIN_SHIFT) / 180.0
    return round(x, 2), round(y, 2)


def is_likely_epsg3857(x: float, y: float) -> bool:
    """
    Heuristic to determine if coordinates are in EPSG:3857 (typically magnitude > 180).
    """
    return abs(x) > 180.0 or abs(y) > 90.0


def transform_coordinate_array(coords: Any) -> Any:
    """
    Recursively transforms a nested GeoJSON coordinate structure from EPSG:3857 to EPSG:4326.
    Handles Point [x, y, (z)], Polygon [[[x, y], ...]], MultiPolygon [[[[x, y], ...]]].
    """
    if not isinstance(coords, list) or len(coords) == 0:
        return coords

    # Base case: [x, y] or [x, y, z]
    if isinstance(coords[0], (int, float)):
        x = float(coords[0])
        y = float(coords[1])
        if is_likely_epsg3857(x, y):
            lng, lat = epsg3857_to_epsg4326(x, y)
            return [lng, lat]
        return [round(x, 7), round(y, 7)]

    # Recursive case for nested arrays
    return [transform_coordinate_array(item) for item in coords]


def transform_geojson_geometry(geometry: Dict[str, Any]) -> Dict[str, Any]:
    """
    Transforms any GeoJSON geometry object (Point, Polygon, MultiPolygon) to EPSG:4326.
    """
    if not geometry or "type" not in geometry or "coordinates" not in geometry:
        return geometry

    transformed_coords = transform_coordinate_array(geometry["coordinates"])
    return {
        "type": geometry["type"],
        "coordinates": transformed_coords,
    }


def calculate_polygon_centroid(geometry: Dict[str, Any]) -> List[float]:
    """
    Calculates the 2D bounding centroid [lng, lat] for a GeoJSON geometry.
    """
    if not geometry or "coordinates" not in geometry:
        return [0.0, 0.0]

    all_points = []

    def _extract_points(c: Any):
        if isinstance(c, list) and len(c) >= 2 and isinstance(c[0], (int, float)):
            all_points.append((float(c[0]), float(c[1])))
        elif isinstance(c, list):
            for sub in c:
                _extract_points(sub)

    _extract_points(geometry["coordinates"])

    if not all_points:
        return [0.0, 0.0]

    # If points are in 3857, convert them first
    converted_points = []
    for pt in all_points:
        if is_likely_epsg3857(pt[0], pt[1]):
            lng, lat = epsg3857_to_epsg4326(pt[0], pt[1])
            converted_points.append((lng, lat))
        else:
            converted_points.append(pt)

    avg_lng = sum(p[0] for p in converted_points) / len(converted_points)
    avg_lat = sum(p[1] for p in converted_points) / len(converted_points)
    return [round(avg_lng, 7), round(avg_lat, 7)]


def point_in_polygon(lng: float, lat: float, polygon_coords: List[List[List[float]]]) -> bool:
    """
    2D Ray-casting algorithm to test if (lng, lat) is within a Polygon's exterior ring.
    polygon_coords format: [[[lng1, lat1], [lng2, lat2], ...]]
    """
    if not polygon_coords or len(polygon_coords) == 0:
        return False

    exterior_ring = polygon_coords[0]
    n = len(exterior_ring)
    inside = False

    p1x, p1y = exterior_ring[0][0], exterior_ring[0][1]
    for i in range(1, n + 1):
        p2x, p2y = exterior_ring[i % n][0], exterior_ring[i % n][1]
        if lat > min(p1y, p2y):
            if lat <= max(p1y, p2y):
                if lng <= max(p1x, p2x):
                    if p1y != p2y:
                        xinters = (lat - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                    if p1x == p2x or lng <= xinters:
                        inside = not inside
        p1x, p1y = p2x, p2y

    return inside
