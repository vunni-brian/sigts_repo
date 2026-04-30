// Structured JSON logger for SIGTS.
// Each log line is a single JSON object that includes any context bound to
// the current request via AsyncLocalStorage (correlation_id, user_id, ...).

const fs = require('fs');
const path = require('path');
const { AsyncLocalStorage } = require('async_hooks');

const logsDir = path.join(__dirname, '../../logs');
if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
}

const LEVELS = { ERROR: 0, WARN: 1, INFO: 2, DEBUG: 3 };
const currentLevel = (process.env.LOG_LEVEL || 'INFO').toUpperCase();

const requestContext = new AsyncLocalStorage();

function getRequestContext() {
    return requestContext.getStore() || {};
}

function runWithContext(context, fn) {
    return requestContext.run({ ...context }, fn);
}

function attachToContext(extra) {
    const store = requestContext.getStore();
    if (store) Object.assign(store, extra);
}

function formatLine(level, message, args) {
    const ctx = getRequestContext();
    const meta = args.length === 1 && typeof args[0] === 'object' && args[0] !== null
        ? args[0]
        : (args.length > 0 ? { details: args.map(String).join(' ') } : {});

    return JSON.stringify({
        ts: new Date().toISOString(),
        level,
        msg: typeof message === 'string' ? message : String(message),
        ...ctx,
        ...meta
    });
}

function log(level, message, ...args) {
    if (LEVELS[level] > LEVELS[currentLevel]) return;

    const line = formatLine(level, message, args);

    if (level === 'ERROR') {
        console.error(line);
    } else if (level === 'WARN') {
        console.warn(line);
    } else {
        console.log(line);
    }

    try {
        const logFile = path.join(logsDir, `sigts-${new Date().toISOString().split('T')[0]}.log`);
        fs.appendFileSync(logFile, line + '\n');
    } catch (_) {
        // Logging must never crash the app.
    }
}

const logger = {
    error: (message, ...args) => log('ERROR', message, ...args),
    warn: (message, ...args) => log('WARN', message, ...args),
    info: (message, ...args) => log('INFO', message, ...args),
    debug: (message, ...args) => log('DEBUG', message, ...args)
};

module.exports = {
    logger,
    runWithContext,
    attachToContext,
    getRequestContext
};
