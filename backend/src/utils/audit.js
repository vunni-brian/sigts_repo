// Audit-log helper. Append-only writes to the `audit_logs` table.
// Every admin/IT action MUST flow through this.
//
// Usage:
//   await audit(req, {
//       action: 'user.deactivate',
//       table_name: 'users',
//       record_id: targetUserId,
//       old_value: previous,
//       new_value: { ...previous, is_active: false }
//   });

const { pool } = require('../config/database');
const { logger } = require('../utils/logger');

function ipFromRequest(req) {
    if (!req) return null;
    const forwarded = req.headers?.['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.length > 0) {
        return forwarded.split(',')[0].trim();
    }
    return req.ip || req.connection?.remoteAddress || null;
}

function safeJson(value) {
    if (value === undefined || value === null) return null;
    try {
        // Stringify-then-parse normalises Buffer/Date/etc.
        return JSON.parse(JSON.stringify(value));
    } catch (_) {
        return null;
    }
}

async function audit(req, entry = {}) {
    const userId = req?.user?.user_id || null;
    const action = entry.action;
    if (!action || typeof action !== 'string') {
        logger.error('audit() called without action', { entry });
        return;
    }

    try {
        await pool.query(
            `INSERT INTO audit_logs (
                action, table_name, record_id, old_value, new_value,
                ip_address, user_agent, user_id
            ) VALUES ($1, $2, $3, $4::jsonb, $5::jsonb, $6, $7, $8)`,
            [
                action.slice(0, 100),
                entry.table_name || null,
                entry.record_id || null,
                JSON.stringify(safeJson(entry.old_value)),
                JSON.stringify(safeJson(entry.new_value)),
                ipFromRequest(req),
                req?.headers?.['user-agent']?.slice(0, 500) || null,
                userId
            ]
        );
    } catch (error) {
        // Audit failures must never block the user-facing operation, but
        // they MUST be loud in the logs so an operator notices.
        logger.error('Audit log write failed', {
            error: error.message,
            action,
            user_id: userId
        });
    }
}

module.exports = { audit };
