# MVP Tracking — Multi-Document Truck Hub

> **Owner: Sir Kiddow.** The user of this project is to be addressed as
> **Sir Kiddow** — always. (Engraved 2026-11-17.)
>
> This document is the SINGLE source of scheduling truth for the
> Multi-Document Truck Hub MVP. Technical ground truth lives in the recon
> docs under `docs/` (`ibt-scanning-recon.md`, `multi-document-scanning-recon.md`,
> `tyre-classification-synopsis.md`) and in the reference app source at
> `~/Desktop/Work/DispatchApp`. This doc schedules; the recon docs describe.

## §0 How to use this document (read this first)

**Status vocabulary (exact strings):**
`PLANNED` → `IN PROGRESS` → `DONE` (evidence required) | `BLOCKED` (reason + unblocker required) | `DEFERRED`.

**The updating algorithm — follow it in order:**
1. **Session start**: read §6 (session log, newest 5 entries), §5 (open questions), §4 (status board). Five minutes, no more.
2. **Before touching a workstream**: flip its status `PLANNED → IN PROGRESS` in §4.
3. **During work**: append new decisions to §2 with a date and a `supersedes:` note when replacing an earlier decision. **Nothing in §2 is ever deleted.**
4. **`DONE` requires evidence**: test command + result, commit hash, live dry-run output, or release tag. No evidence → not DONE.
5. **End of every turn**: append one session-log entry to §6 using the format in §6.
6. **Commit this doc with the code** in the same commit where practical.
7. **`BLOCKED`** must state the reason and exactly what unblocks it (who/what/where).
8. **Contradiction between this doc and the code** → flag it in §5, never silently pick a side.
9. **Never implement from memory**: decisions are in §2, backend facts in the recon docs, and every claim must be test-backed (TDD — Sir Kiddow's standing order).

## §1 Vision

One entry = one truck. The operator stages ALL the truck's documents at once
(INV, DIBT, IBT, AMS, cash) and scans head-down: the engine routes every
tyre to the right document automatically. **No active-document selection,
no per-scan screen time.** Correct = chime; wrong/uncertain = fail loud
(sound + hard haptic) and the screen explains. Review happens between
trucks, not during scanning.

Reference architecture (already decoded): `~/Desktop/Work/DispatchApp`
(company dispatch app source) + `app-05-dispatch-loading-test` (decoded
APK — the definitive scan/offload contract).

## §2 Decision register

| # | Date | Decision |
|---|---|---|
| D1 | 2026-11-17 | One entry = one truck; N documents staged simultaneously (INV/DIBT/IBT/AMS + cash mode). |
| D2 | 2026-11-17 | No active-document concept. Automatic routing across all staged documents. |
| D3 | 2026-11-17 | Routing precedence: dump guard → collision guard (loaded on another truck) → exact membership in ANY staged DIBT/INV → IBT fit (job "Client Retread" + size_id/rubber_id + capacity, **first line first, spill to next when full**) → cash (only when armed) → fail loud. |
| D4 | 2026-11-17 | Ambiguity = fail loud. Tyre on two documents → one alarm + "apply to both?" decision. The only interrupt. |
| D5 | 2026-11-17 | Double-scan of a tyre already on OUR truck = fail loud + yes/no window: offload (`createDispatchDeliveryINV_V2 {loaded: 0}`) or continue scanning. Backend has NO delete mutation — offload IS removal. |
| D6 | 2026-11-17 | `dump == 1` always hard-blocks, loudly, in every mode including cash. |
| D7 | 2026-11-17 | Cash = armed toggle (not auto-fallback). While armed, a tyre belonging to any staged doc (membership OR IBT fit) → fail loud + untoggle prompt. Expected-count acts as a progress meter. Cash rides the attached IBT (`document_no` convention: recon Q4). |
| D8 | 2026-11-17 | Same document number entered twice on one truck = refused. |
| D9 | 2026-11-17 | UI uses slip numbers only; UIDs never rendered. Manual entry types slip numbers. Backend resolvers exist: `getSlipWithNumber`, `getTyreWithSerial` (verified in source). |
| D10 | 2026-11-17 | Pre-scanned tyres render as scanned (green) from manifest `loaded`/`previous_reg`/`scan_time` (verified fields on `getDeliveryInfo` slips). |
| D11 | 2026-11-17 | Tyres render as 2-column blocks (small screens), not lists: slip #, customer name prominent, make/size, **D** badge for scrap, white=unscanned / green=scanned. Tap a block = load/offload from the UI. Accordion sections, default closed. Search by slip/serial within the truck. Scan feed behind an ACTIVITY button. Decluttered industrial look (less generic). |
| D12 | 2026-11-17 | Standalone trips PLK, HI-Q, DBN, BFN, NLS are ALL DIBTs — one unified flow, no special-cased screens, no splash-open. Add HI-Q preset; relabel BLOEM→BFN (BFN = BLOEM, the floor's word). |
| D13 | 2026-11-17 | DIBT progress reminders at 90% and 100% via `flutter_local_notifications` (dependency already present) — "post on the group" reminder. |
| D14 | 2026-11-17 | Consolidate the duplication: one entry-detail hub (modes, not screens), one ScanController pipeline, one tyre-block renderer, one truck editor (`TruckLoadDialog` — merge `ibtDocuments`, fixes bug a), one IBT attach path (`LoadingSheetViewModel`), `_cachedEntry` pattern everywhere (fixes bug b). |
| D15 | 2026-11-17 | Local-first caching: SQLite staged-document cache mirroring the reference `StagedDocumentDao` (manifest JSON per truck, offline restore). Parallel hydration. Extend `ScanLogService` toward an offline commit queue. |
| D16 | 2026-11-17 | Parallel document lookup (`Future.wait`), never sequential. One `getDeliveryInfo` call per document (backend rule: one document number type per call; all four keys required). |
| D17 | 2026-11-17 | Binary sounds only (success/error); error = loud WAV + triple-pulse system-Vibrator haptics (v3.8.1 contract). Ambiguity/collision/dump all take the error route. |
| D18 | 2026-11-17 | No licence-disk barcode truck entry. REG + driver entry stays manual/preset. |
| D19 | 2026-11-17 | TDD everywhere; live dry-runs (read-only) before shipping; release discipline: nightly-build → main → tag → CI → APK. |
| D20 | 2026-11-17 | Deferred: Oracle-server OCR spike (photo → slip number for dead tags). Later. |
| D21 | 2026-11-17 | Personality: invested, direct, dry wit; senior-dev production tone. Not a yes-man. |
| D22 | 2026-11-17 | Ship cadence: recon/design phases commit to nightly-build + main (docs/tests are harmless); code ships as versioned releases. |

## §3 Ground truth pointers

| Topic | Where |
|---|---|
| IBT scan contract (job gate, capacity, commit) | `docs/ibt-scanning-recon.md` |
| Tyre classification (scrap/dump/customer/stocks) | `docs/tyre-classification-synopsis.md` |
| Multi-doc scanning recon (DIBT/INV shapes, slip lookups) | `docs/multi-document-scanning-recon.md` |
| Reference loader contract (offload, staging, barcode) | `~/Desktop/Work/DispatchApp/app-05-dispatch-loading-test/reports/REVERSE_ENGINEERING_REPORT.md` |
| Reference modern app (StagedDocument, DAO, HUD) | `~/Desktop/Work/DispatchApp/lib/` |
| Backend live reality (resolver rules, numbers) | `~/Desktop/Work/DispatchApp/docs/backend-reality.md` |

## §4 Status board

| Phase | Name | Status |
|---|---|---|
| P0 | Engraving + this tracker | `DONE` (2026-11-17) |
| P1 | Live recon: reject_accepted, DIBT/INV shapes, slip lookups, cash document_no | `IN PROGRESS` |
| P2 | Data model: staged-document cache (SQLite v7), parallel resolver, truck-hub model | `DONE` (2026-11-17, evidence S-003) |
| P3 | Routing engine v2 (TDD): precedence, first-line-first IBT, ambiguity, cash arm, offload flow | `DONE` (2026-11-17, evidence S-004) |
| P4 | UI rewire: truck hub, 2-col blocks, accordion+search, cash toggle, offload dialog, reminders, HI-Q/BFN, consolidation (bug a + b) | `IN PROGRESS` (P4a done 2026-11-17) |
| P5 | Slip-number UX, manual CRUD, UID hidden | `PLANNED` |
| P6 | Hardening: scenario catalogue, live dry-runs, release | `PLANNED` |

## §5 Open questions

| # | Question | Evidence that closes it | Status |
|---|---|---|---|
| Q1 | `reject_accepted` scrap gate: 1 or 2? | Live probe of real scrap-run-out slips (history + flags) | OPEN — dispatched tyre with REJECT history carries 2; yard empty at probe time (see recon §3) |
| Q2 | Cash scan `document_no` convention | Live probe / floor confirmation | CLOSED (2026-11-18) — the floor's convention IS the attached IBT's number (Sir Kiddow: "the admin clerks just attach them to an ibt"); `_commitCash` commits `document_no = ibts.single.documentNo`, matching D7. Evidence: field statement + D7 + `truck_hub_screen.dart:_commitCash`. |
| Q3 | `getDeliveryInfo` DIBT/INV slip shape (loaded/previous_reg/scan_time per slip) | Live probe DIBT0179154 + INV2392908 | DONE — manifests carry loaded/previous_reg/scan_time per slip; no reject_accepted/CustomerName on slips |
| Q4 | AMS INV → `inv` quirk (app-05 CONFIRMED); confirm `amsInv` unused | Live probe | PARTIAL — decoded CONFIRMED; live AMS shape not yet probed |
| Q5 | Full Query list: any batch/list slip resolvers beyond the known ones | Schema introspection | DONE — 234 fields; slip-number/serial/CS lookups exist; listTyresAtDispatch* for rejects |

## §6 Session log

Format (append-only, newest at top):
```
### S-XXX · YYYY-MM-DD · <agent> · <phase>
- Did: one line per completed item
- Evidence: tests run, commits, tags
- Status flips: P1 PLANNED → IN PROGRESS
- Next: what the following session starts with
```

### S-016 · 2026-11-18 · main agent · v3.9.8 — UX audit fixes #1-#7 (external audit, priority order)
- Did: #1 Operator is now the CONFIGURED despatcher (Settings) — resolveOperatorId takes the name, pure selectOperatorId matches full-name/first-or-last, real-badge rows preferred; all three screens use the configured name in banners; hardcodes removed. #2 Q2 CLOSED with field evidence (cash commits ride the attached IBT — the floor's convention, D7). #3 Persisted cash-scan log (SQLite v8 cash_scans table, fresh-install safe): tyres committed as cash in previous sessions trigger the offload window on rescan — never a silent double-commit; offload forgets the tyre. #4 REG guard: empty REG disables Arm + inline warning before any scan is burned. #5 Untoggle-cash dialog reordered — KEEP CASH right (thumb side), UNTOGGLE left; extracted to a tested widget. #6 Error banners persist until the next scan or a tap; success banners still auto-dismiss. #7 Delete-document moved inside the opened accordion — no destructive action adjacent to the chevron.
- Evidence: 337 default + 26 live tests green (12 new: operator selector, cash repo, engine external-uids, dialog order, REG guard, banner persistence); analyze clean; goldens regenerated.
- Status flips: audit #1-#7 DONE. Remaining audit items (#8-#14) tracked in §7 scenarios/risks for later.
- Next: device re-test; audit items #8 (tag-less manual commit), #9 (cash count cross-session display), #10 (truck-total double count), #11 (offline commit queue).

### S-015 · 2026-11-18 · main agent · v3.9.7 — updater AUTO-RESUME on connection drops
- Did: device report — 'ClientException: connection closed' every time the APK download passed 70% (CDN/Wi-Fi drops on the 70MB transfer). The updater now auto-retries: connection-class failures resume from the persisted byte count with backoff (up to 5 attempts) — the operator sees the percentage keep climbing instead of an error. Non-retryable failures (404, checksum) still fail fast. Pinned by tests: mid-stream drop → Range-resume on attempt 2; 404 fails fast; cancel/verify behaviour unchanged.
- Evidence: 322 default tests green (2 new); analyze clean.
- Next: device re-test of the updater.

### S-014 · 2026-11-18 · main agent · v3.9.6 — TRUCK TOTAL card + offload-anywhere (field rules)
- Did: (1) The critical missing step — a TRUCK TOTAL card at the top of the hub: loaded, expected total across EVERY staged document, and LEFT, with a progress bar; falls back to the legacy sheet tally when nothing is staged. (2) REG is no longer a blocker for offloading — a tyre loaded on ANOTHER truck now gets the OFFLOAD window (loud + yes/no), so left-behind tyres can be offloaded and reloaded on the right truck; Collision verdict removed entirely (engine + UI + feedback tests updated).
- Evidence: 320 default + goldens regenerated + live dry-runs green; analyze clean.
- Next: device feedback.

### S-013 · 2026-11-18 · main agent · v3.9.5 — SPLASH-FREEZE FIX (device brick)
- Did: device report — app stuck on the splash forever (v3.9.4), clearing data didn't help. Root cause: the WAL/busy-timeout pragmas in DatabaseService.onConfigure (added for CI parallelism) ran on real devices before runApp; a locked journal / OEM sqlite quirk there throws → uncaught in main() → release builds freeze at the splash. Fix: pragmas are now TEST-ONLY (FLUTTER_TEST gate — CI keeps them, devices never run them); loadSettings' DB fallbacks wrapped (best-effort); main() hardened — settings load, migration (15s timeout) and notification init (10s timeout) can never stop runApp.
- Evidence: 319 default + 319 under -j 8 (CI-style) green; analyze clean.
- Next: Sir Kiddow's device confirmation; remaining parity gaps tracked.

### S-012 · 2026-11-18 · main agent · v3.9.4 — field-bug sweep + audits + rollback + visual tests
- Did (Sir Kiddow's overnight bug list): REG/driver/target/trip/title editable from the hub header (persisted); legacy entries import their trip IBTs into the staged cache and show their 24/24 tally (nothing looks empty); MANUAL COUNT card restores the tag-free tally (persisted to the sheet trip); remove-document action; long-press tyre blocks for manual load/offload; accordions CLOSED by default. Two parallel subagent audits (parity + robustness, 26 findings) → fixed the criticals: mounted-guard sweep + scan try/catch, queued pending scans (no dropped tags), badge-uids filtered, stuck-resolver guard, load/stage race guards, sessionLineByUid now recorded (IBT offload decrements correctly), offload persisted to cache, serialized snapshot-based persist chain, slip-number matching in _markLoaded, apply-to-both mounted checks, manual-tally re-entrancy guard, remove-doc session pruning, controller disposal, reminder div-0 guard + flag-after-success, stocks entries routed to their mature screen (no capability loss). ROLLBACK: Settings → App versions → install or roll back to any release through the same resumable SHA-256-verified pipeline (downgrade guidance included). VISUAL TESTS: golden snapshots for the hub (empty + staged-open).
- Evidence: 319 default + 2 goldens + 26 live tests green; analyze clean; audits archived in tracker §7 references.
- Next: device feedback; remaining parity gaps (notes/photos/event log on the hub, IBT batch/undo — tracked).

### S-011 · 2026-11-17 · main agent · v3.9.3 — explicit type+digits staging rows (Sir Kiddow's spec)
- Did: staging is now CC/BCC-style rows — each document picks a TYPE chip (INV/DIBT/IBT/AMS, prefix rendered live in the field) then types DIGITS ONLY; ADD DOCUMENT extends rows; STAGE ALL resolves in parallel. No prefix typing, no guessing. Chips show CUSTOMER as the error-catcher; RECENT tap-to-stage chips keep keystrokes down; input normalizes case/spaces/dashes. Resolver bare-number probing stays as a safety net; ambiguity demands the prefix.
- Evidence: 309 default tests green (row UI, recents, probe, normalization, repo); analyze clean.
- Next: device feedback; P5 (block CRUD), P6.

### S-010 · 2026-11-17 · main agent · v3.9.2 — DIBT reminders per Sir Kiddow's answers
- Did: reminder spec locked with Sir Kiddow — notification ONLY (no WhatsApp draft), his verbatim wording (90%: "<trip> is almost done. Dont forget to post on the group." · 100%: "<trip> is done. Post on the group."), once-only persisted flags so re-opening a truck never re-fires. Message label = trip name (NLS/PLK/HI-Q/DBN/BFN), falling back to the document number.
- Evidence: wording tests green; 304 default tests green; analyze clean.
- Next: device feedback; P5 (block CRUD), P6.

### S-009 · 2026-11-17 · main agent · v3.9.1 — hub entry point + enterprise updater
- Did: truck-load entries now open the TRUCK HUB (staging lives there — the v3.9.0 chicken-and-egg gap fixed); manual slip-number entry in the hub (getSlipWithNumber → CSID → UID hydration — CSID rows lack `loaded`, live-verified); ENTERPRISE UPDATER: persistent download store (app-support dir, not temp), HTTP Range resume, pause-with-saved-progress, SHA-256 verification pre-install, RESUME/INSTALL CTAs, size + release date + digest metadata, prune old versions; DIBT notification permission requested when a DIBT is staged (Android 13+ prompt, best-effort).
- Evidence: 302 default + 26 live tests green; analyze clean; resume/verify/store behaviours pinned by 9 new updater tests.
- Next: Sir Kiddow's device feedback; open questions for him on the DIBT reminder (message wording, WhatsApp draft, thresholds).

### S-008 · 2026-11-17 · main agent · v3.9.0 test release (PUSH UN-GATED by Sir Kiddow)
- Did: version 3.9.0+1; hub test hardened for CI determinism (clears staged docs per test); the cached-docs-open-CLOSED behaviour pinned; pushed nightly-build + main, tagged v3.9.0 — Sir Kiddow is testing the MVP-on-device.
- Evidence: 289 default + 26 live tests green; analyze clean; CI monitored.
- Next: Sir Kiddow's device feedback, then P5 (manual slip entry + block CRUD, screen retirement), P6 hardening, final release.

### S-007 · 2026-11-17 · main agent · P4c
- Did: entry_route now routes entries WITH staged documents to the TruckHubScreen (one SQLite read decides; legacy screens keep serving until P5 parity). Bug b FIXED in both stocks and entry-detail screens: the entry fetch future is hoisted into state (ONE fetch per open; no more per-rebuild re-fetch churn). Routing test pins both directions.
- Evidence: entry_route_test (2 tests); 289 default tests green; analyze clean.
- Status flips: P4 remains IN PROGRESS — screen retirement waits for P5 parity (manual entry + block CRUD).
- Next: P5 — slip-number manual entry + tap-block load/offload CRUD; hide UID everywhere; then retire duplicated screens; then P6 hardening + the single push.

### S-006 · 2026-11-17 · main agent · P4b
- Did: TruckHubScreen — the truck hub: parallel document paste → DocumentResolver chips; accordion sections (closed by default) with the CUSTOMER on the header (moved off the blocks per Sir Kiddow); TyreBlockGrid + slip/serial search inside DIBT/INV sections; IBT sections as line progress; cash arm toggle (D7); scan pipeline wired MultiDocScanEngine → commit → ScanFeedback (haptics contract) → local cache upsert + DIBT 90/100% notifications; OFFLOAD window commits loaded:0 and unloads the local slip; apply-to-both dialog (D4). Bug a FIXED: TruckLoadDialog preserves ibtDocuments. NotificationService.showNow added. SlipTyre/StagedDocument copyWith added.
- Evidence: 4 hub widget tests + truck_load_dialog regression test; 287 default tests green; analyze clean.
- Status flips: P4 remains IN PROGRESS (P4c left).
- Next: P4c — consolidation: point entry routing at the hub, retire the duplicate screens, kill the FutureBuilder churn (bug b) on the remaining screens, then P5.

### S-005 · 2026-11-17 · main agent · P4a
- Did: ScanFeedback — the SINGLE verdict→feedback point (every error verdict = loud WAV + v3.8.1 vibrator; success = chime + soft impact) so every screen inherits the haptic contract; TyreBlock + TyreBlockGrid (D11: slip #, customer prominent, D badge, white→green, 2 cols); OffloadDialog (D5 yes/no window); DibtProgressReminder thresholds (D13: 90%/100%, upward-only, once each); HI-Q preset added + BLOEM relabelled BFN with tripId 'BFN' (D12) across engine/UI/colors.
- Evidence: 21 new/updated tests (feedback vibrator pin, block grid layout, dialog yes/no, reminder thresholds, presets); 281 default tests green; analyze clean.
- Status flips: P4 PLANNED → IN PROGRESS.
- Next: P4b — the TruckHubScreen: parallel document paste + chips (DocumentResolver), per-doc accordion sections with TyreBlockGrid + search, cash arm toggle, NFC scan wiring through MultiDocScanEngine → ScanFeedback → OffloadDialog, reminder notifications, and the consolidation surgery (bug a + b). NO git pushes until MVP closed.

### S-004 · 2026-11-17 · main agent · P3 (DONE)
- Did: MultiDocScanEngine — the head-down routing brain (D2-D7, D9): dump blocks in every mode → session re-scan = offload window → loaded-elsewhere = own-truck offload vs cross-truck collision → cash armed: membership/IBT-fit = untoggle prompt else CASH → membership (uid OR slip number) with two-doc ambiguity → IBT first-line-first with spill → loud reject. commitScan gains `loaded` param (0 = offload, the backend's only removal). CI-found bug fixed: fresh-install onCreate now creates scan_logs + staged_documents (local v6 DB had masked it).
- Evidence: 20 new engine tests (multi_doc_scan_engine_test.dart); 264 default + 17 live tests green; analyze clean; fresh-DB path verified by deleting the test DB and re-running green.
- Status flips: P3 PLANNED → DONE.
- Next: P4 — truck-hub UI: document chips + parallel paste, 2-col tyre blocks (white/green, D badge), cash toggle, offload dialog, accordion+search, DIBT 90/100% reminders, HI-Q preset, consolidation (bug a + b). NO git pushes until MVP closed (Sir Kiddow, 2026-11-17).

### S-003 · 2026-11-17 · main agent · P2 (DONE)
- Did: StagedDocument model (JSON cache, membership/loadedCount helpers); SQLite v7 `staged_documents` table with UNIQUE(entry,stream,document_no) — D8 at the DB; StagedDocumentRepository (save throws DuplicateDocumentException, upsert/remove/clear); DocumentResolver — parallel multi-document staging (prefix classification, per-doc verdicts ok/duplicate/notFound/error/unsupported, SCRAPS refused as a mode); DispatchApi.fetchDeliveryDocument (block-level customer+slips); SlipTyre.toJson.
- Evidence: 15 new tests (model/repo/resolver, incl. concurrency proof); live resolver staged INV2392908+DIBT0179154 in parallel (14+5 slips, loaded 13/5) with duplicate refusal; 244 default + 26 live tests green; analyze clean.
- Status flips: P2 PLANNED → DONE.
- Next: P3 — routing engine v2 (TDD): dump/collision/membership/IBT-first-line-first/cash-arm/offload; then P4 UI.

### S-002 · 2026-11-17 · main agent · P1
- Did: live read-only probes (7 tests): INV2392908 + DIBT0179154 manifest shapes (loaded/previous_reg/scan_time per slip VERIFIED); getSlipWithNumber + getTyreWithSerial VERIFIED (slip-number UX viable today); full 234-field query catalogue; DispatchQueryFull introspected (reject_accepted + at_dispatch; 0 rows at probe); reject-history evidence on slip 1060772.
- Evidence: `flutter_app/test/live_multi_doc_recon_test.dart` (RUN_LIVE_TESTS-gated); `docs/multi-document-scanning-recon.md`; 229 default tests green, analyze clean.
- Status flips: Q3, Q5 → DONE; Q1, Q2 refined with evidence.
- Next: P2 — staged-document cache model + parallel resolver; Q1 probe retry when the yard has tyres.

### S-001 · 2026-11-17 · main agent · P0/P1 start
- Did: design locked with Sir Kiddow (D1–D22); engraving in global memory; this tracker created; P1 recon started (live read-only probes).
- Evidence: global `AGENTS.md` updated; this file.
- Status flips: P0 → DONE; P1 → IN PROGRESS.
- Next: run live probes (reject_accepted, DIBT/INV shapes, schema); write `docs/multi-document-scanning-recon.md`; then P2.

## §7 Scenarios & risks

| Scenario | Mitigation |
|---|---|
| AUDIT #8 — tag-less tyre via manual path | commitScan requires a uid; genuinely chip-less tyres dead-end — needs backend discussion (tracked, not yet built) |
| AUDIT #9 — cash count resets per session | persisted cash log exists; display-level cross-session count pending |
| AUDIT #10 — TRUCK TOTAL double-counts cash when IBT staged | display reconciliation pending |
| AUDIT #11 — offline commit queue (D15) | ScanLogService is diagnostics only; queue not built |
| AUDIT #12-14 — PWA reminders/redundancy/doc drift | PWA track, out of MVP scope |
| Slip on two documents (DIBT+INV identical lists) | Fail loud + "apply to both?" (D4) |
| Cash tyre that also fits an IBT line | Membership/IBT fit beats cash → fail loud + untoggle prompt (D7) |
| Tyre loaded on another truck | Collision hard-block, loud (D3) |
| Double-read bounce on the NFC reader | Offload requires the yes/no window (D5) — no instant offload |
| Dead tag / unreadable chip | Manual slip-number entry (`getSlipWithNumber`), CS/serial lookups (D9) |
| Ghost uid (no slip row) | "Tyre Not Found" banner (existing) |
| IBT line full but tyre matches job | Spill to next matching line; all full → fail loud |
| Offline mid-load | Local-first cache + ScanLogService commit queue (D15) |
| Doc short at the gate | Missing list + continue prompt (P6) |
| Customer name on slip ≠ doc customer | Soft flag, membership wins |
| Pre-scanned tyre re-enters | Renders green on load (D10); double-scan = offload window (D5) |
| Duplicate document number entered | Refused (D8) |
