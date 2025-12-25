importScripts("https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.sw.js");

self.addEventListener('notificationclick', function (event) {
    const urlToOpen = new URL(event.notification.data?.url || '/', self.location.origin).href;

    const promiseChain = clients.matchAll({
        type: 'window',
        includeUncontrolled: true
    }).then((windowClients) => {
        // Check if there is already a window/tab open with the target URL
        for (let i = 0; i < windowClients.length; i++) {
            const client = windowClients[i];
            // If the client is open and focusing is allowed
            if (client.url === urlToOpen || client.url.startsWith(self.location.origin)) {
                return client.focus();
            }
        }
        // If no window/tab is open, open the URL
        return clients.openWindow(urlToOpen);
    });

    event.waitUntil(promiseChain);
});