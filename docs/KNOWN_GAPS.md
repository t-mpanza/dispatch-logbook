# Known Gaps & Issues

Honest catalogue of real problems, rough edges, and missing features. Priority ordered within each section.

---

## PWA

### 🔴 P1 — Manifest `start_url` breaks GitHub Pages install

`manifest.webmanifest` hardcodes `start_url: "/"` and `scope: "/"`. On GitHub Pages the app is at `https://kiddow.github.io/dispatch-logbook/`. An installed PWA with `start_url: "/"` will navigate to the origin root, which is a 404.

**Fix**: Set `start_url` and `scope` to the correct sub-path at build time (inject via Vite plugin or use `vite-plugin-pwa` which handles this automatically).

---

### 🔴 P1 — SW precache paths are wrong for GitHub Pages

`sw.js` precaches `["./", "index.html", ...]` — these relative paths resolve correctly when the SW is at `/dispatch-logbook/sw.js` and the page is at `/dispatch-logbook/`. But if the SW ever gets registered at a different scope, these break. Using `vite-plugin-pwa` (Workbox) would generate a proper precache manifest with hashed assets.

**Bigger issue**: The SW doesn't precache the JS/CSS bundles at all — only the HTML shell and manifest. On a slow connection, the app bundles still go over the network on every visit.

---

### 🟡 P2 — No `vite-plugin-pwa` / Workbox

The hand-written SW misses:
- Asset precaching (only shell is cached)
- Cache busting (old caches aren't invalidated by content hash)
- Reliable update flow (no `waiting` → `skipWaiting` prompt)
- Background sync capability

**Fix**: Replace `public/sw.js` with `vite-plugin-pwa` (Workbox-backed). This handles GitHub Pages base path, generates a typed precache manifest, and provides a proper update flow.

---

### 🟡 P2 — No PWA update prompt

When a new version deploys, users get the old SW (stale-while-revalidate). The new SW installs in the background but won't activate until all tabs close. There's no "Update available — tap to refresh" UI.

---

## Camera

### 🔴 P1 — Stream leak on camera switch (`InAppCamera.tsx`)

In the `facingMode` effect, the cleanup code tries to stop the old stream:

```ts
useEffect(() => {
  if (stream) {  // ← `stream` is STALE here (closure over old state)
    stream.getTracks().forEach(track => track.stop());
  }
  // starts new stream...
}, [facingMode]);
```

`stream` in this effect references the value at the time the effect was created, not the current value. When `facingMode` changes, the old stream tracks are NOT stopped — they stay alive. This wastes memory and can cause the camera LED to stay on.

**Fix**: Use a `useRef` to track the current stream, not `useState`. Or restructure the effect to only start a new stream and use the cleanup return to stop it.

---

### 🟡 P2 — No camera permission state in UI

If `getUserMedia` is blocked (permission denied), the component calls `onFallback()` silently after showing a toast. There's no persistent "camera permission denied" message guiding the user to enable it in browser settings.

---

### 🟡 P2 — In-app camera captures at full resolution

`InAppCamera.capture()` draws the full `videoWidth × videoHeight` frame to canvas. A 4K camera feed gives a 4K JPEG. The blob is then passed to `onCapture` in `CaptureBar`, which calls `getImageDimensions` but does **not** call `downscaleImage` on the camera blob.

`CaptureBar.handleImage()` (for the file picker path) does call `downscaleImage`. The in-app camera path does not.

**Fix**: Call `downscaleImage` on the blob before calling `onCapture` in `CaptureBar`, or pass it through `downscaleImage` in the `onCapture` callback.

---

## Performance

### 🟡 P2 — Archive `groupEntries()` runs on every render

`archive.tsx` calls `groupEntries(entries)` directly in the render body with no `useMemo`. On a device with many entries, this O(n) grouping + sort runs on every re-render triggered by anything in the component tree.

**Fix**: `const grouped = useMemo(() => groupEntries(entries), [entries]);`

---

### 🟡 P2 — `rescheduleAll()` on every AppShell mount

`AppShell` calls `rescheduleAll()` in a `useEffect` with no dependencies (runs on every mount). Every time the user navigates between tabs (Today → Archive → Search), it re-scans all reminders from IDB and resets all timeouts.

This is functionally correct but unnecessary overhead. Should run once at app startup, or only when reminders change.

---

### 🟡 P2 — No `React.memo` on list items

`EntryListItem` re-renders whenever the parent list re-renders. On archive pages with many entries, this can be expensive.

**Fix**: `export const EntryListItem = React.memo(function EntryListItem(...) {...})`

---

### 🟢 P3 — `searchEntries` is a full table scan

Every keypress in the search box triggers a full IDB scan + in-memory filter. On large datasets this will feel slow.

**Fix**: Debounce the query (200–300ms), and consider an in-memory index on app load.

---

## UX / Missing features

### 🟡 P2 — No export/backup mechanism

All data is in IndexedDB on one device. No way to export entries as JSON, CSV, or PDF. If the user clears browser storage, everything is gone.

---

### 🟡 P2 — No edit for notes in timeline

Notes in the timeline are read-only once added. No inline edit, no delete per note (only the entire entry can be deleted).

---

### 🟢 P3 — Reminder 24h scheduling cap

`rescheduleAll()` only arms timeouts for reminders within the next 24 hours. Reminders set further out are silently ignored until the next time the app is opened close enough to the trigger time.

---

### 🟢 P3 — Tags are not typed on mobile without comma

The `TagsInput` adds tags on `Enter` or `,`. Mobile keyboards often don't show a comma key prominently. Some users may not know how to commit a tag.

---

### 🟢 P3 — No swipe gestures on Lightbox

The image lightbox only supports keyboard arrow navigation and on-screen buttons. No swipe to advance — feels like a web app, not a native app.

---

## Code quality

### 🟢 P3 — `entry.$id.tsx` is a 378-line god component

Everything is in one file: edit state, timeline render, reminder UI, lightbox trigger. Should be broken up into sub-components.

---

### 🟢 P3 — `persist()` invalidates too broadly

Invalidates `["entries"]` (wildcard) on every save, causing all entry list queries to refetch. Fine for small datasets; at scale could cause unnecessary IDB reads.
