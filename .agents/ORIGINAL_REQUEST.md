# Original User Request

## 2026-08-13T20:29:29Z

Extend the Dispatch Diary codebase to build a complete digital compliance system for the "DESPATCH LOADING SHEET", a companion PWA for personal devices, multi-device media sync, and a rich messaging-grade interface.

Working directory: /home/kiddow/Desktop/Work/Despatch Diary
Integrity mode: development

## Requirements

### R1. Digital "DESPATCH LOADING SHEET" Compliance System

- **Header**: Date, Despatcher Name (saved user preference).
- **Columns**:
  1. `Reg` (Truck Registration plate)
  2. `Driver Name`
  3. `Trip ID` (dropdown presets + free text input):
     - `DBN`
     - `NLS`
     - `BLOEM`
     - `PLK`
     - `STOCKS [i]` — auto-increments daily counter (`STOCKS 1`, `STOCKS 2`, `STOCKS 3`...) and resets each day.
     - `NLH` — preset shortcut that auto-fills Driver Name: `Neil` and Reg: `MN05XNGP`.
     - `TIREPOINT`
     - Custom text input option for any other Trip ID.
  4. `Loading Start Time` (auto-populated from 1st scan timestamp, editable).
  5. `Loading Finished Time` (auto-populated from last scan timestamp, editable).
  6. `Minutes` (auto-calculated duration in minutes between start and finish time).
  7. `Quantity Loaded` (auto-calculated from counter session, editable).
- **Removed Fields**: Arrival Time, Departure Time, Pressure Check, and footer PSI warning banner are removed.
- **Summary Footer**:
  - `TOTAL TYRES LOADED` (auto-summed across all rows for the day)
  - `TOTAL LOADING TIME` (total aggregate minutes loaded)
- Support standalone manual truck entries directly on the daily sheet (for small loads like 2–4 tyres that bypass the scanner counter).
- Export options: Clean printable/PDF loading sheet report, and formatted WhatsApp share text message.

### R2. Companion Web App (PWA)

- Dedicated companion PWA view designed for personal phone access.
- Real-time read/write access to today's loading sheet and entries synced via Supabase.
- Offline caching with sync status indicators (`Sent` / `Synced` / `Offline saved`).

### R3. Multi-Device Media Sync & Storage Fix

- Fix Supabase Storage media sync: ensure uploaded photos, videos, and voice notes render properly across all devices signed into the user's account.
- Restore media metadata and storage download URLs on fresh device installs/reinstalls.
- Optimize background sync speed and eliminate duplicate re-push loops.

### R4. WhatsApp / Telegram-Style UI Overhaul

- Transform event timeline into a Telegram/WhatsApp-grade chat bubble layout for notes, voice notes, photos, video, and trip events.
- Rich media gallery with inline previews and smooth full-screen lightbox modal.
- Tactile/haptic feedback on scan and counter button presses (`navigator.vibrate`).
- Instant cloud sync status icons (single check / double check / offline status).

## Acceptance Criteria

### Despatch Loading Sheet Compliance

- [ ] Digital loading sheet includes exact active columns: Reg, Driver Name, Trip ID, Loading Start Time, Loading Finished Time, Minutes, Quantity Loaded.
- [ ] Presets list includes DBN, NLS, BLOEM, PLK, STOCKS [i], NLH, TIREPOINT.
- [ ] Selecting `STOCKS` auto-increments the daily counter (e.g. `STOCKS 1`, `STOCKS 2`) and resets at midnight.
- [ ] Selecting `NLH` preset auto-fills Driver `Neil` and Reg `MN05XNGP`.
- [ ] Header includes Date and Despatcher Name.
- [ ] Footer automatically calculates `TOTAL TYRES LOADED` and `TOTAL LOADING TIME`.
- [ ] Arrival time, departure time, pressure check, and footer PSI notice are omitted.
- [ ] Standalone truck rows can be added manually without requiring a full scanner session.
- [ ] PDF export generates a clean, printable daily loading sheet report.
- [ ] WhatsApp share button formats the day's sheet into a clean text summary.

### Sync & Multi-Device Media

- [ ] Photos, videos, and audio notes recorded on the work scanner app download and render on the personal phone companion app.
- [ ] Fresh installs restore full entry data and download media on demand from Supabase Storage.
- [ ] Sync status badges accurately show Offline, Syncing, or Synced state.

### UI & Performance

- [ ] Event log uses a chat-bubble layout with distinct visual styling for notes, trips, photos, and voice notes.
- [ ] Lightbox opens smoothly and supports full-size image viewing across devices.
- [ ] Counter buttons provide haptic feedback (`navigator.vibrate`) on supported mobile devices.
