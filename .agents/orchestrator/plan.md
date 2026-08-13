# Despatch Diary — Master Plan

## Project Overview

Extend the Despatch Diary codebase to build a complete digital compliance system for the "DESPATCH LOADING SHEET", a companion PWA for personal devices, multi-device media sync via Supabase Storage, and a rich WhatsApp/Telegram-style messaging interface.

## Logical Implementation Phases (Milestones)

### Milestone 1: Exploration & Codebase Audit

- Codebase inspection, framework detection (React/Vite/Next/Flutter/etc.), existing database schema, Supabase setup, build scripts, test harness.
- Verification of test suites and current build status.

### Milestone 2: R1 - Digital "DESPATCH LOADING SHEET" Compliance System

- Header with Date and Despatcher Name (persisted user preference).
- Grid/Sheet with specified active columns: `Reg`, `Driver Name`, `Trip ID`, `Loading Start Time`, `Loading Finished Time`, `Minutes`, `Quantity Loaded`.
- Preset dropdown + free text input: `DBN`, `NLS`, `BLOEM`, `PLK`, `STOCKS [i]` (daily auto-increment counter reset at midnight), `NLH` (auto-fills Driver `Neil` & Reg `MN05XNGP`), `TIREPOINT`, and custom text.
- Omit old fields (Arrival Time, Departure Time, Pressure Check, footer PSI warning banner).
- Automatic duration calculation (`Minutes`) and quantity tracking.
- Standalone manual truck entry support directly on daily sheet (without scanner session).
- Summary footer (`TOTAL TYRES LOADED`, `TOTAL LOADING TIME`).
- PDF export (clean printable loading sheet report) & WhatsApp share text message generator.

### Milestone 3: R2 - Companion Web App (PWA)

- Dedicated mobile PWA view designed for personal phone access.
- Manifest configuration, service worker caching, offline capability.
- Real-time read/write sync with today's loading sheet and entries via Supabase.
- Offline status indicators (`Sent` / `Synced` / `Offline saved`).

### Milestone 4: R3 - Multi-Device Media Sync & Storage Fix

- Supabase Storage fix for media sync: images, videos, voice notes.
- Restore media metadata and storage download URLs on fresh device installs/reinstalls.
- Optimize background sync speed and eliminate duplicate re-push loops.
- Cross-device media availability test and verification.

### Milestone 5: R4 - WhatsApp / Telegram-Style UI Overhaul & Haptics

- Event timeline chat bubble UI for notes, voice notes, photos, videos, trip events.
- Rich media gallery with inline previews & lightbox modal.
- Tactile/haptic feedback on scan and counter button actions (`navigator.vibrate`).
- Instant cloud sync status icons (single check / double check / offline status).

### Milestone 6: E2E Testing Track, Adversarial Coverage Hardening & Victory Audit

- Comprehensive opaque-box E2E test suite (Tiers 1-4).
- Tier 5 adversarial testing.
- Forensic Auditor integrity verification.
