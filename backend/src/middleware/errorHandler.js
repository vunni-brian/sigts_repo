// backend/src/middleware/errorHandler.js
const { logger } = require('../utils/logger');

/**
 * 404 Not Found handler
 */
function notFound(req, res, next) {
    const error = new Error(`Not Found - ${req.originalUrl}`);
    error.status = 404;
    next(error);
}

/**
 * Global error handler
 */
function errorHandler(err, req, res, next) {
    const statusCode = err.status || 500;
    const message = err.message || 'Internal Server Error';

    // Log error
    if (statusCode >= 500) {
        logger.error(`[${statusCode}] ${message} - ${req.method} ${req.originalUrl}`);
        logger.error(err.stack);
    } else {
        logger.warn(`[${statusCode}] ${message} - ${req.method} ${req.originalUrl}`);
    }

    // Send response
    res.status(statusCode).json({
        success: false,
        error: message,
        ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
        timestamp: new Date().toISOString()
    });
}

module.exports = { notFound, errorHandler };