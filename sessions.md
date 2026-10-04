# Session Summary: Dispatch Diary v3.1.0 + v3.2.0 — IBT Batch Tally, Auto-Login, Dispatch Hub Fusion

**Objective**: Attack user complaints, embed auto-login, fuse dispatch-app functionality into Dispatch Diary. All work committed, tagged, released and CI-verified on `t-mpanza/dispatch-logbook`.

**State**: `flutter analyze` clean · **134 tests passing** (+2 live-gated) · v3.0.0, v3.1.0, v3.2.0 all released with signed APKs.

---

## v3.1.0 — Batch-entry IBT tally + embedded auto-login + live-validated 12R fix

### IBT tally rebuilt around DIRECT ENTRY
- User: "I prefer manually entering a number than small increments. if its 7 then 7, no clicking on 5 then double clicking the single incrementer leaving +5 +1 +1 on history."
- Steppers/quick-pills REMOVED from line cards and tally bar.
- `BatchPad` (number_pad.dart): add-mode keypad — type the exact number loaded, previous batch size pre-filled, manifest cap enforced, "ADD n" confirm.
- One tap = one clean history entry (`+7 · 07:32`) — no more stepper noise.
- History chips are now TAP-TO-UNDO per batch (`IbtLineOps.undoBatch` by event id), plus undo-last; same model in the tally bar and the IBT bottom sheet.
- `IbtLineOps` = single engine for delta/set/undo/undoBatch (stocks screen, viewmodel, bottom sheet all converge).

### Silent auto-login (no manual sign-in)
- User: "no manual log in now. the app should already be logged in to the system and ready to fetch stuff on demand."
- `AwsAutoLoginService`: complete Cognito SRP handshake (USER_SRP_AUTH → PASSWORD_VERIFIER, HKDF info "Caldera Derived Key", 16-byte key) in pure Dart — verified against golden vectors AND the live pool.
- Credentials lightly obfuscated (XOR 0x5A + base64) — internal builds only.
- `AppSyncManifestService.getValidIdToken` falls back to auto-login when no session exists → IBT manifests fetch out-of-the-box.
- Debugging journey (recorded for future sessions): corrupted N constant (770 vs 768 hex chars), then `utf8.encode(hexString)` producing ASCII instead of raw bytes for HKDF ikm/salt — fixed with `hexToBytes`.

### 12R size bug — CONFIRMED + FIXED against live data
- Live IBT 122773: `description: "12R22.5 M38 STOCK RETREAD", size_id: 22` — master map wrongly said 22 = 315/80R22.5. That was the "12R referenced as 315" bug.
- `resolveSize`: description always wins (imperial first, metric fallback), master map corrected (22→12R22.5, 16/45→11R22.5, 70→315/80R22.5).
- `resolveRubber`: description first — live patterns (M38, M43, M100, MM65) extract even when rubber_id is unknown.
- `RUN_LIVE_TESTS=1` integration tests fetch the real manifest and assert 12R resolves to 12R22.5.

## v3.2.0 — Dispatch Hub (dispatch-app fusion)

- User: "Fuse the two apps that one on this one not the other way around… The lite apk didn't have the nfc capability it only used the text input."
- New 4th dock tab **Dispatch** → hub with 4 inner tabs (Board, Lookup, Inspect, Summary), Obsidian-styled.
- **Board**: active dispatch session card, stat grid (at dispatch / batches / late / rejects / total), late-batch tiles, customer-grouped tyre tiles.
- **Lookup**: tyre story by UID / serial / CS / slip with spec card + scan-history timeline.
- **Inspect**: lite text-input mode (14-hex UID) → live validation → APPROVE/SCRAP with local persistence (`dispatch_decisions` table, DB v3 migration).
- **Summary**: per-work-cell shift totals with quota bars.
- `lib/dispatch/` module: defensive DTO parsers (json_helpers), SlipTyre, board DTOs, ScrapMarker, DocumentNumberParser (INV/DIBT/IBT/AMS/REJ), TyreStory usecase, live GraphQL operations catalog via `DispatchApi` (reuses the auto-login token pipeline).
- dispatch-app studied from `t-mpanza/dispatch-app` (v3 Tyre Inspector, ~21k lines); pure domain/data layer ported, transport rewired onto Dispatch Diary's existing AppSync auth, UI rebuilt in the app's own theme (no bloc/go_router/get_it dragged in).

## Releases shipped (all CI-verified)

| Tag | Release | Tests on CI |
|---|---|---|
| v3.0.0 | IBT overhaul, hardened updater, daily email, reminders | ✓ |
| v3.1.0 | batch-entry tally, auto-login, 12R fix | ✓ 52s |
| v3.2.0 | Dispatch Hub fusion | ✓ 52s, build 7m23s |

## Known follow-ups

- Daily-report email: environment `reporting` + 5 secrets configured; first autonomous run Monday 06:00 SAST.
- In-app "Send now" needs a fine-grained PAT (Actions: Read & write) pasted in Settings → Configure report trigger token.
- dispatch-app's Documents staging + Trucks screens not yet ported (future fusion work).
- The `main` bogus release was deleted (root cause of old updater behaviour); updater now ignores non-semver tags.

---

*Session log rebuilt after session-store loss; supersedes all earlier entries.*
