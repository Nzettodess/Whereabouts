// Firebase Cloud Messaging Service Worker for PWA Push Notifications
// Give the service worker access to Firebase Messaging.
// Note that you can only use Firebase Messaging here. Other Firebase libraries
// are not available in the service worker.
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config object.
// This should match your main Firebase configuration
firebase.initializeApp({
    apiKey: "AIzaSyCUH2iqfZZKzEOOLHhXoC7gE1YF1nIUzF8",
    authDomain: "whereabouts-510db.firebaseapp.com",
    projectId: "whereabouts-510db",
    storageBucket: "whereabouts-510db.firebasestorage.app",
    messagingSenderId: "991486277733",
    appId: "1:991486277733:web:fd67b5372c01962b086e8c"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message:', payload);

    // Customize notification here
    const notificationTitle = payload.notification?.title || 'Orbit';
    const notificationOptions = {
        body: payload.notification?.body || 'You have a new notification',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: payload.data?.tag || 'orbit-notification',
        data: payload.data,
        // Actions for interactive notifications (optional)
        actions: [
            { action: 'open', title: 'Open App' },
            { action: 'dismiss', title: 'Dismiss' }
        ]
    };

    return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
    console.log('[firebase-messaging-sw.js] Notification clicked:', event);

    event.notification.close();

    if (event.action === 'dismiss') {
        return;
    }

    // Open the app when notification is clicked
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true })
            .then((clientList) => {
                // If app is already open, focus it
                for (const client of clientList) {
                    if (client.url.includes('/') && 'focus' in client) {
                        return client.focus();
                    }
                }
                // Otherwise open a new window
                if (clients.openWindow) {
                    return clients.openWindow('/');
                }
            })
    );
});

// Handle service worker installation
self.addEventListener('install', (event) => {
    console.log('[firebase-messaging-sw.js] Service Worker installed');
    self.skipWaiting();
});

// Handle service worker activation
self.addEventListener('activate', (event) => {
    console.log('[firebase-messaging-sw.js] Service Worker activated');
    event.waitUntil(clients.claim());
});
