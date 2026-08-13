# Context Summary

## Project Overview

Project: Dispatch Diary (Despatch Diary)
Goal: Digital compliance system for "DESPATCH LOADING SHEET", Companion PWA, Multi-device media sync & storage fix, and WhatsApp/Telegram-style UI overhaul.

## Requirements Breakdown

1. **R1. Digital "DESPATCH LOADING SHEET" Compliance System**
   - Header: Date, Despatcher Name (saved user preference).
   - Columns: Reg, Driver Name, Trip ID, Loading Start Time, Loading Finished Time, Minutes, Quantity Loaded.
   - Presets: DBN, NLS, BLOEM, PLK, STOCKS [i] (daily auto-increment & reset at midnight), NLH (auto-fills Neil & MN05XNGP), TIREPOINT, Custom.
   - Removed: Arrival Time, Departure Time, Pressure Check, PSI footer warning.
   - Summary Footer: TOTAL TYRES LOADED, TOTAL LOADING TIME.
   - Standalone manual truck rows.
   - PDF printable report export & WhatsApp formatted text share.
2. **R2. Companion Web App (PWA)**
   - Personal phone access view.
   - Real-time read/write via Supabase.
   - Offline caching & sync indicators (`Sent` / `Synced` / `Offline saved`).
3. **R3. Multi-Device Media Sync & Storage Fix**
   - Supabase Storage media sync (photos, videos, audio/voice notes).
   - Restore metadata & download URLs on fresh install.
   - Optimize sync speed & eliminate duplicate re-push loops.
4. **R4. WhatsApp / Telegram-Style UI Overhaul**
   - Chat bubble layout for timeline/log events (notes, voice notes, photos, videos, trip events).
   - Rich media gallery & lightbox modal.
   - Tactile/haptic feedback (`navigator.vibrate`).
   - Instant cloud sync status icons.

## Current State

Initial state setup. Initial codebase exploration to be dispatched.
