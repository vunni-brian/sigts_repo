// backend/src/intranet-websocket.js
const WebSocket = require('ws');

const clients = new Set();

function setupIntranetWebSocket(server) {
    const wss = new WebSocket.Server({ server, path: '/intranet' });
    
    wss.on('connection', (ws, req) => {
        const clientIp = req.socket.remoteAddress;
        console.log(`Intranet client connected: ${clientIp}`);
        clients.add(ws);
        
        // Send initial status
        ws.send(JSON.stringify({
            type: 'connected',
            peers: clients.size,
            timestamp: new Date().toISOString()
        }));
        
        // Broadcast to all clients when new client connects
        broadcastIntranetMessage({
            type: 'peer_joined',
            peer: clientIp,
            totalPeers: clients.size
        });
        
        ws.on('message', (data) => {
            try {
                const message = JSON.parse(data);
                handleIntranetMessage(ws, message);
            } catch (e) {}
        });
        
        ws.on('close', () => {
            clients.delete(ws);
            broadcastIntranetMessage({
                type: 'peer_left',
                totalPeers: clients.size
            });
        });
    });
}

function broadcastIntranetMessage(message) {
    const data = JSON.stringify(message);
    clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(data);
        }
    });
}

function handleIntranetMessage(ws, message) {
    switch(message.type) {
        case 'get_peers':
            ws.send(JSON.stringify({
                type: 'peers_list',
                peers: Array.from(clients).length
            }));
            break;
        case 'sync_request':
            broadcastIntranetMessage({
                type: 'content_update',
                source: message.source
            });
            break;
    }
}

module.exports = { setupIntranetWebSocket };