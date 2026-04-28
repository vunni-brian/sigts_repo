// backend/src/utils/validators.js

/**
 * Validate email format
 */
function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

/**
 * Validate phone number (Ugandan format)
 */
function isValidPhone(phone) {
    const phoneRegex = /^(\+256|0)[7-9][0-9]{8}$/;
    return phoneRegex.test(phone);
}

/**
 * Validate UUID
 */
function isValidUUID(uuid) {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(uuid);
}

/**
 * Validate coordinates
 */
function isValidCoordinates(lat, lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

/**
 * Validate password strength
 */
function isStrongPassword(password) {
    // At least 8 characters, one uppercase, one lowercase, one number
    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
    return passwordRegex.test(password);
}

/**
 * Validate date format (YYYY-MM-DD)
 */
function isValidDate(dateString) {
    const date = new Date(dateString);
    return date instanceof Date && !isNaN(date);
}

/**
 * Sanitize input (remove XSS)
 */
function sanitizeInput(input) {
    if (typeof input !== 'string') return input;
    return input
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

/**
 * Validate and parse pagination parameters
 */
function parsePagination(query) {
    const limit = Math.min(parseInt(query.limit) || 20, 100);
    const offset = parseInt(query.offset) || 0;
    const page = Math.floor(offset / limit) + 1;
    
    return { limit, offset, page };
}

/**
 * Validate sort parameters
 */
function parseSort(query, allowedFields) {
    const sortField = query.sort_by;
    const sortOrder = query.sort_order === 'desc' ? 'DESC' : 'ASC';
    
    if (sortField && allowedFields.includes(sortField)) {
        return { field: sortField, order: sortOrder };
    }
    return { field: 'created_at', order: 'DESC' };
}

module.exports = {
    isValidEmail,
    isValidPhone,
    isValidUUID,
    isValidCoordinates,
    isStrongPassword,
    isValidDate,
    sanitizeInput,
    parsePagination,
    parseSort
};