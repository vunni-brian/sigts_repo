// backend/src/routes/users.js
const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { pool } = require('../config/database');
const { authenticateJWT, authorize } = require('../middleware/auth');

// =====================================================
// GET /api/users/profile
// Get current user profile
// =====================================================
router.get('/profile', authenticateJWT, async (req, res) => {
    const userId = req.user.user_id;

    try {
        // Get base user info
        const userResult = await pool.query(
            `SELECT user_id, username, email, phone, first_name, last_name, 
                    user_type, created_at, last_login, language_pref, profile_pic_url,
                    email_verified
             FROM users WHERE user_id = $1`,
            [userId]
        );

        if (userResult.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const profile = userResult.rows[0];

        // Get role-specific data
        if (profile.user_type === 'tourist') {
            const touristData = await pool.query(
                `SELECT nationality, date_of_birth, interests, total_visits, is_premium,
                        emergency_contact_name, emergency_contact_phone
                 FROM tourists WHERE user_id = $1`,
                [userId]
            );
            if (touristData.rows.length > 0) {
                profile.role_data = touristData.rows[0];
            }
        } else if (profile.user_type === 'guide') {
            const guideData = await pool.query(
                `SELECT license_number, specialization, years_experience, languages,
                        certification_level, average_rating, total_tours_conducted
                 FROM tour_guides WHERE user_id = $1`,
                [userId]
            );
            if (guideData.rows.length > 0) {
                profile.role_data = guideData.rows[0];
            }
        } else if (profile.user_type === 'it_manager') {
            const adminData = await pool.query(
                `SELECT employee_id, department, access_level
                 FROM it_managers WHERE user_id = $1`,
                [userId]
            );
            if (adminData.rows.length > 0) {
                profile.role_data = adminData.rows[0];
            }
        }

        res.json(profile);

    } catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({ error: 'Failed to get profile' });
    }
});

// =====================================================
// PUT /api/users/profile
// Update user profile
// =====================================================
router.put('/profile', authenticateJWT, [
    body('firstName').optional().trim().escape(),
    body('lastName').optional().trim().escape(),
    body('phone').optional().trim(),
    body('language_pref').optional().isIn(['en', 'fr', 'sw', 'ruk']),
    body('nationality').optional().trim(),
    body('interests').optional().isArray()
], async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }

    const userId = req.user.user_id;
    const { firstName, lastName, phone, language_pref, profile_pic_url, nationality, interests } = req.body;

    try {
        // Update base user info
        const updates = [];
        const values = [];
        let paramIndex = 1;

        if (firstName !== undefined) {
            updates.push(`first_name = $${paramIndex++}`);
            values.push(firstName);
        }
        if (lastName !== undefined) {
            updates.push(`last_name = $${paramIndex++}`);
            values.push(lastName);
        }
        if (phone !== undefined) {
            updates.push(`phone = $${paramIndex++}`);
            values.push(phone);
        }
        if (language_pref !== undefined) {
            updates.push(`language_pref = $${paramIndex++}`);
            values.push(language_pref);
        }
        if (profile_pic_url !== undefined) {
            updates.push(`profile_pic_url = $${paramIndex++}`);
            values.push(profile_pic_url);
        }

        if (updates.length > 0) {
            values.push(userId);
            await pool.query(
                `UPDATE users SET ${updates.join(', ')} WHERE user_id = $${paramIndex}`,
                values
            );
        }

        // Update tourist-specific data
        if (req.user.user_type === 'tourist' && (nationality !== undefined || interests !== undefined)) {
            const touristUpdates = [];
            const touristValues = [];
            let touristIndex = 1;

            if (nationality !== undefined) {
                touristUpdates.push(`nationality = $${touristIndex++}`);
                touristValues.push(nationality);
            }
            if (interests !== undefined) {
                touristUpdates.push(`interests = $${touristIndex++}`);
                touristValues.push(JSON.stringify(interests));
            }

            if (touristUpdates.length > 0) {
                touristValues.push(userId);
                await pool.query(
                    `UPDATE tourists SET ${touristUpdates.join(', ')} WHERE user_id = $${touristIndex}`,
                    touristValues
                );
            }
        }

        // Get updated profile
        const updatedResult = await pool.query(
            `SELECT user_id, username, email, phone, first_name, last_name, user_type,
                    language_pref, profile_pic_url
             FROM users WHERE user_id = $1`,
            [userId]
        );

        res.json(updatedResult.rows[0]);

    } catch (error) {
        console.error('Update profile error:', error);
        res.status(500).json({ error: 'Failed to update profile' });
    }
});

// =====================================================
// DELETE /api/users/deactivate
// Deactivate user account
// =====================================================
router.delete('/deactivate', authenticateJWT, async (req, res) => {
    const userId = req.user.user_id;

    try {
        await pool.query(
            'UPDATE users SET is_active = false WHERE user_id = $1',
            [userId]
        );

        res.json({ success: true, message: 'Account deactivated' });

    } catch (error) {
        console.error('Deactivate account error:', error);
        res.status(500).json({ error: 'Failed to deactivate account' });
    }
});

// =====================================================
// GET /api/users/:id (Admin only)
// Get user by ID
// =====================================================
router.get('/:id', authenticateJWT, authorize('it_manager'), async (req, res) => {
    const { id } = req.params;

    try {
        const result = await pool.query(
            `SELECT user_id, username, email, phone, first_name, last_name, user_type,
                    is_active, created_at, last_login
             FROM users WHERE user_id = $1`,
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json(result.rows[0]);

    } catch (error) {
        console.error('Get user error:', error);
        res.status(500).json({ error: 'Failed to get user' });
    }
});

module.exports = router;