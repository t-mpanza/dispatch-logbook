# IBT Scanning Recon — What the System Really Looks For

> Full reconnaissance of how tyres are identified as STOCKS vs customer vs
> dump when scanned under an IBT document. Sources: `dispatch-app` source +
> `docs/backend-reality.md` (live probes 2026-09), the reverse-engineered
> **ATT Supervisor** APK (factory side), and our own Dispatch Diary.
>
> The two open bugs (sheet-side edit wiping IBT data; slow IBT
> materialization) are documented at the end — not fixed yet, per request.

## 1. "Stocks" is our word — the system speaks IBT

`STOCKS` in Dispatch Diary = **IBT documents** (`getDeliveryInfo.ibt`).
IBT = an internal stock transfer between depots. The backend names the
object literally:

```
Stock_Info { rcs_code: String, total: Int, rubber_id: Int,
             size_id: Int, description: String }
```

Live samples (IBT 120803, IBT 122773):

| rcs_code | size_id | rubber_id | description | total |
|---|---|---|---|---|
| RCS141 | 70 | ? | `315/80R22.5 A1 STOCK RETREAD` | 50 |
| RCS317 | 70 | 36 | `315/80R22.5 M90L STOCK RETREAD` | 83 |
| LLS039 | 70 | 60 | `315/80R22.5 RD2+ STOCK RINGTREAD` | 13 |
| RCS790 | 54 | 16 | `275/70R22.5 MM84 STOCK RETREAD` | 3 |
| RCS791 | 16 | 16 | `11R22.5 MM84 STOCK RETREAD` | 5 |

**The "GRV number" you half-remember is most likely the `rcs_code`** —
the stock-line identifier on every IBT manifest line (`RCSxxx` series,
older `LLSxxx` series). Nothing in any codebase contains the literal
"GRV". The goods-received register that matches GRV semantics is the
received-CS set: `CreateReceivedCS` / `UpdateReceivedCS {received_complete}`
/ `listReceivedCS` (2023-era rows), plus the factory receiving tallies
`getReceiveTotal` and `getRecievingPersonnelTally` (ATT Supervisor).
Worth asking the floor: "what number is printed on the IBT slip?" — if
they say an `RCSxxx`-style code, that confirms it.

## 2. What the scanner does at scan time

### 2.1 The scan itself (both apps)
A scan is a **14-hex NFC UID** read from the tyre chip. Nothing else is
read from the tag. Every decision flows from that UID:

```
uid → getSlipTyreWithUID(uid)          // Slip_Tyre_Info row
    → getTyreHistory(slip.idSlip)      // movement vocabulary
```

### 2.2 The dispatch scan mutation (`createDispatchDeliveryINV_V2`)
The authoritative per-scan record:

```
{ uid, personnel_id, registration, document_no, location_id, loaded }
```

- `document_no` is the ERP document number WITH prefix: `INV2392908`
  (customer), `DIBT0179154`, **`IBT120803` (stocks)**, or AMS.
- `loaded` (Int 0/1) marks the tyre as loaded onto the truck.
- **This is how a tyre "falls under stocks": the operator staged an IBT
  document and the scan was committed with `document_no = IBTxxxxx`.**
- The loading log is mutation-only — there is NO read query for it today
  (known resolver gap; `listDispatchLoadingLog` was requested).

### 2.3 IBT manifests have no tyre list — trust-based reconciliation
`getDeliveryInfo.ibt` returns **spec lines only** — no slips, no UIDs.
"IBT reconciliation has nothing to match" (backend-reality §5.2). So at
scan time the system CANNOT verify a tyre against an IBT line by UID.
dispatch-app's `ScanReconciliationEngine` therefore returns
`ValidatedUnlisted("Not on IBT …")` for every IBT scan — the backend
accepts it and the operator's staged document carries the trust.
(For INV/DIBT/AMS and CS documents, slips WITH uids DO exist and scans
are matched via `StagedDocument.containsUid(uid)`.)

### 2.4 Scan-time guards (the error messages)
- Backend resolver (getDeliveryInfo): **"Only one document number type
  can be entered"** · **"Document number not found"** · **"Invalid
  document number"** · `Lambda:Unhandled` when any of the four keys is
  missing (all-four-keys rule — unused keys must be empty strings).
- dispatch-app scan outcomes: `AlreadyLoaded` (with `previous_reg` —
  cross-truck collision, must not count), `DumpedTyre` (`dump == 1`),
  `ScrapNotAccepted` (rejects stream, `reject_accepted != 1`),
  `TyreUnknown` (no slip row for the uid), `TyreLookupUnavailable`
  (network).
- ATT Supervisor factory guards: `Reject Already Accepted` ·
  `Failed! NFC turned off` · `Please Scan Valid Tyre/Personnel Tag` ·
  `Tyre Not Scanned` · `No Rubber` · `No Tyre Data` · `Not authorised` ·
  `Work cell not selected yet`.

## 3. Data-side fingerprints — how OUR app can identify a stocks tyre

After scanning a UID, the system can answer "is this tyre stock?" with
these signals (highest confidence first):

| # | Signal | Where | Meaning |
|---|---|---|---|
| 1 | `description` contains `STOCK` (STOCK RETREAD / STOCK RINGTREAD) | manifest / slip pattern | stock-transfer tyre |
| 2 | `rcs_code` present on its manifest line | `getDeliveryInfo.ibt` only (NOT on slip rows) | stock-line id ("GRV") |
| 3 | `location_id == 008` | slip row | **Stock Tyre Bay / Stock Storage Yard** (location vocabulary; 091 = Bulk Bay, 090 = Factory) |
| 4 | latest history cell `DISPATCH STOCK TAKE` | getTyreHistory | counted at dispatch — standing in the yard |
| 5 | no `INV…`/`CRN…` stamp in `invoice_number` | slip row | not customer-bound (DIBT also unstamped — careful) |
| 6 | no `DISPATCH DELIVERY` cell | history | not dispatched to a customer |
| 7 | not scrap/dump (`reject_accepted != 2`, no REJECT cells, `dump != 1`) | slip + history | not reject flow |
| 8 | session vocabulary `STOCKTAKE`/`STOCK TAKE`/`STOCKS`/`STOKETAKE` | getActiveDispatchSession comments | stocktake activity |
| 9 | stock ledger `listStockMinMax` (size+pattern min/max) + `UpdateRubberStock`/`UpdateRubberProvisionalStock` | stock mutations | the "how many do we hold" ledger |

Slip rows expose `size_id`, `rubber_id`, `size` — but **never
`rcs_code`** (§backend-reality 729). To map a scanned tyre to its RCS
line, cross-reference `size_id + rubber_id` (plus pattern) against the
IBT manifest's Stock_Info lines — the same matching OUR IBT tally already
does when counting.

## 4. Decision tree for the future scan section

```
scan uid → getSlipTyreWithUID + getTyreHistory
  ├─ dump==1 or REJECT DUMP cell                 → DUMP
  ├─ reject_accepted==2 or REJECT cells or DUD   → SCRAP
  ├─ job "Claim…" / pattern CLAIM                → CLAIM
  ├─ invoice_number INV/CRN or DISPATCH DELIVERY → CUSTOMER
  ├─ latest cell DISPATCH STOCK TAKE
  │    OR location_id 008
  │    OR size+rubber matches an IBT Stock_Info line (RCS code)
  │    OR description contains STOCK             → STOCKS (IBT)
  └─ otherwise                                   → IN FACTORY
```

## 5. The two reported bugs (documented, NOT fixed yet)

### 5.1 Sheet-side edit wipes the entry's IBT data
`TruckLoadDialog._handleSave` constructs a fresh `LoadingSheetTrip`
without `ibtDocuments` (the dialog never loads them). When a STOCKS row
is edited from the loading sheet, `LoadingSheetViewModel.updateTruckLoad`
replaces the trip wholesale → IBT documents, per-line progress and
history are dropped, while the sheet row still shows the old computed
status until refresh. Fix direction (later): carry `ibtDocuments`
through the dialog round-trip, or have `updateTruckLoad` merge
`ibtDocuments`/history from the previous trip.

### 5.2 IBT materializes slowly
The IBT fetch path is one synchronous GraphQL call (`fetchIbtDocument`)
with no cached token/response reuse and a full re-fetch per attach; the
stocks screen also re-reads the entry through `FutureBuilder` on every
notify. Fix direction (later): cache manifests locally, resolve the
auto-session up front, and avoid re-fetch storms on `notifyListeners`.

---

*Recon complete. Next step candidates: (a) confirm the RCS code on the
physical IBT slip with the floor, (b) build the scan→classify engine
from §4, (c) then fix 5.1/5.2.*
