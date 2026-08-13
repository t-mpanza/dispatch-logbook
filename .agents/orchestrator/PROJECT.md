# Project: Despatch Diary Compliance & Companion System

## Architecture

- **Application Type**: To be identified in Milestone 1 (Web / PWA / Hybrid App).
- **Backend / Sync**: Supabase Database & Supabase Storage.
- **Frontend / UI**: Modern web / PWA framework with WhatsApp/Telegram-style chat bubble event log, loading sheet compliance table, media gallery, lightbox modal, and haptic feedback.

## Milestones

| #   | Name                    | Scope                                                                           | Dependencies   | Status      |
| --- | ----------------------- | ------------------------------------------------------------------------------- | -------------- | ----------- |
| 1   | Exploration & Audit     | Analyze codebase, tech stack, test runner, build commands                       | None           | IN_PROGRESS |
| 2   | R1 Compliance Sheet     | Loading sheet, preset rules, trip dropdown, PDF & WhatsApp export, manual rows  | M1             | PLANNED     |
| 3   | R2 Companion PWA        | PWA manifest, service worker, offline cache, mobile UI, sync badges             | M1, M2         | PLANNED     |
| 4   | R3 Media Sync & Storage | Supabase media storage sync, URL recovery on fresh install, anti-duplicate sync | M1             | PLANNED     |
| 5   | R4 Chat UI & Haptics    | Chat bubble timeline, media gallery, lightbox, haptic vibrate, sync icons       | M1, M3, M4     | PLANNED     |
| 6   | E2E & Hardening         | Dual track E2E tests, Tier 1-5 testing, Forensic Audit                          | M2, M3, M4, M5 | PLANNED     |

## Interface Contracts

### Daily Loading Sheet ↔ Supabase Sync

- Sheet Data: Date, Despatcher Name, Total Tyres Loaded, Total Loading Time.
- Row Data: id, reg, driver_name, trip_id, loading_start_time, loading_finished_time, minutes, quantity_loaded, is_manual.
- Media Items: id, entry_id, type ('photo'|'video'|'audio'), storage_path, download_url, sync_status.

## Code Layout

- TBD during Milestone 1 Exploration.
