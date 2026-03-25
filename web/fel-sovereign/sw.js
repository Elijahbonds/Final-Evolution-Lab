/* Final Evolution — minimal PWA shell. Point `navigator.serviceWorker.register` at this file from your site root.
   Game assets load from your WASM / Pixel Streaming host; cache policy should be versioned per sovereign release. */
const FEL_CACHE = "fel-sovereign-v1";

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(FEL_CACHE).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== FEL_CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") {
    return;
  }
  event.respondWith(fetch(event.request).catch(() => caches.match(event.request)));
});
