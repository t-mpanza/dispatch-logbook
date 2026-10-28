# Tyre Classification Synopsis — STOCKS vs CUSTOMER vs DUMP

> Research deliverable for the future in-app tyre-scanning section.
> Sources: `dispatch-app` docs (`backend-reality.md` §11–§16, live data studies
> 2026-09-07 / 2026-09-16), dispatch-app domain code (ScrapMarker,
> StocktakeMarker, movement markers), and our own Dispatch Diary flags.

## 1. How the system identifies a tyre today

Identity is the **14-hex NFC UID** on the tyre chip. Everything else is
derived by walking three read-only surfaces:

| Surface | Query | What it tells us |
|---|---|---|
| Slip row | `getSlipTyreWithUID(uid)` | `reject_accepted`, `dump`, `job`, `pattern`, `invoice_number`, `cs_number`, `location_id`, `loaded`, `serial`, `size`, `make`, `customerName` |
| Scan history | `getTyreHistory(slip_id)` | every work-cell scan the tyre has ever had (movement vocabulary) |
| Document | `getDeliveryInfo(inv/dibt/ibt/amsInv)` | which manifest the tyre belongs to + its slip list |

There is **no single "is_stocks" flag**. Classification is derived from the
combination of flags + movement vocabulary below (this is why the deep
research matters).

## 2. The four classes and their signals

### 2.1 SCRAP (failed tyre, going back or thrown away)
- `reject_accepted == 2` on the slip row — **the reliable flag**
  (verified: every scrap slip in the live probe carried it).
- History contains a rejects-flow cell: `REJECT INSPECTOR`,
  `REJECT EXIT`, `REJECT RETURN`, `REJECT TRANSFER`.
- `DUD` code present in `serial` / `pattern` / `size`
  (e.g. `DUD - DAMAGE BELT`).
- Usually `casing_grade = Z`.

### 2.2 DUMP (physically thrown away)
- `dump == 1` flag on the slip row, OR
- `REJECT DUMP` in history (~12 % of scraps in the live probe get dumped;
  the rest return to the customer).
- Note: `dump` is **not** the scrap marker — it is the disposal marker on
  top of scrap.

### 2.3 CUSTOMER tyre (invoice flow)
- Slip stamped with an invoice: `invoice_number` starting `INV…` or
  `CRN…` (credit notes) — live census: INV 153 · CRN 46 · empty 101 per
  300 slips; DIBT slips are **never stamped** (known gap, §13.4).
- `loaded == 1` on its delivery-document slip row (it left on a truck).
- History contains `DISPATCH DELIVERY` (the load-out event) and its
  production journey (`INITIAL INSPECTION → … → DISPATCH INSPECTION`).

### 2.4 STOCKS tyre (yard / stock transfer, not customer-bound)
- History's **latest cell is `DISPATCH STOCK TAKE`** — the yard signature
  (77 of the live probe's tyres stand there right now). Delivery or stock
  take always follows `DISPATCH INSPECTION`, so the *latest* cell decides.
- Belongs to an **IBT document** — IBT = internal stock transfer; manifest
  descriptions literally carry `STOCK` (`315/80R22.5 M90L STOCK RETREAD`,
  `… STOCK RINGTREAD`).
- Active dispatch sessions with stocktake comments: `STOCKTAKE`,
  `STOCK TAKE`, `WEEKLY STOCKTAKE`, `STOCKS`, and the typo `STOKETAKE`
  (dispatch-app `StocktakeMarker` normalises whitespace and matches all
  variants).
- Stock ledger side (`listStockMinMax`) tracks per-size/pattern stock
  min/max — the "how many of X do we hold" view.

### 2.5 CLAIM (adjacent class — warranty rework)
- `job_id == 2` / `job = "Claim…"/"Claim Redo"` + `pattern = "CLAIM"` +
  `CLAIM INSPECTION / CLAIM REDO / CREDIT PROCESSING` history.

## 3. Decision tree (scan → classify)

```
scan uid
 ├─ getSlipTyreWithUID(uid)            → slip row
 ├─ getTyreHistory(slip.idSlip)        → cells[]
 │
 ├─ reject_accepted == 2  OR  any cell contains "REJECT"  OR  DUD in serial/pattern/size
 │        └─ dump == 1 OR "REJECT DUMP" in cells ? DUMP : SCRAP
 ├─ job == "Claim…" / pattern == "CLAIM"          → CLAIM
 ├─ latest cell == "DISPATCH DELIVERY"  OR  invoice_number starts INV/CRN
 │        └─ CUSTOMER (delivered)
 ├─ latest cell in stocktake vocabulary  OR  belongs to an IBT document
 │        └─ STOCKS (in yard)
 └─ otherwise                                    → IN FACTORY (production)
```

## 4. Proposed scan section for Dispatch Diary

1. **Scan** tyre tag (NFC, already live in the hidden Dispatch tab).
2. Resolve slip + history (already built: `DispatchApi.fetchTyreByUid` +
   `TyreHistoryEntry`).
3. Classify with the tree above (new pure engine, unit-tested) and show a
   colour-coded class badge: SCRAP red · DUMP black-red · CUSTOMER green ·
   STOCKS blue · CLAIM amber.
4. **Stock counting** (the future part): aggregate scans per size+pattern
   into a live ledger (`M90L ×12 · M38 ×7 …`), reconcilable against the
   backend stock ledger (`listStockMinMax`) — our answer to
   "scan tyres from our app, not the company app".

## 5. Known traps (from live study)

- `STOKETAKE` typo and whitespace variants in session comments.
- DIBT deliveries are never stamped on slips — only the loading log knows
  them (invoice-stamp check must not misclassify DIBT tyres as stocks).
- Some rejected tyres are still delivered under an INV later (§15.1) —
  `DISPATCH DELIVERY` overrides REJECT RETURN when it is the *latest* cell.
- `dump = 0` on scrap rows is normal — do not require dump for scrap.

*Synopsis prepared for the future scanning feature. Ground truth from
`dispatch-app/docs/backend-reality.md` (verified live probes 2026-09).*
