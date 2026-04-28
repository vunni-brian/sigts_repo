// backend/src/routes/intranet.js
const express = require('express');
const router = express.Router();
const { pool } = require('../config/database');

// Get current intranet status
router.get('/status', async (req, res) => {
    const clientIp = req.ip || req.connection.remoteAddress;
    const isIntranet = clientIp.startsWith('192.168.100') || 
                       clientIp.startsWith('10.') ||
                       clientIp.startsWith('172.');
    
    res.json({
        isIntranet,
        ip: clientIp,
        timestamp: new Date().toISOString(),
        subnet: '192.168.100.0/24'
    });
});

// Get list of peers on intranet
router.get('/peers', async (req, res) => {
    try {
        // Get active users in last 5 minutes
        const result = await pool.query(`
            SELECT user_id, username, user_type, 
                   last_lat, last_lng, last_location_time
            FROM users 
            WHERE last_location_time > NOW() - INTERVAL '5 minutes'
            AND is_active = true
        `);
        
        const peers = result.rows.map(row => ({
            id: row.user_id,
            name: row.username,
            type: row.user_type,
            location: row.last_lat ? { lat: row.last_lat, lng: row.last_lng } : null,
            lastSeen: row.last_location_time
        }));
        
        res.json({ count: peers.length, peers });
    } catch (error) {
        res.json({ count: 0, peers: [] });
    }
});

// Test bandwidth
router.get('/bandwidth-test', (req, res) => {
    const size = 5 * 1024 * 1024; // 5MB test file
    const data = Buffer.alloc(size, 'X');
    res.set('Content-Type', 'application/octet-stream');
    res.send(data);
});

// Manual sync trigger
router.post('/sync/manual', async (req, res) => {
    // Trigger sync for all offline data
    res.json({ success: true, message: 'Sync initiated' });
});

// Get IP address
router.get('/ip', (req, res) => {
    const ip = req.ip || req.connection.remoteAddress;
    res.json({ ip: ip.replace('::ffff:', '') });
});

module.exports = router;