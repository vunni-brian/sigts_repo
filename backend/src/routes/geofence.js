// backend/src/routes/geofence.js
const express = require('express');
const router = express.Router();
const { pool } = require('../config/database');
const { authenticateJWT } = require('../middleware/auth');

// =====================================================
// POST /api/geofence/validate
// Validate if user is inside park boundaries
// =====================================================
router.post('/validate', authenticateJWT, async (req, res) => {
    const { lat, lng } = req.body;

    if (!lat || !lng) {
        return res.status(400).json({ error: 'Latitude and longitude required' });
    }

    try {
        const result = await pool.query(
            `SELECT ST_Contains(
                geofence_boundary, 
                ST_SetSRID(ST_MakePoint($1, $2), 4326)
             ) as is_inside
             FROM parks 
             WHERE park_id = (SELECT park_id FROM parks LIMIT 1)`,
            [lng, lat]
        );

        const isInsidePark = result.rows[0]?.is_inside || false;

        res.json({ isInsidePark });

    } catch (error) {
        console.error('Geofence validation error:', error);
        res.status(500).json({ error: 'Failed to validate location' });
    }
});

// =====================================================
// GET /api/geofence/boundary
// Get park boundary polygon
// =====================================================
router.get('/boundary', authenticateJWT, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT ST_AsGeoJSON(geofence_boundary) as boundary
             FROM parks 
             WHERE park_id = (SELECT park_id FROM parks LIMIT 1)`
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Park boundary not found' });
        }

        const boundary = JSON.parse(result.rows[0].boundary);

        res.json(boundary);

    } catch (error) {
        console.error('Get boundary error:', error);
        res.status(500).json({ error: 'Failed to get park boundary' });
    }
});

module.exports = router;