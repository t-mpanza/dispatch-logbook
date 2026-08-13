# Codebase Analysis & UI Audit Report — Milestone 1 (Explorer 2)

> **Target Codebase**: Dispatch Diary (`/home/kiddow/Desktop/Work/Despatch Diary`)  
> **Audit Date**: 2026-08-13  
> **Focus**: Despatch / Loading Sheet UI & Compliance (Requirement R1) + Timeline, Event Log & Media UI (Requirement R4)

---

## Executive Summary

This investigation conducted a comprehensive code audit of the Despatch Diary React/TanStack application, focusing specifically on **Requirement R1** (Despatch Loading Sheet Compliance System) and **Requirement R4** (WhatsApp/Telegram-Style UI & Tactile Feedback).

The codebase exhibits a clean, modern modular architecture built on **React 19**, **TanStack Router** (file-based routing under `src/routes/`), **IndexedDB** (`idb`), **Tailwind CSS v4**, and **Supabase**. All core UI components for both R1 and R4 are fully implemented, functional, and integrated into the primary entry workflow (`src/routes/entry.$id.tsx`).

---

## 1. Source Code Structure & Directory Architecture

```
src/
├── components/           # UI components & interactive overlays
│   ├── AppShell.tsx         # Root mobile container & 4-tab bottom navigation bar
│   ├── AttachmentView.tsx   # Per-kind media renderer (image, video, audio, file)
│   ├── CaptureBar.tsx       # 4-option popover menu (Audio, Camera, Video, File)
│   ├── CounterPanel.tsx     # Tyre counter stepper, quick-pick (+2, +4, +8, +10) & manual slip logger
│   ├── CounterProgress.tsx  # Total scanned vs expected invoice tyre count progress bar
│   ├── EntryListItem.tsx    # Card representation of entries in lists (Today, Search, Archive)
│   ├── EventLog.tsx         # Chronological stream of notes, attachments & trip chips
│   ├── FloatingNoteBar.tsx  # Bottom-anchored note input bar with integrated CaptureBar
│   ├── InAppCamera.tsx      # Full-screen custom viewfinder modal (photo & video modes)
│   ├── Lightbox.tsx         # Full-screen image lightbox gallery modal with navigation
│   ├── LoadingSheet.tsx     # 7-active column compliance Loading Sheet table component
│   ├── TagsInput.tsx        # Pill tag input with autocomplete suggestions
│   ├── VoiceRecorder.tsx    # Audio recording panel with live elapsed timer
│   └── ui/                  # Radix UI / shadcn base UI primitives
├── lib/                  # Utilities, domain business logic & export engines
│   ├── chat-bubbles.ts      # Chat bubble view model converter & lightbox state helpers
│   ├── db.ts                # IndexedDB persistence layer (IDB store operations)
│   ├── export-pdf.ts        # Printable PDF report generator & CSS print rules
│   ├── export-whatsapp.ts   # Formatted WhatsApp text generator & native share/clipboard fallback
│   ├── haptics.ts           # Haptic feedback wrapper (`navigator.vibrate`)
│   ├── image.ts             # Image downscaling (`OffscreenCanvas`) & metadata extraction
│   ├── loading-presets.ts   # Preset route auto-fill & STOCKS daily counter logic
│   └── types.ts             # TypeScript interface contracts (`Entry`, `LoadingSheetTrip`, etc.)
└── routes/               # TanStack file-based routes
    ├── __root.tsx           # Main application root layout & global toaster
    ├── index.tsx            # Today's entries dashboard (`/`)
    ├── counter.tsx          # Trip counting counter sessions listing (`/counter`)
    ├── entry.$id.tsx        # Full entry detail view (Loading sheet + Timeline + Counter)
    ├── entry.new.tsx        # New entry creation page
    ├── day.$date.tsx        # Day drilldown archive view
    ├── search.tsx           # Entry search page
    ├── archive.tsx          # Monthly/Yearly historical archive view
    └── auth.tsx             # Supabase authentication view
```

---

## 2. Requirement R1: Despatch Loading Sheet Compliance System Audit

Requirement R1 specifies a digital Despatch Loading Sheet compliance table replacing paper loading sheets, supporting presets, manual truck additions, auto-calculations, and PDF/WhatsApp export functions.

### 2.1 Header & Despatcher Configuration (`LoadingSheet.tsx`, `db.ts`)

- **Despatcher Name**: Editable input field in the header. Interacts directly with IndexedDB (`getDespatcherName()` and `saveDespatcherName()`) to persist user preference across sessions.
- **Date Header**: Displays formatted date label (`fmtDayLabel(entry.createdAt)`) alongside the ISO date key (`entry.dayKey`).

### 2.2 Active 7-Column Table (`LoadingSheet.tsx`)

The loading sheet renders exactly 7 active columns in accordance with despatch compliance:

1. **Reg**: Truck registration plate input (e.g. `MN05XNGP`). Automatically converts user input to uppercase (`value.toUpperCase()`).
2. **Driver Name**: Text input for driver identification (e.g. `Neil`).
3. **Trip ID**: Preset dropdown selector combined with custom text input when `"CUSTOM"` is selected.
4. **Start Time**: `<input type="time">` field mapping standard `HH:mm` format to epoch timestamps (`startTime`).
5. **Finished Time**: `<input type="time">` field mapping `HH:mm` format to epoch timestamps (`finishTime`).
6. **Minutes**: Auto-calculated duration in minutes derived via `calculateDurationMinutes(startTime, finishTime)`. Read-only tabular-num display.
7. **Quantity Loaded**: Numeric input for tyres loaded on the trip.

- **Legacy Column Cleanup**: Explicitly omits obsolete paper sheet columns (Arrival Time, Departure Time, Tyre Pressure, PSI).

### 2.3 Presets & Auto-Fill System (`loading-presets.ts`)

The preset system (`getPresetFill()`) supports standard route keys and dynamic rules:

- **`STOCKS`**: Dynamic preset that auto-increments daily (`STOCKS 1`, `STOCKS 2`, etc.). Scans existing trips on today's sheet and checks `localStorage` (`dispatch_stocks_counter`).
- **`NLH`**: Auto-fills driver name (`"Neil"`) and registration plate (`"MN05XNGP"`).
- **`DBN`**, **`NLS`**, **`BLOEM`**, **`PLK`**, **`TIREPOINT`**: Route presets populating `tripId`.
- **`CUSTOM`**: Clears pre-filled trip ID for freeform text entry.

### 2.4 Standalone Manual Truck Rows (`LoadingSheet.tsx`)

- **`+ Add Standalone Truck Row`**: Appends a new `LoadingSheetTrip` entry to `entry.loadingSheetTrips`.
- Sets default values: `quantityLoaded: 2`, `isManual: true`, current timestamp for `startTime` and `finishTime`.
- Supports deletion of individual rows via row delete action icon (`Trash2`).

### 2.5 Table Calculations & Summary Footer (`LoadingSheet.tsx`, `loading-presets.ts`)

- **`calculateLoadingSheetTotals()`**: Sums total tyres loaded (`totalTyresLoaded`) and total loading duration minutes (`totalLoadingTimeMinutes`).
- **Summary Footer**: Displays total trip count, formatted loading duration (`Xh Ym (Z mins)` or `Z mins`), and total tyres loaded count with primary glow accent styling.

### 2.6 Compliance Export Capabilities

- **Printable PDF Export (`export-pdf.ts`)**:
  - Dynamically constructs a temporary `#printable-loading-sheet` HTML node with dedicated `@media print` rules for clean A4 portrait export.
  - Includes report title ("DESPATCH LOADING SHEET REPORT"), despatcher name, date, full 7-column table, totals summary box, signature line, and generation timestamp.
  - Automatically invokes `window.print()`.
- **Formatted WhatsApp Share (`export-whatsapp.ts`)**:
  - Formats loading sheet data into WhatsApp markdown text with emojis:
    - Header (`📋 *DESPATCH LOADING SHEET*`, date, despatcher name).
    - Itemized trip list (`1. [STOCKS 1] MN05XNGP (Neil) - 50 tyres (45 mins)`).
    - Summary totals (`📦 TOTAL TYRES LOADED`, `⏱️ TOTAL LOADING TIME`).
  - Supports `navigator.clipboard.writeText`, native Web Share API (`navigator.share`), and fallback to `https://api.whatsapp.com/send?text=...`.

---

## 3. Requirement R4: WhatsApp/Telegram-Style Timeline & Media Audit

Requirement R4 specifies an operational timeline interface inspired by WhatsApp/Telegram, complete with rich media attachments, voice recording, lightbox modal, and tactile haptic feedback.

### 3.1 Timeline Layout & Event Stream (`EventLog.tsx`, `chat-bubbles.ts`, `entry.$id.tsx`)

- **Event Log (`EventLog.tsx`)**: Merges notes (`NoteBlock`), attachments (`Attachment`), and counter trips (`Trip`) into a single chronological stream sorted by `createdAt`.
- **Chat Bubbles Helper (`chat-bubbles.ts`)**: `entryToChatBubbles()` transforms entry data into a structured `ChatBubbleItem` model containing `kind`, `syncStatus`, `timeString`, and content payload.
- **Auto-Scroll Mechanics**: `entry.$id.tsx` uses a `scrollRef` anchor to auto-scroll the timeline to the bottom when new items are added or when the entry loads.

### 3.2 Floating Note & Attachment Capture Bar (`FloatingNoteBar.tsx`, `CaptureBar.tsx`)

- **`FloatingNoteBar.tsx`**: Bottom-fixed input container with auto-expanding `textarea` (1 row idle, 3 rows expanded on focus). Submits on `Enter` (without `Shift`), dismisses on `Escape`.
- **`CaptureBar.tsx`**: Popover menu providing 4 media capture actions:
  - **Audio**: Activates `<VoiceRecorder>`.
  - **Camera**: Opens `<InAppCamera defaultMode="photo">`.
  - **Video**: Opens `<InAppCamera defaultMode="video">`.
  - **Document**: Triggers native file selector (`<input type="file" multiple>`).
- **Caption Overlay**: Portals a full-screen caption screen before committing photos or videos to the log.

### 3.3 Voice Recording Engine (`VoiceRecorder.tsx`)

- Micro-app overlay utilizing `navigator.mediaDevices.getUserMedia({ audio: true })` and `MediaRecorder` (`audio/webm`).
- Real-time elapsed timer updating every 200ms via `setInterval`.
- Includes animated recording pulse indicator, "Stop & save" action, and "Cancel" action with proper track cleanup (`stream.getTracks().forEach(t => t.stop())`).

### 3.4 In-App Camera Engine (`InAppCamera.tsx`)

- Custom full-screen modal overlay created via React portal (`createPortal`).
- Utilizes rear camera (`facingMode: "environment"`) by default, with camera toggle if multiple video input devices exist.
- Supports hardware-accelerated `ImageCapture` API with fallback to 2D canvas frame export (`image/jpeg`, quality 0.88).
- Includes video recording mode using `MediaRecorder` with codec detection (`h264` / `vp8` / `webm`).

### 3.5 Media Preview & Lightbox Modal (`AttachmentView.tsx`, `Lightbox.tsx`)

- **`AttachmentView.tsx`**: Specialized card component rendering media attachments based on `kind`:
  - **Image**: `<img>` element with Blob URL creation (`URL.createObjectURL`), hover overlay ("Tap to view"), and click trigger for Lightbox.
  - **Video**: `<video controls playsInline>` element.
  - **Audio**: `<audio controls>` player with duration label (`formatDuration`).
  - **File**: Download card featuring icon, filename, and formatted byte size (`formatBytes`).
- **`Lightbox.tsx`**: Full-screen modal (z-100, `bg-black/95`, backdrop blur) filtering entry attachments to `kind === "image"`:
  - Image counter (`1 / N`).
  - Keyboard navigation (`Escape` to close, `ArrowLeft` / `ArrowRight` to navigate).
  - Download action button for full-resolution blob image.
  - Body scroll locking (`document.body.style.overflow = "hidden"`).
  - Touch pinch-zoom CSS (`touchAction: "pinch-zoom"`).

### 3.6 Tactile Haptics Engine (`haptics.ts`)

- Lightweight wrapper around `navigator.vibrate()`.
- Standardized vibration patterns:
  - `light`: `10ms`
  - `medium`: `25ms`
  - `heavy`: `50ms`
  - `success`: `[10, 30, 20]ms`
  - `error`: `[50, 30, 50, 30, 50]ms`
- Maintains `lastHapticTriggered` state object for test suite verification.

---

## 4. Compliance & Gap Audit Matrix

| Feature / Sub-Requirement       | Implementation File                     |    Status     | Notes & Identified Gaps                                                                                                                       |
| ------------------------------- | --------------------------------------- | :-----------: | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **Header & Despatcher Pref**    | `LoadingSheet.tsx`, `db.ts`             | **COMPLIANT** | Saved to IDB via `saveDespatcherName()`.                                                                                                      |
| **7 Active Table Columns**      | `LoadingSheet.tsx`                      | **COMPLIANT** | Reg, Driver, Trip ID, Start, Finished, Mins, Qty Loaded.                                                                                      |
| **Auto-calculated Minutes**     | `loading-presets.ts`                    | **COMPLIANT** | Derived via `calculateDurationMinutes()`.                                                                                                     |
| **Presets (STOCKS, NLH, etc.)** | `loading-presets.ts`                    | **COMPLIANT** | `STOCKS` auto-increments via local storage & trip history.                                                                                    |
| **Standalone Manual Rows**      | `LoadingSheet.tsx`                      | **COMPLIANT** | `handleAddManualRow()` appends manual trip object.                                                                                            |
| **Summary Footer Totals**       | `LoadingSheet.tsx`                      | **COMPLIANT** | Totals sum quantity loaded & total loading time.                                                                                              |
| **Printable PDF Export**        | `export-pdf.ts`                         | **COMPLIANT** | Generates print styles & opens `window.print()`.                                                                                              |
| **Formatted WhatsApp Share**    | `export-whatsapp.ts`                    | **COMPLIANT** | Text formatting with emojis, clipboard & URL fallbacks.                                                                                       |
| **Timeline Event Stream**       | `EventLog.tsx`, `entry.$id.tsx`         | **COMPLIANT** | Notes, media & trip chips combined in stream.                                                                                                 |
| **Floating Note & Capture Bar** | `FloatingNoteBar.tsx`, `CaptureBar.tsx` | **COMPLIANT** | Expandable textarea + 4-option popover menu.                                                                                                  |
| **In-App Voice Recording**      | `VoiceRecorder.tsx`                     | **COMPLIANT** | Live timer, `audio/webm` blob creation & track cleanup.                                                                                       |
| **In-App Camera Capture**       | `InAppCamera.tsx`                       |  **PARTIAL**  | Functional, but stream leak bug exists on camera switch (`facingMode` useEffect). Also camera blob bypasses `downscaleImage` in `CaptureBar`. |
| **Media Previews & Lightbox**   | `AttachmentView.tsx`, `Lightbox.tsx`    |  **PARTIAL**  | Lightbox supports keyboard & button navigation, but lacks mobile touch swipe gesture handling.                                                |
| **Tactile Haptics Engine**      | `haptics.ts`                            | **COMPLIANT** | Predefined vibration patterns + `lastHapticTriggered` verification hook.                                                                      |

---

## 5. Key Architecture Recommendations for Subsequent Milestones

1. **Camera Stream Leak Fix (`InAppCamera.tsx`)**: Refactor stream cleanup in `InAppCamera` to use `useRef` or cleanup returns so video tracks are reliably stopped when toggling `facingMode`.
2. **Camera Image Downscaling (`CaptureBar.tsx`)**: Ensure captured blobs from `InAppCamera` pass through `downscaleImage()` prior to logging to prevent storing uncompressed 4K images in IndexedDB.
3. **Lightbox Touch Swipe Gestures (`Lightbox.tsx`)**: Implement `onTouchStart` and `onTouchEnd` swipe gesture listeners in `Lightbox` for improved mobile user experience.
