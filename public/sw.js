/**
 * Dispatch Diary Service Worker
 *
 * Strategy:
 *  - Navigation requests: network-first → cached SPA shell
 *  - Vite hashed assets (/assets/*-<hash>.*): cache-first (immutable URLs)
 *  - Everything else: stale-while-revalidate
 *
 * Compatible with VitePWA's useRegisterSW (registerType: "autoUpdate").
 * The SKIP_WAITING message listener is all workbox-window needs from us.
 */

const CACHE_VERSION = "v2";
const CACHE_NAME = `dispatch-diary-${CACHE_VERSION}`;

// ── Auto-update handshake with workbox-window / useRegisterSW ──────────────
self.addEventListener("message", (event) => {
  if (event.data?.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});

// ── Install: take over immediately ─────────────────────────────────────────
self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

// ── Activate: clear old caches, claim all clients ──────────────────────────
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

// ── Fetch ───────────────────────────────────────────────────────────────────
self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);

  // 1. Navigation — network-first, fallback to SPA shell
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).catch(() => {
        // scope includes the base path ("/dispatch-logbook/" on GitHub Pages, "/" otherwise)
        const scope = self.registration.scope;
        return (
          caches.match(scope) ||
          caches.match(scope + "index.html") ||
          caches.match("/")
        );
      }),
    );
    return;
  }

  // 2. Vite-hashed assets — cache-first (URLs are immutable per content hash)
  if (/\/assets\/[^/]+-[\w]{8,}\.[a-z]+(\?.*)?$/.test(url.pathname)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached;
        return fetch(request).then((response) => {
          if (response.ok) {
            caches
              .open(CACHE_NAME)
              .then((cache) => cache.put(request, response.clone()));
          }
          return response;
        });
      }),
    );
    return;
  }

  // 3. Everything else — stale-while-revalidate
  event.respondWith(
    caches.match(request).then((cached) => {
      const networkFetch = fetch(request)
        .then((response) => {
          if (response.ok) {
            caches
              .open(CACHE_NAME)
              .then((cache) => cache.put(request, response.clone()));
          }
          return response;
        })
        .catch(() => cached); // offline: return stale if available

      return cached ?? networkFetch;
    }),
  );
});
