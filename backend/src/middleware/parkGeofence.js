// Park geofence middleware.
// Strict on first entry, lenient (50m hysteresis buffer) for users who
// were last seen inside the park within HYSTERESIS_WINDOW_MS. The buffer
// prevents GPS jitter at the boundary from triggering false exit events.

const { pool } = require('../config/database');
const { logger } = require('../utils/logger');

const ENFORCE_PARK_GEOFENCE =
    process.env.ENFORCE_PARK_GEOFENCE === 'true' || process.env.NODE_ENV === 'production';

const HYSTERESIS_BUFFER_METERS = Number(process.env.GEOFENCE_HYSTERESIS_METERS || 50);
const HYSTERESIS_WINDOW_MS = Number(process.env.GEOFENCE_HYSTERESIS_WINDOW_MS || 5 * 60 * 1000);

function readCoordinates(req) {
    const lat = Number(req.body?.lat ?? req.query?.lat ?? req.headers['x-user-lat']);
    const lng = Number(req.body?.lng ?? req.query?.lng ?? req.headers['x-user-lng']);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
    return { lat, lng };
}

// Returns true if the point is inside the park polygon, optionally with a
// `bufferMeters` slack zone outside the polygon (for hysteresis).
async function isInsidePark(lat, lng, { bufferMeters = 0 } = {}) {
    if (bufferMeters > 0) {
        const result = await pool.query(
            `SELECT (
                ST_Contains(geofence_boundary, ST_SetSRID(ST_MakePoint($1, $2), 4326))
                OR ST_DWithin(
                    geofence_boundary::geography,
                    ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
                    $3
                )
             ) AS is_inside
             FROM parks
             LIMIT 1`,
            [lng, lat, bufferMeters]
        );
        return result.rows[0]?.is_inside === true;
    }

    const result = await pool.query(
        `SELECT ST_Contains(
            geofence_boundary,
            ST_SetSRID(ST_MakePoint($1, $2), 4326)
         ) AS is_inside
         FROM parks
         LIMIT 1`,
        [lng, lat]
    );
    return result.rows[0]?.is_inside === true;
}

async function readLastInsideTime(userId) {
    if (!userId) return null;
    try {
        const result = await pool.query(
            `SELECT last_inside_park_time
             FROM tourists
             WHERE user_id = $1
             LIMIT 1`,
            [userId]
        );
        return result.rows[0]?.last_inside_park_time || null;
    } catch (_) {
        return null;
    }
}

function withinHysteresisWindow(timestamp) {
    if (!timestamp) return false;
    const t = timestamp instanceof Date ? timestamp.getTime() : new Date(timestamp).getTime();
    if (!Number.isFinite(t)) return false;
    return Date.now() - t <= HYSTERESIS_WINDOW_MS;
}

function requireInsidePark(options = {}) {
    const bypassRoles = options.bypassRoles || [];
    const requireCoordinates = options.requireCoordinates !== false;
    const strict = options.strict === true;

    return async (req, res, next) => {
        if (!ENFORCE_PARK_GEOFENCE) return next();

        const role = req.user?.user_type;
        if (role && bypassRoles.includes(role)) return next();

        const coordinates = readCoordinates(req);
        if (!coordinates) {
            if (!requireCoordinates) return next();
            return res.status(400).json({
                error: 'Location required',
                message: 'Latitude and longitude are required for park boundary validation'
            });
        }

        try {
            const lastInside = strict ? null : await readLastInsideTime(req.user?.user_id);
            const useHysteresis = !strict && withinHysteresisWindow(lastInside);
            const buffer = useHysteresis ? HYSTERESIS_BUFFER_METERS : 0;

            const inside = await isInsidePark(coordinates.lat, coordinates.lng, {
                bufferMeters: buffer
            });

            if (!inside) {
                logger.info('Geofence reject', {
                    user_id: req.user?.user_id || null,
                    used_hysteresis: useHysteresis,
                    buffer_meters: buffer
                });
                return res.status(403).json({
                    error: 'Access denied',
                    message: 'This operation is only available within park boundaries'
                });
            }

            // Refresh last_inside_park_time so subsequent requests get hysteresis.
            if (req.user?.user_id) {
                pool.query(
                    `UPDATE tourists
                     SET last_inside_park_time = CURRENT_TIMESTAMP
                     WHERE user_id = $1`,
                    [req.user.user_id]
                ).catch(() => {});
            }

            req.geofence = {
                insidePark: true,
                ...coordinates,
                used_hysteresis: useHysteresis
            };
            next();
        } catch (error) {
            logger.error('Geofence check failed', { error: error.message });
            return res.status(500).json({ error: 'Failed to validate geofence boundary' });
        }
    };
}

module.exports = {
    ENFORCE_PARK_GEOFENCE,
    HYSTERESIS_BUFFER_METERS,
    HYSTERESIS_WINDOW_MS,
    readCoordinates,
    isInsidePark,
    requireInsidePark
};
