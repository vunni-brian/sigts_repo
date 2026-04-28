// backend/src/routes/locations.js
const express = require('express');
const router = express.Router();
const { body, query, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const { authenticateJWT, authorize } = require('../middleware/auth');

// =====================================================
// GET /api/locations
// Get all locations (POIs) in the park
// =====================================================
router.get('/', authenticateJWT, [
    query('type').optional().isIn(['waterhole', 'viewpoint', 'camp', 'gate', 'trail', 'ranger_post']),
    query('lat').optional().isFloat(),
    query('lng').optional().isFloat(),
    query('radius').optional().isInt({ min: 1, max: 10000 }),
    query('limit').optional().isInt({ min: 1, max: 100 })
], async (req, res) => {
    const { type, lat, lng, radius, limit = 50, offset = 0 } = req.query;

    try {
        let query = `
            SELECT location_id, name, location_type, 
                   ST_X(coordinates) as longitude, ST_Y(coordinates) as latitude,
                   description, image_urls, audio_guide_url, trigger_radius,
                   facilities, best_viewing_time
            FROM locations
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        if (type) {
            query += ` AND location_type = $${paramIndex++}`;
            params.push(type);
        }

        if (lat && lng && radius) {
            query = `
                SELECT location_id, name, location_type, 
                       ST_X(coordinates) as longitude, ST_Y(coordinates) as latitude,
                       description, image_urls, audio_guide_url, trigger_radius,
                       facilities, best_viewing_time,
                       ST_Distance(
                           coordinates, 
                           ST_SetSRID(ST_MakePoint($${paramIndex++}, $${paramIndex++}), 4326)
                       ) as distance
                FROM locations
                WHERE ST_DWithin(
                    coordinates, 
                    ST_SetSRID(ST_MakePoint($${paramIndex++}, $${paramIndex++}), 4326), 
                    $${paramIndex++}
                )
            `;
            params.push(lng, lat, lng, lat, radius);
        }

        query += ` ORDER BY name LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);

        res.json({
            locations: result.rows,
            total: result.rowCount,
            limit: parseInt(limit),
            offset: parseInt(offset)
        });

    } catch (error) {
        console.error('Get locations error:', error);
        res.status(500).json({ error: 'Failed to fetch locations' });
    }
});

// =====================================================
// GET /api/locations/:id
// Get location by ID with details
// =====================================================
router.get('/:id', authenticateJWT, async (req, res) => {
    const { id } = req.params;

    try {
        const result = await pool.query(
            `SELECT l.*, 
                    ST_X(l.coordinates) as longitude, ST_Y(l.coordinates) as latitude,
                    p.name as park_name,
                    array_agg(DISTINCT a.name) FILTER (WHERE a.name IS NOT NULL) as common_animals,
                    array_agg(DISTINCT a.animal_id) FILTER (WHERE a.animal_id IS NOT NULL) as animal_ids,
                    array_agg(DISTINCT c.title_en) FILTER (WHERE c.title_en IS NOT NULL) as related_stories
             FROM locations l
             LEFT JOIN parks p ON l.park_id = p.park_id
             LEFT JOIN animal_locations al ON l.location_id = al.location_id
             LEFT JOIN animals a ON al.animal_id = a.animal_id
             LEFT JOIN cultural_locations cl ON l.location_id = cl.location_id
             LEFT JOIN cultural_narratives c ON cl.narrative_id = c.narrative_id
             WHERE l.location_id = $1
             GROUP BY l.location_id, p.park_name`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Location not found' });
        }

        res.json(result.rows[0]);

    } catch (error) {
        console.error('Get location error:', error);
        res.status(500).json({ error: 'Failed to fetch location' });
    }
});

// =====================================================
// POST /api/locations (Admin only)
// Create new location
// =====================================================
router.post('/', authenticateJWT, authorize('it_manager'), [
    body('name').notEmpty().trim(),
    body('park_id').isUUID(),
    body('location_type').isIn(['waterhole', 'viewpoint', 'camp', 'gate', 'trail', 'ranger_post']),
    body('latitude').isFloat(),
    body('longitude').isFloat(),
    body('description').optional().trim(),
    body('trigger_radius').optional().isInt({ min: 10, max: 500 })
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    const { name, park_id, location_type, latitude, longitude, description, trigger_radius, image_urls, facilities } = req.body;

    try {
        const result = await pool.query(
            `INSERT INTO locations (location_id, park_id, name, description, location_type, 
                                    coordinates, trigger_radius, image_urls, facilities)
             VALUES (gen_random_uuid(), $1, $2, $3, $4, 
                     ST_SetSRID(ST_MakePoint($5, $6), 4326), $7, $8, $9)
             RETURNING location_id`,
            [park_id, name, description, location_type, longitude, latitude, trigger_radius || 50, image_urls || [], facilities || '[]']
        );

        res.status(201).json({
            success: true,
            location_id: result.rows[0].location_id,
            message: 'Location created successfully'
        });

    } catch (error) {
        console.error('Create location error:', error);
        res.status(500).json({ error: 'Failed to create location' });
    }
});

// =====================================================
// PUT /api/locations/:id (Admin only)
// Update location
// =====================================================
router.put('/:id', authenticateJWT, authorize('it_manager'), async (req, res) => {
    const { id } = req.params;
    const updates = req.body;
    const allowedFields = ['name', 'description', 'location_type', 'latitude', 'longitude', 'trigger_radius', 'image_urls', 'facilities', 'best_viewing_time', 'is_active'];

    try {
        const updateFields = [];
        const values = [];
        let paramIndex = 1;

        for (const field of allowedFields) {
            if (updates[field] !== undefined) {
                if (field === 'latitude' || field === 'longitude') {
                    if (updates.latitude && updates.longitude) {
                        updateFields.push(`coordinates = ST_SetSRID(ST_MakePoint($${paramIndex++}, $${paramIndex++}), 4326)`);
                        values.push(updates.longitude, updates.latitude);
                    }
                } else {
                    updateFields.push(`${field} = $${paramIndex++}`);
                    values.push(updates[field]);
                }
            }
        }

        if (updateFields.length === 0) {
            return res.status(400).json({ error: 'No fields to update' });
        }

        values.push(id);
        await pool.query(
            `UPDATE locations SET ${updateFields.join(', ')} WHERE location_id = $${paramIndex}`,
            values
        );

        res.json({ success: true, message: 'Location updated successfully' });

    } catch (error) {
        console.error('Update location error:', error);
        res.status(500).json({ error: 'Failed to update location' });
    }
});

// =====================================================
// DELETE /api/locations/:id (Admin only)
// Delete location
// =====================================================
router.delete('/:id', authenticateJWT, authorize('it_manager'), async (req, res) => {
    const { id } = req.params;

    try {
        await pool.query('DELETE FROM locations WHERE location_id = $1', [id]);
        res.json({ success: true, message: 'Location deleted successfully' });

    } catch (error) {
        console.error('Delete location error:', error);
        res.status(500).json({ error: 'Failed to delete location' });
    }
});

module.exports = router;