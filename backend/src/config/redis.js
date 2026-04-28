// Redis connection configuration for SIGTS
// Used for session storage, rate limiting, and real-time features

const redis = require('redis');
const { logger } = require('../utils/logger');

let redisClient = null;
let isConnected = false;

// Initialize Redis connection
async function initializeRedis() {
    try {
        const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
        
        redisClient = redis.createClient({
            url: redisUrl,
            socket: {
                reconnectStrategy: (retries) => {
                    if (retries > 10) {
                        logger.error('Redis max reconnection attempts reached');
                        return new Error('Redis max reconnection attempts reached');
                    }
                    return Math.min(retries * 100, 3000);
                }
            }
        });

        redisClient.on('error', (err) => {
            logger.error('Redis Client Error:', err);
            isConnected = false;
        });

        redisClient.on('connect', () => {
            logger.info('Redis Client Connected');
            isConnected = true;
        });

        redisClient.on('ready', () => {
            logger.info('Redis Client Ready');
            isConnected = true;
        });

        redisClient.on('end', () => {
            logger.info('Redis Client Connection Ended');
            isConnected = false;
        });

        await redisClient.connect();
        
        return redisClient;
    } catch (error) {
        logger.error('Failed to connect to Redis:', error);
        // Return a mock client for development if Redis is not available
        if (process.env.NODE_ENV === 'development') {
            logger.warn('Running without Redis - some features may be limited');
            return createMockRedis();
        }
        throw error;
    }
}

// Create a mock Redis client for development without Redis
function createMockRedis() {
    const mockStore = new Map();
    
    return {
        get: async (key) => mockStore.get(key) || null,
        set: async (key, value, options) => {
            mockStore.set(key, value);
            return 'OK';
        },
        setEx: async (key, seconds, value) => {
            mockStore.set(key, value);
            return 'OK';
        },
        del: async (key) => {
            mockStore.delete(key);
            return 1;
        },
        incr: async (key) => {
            const current = parseInt(mockStore.get(key) || 0);
            mockStore.set(key, current + 1);
            return current + 1;
        },
        expire: async (key, seconds) => true,
        ping: async () => 'PONG',
        isReady: true,
        on: () => {},
        quit: async () => {}
    };
}

// Get Redis client instance
function getRedisClient() {
    if (!redisClient) {
        throw new Error('Redis not initialized. Call initializeRedis first.');
    }
    return redisClient;
}

// Check if Redis is connected
function isRedisConnected() {
    return isConnected && redisClient && redisClient.isReady;
}

// Close Redis connection
async function closeRedis() {
    if (redisClient) {
        await redisClient.quit();
        logger.info('Redis connection closed');
    }
}

module.exports = {
    initializeRedis,
    getRedisClient,
    isRedisConnected,
    closeRedis
};