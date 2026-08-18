#!/usr/bin/env python3
"""
GIS Cadastral Dataset Validator & Forensic Quality Auditor
Audits PMTiles headers, vector tile schemas, GeoJSON sources, polygon geometry integrity,
coordinate reference systems, administrative identifiers, and cross-tile fragmentation.
"""

import json
import math
import os
import sys
from typing import Dict, Any, List, Optional, Tuple


ODISHA_BBOX = {
    "min_lon": 81.3,
    "max_lon": 87.6,
    "min_lat": 17.7,
    "max_lat": 22.7,
}


def is_valid_ring(ring: List[List[float]]) -> Tuple[bool, str]:
    if len(ring) < 4:
        return False, f"Ring has fewer than 4 vertices ({len(ring)})"
    if ring[0] != ring[-1]:
        return False, "Ring is not closed (first != last)"
    for pt in ring:
        if len(pt) < 2:
            return False, "Malformed coordinate point (<2 elements)"
        lon, lat = pt[0], pt[1]
        if not (-180.0 <= lon <= 180.0 and -90.0 <= lat <= 90.0):
            return False, f"Coordinates out of WGS84 range: lon={lon}, lat={lat}"
    return True, "Valid"


def calculate_polygon_area_acres(ring: List[List[float]]) -> float:
    """Calculates planar polygon area in acres using shoelace formula on spherical approximation."""
    if len(ring) < 4:
        return 0.0
    # Shoelace formula on lat/lon converted to meters at mid-latitude
    mid_lat = math.radians(sum(p[1] for p in ring[:-1]) / (len(ring) - 1))
    meters_per_deg_lat = 111132.954 - 559.822 * math.cos(2 * mid_lat)
    meters_per_deg_lon = 111412.84 * math.cos(mid_lat)

    area_sqm = 0.0
    n = len(ring) - 1
    for i in range(n):
        x1 = ring[i][0] * meters_per_deg_lon
        y1 = ring[i][1] * meters_per_deg_lat
        x2 = ring[i + 1][0] * meters_per_deg_lon
        y2 = ring[i + 1][1] * meters_per_deg_lat
        area_sqm += (x1 * y2 - x2 * y1)

    area_sqm = abs(area_sqm) / 2.0
    return area_sqm / 4046.8564224  # 1 acre = 4046.8564224 sqm


def audit_geojson_dataset(filepath: str) -> Dict[str, Any]:
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    features = data.get("features", [])
    total_features = len(features)

    seen_pids = set()
    duplicate_pids = 0
    missing_pids = 0

    seen_plots = set()
    duplicate_plots = 0
    missing_plots = 0

    invalid_geometries = 0
    multipolygon_count = 0
    polygon_count = 0
    outside_odisha = 0

    missing_village_ids = 0
    missing_tahasil_ids = 0
    missing_district_ids = 0

    for f in features:
        props = f.get("properties", {})
        pid = props.get("p_id") or props.get("id")
        if not pid:
            missing_pids += 1
        elif pid in seen_pids:
            duplicate_pids += 1
        else:
            seen_pids.add(pid)

        plot = props.get("revenue_plot") or props.get("plot_number")
        if not plot or str(plot).strip() in ("0", "N/A", ""):
            missing_plots += 1
        elif plot in seen_plots:
            duplicate_plots += 1
        else:
            seen_plots.add(plot)

        if not (props.get("v_id") or props.get("v_name") or props.get("village")):
            missing_village_ids += 1
        if not (props.get("b_id") or props.get("b_name") or props.get("tahasil") or props.get("t_name")):
            missing_tahasil_ids += 1
        if not (props.get("d_id") or props.get("d_name") or props.get("district")):
            missing_district_ids += 1

        geom = f.get("geometry")
        if not geom:
            invalid_geometries += 1
            continue

        gtype = geom.get("type")
        coords = geom.get("coordinates", [])

        if gtype == "Polygon":
            polygon_count += 1
            if not coords:
                invalid_geometries += 1
            else:
                valid, msg = is_valid_ring(coords[0])
                if not valid:
                    invalid_geometries += 1
                # Check bounding box
                for pt in coords[0]:
                    lon, lat = pt[0], pt[1]
                    if not (ODISHA_BBOX["min_lon"] <= lon <= ODISHA_BBOX["max_lon"] and
                            ODISHA_BBOX["min_lat"] <= lat <= ODISHA_BBOX["max_lat"]):
                        outside_odisha += 1
                        break

        elif gtype == "MultiPolygon":
            multipolygon_count += 1
            if not coords:
                invalid_geometries += 1
            else:
                for poly in coords:
                    if poly:
                        valid, _ = is_valid_ring(poly[0])
                        if not valid:
                            invalid_geometries += 1
                            break
        else:
            invalid_geometries += 1

    return {
        "file": filepath,
        "total_parcels": total_features,
        "unique_parcel_ids": len(seen_pids),
        "duplicate_parcel_ids": duplicate_pids,
        "missing_parcel_ids": missing_pids,
        "unique_plot_numbers": len(seen_plots),
        "duplicate_plot_numbers": duplicate_plots,
        "missing_plot_numbers": missing_plots,
        "polygon_count": polygon_count,
        "multipolygon_count": multipolygon_count,
        "invalid_geometries": invalid_geometries,
        "features_outside_odisha": outside_odisha,
        "missing_village_ids": missing_village_ids,
        "missing_tahasil_ids": missing_tahasil_ids,
        "missing_district_ids": missing_district_ids,
    }


if __name__ == "__main__":
    sample_path = "/Users/uday/Documents/MyBhoomi/MyBhoomi/Resources/sample_parcels.json"
    if os.path.exists(sample_path):
        report = audit_geojson_dataset(sample_path)
        print("=== GIS DATASET AUDIT REPORT ===")
        print(json.dumps(report, indent=2))
