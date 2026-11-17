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
| P2 | Data model: staged-document cache (SQLite v7), parallel resolver, truck-hub model | `PLANNED` |
| P3 | Routing engine v2 (TDD): precedence, first-line-first IBT, ambiguity, cash arm, offload flow | `PLANNED` |
| P4 | UI rewire: truck hub, 2-col blocks, accordion+search, cash toggle, offload dialog, reminders, HI-Q/BFN, consolidation (bug a + b) | `PLANNED` |
| P5 | Slip-number UX, manual CRUD, UID hidden | `PLANNED` |
| P6 | Hardening: scenario catalogue, live dry-runs, release | `PLANNED` |

## §5 Open questions

| # | Question | Evidence that closes it | Status |
|---|---|---|---|
| Q1 | `reject_accepted` scrap gate: 1 or 2? | Live probe of real scrap-run-out slips (history + flags) | OPEN — dispatched tyre with REJECT history carries 2; yard empty at probe time (see recon §3) |
| Q2 | Cash scan `document_no` convention | Live probe / floor confirmation | OPEN — no cash query in catalogue; floor question or REAL_MUTATIONS forensics |
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
