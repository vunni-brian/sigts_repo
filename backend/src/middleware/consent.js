// Consent gate middleware.
//
// Reads the latest consent_log row for (user_id, consent_type). If there is
// no active grant, returns 403 with an error code the client can use to
// surface a "grant consent" prompt. Use this BEFORE any handler that writes
// or reads sensitive data such as location, analytics events, etc.

const { pool } = require('../config/database');
const { logger } = require('../utils/logger');

async function hasActiveConsent(userId, consentType) {
    const result = await pool.query(
        `SELECT granted, revoked_at
         FROM consent_log
         WHERE user_id = $1 AND consent_type = $2
         ORDER BY granted_at DESC
         LIMIT 1`,
        [userId, consentType]
    );
    if (result.rows.length === 0) return false;
    const row = result.rows[0];
    return row.granted === true && row.revoked_at === null;
}

function requireConsent(consentType) {
    return async (req, res, next) => {
        const userId = req.user?.user_id;
        if (!userId) {
            return res.status(401).json({ error: 'Authentication required' });
        }

        try {
            if (await hasActiveConsent(userId, consentType)) {
                return next();
            }
            logger.info('Consent denied', { user_id: userId, consent_type: consentType });
            return res.status(403).json({
                error: 'Consent required',
                code: 'CONSENT_REQUIRED',
                consent_type: consentType,
                message: `This action requires the user to grant consent for "${consentType}".`
            });
        } catch (error) {
            logger.error('Consent check failed', { error: error.message });
            return res.status(500).json({ error: 'Failed to verify consent' });
        }
    };
}

module.exports = { requireConsent, hasActiveConsent };
