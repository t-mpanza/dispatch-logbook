# Session Summary: Dispatch Diary v3 — IBT Overhaul, Updates, Email Reports, Reminders

**Objective**: Attack every complaint in `user-complaints.md` against the Flutter (canonical) app and ship v3.0.0.

**State**: `flutter analyze` clean · 93/93 tests passing · debug APK builds · release build verified locally.

---

## 1. IBT System Rework (main user focus)

### Static line ordering
- `stocks_entry_detail_screen.dart`: removed `_sortedLines()` — line items now render **exactly as fetched**. No more lines jumping around mid-tally.

### Haptics on every key press (noisy bay)
- Line-card `+/-` steppers: light haptic per tap.
- Tally bar `+/+5/+10/Fill`: light/medium haptics; long-press `+5`/`-5` = medium; heavy on overshoot clamp; success on line complete; medium on undo.
- Central `_reactToDelta()` in the screen: clamp → heavy + snackbar, complete → success, uncomplete → medium, else light.

### Per-line mini history ("what did I just add?")
- New model `IbtLineEvent {id, delta, at}` + `IbtLineItem.history` (JSON-persisted, backwards compatible).
- New pure engine `lib/data/services/ibt_line_ops.dart` (`IbtLineOps.applyDelta / setQuantity / undoLast`) — single source of truth for clamping, history, and trip totals.
- UI: last-3 events shown as `+4 · 07:32` chips on each line card; "Last: +N" in the tally bar; undo button (card + tally bar + IBT bottom sheet).
- `LoadingSheetViewModel.updateIbtLineQuantity/applyIbtLineDelta/undoIbtLineLast` now delegate to the shared engine and **never crash** on missing docs/lines.
- Strict manifest cap is now consistent everywhere (viewmodel, stocks screen, keypad, bottom sheet).

### 12R tyre size bug
- `AppSyncManifestService.resolveSize()`: manifest **description wins** over the size_id master map; imperial designations (12R22.5, 11R22.5, 10.00R20) are matched with priority and a negative lookbehind prevents false "80R22.5" matches inside "315/80R22.5".
- 12R tyres now display as `12R22.5`, never as `315`.

## 2. Incremental Update System → v3

- `pubspec.yaml`: `3.0.0+1`.
- `UpdateService` strengthened:
  - Only releases **newer than installed** are candidates (can never point at an older APK).
  - Best candidate chosen by **semantic version comparison**, not GitHub publish order.
  - Non-version tags (`main`, etc.) ignored; drafts/prereleases/RCs skipped; paginates up to 5 pages.
  - Fallback version `v3.0.0`.
- `.github/workflows/release.yml` fixed:
  - Pushes to `main` now run **tests only** — the bogus "main" release that broke the updater is gone.
  - Releases only from `v*` tags or manual `workflow_dispatch` with a version input.
  - Tag used correctly (`github.ref_name` for tags, input for manual).

## 3. Autonomous Daily Email Report (Mon–Fri, 06:00 SAST)

- New `.github/workflows/daily-report.yml`: scheduled `cron: 0 4 * * 1-5` (weekdays), plus `workflow_dispatch` and `repository_dispatch`.
- New `.github/scripts/send_daily_report.py`:
  - Reports the **previous working day** (Monday's email carries Friday's report — Sat/Sun roll back to Friday).
  - Pulls `entries` from Supabase (service role), aggregates `quantityLoaded` → tyres, entries with sheet trips → trucks.
  - Sends plain-text email from the owner's personal email (Gmail SMTP) with exactly:
    `Good Morning, Gizz.\n\nTyres Loaded: {n}\nTotal Trucks: {n}`.
- In-app manual trigger: Settings → **Reports** → "Send now" calls the GitHub `workflows/daily-report.yml/dispatches` endpoint via a PAT stored in secure storage (configurable in-app). Recipient default `Giz-MarieDP@att-tyres.co.za`.

## 4. Smart Reminders

- Added `flutter_local_notifications` + `timezone`; Android manifest: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, scheduled receivers; core-library desugaring in `build.gradle.kts`.
- `NotificationService`: permission requests (Android 13+), `zonedSchedule`, cancel, and **re-register all pending reminders on cold start** (survives reboots/updates).
- Settings → **Reminders** card: list, create (text + date + time pickers), done-toggle, delete. DB ops added: `updateReminder`, `deleteReminder`, `deleteRemindersForEntry`.

## 5. Cleanup & Consistency

- Single IBT update path (was 3 divergent implementations).
- Settings branding: "Dispatch Diary · IBT Edition" → "Dispatch Diary".
- Verified update dialog + welcome sheet carry no stale v2 branding.

## Tests

- New: `ibt_line_ops_test.dart` (clamp, history, undo, serialization, legacy tolerance), `ibt_size_resolution_test.dart` (12R priority, metric regression), update-service tests for v3 fallback, non-version tags, older-release filtering.
- Updated: `update_service_test.dart`, `update_service_adversarial_test.dart` (v3 fixtures), `challenger_m1_it2_stress_test.dart` (strict-cap expectations).
- **93/93 passing** (`flutter test`), `flutter analyze` clean.

## Secrets the owner must configure (GitHub Environment `reporting`)

1. `REPORT_SENDER_EMAIL` — personal Gmail used to send reports.
2. `REPORT_SENDER_APP_PASSWORD` — Gmail App Password (requires 2-Step Verification; create at myaccount.google.com/apppasswords).
3. `REPORT_RECIPIENT_EMAIL` — `Giz-MarieDP@att-tyres.co.za` (workflow falls back to this if unset).
4. `SUPABASE_URL` — `https://glxxawxuwusxwjvezugo.supabase.co`.
5. `SUPABASE_SERVICE_ROLE_KEY` — Supabase dashboard → Project Settings → API.

For the in-app "Send now" button: a fine-grained PAT (Actions: Read & write on `t-mpanza/dispatch-logbook`) pasted once in Settings → Configure report trigger token.

## Pending

- Commit + push (user to confirm), then tag `v3.0.0` so CI publishes the signed APK.
- Cognito creds for live AppSync testing were rejected (`LAPTOP-E31LQ89M` / `12341!aA1` → NotAuthorizedException); awaiting corrected credentials to validate the 12R fix against live data.

---

*Session log rebuilt after session-store loss.*
