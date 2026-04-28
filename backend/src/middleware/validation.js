// backend/src/middleware/validation.js
const { validationResult } = require('express-validator');

/**
 * Validate request using express-validator results
 */
function validateRequest(req, res, next) {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            error: 'Validation Error',
            errors: errors.array().map(err => ({
                field: err.param,
                message: err.msg,
                value: err.value
            })),
            timestamp: new Date().toISOString()
        });
    }
    next();
}

/**
 * Common validation rules
 */
const validators = {
    // User validation
    username: (field = 'username') => ({
        in: ['body'],
        notEmpty: { errorMessage: 'Username is required' },
        isLength: { options: { min: 3, max: 50 }, errorMessage: 'Username must be between 3 and 50 characters' },
        matches: { options: /^[a-zA-Z0-9_]+$/, errorMessage: 'Username can only contain letters, numbers, and underscore' }
    }),
    
    email: (field = 'email') => ({
        in: ['body'],
        notEmpty: { errorMessage: 'Email is required' },
        isEmail: { errorMessage: 'Invalid email format' },
        normalizeEmail: true
    }),
    
    password: (field = 'password') => ({
        in: ['body'],
        notEmpty: { errorMessage: 'Password is required' },
        isLength: { options: { min: 6 }, errorMessage: 'Password must be at least 6 characters' },
        matches: { options: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, errorMessage: 'Password must contain at least one uppercase letter, one lowercase letter, and one number' }
    }),
    
    // ID validation
    id: (field = 'id') => ({
        in: ['params'],
        isUUID: { errorMessage: 'Invalid ID format' }
    }),
    
    // Pagination
    pagination: () => ({
        in: ['query'],
        optional: true,
        isInt: { options: { min: 1, max: 100 }, errorMessage: 'Limit must be between 1 and 100' }
    }),
    
    // Coordinates
    latitude: (field = 'latitude') => ({
        in: ['body'],
        optional: true,
        isFloat: { options: { min: -90, max: 90 }, errorMessage: 'Latitude must be between -90 and 90' }
    }),
    
    longitude: (field = 'longitude') => ({
        in: ['body'],
        optional: true,
        isFloat: { options: { min: -180, max: 180 }, errorMessage: 'Longitude must be between -180 and 180' }
    })
};

module.exports = { validateRequest, validators };