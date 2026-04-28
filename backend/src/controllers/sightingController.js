// backend/src/controllers/sightingController.js
const { pool } = require('../config/database');
const { logger } = require('../utils/logger');

/**
 * Report a wildlife sighting
 */
async function reportSighting(req, res) {
    const { animal_id, location_id, number_observed, behavior, photo_urls, notes } = req.body;
    const userId = req.user.user_id;
    const userType = req.user.user_type;

    try {
        const result = await pool.query(
            `INSERT INTO sightings (sighting_id, animal_id, location_id, 
                reported_by_${userType === 'guide' ? 'guide' : 'tourist'},
                number_observed, behavior, photo_urls, notes, verification_status)
             VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8)
             RETURNING sighting_id, verification_status`,
            [animal_id, location_id, userId, number_observed, behavior, photo_urls, notes,
             userType === 'guide' ? 'verified' : 'pending']
        );

        // Update last_sighted in animal_locations
        await pool.query(
            `UPDATE animal_locations 
             SET last_sighted = CURRENT_TIMESTAMP 
             WHERE animal_id = $1 AND location_id = $2`,
            [animal_id, location_id]
        );

        // Broadcast via WebSocket
        const io = req.app.get('io');
        io.emit('new-sighting', {
            sighting_id: result.rows[0].sighting_id,
            animal_id,
            location_id,
            timestamp: new Date().toISOString()
        });

        res.status(201).json({
            success: true,
            sighting_id: result.rows[0].sighting_id,
            status: result.rows[0].verification_status,
            message: 'Sighting reported successfully'
        });

    } catch (error) {
        logger.error('Report sighting error:', error);
        res.status(500).json({ error: 'Failed to report sighting' });
    }
}

/**
 * Get recent sightings
 */
async function getRecentSightings(req, res) {
    const { lat, lng, radius = 5, limit = 20 } = req.query;

    try {
        let query = `
            SELECT s.sighting_id, s.timestamp, s.number_observed, s.behavior,
                   a.name as animal_name, a.conservation_status, a.image_urls,
                   l.name as location_name, l.location_type,
                   ST_X(l.coordinates) as longitude, ST_Y(l.coordinates) as latitude,
                   CASE WHEN s.reported_by_guide IS NOT NULL THEN 'guide' ELSE 'tourist' END as reported_by,
                   s.verification_status, s.photo_urls
            FROM sightings s
            JOIN animals a ON s.animal_id = a.animal_id
            JOIN locations l ON s.location_id = l.location_id
            WHERE s.verification_status = 'verified'
        `;
        const params = [];
        let paramIndex = 1;

        if (lat && lng) {
            query += ` AND ST_DWithin(l.coordinates, ST_SetSRID(ST_MakePoint($${paramIndex++}, $${paramIndex++}), 4326), $${paramIndex++})`;
            params.push(lng, lat, radius * 1000);
        }

        query += ` ORDER BY s.timestamp DESC LIMIT $${paramIndex++}`;
        params.push(limit);

        const result = await pool.query(query, params);

        res.json(result.rows);

    } catch (error) {
        logger.error('Get recent sightings error:', error);
        res.status(500).json({ error: 'Failed to fetch sightings' });
    }
}

module.exports = { reportSighting, getRecentSightings };