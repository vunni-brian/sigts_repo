// Idempotency-Key middleware.
//
// Clients (especially mobile clients with flaky connectivity) supply an
// `Idempotency-Key` header — a UUID v4 — when issuing mutating requests.
// The first successful (or 4xx) response is captured; subsequent requests
// with the same (user, key) tuple replay that cached response without
// re-running the handler.
//
// Rules
//   * Same key + same body  -> replay cached response.
//   * Same key + different body -> 422 (request mismatch).
//   * No key on a route that requires it -> 400 (missing header).
//   * Anonymous requests use a synthetic user_id so unauthenticated retries
//     still benefit, but are still scoped to (key + body).

const crypto = require('crypto');
const { pool } = require('../config/database');
const { logger } = require('../utils/logger');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ANONYMOUS_USER_ID = '00000000-0000-0000-0000-000000000000';
const TTL_HOURS = 24;

function hashRequest(req) {
    const payload = JSON.stringify({
        method: req.method,
        path: req.originalUrl || req.url,
        body: req.body ?? null
    });
    return crypto.createHash('sha256').update(payload).digest('hex');
}

function getKey(req) {
    const raw = req.headers['idempotency-key'];
    if (!raw || typeof raw !== 'string') return null;
    const trimmed = raw.trim();
    if (!UUID_RE.test(trimmed)) return null;
    return trimmed.toLowerCase();
}

function getUserId(req) {
    return req.user?.user_id || ANONYMOUS_USER_ID;
}

// Captures res.json/res.send so we can persist the outgoing payload after
// the handler runs.
function captureResponse(res, onCapture) {
    const originalJson = res.json.bind(res);
    const originalSend = res.send.bind(res);

    res.json = (body) => {
        try { onCapture(res.statusCode || 200, body); } catch (_) {}
        return originalJson(body);
    };
    res.send = (body) => {
        // Try to detect JSON-ish payloads sent via res.send().
        let parsed = body;
        if (typeof body === 'string') {
            try { parsed = JSON.parse(body); } catch (_) { parsed = { raw: body }; }
        }
        try { onCapture(res.statusCode || 200, parsed); } catch (_) {}
        return originalSend(body);
    };
}

// `options.required` (default true) -> reject requests that don't carry a key.
//                                false -> accept (no replay protection).
function idempotency(options = {}) {
    const required = options.required !== false;

    return async (req, res, next) => {
        const key = getKey(req);

        if (!key) {
            if (!required) return next();
            return res.status(400).json({
                error: 'Idempotency-Key required',
                message: 'Mutating requests must include an Idempotency-Key header (UUID v4).'
            });
        }

        const userId = getUserId(req);
        const requestHash = hashRequest(req);

        try {
            const existing = await pool.query(
                `SELECT request_hash, status_code, response_body
                 FROM idempotency_keys
                 WHERE key = $1 AND user_id = $2 AND expires_at > CURRENT_TIMESTAMP
                 LIMIT 1`,
                [key, userId]
            );

            if (existing.rows.length > 0) {
                const row = existing.rows[0];
                if (row.request_hash !== requestHash) {
                    logger.warn('Idempotency key reused with different body', { key });
                    return res.status(422).json({
                        error: 'Idempotency key reused with different request body'
                    });
                }
                logger.info('Idempotent replay', { key, status: row.status_code });
                res.setHeader('Idempotent-Replay', 'true');
                return res.status(row.status_code).json(row.response_body);
            }
        } catch (error) {
            // If lookup fails we still want the request to go through; we'd
            // rather double-process than 500 the client.
            logger.error('Idempotency lookup failed', { error: error.message });
            return next();
        }

        // No prior record — let the handler run, capture its response.
        captureResponse(res, async (statusCode, body) => {
            // Only cache definitive responses (2xx and most 4xx). 5xx and
            // network errors should be retryable.
            if (statusCode >= 500) return;
            try {
                await pool.query(
                    `INSERT INTO idempotency_keys
                        (key, user_id, method, path, request_hash, status_code, response_body, expires_at)
                     VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, CURRENT_TIMESTAMP + ($8 || ' hours')::interval)
                     ON CONFLICT (key, user_id) DO NOTHING`,
                    [
                        key,
                        userId,
                        req.method,
                        (req.originalUrl || req.url).slice(0, 255),
                        requestHash,
                        statusCode,
                        JSON.stringify(body ?? null),
                        String(TTL_HOURS)
                    ]
                );
            } catch (error) {
                logger.error('Idempotency persist failed', { error: error.message, key });
            }
        });

        next();
    };
}

module.exports = { idempotency };
