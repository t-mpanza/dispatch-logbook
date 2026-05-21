# PWA

## Manifest (`public/manifest.webmanifest`)

```json
{
  "name": "Dispatch Diary",
  "short_name": "Diary",
  "display": "standalone",
  "orientation": "portrait",
  "start_url": "/",
  "scope": "/",
  "background_color": "#0a0a1a",
  "theme_color": "#0a0a1a",
  "icons": [{ "src": "/icon-512.png", "sizes": "512x512", "purpose": "any maskable" }]
}
```

**Known gap**: `start_url` and `scope` are hardcoded to `/`. On GitHub Pages, the app is served at `/dispatch-logbook/`. This means the installed PWA may fail to launch correctly on GitHub Pages. See `KNOWN_GAPS.md`.

---

## Service Worker (`public/sw.js`)

Hand-written (no Workbox). Cache name: `dispatch-logbook-cache-v1`.

### Strategy: Stale-While-Revalidate

```
Request
  │
  ├─ Navigation (mode === "navigate")
  │     Network first → fallback to cached "./" or "index.html"
  │
  └─ Assets (JS, CSS, images, fonts)
        Cache hit? → return cached + background-update cache
        No cache?  → fetch network + store in cache
```

### Lifecycle

| Event | Behaviour |
|---|---|
| `install` | Pre-caches `["./", "index.html", "manifest.webmanifest", "icon-512.png"]` then `skipWaiting()` |
| `activate` | Deletes all caches except `CACHE_NAME`, then `clients.claim()` |
| `fetch` | Only handles GET requests |

### Registration (`__root.tsx`)

```ts
const swUrl = `${import.meta.env.BASE_URL}sw.js`;
navigator.serviceWorker.register(swUrl);
```

SW is registered client-side on every root component mount. `BASE_URL` is `/dispatch-logbook/` on GitHub Pages, `/` otherwise.

---

## Offline behaviour

After first load:
- All JS/CSS bundles are cached by the SW
- Navigation requests fall back to the cached index shell if offline
- IndexedDB data (entries, attachments, reminders) is always local — works 100% offline
- Reminders do **not** fire when offline (no push, no background sync)

---

## Installability

Installable on Android (Chrome), iOS (Safari "Add to Home Screen"), and desktop (Chrome/Edge).

PWA meta tags in `__root.tsx`:
```html
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Diary">
```

iOS `apple-mobile-web-app-capable` makes it launch in standalone mode from the home screen.

---

## Known PWA issues

See [KNOWN_GAPS.md](./KNOWN_GAPS.md#pwa) for a full list.
