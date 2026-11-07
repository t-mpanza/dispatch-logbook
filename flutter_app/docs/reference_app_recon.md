# Reference app (dispatch_loading_app_v3.apk) — recon & integration notes

Source: `/home/kiddow/Desktop/Work/Dispatch (CAB)/dispatch_loading_app_v3.apk`
(release AOT, `com.example.dispatch_loading_app_new`, added 2026-11-07).
Strings extracted to `/tmp/opencode/v3apk/strings_app.txt`.

## What the reference app does (recovered semantics)

**Scan modes:** Scan Tyre / Scan Tyres, Receive Tyre(s), Send Tyre, Prepare
Tyres, Stock Take — driven by sessions (`createDispatchSession`,
stop session, `bPrep` prepare flag).

**Trucks:** Add Truck / Add Another Truck / Load Truck / Remove Active Truck;
REG via license-disk barcode (`Scan License Disk` / `Rescan License Disk`) or
`Manually Enter Reg`.

**Personnel:** `Scan Personnel` first (`Scan personnel tag before adding
truck`, `NO PERSONNEL SCANNED`); personnel by badge UID
(`getFactoryPersonnelWithUID`) and name fallback (`getUserPoolPersonnel`).

**Documents:** INV / DIBT / IBT / AMS INV resolved live via
`getDeliveryInfo` (all four keys must be sent — the all-four-keys rule,
AMS sent as `inv`, `amsInv` always empty). `Remove Active Document`.

**Scan gate:** `Checking Tyre in Active Document or IBT` — before committing,
the tyre must belong to the active document (or IBT). Errors:
`Tyre found outside of active document`, `Tyre not found in active truck`,
`All tyres are already loaded`, `Tyre Already Loaded`, `Previously loaded by`,
`Loaded by` / `Loaded onto`, `was not loaded`, `Not A Stock Tyre`.

**Commit:** `createDispatchDeliveryINV_V2` → {successful, duplicate_scan,
previous_reg, scan_time, name}. Offload: `Are you off-loading this tyre?`
(loaded: 0).

**Rejects:** NOT a scanner — manual count fallback: `Enter Number of Rejects`,
`Enter valid number of rejects`, `Added Rejects to truck`, `REJECTS #`,
`Reject loading not permitted`. Used when invoice numbers don't work.

**Manual tyre log:** `createFactoryTyreLog(factory_personnel_id, slip_id,
work_station_id)` → Factory_Tyre_log rows; read back via
`listFactoryTyreLog` / `getFactoryTyreLogWithId(factory_personnel_id)`.

**NFC lifecycle:** `handleAppLifecycleStateChanged` + `onResume` +
`on_background` — stop the NFC session when backgrounded (another NFC app
takes over), restart on resume. Polling: iso14443 (A+B) + iso15693 (V).
`Error starting NFC session:`, `NFC is not available or turned off.`

## Forensics data map (tyre investigation)

Evidence sources on the live schema for "what happened to this tyre":

| Query | Evidence |
| :--- | :--- |
| `getTyreWithUIDRep` / `getTyreWithSerialRep` / `getTyreWithJobNumberRep` | Tyre master row: serial, make, size, dot, duplicate, location_id, future_location_id, customer, tyre_uid |
| `getRepSlipTyreWithCSID(cs_id)` | Rich slip row: job, inspections II/Q2/Q3/FI/DI + descriptions, rubber, patches, **scan_out_time, work_cell, claims**, location, tagged, dump |
| `getTyreHistory(slip_id)` | Work-cell timeline: operator names, scan_in/scan_out, scan_out flag |
| `listFactoryTyreLog` / `getFactoryTyreLogWithId(factory_personnel_id)` | Manual factory log rows (personnel, work station, timestamps) |
| `getSlipWithNumber` | previous_slip_id, repeat_uid, missing, no_guarantee, late, green_block, reject_accepted, casing data |
| `getMissingTyreWithUID` | The missing-tyre registry lookup |
| `getFactoryOutstanding*` / `getReceivingOustandingTyres` / `getTyresBetweenCells` | Where a tyre is stuck (factory/receiving/transit) |
| `getMovementWorkCell` | Movement work cells per location |
| `getRejectInfo` / `getInProcessRejectInfo` / `getRedoInfo` / `getRerunInfo` / `getRedoWithSlipID` / `getReRunWithSlipID` / `getRejectBOM` | Reject/redo/rerun trails with reasons |
| `getQualityDeviations(Info)` / `getDeviations` / `getDeviationLoggers` | Deviation records |
| `listClaimInfo` / `getClaimInfoWithSlipNumber` | Warranty-claim trail (rich: adjustment, lives, old_slip_number, credit_note, reason, previous_customer…) |
| `getOverrideCardWithUid` | Override cards by UID |
| `listLatestUID` / `tyreUIDcheck` | UID registry + existence checks |
| `getBatchInFactoryTime` / `getBatchOutFactoryTime` | Batch factory timing |
| `createDispatchDeliveryINV_V2` response / `DispatchDeliveryLog` | Delivery scans (successful, duplicate_scan, previous_reg, scan_time, name) |
| `createRemovedSlips` (mutation) | Removed-slip markers |

**Inference design (not built yet):** serial/UID/slip → locate (master row +
location) → timeline (getTyreHistory + FactoryTyreLog + delivery log) →
terminal events (dump, missing, reject, redo/rerun, claims, removed marker)
→ verdict. Build bottom-up, one evidence source at a time; no guessing.

## Fixes to the Diary app (this round)

1. **IBT false-error — ROOT CAUSE FOUND (live-verified 2026-11-07).**
   The backend answers the scan mutation with the factory-wide sentinel
   convention: `0` = no, ANY non-zero = yes. A real duplicate scan returned
   `{"successful": 0, "duplicate_scan": 2, "previous_reg": "HW72JS", …}`.
   The app checked `== 1` → genuine scans fell through to
   "Scan rejected by system" while the backend recorded them. Fix:
   `parseCommitResponse` now treats non-zero as truthy for both
   `successful` and `duplicate_scan` (tests pin both sentinels).
   ALSO live-verified: `Slip_Tyre_Info` has NO `previous_reg` field, and
   its `registration` field does NOT change on scan commits — a read-back
   verification approach can never work (no read query exists for the
   loading log). Read-back code removed.
2. **Rejects screen** — manual scan-out fallback: ANY tyre passes. Remove
   the `ScrapScanEngine.evaluate` gate; keep operator/reg/dedupe checks.
3. **NFC traffic & coexistence** —
   - re-arm on resume when previously armed (reference `onResume` semantics)
   - buffer the last scan while busy instead of dropping it
   - service debounce 1.5s → 500ms (screen-level sessionUids already dedupes)
4. **Lookup UI** — port the reference app's Tyre Information presentation
   into the diary lookup screen (layout from widget-class strings).

## Live forensics tooling (committed)

- `test/live_ibt_forensics_test.dart` — read-only probes always run
  (real tyre row shapes, history, raw responses). With `REAL_MUTATIONS=1`
  it sends ONE duplicate-scan commit (same truck, no state change) and
  captures the raw response.
- `test/live_schema_introspection_test.dart` — dumps the CURRENT live
  fields of Slip_Tyre_Info / DispatchDeliveryLog / the scan mutation input
  (ground truth vs the pinned SDL snapshot).
