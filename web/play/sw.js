// v3: bump when shell assets change — stale caches clear on activate.
const FEL_PLAY_CACHE = "fel-play-v4";

self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(FEL_PLAY_CACHE).then((cache) =>
      cache.addAll(["./", "./index.html", "./manifest.webmanifest"]).catch(() => {})
    ).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== FEL_PLAY_CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  e.respondWith(
    fetch(e.request).catch(() => caches.match(e.request))
  );
});
