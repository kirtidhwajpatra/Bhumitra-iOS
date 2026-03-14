-- 1. Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Create villages table
CREATE TABLE IF NOT EXISTS villages (
    id SERIAL PRIMARY KEY,
    village_name TEXT NOT NULL,
    panchayat_name TEXT,
    tehsil_name TEXT,
    district_name TEXT,
    village_code TEXT UNIQUE,
    geom GEOMETRY(Polygon, 4326)
);

-- 3. Create spatial index for fast lookups
CREATE INDEX IF NOT EXISTS idx_villages_geom ON villages USING GIST(geom);

-- 4. Sample Test Data: Maidan Khel (Keonjhar)
-- A small 1km square around 21.6231, 85.5839
INSERT INTO villages (village_name, panchayat_name, tehsil_name, district_name, village_code, geom)
VALUES (
    'Maidan Khel', 
    'Maidan Khel GP', 
    'Keonjhar', 
    'Keonjhar', 
    '385750', 
    ST_GeomFromText('POLYGON((85.578 21.618, 85.588 21.618, 85.588 21.628, 85.578 21.628, 85.578 21.618))', 4326)
) ON CONFLICT (village_code) DO NOTHING;
