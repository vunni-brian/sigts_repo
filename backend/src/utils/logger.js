// Simple logger utility for SIGTS

const fs = require('fs');
const path = require('path');

// Create logs directory if it doesn't exist
const logsDir = path.join(__dirname, '../../logs');
if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
}

// Log levels
const levels = {
    ERROR: 0,
    WARN: 1,
    INFO: 2,
    DEBUG: 3
};

const currentLevel = process.env.LOG_LEVEL || 'INFO';

function log(level, message, ...args) {
    if (levels[level] > levels[currentLevel]) return;
    
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] [${level}] ${message} ${args.join(' ')}`;
    
    // Console output
    if (level === 'ERROR') {
        console.error(logMessage);
    } else if (level === 'WARN') {
        console.warn(logMessage);
    } else {
        console.log(logMessage);
    }
    
    // File output
    const logFile = path.join(logsDir, `sigts-${new Date().toISOString().split('T')[0]}.log`);
    fs.appendFileSync(logFile, logMessage + '\n');
}

const logger = {
    error: (message, ...args) => log('ERROR', message, ...args),
    warn: (message, ...args) => log('WARN', message, ...args),
    info: (message, ...args) => log('INFO', message, ...args),
    debug: (message, ...args) => log('DEBUG', message, ...args)
};

module.exports = { logger };