// Per-request correlation ID middleware.
// Reads X-Correlation-Id (or X-Request-Id) from the incoming request,
// generates a fresh UUID otherwise, and stores it in AsyncLocalStorage
// so every logger call inside the request lifetime includes it.

const crypto = require('crypto');
const { runWithContext, attachToContext } = require('../utils/logger');

const HEADER_CANDIDATES = ['x-correlation-id', 'x-request-id'];

function readIncomingId(req) {
    for (const header of HEADER_CANDIDATES) {
        const value = req.headers[header];
        if (typeof value === 'string' && value.trim().length > 0 && value.length <= 128) {
            return value.trim();
        }
    }
    return null;
}

function correlationId() {
    return (req, res, next) => {
        const id = readIncomingId(req) || crypto.randomUUID();
        req.correlationId = id;
        res.setHeader('X-Correlation-Id', id);

        runWithContext({ correlation_id: id }, () => {
            // Once the auth middleware populates req.user we enrich the
            // context so downstream logs include the user_id automatically.
            const originalEnd = res.end;
            res.end = function patchedEnd(...args) {
                if (req.user?.user_id) {
                    attachToContext({ user_id: req.user.user_id });
                }
                return originalEnd.apply(this, args);
            };
            next();
        });
    };
}

module.exports = { correlationId };
