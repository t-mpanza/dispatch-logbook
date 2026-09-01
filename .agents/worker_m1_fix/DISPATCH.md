## 2026-09-01T19:16:16Z
Scope & Task:
Remediate the 5 defects uncovered by the adversarial challengers:
1. `flutter_app/lib/data/models/loading_sheet_trip.dart`:
   - In `copyWith`, allow clearing or replacing `ibtDocuments`. Support `bool clearIbtDocuments = false` (or `clearTargetQuantity = false`), ensuring that when `clearIbtDocuments` is true, `ibtDocuments` becomes `null`.
2. `flutter_app/lib/presentation/viewmodels/loading_sheet_viewmodel.dart`:
   - In `removeIbtDocument`:
     - If remaining `filtered` documents is non-empty, recalculate `totalTarget` and `totalLoaded` across `filtered`, and update `trip.copyWith(ibtDocuments: filtered, targetQuantity: totalTarget, quantityLoaded: totalLoaded)`.
     - If `filtered` is empty, update `trip.copyWith(clearIbtDocuments: true, targetQuantity: null, quantityLoaded: 0)`.
   - In `updateIbtLineQuantity`:
     - In `trip.copyWith(...)`, set `quantityLoaded: totalLoadedAcrossAllIbts` unconditionally so that stepping down counts to 0 properly sets `quantityLoaded` to 0.
3. `flutter_app/lib/data/models/ibt_manifest.dart`:
   - In `IbtLineItem.overCount`, change logic to avoid `ArgumentError` on negative quantities:
     `if (loadedQuantity <= targetTotal) return 0; return loadedQuantity - targetTotal;`
4. `flutter_app/lib/data/services/whatsapp_export_service.dart` & `flutter_app/lib/data/services/pdf_export_service.dart`:
   - Check `isOverloaded` BEFORE `isComplete` when rendering line item status badges/labels so overloaded line items are not incorrectly tagged as `COMPLETE` or `[✓]`.
5. Add comprehensive unit tests in `flutter_app/test/` (e.g. in `ibt_manifest_test.dart` and `ibt_workflow_tdd_test.dart`) covering:
   - Removing the last IBT document and verifying `hasIbtDocuments == false` and `ibtDocuments == null`.
   - Stepping loaded quantities down to 0 and verifying `quantityLoaded == 0`.
   - Negative loadedQuantity in `IbtLineItem.overCount`.
   - Multi-IBT document target recalculation upon removal.
   - WhatsApp and PDF export status ordering (`isOverloaded` vs `isComplete`).
6. Run `dart analyze` and `flutter test` in `flutter_app/`.

Output:
Write a full report to `/home/kiddow/Desktop/Work/Despatch Diary/.agents/worker_m1_fix/handoff.md`.
Send a completion message back to the orchestrator.
