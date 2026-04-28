// backend/src/utils/helpers.js
const crypto = require('crypto');

/**
 * Generate random string
 */
function generateRandomString(length = 32) {
    return crypto.randomBytes(length).toString('hex');
}

/**
 * Generate OTP code
 */
function generateOTP(digits = 6) {
    return Math.floor(Math.random() * Math.pow(10, digits)).toString().padStart(digits, '0');
}

/**
 * Calculate distance between two coordinates (Haversine formula)
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3; // Earth's radius in meters
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ/2) * Math.sin(Δλ/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

    return R * c;
}

/**
 * Format currency
 */
function formatCurrency(amount, currency = 'USD') {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: currency
    }).format(amount);
}

/**
 * Format date
 */
function formatDate(date, format = 'full') {
    const d = new Date(date);
    const options = {
        full: { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' },
        date: { year: 'numeric', month: 'long', day: 'numeric' },
        time: { hour: '2-digit', minute: '2-digit' }
    };
    
    return d.toLocaleDateString('en-US', options[format]);
}

/**
 * Format file size
 */
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * Deep clone object
 */
function deepClone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

/**
 * Sleep/delay function
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry async function with exponential backoff
 */
async function retry(fn, maxRetries = 3, delay = 1000) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            return await fn();
        } catch (error) {
            if (i === maxRetries - 1) throw error;
            await sleep(delay * Math.pow(2, i));
        }
    }
}

/**
 * Extract coordinates from PostGIS point
 */
function extractCoordinates(point) {
    if (!point) return null;
    const match = point.match(/POINT\(([-\d.]+) ([-\d.]+)\)/);
    if (match) {
        return { lng: parseFloat(match[1]), lat: parseFloat(match[2]) };
    }
    return null;
}

/**
 * Build WHERE clause for filters
 */
function buildWhereClause(filters, allowedFields) {
    const conditions = [];
    const values = [];
    let paramIndex = 1;

    for (const [field, value] of Object.entries(filters)) {
        if (allowedFields.includes(field) && value !== undefined && value !== null && value !== '') {
            if (field === 'search') {
                conditions.push(`(name ILIKE $${paramIndex} OR description ILIKE $${paramIndex})`);
                values.push(`%${value}%`);
                paramIndex++;
            } else {
                conditions.push(`${field} = $${paramIndex}`);
                values.push(value);
                paramIndex++;
            }
        }
    }

    return {
        whereClause: conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '',
        values
    };
}

module.exports = {
    generateRandomString,
    generateOTP,
    calculateDistance,
    formatCurrency,
    formatDate,
    formatFileSize,
    deepClone,
    sleep,
    retry,
    extractCoordinates,
    buildWhereClause
};