const db = require('../config/db');
const NodeCache = require('node-cache');
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

    try {
        const { rows } = await db.query(query, [lng, lat]);

        if (rows.length === 0) {
            return null;
        }

        const result = {
            district: rows[0].district_name,
            tehsil: rows[0].tehsil_name,
            panchayat: rows[0].panchayat_name,
            village: rows[0].village_name,
            village_code: rows[0].village_code
        };

        // Store in cache
        cache.set(cacheKey, result);
        return result;
    } catch (error) {
        console.error('ERROR: ❌ Spatial Query Failed:', error.message);
        throw error;
    }
};

module.exports = {
    getLocationInfo
};
