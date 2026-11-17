# Multi-Document Scanning Recon — Live-Verified Facts

> P1 recon for the Multi-Document Truck Hub MVP (tracker:
> `docs/mvp-tracking.md`). All facts below were verified LIVE against the
> production AppSync backend on 2026-11-17 via
> `flutter_app/test/live_multi_doc_recon_test.dart` (read-only; no
> mutations), plus the decoded reference apps
> (`~/Desktop/Work/DispatchApp` — company dispatch app source + the
> app-05 `dispatch_control_test` APK).

## 1. Document manifests (getDeliveryInfo) — the multi-doc foundation

`getDeliveryInfo` is one call **per document** (backend rule: only one
document-number type per call; all four keys `amsInv/dibt/ibt/inv` must be
present, unused ones empty strings).

Live-verified shapes:

- **`INV2392908`** (EPS COURIERS SERVICES, 14 slips) — every slip row in
  the manifest carries:
  `slip_number, uid, size, make, serial, pattern, location_code, loaded,
  name, previous_reg, scan_time, dump`.
  Live sample: `slip=96975621 loaded=1 prev=HW72JS scan_time=2026-09-01 08:08:05`.
- **`DIBT0179154`** (EPS COURIERS SERVICES, 5 slips) — same shape, same
  populated `loaded/previous_reg/scan_time`.
- The manifest slip type is `DispatchDeliverySlipInfo`. It does **NOT**
  have `reject_accepted` or `CustomerName` (FieldUndefined — verified).
  Customer lives at the **block level** (`customerName` on the document),
  reject state lives on the **slip row** (`Slip_Tyre_Info`).

**Consequences:**
- Pre-scanned tyres render green **from the manifest alone** — no loading
  log read query needed (D10 satisfied; there is still no read query for
  the loading log itself).
- Cross-truck guard data is in the manifest too: `previous_reg` shows
  which truck has the tyre.
- Per-slip customer name is NOT available from manifests — for DIBT/INV
  blocks the customer is the document's customer (fine, one customer per
  DIBT/INV in practice).

## 2. Slip-number-first UX (no UIDs) — resolvers exist TODAY

| Resolver | Arg | Returns | Live-verified |
|---|---|---|---|
| `getSlipWithNumber` | `slip_number: Int!` | full slip row incl. `reject_accepted`, `invoice_number`, `job_staged`, `casing_grade` | ✓ found (slip 96975621) |
| `getTyreWithSerial` | `serial: String!` | tyre + slip + customer | ✓ `2608E105 → slip=96975621 customer=EPS COURIERS SERVICES (PTY) LTD` (note trailing space — trim) |
| `getConfirmationSheetWithCSID` | `idConfirmation_Sheet` | all slips on a CS | known from source |
| `slipNumberCheck` | `slip_number` | existence check | in catalogue |
| `getTyreWithSerialRep` / `…3rd` | `serial` | repair/3rd variants | in catalogue |

Manual entry by slip number is fully supported. UIDs can be hidden
everywhere in the UI.

## 3. The reject gate (reject_accepted) — UNRESOLVED, evidence logged

| Source | Claim |
|---|---|
| Our SCRAPS gate + reference dispatch-app engine | gate on `reject_accepted == 1` (`isRejectAccepted`) |
| ATT Supervisor app (decoded) | writes `reject_accepted = 2` on reject-accept |
| Live slip row 1060772 (dispatched tyre) | `reject_accepted = 2` with history `… REJECT INSPECTOR → REJECT RETURN → REJECT EXIT → … → DISPATCH DELIVERY` (was rejected, later re-manufactured and delivered) |
| Classification synopsis (live study 2026-09) | scrap slips carry `== 2` |

**Interpretation**: `2` = "reject accepted" (the tyre went through the
reject flow), NOT "currently scrap-despatchable" — a reject-accepted tyre
can later be re-manufactured and delivered. Whether the SCRAPS despatch
gate should be `1` or `2` is still open. The dispatch-side rejects list is
queryable: `listTyresAtDispatchFull()` (no args) returns
`DispatchQueryFull` rows with `reject_accepted` + `at_dispatch` — live
probe returned **0 rows** (yard empty at probe time). To settle: probe
again when tyres sit at dispatch, or ask the floor which state marks a
tyre ready for scrap run-out.

**Interim design rule**: the engine's scrap gate is a single verified
constant, parameterized and pinned by a live test the day the yard has
data. Do not hard-code either value into the routing logic before then.

## 4. Cash sales — document_no convention still open

- Cash tyres are attached by admin clerks to an **IBT** (not a legal
  document), mostly NLS. Operator verifies doc-vs-tyre info manually and
  scans; expected count known.
- No "cash" query or document type exists in the 234-query catalogue.
- Open: what `document_no` a cash scan commits with (the attached IBT's
  number? A synthetic one?). Candidates to settle it: ask the floor, or
  run a `REAL_MUTATIONS=1` forensics scan while the operator stages a real
  cash tyre.
- Design (locked, D7): cash is an ARMED TOGGLE, never auto-fallback;
  expected-count as progress meter; while armed, any tyre belonging to a
  staged doc (manifest membership OR IBT fit) fails loud with an untoggle
  prompt.

## 5. Query catalogue highlights (234 root fields)

Useful for the hub: `listTyresAtDispatch`, `listTyresAtDispatchFull`,
`listTyresAtDispatchStation(V2)`, `listTyresInFactory`, `listOutstandingTyres`,
`getFactoryOutstandingTyres`, `getRejectInfo`, `getInProcessRejectInfo`,
`getAmountOfRejects`, `getFinalRejectTotal`, `listRejectCode`,
`getTyresAtDispatchWithCustomerID`, `listReceivedCS`, `slipNumberCheck`,
`tyreUIDcheck`, `getClaimInfoWithSlipNumber`.

`DispatchQueryFull` fields (live): `reject_accepted, slip_number,
CustomerName, at_dispatch, invoice_number, EVO_status, idSlip, idTyre,
make, size, serial, pattern, idLocation, location_code, fut_idLocation,
fut_location_code, …` — note: **no `loaded`/`uid`** on this type; the
manifest (`DispatchDeliverySlipInfo`) is the loaded-state source.

## 6. Reference loader contract (decoded app-05) — the routing secret

- Truck holds multiple docs (invoice/DIBT lists + IBTs) with one ACTIVE
  at a time — we deliberately DROP the active concept (D2): all staged
  docs route simultaneously.
- Manifest path (INV/DIBT): exact uid membership; `loaded==0` → load;
  `loaded==1` → unload dialog (`loaded:0`); found in ANOTHER truck's doc
  → treated as not found (never steal).
- IBT path: `job == "Client Retread"` + `size_id`+`rubber_id` +
  `total > tyres.length`; else `wrong_tyre.mp3`.
- Offload = `createDispatchDeliveryINV_V2 {loaded: 0}`. NO delete
  mutation exists in the entire backend (234Q/136M introspected) —
  offload IS removal.
- AMS INV is sent as `inv`; `amsInv` always empty (quirk, CONFIRMED).
- Licence-disk barcode truck entry exists in the reference — **REJECTED
  by Sir Kiddow (D18)**.

## 7. Open recon items (next probes)

1. `reject_accepted` gate truth — probe `listTyresAtDispatchFull` when the
   yard has tyres; or `getRejectInfo` shape (input object not yet mapped).
2. Cash `document_no` — floor question or REAL_MUTATIONS forensics.
3. AMS document live shape (`getDeliveryInfo` with `inv: <AMS number>`) —
   confirm slips come back under `inv`.
4. `getRejectInfo` / `getInProcessRejectInfo` input shapes (introspection).
