# Codebase Technical Analysis: UI, Event Timeline & PWA Architecture

**Target Repository:** `/home/kiddow/Desktop/Work/Despatch Diary`  
**Researcher:** `teamwork_preview_explorer_2`  
**Date:** 2026-08-13

---

## 1. Executive Summary

This investigation analyzed the frontend UI architecture, event timeline/log components, media handling & lightbox, haptic feedback integration, and PWA / offline sync mechanisms of **Dispatch Diary**.

The project is built on **React 19**, **TanStack Start** with **TanStack Router**, **Tailwind CSS v4**, **Radix UI**, **IndexedDB (`idb`)**, **Supabase**, and **Vite PWA / Capacitor**. It uses a **local-first architecture** where IndexedDB acts as the source of truth, with background synchronization to Supabase and optional native packaging via Capacitor.

---

## 2. Comprehensive Findings

### 2.1 UI Layout, Component Hierarchy, Styling & Routing

- **Routing Framework**: TanStack Router (file-based routing via `src/routes/` and generated `src/routeTree.gen.ts`).
- **Root Configuration (`src/routes/__root.tsx`)**: Sets up global head meta tags, dark theme status bar (`#0a0a1a`), Service Worker registration, Capacitor native back button listener, OTA update checks, and Supabase auth sync listener.
- **Shell Component (`src/components/AppShell.tsx`)**:
  - Enforces a mobile-first column container capped at `max-w-md mx-auto` on wide viewports.
  - Provides a fixed bottom navigation bar (`fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-md bg-surface/90 backdrop-blur-xl border-t border-border z-40`) with safe-area bottom inset handling (`pb-[max(0.5rem,env(safe-area-inset-bottom))]`).
  - Bottom Nav contains 4 navigation buttons: **Today** (`/`), **Counter** (`/counter`), **Search** (`/search`), **Archive** (`/archive`), and a **Sync Status Pill**.
- **Page Views & Component Hierarchy**:
  1.  `routes/index.tsx` (**Today View**): Displays today's entry list (`EntryListItem`), quick button to Yesterday (`/day/$date`), and floating action button (`+`) to `/entry/new`.
  2.  `routes/day.$date.tsx` (**Day Detail View**): Lists all entries for a specific `YYYY-MM-DD` with date pagination controls (`ChevronLeft`/`ChevronRight`).
  3.  `routes/entry.$id.tsx` (**Single Entry View**): Entry header with editable title and tags input, optional sticky counter header (`CounterProgress` + `CounterPanel`), chronological `EventLog`, floating note/media input bar (`FloatingNoteBar`), and image `Lightbox`.
  4.  `routes/entry.new.tsx` (**New Entry View**): Title input, tags with suggestions, quick preset templates (`QUICK_TEMPLATES`), and trip counter toggle.
  5.  `routes/counter.tsx` (**Counter Index View**): List of active/archived tyre count sessions showing total counts and trip numbers.
  6.  `routes/search.tsx` (**Search View**): Real-time search input matching titles, tags, and note content, with quick tag filter pills.
  7.  `routes/archive.tsx` (**Archive View**): Hierarchical accordion grouping entries by `Year -> Month -> Week -> Day`.
  8.  `routes/auth.tsx` (**Authentication View**): Email/password login with Supabase and offline skip option.
- **Styling Framework & Theme (`src/styles.css`)**:
  - Tailwind CSS v4 (`@import "tailwindcss" source(none); @source "../src";`).
  - Single custom dark theme ("Midnight Indigo") using OKLCH color primitives (`--background: oklch(0.13 0.04 275)`, `--primary: oklch(0.62 0.21 275)`, `--primary-glow: oklch(0.72 0.22 280)`).
  - Mobile UX optimizations: `-webkit-tap-highlight-color: transparent`, `overscroll-behavior-y: none`, custom `.no-scrollbar` utility.

---

### 2.2 Event Timeline / Event Log Components

- **Core Component**: `EventLog.tsx` (`src/components/EventLog.tsx`).
- **Data Aggregation**: Merges `notes: NoteBlock[]`, `attachments: Attachment[]`, and `trips: Trip[]` into a unified log array, sorted chronologically by timestamp (`createdAt`).
- **Grouping Mechanism**: Consecutive trip logs are automatically grouped into a single `TripGroupRow`.
- **Event Type Rendering**:
  - **Notes (`NoteRow`)**: Displayed in a surface card with `whitespace-pre-wrap` and hover-to-delete button.
  - **Audio / Voice Notes (`AttachmentView`)**: Rendered with HTML5 `<audio>` player, play/pause controls, and formatted duration (`formatDuration`).
  - **Photos (`AttachmentView`)**: Displayed with lazy-loaded `<img>` (`max-h-80 object-cover`), hover/tap overlay ("Tap to view"), caption box, and click handler triggering `Lightbox`.
  - **Videos (`AttachmentView`)**: Rendered with HTML5 `<video>` player (`controls playsInline preload="metadata"`).
  - **Files / Documents (`AttachmentView`)**: Displayed with file icon, filename, formatted size (`formatBytes`), and download link.
  - **Trip Events (`TripChip`)**: Displayed as pill chips. Scanned trips are styled in primary glow (`+N`), manual/rejected trips in orange (`+N`). If linked to a delivery slip photo (`slip:photo:<id>`), displays a `📷` emoji; if linked to slip text (`slip:text:<text>`), displays truncated slip text.

---

### 2.3 Media Gallery & Lightbox Implementation

- **In-App Camera (`src/components/InAppCamera.tsx`)**:
  - Fullscreen modal portal (`createPortal`) accessing user media stream (`getUserMedia`).
  - Uses hardware-accelerated `ImageCapture` API (`imageCapture.takePhoto()`) with Canvas fallback for fast, crisp photo capture.
  - Supports video recording using `MediaRecorder` (`video/webm;codecs=h264`, `vp8`, `webm`) with live timer.
  - Camera flip button (`facingMode`: `environment` vs `user`).
- **Image Optimization (`src/lib/image.ts`)**:
  - Automatic image downscaling via `downscaleImage()` to a maximum edge of `1800px` at JPEG quality `0.85`.
  - Uses `OffscreenCanvas` and `createImageBitmap` to process images off the main thread, reducing memory footprint from ~6 MB to ~300 KB.
- **Lightbox Gallery (`src/components/Lightbox.tsx`)**:
  - Fullscreen modal overlay (`bg-black/95 backdrop-blur-md z-[100]`).
  - Filters attachments for `kind === "image"`.
  - Supports touch pinch-zoom (`touchAction: "pinch-zoom"`), image index indicator (`1 / N`), prev/next navigation, download button (`<a download>`), and keyboard shortcuts (`Escape`, `ArrowLeft`, `ArrowRight`).
- **Media Capture Bar (`src/components/CaptureBar.tsx` & `FloatingNoteBar.tsx`)**:
  - Floating note input bar positioned at the bottom of the entry screen.
  - Attachment popup menu offering 4 options: **Audio**, **Camera**, **Video**, **Document**.
  - Provides full-screen caption modal (`createPortal`) allowing users to add captions to photos/videos before appending to the event log.

---

### 2.4 Tactile / Haptic Feedback Analysis

- **Search Conducted**: Grep searches for `vibrate`, `navigator.vibrate`, `Haptic`, `@capacitor/haptics`.
- **Finding**: **`navigator.vibrate` and native haptic feedback are currently NOT implemented anywhere in the codebase.**
- **Existing Interaction Feedback**: The app relies exclusively on CSS active scale animations (`active:scale-95`, `active:scale-90`) and visual transitions for tactile responsiveness.

---

### 2.5 PWA Setup, Caching & Sync Architecture

- **Vite PWA Plugin (`vite.config.ts`)**:
  - Strategy: `injectManifest` with `filename: "sw.js"` in `public/`.
  - `manifest.webmanifest`: App name "Dispatch Diary", short name "Diary", standalone display, portrait orientation, theme/background `#0a0a1a`, maskable 512x512 icon.
- **Service Worker (`public/sw.js`)**:
  - Manages 3 caching strategies:
    1.  _Navigation Requests_: Network-first, fallback to cached SPA shell (`index.html`).
    2.  _Vite Hashed Assets (`/assets/_-<hash>._`)_: Cache-first (immutable content hashing).
    3.  _All Other Requests_: Stale-while-revalidate.
  - Service worker registered via `useEffect` in `src/routes/__root.tsx`.
- **Offline Data Store (`src/lib/db.ts`)**:
  - Local-first architecture using IndexedDB via the `idb` wrapper.
  - Stores `entries` (with indexed fields `dayKey`, `monthKey`, `yearKey`, `updatedAt`) and `reminders`.
  - Blobs for audio, photo, video, and file attachments are stored directly inside IndexedDB records as native `Blob` objects.
- **Sync Engine (`src/lib/sync.ts`)**:
  - `pushEntry(entry)`: Asynchronously uploads entry metadata to Supabase DB (`entries` table) and binary blobs to Supabase Storage (`attachments` bucket).
  - `pullAndMerge()`: Downloads remote entries and merges them into IndexedDB using timestamp conflict resolution (`updatedAt`).
  - Auto-authentication fallback (`kiddow@dispatch.local`) if user session drops.
- **Sync Status Indicators**:
  - Global online/offline status monitored via `window` `online`/`offline` event listeners in `AppShell.tsx`.
  - Status rendered in the bottom navigation bar as a pill component:
    - `Cloud` icon + "Synced" text (primary glow) when `online === true`.
    - `CloudOff` icon + "Offline" text (muted foreground) when `online === false`.
  - _Note_: Per-entry sync status badges (`Sent`, `Synced`, `Offline saved`) are not individually rendered on `EntryListItem`.
- **Companion App View / Capacitor Shell**:
  - Configured for native Android deployment via Capacitor (`capacitor.config.ts`).
  - StatusBar configuration (`StatusBar.setOverlaysWebView`, `StatusBar.setBackgroundColor("#0a0a1a")`).
  - Android hardware back button listener for in-app history navigation and double-tap to exit.
  - Over-The-Air (OTA) update checking via `@capgo/capacitor-updater` pointing to GitHub releases.
