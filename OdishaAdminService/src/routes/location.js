const express = require('express');
const router = express.Router();
const locationService = require('../services/locationService');

/**
 * GET /location-info?lat={lat}&lng={lng}
 */
router.get('/location-info', async (req, res) => {
    const { lat, lng } = req.query;

    if (!lat || !lng) {
        return res.status(400).json({
            error: "Missing latitude or longitude parameters"
        });
    }

    // Validate numeric inputs
    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);

    if (isNaN(latitude) || isNaN(longitude)) {
        return res.status(400).json({
            error: "Invalid coordinates format"
        });
    }

    try {
        const info = await locationService.getLocationInfo(latitude, longitude);

        if (!info) {
            return res.status(404).json({
                error: "Location not found in dataset"
            });
        }

        res.json(info);
    } catch (error) {
        res.status(500).json({
            error: "Internal server error occurred while processing spatial request"
        });
    }
});

module.exports = router;
