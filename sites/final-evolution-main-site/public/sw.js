const CACHE_NAME = 'sovereign-vva-curriculum-v1';
// PWA Caching Strategy for Zero-Latency Video Playback
// Caches only authenticated curriculum assets explicitly.

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((name) => {
          if (name !== CACHE_NAME) {
            return caches.delete(name);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Stale-While-Revalidate pattern for critical video assets
self.addEventListener('fetch', (event) => {
  // Only aggressively cache the curriculum video assets
  if (event.request.url.includes('/public/sovereign-assets/curriculum/')) {
    event.respondWith(
      caches.match(event.request).then((cachedResponse) => {
        if (cachedResponse) {
          // Fire a background fetch to update the cache
          event.waitUntil(
            fetch(event.request).then((networkResponse) => {
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(event.request, networkResponse);
              });
            })
          );
          return cachedResponse;
        }

        // Not in cache, fetch and put
        return fetch(event.request).then((networkResponse) => {
          return caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, networkResponse.clone());
            return networkResponse;
          });
        });
      })
    );
  }
});