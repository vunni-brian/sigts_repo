// Rate limiting middleware for SIGTS

const rateLimit = require('express-rate-limit');

// General API rate limiter - 100 requests per 15 minutes
const rateLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: {
        error: 'Too many requests',
        message: 'Please try again after 15 minutes'
    },
    standardHeaders: true,
    legacyHeaders: false,
});

// Strict rate limiter for authentication - 5 requests per minute
const authLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 5, // limit each IP to 5 requests per minute
    message: {
        error: 'Too many login attempts',
        message: 'Please try again after 1 minute'
    },
    skipSuccessfulRequests: true, // Don't count successful logins
});

// Admin rate limiter - 50 requests per minute
const adminLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 50,
    message: {
        error: 'Too many admin requests',
        message: 'Please slow down'
    },
});

module.exports = {
    rateLimiter,
    authLimiter,
    adminLimiter
};