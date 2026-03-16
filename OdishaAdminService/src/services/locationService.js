const db = require('../config/db');
const NodeCache = require('node-cache');
const axios = require('axios'); // Requires axios
require('dotenv').config();

// Initialize cache with configurable TTL (default 1 hour)
const cache = new NodeCache({ stdTTL: process.env.CACHE_TTL || 3600 });

/**
 * Find administrative info for a given coordinate
 */
const getLocationInfo = async (lat, lng) => {
    const cacheKey = `loc_${lat}_${lng}`;

    // Check cache first
    const cachedData = cache.get(cacheKey);
    if (cachedData) {
        console.log('DEBUG: 🟢 Cache HIT for', cacheKey);
        return cachedData;
    }

    try {
        const query = `
        SELECT 
          village_name, 
          panchayat_name, 
          tehsil_name, 
          district_name, 
          village_code
        FROM villages
        WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint($1, $2), 4326))
        LIMIT 1;
        `;
        const { rows } = await db.query(query, [lng, lat]);

        if (rows.length > 0) {
            const result = {
                district: rows[0].district_name,
                tehsil: rows[0].tehsil_name,
                panchayat: rows[0].panchayat_name,
                village: rows[0].village_name,
                village_code: rows[0].village_code
            };
            cache.set(cacheKey, result);
            return result;
        }
    } catch (error) {
        console.log('DEBUG: ⚠️ DB query failed or table missing, falling back to Nominatim API');
    }

    // Fallback to Nominatim Reverse Geocoding
    try {
        const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=18&addressdetails=1`;
        const response = await axios.get(url, {
            headers: {
                'User-Agent': 'MyBhoomiApp/1.0 (Contact: admin@example.com)'
            }
        });

        const address = response.data.address || {};

        const fallbackResult = {
            district: address.state_district || address.county || 'Unknown District',
            tehsil: address.county || address.state_district || 'Unknown Tehsil',
            panchayat: address.suburb || address.village || address.town || 'Unknown Panchayat',
            village: address.village || address.hamlet || address.town || address.city || 'Unknown Village',
            village_code: 'OSM-' + (response.data.osm_id || '000')
        };

        // Store in cache
        cache.set(cacheKey, fallbackResult);
        return fallbackResult;
    } catch (fallbackError) {
        console.error('ERROR: ❌ Both Spatial Query and Nominatim Fallback Failed:', fallbackError.message);
        return null;
    }
};

module.exports = {
    getLocationInfo
};
