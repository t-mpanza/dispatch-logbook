# DISPATCH DIARY — FEATURE LOG
> Living document. Updated as work progresses.

---

## LEGEND
- ✅ Shipped & working
- 🚧 In progress
- 📋 Planned (approved)
- 💡 Idea / backlog
- 🔴 Known bug
- ⚰️ Removed / abandoned

---

## 📦 RELEASE HISTORY

---

### v0.1 — Initial Build
**Status: ✅ Shipped**

- ✅ PWA scaffolded on TanStack Start + Vite
- ✅ IndexedDB persistence via `idb` (all data on-device, no backend needed)
- ✅ Entry creation: title, tags, notes
- ✅ Media capture: photos (system camera), audio recording, video (system camera), file attachments
- ✅ Entry timeline — notes + media in chronological order
- ✅ Archive view (grouped by month)
- ✅ Search across entries
- ✅ Calendar/day view
- ✅ Bottom tab navigation (Today / Counter / Search / Archive)
- ✅ Trip counter v1 (Accepted / Rejected counts per trip)
- ✅ "Midnight Indigo" dark theme
- ✅ Deployed to GitHub Pages

---

### v0.2 — PWA Hardening & Counter Redesign
**Status: ✅ Shipped**

#### PWA
- ✅ Custom `public/sw.js` — proper network-first + cache-first strategy
- ✅ Switched from `virtual:pwa-register` (SSR-crash) to `useEffect`-based manual SW registration
- ✅ Fixed manifest + icons using `import.meta.env.BASE_URL` so they actually load on GitHub Pages
- ✅ `start_url` and `scope` now dynamically correct for GitHub Pages deployment

#### Camera
- ✅ Fixed camera hardware leak — moved stream to `useRef`, added `isCancelled` flag for async race conditions
- ✅ In-app camera (`getUserMedia`) now used for Photo button — bypasses system camera app
- ✅ Downscale applied consistently to both in-app camera AND file picker captures

#### Counter Redesign (v2)
- ✅ Replaced "Accepted / Rejected" with "Scanned / Manual (No-NFC)"
- ✅ Tabbed interface: Scanned tab and Manual tab
- ✅ Manual tab: slip number text input + direct camera capture for slip photo
- ✅ Session total header (Scanned + Manual = Total Tyres)
- ✅ History list in counter with orange/primary colour coding

#### Performance
- ✅ `groupEntries` in archive wrapped in `useMemo`
- ✅ `rescheduleAll` runs once per browser session (module-level flag)
- ✅ `EntryListItem` wrapped in `React.memo`

#### Docs
- ✅ `/docs/` directory created: `INDEX.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `ROUTES.md`, `COMPONENTS.md`, `LIB.md`, `DESIGN_SYSTEM.md`, `PWA.md`, `KNOWN_GAPS.md`

#### Problems Encountered & Fixed
- 🔴➜✅ **SSR crash on GitHub Actions**: `useRegisterSW` accessed `navigator` synchronously during TanStack Start prerender in Node.js — `navigator` doesn't exist on server. Fixed by replacing with `useEffect`-only registration.
- 🔴➜✅ **Manifest 404 on GitHub Pages**: Hardcoded `/manifest.webmanifest` path resolved from domain root, not from `/dispatch-logbook/` base. Fixed with `import.meta.env.BASE_URL` prefix.
- 🔴➜✅ **Camera hardware leak**: `useState` stream caused stale closures — old tracks kept running after component unmount or camera flip. Fixed with `useRef` + cancellation flag.
- 🔴➜✅ **Slip photos not downscaled**: In-app camera capture path didn't call `downscaleImage`, only the file picker path did. Fixed.

---

### v0.3 — Full App Overhaul ← CURRENT
**Status: 🚧 In progress**

> Goal: Replace the cluttered, duplicated layout with a purposeful single-source-of-truth design. Upgrade media stack. Set up for Capacitor APK.

#### Platform
- 📋 **Capacitor setup** — wrap existing web code into a real Android APK
  - APK built via GitHub Actions CI (no Android Studio needed on dev machine)
  - Sideload via USB or direct download link
- ⰰ️ Oracle VM — not needed for now. Data stays on-device (IndexedDB). No backend.
- ⰰ️ React Native — full rewrite cost not justified for this app size
- ⰰ️ NativePHP — desktop-focused, mobile is broken experiment

#### Entry View — Full Restructure
- 📋 Remove "Recent Logs" section from CounterPanel — it duplicates the event log
- 📋 Remove separate "Timeline" section label — the event log IS the page content
- 📋 **Single Unified Event Log** component — notes, media, trips all in one chronological feed
- 📋 Trip events in the log displayed as **horizontal chips**: `[+11] ─── [+12] ─── [+1]` not a stacked vertical list
- 📋 Move "Quick Note" textarea to a **floating bar** at bottom of screen (always accessible, non-intrusive)
- 📋 **Remove Reminders** from main UI — they're broken (setTimeout dies when tab closes), they're noise

#### Counter — v3
- 📋 **Expected Total** — set once per session (e.g. invoice says 100 tyres)
  - New optional field on `Entry`: `expectedTotal?: number`
  - No IndexedDB migration needed — optional field, undefined = not set
- 📋 **Progress display**: `116 / 100` with a fill bar
  - Under target → primary colour fill, shows "X remaining"
  - Exactly hit → green, "✓ Complete"
  - Over → red, "X over"
- 📋 Counter input becomes a **compact strip** (not a full tall card):
  `[SCANNED | MANUAL] | [+4] [+8] [+10] [+12] | [ LOG ]`
- 📋 Manual tab: compact slip # input inline, camera icon to capture

#### Media Stack Overhaul
- 📋 **Eliminate system camera entirely** — `capture="environment"` file inputs removed
  - Photo → InAppCamera only
  - File picker still available for importing existing files from storage
- 📋 **In-app video recording** — `MediaRecorder` API, records `video/webm` directly
  - Record button in InAppCamera (tap-hold or toggle mode)
  - Stored as video Attachment, plays in timeline
- 📋 **Front/back camera toggle** — already exists in InAppCamera, bring button to forefront visually
- 📋 **Slip photo preview** in Manual tab:
  - When photo is captured, store `attachmentId` in trip note as `"slip:photo:<id>"`
  - Event log renderer detects this prefix, finds the attachment, renders thumbnail inline under the trip chip
- 📋 **No `downscaleImage` blocking on capture** — move downscale to a background `queueMicrotask` so the camera UI closes instantly
- 📋 **Remove "Use System" fallback button** from InAppCamera — system camera is no longer the fallback

#### Known Bugs To Fix In This Release
- 🔴 Slip photos captured in Manual tab don't show as thumbnails — the `attachmentId` is not stored with the trip, only a text note is
- 🔴 Reminders `setTimeout` dies when browser tab is closed — currently a dead feature
- 🔴 "Recent Logs" in CounterPanel + "Timeline" below it = same data rendered twice

---

### v0.4 — Capacitor APK (Planned)
**Status: 📋 Planned**

- 📋 `npx cap init` + Android platform added
- 📋 GitHub Actions workflow — build signed APK using `ubuntu-latest` + Java + Android SDK in CI
- 📋 APK uploaded as GitHub Release artifact — download and sideload
- 📋 Local Notifications via `@capacitor/local-notifications` — replaces broken web reminders
- 📋 App icon + splash screen set for Capacitor

---

## 💡 BACKLOG / IDEAS

- 💡 **OCR on slip photos** — use `tesseract.js` to auto-extract slip number from a captured photo (kills manual typing entirely)
- 💡 **Oracle VM sync** — if multi-device or data backup is ever needed, a lightweight backend on the VM can store entry blobs
- 💡 **Export to PDF** — generate a daily/session report
- 💡 **Invoice QR / barcode scan** — scan invoice to auto-fill `expectedTotal` and `invoiceRef`
- 💡 **Batch quick-add** — shake gesture to trigger the counter quick-add strip

---

## 🔴 CURRENT KNOWN ISSUES

| # | Issue | Severity | Fix Planned |
|---|---|---|---|
| 1 | Slip photo not previewing in Manual trip log | Medium | v0.3 |
| 2 | Reminders don't fire when tab is closed | High | v0.4 (Capacitor local notifs) |
| 3 | Recent Logs + Timeline = duplicate data | High | v0.3 |
| 4 | System camera app opens on "Photo" button (user feedback: slow + heavy) | High | v0.3 |
| 5 | Counter panel is a tall card, pushes media/timeline far down | Medium | v0.3 |
| 6 | PWA install still shows as "shortcut" on some devices (manifest caching) | Medium | v0.3 (clear + reinstall after deploy) |
