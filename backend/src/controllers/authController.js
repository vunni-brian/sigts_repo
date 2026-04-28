// backend/src/controllers/authController.js
const { pool } = require('../config/database');
const { generateToken, hashPassword, comparePassword } = require('../middleware/auth');
const { sendVerificationEmail, sendPasswordResetEmail } = require('../services/emailService');
const { logger } = require('../utils/logger');
const { validationResult } = require('express-validator');

/**
 * Register a new user
 */
async function register(req, res) {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    const { username, email, password, firstName, lastName, phone, userType } = req.body;

    try {
        // Check if user exists
        const existing = await pool.query(
            'SELECT user_id FROM users WHERE username = $1 OR email = $2',
            [username, email]
        );
        
        if (existing.rows.length > 0) {
            return res.status(400).json({ error: 'Username or email already exists' });
        }

        // Hash password
        const hashedPassword = await hashPassword(password);

        // Insert user
        const result = await pool.query(
            `INSERT INTO users (user_id, username, password_hash, email, first_name, last_name, phone, user_type)
             VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7)
             RETURNING user_id, username, email, user_type`,
            [username, hashedPassword, email, firstName, lastName, phone, userType || 'tourist']
        );

        const user = result.rows[0];

        // Create role-specific profile
        if (user.user_type === 'tourist') {
            await pool.query(
                `INSERT INTO tourists (user_id, interests)
                 VALUES ($1, $2)`,
                [user.user_id, '[]']
            );
        } else if (user.user_type === 'guide') {
            await pool.query(
                `INSERT INTO tour_guides (user_id, license_number, certification_level)
                 VALUES ($1, $2, $3)`,
                [user.user_id, `TEMP-${Date.now()}`, 'trainee']
            );
        }

        // Send verification email (async, don't wait)
        sendVerificationEmail(email, user.user_id).catch(err => logger.error('Email error:', err));

        // Generate token
        const token = generateToken(user.user_id, user.user_type);

        res.status(201).json({
            success: true,
            message: 'Registration successful. Please check your email for verification.',
            token,
            user: {
                id: user.user_id,
                username: user.username,
                email: user.email,
                role: user.user_type
            }
        });

    } catch (error) {
        logger.error('Registration error:', error);
        res.status(500).json({ error: 'Registration failed' });
    }
}

/**
 * Login user
 */
async function login(req, res) {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    const { username, password } = req.body;

    try {
        const result = await pool.query(
            `SELECT user_id, username, password_hash, user_type, first_name, last_name, 
                    is_active, email_verified, failed_attempts, locked_until
             FROM users WHERE username = $1`,
            [username]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const user = result.rows[0];

        // Check if account is locked
        if (user.locked_until && new Date(user.locked_until) > new Date()) {
            return res.status(401).json({ 
                error: `Account locked until ${new Date(user.locked_until).toLocaleTimeString()}`
            });
        }

        if (!user.is_active) {
            return res.status(401).json({ error: 'Account deactivated. Contact support.' });
        }

        const isValid = await comparePassword(password, user.password_hash);
        if (!isValid) {
            await pool.query(
                `UPDATE users SET failed_attempts = COALESCE(failed_attempts, 0) + 1
                 WHERE user_id = $1`,
                [user.user_id]
            );
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Reset failed attempts
        await pool.query(
            `UPDATE users SET failed_attempts = 0, last_login = CURRENT_TIMESTAMP
             WHERE user_id = $1`,
            [user.user_id]
        );

        const token = generateToken(user.user_id, user.user_type);

        res.json({
            success: true,
            token,
            user: {
                id: user.user_id,
                username: user.username,
                name: `${user.first_name || ''} ${user.last_name || ''}`.trim(),
                email: user.email,
                role: user.user_type,
                emailVerified: user.email_verified
            }
        });

    } catch (error) {
        logger.error('Login error:', error);
        res.status(500).json({ error: 'Login failed' });
    }
}

/**
 * Refresh JWT token
 */
async function refreshToken(req, res) {
    const { refreshToken } = req.body;
    
    if (!refreshToken) {
        return res.status(401).json({ error: 'Refresh token required' });
    }

    try {
        const decoded = verifyToken(refreshToken);
        const newToken = generateToken(decoded.userId, decoded.userType);
        
        res.json({ token: newToken });
    } catch (error) {
        res.status(401).json({ error: 'Invalid refresh token' });
    }
}

/**
 * Logout user
 */
async function logout(req, res) {
    // In JWT-based auth, logout is handled client-side
    // Optionally blacklist the token here
    res.json({ success: true, message: 'Logged out successfully' });
}

module.exports = {
    register,
    login,
    refreshToken,
    logout
};