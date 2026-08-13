# Scope: Milestone 1 — Despatch Loading Sheet Compliance System

## Requirements

Implement all compliance specifications from `/home/kiddow/Desktop/Work/Despatch Diary/.agents/ORIGINAL_REQUEST.md` §R1:

1. **Header**: Date, Despatcher Name (saved user preference in localStorage / IndexedDB settings).
2. **Active Columns**:
   - `Reg` (Truck Registration plate)
   - `Driver Name`
   - `Trip ID` (dropdown presets + free text):
     - `DBN`
     - `NLS`
     - `BLOEM`
     - `PLK`
     - `STOCKS [i]` (daily auto-incrementing counter `STOCKS 1`, `STOCKS 2`... resetting at midnight)
     - `NLH` (auto-fills Driver: `Neil`, Reg: `MN05XNGP`)
     - `TIREPOINT`
     - Custom text option
   - `Loading Start Time` (auto-populated from 1st scan, editable)
   - `Loading Finished Time` (auto-populated from last scan, editable)
   - `Minutes` (auto-calculated duration in minutes between start and finish time)
   - `Quantity Loaded` (auto-calculated from scan session, editable)
3. **Removed Fields**: Arrival Time, Departure Time, Pressure Check, PSI footer warning banner omitted.
4. **Summary Footer**:
   - `TOTAL TYRES LOADED` (auto-summed across all rows for the day)
   - `TOTAL LOADING TIME` (total aggregate loading minutes)
5. **Standalone Manual Rows**: Support adding standalone manual truck rows directly to daily sheet without full scanner session.
6. **Exports**: Clean printable PDF loading sheet report (`src/lib/export-pdf.ts`) & formatted WhatsApp text share message (`src/lib/export-whatsapp.ts`).

## Code Artifacts

- `src/lib/types.ts`: Extended `LoadingSheetTrip` & `Entry` types.
- `src/lib/loading-presets.ts`: Presets & daily counter logic.
- `src/lib/export-pdf.ts`: PDF generation & print styles.
- `src/lib/export-whatsapp.ts`: WhatsApp text formatter.
- `src/components/LoadingSheet.tsx`: Compliance sheet UI.
- `src/routes/entry.$id.tsx` / `src/routes/counter.tsx`: Loading sheet integration.
