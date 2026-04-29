// Global functions for UI actions
var Auth = new AuthManager();
var Geofence = new GeofenceManager();
var Content = new ContentManager();
var AI = new AIRecommendationEngine();
var OfflineSync = new OfflineSyncManager();
var ITAPI = new ITManagerAPI();
var Intranet = new IntranetManager();
var rareAlertPollTimer = null;

// Prevent stale UI during rapid development updates on desktop/mobile browsers.
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then((registrations) => {
        registrations.forEach((reg) => reg.unregister());
    }).catch(() => {});
    if (window.caches && window.caches.keys) {
        window.caches.keys().then((keys) => {
            keys.filter((k) => k.startsWith('bwindi-')).forEach((k) => caches.delete(k));
        }).catch(() => {});
    }
}

window.renderView = renderView;
window.handleLogin = handleLogin;
window.handleForgotPassword = handleForgotPassword;
window.handleMFASetup = handleMFASetup;
window.handleRegistration = handleRegistration;
window.downloadOfflineContent = downloadOfflineContent;
window.toggleSidebar = toggleSidebar;
window.navigateTo = navigateTo;
window.startTour = startTour;
window.endActiveTour = endActiveTour;
window.quickSighting = quickSighting;
window.clockInOut = clockInOut;
window.clearAllCache = clearAllCache;
window.exportData = exportData;
window.resetApp = resetApp;
window.addSighting = addSighting;
window.Auth = Auth;
window.Geofence = Geofence;
window.Content = Content;
window.AI = AI;
window.OfflineSync = OfflineSync;
window.ITAPI = ITAPI;
window.Intranet = Intranet;

function registerServiceWorker() {
    if (!('serviceWorker' in navigator)) return;
    navigator.serviceWorker.register('/sw.js').catch((error) => {
        console.error('Service worker registration failed:', error);
    });
}

function initHashRouting() {
    window.addEventListener('hashchange', () => {
        const hashView = window.location.hash.replace('#', '');
        if (!hashView) return;
        renderView(hashView, { updateHash: false });
    });
}

async function init() {
    showLoading();
    registerServiceWorker();
    initHashRouting();

    // Never block first paint/login on geofence startup network calls.
    Geofence.init().catch((error) => {
        console.warn('Geofence initialization deferred:', error);
    });

    const users = JSON.parse(localStorage.getItem('registeredUsers') || '[]');

    if (!users.some(user => user.role === 'it_manager')) {
        users.push(
            {
                id: 'admin1',
                name: 'IT Administrator',
                email: 'admin@bwindi.com',
                username: 'admin',
                role: 'it_manager',
                department: 'IT',
                createdAt: new Date().toISOString()
            },
            {
                id: 'guide1',
                name: 'Demo Guide',
                email: 'guide@bwindi.com',
                username: 'guide',
                role: 'guide',
                department: 'Tour Operations',
                createdAt: new Date().toISOString()
            },
            {
                id: 'tourist1',
                name: 'Demo Tourist',
                email: 'tourist@example.com',
                username: 'tourist',
                role: 'tourist',
                department: 'Visitor',
                createdAt: new Date().toISOString()
            }
        );

        localStorage.setItem('registeredUsers', JSON.stringify(users));
    }

    const requestedView = window.location.hash.replace('#', '');

    window.addEventListener('online', () => window.refreshNetworkStatusBadge?.());
    window.addEventListener('offline', () => window.refreshNetworkStatusBadge?.());
    if (rareAlertPollTimer) clearInterval(rareAlertPollTimer);
    rareAlertPollTimer = setInterval(() => window.refreshRareAlertBadge?.(), 20000);

    // Render the first screen directly and keep role-specific defaults.
    // This avoids depending on hashchange timing during initial paint.
    if (Auth.isAuthenticated()) {
        if (requestedView) {
            await renderView(requestedView, { updateHash: true });
        } else {
            const user = Auth.getCurrentUser();
            const role = user?.role || user?.userType || 'tourist';
            const defaultView = role === 'it_manager'
                ? 'it_dashboard'
                : role === 'guide'
                    ? 'guide_dashboard'
                    : 'dashboard';
            await renderView(defaultView, { updateHash: true });
        }
        return;
    }

    await renderView(requestedView === 'register' ? 'register' : 'login', { updateHash: true });
}

init();
